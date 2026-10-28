using System.Text;
using System.Threading.RateLimiting;
using Microsoft.AspNetCore.Authentication.JwtBearer;
using Microsoft.AspNetCore.RateLimiting;
using Microsoft.EntityFrameworkCore;
using Microsoft.IdentityModel.Tokens;
using Microsoft.OpenApi.Models;
using SmartGuard.API.Data;
using SmartGuard.API.Models;
using SmartGuard.API.Services.Discord;
using SmartGuard.API.Services.Email;
using SmartGuard.API.Services.Security;

var builder = WebApplication.CreateBuilder(args);

// 1. Cấu hình Database EF Core (SQL Server)
var connectionString = builder.Configuration.GetConnectionString("DefaultConnection")
    ?? "Server=DESKTOP-IIQVP6N;Database=SmartGuard_Unified_DB;Trusted_Connection=True;TrustServerCertificate=True;";

builder.Services.AddDbContext<SmartGuardDbContext>(options =>
    options.UseSqlServer(connectionString, sql => sql.EnableRetryOnFailure()));

// 2. Cấu hình Dependency Injection Services
builder.Services.Configure<TokenOptions>(builder.Configuration.GetSection(TokenOptions.SectionName));
builder.Services.Configure<EmailOptions>(builder.Configuration.GetSection(EmailOptions.SectionName));
builder.Services.Configure<DiscordOptions>(builder.Configuration.GetSection(DiscordOptions.SectionName));

builder.Services.AddSingleton<ITokenService, TokenService>();
builder.Services.AddScoped<IEmailService, EmailService>();
builder.Services.AddScoped<SmartGuard.API.Services.Adaptive.IAdaptiveRuleEngine, SmartGuard.API.Services.Adaptive.AdaptiveRuleEngine>();

// Discord Bot Service (Hosted Background Service + Singleton Interface)
builder.Services.AddSingleton<DiscordBotService>();
builder.Services.AddSingleton<IDiscordAlertService>(sp => sp.GetRequiredService<DiscordBotService>());
builder.Services.AddHostedService(sp => sp.GetRequiredService<DiscordBotService>());

// 3. Cấu hình Rate Limiting (chống brute-force 15 req/min theo IP)
builder.Services.AddRateLimiter(options =>
{
    options.RejectionStatusCode = StatusCodes.Status429TooManyRequests;
    options.AddPolicy("auth-rate-limit", httpContext =>
        RateLimitPartition.GetFixedWindowLimiter(
            httpContext.Connection.RemoteIpAddress?.ToString() ?? "anonymous",
            _ => new FixedWindowRateLimiterOptions
            {
                PermitLimit = 15,
                Window = TimeSpan.FromMinutes(1),
                QueueLimit = 0
            }));
});

// 4. Cấu hình JWT Authentication
var jwtKey = builder.Configuration["Jwt:Key"] ?? "SmartGuard_Security_Master_Key_2026_AtLeast32BytesLength!";
var jwtIssuer = builder.Configuration["Jwt:Issuer"] ?? "SmartGuardApi";
var jwtAudience = builder.Configuration["Jwt:Audience"] ?? "SmartGuardMobile";

builder.Services.AddAuthentication(options =>
{
    options.DefaultAuthenticateScheme = JwtBearerDefaults.AuthenticationScheme;
    options.DefaultChallengeScheme = JwtBearerDefaults.AuthenticationScheme;
})
.AddJwtBearer(options =>
{
    options.RequireHttpsMetadata = false;
    options.SaveToken = true;
    options.TokenValidationParameters = new TokenValidationParameters
    {
        ValidateIssuerSigningKey = true,
        IssuerSigningKey = new SymmetricSecurityKey(Encoding.UTF8.GetBytes(jwtKey)),
        ValidateIssuer = true,
        ValidIssuer = jwtIssuer,
        ValidateAudience = true,
        ValidAudience = jwtAudience,
        ValidateLifetime = true,
        ClockSkew = TimeSpan.FromMinutes(1)
    };
});

builder.Services.AddAuthorization(options =>
{
    options.AddPolicy("RequireAdmin", policy => policy.RequireRole("Admin"));
    options.AddPolicy("RequireOwnerOrAdmin", policy => policy.RequireRole("Owner", "Admin"));
});

// 5. Cấu hình CORS mở cho thiết bị di động trong mạng LAN
builder.Services.AddCors(options =>
{
    options.AddPolicy("AllowAll", policy =>
    {
        policy.AllowAnyOrigin()
              .AllowAnyMethod()
              .AllowAnyHeader();
    });
});

builder.Services.AddControllers();
builder.Services.AddEndpointsApiExplorer();

// 6. Cấu hình Swagger UI có nút Authorize Bearer Token
builder.Services.AddSwaggerGen(c =>
{
    c.SwaggerDoc("v1", new OpenApiInfo
    {
        Title = "SmartGuard Unified Security API",
        Version = "v1",
        Description = "API giám sát an ninh camera thông minh tích hợp Discord, Sinh trắc học & Adaptive Security"
    });

    c.AddSecurityDefinition("Bearer", new OpenApiSecurityScheme
    {
        Description = "Nhập token JWT theo định dạng: Bearer {token}",
        Name = "Authorization",
        In = ParameterLocation.Header,
        Type = SecuritySchemeType.ApiKey,
        Scheme = "Bearer"
    });

    c.AddSecurityRequirement(new OpenApiSecurityRequirement
    {
        {
            new OpenApiSecurityScheme
            {
                Reference = new OpenApiReference
                {
                    Type = ReferenceType.SecurityScheme,
                    Id = "Bearer"
                }
            },
            Array.Empty<string>()
        }
    });
});

var app = builder.Build();

// 7. Khởi tạo Database & Seed dữ liệu Admin ban đầu
using (var scope = app.Services.CreateScope())
{
    var services = scope.ServiceProvider;
    var logger = services.GetRequiredService<ILogger<Program>>();
    var db = services.GetRequiredService<SmartGuardDbContext>();
    var tokenService = services.GetRequiredService<ITokenService>();

    try
    {
        // Tự động áp dụng các Migration chưa chạy thay vì dùng EnsureCreated
        await db.Database.MigrateAsync();

        // Seed tài khoản Admin mặc định nếu chưa có
        if (!await db.Users.AnyAsync(u => u.Role == "Admin"))
        {
            var defaultAdmin = new User
            {
                Email = "admin@smartguard.local",
                Username = "admin",
                PasswordHash = tokenService.HashPassword("Admin123@"),
                Role = "Admin",
                EmailVerified = true
            };
            db.Users.Add(defaultAdmin);
            await db.SaveChangesAsync();
            logger.LogInformation("✅ Đã khởi tạo tài khoản quản trị mặc định: admin@smartguard.local / Admin123@");
        }
    }
    catch (Exception ex)
    {
        logger.LogError(ex, "Lỗi trong quá trình khởi tạo CSDL.");
    }
}

// 8. Cấu hình HTTP Pipeline
if (app.Environment.IsDevelopment())
{
    app.UseSwagger();
    app.UseSwaggerUI(c =>
    {
        c.SwaggerEndpoint("/swagger/v1/swagger.json", "SmartGuard API v1");
        c.RoutePrefix = "swagger";
    });
}

app.UseCors("AllowAll");
app.UseStaticFiles(); // Cho phép truy cập ảnh bằng chứng tại /evidence/...

app.UseRateLimiter();
app.UseAuthentication();
app.UseAuthorization();

app.MapControllers();

app.MapGet("/", () => Results.Ok(new
{
    service = "SmartGuard Unified Security API",
    status = "Online",
    version = "1.0.0",
    docs = "/swagger"
}));

app.Run();
