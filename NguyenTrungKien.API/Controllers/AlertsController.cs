using NguyenTrungKien.API.Data;
using NguyenTrungKien.API.Models;
using NguyenTrungKien.API.Services;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using Microsoft.EntityFrameworkCore;

namespace NguyenTrungKien.API.Controllers;

/// <summary>Cảnh báo của phụ huynh (SOS, rời vùng an toàn, pin yếu, minh chứng mới...).</summary>
[ApiController]
[Route("api/alerts")]
[Authorize(Roles = Roles.Parent)]
public class AlertsController : ControllerBase
{
    private readonly AppDbContext _db;
    public AlertsController(AppDbContext db) => _db = db;

    [HttpGet]
    public async Task<IActionResult> GetAll([FromQuery] int? childId, [FromQuery] bool unreadOnly = false)
    {
        var uid = User.UserId();
        var q = _db.Alerts.Where(a => a.Child!.ParentId == uid);
        if (childId.HasValue) q = q.Where(a => a.ChildId == childId);
        if (unreadOnly) q = q.Where(a => !a.IsRead);
        var list = await q.OrderByDescending(a => a.CreatedAt).Take(200).Select(a => new
        {
            a.Id, a.ChildId, childName = a.Child!.Name, a.Type, a.Message, a.Latitude, a.Longitude, a.IsRead, a.CreatedAt
        }).ToListAsync();
        return Ok(list);
    }

    [HttpGet("unread-count")]
    public async Task<IActionResult> UnreadCount()
    {
        var uid = User.UserId();
        var count = await _db.Alerts.CountAsync(a => a.Child!.ParentId == uid && !a.IsRead);
        var sos = await _db.Alerts.CountAsync(a => a.Child!.ParentId == uid && !a.IsRead && a.Type == "SOS");
        return Ok(new { count, sos });
    }

    [HttpPatch("{id:int}/read")]
    public async Task<IActionResult> MarkRead(int id)
    {
        var uid = User.UserId();
        var a = await _db.Alerts.FirstOrDefaultAsync(x => x.Id == id && x.Child!.ParentId == uid);
        if (a == null) return NotFound(new { message = "Không tìm thấy cảnh báo." });
        a.IsRead = true;
        await _db.SaveChangesAsync();
        return Ok(new { message = "Đã đánh dấu đã đọc." });
    }

    [HttpPost("read-all")]
    public async Task<IActionResult> ReadAll()
    {
        var uid = User.UserId();
        var list = await _db.Alerts.Where(x => x.Child!.ParentId == uid && !x.IsRead).ToListAsync();
        list.ForEach(a => a.IsRead = true);
        await _db.SaveChangesAsync();
        return Ok(new { message = $"Đã đọc {list.Count} cảnh báo." });
    }

    [HttpDelete("{id:int}")]
    public async Task<IActionResult> Delete(int id)
    {
        var uid = User.UserId();
        var a = await _db.Alerts.FirstOrDefaultAsync(x => x.Id == id && x.Child!.ParentId == uid);
        if (a == null) return NotFound(new { message = "Không tìm thấy cảnh báo." });
        _db.Alerts.Remove(a);
        await _db.SaveChangesAsync();
        return Ok(new { message = "Đã xóa cảnh báo." });
    }
}
