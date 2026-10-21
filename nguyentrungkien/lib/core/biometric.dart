import 'package:flutter/services.dart';
import 'package:local_auth/local_auth.dart';

/// Chức năng e – Xác thực vân tay (local_auth).
class Biometric {
  static final _auth = LocalAuthentication();

  static Future<bool> isAvailable() async {
    try {
      final can = await _auth.canCheckBiometrics;
      final supported = await _auth.isDeviceSupported();
      if (!can || !supported) return false;
      final list = await _auth.getAvailableBiometrics();
      return list.isNotEmpty;
    } on PlatformException {
      return false;
    }
  }

  /// Trả về null nếu thành công, ngược lại là thông báo lỗi.
  static Future<String?> authenticate(String reason) async {
    try {
      if (!await isAvailable()) {
        return 'Thiết bị chưa cài đặt vân tay. Hãy thêm vân tay trong Cài đặt của điện thoại.';
      }
      final ok = await _auth.authenticate(
        localizedReason: reason,
        options: const AuthenticationOptions(biometricOnly: true, stickyAuth: true),
      );
      return ok ? null : 'Xác thực vân tay không thành công.';
    } on PlatformException catch (e) {
      return 'Lỗi vân tay: ${e.message ?? e.code}';
    }
  }
}
