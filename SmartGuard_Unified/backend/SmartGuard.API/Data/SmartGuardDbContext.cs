using Microsoft.EntityFrameworkCore;
using SmartGuard.API.Models;

namespace SmartGuard.API.Data
{
    public class SmartGuardDbContext : DbContext
    {
        public SmartGuardDbContext(DbContextOptions<SmartGuardDbContext> options) : base(options)
        {
        }

        public DbSet<User> Users => Set<User>();
        public DbSet<OtpChallenge> OtpChallenges => Set<OtpChallenge>();
        public DbSet<Zone> Zones => Set<Zone>();
        public DbSet<GuardDevice> Devices => Set<GuardDevice>();
        public DbSet<MemberAccess> MemberAccesses => Set<MemberAccess>();
        public DbSet<AlertEvent> AlertEvents => Set<AlertEvent>();
        public DbSet<EvidenceImage> EvidenceImages => Set<EvidenceImage>();
        public DbSet<AdaptiveProfile> AdaptiveProfiles => Set<AdaptiveProfile>();
        public DbSet<AdaptiveZoneRule> AdaptiveZoneRules => Set<AdaptiveZoneRule>();

        protected override void OnModelCreating(ModelBuilder modelBuilder)
        {
            base.OnModelCreating(modelBuilder);

            modelBuilder.Entity<User>()
                .HasIndex(u => u.Email)
                .IsUnique();

            modelBuilder.Entity<User>()
                .HasIndex(u => u.Username)
                .IsUnique();

            modelBuilder.Entity<GuardDevice>()
                .HasIndex(d => d.DeviceCode)
                .IsUnique();

            modelBuilder.Entity<MemberAccess>()
                .HasOne(m => m.MemberUser)
                .WithMany()
                .HasForeignKey(m => m.MemberUserId)
                .OnDelete(DeleteBehavior.Restrict);

            modelBuilder.Entity<MemberAccess>()
                .HasOne(m => m.Device)
                .WithMany()
                .HasForeignKey(m => m.DeviceId)
                .OnDelete(DeleteBehavior.Cascade);

            modelBuilder.Entity<AlertEvent>()
                .HasOne(a => a.Device)
                .WithMany(d => d.AlertEvents)
                .HasForeignKey(a => a.DeviceId)
                .OnDelete(DeleteBehavior.Cascade);
        }
    }
}
