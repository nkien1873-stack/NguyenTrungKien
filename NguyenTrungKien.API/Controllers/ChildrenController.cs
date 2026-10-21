using System.Security.Cryptography;
using NguyenTrungKien.API.Data;
using NguyenTrungKien.API.DTOs;
using NguyenTrungKien.API.Models;
using NguyenTrungKien.API.Services;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using Microsoft.EntityFrameworkCore;

namespace NguyenTrungKien.API.Controllers;

/// <summary>Phụ huynh quản lý hồ sơ trẻ, thiết bị, vị trí, ví thời gian.</summary>
[ApiController]
[Route("api/children")]
[Authorize(Roles = Roles.Parent)]
public class ChildrenController : ControllerBase
{
    private readonly AppDbContext _db;
    public ChildrenController(AppDbContext db) => _db = db;

    private Task<ChildProfile?> Owned(int id)
    {
        var uid = User.UserId();
        return _db.Children.FirstOrDefaultAsync(c => c.Id == id && c.ParentId == uid);
    }

    // ---------- CRUD hồ sơ trẻ ----------

    [HttpGet]
    public async Task<IActionResult> GetAll()
    {
        var uid = User.UserId();
        var today = DateTime.UtcNow.Date;
        var list = await _db.Children.Where(c => c.ParentId == uid).OrderBy(c => c.Name).Select(c => new
        {
            c.Id, c.Name, c.BirthDate, c.AvatarColor, c.DailyLimitMinutes, c.BonusMinutes, c.BedTime,
            deviceCount = c.Devices.Count(d => d.IsActive),
            zoneCount = c.SafeZones.Count,
            pendingTasks = c.Tasks.Count(t => t.Status == TaskStatuses.Submitted),
            unreadAlerts = _db.Alerts.Count(a => a.ChildId == c.Id && !a.IsRead),
            lastLocation = _db.LocationLogs.Where(l => l.ChildId == c.Id)
                .OrderByDescending(l => l.RecordedAt)
                .Select(l => new { l.Latitude, l.Longitude, l.BatteryLevel, l.RecordedAt })
                .FirstOrDefault()
        }).ToListAsync();
        return Ok(list);
    }

    [HttpGet("{id:int}")]
    public async Task<IActionResult> Get(int id)
    {
        var uid = User.UserId();
        var c = await _db.Children
            .Include(x => x.Devices).Include(x => x.SafeZones).Include(x => x.AppRules)
            .FirstOrDefaultAsync(x => x.Id == id && x.ParentId == uid);
        if (c == null) return NotFound(new { message = "Không tìm thấy hồ sơ." });
        return Ok(new
        {
            c.Id, c.Name, c.BirthDate, c.AvatarColor, c.DailyLimitMinutes, c.BonusMinutes, c.BedTime,
            devices = c.Devices.OrderByDescending(d => d.PairedAt).Select(d => new { d.Id, d.DeviceName, d.Platform, d.BatteryLevel, d.IsActive, d.PairedAt, d.LastSeenAt }),
            safeZones = c.SafeZones.Select(z => new { z.Id, z.Name, z.Latitude, z.Longitude, z.RadiusMeters, z.IsActive }),
            appRules = c.AppRules.OrderBy(r => r.AppName).Select(r => new { r.Id, r.AppName, r.Category, r.DailyLimitMinutes, r.IsBlocked })
        });
    }

    [HttpPost]
    public async Task<IActionResult> Create(ChildUpsertRequest req)
    {
        var c = new ChildProfile
        {
            ParentId = User.UserId(),
            Name = req.Name.Trim(),
            BirthDate = req.BirthDate,
            AvatarColor = string.IsNullOrWhiteSpace(req.AvatarColor) ? "#4F7CFF" : req.AvatarColor!,
            DailyLimitMinutes = req.DailyLimitMinutes,
            BedTime = string.IsNullOrWhiteSpace(req.BedTime) ? "21:30" : req.BedTime!
        };
        _db.Children.Add(c);
        await _db.SaveChangesAsync();
        return Ok(new { message = "Đã thêm hồ sơ trẻ.", id = c.Id });
    }

    [HttpPut("{id:int}")]
    public async Task<IActionResult> Update(int id, ChildUpsertRequest req)
    {
        var c = await Owned(id);
        if (c == null) return NotFound(new { message = "Không tìm thấy hồ sơ." });
        c.Name = req.Name.Trim();
        c.BirthDate = req.BirthDate;
        if (!string.IsNullOrWhiteSpace(req.AvatarColor)) c.AvatarColor = req.AvatarColor!;
        c.DailyLimitMinutes = req.DailyLimitMinutes;
        if (!string.IsNullOrWhiteSpace(req.BedTime)) c.BedTime = req.BedTime!;
        await _db.SaveChangesAsync();
        return Ok(new { message = "Đã cập nhật hồ sơ." });
    }

    [HttpDelete("{id:int}")]
    public async Task<IActionResult> Delete(int id)
    {
        var c = await Owned(id);
        if (c == null) return NotFound(new { message = "Không tìm thấy hồ sơ." });
        _db.Children.Remove(c);
        await _db.SaveChangesAsync();
        return Ok(new { message = "Đã xóa hồ sơ trẻ." });
    }

    // ---------- Ghép thiết bị bằng QR ----------

    /// <summary>Tạo mã ghép (hiển thị thành QR) có hiệu lực 10 phút.</summary>
    [HttpPost("{id:int}/pairing-code")]
    public async Task<IActionResult> CreatePairingCode(int id)
    {
        var c = await Owned(id);
        if (c == null) return NotFound(new { message = "Không tìm thấy hồ sơ." });

        var code = Convert.ToHexString(RandomNumberGenerator.GetBytes(12));
        var expires = DateTime.UtcNow.AddMinutes(10);
        _db.PairingCodes.Add(new PairingCode { ChildId = id, Code = code, ExpiresAt = expires });
        await _db.SaveChangesAsync();
        return Ok(new { code, qrData = "KIDGUARD:" + code, expiresAt = expires });
    }

    [HttpDelete("{id:int}/devices/{deviceId:int}")]
    public async Task<IActionResult> RemoveDevice(int id, int deviceId)
    {
        if (await Owned(id) == null) return NotFound(new { message = "Không tìm thấy hồ sơ." });
        var d = await _db.Devices.FirstOrDefaultAsync(x => x.Id == deviceId && x.ChildId == id);
        if (d == null) return NotFound(new { message = "Không tìm thấy thiết bị." });
        _db.Devices.Remove(d);
        await _db.SaveChangesAsync();
        return Ok(new { message = "Đã gỡ thiết bị." });
    }

    // ---------- Vị trí ----------

    [HttpGet("{id:int}/locations")]
    public async Task<IActionResult> Locations(int id, [FromQuery] int hours = 24)
    {
        if (await Owned(id) == null) return NotFound(new { message = "Không tìm thấy hồ sơ." });
        var from = DateTime.UtcNow.AddHours(-Math.Clamp(hours, 1, 168));
        var logs = await _db.LocationLogs.Where(l => l.ChildId == id && l.RecordedAt >= from)
            .OrderByDescending(l => l.RecordedAt).Take(300)
            .Select(l => new { l.Latitude, l.Longitude, l.Accuracy, l.BatteryLevel, l.RecordedAt })
            .ToListAsync();
        return Ok(logs);
    }

    /// <summary>Vị trí mới nhất của tất cả các con – dùng cho màn hình bản đồ.</summary>
    [HttpGet("locations/latest")]
    public async Task<IActionResult> LatestAll()
    {
        var uid = User.UserId();
        var data = await _db.Children.Where(c => c.ParentId == uid).Select(c => new
        {
            childId = c.Id, c.Name, c.AvatarColor,
            zones = c.SafeZones.Where(z => z.IsActive).Select(z => new { z.Id, z.Name, z.Latitude, z.Longitude, z.RadiusMeters }),
            last = _db.LocationLogs.Where(l => l.ChildId == c.Id).OrderByDescending(l => l.RecordedAt)
                .Select(l => new { l.Latitude, l.Longitude, l.BatteryLevel, l.RecordedAt }).FirstOrDefault()
        }).ToListAsync();
        return Ok(data);
    }

    // ---------- Ví thời gian ----------

    [HttpGet("{id:int}/wallet")]
    public async Task<IActionResult> Wallet(int id)
    {
        var c = await Owned(id);
        if (c == null) return NotFound(new { message = "Không tìm thấy hồ sơ." });
        var tx = await _db.WalletTransactions.Where(t => t.ChildId == id)
            .OrderByDescending(t => t.CreatedAt).Take(50)
            .Select(t => new { t.Id, t.Minutes, t.Reason, t.CreatedAt }).ToListAsync();
        return Ok(new { c.BonusMinutes, c.DailyLimitMinutes, transactions = tx });
    }

    /// <summary>Phụ huynh cộng/trừ phút thủ công (ví dụ phạt khi vi phạm giờ ngủ).</summary>
    [HttpPost("{id:int}/wallet/adjust")]
    public async Task<IActionResult> AdjustWallet(int id, AdjustWalletRequest req)
    {
        var c = await Owned(id);
        if (c == null) return NotFound(new { message = "Không tìm thấy hồ sơ." });
        if (req.Minutes == 0 || Math.Abs(req.Minutes) > 600) return BadRequest(new { message = "Số phút không hợp lệ." });
        c.BonusMinutes = Math.Max(0, c.BonusMinutes + req.Minutes);
        _db.WalletTransactions.Add(new WalletTransaction { ChildId = id, Minutes = req.Minutes, Reason = req.Reason });
        await _db.SaveChangesAsync();
        return Ok(new { message = "Đã cập nhật ví thời gian.", c.BonusMinutes });
    }
}
