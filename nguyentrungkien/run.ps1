# Chạy app KidGuard mà không cần gõ đường dẫn Flutter.
# Cách dùng: bấm đúp run.bat, hoặc:  powershell -ExecutionPolicy Bypass -File run.ps1 [tham số của flutter run]
#   -SetupOnly : chỉ tạo android/ios + pub get, không chạy app (setup.ps1 gọi chế độ này)
param([switch]$SetupOnly)
$FlutterArgs = $args
$ErrorActionPreference = "Stop"
Set-Location $PSScriptRoot
$pathFile = Join-Path $PSScriptRoot ".flutter_path"   # đường dẫn Flutter riêng của từng máy (không đưa lên git)

function Test-Flutter($dir) {
    if ($dir -and (Test-Path (Join-Path $dir "bin\flutter.bat"))) { return (Join-Path $dir "bin\flutter.bat") }
    return $null
}

function Find-Flutter {
    # 1. Đã có trong PATH
    $cmd = Get-Command flutter -ErrorAction SilentlyContinue
    if ($cmd) { return $cmd.Source }
    # 2. Đường dẫn đã lưu lần trước, hoặc biến FLUTTER_ROOT
    if (Test-Path $pathFile) { $f = Test-Flutter (Get-Content $pathFile -TotalCount 1).Trim(); if ($f) { return $f } }
    $f = Test-Flutter $env:FLUTTER_ROOT; if ($f) { return $f }
    # 3. Các chỗ hay cài
    $candidates = @(
        "$env:USERPROFILE\flutter", "$env:LOCALAPPDATA\flutter", "C:\flutter", "C:\src\flutter",
        "C:\tools\flutter", "D:\flutter", "D:\src\flutter"
    )
    foreach ($root in @("$env:USERPROFILE\Downloads", "C:\Downloads", "D:\Downloads", "D:\", "C:\")) {
        if (Test-Path $root) {
            Get-ChildItem $root -Directory -Filter "flutter*" -ErrorAction SilentlyContinue | ForEach-Object {
                $candidates += $_.FullName; $candidates += (Join-Path $_.FullName "flutter")
            }
        }
    }
    foreach ($c in $candidates) { $f = Test-Flutter $c; if ($f) { return $f } }
    # 4. Không tìm thấy: hỏi người dùng 1 lần rồi lưu lại
    Write-Host "Không tìm thấy Flutter SDK trên máy này." -ForegroundColor Yellow
    $dir = (Read-Host "Dán đường dẫn thư mục flutter (vd: C:\src\flutter)").Trim('" ')
    $f = Test-Flutter $dir
    if (-not $f) { throw "Không có bin\flutter.bat trong '$dir'." }
    return $f
}

$flutter = Find-Flutter
Set-Content -Path $pathFile -Value (Split-Path (Split-Path $flutter)) -Encoding utf8
Write-Host "==> Dùng Flutter: $flutter" -ForegroundColor Cyan

if (-not (Test-Path "android")) {
    Write-Host "==> Lần đầu: tạo thư mục android/ios (không ghi đè lib/)" -ForegroundColor Cyan
    & $flutter create --org com.nguyentrungkien --project-name nguyentrungkien --platforms android,ios .
    if ($LASTEXITCODE -ne 0) { throw "flutter create thất bại." }
    Copy-Item -Recurse -Force "platform_files\android\*" "android\"
    New-Item -ItemType Directory -Force "test" | Out-Null
    Copy-Item -Force "platform_files\test\widget_test.dart" "test\widget_test.dart"
}

# Dự án và pub cache nằm khác ổ đĩa -> cache incremental của Kotlin lỗi "different roots"
$props = "android\gradle.properties"
if (-not (Select-String -Path $props -Pattern "^kotlin.incremental=" -Quiet)) {
    Add-Content -Path $props -Value "kotlin.incremental=false" -Encoding ascii
}

Write-Host "==> flutter pub get" -ForegroundColor Cyan
& $flutter pub get
if ($LASTEXITCODE -ne 0) { throw "flutter pub get thất bại." }

if ($SetupOnly) { Write-Host "Xong! Chạy app bằng run.bat" -ForegroundColor Green; return }

# Điện thoại cắm USB: chuyển cổng 5080 của điện thoại về máy tính, để app dùng được http://localhost:5080
# (adb reverse mất mỗi khi rút cáp/khởi động lại adb, nên chạy lại mỗi lần)
$adb = @("$env:ANDROID_HOME", "$env:ANDROID_SDK_ROOT", "$env:LOCALAPPDATA\Android\Sdk") |
    Where-Object { $_ } | ForEach-Object { Join-Path $_ "platform-tools\adb.exe" } |
    Where-Object { Test-Path $_ } | Select-Object -First 1
if ($adb) {
    & $adb reverse tcp:5080 tcp:5080 2>$null | Out-Null
    if ($LASTEXITCODE -eq 0) { Write-Host "==> Đã nối cổng 5080 qua USB (trong app dùng http://localhost:5080)" -ForegroundColor Cyan }
}

Write-Host "==> flutter run (bấm r = hot reload, R = khởi động lại, q = thoát)" -ForegroundColor Cyan
& $flutter run @FlutterArgs
