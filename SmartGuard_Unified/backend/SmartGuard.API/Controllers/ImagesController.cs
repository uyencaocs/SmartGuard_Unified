using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using Microsoft.EntityFrameworkCore;
using SmartGuard.API.Data;
using SmartGuard.API.Models;

namespace SmartGuard.API.Controllers
{
    public class UploadImageDto
    {
        public IFormFile File { get; set; } = null!;
        public Guid DeviceId { get; set; }
        public Guid? AlertId { get; set; }
    }

    [ApiController]
    [Route("api/[controller]")]
    public class ImagesController : ControllerBase
    {
        private readonly SmartGuardDbContext _db;
        private readonly IWebHostEnvironment _env;
        private readonly ILogger<ImagesController> _logger;

        public ImagesController(
            SmartGuardDbContext db,
            IWebHostEnvironment env,
            ILogger<ImagesController> logger)
        {
            _db = db;
            _env = env;
            _logger = logger;
        }

        [HttpPost("upload")]
        [Authorize]
        [Consumes("multipart/form-data")]
        [RequestSizeLimit(15 * 1024 * 1024)] // 15MB limit
        public async Task<IActionResult> UploadImage([FromForm] UploadImageDto dto)
        {
            if (dto.File == null || dto.File.Length == 0)
                return BadRequest(new { message = "Không tìm thấy file ảnh tải lên." });

            var ext = Path.GetExtension(dto.File.FileName).ToLowerInvariant();
            if (ext != ".jpg" && ext != ".jpeg" && ext != ".png")
                return BadRequest(new { message = "Định dạng file không hợp lệ. Chỉ chấp nhận JPG/PNG." });

            var webRoot = _env.WebRootPath ?? Path.Combine(_env.ContentRootPath, "wwwroot");
            var evidenceDir = Path.Combine(webRoot, "evidence");
            if (!Directory.Exists(evidenceDir)) Directory.CreateDirectory(evidenceDir);

            var uniqueFileName = $"{Guid.NewGuid():N}_{DateTime.UtcNow:yyyyMMdd_HHmmss}{ext}";
            var fullPath = Path.Combine(evidenceDir, uniqueFileName);

            using (var stream = new FileStream(fullPath, FileMode.Create))
            {
                await dto.File.CopyToAsync(stream);
            }

            var relativeUrl = $"/evidence/{uniqueFileName}";

            var evidence = new EvidenceImage
            {
                DeviceId = dto.DeviceId,
                AlertEventId = dto.AlertId,
                FileName = uniqueFileName,
                RelativeUrl = relativeUrl,
                UploadedAt = DateTime.UtcNow
            };

            _db.EvidenceImages.Add(evidence);

            // Cập nhật URL ảnh vào AlertEvent nếu có
            if (dto.AlertId.HasValue)
            {
                var alert = await _db.AlertEvents.FindAsync(dto.AlertId.Value);
                if (alert != null)
                {
                    alert.ImageUrl = relativeUrl;
                }
            }

            await _db.SaveChangesAsync();

            _logger.LogInformation("Đã lưu ảnh bằng chứng {FileName} cho thiết bị {DeviceId}", uniqueFileName, dto.DeviceId);

            return Ok(new
            {
                message = "Tải ảnh bằng chứng thành công!",
                imageId = evidence.Id,
                imageUrl = relativeUrl
            });
        }

        [HttpGet("list")]
        [Authorize]
        public async Task<IActionResult> GetEvidenceList([FromQuery] int limit = 30)
        {
            var list = await _db.EvidenceImages
                .OrderByDescending(e => e.UploadedAt)
                .Take(Math.Clamp(limit, 1, 100))
                .Select(e => new
                {
                    e.Id,
                    e.DeviceId,
                    e.AlertEventId,
                    e.FileName,
                    e.RelativeUrl,
                    e.UploadedAt
                })
                .ToListAsync();

            return Ok(list);
        }

        [HttpDelete("{id:guid}")]
        [Authorize]
        public async Task<IActionResult> DeleteImage(Guid id)
        {
            var evidence = await _db.EvidenceImages.FindAsync(id);
            if (evidence == null) return NotFound(new { message = "Không tìm thấy ảnh này." });

            try
            {
                var webRoot = _env.WebRootPath ?? Path.Combine(_env.ContentRootPath, "wwwroot");
                var fullPath = Path.Combine(webRoot, "evidence", evidence.FileName);
                if (System.IO.File.Exists(fullPath))
                {
                    System.IO.File.Delete(fullPath);
                }
            }
            catch { }

            _db.EvidenceImages.Remove(evidence);
            await _db.SaveChangesAsync();

            return Ok(new { message = "Đã xóa hình ảnh thành công.", imageId = id });
        }
    }
}
