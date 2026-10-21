using NguyenTrungKien.API.Data;
using NguyenTrungKien.API.DTOs;
using NguyenTrungKien.API.Models;
using NguyenTrungKien.API.Services;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using Microsoft.EntityFrameworkCore;

namespace NguyenTrungKien.API.Controllers;

/// <summary>
/// TÍNH NĂNG MỚI – "Ví thời gian": phụ huynh giao nhiệm vụ, trẻ gửi ảnh minh chứng,
/// phụ huynh duyệt (xác nhận bằng vân tay trên app) thì phút thưởng được cộng vào ví.
/// </summary>
[ApiController]
[Route("api/tasks")]
[Authorize(Roles = Roles.Parent)]
public class TasksController : ControllerBase
{
    private readonly AppDbContext _db;
    public TasksController(AppDbContext db) => _db = db;

    [HttpGet]
    public async Task<IActionResult> GetAll([FromQuery] int? childId, [FromQuery] string? status)
    {
        var uid = User.UserId();
        var q = _db.RewardTasks.Where(t => t.Child!.ParentId == uid);
        if (childId.HasValue) q = q.Where(t => t.ChildId == childId);
        if (!string.IsNullOrWhiteSpace(status)) q = q.Where(t => t.Status == status);
        var list = await q
            .OrderBy(t => t.Status == TaskStatuses.Submitted ? 0 : t.Status == TaskStatuses.Assigned ? 1 : 2)
            .ThenByDescending(t => t.CreatedAt)
            .Select(t => new
            {
                t.Id, t.ChildId, childName = t.Child!.Name, t.Title, t.Description, t.RewardMinutes, t.DueDate,
                t.Status, t.ProofImageUrl, t.ChildNote, t.ParentComment, t.CreatedAt, t.SubmittedAt, t.ReviewedAt
            }).ToListAsync();
        return Ok(list);
    }

    [HttpPost]
    public async Task<IActionResult> Create(TaskUpsertRequest req)
    {
        var uid = User.UserId();
        if (!await _db.Children.AnyAsync(c => c.Id == req.ChildId && c.ParentId == uid))
            return NotFound(new { message = "Không tìm thấy hồ sơ trẻ." });
        var t = new RewardTask
        {
            ChildId = req.ChildId, Title = req.Title.Trim(), Description = req.Description,
            RewardMinutes = req.RewardMinutes, DueDate = req.DueDate
        };
        _db.RewardTasks.Add(t);
        await _db.SaveChangesAsync();
        return Ok(new { message = "Đã giao nhiệm vụ.", id = t.Id });
    }

    [HttpPut("{id:int}")]
    public async Task<IActionResult> Update(int id, TaskUpsertRequest req)
    {
        var uid = User.UserId();
        var t = await _db.RewardTasks.FirstOrDefaultAsync(x => x.Id == id && x.Child!.ParentId == uid);
        if (t == null) return NotFound(new { message = "Không tìm thấy nhiệm vụ." });
        if (t.Status == TaskStatuses.Approved) return BadRequest(new { message = "Nhiệm vụ đã duyệt, không thể sửa." });
        t.Title = req.Title.Trim();
        t.Description = req.Description;
        t.RewardMinutes = req.RewardMinutes;
        t.DueDate = req.DueDate;
        await _db.SaveChangesAsync();
        return Ok(new { message = "Đã cập nhật nhiệm vụ." });
    }

    [HttpDelete("{id:int}")]
    public async Task<IActionResult> Delete(int id)
    {
        var uid = User.UserId();
        var t = await _db.RewardTasks.FirstOrDefaultAsync(x => x.Id == id && x.Child!.ParentId == uid);
        if (t == null) return NotFound(new { message = "Không tìm thấy nhiệm vụ." });
        _db.RewardTasks.Remove(t);
        await _db.SaveChangesAsync();
        return Ok(new { message = "Đã xóa nhiệm vụ." });
    }

    /// <summary>Duyệt / từ chối minh chứng. Duyệt -> cộng phút vào ví thời gian.</summary>
    [HttpPost("{id:int}/review")]
    public async Task<IActionResult> Review(int id, ReviewTaskRequest req)
    {
        var uid = User.UserId();
        var t = await _db.RewardTasks.Include(x => x.Child)
            .FirstOrDefaultAsync(x => x.Id == id && x.Child!.ParentId == uid);
        if (t == null) return NotFound(new { message = "Không tìm thấy nhiệm vụ." });
        if (t.Status != TaskStatuses.Submitted) return BadRequest(new { message = "Nhiệm vụ chưa được trẻ gửi minh chứng." });

        t.Status = req.Approve ? TaskStatuses.Approved : TaskStatuses.Rejected;
        t.ParentComment = req.Comment;
        t.ReviewedAt = DateTime.UtcNow;

        if (req.Approve)
        {
            t.Child!.BonusMinutes += t.RewardMinutes;
            _db.WalletTransactions.Add(new WalletTransaction
            {
                ChildId = t.ChildId, Minutes = t.RewardMinutes, Reason = "Hoàn thành: " + t.Title
            });
        }
        await _db.SaveChangesAsync();
        return Ok(new
        {
            message = req.Approve ? $"Đã duyệt, cộng {t.RewardMinutes} phút cho {t.Child!.Name}." : "Đã từ chối minh chứng.",
            bonusMinutes = t.Child!.BonusMinutes
        });
    }
}
