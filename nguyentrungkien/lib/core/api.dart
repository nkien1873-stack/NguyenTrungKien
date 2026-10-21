import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:http/io_client.dart';

import 'config.dart';

class ApiException implements Exception {
  final String message;
  final int? statusCode;
  final dynamic data;
  ApiException(this.message, {this.statusCode, this.data});

  @override
  String toString() => message;
}

/// Client gọi Web API NguyenTrungKien.API (JWT Bearer).
class Api {
  Api._();
  static final Api I = Api._();

  /// Emulator Android: 10.0.2.2 trỏ về localhost của máy tính.
  /// Máy thật: app tự dò (USB -> emulator -> Wi-Fi), hoặc nhập IP trong màn hình "Cấu hình máy chủ".
  String baseUrl = kDefaultApiUrl;
  String? token;

  /// Gọi khi token hết hạn / thiết bị bị gỡ -> đăng xuất.
  void Function(String message)? onUnauthorized;

  /// Gọi khi tự dò được địa chỉ máy chủ mới -> Session lưu lại.
  void Function(String url)? onBaseUrlFound;

  // Kết nối không được thì báo lỗi sau 5 giây (mặc định của hệ điều hành có thể tới hơn 1 phút)
  final http.Client _http = IOClient(HttpClient()..connectionTimeout = const Duration(seconds: 5));

  // ---------------- Tự tìm máy chủ ----------------
  static const discoveryPort = 5079; // phải trùng Connectivity:DiscoveryPort của API
  Future<String?>? _discovering;

  // Cổng API chạy trên máy tính (địa chỉ online dùng cổng 443 nên không lấy từ đó)
  int get _port {
    final u = Uri.tryParse(baseUrl);
    return (u == null || u.scheme == 'https' || !u.hasPort) ? 5080 : u.port;
  }

  /// Địa chỉ có phải Web API NguyenTrungKien đang chạy không (gọi /api/health).
  Future<bool> probe(String url) async {
    try {
      final base = url.endsWith('/') ? url.substring(0, url.length - 1) : url;
      final res = await _http.get(Uri.parse('$base/api/health')).timeout(const Duration(seconds: 3));
      return res.statusCode == 200 && utf8.decode(res.bodyBytes).contains('NguyenTrungKien');
    } catch (_) {
      return false;
    }
  }

  /// Gửi UDP broadcast trong mạng Wi-Fi, API trả lời "KIDGUARD_API|NguyenTrungKien|<cổng>".
  Future<String?> _discoverLan() async {
    RawDatagramSocket? socket;
    try {
      socket = await RawDatagramSocket.bind(InternetAddress.anyIPv4, 0);
      socket.broadcastEnabled = true;
      final found = Completer<String?>();
      socket.listen((e) {
        if (e != RawSocketEvent.read) return;
        final d = socket!.receive();
        if (d == null) return;
        final parts = utf8.decode(d.data, allowMalformed: true).split('|');
        if (parts.length == 3 && parts[0] == 'KIDGUARD_API' && !found.isCompleted) {
          found.complete('http://${d.address.address}:${parts[2]}');
        }
      });

      // Gửi tới 255.255.255.255 và địa chỉ broadcast của từng mạng (coi như /24)
      final targets = {InternetAddress('255.255.255.255')};
      for (final ni in await NetworkInterface.list(type: InternetAddressType.IPv4)) {
        for (final a in ni.addresses) {
          final p = a.address.split('.');
          if (p.length == 4) targets.add(InternetAddress('${p[0]}.${p[1]}.${p[2]}.255'));
        }
      }
      final msg = utf8.encode('KIDGUARD_DISCOVER');
      for (var i = 0; i < 3 && !found.isCompleted; i++) {
        for (final t in targets) {
          try {
            socket.send(msg, t, discoveryPort);
          } catch (_) {}
        }
        await Future.any([found.future, Future.delayed(const Duration(milliseconds: 800))]);
      }
      return await found.future.timeout(const Duration(milliseconds: 600), onTimeout: () => null);
    } catch (_) {
      return null;
    } finally {
      socket?.close();
    }
  }

  /// Thử lần lượt: địa chỉ đang lưu -> máy chủ online (nếu có) -> USB (localhost) -> emulator (10.0.2.2) -> dò Wi-Fi.
  /// Tìm được thì dùng luôn và báo cho Session lưu lại. Trả về địa chỉ, hoặc null.
  Future<String?> discover() => _discovering ??= _discover().whenComplete(() => _discovering = null);

  Future<String?> _discover() async {
    final port = _port;
    for (final url in {baseUrl, if (kPublicApiUrl.isNotEmpty) kPublicApiUrl, 'http://localhost:$port', 'http://10.0.2.2:$port'}) {
      if (await probe(url)) return _use(url);
    }
    final lan = await _discoverLan();
    if (lan != null && await probe(lan)) return _use(lan);
    return null;
  }

  String _use(String url) {
    if (url != baseUrl) {
      baseUrl = url;
      onBaseUrlFound?.call(url);
    }
    return url;
  }

  Uri _uri(String path, [Map<String, dynamic>? query]) {
    final q = <String, String>{};
    query?.forEach((k, v) {
      if (v != null && v.toString().isNotEmpty) q[k] = v.toString();
    });
    final base = baseUrl.endsWith('/') ? baseUrl.substring(0, baseUrl.length - 1) : baseUrl;
    return Uri.parse('$base$path').replace(queryParameters: q.isEmpty ? null : q);
  }

  String fileUrl(String? relative) {
    if (relative == null || relative.isEmpty) return '';
    if (relative.startsWith('http')) return relative;
    final base = baseUrl.endsWith('/') ? baseUrl.substring(0, baseUrl.length - 1) : baseUrl;
    return '$base$relative';
  }

  Map<String, String> get _headers => {
        'Content-Type': 'application/json; charset=utf-8',
        'Accept': 'application/json',
        if (token != null) 'Authorization': 'Bearer $token',
      };

  Future<dynamic> get(String path, {Map<String, dynamic>? query}) =>
      _send(() => _http.get(_uri(path, query), headers: _headers));

  Future<dynamic> post(String path, [Object? body]) =>
      _send(() => _http.post(_uri(path), headers: _headers, body: jsonEncode(body ?? {})));

  Future<dynamic> put(String path, [Object? body]) =>
      _send(() => _http.put(_uri(path), headers: _headers, body: jsonEncode(body ?? {})));

  Future<dynamic> patch(String path, [Object? body]) =>
      _send(() => _http.patch(_uri(path), headers: _headers, body: jsonEncode(body ?? {})));

  Future<dynamic> delete(String path) => _send(() => _http.delete(_uri(path), headers: _headers));

  Future<dynamic> _send(Future<http.Response> Function() call, {bool retried = false}) async {
    http.Response res;
    try {
      res = await call().timeout(const Duration(seconds: 25));
    } on SocketException {
      // Mất kết nối (rút USB, đổi Wi-Fi, IP máy tính đổi...) -> tự tìm lại máy chủ rồi gửi lại 1 lần.
      // call() tính lại URL từ baseUrl mới nên gửi lại đúng chỗ.
      if (!retried && await discover() != null) return _send(call, retried: true);
      throw ApiException('Không tìm thấy máy chủ. Kiểm tra API đã chạy, điện thoại cắm USB '
          'hoặc cùng Wi-Fi với máy tính (máy tính đã chạy mo-firewall.ps1).');
    } on TimeoutException {
      throw ApiException('Máy chủ phản hồi quá lâu. Thử lại sau.');
    } on http.ClientException catch (e) {
      throw ApiException('Lỗi kết nối: ${e.message}');
    }

    dynamic data;
    final text = utf8.decode(res.bodyBytes);
    if (text.isNotEmpty) {
      try {
        data = jsonDecode(text);
      } catch (_) {
        data = text;
      }
    }

    if (res.statusCode >= 200 && res.statusCode < 300) return data;

    final msg = _errorMessage(data, res.statusCode);
    if (res.statusCode == 401 && token != null) {
      onUnauthorized?.call(msg);
    }
    throw ApiException(msg, statusCode: res.statusCode, data: data);
  }

  String _errorMessage(dynamic data, int code) {
    if (data is Map) {
      if (data['message'] is String) return data['message'];
      // ProblemDetails của ASP.NET (lỗi validate)
      if (data['errors'] is Map) {
        final errors = (data['errors'] as Map).values.expand((e) => e is List ? e : [e]).map((e) => e.toString());
        if (errors.isNotEmpty) return errors.join('\n');
      }
      if (data['title'] is String) return data['title'];
    }
    switch (code) {
      case 401:
        return 'Phiên đăng nhập hết hạn hoặc không có quyền.';
      case 403:
        return 'Bạn không có quyền thực hiện thao tác này.';
      case 404:
        return 'Không tìm thấy dữ liệu.';
      default:
        return 'Có lỗi xảy ra (mã $code).';
    }
  }
}
