using NguyenTrungKien.API.Data;
using NguyenTrungKien.API.DTOs;
using NguyenTrungKien.API.Models;
using NguyenTrungKien.API.Services;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using Microsoft.EntityFrameworkCore;

namespace NguyenTrungKien.API.Controllers;

/// <summary>Trang quản trị – chỉ Admin.</summary>
[ApiController]
[Route("api/admin")]
[Authorize(Roles = Roles.Admin)]
public class AdminController : ControllerBase
{
    private readonly AppDbContext _db;
    public AdminController(AppDbContext db) => _db = db;

    [HttpGet("stats")]
    public async Task<IActionResult> Stats()
    {
        var today = DateTime.UtcNow.Date;
        var from = today.AddDays(-6);
        var regs = await _db.Users.Where(u => u.CreatedAt >= from)
            .GroupBy(u => u.CreatedAt.Date)
            .Select(g => new { date = g.Key, count = g.Count() })
            .ToListAsync();

        var last7 = Enumerable.Range(0, 7).Select(i =>
        {
            var d = from.AddDays(i);
            return new { date = d.ToString("dd/MM"), count = regs.FirstOrDefault(r => r.date == d)?.count ?? 0 };
        });

        return Ok(new
        {
            totalUsers = await _db.Users.CountAsync(),
            admins = await _db.Users.CountAsync(u => u.Role == Roles.Admin),
            staffs = await _db.Users.CountAsync(u => u.Role == Roles.Staff),
            parents = await _db.Users.CountAsync(u => u.Role == Roles.Parent),
            lockedUsers = await _db.Users.CountAsync(u => u.IsLocked),
            children = await _db.Children.CountAsync(),
            devices = await _db.Devices.CountAsync(d => d.IsActive),
            alertsToday = await _db.Alerts.CountAsync(a => a.CreatedAt >= today),
            sosToday = await _db.Alerts.CountAsync(a => a.CreatedAt >= today && a.Type == "SOS"),
            openTickets = await _db.SupportTickets.CountAsync(t => t.Status != "Resolved"),
            registrationsLast7Days = last7
        });
    }

    [HttpGet("users")]
    public async Task<IActionResult> GetUsers([FromQuery] string? search, [FromQuery] string? role)
    {
        var q = _db.Users.AsQueryable();
        if (!string.IsNullOrWhiteSpace(role)) q = q.Where(u => u.Role == role);
        if (!string.IsNullOrWhiteSpace(search))
        {
            var s = search.Trim().ToLower();
            q = q.Where(u => u.Username.Contains(s) || u.Email.Contains(s) || u.FullName.ToLower().Contains(s));
        }
        var list = await q.OrderByDescending(u => u.CreatedAt).Select(u => new
        {
            u.Id, u.Username, u.Email, u.FullName, u.Phone, u.Role, u.IsLocked, u.EmailConfirmed,
            hasFace = u.FaceTemplate != null, u.CreatedAt, u.LastLoginAt,
            childCount = u.Children.Count
        }).ToListAsync();
        return Ok(list);
    }

    [HttpGet("users/{id:int}")]
    public async Task<IActionResult> GetUser(int id)
    {
        var u = await _db.Users.Include(x => x.Children).FirstOrDefaultAsync(x => x.Id == id);
        if (u == null) return NotFound(new { message = "Không tìm thấy người dùng." });
        return Ok(new
        {
            u.Id, u.Username, u.Email, u.FullName, u.Phone, u.Role, u.IsLocked, u.EmailConfirmed,
            hasFace = u.FaceTemplate != null, u.CreatedAt, u.LastLoginAt,
            children = u.Children.Select(c => new { c.Id, c.Name })
        });
    }

    [HttpPost("users")]
    public async Task<IActionResult> CreateUser(AdminCreateUserRequest req)
    {
        if (!Roles.All.Contains(req.Role) || req.Role == Roles.Child)
            return BadRequest(new { message = "Vai trò không hợp lệ." });
        var username = req.Username.Trim().ToLower();
        var email = req.Email.Trim().ToLower();
        if (await _db.Users.AnyAsync(u => u.Username == username)) return Conflict(new { message = "Tên đăng nhập đã tồn tại." });
        if (await _db.Users.AnyAsync(u => u.Email == email)) return Conflict(new { message = "Email đã được sử dụng." });

        var user = new User
        {
            Username = username, Email = email, FullName = req.FullName.Trim(), Phone = req.Phone,
            Role = req.Role, EmailConfirmed = true,
            PasswordHash = BCrypt.Net.BCrypt.HashPassword(req.Password)
        };
        _db.Users.Add(user);
        await _db.SaveChangesAsync();
        return Ok(new { message = "Đã tạo tài khoản.", id = user.Id });
    }

    [HttpPut("users/{id:int}")]
    public async Task<IActionResult> UpdateUser(int id, AdminUpdateUserRequest req)
    {
        var u = await _db.Users.FindAsync(id);
        if (u == null) return NotFound(new { message = "Không tìm thấy người dùng." });
        if (!Roles.All.Contains(req.Role) || req.Role == Roles.Child) return BadRequest(new { message = "Vai trò không hợp lệ." });
        if (id == User.UserId() && (req.IsLocked || req.Role != Roles.Admin))
            return BadRequest(new { message = "Không thể tự khóa hoặc hạ quyền chính mình." });

        var email = req.Email.Trim().ToLower();
        if (await _db.Users.AnyAsync(x => x.Email == email && x.Id != id))
            return Conflict(new { message = "Email đã được sử dụng." });

        u.FullName = req.FullName.Trim();
        u.Email = email;
        u.Phone = req.Phone;
        u.Role = req.Role;
        u.IsLocked = req.IsLocked;
        u.EmailConfirmed = req.EmailConfirmed;
        if (!string.IsNullOrWhiteSpace(req.NewPassword))
        {
            if (req.NewPassword.Length < 6) return BadRequest(new { message = "Mật khẩu tối thiểu 6 ký tự." });
            u.PasswordHash = BCrypt.Net.BCrypt.HashPassword(req.NewPassword);
        }
        await _db.SaveChangesAsync();
        return Ok(new { message = "Đã cập nhật." });
    }

    [HttpPatch("users/{id:int}/lock")]
    public async Task<IActionResult> ToggleLock(int id)
    {
        if (id == User.UserId()) return BadRequest(new { message = "Không thể tự khóa chính mình." });
        var u = await _db.Users.FindAsync(id);
        if (u == null) return NotFound(new { message = "Không tìm thấy người dùng." });
        u.IsLocked = !u.IsLocked;
        await _db.SaveChangesAsync();
        return Ok(new { message = u.IsLocked ? "Đã khóa tài khoản." : "Đã mở khóa tài khoản.", u.IsLocked });
    }

    [HttpDelete("users/{id:int}")]
    public async Task<IActionResult> DeleteUser(int id)
    {
        if (id == User.UserId()) return BadRequest(new { message = "Không thể xóa chính mình." });
        var u = await _db.Users.FindAsync(id);
        if (u == null) return NotFound(new { message = "Không tìm thấy người dùng." });

        // Gỡ phân công ticket nếu là nhân viên (FK NoAction)
        var assigned = await _db.SupportTickets.Where(t => t.AssignedStaffId == id).ToListAsync();
        assigned.ForEach(t => t.AssignedStaffId = null);

        _db.Users.Remove(u);
        await _db.SaveChangesAsync();
        return Ok(new { message = "Đã xóa người dùng." });
    }
}
