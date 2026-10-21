# NguyenTrungKien – App quản lý điện thoại trẻ em

Đề 1 – Lập trình di động. Gồm 3 phần:

| Thư mục | Nội dung |
|---|---|
| `NguyenTrungKien.API/` | Web API ASP.NET Core 8 + Entity Framework Core + JWT |
| `database/DB_NguyenTrungKien.sql` | Script tạo CSDL SQL Server `DB_NguyenTrungKien` |
| `nguyentrungkien/` | App di động Flutter |

**Tên cá nhân: Nguyễn Trung Kiên**
- Project / solution: `NguyenTrungKien`
- Web API: `NguyenTrungKien.API` (namespace `NguyenTrungKien.API`)
- Cơ sở dữ liệu: `DB_NguyenTrungKien`
- App Flutter: `nguyentrungkien` (package Android `com.nguyentrungkien.nguyentrungkien`)

---

## 1. Đối chiếu yêu cầu đề bài

| # | Yêu cầu | Đã làm | Nằm ở đâu |
|---|---|---|---|
| 1 | Đăng ký qua email | Đăng ký phụ huynh → OTP 6 số gửi email → kích hoạt | `AuthController.Register / VerifyEmail`, `register_screen.dart`, `otp_screen.dart` |
| 2 | Đăng nhập tên đăng nhập + mật khẩu + OTP | Bước 1 kiểm tra mật khẩu (BCrypt) → gửi OTP; bước 2 nhập OTP → JWT. OTP băm SHA-256, hết hạn 5 phút, tối đa 5 lần sai, chờ 60s mới gửi lại | `AuthController.Login / VerifyLoginOtp`, `OtpService.cs` |
| 3 | Phân quyền | **Admin** → Trang quản trị · **Staff** (nhân viên hỗ trợ) → Dashboard nhân viên · **Parent** (khách hàng) → Trang phụ huynh · **Child** (máy của trẻ) → Màn hình trẻ em. API chặn bằng `[Authorize(Roles=...)]` | `screens/router.dart` (`homeFor`), các Controller |
| 4 | CRUD | Admin: người dùng · Phụ huynh: hồ sơ trẻ, vùng an toàn, quy tắc ứng dụng, nhiệm vụ, cảnh báo, yêu cầu hỗ trợ · Nhân viên: xử lý ticket | `Controllers/*.cs`, `screens/admin`, `screens/parent`, `screens/staff` |
| 5a | Đăng nhập khuôn mặt | Camera + Google ML Kit lấy điểm mốc khuôn mặt → vector đặc trưng → server so khớp. Chỉ **1 bước**: nhìn thẳng, bấm Chụp. App tự chụp vài ảnh liên tiếp và dùng ảnh rõ mặt | `face_capture_screen.dart`, `face_features.dart`, `FaceMatcher.cs` |
| 5b | Chia sẻ vị trí | Máy trẻ gửi GPS + pin mỗi 30s; phụ huynh xem bản đồ tự làm mới 10s, lộ trình 24h, **vùng an toàn** (ra/vào vùng → cảnh báo), nút **SOS** | `child_home.dart`, `map_tab.dart`, `zone_form_screen.dart`, `ChildDeviceController.cs` |
| 5e | QR + vân tay | Ghép máy trẻ bằng **mã QR** (hết hạn 10 phút, dùng 1 lần) · **Vân tay** để khóa app, duyệt cộng phút, xóa hồ sơ, thoát chế độ trẻ em | `pair_qr_screen.dart`, `child_pair_screen.dart`, `biometric.dart` |
| 6 | Tính năng mới | **Ví thời gian**: bố mẹ giao nhiệm vụ đời thực → trẻ chụp ảnh minh chứng → bố mẹ duyệt bằng vân tay → phút thưởng vào ví → trẻ tự chọn lúc dùng | `TasksController.cs`, `tasks_tab.dart`, tab Nhiệm vụ của trẻ |
| 7 | Giao diện, cả nhóm chạy được | Material 3, màu riêng cho từng vai trò; màn hình **Cấu hình máy chủ** để mỗi người tự nhập IP; dữ liệu mẫu tự sinh | `theme.dart`, `server_settings_screen.dart`, `DbSeeder.cs` |

**Vì sao "Ví thời gian" là tính năng mới:** Google Family Link, Kaspersky Safe Kids, Qustodio cho phụ huynh *cộng giờ thủ công* hoặc trẻ *xin thêm giờ*. Các app này không gắn thời gian màn hình với **việc làm có minh chứng ảnh**, cũng không có **ví tích lũy** để trẻ tự quyết lúc dùng. KidGuard biến thời gian dùng máy thành phần thưởng cho hành vi tốt, thay vì chỉ cấm đoán.

---

## 2. Cài đặt

### Yêu cầu
- Visual Studio 2022 (hoặc .NET 8 SDK) + SQL Server (Express/Developer) + SSMS
- Flutter SDK ≥ 3.27, Android Studio, emulator hoặc điện thoại Android **có vân tay**

### 2.1. Web API
1. Mở `NguyenTrungKien.sln` bằng Visual Studio.
2. Sửa `appsettings.json` → `ConnectionStrings:DefaultConnection` nếu SQL Server không phải `localhost`
   (SQL Express: `Server=.\\SQLEXPRESS;...`).
3. Chạy (F5). Lần đầu chạy, API **tự tạo database `DB_NguyenTrungKien` và dữ liệu mẫu**. Swagger mở ở `http://localhost:5080/swagger`.
4. Điện thoại thật qua Wi-Fi: chạy `mo-firewall.ps1` 1 lần (mở cổng 5080 + 5079, xem mục 2.3). Cắm USB thì không cần.

### 2.2. Gửi OTP qua Gmail thật
Mặc định `Email:Enabled=false` (chế độ demo): OTP in ra cửa sổ console của API và hiện trên app để test nhanh.
Khi demo cho giảng viên:
1. Gmail → Quản lý tài khoản Google → Bảo mật → bật Xác minh 2 bước → **Mật khẩu ứng dụng** → tạo mật khẩu 16 ký tự.
2. Trong thư mục `NguyenTrungKien.API`, chạy rồi nhập Gmail và mật khẩu 16 ký tự:
   `powershell -ExecutionPolicy Bypass -File set-gmail.ps1`
   Mật khẩu lưu bằng **User Secrets** (ngoài thư mục dự án), không nằm trong `appsettings.json`, nên nộp bài hay gửi code cho bạn cũng không lộ.
3. Khởi động lại API. Muốn về chế độ demo: `set-gmail.ps1 -Off`.

**Tạm tắt OTP khi đăng nhập** (chỉ để thử nhanh trên máy mình; **đề bài yêu cầu có OTP**, nên trước khi demo phải bật lại). Chạy trong thư mục `NguyenTrungKien.API`, rồi khởi động lại API:
- Tắt: `dotnet user-secrets set "Auth:LoginOtp" "false"`, đúng mật khẩu là vào app luôn.
- Bật lại: `dotnet user-secrets set "Auth:LoginOtp" "true"`. Mặc định trong `appsettings.json` là `true`, nên người khác chạy code của bạn vẫn có OTP.

Nếu Gmail từ chối, app sẽ báo *"Gmail từ chối đăng nhập. Kiểm tra … Mật khẩu ứng dụng"*. Lỗi này thường do dùng mật khẩu Gmail thường thay cho Mật khẩu ứng dụng.

### 2.3. App Flutter
Mở emulator (hoặc cắm điện thoại), rồi **bấm đúp `nguyentrungkien\run.bat`**. Không cần cài Flutter vào PATH:
- Script tự tìm Flutter SDK (PATH, `FLUTTER_ROOT`, `C:\src\flutter`, `Downloads\flutter*`…). Không thấy thì hỏi đường dẫn **một lần** rồi lưu vào `.flutter_path`.
- Lần đầu tự tạo `android/ios`, chép `AndroidManifest.xml` (quyền GPS, camera, vân tay) và `MainActivity` (`FlutterFragmentActivity`, bắt buộc cho vân tay), rồi `pub get` và `flutter run`.

Từ terminal: `.\run.bat` (có thể thêm tham số của `flutter run`, vd `.\run.bat -d emulator-5554`).

**App tự tìm máy chủ, thường không cần nhập địa chỉ.** Khi mở app hoặc khi mất kết nối, app lần lượt thử:
1. **USB:** `http://localhost:5080`. API tự chạy `adb reverse` mỗi khi phát hiện điện thoại cắm vào (rút ra cắm lại vẫn tự nối).
2. **Emulator:** `http://10.0.2.2:5080`.
3. **Wi-Fi:** gửi tín hiệu dò tìm trong mạng (UDP 5079). Máy tính chạy API trả lời, app tự lấy IP.

Tìm được thì app lưu lại và gửi lại yêu cầu đang làm dở.

**Dùng Wi-Fi (không cắm cáp):** điện thoại và máy tính cùng mạng Wi-Fi. Trên **mỗi máy tính chạy API**, chạy **1 lần**:
`NguyenTrungKien.API\mo-firewall.ps1` (chuột phải > Run with PowerShell, Windows hỏi quyền Admin).
Script mở TCP 5080 + UDP 5079 và chỉ cho thiết bị trong mạng nội bộ. Gỡ bằng `mo-firewall.ps1 -Remove`.
Lưu ý: Wi-Fi công cộng hoặc Wi-Fi trường có thể chặn các máy nói chuyện với nhau. Khi đó dùng USB, hoặc phát hotspot từ điện thoại cho máy tính bắt.

Muốn nhập tay: bấm ⚙ ở màn hình đăng nhập (có nút **Tự tìm máy chủ**), nhập `http://<IPv4 máy tính>:5080` (xem IP bằng `ipconfig`).

**iOS** (nếu nhóm có máy Mac): thêm vào `ios/Runner/Info.plist` các key `NSCameraUsageDescription`, `NSLocationWhenInUseUsageDescription`, `NSFaceIDUsageDescription`, `NSPhotoLibraryUsageDescription`, và đặt `platform :ios, '15.5'` trong `ios/Podfile`.

### 2.4. Máy khác chạy được ngay (máy thầy)
- Chỉ cần **.NET 8 trở lên** (máy chỉ có .NET 9/10 cũng chạy) và **một trong**: SQL Server, SQL Express, hoặc LocalDB (có sẵn khi cài Visual Studio).
- API **tự dò SQL Server**: thử `localhost`, không được thì `.\SQLEXPRESS`, rồi `(localdb)\MSSQLLocalDB`. Cửa sổ API in ra server đang dùng. CSDL `DB_NguyenTrungKien` và dữ liệu mẫu tự tạo.
- Không cần Gmail: mặc định OTP **hiện ngay trên app** (chế độ demo), đăng nhập vẫn qua OTP như đề yêu cầu.

### 2.5. Trước khi nộp bài
- Xóa các thư mục `bin`, `obj`, `.vs`, `nguyentrungkien/build`, `nguyentrungkien/.dart_tool` cho nhẹ.
- Nếu lúc thử bạn đã tắt OTP đăng nhập thì bật lại: `dotnet user-secrets set "Auth:LoginOtp" "true"`.

### Tài khoản mẫu
| Vai trò | Tên đăng nhập | Mật khẩu |
|---|---|---|
| Admin | `admin` | `Admin@123` |
| Nhân viên | `staff` | `Staff@123` |
| Phụ huynh | `phuhuynh` | `Parent@123` |

Email của tài khoản mẫu là giả, nên OTP chỉ xem được ở chế độ demo. Khi demo email thật, hãy **đăng ký tài khoản mới bằng email của bạn**.

---

## 3. Kịch bản demo với 1 điện thoại (khoảng 15 phút)

Một điện thoại **đổi vai**: làm **máy bố mẹ**, rồi ghép thành **máy của con**, rồi thoát (bằng vân tay bố mẹ) để quay về máy bố mẹ xem kết quả. Máy tính chiếu **Gmail** để lấy OTP.
Thứ tự đã sắp để chỉ đổi vai **2 lần**, và việc làm ở vai này có kết quả dùng ngay ở vai sau.

### 3.0. Chuẩn bị (trước giờ demo, không chiếu)
1. Chạy API (F5). Cắm USB điện thoại vào máy tính (hoặc cùng Wi-Fi, máy tính đã chạy `mo-firewall.ps1`). Mở app; không kết nối được thì bấm ⚙ → **Tự tìm máy chủ**.
2. Đã chạy `set-gmail.ps1`. Email của `admin` và `staff` đã đổi sang bí danh Gmail của bạn (`...+admin@gmail.com`, `...+staff@gmail.com`) để nhận được OTP.
3. Điện thoại **đã cài vân tay**. Bật GPS. Trong thư viện ảnh có sẵn 1 ảnh "bàn học gọn gàng" để dùng nếu camera kém.
4. Xóa tài khoản test cũ để demo đăng ký từ đầu.

### Vai 1: MÁY BỐ MẸ
**3.1. Đăng ký qua email (Mục 1)**
1. *Đăng ký bằng email*, điền thông tin + **email thật** → **Đăng ký**.
2. Chiếu Gmail: thư *"[KidGuard] Xác thực email đăng ký"* → nhập 6 số → *"Xác thực email thành công"*.
   - Nói: OTP được **băm SHA-256** khi lưu, **hết hạn 5 phút**, **sai tối đa 5 lần**, phải chờ 60 giây mới gửi lại được.

**3.2. Đăng nhập tên + mật khẩu + OTP (Mục 2)**
1. Nhập **sai mật khẩu** → bị từ chối. Nhập đúng → **chưa vào ngay** mà chuyển sang màn hình OTP → lấy *"Mã đăng nhập"* trong Gmail → vào **Trang phụ huynh**.
2. App hỏi *"Đăng ký khuôn mặt?"* → **Đăng ký ngay** → nhìn thẳng → **Chụp** (dùng ở 3.7).

**3.3. CRUD (Mục 4)**
1. **Thêm hồ sơ con** "Bé An" → **Sửa** (đổi giờ ngủ).
2. Hồ sơ con → **Thêm vùng an toàn** "Nhà" → bấm **Vị trí của tôi** → Lưu. Vùng phải bao vị trí hiện tại để lát nữa máy con báo *"Đang ở: Nhà"*.
3. **Thêm quy tắc** "TikTok – Chặn" → **sửa** → **xóa**.
4. Tab **Nhiệm vụ** → **Giao nhiệm vụ** "Dọn bàn học" +15 phút.
5. Tài khoản → *Yêu cầu hỗ trợ* → gửi ticket "Hỏi cách ghép máy" (dùng ở 3.10).

**3.4. Tạo mã QR (Mục 5e)**
1. Hồ sơ con → **Ghép điện thoại của con** → hiện **QR** và đếm ngược 10 phút.
   - Nói: QR **dùng 1 lần**, quá 10 phút thì hết hạn. Có 2 máy thì máy con quét QR; demo 1 máy nên dùng **mã chữ** in ngay dưới QR (mã giống hệt).
2. **Chạm vào mã chữ** để sao chép → quay lại → Tài khoản → **Đăng xuất**.

### Vai 2: MÁY CỦA CON
**3.5. Ghép máy + chia sẻ vị trí + SOS (Mục 5e, 5b)**
1. Màn hình đăng nhập → **Đây là điện thoại của con?** → màn hình quét QR mở camera (cho thấy chức năng quét) → **Nhập mã thủ công** → dán mã → **Ghép**.
2. Vào **chế độ trẻ em**: *"Đang chia sẻ vị trí với bố mẹ… Đang ở: Nhà"* (gửi GPS + pin mỗi 30 giây).
3. Bấm **SOS** → **GỬI SOS** → *"Đã gửi tín hiệu SOS tới phụ huynh"*.

**3.6. Con làm nhiệm vụ (Mục 6)**
1. Tab **Nhiệm vụ** → "Dọn bàn học" → **Chụp ảnh minh chứng** (camera kém thì **Chọn từ thư viện**) → lời nhắn → **Gửi**.
2. Tab **Của con**: Ví thời gian đang **0 phút**.
3. **Nhấn giữ avatar** → *Xác thực* → **quét vân tay bố mẹ** → thoát chế độ trẻ em (Mục 5e: chỉ bố mẹ mới gỡ được máy).

### Vai 3: QUAY LẠI MÁY BỐ MẸ
**3.7. Đăng nhập bằng khuôn mặt (Mục 5a)**
1. **Để trống tên đăng nhập** → **Đăng nhập bằng khuôn mặt** → nhìn thẳng → **Chụp** → app **tự nhận ra tài khoản** và vào thẳng, không cần mật khẩu, không cần OTP.
2. *(Tùy chọn)* Cho bạn khác thử → *"Không nhận ra khuôn mặt…"*.

**3.8. Bố mẹ nhận kết quả (Mục 5b)**
1. Vừa vào app đã bật popup **CẢNH BÁO SOS** (SOS bấm ở 3.5) → *Xem cảnh báo*: SOS + *"Đã ghép thiết bị mới"*, kèm vị trí.
2. Tab **Bản đồ**: avatar của con ở **vị trí thật**, bật **Lộ trình 24h**.
3. Hồ sơ con: thiết bị đã ghép, **mức pin**, *"Hoạt động … trước"*.
   - Nói: con **ra khỏi vùng an toàn** hoặc **pin dưới 15%** thì bố mẹ cũng nhận cảnh báo (demo 1 máy đứng yên nên chỉ nói, không diễn).

**3.9. Duyệt nhiệm vụ bằng vân tay (Mục 6 + 5e)**
1. Tab **Nhiệm vụ** → *Chờ duyệt* → mở → thấy **ảnh minh chứng + lời nhắn** → **Duyệt** → **quét vân tay** → *"Đã duyệt, cộng 15 phút"*.
2. Hồ sơ con: **Ví thời gian 15 phút**.
   - Nói: Family Link, Qustodio chỉ cho bố mẹ *cộng giờ thủ công*. KidGuard gắn thời gian màn hình với **việc tốt có ảnh minh chứng**, có **ví** để con tự quyết lúc dùng, và bố mẹ duyệt bằng vân tay nên con không tự duyệt được.
3. Tài khoản → bật **Khóa ứng dụng bằng vân tay** → thoát hẳn app, mở lại → phải quét vân tay (Mục 5e).

### Vai 4: NHÂN VIÊN và ADMIN (Mục 3 + 4)
**3.10. Phân quyền**
1. Đăng xuất → đăng nhập `staff` (OTP về Gmail) → **Dashboard nhân viên** → mở ticket ở 3.3 → trả lời → *Đã xong*.
2. Đăng xuất → đăng nhập `admin` → **Trang quản trị**: thống kê người dùng, thiết bị, SOS hôm nay.
3. Tab **Người dùng**: **thêm** nhân viên → **sửa** → **khóa** → **xóa**.
   - Nói: mỗi vai trò vào một trang riêng. API kiểm tra quyền ở từng hàm (`[Authorize(Roles=...)]`), phụ huynh gọi API của admin sẽ nhận **403**. Có thể mở Swagger (`/swagger`) để chứng minh.

### (Tùy chọn, nếu còn thời gian) Con dùng ví
Đăng nhập lại phụ huynh → tạo mã ghép mới → ghép máy lần nữa → **Ví 15 phút** → **Dùng** → thời gian hôm nay thành *2 giờ 15 phút*.

### Nếu có sự cố khi demo
| Sự cố | Cách xử lý nhanh |
|---|---|
| *Không tìm thấy máy chủ* | API đã chạy chưa? Cắm lại USB, hoặc ⚙ → **Tự tìm máy chủ**. Wi-Fi trường chặn thì phát hotspot từ điện thoại |
| OTP không tới | Xem thư mục Spam. Gấp thì chạy `set-gmail.ps1 -Off` rồi khởi động lại API (OTP hiện trên app) |
| Mã ghép hết hạn hoặc lỡ quên chép | Đăng nhập lại phụ huynh → *Tạo mã mới* |
| Camera mờ khi chụp minh chứng | **Chọn từ thư viện** |
| Khuôn mặt không khớp | Chỗ đủ sáng, nhìn thẳng. Hoặc vào Tài khoản → đăng ký lại mặt. Hoặc tăng `Face:Threshold` lên 0.09 |
| Bản đồ trắng | Mạng chặn máy chủ bản đồ, đổi mạng hoặc dùng hotspot |

---

## 4. Giới hạn cần nói rõ khi bị hỏi
- **Chặn ứng dụng thật** trên Android cần Device Owner/Accessibility Service (code native), ngoài phạm vi đồ án. App lưu và hiển thị quy tắc cho trẻ; phần thực thi là hướng phát triển.
- **Nhận diện khuôn mặt** dùng tỉ lệ khoảng cách giữa các điểm mốc ML Kit. Cách này phù hợp để demo nhưng kém chính xác hơn mô hình embedding (FaceNet/ArcFace). Ngưỡng chỉnh ở `appsettings.json → Face:Threshold`: giảm để chặt hơn, tăng nếu khó đăng nhập.
- **Vị trí** gửi khi app trên máy con đang mở (foreground). Chạy nền cần `flutter_background_service` (hướng phát triển).

## 5. Cấu trúc code Flutter
```
lib/
  main.dart                 khởi động, đọc phiên đăng nhập
  theme.dart                màu sắc, giao diện
  core/                     api.dart (JWT), session.dart, biometric.dart, face_features.dart, location_helper.dart
  widgets/common.dart       widget dùng chung
  screens/router.dart       PHÂN QUYỀN: homeFor(role), khóa vân tay
  screens/auth/             đăng nhập, OTP, đăng ký, quên mật khẩu, khuôn mặt, quét QR, cấu hình máy chủ
  screens/admin/            trang quản trị (thống kê + CRUD người dùng)
  screens/staff/            dashboard nhân viên (ticket + tra cứu phụ huynh)
  screens/parent/           trang phụ huynh (con, bản đồ, nhiệm vụ, cảnh báo, hỗ trợ)
  screens/child/            màn hình của trẻ (thời gian, ví, SOS, nhiệm vụ, quy tắc)
```
