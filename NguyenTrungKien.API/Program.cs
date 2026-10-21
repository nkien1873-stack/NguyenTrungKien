using System.Text;
using NguyenTrungKien.API.Data;
using NguyenTrungKien.API.Services;
using Microsoft.AspNetCore.Authentication.JwtBearer;
using Microsoft.AspNetCore.Diagnostics;
using Microsoft.EntityFrameworkCore;
using Microsoft.IdentityModel.Tokens;
using Microsoft.OpenApi.Models;

var builder = WebApplication.CreateBuilder(args);

// ---------- Cấu hình ----------
builder.Services.Configure<JwtOptions>(builder.Configuration.GetSection("Jwt"));
builder.Services.Configure<EmailOptions>(builder.Configuration.GetSection("Email"));
var jwt = builder.Configuration.GetSection("Jwt").Get<JwtOptions>() ?? new JwtOptions();
if (jwt.Key.Length < 32) throw new InvalidOperationException("Jwt:Key phải dài tối thiểu 32 ký tự (xem appsettings.json).");

// ---------- Database: SQL Server ----------
// Máy khác (máy thầy) có thể chỉ có SQL Express/LocalDB -> tự dò server dùng được
var connectionString = SqlServerLocator.Resolve(
    builder.Configuration.GetConnectionString("DefaultConnection") ?? "",
    builder.Configuration.GetValue<bool?>("Database:AutoDetectServer") ?? true,
    out var sqlMessage);
Console.WriteLine("[KidGuard] " + sqlMessage);
builder.Services.AddDbContext<AppDbContext>(opt => opt.UseSqlServer(connectionString));

// ---------- Services ----------
builder.Services.AddScoped<IEmailService, EmailService>();
builder.Services.AddScoped<OtpService>();
builder.Services.AddSingleton<TokenService>();
builder.Services.AddSingleton<FaceMatcher>();
// Điện thoại tự kết nối: tự "adb reverse" khi cắm USB + trả lời app dò tìm máy chủ qua Wi-Fi
builder.Services.AddHostedService<AdbReverseService>();
builder.Services.AddHostedService<LanDiscoveryService>();

// ---------- JWT ----------
builder.Services.AddAuthentication(JwtBearerDefaults.AuthenticationScheme)
    .AddJwtBearer(o =>
    {
        o.TokenValidationParameters = new TokenValidationParameters
        {
            ValidateIssuer = true,
            ValidateAudience = true,
            ValidateLifetime = true,
            ValidateIssuerSigningKey = true,
            ValidIssuer = jwt.Issuer,
            ValidAudience = jwt.Audience,
            IssuerSigningKey = new SymmetricSecurityKey(Encoding.UTF8.GetBytes(jwt.Key)),
            ClockSkew = TimeSpan.FromMinutes(1)
        };
    });
builder.Services.AddAuthorization();

builder.Services.AddCors(o => o.AddDefaultPolicy(p => p.AllowAnyOrigin().AllowAnyHeader().AllowAnyMethod()));
builder.Services.AddControllers();
builder.Services.AddEndpointsApiExplorer();
builder.Services.AddSwaggerGen(c =>
{
    c.SwaggerDoc("v1", new OpenApiInfo { Title = "NguyenTrungKien Web API", Version = "v1" });
    c.AddSecurityDefinition("Bearer", new OpenApiSecurityScheme
    {
        Name = "Authorization",
        Type = SecuritySchemeType.Http,
        Scheme = "bearer",
        BearerFormat = "JWT",
        In = ParameterLocation.Header,
        Description = "Dán JWT (không cần chữ Bearer)"
    });
    c.AddSecurityRequirement(new OpenApiSecurityRequirement
    {
        {
            new OpenApiSecurityScheme { Reference = new OpenApiReference { Type = ReferenceType.SecurityScheme, Id = "Bearer" } },
            Array.Empty<string>()
        }
    });
});

var app = builder.Build();

// ---------- Tạo database + dữ liệu mẫu ----------
using (var scope = app.Services.CreateScope())
{
    var db = scope.ServiceProvider.GetRequiredService<AppDbContext>();
    db.Database.EnsureCreated();
    DbSeeder.Seed(db);
}

// Lỗi không lường trước -> trả JSON { message } để app hiển thị
app.UseExceptionHandler(err => err.Run(async ctx =>
{
    var ex = ctx.Features.Get<IExceptionHandlerFeature>()?.Error;
    app.Logger.LogError(ex, "Unhandled error");
    ctx.Response.StatusCode = 500;
    await ctx.Response.WriteAsJsonAsync(new { message = "Lỗi máy chủ: " + ex?.Message });
}));

app.UseSwagger();
app.UseSwaggerUI();

app.UseCors();
app.UseStaticFiles();
app.UseAuthentication();
app.UseAuthorization();
app.MapControllers();
app.MapGet("/", () => Results.Redirect("/swagger"));
app.MapGet("/api/health", () => Results.Ok(new { status = "ok", app = "NguyenTrungKien", time = DateTime.UtcNow }));

app.Run();
