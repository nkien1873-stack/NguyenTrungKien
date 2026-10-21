using System.ComponentModel.DataAnnotations;
using System.ComponentModel.DataAnnotations.Schema;

namespace NguyenTrungKien.API.Models;

/// <summary>Các vai trò trong hệ thống.</summary>
public static class Roles
{
    public const string Admin = "Admin";     // Quản trị viên
    public const string Staff = "Staff";     // Nhân viên hỗ trợ
    public const string Parent = "Parent";   // Phụ huynh (khách hàng)
    public const string Child = "Child";     // Thiết bị của trẻ

    public static readonly string[] All = { Admin, Staff, Parent, Child };
}

/// <summary>Tài khoản đăng nhập (Admin, Nhân viên, Phụ huynh).</summary>
public class User
{
    public int Id { get; set; }

    [MaxLength(50)] public string Username { get; set; } = "";
    [MaxLength(120)] public string Email { get; set; } = "";
    [MaxLength(100)] public string FullName { get; set; } = "";
    [MaxLength(20)] public string? Phone { get; set; }
    public string PasswordHash { get; set; } = "";
    [MaxLength(20)] public string Role { get; set; } = Roles.Parent;

    public bool EmailConfirmed { get; set; }
    public bool IsLocked { get; set; }

    /// <summary>Mẫu khuôn mặt (vector đặc trưng dạng JSON) dùng cho đăng nhập khuôn mặt.</summary>
    public string? FaceTemplate { get; set; }

    public DateTime CreatedAt { get; set; } = DateTime.UtcNow;
    public DateTime? LastLoginAt { get; set; }

    public List<ChildProfile> Children { get; set; } = new();
}

/// <summary>Hồ sơ trẻ em do phụ huynh quản lý.</summary>
public class ChildProfile
{
    public int Id { get; set; }
    public int ParentId { get; set; }
    public User? Parent { get; set; }

    [MaxLength(100)] public string Name { get; set; } = "";
    public DateTime? BirthDate { get; set; }
    [MaxLength(20)] public string AvatarColor { get; set; } = "#4F7CFF";

    /// <summary>Số phút được dùng máy mỗi ngày (cơ bản).</summary>
    public int DailyLimitMinutes { get; set; } = 120;

    /// <summary>Ví thời gian: số phút thưởng còn lại (tính năng mới).</summary>
    public int BonusMinutes { get; set; }

    /// <summary>Giờ đi ngủ – sau giờ này máy bị khóa (định dạng HH:mm).</summary>
    [MaxLength(5)] public string BedTime { get; set; } = "21:30";

    public DateTime CreatedAt { get; set; } = DateTime.UtcNow;

    public List<Device> Devices { get; set; } = new();
    public List<SafeZone> SafeZones { get; set; } = new();
    public List<AppRule> AppRules { get; set; } = new();
    public List<RewardTask> Tasks { get; set; } = new();
}

/// <summary>Điện thoại của trẻ đã được ghép bằng mã QR.</summary>
public class Device
{
    public int Id { get; set; }
    public int ChildId { get; set; }
    public ChildProfile? Child { get; set; }

    [MaxLength(100)] public string DeviceName { get; set; } = "";
    [MaxLength(50)] public string Platform { get; set; } = "";
    public int? BatteryLevel { get; set; }
    public bool IsActive { get; set; } = true;
    public DateTime PairedAt { get; set; } = DateTime.UtcNow;
    public DateTime? LastSeenAt { get; set; }
}

/// <summary>Mã ghép thiết bị (hiển thị dưới dạng QR trên máy phụ huynh).</summary>
public class PairingCode
{
    public int Id { get; set; }
    public int ChildId { get; set; }
    [MaxLength(64)] public string Code { get; set; } = "";
    public DateTime ExpiresAt { get; set; }
    public bool Used { get; set; }
}

/// <summary>Lịch sử vị trí do máy trẻ gửi lên.</summary>
public class LocationLog
{
    public long Id { get; set; }
    public int ChildId { get; set; }
    public double Latitude { get; set; }
    public double Longitude { get; set; }
    public double? Accuracy { get; set; }
    public int? BatteryLevel { get; set; }
    public DateTime RecordedAt { get; set; } = DateTime.UtcNow;
}

/// <summary>Vùng an toàn (nhà, trường...). Ra khỏi vùng sẽ sinh cảnh báo.</summary>
public class SafeZone
{
    public int Id { get; set; }
    public int ChildId { get; set; }
    public ChildProfile? Child { get; set; }

    [MaxLength(100)] public string Name { get; set; } = "";
    public double Latitude { get; set; }
    public double Longitude { get; set; }
    public double RadiusMeters { get; set; } = 200;
    public bool IsActive { get; set; } = true;
}

/// <summary>Quy tắc cho từng ứng dụng trên máy trẻ.</summary>
public class AppRule
{
    public int Id { get; set; }
    public int ChildId { get; set; }
    public ChildProfile? Child { get; set; }

    [MaxLength(100)] public string AppName { get; set; } = "";
    [MaxLength(50)] public string Category { get; set; } = "Khác";
    /// <summary>0 = không giới hạn.</summary>
    public int DailyLimitMinutes { get; set; }
    public bool IsBlocked { get; set; }
}

/// <summary>Nhiệm vụ đổi thời gian (Ví thời gian).</summary>
public class RewardTask
{
    public int Id { get; set; }
    public int ChildId { get; set; }
    public ChildProfile? Child { get; set; }

    [MaxLength(150)] public string Title { get; set; } = "";
    [MaxLength(500)] public string? Description { get; set; }
    public int RewardMinutes { get; set; } = 15;
    public DateTime? DueDate { get; set; }

    /// <summary>Assigned | Submitted | Approved | Rejected</summary>
    [MaxLength(20)] public string Status { get; set; } = TaskStatuses.Assigned;
    public string? ProofImageUrl { get; set; }
    [MaxLength(500)] public string? ChildNote { get; set; }
    [MaxLength(500)] public string? ParentComment { get; set; }

    public DateTime CreatedAt { get; set; } = DateTime.UtcNow;
    public DateTime? SubmittedAt { get; set; }
    public DateTime? ReviewedAt { get; set; }
}

public static class TaskStatuses
{
    public const string Assigned = "Assigned";
    public const string Submitted = "Submitted";
    public const string Approved = "Approved";
    public const string Rejected = "Rejected";
}

/// <summary>Lịch sử cộng/trừ phút trong Ví thời gian.</summary>
public class WalletTransaction
{
    public int Id { get; set; }
    public int ChildId { get; set; }
    public int Minutes { get; set; }
    [MaxLength(200)] public string Reason { get; set; } = "";
    public DateTime CreatedAt { get; set; } = DateTime.UtcNow;
}

/// <summary>Cảnh báo gửi cho phụ huynh (SOS, rời vùng an toàn, pin yếu...).</summary>
public class Alert
{
    public int Id { get; set; }
    public int ChildId { get; set; }
    public ChildProfile? Child { get; set; }

    /// <summary>SOS | LeaveZone | LowBattery | TaskSubmitted | Info</summary>
    [MaxLength(30)] public string Type { get; set; } = "Info";
    [MaxLength(300)] public string Message { get; set; } = "";
    public double? Latitude { get; set; }
    public double? Longitude { get; set; }
    public bool IsRead { get; set; }
    public DateTime CreatedAt { get; set; } = DateTime.UtcNow;
}

/// <summary>Yêu cầu hỗ trợ của phụ huynh – nhân viên xử lý.</summary>
public class SupportTicket
{
    public int Id { get; set; }
    public int ParentId { get; set; }
    public User? Parent { get; set; }
    public int? AssignedStaffId { get; set; }
    public User? AssignedStaff { get; set; }

    [MaxLength(150)] public string Subject { get; set; } = "";
    [MaxLength(2000)] public string Content { get; set; } = "";
    [MaxLength(2000)] public string? StaffReply { get; set; }

    /// <summary>Open | InProgress | Resolved</summary>
    [MaxLength(20)] public string Status { get; set; } = "Open";
    [MaxLength(10)] public string Priority { get; set; } = "Normal";

    public DateTime CreatedAt { get; set; } = DateTime.UtcNow;
    public DateTime? UpdatedAt { get; set; }
}

/// <summary>Mã OTP gửi qua email (đăng ký / đăng nhập / quên mật khẩu).</summary>
public class OtpCode
{
    public int Id { get; set; }
    public int UserId { get; set; }
    /// <summary>Register | Login | ResetPassword</summary>
    [MaxLength(20)] public string Purpose { get; set; } = "";
    /// <summary>Lưu dạng băm SHA-256, không lưu mã gốc.</summary>
    [MaxLength(100)] public string CodeHash { get; set; } = "";
    public DateTime ExpiresAt { get; set; }
    public int Attempts { get; set; }
    public bool Used { get; set; }
    public DateTime CreatedAt { get; set; } = DateTime.UtcNow;
}
