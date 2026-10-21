import 'package:flutter_test/flutter_test.dart';
import 'package:nguyentrungkien/core/utils.dart';

void main() {
  test('fmtMinutes hiển thị đúng', () {
    expect(fmtMinutes(0), '0 phút');
    expect(fmtMinutes(45), '45 phút');
    expect(fmtMinutes(60), '1 giờ');
    expect(fmtMinutes(135), '2 giờ 15 phút');
  });

  test('hexColor / colorHex chuyển đổi 2 chiều', () {
    final c = hexColor('#FF8A4C');
    expect(colorHex(c), '#FF8A4C');
  });
}
