import 'package:geolocator/geolocator.dart';

class LocationResult {
  final Position? position;
  final String? error;
  LocationResult({this.position, this.error});
}

/// Chức năng b – Lấy vị trí GPS (xin quyền khi cần).
class LocationHelper {
  static Future<String?> ensurePermission() async {
    if (!await Geolocator.isLocationServiceEnabled()) {
      return 'Hãy bật Định vị (GPS) trên điện thoại.';
    }
    var perm = await Geolocator.checkPermission();
    if (perm == LocationPermission.denied) {
      perm = await Geolocator.requestPermission();
    }
    if (perm == LocationPermission.denied) return 'Bạn chưa cấp quyền vị trí.';
    if (perm == LocationPermission.deniedForever) {
      return 'Quyền vị trí bị từ chối vĩnh viễn. Hãy bật lại trong Cài đặt > Ứng dụng > KidGuard.';
    }
    return null;
  }

  static Future<LocationResult> current() async {
    final err = await ensurePermission();
    if (err != null) return LocationResult(error: err);
    try {
      final p = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(accuracy: LocationAccuracy.high, timeLimit: Duration(seconds: 15)),
      );
      return LocationResult(position: p);
    } catch (_) {
      final last = await Geolocator.getLastKnownPosition();
      if (last != null) return LocationResult(position: last);
      return LocationResult(error: 'Không lấy được vị trí. Thử lại ở nơi thoáng.');
    }
  }
}
