using System.ComponentModel.DataAnnotations;
using System.ComponentModel.DataAnnotations.Schema;

namespace SmartGuard.API.Models
{
    public class User
    {
        [Key]
        public Guid Id { get; set; } = Guid.NewGuid();

        [Required, MaxLength(100)]
        public string Email { get; set; } = string.Empty;

        [Required, MaxLength(50)]
        public string Username { get; set; } = string.Empty;

        [Required]
        public string PasswordHash { get; set; } = string.Empty;

        [Required, MaxLength(20)]
        public string Role { get; set; } = "Owner"; // Admin | Owner | Member

        public bool EmailVerified { get; set; } = true;

        public bool IsLocked { get; set; } = false;

        public DateTime CreatedAt { get; set; } = DateTime.UtcNow;

        public ICollection<GuardDevice>? Devices { get; set; }
        public ICollection<Zone>? Zones { get; set; }
    }

    public class OtpChallenge
    {
        [Key]
        public Guid Id { get; set; } = Guid.NewGuid();

        public Guid UserId { get; set; }

        [Required, MaxLength(30)]
        public string Purpose { get; set; } = "Login"; // Login | VerifyEmail

        [Required]
        public string CodeHash { get; set; } = string.Empty;

        public int Attempts { get; set; } = 0;

        public DateTime ExpiresAt { get; set; }

        public DateTime? UsedAt { get; set; }
    }

    public class Zone
    {
        [Key]
        public Guid Id { get; set; } = Guid.NewGuid();

        [Required]
        public Guid OwnerId { get; set; }

        [Required, MaxLength(100)]
        public string Name { get; set; } = string.Empty;

        [MaxLength(255)]
        public string Description { get; set; } = string.Empty;

        [ForeignKey("OwnerId")]
        public User? Owner { get; set; }

        public ICollection<GuardDevice>? Devices { get; set; }
    }

    public class GuardDevice
    {
        [Key]
        public Guid Id { get; set; } = Guid.NewGuid();

        [Required]
        public Guid OwnerId { get; set; }

        public Guid? ZoneId { get; set; }

        [Required, MaxLength(100)]
        public string Name { get; set; } = string.Empty;

        [MaxLength(50)]
        public string DeviceCode { get; set; } = Guid.NewGuid().ToString("N")[..8].ToUpper();

        [MaxLength(255)]
        public string Description { get; set; } = string.Empty;

        public bool IsArmed { get; set; } = true;

        public double NoiseThreshold { get; set; } = 70.0;

        public double MotionThreshold { get; set; } = 3.5;

        public DateTime RegisteredAt { get; set; } = DateTime.UtcNow;

        public DateTime LastSeenAt { get; set; } = DateTime.UtcNow;

        [ForeignKey("OwnerId")]
        public User? Owner { get; set; }

        [ForeignKey("ZoneId")]
        public Zone? Zone { get; set; }

        public ICollection<AlertEvent>? AlertEvents { get; set; }
    }

    public class MemberAccess
    {
        [Key]
        public Guid Id { get; set; } = Guid.NewGuid();

        [Required]
        public Guid OwnerId { get; set; }

        [Required]
        public Guid MemberUserId { get; set; }

        public Guid? DeviceId { get; set; } // null => toàn quyền các thiết bị của Owner

        public bool CanAcknowledge { get; set; } = true;

        public DateTime CreatedAt { get; set; } = DateTime.UtcNow;

        [ForeignKey("MemberUserId")]
        public User? MemberUser { get; set; }

        [ForeignKey("DeviceId")]
        public GuardDevice? Device { get; set; }
    }

    public class AlertEvent
    {
        [Key]
        public Guid Id { get; set; } = Guid.NewGuid();

        [Required]
        public Guid DeviceId { get; set; }

        [Required, MaxLength(50)]
        public string TriggerReason { get; set; } = "CHUYEN_DONG"; // RUNG_LAC | TIENG_DONG | NGUOI_LA | CANH_BAO_THU_CONG

        public double TriggerScore { get; set; } = 0.0;

        [MaxLength(20)]
        public string Severity { get; set; } = "Warning"; // Info | Warning | Critical

        public DateTime TriggeredAt { get; set; } = DateTime.UtcNow;

        public string? ImageUrl { get; set; }

        public string? DiscordMessageId { get; set; }

        public Guid? AcknowledgedBy { get; set; }

        public DateTime? AcknowledgedAt { get; set; }

        [MaxLength(100)]
        public string Status { get; set; } = "Triggered"; // Triggered | Dismissed | Confirmed

        [MaxLength(255)]
        public string? AdaptiveReason { get; set; }

        [ForeignKey("DeviceId")]
        public GuardDevice? Device { get; set; }
    }

    public class EvidenceImage
    {
        [Key]
        public Guid Id { get; set; } = Guid.NewGuid();

        public Guid? AlertEventId { get; set; }

        public Guid DeviceId { get; set; }

        [Required, MaxLength(255)]
        public string FileName { get; set; } = string.Empty;

        [Required, MaxLength(500)]
        public string RelativeUrl { get; set; } = string.Empty;

        public DateTime UploadedAt { get; set; } = DateTime.UtcNow;

        [ForeignKey("AlertEventId")]
        public AlertEvent? AlertEvent { get; set; }
    }

    // Smart Adaptive Security Models (Giai đoạn 3)
    public class AdaptiveProfile
    {
        [Key]
        public Guid Id { get; set; } = Guid.NewGuid();

        [Required]
        public Guid UserId { get; set; }

        [Required, MaxLength(50)]
        public string ModeName { get; set; } = "Home"; // Home | Away | Night | Custom

        [Required, MaxLength(100)]
        public string DisplayName { get; set; } = "Ở nhà";

        [MaxLength(255)]
        public string Description { get; set; } = "Giảm cảnh báo tại các khu vực sinh hoạt, chỉ canh gác cổng/sân ngoài.";

        public bool IsActive { get; set; } = false;

        [MaxLength(5)]
        public string ActiveFrom { get; set; } = "00:00";

        [MaxLength(5)]
        public string ActiveTo { get; set; } = "23:59";

        [MaxLength(50)]
        public string BehaviorOnDisconnect { get; set; } = "AlertOffline"; // AlertOffline | MaintainState | FailSecure

        public DateTime? SnoozeUntil { get; set; } // Tạm dừng cảnh báo đến thời điểm này

        public ICollection<AdaptiveZoneRule>? ZoneRules { get; set; }
    }

    public class AdaptiveZoneRule
    {
        [Key]
        public Guid Id { get; set; } = Guid.NewGuid();

        [Required]
        public Guid ProfileId { get; set; }

        [Required]
        public Guid ZoneId { get; set; }

        public bool EnableMonitoring { get; set; } = true; // Cho phép bật/tắt giám sát theo phân vùng

        public bool EnableAlarmSound { get; set; } = true;

        public bool EnableDiscordNotification { get; set; } = true;

        public double CustomSensitivity { get; set; } = 1.0; // Hệ số nhân: 0.5 (giảm) .. 2.0 (tăng nhạy)

        [ForeignKey("ProfileId")]
        public AdaptiveProfile? Profile { get; set; }

        [ForeignKey("ZoneId")]
        public Zone? Zone { get; set; }
    }
}
