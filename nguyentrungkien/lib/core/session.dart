import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'api.dart';
import 'config.dart';

class Roles {
  static const admin = 'Admin';
  static const staff = 'Staff';
  static const parent = 'Parent';
  static const child = 'Child';

  static String label(String role) {
    switch (role) {
      case admin:
        return 'Quản trị viên';
      case staff:
        return 'Nhân viên hỗ trợ';
      case parent:
        return 'Phụ huynh';
      case child:
        return 'Trẻ em';
      default:
        return role;
    }
  }
}

/// Phiên đăng nhập hiện tại (lưu token trong secure storage).
class Session extends ChangeNotifier {
  static const _storage = FlutterSecureStorage();

  String? token;
  String? role;
  int? userId;
  String username = '';
  String fullName = '';
  String email = '';
  bool hasFace = false;

  // Dành cho máy của trẻ
  int? childId;
  String parentName = '';

  // Cài đặt
  String baseUrl = kDefaultApiUrl;
  bool biometricLock = false;
  String lastUsername = '';

  bool get isLoggedIn => token != null && role != null;

  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    baseUrl = prefs.getString('baseUrl') ?? baseUrl;
    biometricLock = prefs.getBool('biometricLock') ?? false;
    lastUsername = prefs.getString('lastUsername') ?? '';
    Api.I.baseUrl = baseUrl;

    token = await _storage.read(key: 'token');
    role = await _storage.read(key: 'role');
    userId = int.tryParse(await _storage.read(key: 'userId') ?? '');
    childId = int.tryParse(await _storage.read(key: 'childId') ?? '');
    username = await _storage.read(key: 'username') ?? '';
    fullName = await _storage.read(key: 'fullName') ?? '';
    email = await _storage.read(key: 'email') ?? '';
    parentName = await _storage.read(key: 'parentName') ?? '';
    hasFace = (await _storage.read(key: 'hasFace')) == 'true';
    Api.I.token = token;
    notifyListeners();
  }

  Future<void> setBaseUrl(String url) async {
    baseUrl = url.trim();
    Api.I.baseUrl = baseUrl;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('baseUrl', baseUrl);
    notifyListeners();
  }

  Future<void> setBiometricLock(bool value) async {
    biometricLock = value;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('biometricLock', value);
    notifyListeners();
  }

  /// Lưu kết quả AuthResponse từ API (Admin / Staff / Parent).
  Future<void> saveUser(Map<String, dynamic> auth) async {
    token = auth['token'];
    role = auth['role'];
    userId = auth['userId'];
    username = auth['username'] ?? '';
    fullName = auth['fullName'] ?? '';
    email = auth['email'] ?? '';
    hasFace = auth['hasFace'] == true;
    childId = null;
    lastUsername = username;

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('lastUsername', username);
    await _persist();
  }

  /// Lưu kết quả ghép thiết bị của trẻ (role Child).
  Future<void> saveChild(Map<String, dynamic> auth) async {
    token = auth['token'];
    role = Roles.child;
    childId = auth['childId'];
    fullName = auth['childName'] ?? '';
    parentName = auth['parentName'] ?? '';
    userId = null;
    username = '';
    email = '';
    hasFace = false;
    await _persist();
  }

  Future<void> setHasFace(bool v) async {
    hasFace = v;
    await _storage.write(key: 'hasFace', value: v.toString());
    notifyListeners();
  }

  Future<void> setProfile(String name) async {
    fullName = name;
    await _storage.write(key: 'fullName', value: name);
    notifyListeners();
  }

  Future<void> _persist() async {
    Api.I.token = token;
    await _storage.write(key: 'token', value: token);
    await _storage.write(key: 'role', value: role);
    await _storage.write(key: 'userId', value: userId?.toString() ?? '');
    await _storage.write(key: 'childId', value: childId?.toString() ?? '');
    await _storage.write(key: 'username', value: username);
    await _storage.write(key: 'fullName', value: fullName);
    await _storage.write(key: 'email', value: email);
    await _storage.write(key: 'parentName', value: parentName);
    await _storage.write(key: 'hasFace', value: hasFace.toString());
    notifyListeners();
  }

  Future<void> logout() async {
    token = null;
    role = null;
    userId = null;
    childId = null;
    Api.I.token = null;
    for (final k in ['token', 'role', 'userId', 'childId', 'username', 'fullName', 'email', 'parentName', 'hasFace']) {
      await _storage.delete(key: k);
    }
    notifyListeners();
  }
}
