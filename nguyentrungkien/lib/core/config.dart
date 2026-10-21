/// Địa chỉ Web API nếu sau này đưa lên hosting (vd 'https://ten-mien-cua-ban'). Hiện chưa dùng.
/// Để trống ('') thì app tự tìm API chạy trên máy tính (USB / emulator / Wi-Fi).
const kPublicApiUrl = '';

/// Địa chỉ mặc định khi mới cài app.
String get kDefaultApiUrl => kPublicApiUrl.isNotEmpty ? kPublicApiUrl : 'http://10.0.2.2:5080';
