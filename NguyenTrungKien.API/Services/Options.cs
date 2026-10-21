namespace NguyenTrungKien.API.Services;

public class JwtOptions
{
    public string Key { get; set; } = "";
    public string Issuer { get; set; } = "NguyenTrungKien";
    public string Audience { get; set; } = "NguyenTrungKien.App";
    public int ExpireHours { get; set; } = 24;
    /// <summary>Token của máy trẻ sống lâu hơn (ngày).</summary>
    public int ChildExpireDays { get; set; } = 180;
}

public class EmailOptions
{
    /// <summary>false = không gửi mail thật, mã OTP in ra console (chế độ demo).</summary>
    public bool Enabled { get; set; }
    public string Host { get; set; } = "smtp.gmail.com";
    public int Port { get; set; } = 587;
    public string UserName { get; set; } = "";
    public string Password { get; set; } = "";
    public string FromName { get; set; } = "KidGuard";
    public string FromEmail { get; set; } = "";
    /// <summary>Trả mã OTP trong response để test khi chưa cấu hình SMTP. TẮT khi nộp bài/thuyết trình thật.</summary>
    public bool ReturnOtpInResponse { get; set; }
}
