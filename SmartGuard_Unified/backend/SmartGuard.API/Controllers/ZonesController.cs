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
    public class ZonesController : ControllerBase
    {
        private readonly SmartGuardDbContext _db;

        public ZonesController(SmartGuardDbContext db)
        {
            _db = db;
        }

        private Guid CurrentUserId => Guid.Parse(User.FindFirstValue(ClaimTypes.NameIdentifier)!);
        private bool IsAdmin => User.IsInRole("Admin");

        [HttpGet]
        public async Task<IActionResult> GetZones()
        {
            var userId = CurrentUserId;
            var zones = await _db.Zones
                .Where(z => IsAdmin || z.OwnerId == userId)
                .Select(z => new ZoneResponseDto(
                    z.Id,
                    z.Name,
                    z.Description,
                    z.Devices != null ? z.Devices.Count : 0
                ))
                .ToListAsync();

            return Ok(zones);
        }

        [HttpPost]
        public async Task<IActionResult> CreateZone([FromBody] CreateZoneDto dto)
        {
            var zone = new Zone
            {
                OwnerId = CurrentUserId,
                Name = dto.Name.Trim(),
                Description = dto.Description?.Trim() ?? string.Empty
            };

            _db.Zones.Add(zone);
            await _db.SaveChangesAsync();

            return Ok(new ZoneResponseDto(zone.Id, zone.Name, zone.Description, 0));
        }

        [HttpPut("{id:guid}")]
        public async Task<IActionResult> UpdateZone(Guid id, [FromBody] UpdateZoneDto dto)
        {
            var zone = await _db.Zones.FirstOrDefaultAsync(z => z.Id == id && (IsAdmin || z.OwnerId == CurrentUserId));
            if (zone == null) return NotFound(new { message = "Không tìm thấy khu vực." });

            zone.Name = dto.Name.Trim();
            zone.Description = dto.Description?.Trim() ?? string.Empty;

            await _db.SaveChangesAsync();
            return Ok(new { message = "Cập nhật khu vực thành công." });
        }

        [HttpDelete("{id:guid}")]
        public async Task<IActionResult> DeleteZone(Guid id)
        {
            var zone = await _db.Zones.FirstOrDefaultAsync(z => z.Id == id && (IsAdmin || z.OwnerId == CurrentUserId));
            if (zone == null) return NotFound(new { message = "Không tìm thấy khu vực." });

            // Gỡ bỏ liên kết ZoneId của các thiết bị thuộc Zone này
            var devices = await _db.Devices.Where(d => d.ZoneId == id).ToListAsync();
            foreach (var d in devices) d.ZoneId = null;

            _db.Zones.Remove(zone);
            await _db.SaveChangesAsync();

            return Ok(new { message = "Đã xóa khu vực thành công." });
        }
    }
}
