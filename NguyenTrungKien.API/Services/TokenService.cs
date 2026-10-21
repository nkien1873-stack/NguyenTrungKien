using System.IdentityModel.Tokens.Jwt;
using System.Security.Claims;
using System.Text;
using NguyenTrungKien.API.Models;
using Microsoft.Extensions.Options;
using Microsoft.IdentityModel.Tokens;

namespace NguyenTrungKien.API.Services;

public class TokenService
{
    private readonly JwtOptions _opt;
    public TokenService(IOptions<JwtOptions> opt) => _opt = opt.Value;

    public string CreateUserToken(User user) => Build(new List<Claim>
    {
        new("uid", user.Id.ToString()),
        new(ClaimTypes.Name, user.Username),
        new("fullName", user.FullName),
        new(ClaimTypes.Role, user.Role),
    }, DateTime.UtcNow.AddHours(_opt.ExpireHours));

    public string CreateChildToken(ChildProfile child, Device device) => Build(new List<Claim>
    {
        new("childId", child.Id.ToString()),
        new("deviceId", device.Id.ToString()),
        new("parentId", child.ParentId.ToString()),
        new(ClaimTypes.Name, child.Name),
        new("fullName", child.Name),
        new(ClaimTypes.Role, Roles.Child),
    }, DateTime.UtcNow.AddDays(_opt.ChildExpireDays));

    private string Build(List<Claim> claims, DateTime expires)
    {
        var key = new SymmetricSecurityKey(Encoding.UTF8.GetBytes(_opt.Key));
        var token = new JwtSecurityToken(
            issuer: _opt.Issuer,
            audience: _opt.Audience,
            claims: claims,
            expires: expires,
            signingCredentials: new SigningCredentials(key, SecurityAlgorithms.HmacSha256));
        return new JwtSecurityTokenHandler().WriteToken(token);
    }
}

public static class ClaimsExtensions
{
    public static int UserId(this ClaimsPrincipal p) =>
        int.TryParse(p.FindFirst("uid")?.Value, out var id) ? id : 0;

    public static int ChildId(this ClaimsPrincipal p) =>
        int.TryParse(p.FindFirst("childId")?.Value, out var id) ? id : 0;

    public static int DeviceId(this ClaimsPrincipal p) =>
        int.TryParse(p.FindFirst("deviceId")?.Value, out var id) ? id : 0;
}
