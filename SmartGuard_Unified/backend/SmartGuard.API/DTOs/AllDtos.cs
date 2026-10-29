using System.ComponentModel.DataAnnotations;

namespace SmartGuard.API.DTOs
{
    // --- Auth DTOs ---
    public record RegisterDto(
        [Required, EmailAddress] string Email,
        [Required, MinLength(3)] string Username,
        [Required, MinLength(6)] string Password,
        string Role = "Owner"
    );

    public record LoginDto(
        [Required] string Identifier, // Email or Username
        [Required] string Password
    );

    public record VerifyOtpDto(
        [Required] Guid ChallengeId,
        [Required, StringLength(6, MinimumLength = 6)] string Code
    );

    public record AuthResponseDto(
        string Token,
        Guid UserId,
        string Email,
        string Username,
        string Role,
        DateTime ExpiresAt
    );

    public record UserProfileDto(
        Guid Id,
        string Email,
        string Username,
        string Role,
        bool IsLocked,
        DateTime CreatedAt
    );

    // --- Device DTOs ---
    public record CreateDeviceDto(
        [Required] string Name,
        string? Description,
        Guid? ZoneId,
        double NoiseThreshold = 70.0,
        double MotionThreshold = 3.5
    );

    public record UpdateDeviceDto(
        string? Name,
        string? Description,
        Guid? ZoneId,
        bool? IsArmed,
        double? NoiseThreshold,
        double? MotionThreshold
    );

    public record DeviceResponseDto(
        Guid Id,
        Guid OwnerId,
        Guid? ZoneId,
        string? ZoneName,
        string Name,
        string DeviceCode,
        string Description,
        bool IsArmed,
        double NoiseThreshold,
        double MotionThreshold,
        DateTime RegisteredAt,
        DateTime LastSeenAt
    );

    // --- Zone DTOs ---
    public record CreateZoneDto(
        [Required] string Name,
        string? Description
    );

    public record UpdateZoneDto(
        [Required] string Name,
        string? Description
    );

    public record ZoneResponseDto(
        Guid Id,
        string Name,
        string Description,
        int DeviceCount
    );

    // --- Member Access DTOs ---
    public record ShareAccessDto(
        [Required, EmailAddress] string MemberEmail,
        Guid? DeviceId,
        bool CanAcknowledge = true
    );

    public record MemberAccessResponseDto(
        Guid Id,
        Guid MemberUserId,
        string MemberEmail,
        string MemberUsername,
        Guid? DeviceId,
        string? DeviceName,
        bool CanAcknowledge,
        DateTime CreatedAt
    );

    // --- Alert DTOs ---
    public record TriggerAlertDto(
        [Required] Guid DeviceId,
        [Required] string TriggerReason, // CHUYEN_DONG | TIENG_DONG | NGUOI_LA | CANH_BAO_THU_CONG
        double TriggerScore,
        string Severity = "Warning",
        string? ImageUrl = null
    );

    public record AlertResponseDto(
        Guid Id,
        Guid DeviceId,
        string DeviceName,
        string? ZoneName,
        string TriggerReason,
        double TriggerScore,
        string Severity,
        string Status,
        string? ImageUrl,
        DateTime TriggeredAt,
        DateTime? AcknowledgedAt,
        string? AdaptiveReason = null
    );

    public record AcknowledgeAlertDto(
        [Required] string Action // Acknowledge | Dismiss | SoundAlarm
    );

    // --- Admin DTOs ---
    public record AdminStatsDto(
        int TotalUsers,
        int TotalDevices,
        int TotalAlertsToday,
        int ActiveArmedDevices
    );

    public record UpdateUserStatusDto(
        string? Role,
        bool? IsLocked
    );

    public record CreateUserAdminDto(
        [Required, EmailAddress] string Email,
        [Required, MinLength(3)] string Username,
        [Required, MinLength(6)] string Password,
        string Role = "Owner"
    );

    public record UpdateUserAdminDto(
        string? Email,
        string? Username,
        string? Role,
        string? Password,
        bool? IsLocked
    );

    // --- Smart Adaptive Security DTOs (Giai đoạn 3) ---
    public record AdaptiveZoneRuleDto(
        Guid Id,
        Guid ZoneId,
        string ZoneName,
        bool EnableMonitoring,
        bool EnableAlarmSound,
        bool EnableDiscordNotification,
        double CustomSensitivity
    );

    public record AdaptiveProfileDto(
        Guid Id,
        string ModeName,
        string DisplayName,
        string Description,
        bool IsActive,
        string ActiveFrom,
        string ActiveTo,
        string BehaviorOnDisconnect,
        DateTime? SnoozeUntil,
        bool IsSnoozed,
        List<AdaptiveZoneRuleDto> ZoneRules
    );

    public record UpdateAdaptiveRuleDto(
        Guid ZoneId,
        bool EnableMonitoring,
        bool EnableAlarmSound,
        bool EnableDiscordNotification,
        double CustomSensitivity
    );

    public record UpdateAdaptiveProfileDto(
        string? DisplayName,
        string? Description,
        string? ActiveFrom,
        string? ActiveTo,
        string? BehaviorOnDisconnect,
        List<UpdateAdaptiveRuleDto>? ZoneRules
    );

    public record SnoozeProfileDto(
        [Range(1, 1440)] int Minutes = 30
    );
}
