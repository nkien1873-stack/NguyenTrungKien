using NguyenTrungKien.API.Models;
using Microsoft.EntityFrameworkCore;

namespace NguyenTrungKien.API.Data;

public class AppDbContext : DbContext
{
    public AppDbContext(DbContextOptions<AppDbContext> options) : base(options) { }

    public DbSet<User> Users => Set<User>();
    public DbSet<ChildProfile> Children => Set<ChildProfile>();
    public DbSet<Device> Devices => Set<Device>();
    public DbSet<PairingCode> PairingCodes => Set<PairingCode>();
    public DbSet<LocationLog> LocationLogs => Set<LocationLog>();
    public DbSet<SafeZone> SafeZones => Set<SafeZone>();
    public DbSet<AppRule> AppRules => Set<AppRule>();
    public DbSet<RewardTask> RewardTasks => Set<RewardTask>();
    public DbSet<WalletTransaction> WalletTransactions => Set<WalletTransaction>();
    public DbSet<Alert> Alerts => Set<Alert>();
    public DbSet<SupportTicket> SupportTickets => Set<SupportTicket>();
    public DbSet<OtpCode> OtpCodes => Set<OtpCode>();

    protected override void OnModelCreating(ModelBuilder b)
    {
        b.Entity<User>(e =>
        {
            e.HasIndex(x => x.Username).IsUnique();
            e.HasIndex(x => x.Email).IsUnique();
        });

        b.Entity<ChildProfile>()
            .HasOne(c => c.Parent).WithMany(u => u.Children)
            .HasForeignKey(c => c.ParentId).OnDelete(DeleteBehavior.Cascade);

        b.Entity<Device>()
            .HasOne(d => d.Child).WithMany(c => c.Devices)
            .HasForeignKey(d => d.ChildId).OnDelete(DeleteBehavior.Cascade);

        b.Entity<SafeZone>()
            .HasOne(z => z.Child).WithMany(c => c.SafeZones)
            .HasForeignKey(z => z.ChildId).OnDelete(DeleteBehavior.Cascade);

        b.Entity<AppRule>()
            .HasOne(r => r.Child).WithMany(c => c.AppRules)
            .HasForeignKey(r => r.ChildId).OnDelete(DeleteBehavior.Cascade);

        b.Entity<RewardTask>()
            .HasOne(t => t.Child).WithMany(c => c.Tasks)
            .HasForeignKey(t => t.ChildId).OnDelete(DeleteBehavior.Cascade);

        b.Entity<Alert>()
            .HasOne(a => a.Child).WithMany()
            .HasForeignKey(a => a.ChildId).OnDelete(DeleteBehavior.Cascade);

        b.Entity<LocationLog>(e =>
        {
            e.HasOne<ChildProfile>().WithMany().HasForeignKey(x => x.ChildId).OnDelete(DeleteBehavior.Cascade);
            e.HasIndex(x => new { x.ChildId, x.RecordedAt });
        });

        b.Entity<WalletTransaction>()
            .HasOne<ChildProfile>().WithMany().HasForeignKey(x => x.ChildId).OnDelete(DeleteBehavior.Cascade);

        b.Entity<PairingCode>(e =>
        {
            e.HasOne<ChildProfile>().WithMany().HasForeignKey(x => x.ChildId).OnDelete(DeleteBehavior.Cascade);
            e.HasIndex(x => x.Code).IsUnique();
        });

        b.Entity<OtpCode>()
            .HasOne<User>().WithMany().HasForeignKey(x => x.UserId).OnDelete(DeleteBehavior.Cascade);

        b.Entity<SupportTicket>(e =>
        {
            e.HasOne(t => t.Parent).WithMany()
                .HasForeignKey(t => t.ParentId).OnDelete(DeleteBehavior.Cascade);
            // SQL Server không cho 2 đường cascade từ cùng bảng Users -> dùng NoAction
            e.HasOne(t => t.AssignedStaff).WithMany()
                .HasForeignKey(t => t.AssignedStaffId).OnDelete(DeleteBehavior.NoAction);
        });
    }
}
