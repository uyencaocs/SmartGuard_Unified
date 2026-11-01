using System.Security.Claims;
using System.Security.Cryptography;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using Microsoft.EntityFrameworkCore;
using SmartGuard.API.Data;
using SmartGuard.API.DTOs;
using SmartGuard.API.Models;
using SmartGuard.API.Services.Email;
using SmartGuard.API.Services.Security;

namespace SmartGuard.API.Controllers
{
    [ApiController]
    [Route("api/[controller]")]
    public class AuthController : ControllerBase
    {
        private readonly SmartGuardDbContext _db;
        private readonly ITokenService _tokenService;
        private readonly IEmailService _emailService;
        private readonly ILogger<AuthController> _logger;

        public AuthController(
            SmartGuardDbContext db,
            ITokenService tokenService,
            IEmailService emailService,
            ILogger<AuthController> logger)
        {
            _db = db;
            _tokenService = tokenService;
            _emailService = emailService;
            _logger = logger;
        }

        [HttpPost("register")]
        public async Task<IActionResult> Register([FromBody] RegisterDto dto)
        {
            var normalizedEmail = dto.Email.Trim().ToLowerInvariant();
            var normalizedUsername = dto.Username.Trim().ToLowerInvariant();

            if (await _db.Users.AnyAsync(u => u.Email == normalizedEmail))
                return BadRequest(new { message = "Email này đã được sử dụng." });

            if (await _db.Users.AnyAsync(u => u.Username == normalizedUsername))
                return BadRequest(new { message = "Tên đăng nhập này đã tồn tại." });

            var role = dto.Role.Equals("Admin", StringComparison.OrdinalIgnoreCase) ? "Admin" : "Owner";

            var user = new User
            {
                Email = normalizedEmail,
                Username = normalizedUsername,
                PasswordHash = _tokenService.HashPassword(dto.Password),
                Role = role,
                EmailVerified = true
            };

            _db.Users.Add(user);
            await _db.SaveChangesAsync();

            _logger.LogInformation("Người dùng mới đã đăng ký: {Username} ({Email}) với vai trò {Role}", user.Username, user.Email, user.Role);
            return Ok(new { message = "Đăng ký tài khoản thành công!", userId = user.Id });
        }

        [HttpPost("login")]
        public async Task<IActionResult> Login([FromBody] LoginDto dto)
        {
            var identifier = dto.Identifier.Trim().ToLowerInvariant();
            var user = await _db.Users.FirstOrDefaultAsync(u => u.Email == identifier || u.Username == identifier);

            if (user == null || !_tokenService.VerifyPassword(dto.Password, user.PasswordHash))
                return Unauthorized(new { message = "Tài khoản hoặc mật khẩu không chính xác." });

            if (user.IsLocked)
                return StatusCode(StatusCodes.Status403Forbidden, new { message = "Tài khoản của bạn đã bị khóa bởi quản trị viên." });

            // Tạo mã OTP 6 số ngẫu nhiên an toàn
            var otpCode = RandomNumberGenerator.GetInt32(100000, 999999).ToString();
            var challenge = new OtpChallenge
            {
                UserId = user.Id,
                Purpose = "Login",
                CodeHash = _tokenService.HashPassword(otpCode),
                ExpiresAt = DateTime.UtcNow.AddMinutes(5)
            };

            _db.OtpChallenges.Add(challenge);
            await _db.SaveChangesAsync();

            var emailSent = await _emailService.SendOtpEmailAsync(user.Email, otpCode, "Đăng nhập");

            return Ok(new
            {
                challengeId = challenge.Id,
                email = MaskEmail(user.Email),
                message = emailSent
                    ? "Vui lòng nhập mã OTP đã gửi đến email của bạn."
                    : "Chế độ LAN/Offline: vui lòng dùng mã OTP hiển thị hoặc trong log server.",
                expiresInSeconds = 300,
                devOtp = emailSent ? null : otpCode
            });
        }

        [HttpPost("verify-otp")]
        public async Task<IActionResult> VerifyOtp([FromBody] VerifyOtpDto dto)
        {
            var challenge = await _db.OtpChallenges.FirstOrDefaultAsync(c => c.Id == dto.ChallengeId && c.Purpose == "Login");
            if (challenge == null)
                return BadRequest(new { message = "Yêu cầu OTP không hợp lệ hoặc đã hết hạn." });

            if (challenge.UsedAt.HasValue)
                return BadRequest(new { message = "Mã OTP này đã được sử dụng." });

            if (challenge.ExpiresAt < DateTime.UtcNow)
                return BadRequest(new { message = "Mã OTP đã hết hạn." });

            if (challenge.Attempts >= 5)
                return BadRequest(new { message = "Bạn đã thử sai quá 5 lần. Vui lòng đăng nhập lại." });

            if (!_tokenService.VerifyPassword(dto.Code, challenge.CodeHash))
            {
                challenge.Attempts++;
                await _db.SaveChangesAsync();
                return BadRequest(new { message = $"Mã OTP không đúng. Còn {5 - challenge.Attempts} lần thử." });
            }

            challenge.UsedAt = DateTime.UtcNow;
            var user = await _db.Users.FindAsync(challenge.UserId);
            if (user == null) return NotFound(new { message = "Không tìm thấy người dùng." });

            await _db.SaveChangesAsync();

            var token = _tokenService.GenerateToken(user);
            return Ok(new AuthResponseDto(
                Token: token,
                UserId: user.Id,
                Email: user.Email,
                Username: user.Username,
                Role: user.Role,
                ExpiresAt: DateTime.UtcNow.AddHours(24)
            ));
        }

        [HttpGet("me")]
        [Authorize]
        public async Task<IActionResult> GetProfile()
        {
            var userIdStr = User.FindFirstValue(ClaimTypes.NameIdentifier);
            if (!Guid.TryParse(userIdStr, out var userId)) return Unauthorized();

            var user = await _db.Users.FindAsync(userId);
            if (user == null) return NotFound();

            return Ok(new UserProfileDto(
                Id: user.Id,
                Email: user.Email,
                Username: user.Username,
                Role: user.Role,
                IsLocked: user.IsLocked,
                CreatedAt: user.CreatedAt
            ));
        }

        private static string MaskEmail(string email)
        {
            var parts = email.Split('@');
            if (parts.Length != 2) return email;
            var name = parts[0];
            var maskedName = name.Length <= 2 ? name + "***" : name[..2] + new string('*', name.Length - 2);
            return $"{maskedName}@{parts[1]}";
        }
    }
}
