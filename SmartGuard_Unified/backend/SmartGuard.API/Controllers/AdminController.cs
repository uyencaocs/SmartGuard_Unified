using System.Diagnostics;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using Microsoft.EntityFrameworkCore;
using SmartGuard.API.Data;
using SmartGuard.API.DTOs;
using SmartGuard.API.Models;
using SmartGuard.API.Services.Security;

namespace SmartGuard.API.Controllers
{
    [ApiController]
    [Route("api/[controller]")]
    [Authorize(Roles = "Admin")]
    public class AdminController : ControllerBase
    {
        private readonly SmartGuardDbContext _db;
        private readonly ITokenService _tokenService;

        public AdminController(SmartGuardDbContext db, ITokenService tokenService)
        {
            _db = db;
            _tokenService = tokenService;
        }

        [HttpGet("stats")]
        public async Task<IActionResult> GetDashboardStats()
        {
            var today = DateTime.UtcNow.Date;

            var totalUsers = await _db.Users.CountAsync();
            var totalDevices = await _db.Devices.CountAsync();
            var totalAlertsToday = await _db.AlertEvents.CountAsync(a => a.TriggeredAt >= today);
            var activeArmedDevices = await _db.Devices.CountAsync(d => d.IsArmed);

            return Ok(new AdminStatsDto(
                TotalUsers: totalUsers,
                TotalDevices: totalDevices,
                TotalAlertsToday: totalAlertsToday,
                ActiveArmedDevices: activeArmedDevices
            ));
        }

        [HttpGet("users")]
        public async Task<IActionResult> GetUsers()
        {
            var users = await _db.Users
                .OrderByDescending(u => u.CreatedAt)
                .Select(u => new UserProfileDto(
                    u.Id,
                    u.Email,
                    u.Username,
                    u.Role,
                    u.IsLocked,
                    u.CreatedAt
                ))
                .ToListAsync();

            return Ok(users);
        }

        [HttpPatch("users/{id:guid}/status")]
        public async Task<IActionResult> UpdateUserStatus(Guid id, [FromBody] UpdateUserStatusDto dto)
        {
            var user = await _db.Users.FindAsync(id);
            if (user == null) return NotFound(new { message = "Không tìm thấy người dùng." });

            if (!string.IsNullOrWhiteSpace(dto.Role))
            {
                user.Role = dto.Role.Equals("Admin", StringComparison.OrdinalIgnoreCase) ? "Admin" : "Owner";
            }

            if (dto.IsLocked.HasValue)
            {
                user.IsLocked = dto.IsLocked.Value;
            }

            await _db.SaveChangesAsync();

            return Ok(new { message = "Cập nhật trạng thái người dùng thành công.", userId = user.Id, isLocked = user.IsLocked, role = user.Role });
        }

        [HttpPost("users")]
        public async Task<IActionResult> CreateUser([FromBody] CreateUserAdminDto dto)
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
                EmailVerified = true,
                CreatedAt = DateTime.UtcNow
            };

            _db.Users.Add(user);
            await _db.SaveChangesAsync();

            return Ok(new UserProfileDto(
                user.Id,
                user.Email,
                user.Username,
                user.Role,
                user.IsLocked,
                user.CreatedAt
            ));
        }

        [HttpPut("users/{id:guid}")]
        public async Task<IActionResult> UpdateUser(Guid id, [FromBody] UpdateUserAdminDto dto)
        {
            var user = await _db.Users.FindAsync(id);
            if (user == null) return NotFound(new { message = "Không tìm thấy người dùng." });

            if (!string.IsNullOrWhiteSpace(dto.Email))
            {
                var normalizedEmail = dto.Email.Trim().ToLowerInvariant();
                if (await _db.Users.AnyAsync(u => u.Email == normalizedEmail && u.Id != id))
                    return BadRequest(new { message = "Email này đã được sử dụng bởi tài khoản khác." });
                user.Email = normalizedEmail;
            }

            if (!string.IsNullOrWhiteSpace(dto.Username))
            {
                var normalizedUsername = dto.Username.Trim().ToLowerInvariant();
                if (await _db.Users.AnyAsync(u => u.Username == normalizedUsername && u.Id != id))
                    return BadRequest(new { message = "Tên đăng nhập này đã được sử dụng bởi tài khoản khác." });
                user.Username = normalizedUsername;
            }

            if (!string.IsNullOrWhiteSpace(dto.Role))
            {
                user.Role = dto.Role.Equals("Admin", StringComparison.OrdinalIgnoreCase) ? "Admin" : "Owner";
            }

            if (!string.IsNullOrWhiteSpace(dto.Password))
            {
                user.PasswordHash = _tokenService.HashPassword(dto.Password);
            }

            if (dto.IsLocked.HasValue)
            {
                user.IsLocked = dto.IsLocked.Value;
            }

            await _db.SaveChangesAsync();

            return Ok(new UserProfileDto(
                user.Id,
                user.Email,
                user.Username,
                user.Role,
                user.IsLocked,
                user.CreatedAt
            ));
        }

        [HttpDelete("users/{id:guid}")]
        public async Task<IActionResult> DeleteUser(Guid id)
        {
            var user = await _db.Users.FindAsync(id);
            if (user == null) return NotFound(new { message = "Không tìm thấy người dùng." });

            _db.Users.Remove(user);
            await _db.SaveChangesAsync();

            return Ok(new { message = "Đã xóa tài khoản người dùng thành công.", userId = id });
        }

        [HttpGet("system")]
        public IActionResult GetSystemInfo()
        {
            using var proc = Process.GetCurrentProcess();

            return Ok(new
            {
                serverTime = DateTime.UtcNow,
                osVersion = Environment.OSVersion.ToString(),
                machineName = Environment.MachineName,
                dotnetVersion = Environment.Version.ToString(),
                workingSetMemoryMb = Math.Round(proc.WorkingSet64 / (1024.0 * 1024.0), 2),
                threads = proc.Threads.Count,
                uptimeSeconds = (DateTime.UtcNow - proc.StartTime.ToUniversalTime()).TotalSeconds
            });
        }
    }
}
