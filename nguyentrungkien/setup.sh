#!/usr/bin/env bash
# Tạo các thư mục nền tảng (android/ios) rồi chép file cấu hình quyền của KidGuard vào.
set -e
cd "$(dirname "$0")"

echo "==> flutter create (không ghi đè lib/)"
flutter create --org com.nguyentrungkien --project-name nguyentrungkien --platforms android,ios .

echo "==> Chép AndroidManifest + MainActivity"
cp -R platform_files/android/. android/
cp platform_files/test/widget_test.dart test/widget_test.dart

# Dự án và pub cache khác ổ đĩa -> cache incremental của Kotlin lỗi "different roots"
grep -q "^kotlin.incremental=" android/gradle.properties || echo "kotlin.incremental=false" >> android/gradle.properties

echo "==> flutter pub get"
flutter pub get

echo "Xong! Chạy: flutter run"
