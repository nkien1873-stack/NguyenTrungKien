import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/biometric.dart';
import '../core/session.dart';
import '../theme.dart';
import 'admin/admin_home.dart';
import 'auth/login_screen.dart';
import 'child/child_home.dart';
import 'parent/parent_home.dart';
import 'staff/staff_home.dart';

/// PHÂN QUYỀN: mỗi vai trò vào một màn hình chính riêng.
Widget homeFor(String? role) {
  switch (role) {
    case Roles.admin:
      return const AdminHome();
    case Roles.staff:
      return const StaffHome();
    case Roles.parent:
      return const ParentHome();
    case Roles.child:
      return const ChildHome();
    default:
      return const LoginScreen();
  }
}

/// Màn hình khởi động khi đã có phiên: nếu bật khóa vân tay thì yêu cầu vân tay trước.
Widget startScreenFor(Session s) {
  if (s.role != Roles.child && s.biometricLock) return const BiometricLockScreen();
  return homeFor(s.role);
}

void goHome(BuildContext context, String? role) {
  Navigator.of(context).pushAndRemoveUntil(MaterialPageRoute(builder: (_) => homeFor(role)), (_) => false);
}

Future<void> logout(BuildContext context) async {
  await context.read<Session>().logout();
  if (!context.mounted) return;
  Navigator.of(context).pushAndRemoveUntil(MaterialPageRoute(builder: (_) => const LoginScreen()), (_) => false);
}

/// Chức năng e – Mở khóa ứng dụng bằng vân tay.
class BiometricLockScreen extends StatefulWidget {
  const BiometricLockScreen({super.key});

  @override
  State<BiometricLockScreen> createState() => _BiometricLockScreenState();
}

class _BiometricLockScreenState extends State<BiometricLockScreen> {
  String? _error;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _unlock());
  }

  Future<void> _unlock() async {
    final err = await Biometric.authenticate('Quét vân tay để mở KidGuard');
    if (!mounted) return;
    if (err == null) {
      goHome(context, context.read<Session>().role);
    } else {
      setState(() => _error = err);
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = context.watch<Session>();
    return Scaffold(
      body: Container(
        width: double.infinity,
        decoration: const BoxDecoration(
          gradient: LinearGradient(colors: AppColors.parentGradient, begin: Alignment.topLeft, end: Alignment.bottomRight),
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(28),
            child: Column(
              children: [
                const Spacer(),
                const Icon(Icons.fingerprint, size: 110, color: Colors.white),
                const SizedBox(height: 20),
                Text('Xin chào, ${s.fullName}',
                    style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.w800)),
                const SizedBox(height: 8),
                const Text('Ứng dụng đang được khóa bằng vân tay',
                    style: TextStyle(color: Colors.white70)),
                if (_error != null) ...[
                  const SizedBox(height: 16),
                  Text(_error!, textAlign: TextAlign.center, style: const TextStyle(color: Colors.white)),
                ],
                const Spacer(),
                FilledButton.icon(
                  style: FilledButton.styleFrom(backgroundColor: Colors.white, foregroundColor: AppColors.primary),
                  onPressed: _unlock,
                  icon: const Icon(Icons.fingerprint),
                  label: const Text('Mở khóa bằng vân tay'),
                ),
                const SizedBox(height: 10),
                TextButton(
                  onPressed: () => logout(context),
                  child: const Text('Đăng nhập bằng tài khoản khác', style: TextStyle(color: Colors.white)),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
