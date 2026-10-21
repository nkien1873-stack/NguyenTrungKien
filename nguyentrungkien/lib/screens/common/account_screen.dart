import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/api.dart';
import '../../core/biometric.dart';
import '../../core/session.dart';
import '../../core/utils.dart';
import '../../theme.dart';
import '../../widgets/common.dart';
import '../auth/face_capture_screen.dart';
import '../auth/server_settings_screen.dart';
import '../router.dart';

/// Trang tài khoản dùng chung cho Admin / Nhân viên / Phụ huynh.
class AccountScreen extends StatelessWidget {
  final List<Color> gradient;
  final List<Widget> extraItems;

  const AccountScreen({super.key, required this.gradient, this.extraItems = const []});

  Future<void> _editProfile(BuildContext context) async {
    final s = context.read<Session>();
    Map<String, dynamic> me;
    try {
      me = Map<String, dynamic>.from(await Api.I.get('/api/auth/me'));
    } on ApiException catch (e) {
      if (context.mounted) showMsg(context, e.message, error: true);
      return;
    }
    if (!context.mounted) return;
    final name = TextEditingController(text: me['fullName']);
    final phone = TextEditingController(text: me['phone'] ?? '');
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Thông tin cá nhân'),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          TextField(controller: name, decoration: const InputDecoration(labelText: 'Họ tên')),
          const SizedBox(height: 12),
          TextField(controller: phone, keyboardType: TextInputType.phone, decoration: const InputDecoration(labelText: 'Số điện thoại')),
          const SizedBox(height: 12),
          InfoRow(Icons.email_outlined, 'Email', me['email'] ?? ''),
        ]),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Hủy')),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Lưu')),
        ],
      ),
    );
    if (ok != true || name.text.trim().isEmpty) return;
    try {
      await Api.I.put('/api/auth/me', {'fullName': name.text.trim(), 'phone': phone.text.trim()});
      await s.setProfile(name.text.trim());
      if (context.mounted) showMsg(context, 'Đã cập nhật thông tin');
    } on ApiException catch (e) {
      if (context.mounted) showMsg(context, e.message, error: true);
    }
  }

  Future<void> _changePassword(BuildContext context) async {
    final oldP = TextEditingController();
    final newP = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Đổi mật khẩu'),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          TextField(controller: oldP, obscureText: true, decoration: const InputDecoration(labelText: 'Mật khẩu hiện tại')),
          const SizedBox(height: 12),
          TextField(controller: newP, obscureText: true, decoration: const InputDecoration(labelText: 'Mật khẩu mới (≥ 6 ký tự)')),
        ]),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Hủy')),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Đổi')),
        ],
      ),
    );
    if (ok != true) return;
    try {
      final res = await Api.I.post('/api/auth/change-password', {'oldPassword': oldP.text, 'newPassword': newP.text});
      if (context.mounted) showMsg(context, res['message'] ?? 'Đã đổi mật khẩu');
    } on ApiException catch (e) {
      if (context.mounted) showMsg(context, e.message, error: true);
    }
  }

  Future<void> _face(BuildContext context, bool hasFace) async {
    if (!hasFace) {
      Navigator.push(context, MaterialPageRoute(builder: (_) => const FaceCaptureScreen.enroll()));
      return;
    }
    final action = await showModalBottomSheet<String>(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          ListTile(leading: const Icon(Icons.refresh), title: const Text('Đăng ký lại khuôn mặt'), onTap: () => Navigator.pop(ctx, 're')),
          ListTile(
            leading: const Icon(Icons.delete_outline, color: AppColors.danger),
            title: const Text('Xóa dữ liệu khuôn mặt'),
            onTap: () => Navigator.pop(ctx, 'del'),
          ),
        ]),
      ),
    );
    if (!context.mounted) return;
    if (action == 're') {
      Navigator.push(context, MaterialPageRoute(builder: (_) => const FaceCaptureScreen.enroll()));
    } else if (action == 'del') {
      try {
        await Api.I.delete('/api/auth/face');
        if (!context.mounted) return;
        await context.read<Session>().setHasFace(false);
        if (context.mounted) showMsg(context, 'Đã xóa dữ liệu khuôn mặt');
      } on ApiException catch (e) {
        if (context.mounted) showMsg(context, e.message, error: true);
      }
    }
  }

  Future<void> _toggleLock(BuildContext context, bool value) async {
    final s = context.read<Session>();
    // Xác thực vân tay trước khi bật / tắt
    final err = await Biometric.authenticate(value ? 'Xác nhận vân tay để bật khóa ứng dụng' : 'Xác nhận vân tay để tắt khóa');
    if (err != null) {
      if (context.mounted) showMsg(context, err, error: true);
      return;
    }
    await s.setBiometricLock(value);
  }

  @override
  Widget build(BuildContext context) {
    final s = context.watch<Session>();
    return ListView(
      padding: EdgeInsets.zero,
      children: [
        GradientHeader(
          colors: gradient,
          subtitle: Roles.label(s.role ?? ''),
          title: s.fullName,
          bottom: Row(children: [
            Avatar(name: s.fullName, color: Colors.white.withValues(alpha: 0.25), size: 56),
            const SizedBox(width: 14),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('@${s.username}', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
                Text(s.email, style: const TextStyle(color: Colors.white70)),
              ]),
            ),
          ]),
        ),
        Padding(
          padding: const EdgeInsets.all(16),
          child: Column(children: [
            Card(
              child: Column(children: [
                ListTile(
                  leading: const Icon(Icons.person_outline),
                  title: const Text('Thông tin cá nhân'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => _editProfile(context),
                ),
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(Icons.password),
                  title: const Text('Đổi mật khẩu'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => _changePassword(context),
                ),
              ]),
            ),
            const SizedBox(height: 14),
            Card(
              child: Column(children: [
                ListTile(
                  leading: const Icon(Icons.face_retouching_natural, color: AppColors.primary),
                  title: const Text('Đăng nhập bằng khuôn mặt'),
                  subtitle: Text(s.hasFace ? 'Đã đăng ký' : 'Chưa đăng ký – chạm để thiết lập'),
                  trailing: Icon(s.hasFace ? Icons.check_circle : Icons.chevron_right,
                      color: s.hasFace ? AppColors.success : null),
                  onTap: () => _face(context, s.hasFace),
                ),
                const Divider(height: 1),
                SwitchListTile(
                  secondary: const Icon(Icons.fingerprint, color: AppColors.primary),
                  title: const Text('Khóa ứng dụng bằng vân tay'),
                  subtitle: const Text('Yêu cầu vân tay mỗi khi mở app'),
                  value: s.biometricLock,
                  onChanged: (v) => _toggleLock(context, v),
                ),
              ]),
            ),
            if (extraItems.isNotEmpty) ...[
              const SizedBox(height: 14),
              Card(child: Column(children: extraItems)),
            ],
            const SizedBox(height: 14),
            Card(
              child: Column(children: [
                ListTile(
                  leading: const Icon(Icons.dns_outlined),
                  title: const Text('Cấu hình máy chủ'),
                  subtitle: Text(s.baseUrl),
                  onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ServerSettingsScreen())),
                ),
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(Icons.logout, color: AppColors.danger),
                  title: const Text('Đăng xuất', style: TextStyle(color: AppColors.danger)),
                  onTap: () async {
                    if (await confirm(context, 'Đăng xuất', 'Bạn muốn đăng xuất khỏi KidGuard?', danger: true)) {
                      if (context.mounted) logout(context);
                    }
                  },
                ),
              ]),
            ),
            const SizedBox(height: 24),
          ]),
        ),
      ],
    );
  }
}
