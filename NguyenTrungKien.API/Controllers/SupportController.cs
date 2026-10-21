using NguyenTrungKien.API.Data;
using NguyenTrungKien.API.DTOs;
using NguyenTrungKien.API.Models;
using NguyenTrungKien.API.Services;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using Microsoft.EntityFrameworkCore;

namespace NguyenTrungKien.API.Controllers;

/// <summary>Yêu cầu hỗ trợ: phụ huynh tạo – nhân viên (Staff) xử lý.</summary>
[ApiController]
[Route("api/support")]
public class SupportController : ControllerBase
{
    private static readonly string[] Statuses = { "Open", "InProgress", "Resolved" };
    private readonly AppDbContext _db;
    public SupportController(AppDbContext db) => _db = db;

    // ================= PHỤ HUYNH =================

    [Authorize(Roles = Roles.Parent)]
    [HttpGet("my-tickets")]
    public async Task<IActionResult> MyTickets()
    {
        var uid = User.UserId();
        return Ok(await _db.SupportTickets.Where(t => t.ParentId == uid).OrderByDescending(t => t.CreatedAt)
            .Select(t => new
            {
                t.Id, t.Subject, t.Content, t.StaffReply, t.Status, t.Priority, t.CreatedAt, t.UpdatedAt,
                staffName = t.AssignedStaff != null ? t.AssignedStaff.FullName : null
            }).ToListAsync());
    }

    [Authorize(Roles = Roles.Parent)]
    [HttpPost("my-tickets")]
    public async Task<IActionResult> Create(TicketCreateRequest req)
    {
        var t = new SupportTicket
        {
            ParentId = User.UserId(), Subject = req.Subject.Trim(), Content = req.Content.Trim(),
            Priority = req.Priority is "High" or "Low" ? req.Priority : "Normal"
        };
        _db.SupportTickets.Add(t);
        await _db.SaveChangesAsync();
        return Ok(new { message = "Đã gửi yêu cầu hỗ trợ.", id = t.Id });
    }

    [Authorize(Roles = Roles.Parent)]
    [HttpPut("my-tickets/{id:int}")]
    public async Task<IActionResult> Update(int id, TicketCreateRequest req)
    {
        var uid = User.UserId();
        var t = await _db.SupportTickets.FirstOrDefaultAsync(x => x.Id == id && x.ParentId == uid);
        if (t == null) return NotFound(new { message = "Không tìm thấy yêu cầu." });
        if (t.Status != "Open") return BadRequest(new { message = "Yêu cầu đang được xử lý, không thể sửa." });
        t.Subject = req.Subject.Trim();
        t.Content = req.Content.Trim();
        t.Priority = req.Priority is "High" or "Low" ? req.Priority : "Normal";
        t.UpdatedAt = DateTime.UtcNow;
        await _db.SaveChangesAsync();
        return Ok(new { message = "Đã cập nhật yêu cầu." });
    }

    [Authorize(Roles = Roles.Parent)]
    [HttpDelete("my-tickets/{id:int}")]
    public async Task<IActionResult> Delete(int id)
    {
        var uid = User.UserId();
        var t = await _db.SupportTickets.FirstOrDefaultAsync(x => x.Id == id && x.ParentId == uid);
        if (t == null) return NotFound(new { message = "Không tìm thấy yêu cầu." });
        _db.SupportTickets.Remove(t);
        await _db.SaveChangesAsync();
        return Ok(new { message = "Đã xóa yêu cầu." });
    }

    // ================= NHÂN VIÊN =================

    [Authorize(Roles = "Staff,Admin")]
    [HttpGet("dashboard")]
    public async Task<IActionResult> StaffDashboard()
    {
        var uid = User.UserId();
        var today = DateTime.UtcNow.Date;
        return Ok(new
        {
            open = await _db.SupportTickets.CountAsync(t => t.Status == "Open"),
            inProgress = await _db.SupportTickets.CountAsync(t => t.Status == "InProgress"),
            resolved = await _db.SupportTickets.CountAsync(t => t.Status == "Resolved"),
            mine = await _db.SupportTickets.CountAsync(t => t.AssignedStaffId == uid && t.Status != "Resolved"),
            resolvedToday = await _db.SupportTickets.CountAsync(t => t.Status == "Resolved" && t.UpdatedAt >= today),
            highPriority = await _db.SupportTickets.CountAsync(t => t.Priority == "High" && t.Status != "Resolved"),
            totalParents = await _db.Users.CountAsync(u => u.Role == Roles.Parent)
        });
    }

    [Authorize(Roles = "Staff,Admin")]
    [HttpGet("tickets")]
    public async Task<IActionResult> AllTickets([FromQuery] string? status, [FromQuery] bool mine = false)
    {
        var uid = User.UserId();
        var q = _db.SupportTickets.AsQueryable();
        if (!string.IsNullOrWhiteSpace(status)) q = q.Where(t => t.Status == status);
        if (mine) q = q.Where(t => t.AssignedStaffId == uid);
        return Ok(await q
            .OrderBy(t => t.Status == "Resolved" ? 1 : 0)
            .ThenBy(t => t.Priority == "High" ? 0 : t.Priority == "Normal" ? 1 : 2)
            .ThenByDescending(t => t.CreatedAt)
            .Select(t => new
            {
                t.Id, t.Subject, t.Content, t.StaffReply, t.Status, t.Priority, t.CreatedAt, t.UpdatedAt,
                parentName = t.Parent!.FullName, parentEmail = t.Parent.Email, parentPhone = t.Parent.Phone,
                staffName = t.AssignedStaff != null ? t.AssignedStaff.FullName : null,
                t.AssignedStaffId
            }).ToListAsync());
    }

    [Authorize(Roles = "Staff,Admin")]
    [HttpPut("tickets/{id:int}")]
    public async Task<IActionResult> Handle(int id, TicketStaffUpdateRequest req)
    {
        if (!Statuses.Contains(req.Status)) return BadRequest(new { message = "Trạng thái không hợp lệ." });
        var t = await _db.SupportTickets.FindAsync(id);
        if (t == null) return NotFound(new { message = "Không tìm thấy yêu cầu." });
        t.Status = req.Status;
        if (!string.IsNullOrWhiteSpace(req.Reply)) t.StaffReply = req.Reply.Trim();
        t.AssignedStaffId ??= User.UserId();
        t.UpdatedAt = DateTime.UtcNow;
        await _db.SaveChangesAsync();
        return Ok(new { message = "Đã cập nhật yêu cầu." });
    }

    /// <summary>Danh sách phụ huynh (chỉ đọc) để nhân viên tra cứu khi hỗ trợ.</summary>
    [Authorize(Roles = "Staff,Admin")]
    [HttpGet("parents")]
    public async Task<IActionResult> Parents([FromQuery] string? search)
    {
        var q = _db.Users.Where(u => u.Role == Roles.Parent);
        if (!string.IsNullOrWhiteSpace(search))
        {
            var s = search.Trim().ToLower();
            q = q.Where(u => u.Username.Contains(s) || u.Email.Contains(s) || u.FullName.ToLower().Contains(s));
        }
        return Ok(await q.OrderBy(u => u.FullName).Select(u => new
        {
            u.Id, u.Username, u.FullName, u.Email, u.Phone, u.IsLocked, u.EmailConfirmed, u.CreatedAt,
            childCount = u.Children.Count,
            deviceCount = u.Children.SelectMany(c => c.Devices).Count()
        }).ToListAsync());
    }
}
