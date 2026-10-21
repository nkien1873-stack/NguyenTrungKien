# Cho điện thoại cùng mạng Wi-Fi kết nối tới API (chỉ cần chạy 1 lần trên mỗi máy tính chạy API).
# Mở: TCP 5080 (Web API) + UDP 5079 (app tự dò tìm máy chủ). Chỉ cho thiết bị trong cùng mạng nội bộ (LocalSubnet).
# Chạy: chuột phải > Run with PowerShell, hoặc  powershell -ExecutionPolicy Bypass -File mo-firewall.ps1
#       Gỡ bỏ:  powershell -ExecutionPolicy Bypass -File mo-firewall.ps1 -Remove
param([switch]$Remove)

# Cần quyền Administrator -> tự mở lại chính nó với quyền Admin (Windows sẽ hỏi)
$admin = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
if (-not $admin) {
    $argList = "-NoProfile -ExecutionPolicy Bypass -File `"$PSCommandPath`"" + $(if ($Remove) { " -Remove" } else { "" })
    Start-Process powershell -Verb RunAs -ArgumentList $argList
    return
}

$rules = @(
    @{ Name = "KidGuard API (TCP 5080)"; Protocol = "TCP"; Port = 5080 },
    @{ Name = "KidGuard tim may chu (UDP 5079)"; Protocol = "UDP"; Port = 5079 }
)
foreach ($r in $rules) {
    Remove-NetFirewallRule -DisplayName $r.Name -ErrorAction SilentlyContinue
    if (-not $Remove) {
        New-NetFirewallRule -DisplayName $r.Name -Direction Inbound -Action Allow -Protocol $r.Protocol `
            -LocalPort $r.Port -RemoteAddress LocalSubnet -Profile Any | Out-Null
    }
}

if ($Remove) {
    Write-Host "Đã gỡ quy tắc Firewall của KidGuard." -ForegroundColor Yellow
} else {
    Write-Host "Xong! Điện thoại cùng Wi-Fi giờ tự tìm và kết nối được API." -ForegroundColor Green
}
Read-Host "Nhấn Enter để đóng"
