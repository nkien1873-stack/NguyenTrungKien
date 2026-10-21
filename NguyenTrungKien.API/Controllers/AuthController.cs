using NguyenTrungKien.API.Data;
using NguyenTrungKien.API.DTOs;
using NguyenTrungKien.API.Models;
using NguyenTrungKien.API.Services;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.Options;

namespace NguyenTrungKien.API.Controllers;

[ApiController]
[Route("api/auth")]
public class AuthController : ControllerBase
{
    private readonly AppDbContext _db;
    private readonly OtpService _otp;
    private readonly TokenService _token;
    private readonly FaceMatcher _face;
    private readonly EmailOptions _emailOpt;

    private readonly bool _loginOtp;

    public AuthController(AppDbContext db, OtpService otp, TokenService token, FaceMatcher face, IOptions<EmailOptions> emailOpt,
        IConfiguration config)
    {
        _db = db;
        _otp = otp;
        _token = token;
        _face = face;
        _emailOpt = emailOpt.Value;
        // Đề bài yêu cầu đăng nhập có OTP -> mặc định bật. Tắt (Auth:LoginOtp=false) chỉ để thử nhanh trên máy mình.
        _loginOtp = config.GetValue<bool?>("Auth:LoginOtp") ?? true;
    }

    private string? Dev(string? code) => _emailOpt.ReturnOtpInResponse ? code : null;

    private static string MaskEmail(string email)
    {
        var at = email.IndexOf('@');
        if (at <= 1) return email;
        var name = email[..at];
        var keep = Math.Min(2, name.Length - 1);
        return name[..keep] + new string('*', Math.Max(3, name.Length - keep)) + email[at..];
    }

    private AuthResponse ToAuth(User u) =>
        new(_token.CreateUserToken(u), u.Role, u.Id, u.Username, u.FullName, u.Email, u.FaceTemplate != null);

    // ---------------- ĐĂNG KÝ QUA EMAIL ----------------

    /// <summary>Đăng ký tài khoản phụ huynh. Hệ thống gửi OTP về email để xác thực.</summary>
    [HttpPost("register")]
    public async Task<IActionResult> Register(RegisterRequest req)
    {
        var username = req.Username.Trim().ToLower();
        var email = req.Email.Trim().ToLower();

        var existed = await _db.Users.FirstOrDefaultAsync(u => u.Username == username || u.Email == email);
        if (existed != null)
        {
            // Cho phép đăng ký lại nếu tài khoản cũ chưa xác thực email
            if (!existed.EmailConfirmed && existed.Email == email && existed.Username == username)
            {
                existed.FullName = req.FullName.Trim();
                existed.Phone = req.Phone;
                existed.PasswordHash = BCrypt.Net.BCrypt.HashPassword(req.Password);
                await _db.SaveChangesAsync();
                var (c, err) = await _otp.CreateAndSendAsync(existed, OtpPurposes.Register);
                if (err != null) return BadRequest(new { message = err });
                return Ok(new OtpStepResponse(true, MaskEmail(email), "Đã gửi lại mã xác thực tới email.", Dev(c)));
            }
            return Conflict(new { message = existed.Username == username ? "Tên đăng nhập đã tồn tại." : "Email đã được sử dụng." });
        }

        var user = new User
        {
            Username = username,
            Email = email,
            FullName = req.FullName.Trim(),
            Phone = req.Phone,
            Role = Roles.Parent,
            PasswordHash = BCrypt.Net.BCrypt.HashPassword(req.Password)
        };
        _db.Users.Add(user);
        await _db.SaveChangesAsync();

        var (code, error) = await _otp.CreateAndSendAsync(user, OtpPurposes.Register);
        if (error != null) return BadRequest(new { message = error });
        return Ok(new OtpStepResponse(true, MaskEmail(email), "Đăng ký thành công. Nhập mã OTP đã gửi tới email để kích hoạt.", Dev(code)));
    }

    [HttpPost("verify-email")]
    public async Task<IActionResult> VerifyEmail(VerifyEmailRequest req)
    {
        var user = await _db.Users.FirstOrDefaultAsync(u => u.Email == req.Email.Trim().ToLower());
        if (user == null) return NotFound(new { message = "Không tìm thấy tài khoản." });
        if (user.EmailConfirmed) return Ok(new { message = "Email đã được xác thực trước đó." });

        var err = await _otp.VerifyAsync(user.Id, OtpPurposes.Register, req.Code);
        if (err != null) return BadRequest(new { message = err });

        user.EmailConfirmed = true;
        await _db.SaveChangesAsync();
        return Ok(new { message = "Xác thực email thành công. Bạn có thể đăng nhập." });
    }

    /// <summary>Gửi lại OTP. Login = tên đăng nhập hoặc email.</summary>
    [HttpPost("resend-otp")]
    public async Task<IActionResult> ResendOtp(ResendOtpRequest req)
    {
        var key = req.Login.Trim().ToLower();
        var user = await _db.Users.FirstOrDefaultAsync(u => u.Username == key || u.Email == key);
        if (user == null) return NotFound(new { message = "Không tìm thấy tài khoản." });
        if (req.Purpose is not (OtpPurposes.Register or OtpPurposes.Login or OtpPurposes.ResetPassword))
            return BadRequest(new { message = "Mục đích OTP không hợp lệ." });

        var (code, err) = await _otp.CreateAndSendAsync(user, req.Purpose);
        if (err != null) return BadRequest(new { message = err });
        return Ok(new OtpStepResponse(true, MaskEmail(user.Email), "Đã gửi lại mã OTP.", Dev(code)));
    }

    // ---------------- ĐĂNG NHẬP: TÊN ĐĂNG NHẬP + MẬT KHẨU + OTP ----------------

    /// <summary>Bước 1: kiểm tra tên đăng nhập + mật khẩu, đúng thì gửi OTP qua email.</summary>
    [HttpPost("login")]
    public async Task<IActionResult> Login(LoginRequest req)
    {
        var username = req.Username.Trim().ToLower();
        var user = await _db.Users.FirstOrDefaultAsync(u => u.Username == username);
        if (user == null || !BCrypt.Net.BCrypt.Verify(req.Password, user.PasswordHash))
            return Unauthorized(new { message = "Sai tên đăng nhập hoặc mật khẩu." });
        if (user.IsLocked)
            return StatusCode(403, new { message = "Tài khoản đã bị khóa. Liên hệ quản trị viên." });

        if (!user.EmailConfirmed)
        {
            var (rc, _) = await _otp.CreateAndSendAsync(user, OtpPurposes.Register);
            return Conflict(new
            {
                message = "Email chưa được xác thực. Mã xác thực đã được gửi lại.",
                needVerifyEmail = true,
                email = user.Email,
                maskedEmail = MaskEmail(user.Email),
                devOtp = Dev(rc)
            });
        }

        if (!_loginOtp)
        {
            // Đã tắt OTP đăng nhập -> đúng mật khẩu là cấp JWT luôn
            user.LastLoginAt = DateTime.UtcNow;
            await _db.SaveChangesAsync();
            return Ok(ToAuth(user));
        }

        var (code, err) = await _otp.CreateAndSendAsync(user, OtpPurposes.Login);
        if (err != null) return BadRequest(new { message = err });
        return Ok(new OtpStepResponse(true, MaskEmail(user.Email), "Mã OTP đã được gửi tới email của bạn.", Dev(code)));
    }

    /// <summary>Bước 2: xác thực OTP và cấp JWT.</summary>
    [HttpPost("verify-login-otp")]
    public async Task<ActionResult<AuthResponse>> VerifyLoginOtp(VerifyLoginOtpRequest req)
    {
        var user = await _db.Users.FirstOrDefaultAsync(u => u.Username == req.Username.Trim().ToLower());
        if (user == null) return Unauthorized(new { message = "Tài khoản không tồn tại." });
        if (user.IsLocked) return StatusCode(403, new { message = "Tài khoản đã bị khóa." });

        var err = await _otp.VerifyAsync(user.Id, OtpPurposes.Login, req.Code);
        if (err != null) return BadRequest(new { message = err });

        user.LastLoginAt = DateTime.UtcNow;
        await _db.SaveChangesAsync();
        return Ok(ToAuth(user));
    }

    // ---------------- ĐĂNG NHẬP BẰNG KHUÔN MẶT ----------------

    [Authorize(Roles = "Admin,Staff,Parent")]
    [HttpPost("face/enroll")]
    public async Task<IActionResult> EnrollFace(FaceEnrollRequest req)
    {
        if (req.Samples.Count < 1 || req.Samples.Any(s => s.Length < 10 || s.Length != req.Samples[0].Length))
            return BadRequest(new { message = "Dữ liệu khuôn mặt không hợp lệ." });
        if (!_face.SamplesConsistent(req.Samples))
            return BadRequest(new { message = "Các ảnh chụp không đồng nhất. Hãy giữ mặt thẳng, đủ sáng và thử lại." });

        var user = await _db.Users.FindAsync(User.UserId());
        if (user == null) return Unauthorized();
        user.FaceTemplate = _face.BuildTemplate(req.Samples);
        await _db.SaveChangesAsync();
        return Ok(new { message = "Đã đăng ký khuôn mặt." });
    }

    [Authorize(Roles = "Admin,Staff,Parent")]
    [HttpDelete("face")]
    public async Task<IActionResult> RemoveFace()
    {
        var user = await _db.Users.FindAsync(User.UserId());
        if (user == null) return Unauthorized();
        user.FaceTemplate = null;
        await _db.SaveChangesAsync();
        return Ok(new { message = "Đã xóa dữ liệu khuôn mặt." });
    }

    private const string HowToEnrollFace =
        "Đăng nhập bằng mật khẩu trước, rồi vào Tài khoản > Đăng nhập bằng khuôn mặt để đăng ký.";

    [HttpPost("face-login")]
    public async Task<ActionResult<AuthResponse>> FaceLogin(FaceLoginRequest req)
    {
        var username = req.Username?.Trim().ToLower();
        User? user;
        double distance;

        if (!string.IsNullOrEmpty(username))
        {
            // Có tên đăng nhập -> so với đúng tài khoản đó
            user = await _db.Users.FirstOrDefaultAsync(u => u.Username == username);
            if (user == null) return BadRequest(new { message = "Không tìm thấy tài khoản " + username + "." });
            if (user.FaceTemplate == null)
                return BadRequest(new { message = $"Tài khoản {username} chưa đăng ký khuôn mặt. {HowToEnrollFace}" });
            (var match, distance) = _face.Compare(user.FaceTemplate, req.Features);
            if (!match)
                return Unauthorized(new { message = "Khuôn mặt không khớp.", distance = Math.Round(distance, 4) });
        }
        else
        {
            // Không nhập tên -> tìm trong mọi tài khoản đã đăng ký khuôn mặt, lấy người khớp nhất
            var candidates = await _db.Users.Where(u => u.FaceTemplate != null && u.Role != Roles.Child).ToListAsync();
            if (candidates.Count == 0)
                return BadRequest(new { message = "Chưa có tài khoản nào đăng ký khuôn mặt. " + HowToEnrollFace });
            var best = candidates
                .Select(u => (user: u, result: _face.Compare(u.FaceTemplate!, req.Features)))
                .OrderBy(x => x.result.distance).First();
            if (!best.result.match)
                return Unauthorized(new { message = "Không nhận ra khuôn mặt của tài khoản nào. Thử lại nơi đủ sáng, hoặc nhập tên đăng nhập.", distance = Math.Round(best.result.distance, 4) });
            user = best.user;
            distance = best.result.distance;
        }

        if (user.IsLocked) return StatusCode(403, new { message = "Tài khoản đã bị khóa." });

        user.LastLoginAt = DateTime.UtcNow;
        await _db.SaveChangesAsync();
        return Ok(ToAuth(user));
    }

    // ---------------- QUÊN MẬT KHẨU ----------------

    [HttpPost("forgot-password")]
    public async Task<IActionResult> ForgotPassword(ForgotPasswordRequest req)
    {
        var user = await _db.Users.FirstOrDefaultAsync(u => u.Email == req.Email.Trim().ToLower());
        // Không tiết lộ email có tồn tại hay không
        if (user == null) return Ok(new OtpStepResponse(true, MaskEmail(req.Email), "Nếu email tồn tại, mã OTP đã được gửi.", null));
        var (code, err) = await _otp.CreateAndSendAsync(user, OtpPurposes.ResetPassword);
        if (err != null) return BadRequest(new { message = err });
        return Ok(new OtpStepResponse(true, MaskEmail(user.Email), "Nếu email tồn tại, mã OTP đã được gửi.", Dev(code)));
    }

    [HttpPost("reset-password")]
    public async Task<IActionResult> ResetPassword(ResetPasswordRequest req)
    {
        var user = await _db.Users.FirstOrDefaultAsync(u => u.Email == req.Email.Trim().ToLower());
        if (user == null) return BadRequest(new { message = "Mã OTP không hợp lệ." });
        var err = await _otp.VerifyAsync(user.Id, OtpPurposes.ResetPassword, req.Code);
        if (err != null) return BadRequest(new { message = err });
        user.PasswordHash = BCrypt.Net.BCrypt.HashPassword(req.NewPassword);
        user.EmailConfirmed = true;
        await _db.SaveChangesAsync();
        return Ok(new { message = "Đổi mật khẩu thành công." });
    }

    // ---------------- TÀI KHOẢN CỦA TÔI ----------------

    [Authorize(Roles = "Admin,Staff,Parent")]
    [HttpGet("me")]
    public async Task<IActionResult> Me()
    {
        var u = await _db.Users.FindAsync(User.UserId());
        if (u == null) return Unauthorized();
        return Ok(new { u.Id, u.Username, u.Email, u.FullName, u.Phone, u.Role, hasFace = u.FaceTemplate != null, u.CreatedAt });
    }

    [Authorize(Roles = "Admin,Staff,Parent")]
    [HttpPut("me")]
    public async Task<IActionResult> UpdateMe(UpdateProfileRequest req)
    {
        var u = await _db.Users.FindAsync(User.UserId());
        if (u == null) return Unauthorized();
        u.FullName = req.FullName.Trim();
        u.Phone = req.Phone;
        await _db.SaveChangesAsync();
        return Ok(new { message = "Đã cập nhật thông tin." });
    }

    [Authorize(Roles = "Admin,Staff,Parent")]
    [HttpPost("change-password")]
    public async Task<IActionResult> ChangePassword(ChangePasswordRequest req)
    {
        var u = await _db.Users.FindAsync(User.UserId());
        if (u == null) return Unauthorized();
        if (!BCrypt.Net.BCrypt.Verify(req.OldPassword, u.PasswordHash))
            return BadRequest(new { message = "Mật khẩu cũ không đúng." });
        u.PasswordHash = BCrypt.Net.BCrypt.HashPassword(req.NewPassword);
        await _db.SaveChangesAsync();
        return Ok(new { message = "Đổi mật khẩu thành công." });
    }

    // ---------------- GHÉP MÁY CỦA TRẺ BẰNG QR ----------------

    /// <summary>Máy của trẻ quét QR do phụ huynh tạo để ghép thiết bị và nhận token vai trò Child.</summary>
    [HttpPost("pair-child")]
    public async Task<ActionResult<ChildAuthResponse>> PairChild(PairChildRequest req)
    {
        var code = req.Code.Trim();
        if (code.StartsWith("KIDGUARD:")) code = code["KIDGUARD:".Length..];

        var pc = await _db.PairingCodes.FirstOrDefaultAsync(p => p.Code == code);
        if (pc == null || pc.Used) return BadRequest(new { message = "Mã QR không hợp lệ hoặc đã được sử dụng." });
        if (pc.ExpiresAt < DateTime.UtcNow) return BadRequest(new { message = "Mã QR đã hết hạn. Hãy tạo mã mới." });

        var child = await _db.Children.Include(c => c.Parent).FirstOrDefaultAsync(c => c.Id == pc.ChildId);
        if (child == null) return BadRequest(new { message = "Không tìm thấy hồ sơ trẻ." });

        pc.Used = true;
        var device = new Device
        {
            ChildId = child.Id,
            DeviceName = string.IsNullOrWhiteSpace(req.DeviceName) ? "Điện thoại của " + child.Name : req.DeviceName!,
            Platform = req.Platform ?? "",
            LastSeenAt = DateTime.UtcNow
        };
        _db.Devices.Add(device);
        _db.Alerts.Add(new Alert { ChildId = child.Id, Type = "Info", Message = $"Đã ghép thiết bị mới: {device.DeviceName}" });
        await _db.SaveChangesAsync();

        return Ok(new ChildAuthResponse(_token.CreateChildToken(child, device), Roles.Child, child.Id, child.Name, child.Parent?.FullName ?? ""));
    }
}
