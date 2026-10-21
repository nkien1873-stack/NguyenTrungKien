using System.ComponentModel.DataAnnotations;

namespace NguyenTrungKien.API.DTOs;

// ===================== AUTH =====================
public record RegisterRequest(
    [Required, StringLength(50, MinimumLength = 4), RegularExpression("^[a-zA-Z0-9_.]+$", ErrorMessage = "Tên đăng nhập chỉ gồm chữ, số, dấu _ và .")] string Username,
    [Required, EmailAddress] string Email,
    [Required, StringLength(100, MinimumLength = 6)] string Password,
    [Required, StringLength(100)] string FullName,
    string? Phone);

public record VerifyEmailRequest([Required, EmailAddress] string Email, [Required] string Code);
public record ResendOtpRequest([Required] string Login, [Required] string Purpose);
public record LoginRequest([Required] string Username, [Required] string Password);
public record VerifyLoginOtpRequest([Required] string Username, [Required] string Code);
public record ForgotPasswordRequest([Required, EmailAddress] string Email);
public record ResetPasswordRequest([Required, EmailAddress] string Email, [Required] string Code, [Required, StringLength(100, MinimumLength = 6)] string NewPassword);
public record ChangePasswordRequest([Required] string OldPassword, [Required, StringLength(100, MinimumLength = 6)] string NewPassword);
public record UpdateProfileRequest([Required, StringLength(100)] string FullName, string? Phone);

public record FaceEnrollRequest([Required, MinLength(1)] List<double[]> Samples);
/// <summary>Username để trống -> server tự tìm tài khoản có khuôn mặt khớp nhất.</summary>
public record FaceLoginRequest(string? Username, [Required] double[] Features);

public record OtpStepResponse(bool RequiresOtp, string MaskedEmail, string Message, string? DevOtp);

public record AuthResponse(
    string Token, string Role, int UserId, string Username, string FullName, string Email, bool HasFace);

public record PairChildRequest([Required] string Code, string? DeviceName, string? Platform);
public record ChildAuthResponse(string Token, string Role, int ChildId, string ChildName, string ParentName);

// ===================== ADMIN =====================
public record AdminCreateUserRequest(
    [Required, StringLength(50, MinimumLength = 4)] string Username,
    [Required, EmailAddress] string Email,
    [Required, StringLength(100)] string FullName,
    string? Phone,
    [Required, StringLength(100, MinimumLength = 6)] string Password,
    [Required] string Role);

public record AdminUpdateUserRequest(
    [Required, StringLength(100)] string FullName,
    [Required, EmailAddress] string Email,
    string? Phone,
    [Required] string Role,
    bool IsLocked,
    bool EmailConfirmed,
    string? NewPassword);

// ===================== PHỤ HUYNH =====================
public record ChildUpsertRequest(
    [Required, StringLength(100)] string Name,
    DateTime? BirthDate,
    string? AvatarColor,
    [Range(0, 1440)] int DailyLimitMinutes,
    [RegularExpression("^([01]\\d|2[0-3]):[0-5]\\d$", ErrorMessage = "Giờ ngủ dạng HH:mm")] string? BedTime);

public record SafeZoneUpsertRequest(
    [Required, StringLength(100)] string Name,
    [Range(-90, 90)] double Latitude,
    [Range(-180, 180)] double Longitude,
    [Range(50, 5000)] double RadiusMeters,
    bool IsActive = true);

public record AppRuleUpsertRequest(
    [Required, StringLength(100)] string AppName,
    string? Category,
    [Range(0, 1440)] int DailyLimitMinutes,
    bool IsBlocked);

public record TaskUpsertRequest(
    int ChildId,
    [Required, StringLength(150)] string Title,
    string? Description,
    [Range(1, 240)] int RewardMinutes,
    DateTime? DueDate);

public record ReviewTaskRequest(bool Approve, string? Comment);
public record AdjustWalletRequest(int Minutes, [Required] string Reason);

// ===================== TRẺ EM =====================
public record LocationReportRequest(
    [Range(-90, 90)] double Latitude,
    [Range(-180, 180)] double Longitude,
    double? Accuracy,
    int? BatteryLevel);

public record SosRequest(double? Latitude, double? Longitude, string? Message);
public record SubmitTaskRequest(string? Note, string? ImageBase64);

// ===================== HỖ TRỢ =====================
public record TicketCreateRequest([Required, StringLength(150)] string Subject, [Required, StringLength(2000)] string Content, string? Priority);
public record TicketStaffUpdateRequest(string? Reply, [Required] string Status);
