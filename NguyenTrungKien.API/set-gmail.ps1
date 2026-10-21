# Bật gửi OTP qua Gmail thật. Mật khẩu lưu bằng User Secrets (ngoài thư mục dự án), không nằm trong appsettings.json.
# Chạy:  powershell -ExecutionPolicy Bypass -File set-gmail.ps1        (bật email thật)
#        powershell -ExecutionPolicy Bypass -File set-gmail.ps1 -Off   (về chế độ demo, xóa mật khẩu đã lưu)
param([switch]$Off)
$ErrorActionPreference = "Stop"
Set-Location $PSScriptRoot

if ($Off) {
    dotnet user-secrets clear | Out-Null
    Write-Host "Đã về chế độ demo (OTP hiện trên console và trên app)." -ForegroundColor Yellow
    return
}

Write-Host "Cần Mật khẩu ứng dụng của Gmail (KHÔNG phải mật khẩu Gmail thường):" -ForegroundColor Cyan
Write-Host "  Tài khoản Google > Bảo mật > bật Xác minh 2 bước > tìm 'Mật khẩu ứng dụng' > tạo > được 16 ký tự."
$user = (Read-Host "Gmail dùng để gửi (vd: ban@gmail.com)").Trim()
$sec = Read-Host "Mật khẩu ứng dụng 16 ký tự (gõ sẽ không hiện)" -AsSecureString
$pass = [Runtime.InteropServices.Marshal]::PtrToStringAuto([Runtime.InteropServices.Marshal]::SecureStringToBSTR($sec)) -replace '\s', ''
if ($user -notmatch '^[^@\s]+@[^@\s]+$') { throw "Email không hợp lệ: $user" }
if ($pass.Length -ne 16) { throw "Mật khẩu ứng dụng phải đúng 16 ký tự (bạn nhập $($pass.Length))." }

dotnet user-secrets set "Email:Enabled" "true" | Out-Null
dotnet user-secrets set "Email:UserName" $user | Out-Null
dotnet user-secrets set "Email:Password" $pass | Out-Null
dotnet user-secrets set "Email:ReturnOtpInResponse" "false" | Out-Null
$pass = $null

Write-Host "Xong! Khởi động lại API (Stop rồi F5 trong Visual Studio) để áp dụng. OTP sẽ gửi từ $user." -ForegroundColor Green
