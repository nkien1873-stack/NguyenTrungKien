using NguyenTrungKien.API.Data;
using NguyenTrungKien.API.DTOs;
using NguyenTrungKien.API.Models;
using NguyenTrungKien.API.Services;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using Microsoft.EntityFrameworkCore;

namespace NguyenTrungKien.API.Controllers;

/// <summary>CRUD quy tắc ứng dụng (chặn / giới hạn phút) của từng trẻ.</summary>
[ApiController]
[Route("api/children/{childId:int}/rules")]
[Authorize(Roles = Roles.Parent)]
public class AppRulesController : ControllerBase
{
    private readonly AppDbContext _db;
    public AppRulesController(AppDbContext db) => _db = db;

    private Task<bool> OwnsChild(int childId)
    {
        var uid = User.UserId();
        return _db.Children.AnyAsync(c => c.Id == childId && c.ParentId == uid);
    }

    [HttpGet]
    public async Task<IActionResult> GetAll(int childId)
    {
        if (!await OwnsChild(childId)) return NotFound(new { message = "Không tìm thấy hồ sơ." });
        return Ok(await _db.AppRules.Where(r => r.ChildId == childId).OrderBy(r => r.AppName)
            .Select(r => new { r.Id, r.ChildId, r.AppName, r.Category, r.DailyLimitMinutes, r.IsBlocked })
            .ToListAsync());
    }

    [HttpPost]
    public async Task<IActionResult> Create(int childId, AppRuleUpsertRequest req)
    {
        if (!await OwnsChild(childId)) return NotFound(new { message = "Không tìm thấy hồ sơ." });
        var name = req.AppName.Trim();
        if (await _db.AppRules.AnyAsync(r => r.ChildId == childId && r.AppName == name))
            return Conflict(new { message = "Ứng dụng này đã có quy tắc." });
        var r = new AppRule
        {
            ChildId = childId, AppName = name, Category = string.IsNullOrWhiteSpace(req.Category) ? "Khác" : req.Category!,
            DailyLimitMinutes = req.DailyLimitMinutes, IsBlocked = req.IsBlocked
        };
        _db.AppRules.Add(r);
        await _db.SaveChangesAsync();
        return Ok(new { message = "Đã thêm quy tắc.", id = r.Id });
    }

    [HttpPut("{id:int}")]
    public async Task<IActionResult> Update(int childId, int id, AppRuleUpsertRequest req)
    {
        if (!await OwnsChild(childId)) return NotFound(new { message = "Không tìm thấy hồ sơ." });
        var r = await _db.AppRules.FirstOrDefaultAsync(x => x.Id == id && x.ChildId == childId);
        if (r == null) return NotFound(new { message = "Không tìm thấy quy tắc." });
        r.AppName = req.AppName.Trim();
        if (!string.IsNullOrWhiteSpace(req.Category)) r.Category = req.Category!;
        r.DailyLimitMinutes = req.DailyLimitMinutes;
        r.IsBlocked = req.IsBlocked;
        await _db.SaveChangesAsync();
        return Ok(new { message = "Đã cập nhật quy tắc." });
    }

    [HttpDelete("{id:int}")]
    public async Task<IActionResult> Delete(int childId, int id)
    {
        if (!await OwnsChild(childId)) return NotFound(new { message = "Không tìm thấy hồ sơ." });
        var r = await _db.AppRules.FirstOrDefaultAsync(x => x.Id == id && x.ChildId == childId);
        if (r == null) return NotFound(new { message = "Không tìm thấy quy tắc." });
        _db.AppRules.Remove(r);
        await _db.SaveChangesAsync();
        return Ok(new { message = "Đã xóa quy tắc." });
    }
}
