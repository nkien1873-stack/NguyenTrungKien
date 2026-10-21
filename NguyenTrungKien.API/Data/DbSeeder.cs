using NguyenTrungKien.API.Models;

namespace NguyenTrungKien.API.Data;

/// <summary>Tạo dữ liệu mẫu lần đầu chạy để cả nhóm đăng nhập thử ngay.</summary>
public static class DbSeeder
{
    public static void Seed(AppDbContext db)
    {
        if (db.Users.Any()) return;

        var admin = new User
        {
            Username = "admin", Email = "admin@kidguard.local", FullName = "Quản trị viên",
            Role = Roles.Admin, EmailConfirmed = true,
            PasswordHash = BCrypt.Net.BCrypt.HashPassword("Admin@123")
        };
        var staff = new User
        {
            Username = "staff", Email = "staff@kidguard.local", FullName = "Nhân viên hỗ trợ",
            Role = Roles.Staff, EmailConfirmed = true,
            PasswordHash = BCrypt.Net.BCrypt.HashPassword("Staff@123")
        };
        var parent = new User
        {
            Username = "phuhuynh", Email = "phuhuynh@kidguard.local", FullName = "Phụ huynh Demo",
            Phone = "0900000000", Role = Roles.Parent, EmailConfirmed = true,
            PasswordHash = BCrypt.Net.BCrypt.HashPassword("Parent@123")
        };
        db.Users.AddRange(admin, staff, parent);
        db.SaveChanges();

        var child = new ChildProfile
        {
            ParentId = parent.Id, Name = "Bé Na", BirthDate = new DateTime(2015, 6, 1),
            DailyLimitMinutes = 90, BonusMinutes = 20, AvatarColor = "#FF8A4C", BedTime = "21:00"
        };
        db.Children.Add(child);
        db.SaveChanges();

        db.SafeZones.AddRange(
            new SafeZone { ChildId = child.Id, Name = "Nhà", Latitude = 10.7769, Longitude = 106.7009, RadiusMeters = 150 },
            new SafeZone { ChildId = child.Id, Name = "Trường học", Latitude = 10.7626, Longitude = 106.6822, RadiusMeters = 250 });

        db.AppRules.AddRange(
            new AppRule { ChildId = child.Id, AppName = "YouTube", Category = "Giải trí", DailyLimitMinutes = 45 },
            new AppRule { ChildId = child.Id, AppName = "TikTok", Category = "Mạng xã hội", IsBlocked = true },
            new AppRule { ChildId = child.Id, AppName = "Duolingo", Category = "Học tập", DailyLimitMinutes = 0 });

        db.RewardTasks.AddRange(
            new RewardTask { ChildId = child.Id, Title = "Làm xong bài tập Toán", RewardMinutes = 20, DueDate = DateTime.UtcNow.AddDays(1) },
            new RewardTask { ChildId = child.Id, Title = "Dọn góc học tập", Description = "Chụp ảnh bàn học gọn gàng", RewardMinutes = 15 });

        db.LocationLogs.Add(new LocationLog { ChildId = child.Id, Latitude = 10.7772, Longitude = 106.7012, BatteryLevel = 76 });

        db.SupportTickets.Add(new SupportTicket
        {
            ParentId = parent.Id, Subject = "Không ghép được máy của con",
            Content = "Quét mã QR báo hết hạn, nhờ hỗ trợ.", Priority = "High"
        });

        db.SaveChanges();
    }
}
