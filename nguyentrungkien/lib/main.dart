import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'core/api.dart';
import 'core/session.dart';
import 'screens/auth/login_screen.dart';
import 'screens/router.dart';
import 'theme.dart';

final navigatorKey = GlobalKey<NavigatorState>();
final messengerKey = GlobalKey<ScaffoldMessengerState>();

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final session = Session();
  await session.load();

  // Token hết hạn hoặc thiết bị bị gỡ -> về màn hình đăng nhập
  Api.I.onUnauthorized = (msg) async {
    if (!session.isLoggedIn) return;
    await session.logout();
    navigatorKey.currentState?.pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const LoginScreen()),
      (_) => false,
    );
    messengerKey.currentState?.showSnackBar(SnackBar(content: Text(msg)));
  };

  // Tự dò được máy chủ ở địa chỉ khác (USB/Wi-Fi) -> lưu lại cho lần sau
  Api.I.onBaseUrlFound = session.setBaseUrl;
  // Kiểm tra máy chủ ngay khi mở app (chạy nền, không chặn giao diện)
  Api.I.discover();

  runApp(ChangeNotifierProvider.value(value: session, child: const KidGuardApp()));
}

class KidGuardApp extends StatelessWidget {
  const KidGuardApp({super.key});

  @override
  Widget build(BuildContext context) {
    final session = context.read<Session>();
    return MaterialApp(
      title: 'KidGuard',
      debugShowCheckedModeBanner: false,
      navigatorKey: navigatorKey,
      scaffoldMessengerKey: messengerKey,
      theme: buildTheme(),
      home: session.isLoggedIn ? startScreenFor(session) : const LoginScreen(),
    );
  }
}
