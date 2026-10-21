using NguyenTrungKien.API.Data;
using NguyenTrungKien.API.DTOs;
using NguyenTrungKien.API.Models;
using NguyenTrungKien.API.Services;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using Microsoft.EntityFrameworkCore;

namespace NguyenTrungKien.API.Controllers;

public record RedeemRequest(int Minutes);

/// <summary>Các API dành cho điện thoại của trẻ (token vai trò Child sau khi quét QR).</summary>
[ApiController]
[Route("api/child")]
[Authorize(Roles = Roles.Child)]
public class ChildDeviceController : ControllerBase
{
    private const string RedeemReason = "Đổi phút sử dụng";

    private readonly AppDbContext _db;
    private readonly IWebHostEnvironment _env;

    public ChildDeviceController(AppDbContext db, IWebHostEnvironment env)
    {
        _db = db;
        _env = env;
    }

    /// <summary>Lấy hồ sơ trẻ và kiểm tra thiết bị còn được ghép (phụ huynh có thể gỡ).</summary>
    private async Task<ChildProfile?> Current()
    {
        var childId = User.ChildId();
        var deviceId = User.DeviceId();
        var device = await _db.Devices.FirstOrDefaultAsync(d => d.Id == deviceId && d.ChildId == childId && d.IsActive);
        if (device == null) return null;
        device.LastSeenAt = DateTime.UtcNow;
        return await _db.Children.Include(c => c.Parent).FirstOrDefaultAsync(c => c.Id == childId);
    }

    private IActionResult Revoked() => Unauthorized(new { message = "Thiết bị đã bị gỡ khỏi tài khoản phụ huynh.", revoked = true });

    [HttpGet("me")]
    public async Task<IActionResult> Me()
    {
        var c = await Current();
        if (c == null) return Revoked();
        await _db.SaveChangesAsync();

        var today = DateTime.UtcNow.Date;
        var redeemedToday = await _db.WalletTransactions
            .Where(t => t.ChildId == c.Id && t.CreatedAt >= today && t.Reason == RedeemReason)
            .SumAsync(t => (int?)-t.Minutes) ?? 0;

        var rules = await _db.AppRules.Where(r => r.ChildId == c.Id).OrderBy(r => r.AppName)
            .Select(r => new { r.Id, r.AppName, r.Category, r.DailyLimitMinutes, r.IsBlocked }).ToListAsync();

        return Ok(new
        {
            c.Id, c.Name, c.AvatarColor, c.BedTime, c.DailyLimitMinutes, c.BonusMinutes,
            parentName = c.Parent?.FullName,
            redeemedToday,
            todayAllowance = c.DailyLimitMinutes + redeemedToday,
            pendingTasks = await _db.RewardTasks.CountAsync(t => t.ChildId == c.Id && t.Status == TaskStatuses.Assigned),
            zoneCount = await _db.SafeZones.CountAsync(z => z.ChildId == c.Id && z.IsActive),
            rules
        });
    }

    /// <summary>Máy trẻ gửi vị trí định kỳ. Server tự sinh cảnh báo rời vùng an toàn / pin yếu.</summary>
    [HttpPost("location")]
    public async Task<IActionResult> ReportLocation(LocationReportRequest req)
    {
        var c = await Current();
        if (c == null) return Revoked();

        var prev = await _db.LocationLogs.Where(l => l.ChildId == c.Id)
            .OrderByDescending(l => l.RecordedAt).FirstOrDefaultAsync();

        _db.LocationLogs.Add(new LocationLog
        {
            ChildId = c.Id, Latitude = req.Latitude, Longitude = req.Longitude,
            Accuracy = req.Accuracy, BatteryLevel = req.BatteryLevel
        });

        var device = await _db.Devices.FindAsync(User.DeviceId());
        if (device != null && req.BatteryLevel.HasValue) device.BatteryLevel = req.BatteryLevel;

        // --- Kiểm tra vùng an toàn ---
        string? zoneStatus = null;
        var zones = await _db.SafeZones.Where(z => z.ChildId == c.Id && z.IsActive).ToListAsync();
        if (zones.Count > 0)
        {
            SafeZone? ZoneAt(double lat, double lng) =>
                zones.FirstOrDefault(z => Geo.DistanceMeters(lat, lng, z.Latitude, z.Longitude) <= z.RadiusMeters);

            var now = ZoneAt(req.Latitude, req.Longitude);
            var before = prev == null ? null : ZoneAt(prev.Latitude, prev.Longitude);
            zoneStatus = now?.Name;

            if (before != null && now == null)
            {
                _db.Alerts.Add(new Alert
                {
                    ChildId = c.Id, Type = "LeaveZone",
                    Message = $"{c.Name} đã rời khỏi vùng an toàn \"{before.Name}\".",
                    Latitude = req.Latitude, Longitude = req.Longitude
                });
            }
            else if (now != null && (before == null || before.Id != now.Id) && prev != null)
            {
                _db.Alerts.Add(new Alert
                {
                    ChildId = c.Id, Type = "Info",
                    Message = $"{c.Name} đã đến \"{now.Name}\".",
                    Latitude = req.Latitude, Longitude = req.Longitude
                });
            }
        }

        // --- Pin yếu ---
        if (req.BatteryLevel is <= 15 && (prev?.BatteryLevel == null || prev.BatteryLevel > 15))
        {
            _db.Alerts.Add(new Alert
            {
                ChildId = c.Id, Type = "LowBattery",
                Message = $"Pin điện thoại của {c.Name} còn {req.BatteryLevel}%.",
                Latitude = req.Latitude, Longitude = req.Longitude
            });
        }

        await _db.SaveChangesAsync();
        return Ok(new { message = "OK", insideZone = zoneStatus });
    }

    /// <summary>Nút khẩn cấp SOS.</summary>
    [HttpPost("sos")]
    public async Task<IActionResult> Sos(SosRequest req)
    {
        var c = await Current();
        if (c == null) return Revoked();
        _db.Alerts.Add(new Alert
        {
            ChildId = c.Id, Type = "SOS",
            Message = string.IsNullOrWhiteSpace(req.Message) ? $"{c.Name} vừa bấm nút SOS khẩn cấp!" : $"SOS từ {c.Name}: {req.Message}",
            Latitude = req.Latitude, Longitude = req.Longitude
        });
        if (req.Latitude.HasValue && req.Longitude.HasValue)
            _db.LocationLogs.Add(new LocationLog { ChildId = c.Id, Latitude = req.Latitude.Value, Longitude = req.Longitude.Value });
        await _db.SaveChangesAsync();
        return Ok(new { message = "Đã gửi tín hiệu SOS tới phụ huynh." });
    }

    // ---------- Ví thời gian (phía trẻ) ----------

    [HttpGet("tasks")]
    public async Task<IActionResult> Tasks()
    {
        var c = await Current();
        if (c == null) return Revoked();
        await _db.SaveChangesAsync();
        var list = await _db.RewardTasks.Where(t => t.ChildId == c.Id)
            .OrderBy(t => t.Status == TaskStatuses.Assigned ? 0 : t.Status == TaskStatuses.Rejected ? 1 : t.Status == TaskStatuses.Submitted ? 2 : 3)
            .ThenByDescending(t => t.CreatedAt)
            .Select(t => new
            {
                t.Id, t.Title, t.Description, t.RewardMinutes, t.DueDate, t.Status,
                t.ProofImageUrl, t.ChildNote, t.ParentComment, t.SubmittedAt, t.ReviewedAt
            }).ToListAsync();
        return Ok(list);
    }

    /// <summary>Trẻ gửi minh chứng hoàn thành (ảnh base64 + ghi chú).</summary>
    [HttpPost("tasks/{id:int}/submit")]
    [RequestSizeLimit(15_000_000)]
    public async Task<IActionResult> Submit(int id, SubmitTaskRequest req)
    {
        var c = await Current();
        if (c == null) return Revoked();
        var t = await _db.RewardTasks.FirstOrDefaultAsync(x => x.Id == id && x.ChildId == c.Id);
        if (t == null) return NotFound(new { message = "Không tìm thấy nhiệm vụ." });
        if (t.Status is not (TaskStatuses.Assigned or TaskStatuses.Rejected))
            return BadRequest(new { message = "Nhiệm vụ đã được gửi hoặc đã duyệt." });

        if (!string.IsNullOrWhiteSpace(req.ImageBase64))
        {
            byte[] bytes;
            try
            {
                var b64 = req.ImageBase64.Contains(',') ? req.ImageBase64[(req.ImageBase64.IndexOf(',') + 1)..] : req.ImageBase64;
                bytes = Convert.FromBase64String(b64);
            }
            catch (FormatException) { return BadRequest(new { message = "Ảnh không hợp lệ." }); }

            var root = _env.WebRootPath ?? Path.Combine(_env.ContentRootPath, "wwwroot");
            var dir = Path.Combine(root, "uploads");
            Directory.CreateDirectory(dir);
            var file = $"task_{t.Id}_{DateTime.UtcNow:yyyyMMddHHmmss}.jpg";
            await System.IO.File.WriteAllBytesAsync(Path.Combine(dir, file), bytes);
            t.ProofImageUrl = "/uploads/" + file;
        }

        t.ChildNote = req.Note;
        t.Status = TaskStatuses.Submitted;
        t.SubmittedAt = DateTime.UtcNow;
        _db.Alerts.Add(new Alert { ChildId = c.Id, Type = "TaskSubmitted", Message = $"{c.Name} đã gửi minh chứng: {t.Title}" });
        await _db.SaveChangesAsync();
        return Ok(new { message = "Đã gửi minh chứng, chờ bố mẹ duyệt nhé!" });
    }

    [HttpGet("wallet")]
    public async Task<IActionResult> Wallet()
    {
        var c = await Current();
        if (c == null) return Revoked();
        await _db.SaveChangesAsync();
        var tx = await _db.WalletTransactions.Where(t => t.ChildId == c.Id)
            .OrderByDescending(t => t.CreatedAt).Take(30)
            .Select(t => new { t.Id, t.Minutes, t.Reason, t.CreatedAt }).ToListAsync();
        return Ok(new { c.BonusMinutes, transactions = tx });
    }

    /// <summary>Trẻ dùng phút trong ví để tăng hạn mức hôm nay.</summary>
    [HttpPost("wallet/redeem")]
    public async Task<IActionResult> Redeem(RedeemRequest req)
    {
        var c = await Current();
        if (c == null) return Revoked();
        if (req.Minutes <= 0) return BadRequest(new { message = "Số phút không hợp lệ." });
        if (req.Minutes > c.BonusMinutes) return BadRequest(new { message = "Ví không đủ phút." });

        c.BonusMinutes -= req.Minutes;
        _db.WalletTransactions.Add(new WalletTransaction { ChildId = c.Id, Minutes = -req.Minutes, Reason = RedeemReason });
        _db.Alerts.Add(new Alert { ChildId = c.Id, Type = "Info", Message = $"{c.Name} đã dùng {req.Minutes} phút từ ví thời gian." });
        await _db.SaveChangesAsync();
        return Ok(new { message = $"Đã thêm {req.Minutes} phút cho hôm nay!", c.BonusMinutes });
    }
}
