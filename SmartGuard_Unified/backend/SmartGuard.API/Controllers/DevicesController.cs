using System.Security.Claims;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using Microsoft.EntityFrameworkCore;
using SmartGuard.API.Data;
using SmartGuard.API.DTOs;
using SmartGuard.API.Models;

namespace SmartGuard.API.Controllers
{
    [ApiController]
    [Route("api/[controller]")]
    [Authorize]
    public class DevicesController : ControllerBase
    {
        private readonly SmartGuardDbContext _db;
        private readonly ILogger<DevicesController> _logger;

        public DevicesController(SmartGuardDbContext db, ILogger<DevicesController> logger)
        {
            _db = db;
            _logger = logger;
        }

        private Guid CurrentUserId => Guid.Parse(User.FindFirstValue(ClaimTypes.NameIdentifier)!);
        private bool IsAdmin => User.IsInRole("Admin");

        [HttpGet]
        public async Task<IActionResult> GetDevices()
        {
            var userId = CurrentUserId;

            // Lấy danh sách thiết bị sở hữu hoặc được chia sẻ quyền
            var ownedDevices = await _db.Devices
                .Include(d => d.Zone)
                .Where(d => IsAdmin || d.OwnerId == userId)
                .Select(d => new DeviceResponseDto(
                    d.Id,
                    d.OwnerId,
                    d.ZoneId,
                    d.Zone != null ? d.Zone.Name : null,
                    d.Name,
                    d.DeviceCode,
                    d.Description,
                    d.IsArmed,
                    d.NoiseThreshold,
                    d.MotionThreshold,
                    d.RegisteredAt,
                    d.LastSeenAt
                ))
                .ToListAsync();

            // Cộng thêm các thiết bị được chia sẻ
            var sharedDeviceIds = await _db.MemberAccesses
                .Where(m => m.MemberUserId == userId)
                .Select(m => m.DeviceId)
                .ToListAsync();

            if (sharedDeviceIds.Any())
            {
                var sharedDevices = await _db.Devices
                    .Include(d => d.Zone)
                    .Where(d => sharedDeviceIds.Contains(d.Id) && !ownedDevices.Select(o => o.Id).Contains(d.Id))
                    .Select(d => new DeviceResponseDto(
                        d.Id,
                        d.OwnerId,
                        d.ZoneId,
                        d.Zone != null ? d.Zone.Name : null,
                        d.Name,
                        d.DeviceCode,
                        d.Description,
                        d.IsArmed,
                        d.NoiseThreshold,
                        d.MotionThreshold,
                        d.RegisteredAt,
                        d.LastSeenAt
                    ))
                    .ToListAsync();

                ownedDevices.AddRange(sharedDevices);
            }

            return Ok(ownedDevices);
        }

        [HttpGet("{id:guid}")]
        public async Task<IActionResult> GetDevice(Guid id)
        {
            var device = await _db.Devices
                .Include(d => d.Zone)
                .FirstOrDefaultAsync(d => d.Id == id && (IsAdmin || d.OwnerId == CurrentUserId ||
                    _db.MemberAccesses.Any(m => m.MemberUserId == CurrentUserId && (m.DeviceId == id || m.DeviceId == null))));

            if (device == null) return NotFound(new { message = "Không tìm thấy thiết bị." });

            return Ok(new DeviceResponseDto(
                device.Id,
                device.OwnerId,
                device.ZoneId,
                device.Zone?.Name,
                device.Name,
                device.DeviceCode,
                device.Description,
                device.IsArmed,
                device.NoiseThreshold,
                device.MotionThreshold,
                device.RegisteredAt,
                device.LastSeenAt
            ));
        }

        [HttpPost]
        public async Task<IActionResult> CreateDevice([FromBody] CreateDeviceDto dto)
        {
            var device = new GuardDevice
            {
                OwnerId = CurrentUserId,
                Name = dto.Name.Trim(),
                Description = dto.Description?.Trim() ?? string.Empty,
                ZoneId = dto.ZoneId,
                NoiseThreshold = dto.NoiseThreshold,
                MotionThreshold = dto.MotionThreshold,
                IsArmed = true
            };

            _db.Devices.Add(device);
            await _db.SaveChangesAsync();

            _logger.LogInformation("Thiết bị mới {DeviceName} ({DeviceCode}) đã đăng ký bởi User {UserId}", device.Name, device.DeviceCode, device.OwnerId);

            return CreatedAtAction(nameof(GetDevice), new { id = device.Id }, new DeviceResponseDto(
                device.Id,
                device.OwnerId,
                device.ZoneId,
                null,
                device.Name,
                device.DeviceCode,
                device.Description,
                device.IsArmed,
                device.NoiseThreshold,
                device.MotionThreshold,
                device.RegisteredAt,
                device.LastSeenAt
            ));
        }

        [HttpPut("{id:guid}")]
        public async Task<IActionResult> UpdateDevice(Guid id, [FromBody] UpdateDeviceDto dto)
        {
            var device = await _db.Devices.FirstOrDefaultAsync(d => d.Id == id && (IsAdmin || d.OwnerId == CurrentUserId));
            if (device == null) return NotFound(new { message = "Không tìm thấy thiết bị hoặc không có quyền." });

            if (!string.IsNullOrWhiteSpace(dto.Name)) device.Name = dto.Name.Trim();
            if (dto.Description != null) device.Description = dto.Description.Trim();
            if (dto.ZoneId.HasValue) device.ZoneId = dto.ZoneId.Value;
            if (dto.IsArmed.HasValue) device.IsArmed = dto.IsArmed.Value;
            if (dto.NoiseThreshold.HasValue) device.NoiseThreshold = dto.NoiseThreshold.Value;
            if (dto.MotionThreshold.HasValue) device.MotionThreshold = dto.MotionThreshold.Value;

            await _db.SaveChangesAsync();
            return Ok(new { message = "Cập nhật thiết bị thành công.", deviceId = device.Id });
        }

        [HttpPatch("{id:guid}/toggle-arm")]
        public async Task<IActionResult> ToggleArm(Guid id)
        {
            var device = await _db.Devices.FirstOrDefaultAsync(d => d.Id == id && (IsAdmin || d.OwnerId == CurrentUserId ||
                _db.MemberAccesses.Any(m => m.MemberUserId == CurrentUserId && m.CanAcknowledge)));

            if (device == null) return NotFound(new { message = "Không tìm thấy thiết bị." });

            device.IsArmed = !device.IsArmed;
            await _db.SaveChangesAsync();

            return Ok(new { isArmed = device.IsArmed, message = device.IsArmed ? "Đã bật chế độ cảnh giác!" : "Đã tắt cảnh giác." });
        }

        [HttpDelete("{id:guid}")]
        public async Task<IActionResult> DeleteDevice(Guid id)
        {
            var device = await _db.Devices.FirstOrDefaultAsync(d => d.Id == id && (IsAdmin || d.OwnerId == CurrentUserId));
            if (device == null) return NotFound(new { message = "Không tìm thấy thiết bị hoặc không có quyền." });

            _db.Devices.Remove(device);
            await _db.SaveChangesAsync();

            return Ok(new { message = "Đã xóa thiết bị thành công." });
        }

        [HttpPost("pair")]
        public async Task<IActionResult> PairDevice([FromBody] string deviceCode)
        {
            var code = deviceCode.Trim().ToUpper();
            var device = await _db.Devices.FirstOrDefaultAsync(d => d.DeviceCode == code);
            if (device == null) return NotFound(new { message = "Mã thiết bị không tồn tại." });

            device.LastSeenAt = DateTime.UtcNow;
            await _db.SaveChangesAsync();

            return Ok(new { message = "Ghép nối thiết bị thành công!", deviceId = device.Id, deviceName = device.Name });
        }
    }
}
