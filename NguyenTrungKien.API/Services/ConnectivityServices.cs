using System.Diagnostics;
using System.Net;
using System.Net.Sockets;
using System.Text;
using Microsoft.AspNetCore.Hosting.Server;
using Microsoft.AspNetCore.Hosting.Server.Features;

namespace NguyenTrungKien.API.Services;

/// <summary>Cổng HTTP thật mà API đang nghe (đọc từ Kestrel), mặc định 5080.</summary>
public static class ApiPort
{
    public static int Get(IServer server)
    {
        var addresses = server.Features.Get<IServerAddressesFeature>()?.Addresses ?? [];
        foreach (var a in addresses)
        {
            if (Uri.TryCreate(a.Replace("0.0.0.0", "localhost").Replace("[::]", "localhost").Replace("*", "localhost").Replace("+", "localhost"),
                    UriKind.Absolute, out var uri) && uri.Scheme == "http")
                return uri.Port;
        }
        return 5080;
    }
}

/// <summary>
/// Trả lời app khi app dò tìm máy chủ trong mạng Wi-Fi (UDP broadcast).
/// App gửi "KIDGUARD_DISCOVER" tới cổng 5079 -> API trả "KIDGUARD_API|NguyenTrungKien|5080".
/// Nhờ vậy điện thoại tự tìm ra IP máy tính, không cần nhập tay.
/// </summary>
public class LanDiscoveryService : BackgroundService
{
    public const string Request = "KIDGUARD_DISCOVER";
    private readonly IServer _server;
    private readonly ILogger<LanDiscoveryService> _log;
    private readonly int _port;

    public LanDiscoveryService(IServer server, IConfiguration config, ILogger<LanDiscoveryService> log)
    {
        _server = server;
        _log = log;
        _port = config.GetValue<int?>("Connectivity:DiscoveryPort") ?? 5079;
    }

    protected override async Task ExecuteAsync(CancellationToken ct)
    {
        UdpClient udp;
        try
        {
            udp = new UdpClient(new IPEndPoint(IPAddress.Any, _port)) { EnableBroadcast = true };
        }
        catch (SocketException ex)
        {
            _log.LogWarning("Không mở được cổng dò tìm UDP {Port} ({Error}). App sẽ không tự tìm được máy chủ qua Wi-Fi.", _port, ex.Message);
            return;
        }
        _log.LogInformation("Đang chờ app dò tìm máy chủ qua Wi-Fi (UDP {Port}). Nếu điện thoại không tìm thấy, chạy mo-firewall.ps1.", _port);

        using (udp)
        {
            while (!ct.IsCancellationRequested)
            {
                try
                {
                    var msg = await udp.ReceiveAsync(ct);
                    if (Encoding.UTF8.GetString(msg.Buffer).Trim() != Request) continue;
                    var reply = Encoding.UTF8.GetBytes($"KIDGUARD_API|NguyenTrungKien|{ApiPort.Get(_server)}");
                    await udp.SendAsync(reply, msg.RemoteEndPoint, ct);
                    _log.LogInformation("App ở {Ip} đã tìm thấy máy chủ qua Wi-Fi", msg.RemoteEndPoint.Address);
                }
                catch (OperationCanceledException) { break; }
                catch (SocketException) { /* gói lỗi -> bỏ qua, nghe tiếp */ }
            }
        }
    }
}

/// <summary>
/// Điện thoại cắm USB: tự chạy "adb reverse tcp:5080 tcp:5080" mỗi khi phát hiện máy mới cắm vào,
/// để app trên điện thoại gọi được http://localhost:5080. Rút cáp cắm lại cũng tự nối lại.
/// </summary>
public class AdbReverseService : BackgroundService
{
    private readonly IServer _server;
    private readonly ILogger<AdbReverseService> _log;
    private readonly bool _enabled;

    public AdbReverseService(IServer server, IConfiguration config, ILogger<AdbReverseService> log)
    {
        _server = server;
        _log = log;
        _enabled = config.GetValue<bool?>("Connectivity:AdbReverse") ?? true;
    }

    private static string? FindAdb()
    {
        var exe = OperatingSystem.IsWindows() ? "adb.exe" : "adb";
        var home = Environment.GetFolderPath(Environment.SpecialFolder.UserProfile);
        string?[] roots =
        [
            Environment.GetEnvironmentVariable("ANDROID_HOME"),
            Environment.GetEnvironmentVariable("ANDROID_SDK_ROOT"),
            Path.Combine(Environment.GetFolderPath(Environment.SpecialFolder.LocalApplicationData), "Android", "Sdk"),
            Path.Combine(home, "Library", "Android", "sdk"), // macOS
            Path.Combine(home, "Android", "Sdk"),            // Linux
        ];
        return roots.Where(r => !string.IsNullOrEmpty(r))
            .Select(r => Path.Combine(r!, "platform-tools", exe))
            .FirstOrDefault(File.Exists);
    }

    private static async Task<(int code, string output)> Run(string adb, string args, CancellationToken ct)
    {
        using var p = Process.Start(new ProcessStartInfo(adb, args)
        {
            RedirectStandardOutput = true,
            RedirectStandardError = true,
            UseShellExecute = false,
            CreateNoWindow = true
        })!;
        var output = await p.StandardOutput.ReadToEndAsync(ct);
        await p.WaitForExitAsync(ct);
        return (p.ExitCode, output);
    }

    protected override async Task ExecuteAsync(CancellationToken ct)
    {
        if (!_enabled) return;
        var adb = FindAdb();
        if (adb == null)
        {
            _log.LogInformation("Không thấy adb (Android SDK) -> bỏ qua tự nối USB. Dùng Wi-Fi hoặc emulator.");
            return;
        }

        while (!ct.IsCancellationRequested)
        {
            try
            {
                var (_, list) = await Run(adb, "devices", ct);
                var online = list.Split('\n').Skip(1)
                    .Select(l => l.Trim().Split('\t'))
                    .Where(c => c.Length == 2 && c[1] == "device")
                    .Select(c => c[0]).ToHashSet();

                // Kiểm tra từng máy: chưa có (mới cắm, hoặc adb vừa khởi động lại làm mất) thì nối lại
                var port = ApiPort.Get(_server);
                foreach (var serial in online)
                {
                    var (_, current) = await Run(adb, $"-s {serial} reverse --list", ct);
                    if (current.Contains($"tcp:{port} tcp:{port}")) continue;
                    var (code, _) = await Run(adb, $"-s {serial} reverse tcp:{port} tcp:{port}", ct);
                    if (code == 0)
                        _log.LogInformation("Đã nối USB cho điện thoại {Serial}: app dùng được http://localhost:{Port}", serial, port);
                }
            }
            catch (OperationCanceledException) { break; }
            catch (Exception ex)
            {
                _log.LogDebug(ex, "adb lỗi, thử lại sau");
            }

            try { await Task.Delay(TimeSpan.FromSeconds(5), ct); }
            catch (OperationCanceledException) { break; }
        }
    }
}
