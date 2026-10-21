using NguyenTrungKien.API.Data;
using NguyenTrungKien.API.DTOs;
using NguyenTrungKien.API.Models;
using NguyenTrungKien.API.Services;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using Microsoft.EntityFrameworkCore;

namespace NguyenTrungKien.API.Controllers;

/// <summary>CRUD vùng an toàn của từng trẻ.</summary>
[ApiController]
[Route("api/children/{childId:int}/zones")]
[Authorize(Roles = Roles.Parent)]
public class SafeZonesController : ControllerBase
{
    private readonly AppDbContext _db;
    public SafeZonesController(AppDbContext db) => _db = db;

    private Task<bool> OwnsChild(int childId)
    {
        var uid = User.UserId();
        return _db.Children.AnyAsync(c => c.Id == childId && c.ParentId == uid);
    }

    [HttpGet]
    public async Task<IActionResult> GetAll(int childId)
    {
        if (!await OwnsChild(childId)) return NotFound(new { message = "Không tìm thấy hồ sơ." });
        return Ok(await _db.SafeZones.Where(z => z.ChildId == childId).OrderBy(z => z.Name)
            .Select(z => new { z.Id, z.ChildId, z.Name, z.Latitude, z.Longitude, z.RadiusMeters, z.IsActive })
            .ToListAsync());
    }

    [HttpPost]
    public async Task<IActionResult> Create(int childId, SafeZoneUpsertRequest req)
    {
        if (!await OwnsChild(childId)) return NotFound(new { message = "Không tìm thấy hồ sơ." });
        var z = new SafeZone
        {
            ChildId = childId, Name = req.Name.Trim(), Latitude = req.Latitude, Longitude = req.Longitude,
            RadiusMeters = req.RadiusMeters, IsActive = req.IsActive
        };
        _db.SafeZones.Add(z);
        await _db.SaveChangesAsync();
        return Ok(new { message = "Đã thêm vùng an toàn.", id = z.Id });
    }

    [HttpPut("{id:int}")]
    public async Task<IActionResult> Update(int childId, int id, SafeZoneUpsertRequest req)
    {
        if (!await OwnsChild(childId)) return NotFound(new { message = "Không tìm thấy hồ sơ." });
        var z = await _db.SafeZones.FirstOrDefaultAsync(x => x.Id == id && x.ChildId == childId);
        if (z == null) return NotFound(new { message = "Không tìm thấy vùng an toàn." });
        z.Name = req.Name.Trim();
        z.Latitude = req.Latitude;
        z.Longitude = req.Longitude;
        z.RadiusMeters = req.RadiusMeters;
        z.IsActive = req.IsActive;
        await _db.SaveChangesAsync();
        return Ok(new { message = "Đã cập nhật vùng an toàn." });
    }

    [HttpDelete("{id:int}")]
    public async Task<IActionResult> Delete(int childId, int id)
    {
        if (!await OwnsChild(childId)) return NotFound(new { message = "Không tìm thấy hồ sơ." });
        var z = await _db.SafeZones.FirstOrDefaultAsync(x => x.Id == id && x.ChildId == childId);
        if (z == null) return NotFound(new { message = "Không tìm thấy vùng an toàn." });
        _db.SafeZones.Remove(z);
        await _db.SaveChangesAsync();
        return Ok(new { message = "Đã xóa vùng an toàn." });
    }
}
