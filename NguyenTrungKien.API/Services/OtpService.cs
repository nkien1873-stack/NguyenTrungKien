using System.Security.Cryptography;
using System.Text;
using NguyenTrungKien.API.Data;
using NguyenTrungKien.API.Models;
using Microsoft.EntityFrameworkCore;

namespace NguyenTrungKien.API.Services;

public static class OtpPurposes
{
    public const string Register = "Register";
    public const string Login = "Login";
    public const string ResetPassword = "ResetPassword";
}

public class OtpService
{
    private const int ExpireMinutes = 5;
    private const int MaxAttempts = 5;
    private const int ResendCooldownSeconds = 60;

    private readonly AppDbContext _db;
    private readonly IEmailService _email;
    private readonly ILogger<OtpService> _log;

    public OtpService(AppDbContext db, IEmailService email, ILogger<OtpService> log)
    {
        _db = db;
        _email = email;
        _log = log;
    }

    private static string Hash(string code) =>
        Convert.ToHexString(SHA256.HashData(Encoding.UTF8.GetBytes(code)));

    /// <summary>Tạo OTP mới, vô hiệu hóa OTP cũ cùng mục đích và gửi email. Trả về mã gốc (chỉ dùng cho chế độ demo).</summary>
    public async Task<(string? code, string? error)> CreateAndSendAsync(User user, string purpose)
    {
        var last = await _db.OtpCodes
            .Where(o => o.UserId == user.Id && o.Purpose == purpose)
            .OrderByDescending(o => o.CreatedAt).FirstOrDefaultAsync();
        if (last != null && !last.Used && (DateTime.UtcNow - last.CreatedAt).TotalSeconds < ResendCooldownSeconds)
            return (null, $"Vui lòng đợi {ResendCooldownSeconds} giây trước khi gửi lại mã.");

        var olds = await _db.OtpCodes.Where(o => o.UserId == user.Id && o.Purpose == purpose && !o.Used).ToListAsync();
        olds.ForEach(o => o.Used = true);

        var code = RandomNumberGenerator.GetInt32(0, 1_000_000).ToString("D6");
        _db.OtpCodes.Add(new OtpCode
        {
            UserId = user.Id,
            Purpose = purpose,
            CodeHash = Hash(code),
            ExpiresAt = DateTime.UtcNow.AddMinutes(ExpireMinutes)
        });
        await _db.SaveChangesAsync();

        var title = purpose switch
        {
            OtpPurposes.Register => "Xác thực email đăng ký",
            OtpPurposes.ResetPassword => "Đặt lại mật khẩu",
            _ => "Mã đăng nhập"
        };
        var html = $@"
<div style='font-family:Arial,sans-serif;max-width:480px;margin:auto;border:1px solid #eee;border-radius:12px;padding:24px'>
  <h2 style='color:#3D5AFE;margin-top:0'>KidGuard – {title}</h2>
  <p>Xin chào <b>{System.Net.WebUtility.HtmlEncode(user.FullName)}</b>,</p>
  <p>Mã OTP của bạn là:</p>
  <div style='font-size:32px;letter-spacing:8px;font-weight:bold;background:#F1F4FF;padding:12px;text-align:center;border-radius:8px'>{code}</div>
  <p style='color:#666'>Mã có hiệu lực trong {ExpireMinutes} phút. Không chia sẻ mã này cho bất kỳ ai.</p>
</div>";
        try
        {
            await _email.SendAsync(user.Email, user.FullName, $"[KidGuard] {title}: {code}", html);
        }
        catch (Exception ex)
        {
            _log.LogError(ex, "Gửi email OTP thất bại");
            // Gmail báo sai tài khoản/mật khẩu bằng mã 5.7.8 (có khi qua AuthenticationException, có khi ngắt kết nối)
            if (ex is MailKit.Security.AuthenticationException || ex.Message.Contains("5.7.8"))
                return (null, "Không gửi được email: Gmail từ chối đăng nhập. Kiểm tra Email:UserName và Mật khẩu ứng dụng (App Password 16 ký tự).");
            return (null, "Không gửi được email OTP: " + ex.Message);
        }
        return (code, null);
    }

    public async Task<string?> VerifyAsync(int userId, string purpose, string code)
    {
        var otp = await _db.OtpCodes
            .Where(o => o.UserId == userId && o.Purpose == purpose && !o.Used)
            .OrderByDescending(o => o.CreatedAt).FirstOrDefaultAsync();

        if (otp == null) return "Không tìm thấy mã OTP. Vui lòng gửi lại mã.";
        if (otp.ExpiresAt < DateTime.UtcNow) { otp.Used = true; await _db.SaveChangesAsync(); return "Mã OTP đã hết hạn."; }
        if (otp.Attempts >= MaxAttempts) { otp.Used = true; await _db.SaveChangesAsync(); return "Nhập sai quá nhiều lần. Vui lòng gửi lại mã."; }

        if (!CryptographicOperations.FixedTimeEquals(
                Encoding.UTF8.GetBytes(otp.CodeHash), Encoding.UTF8.GetBytes(Hash(code.Trim()))))
        {
            otp.Attempts++;
            await _db.SaveChangesAsync();
            return $"Mã OTP không đúng (còn {MaxAttempts - otp.Attempts} lần thử).";
        }

        otp.Used = true;
        await _db.SaveChangesAsync();
        return null;
    }
}
