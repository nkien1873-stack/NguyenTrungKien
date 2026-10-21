import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/api.dart';
import '../../core/session.dart';
import '../../core/utils.dart';
import '../../theme.dart';
import '../../widgets/common.dart';
import '../router.dart';
import 'child_pair_screen.dart';
import 'face_capture_screen.dart';
import 'forgot_password_screen.dart';
import 'otp_screen.dart';
import 'register_screen.dart';
import 'server_settings_screen.dart';

/// Đăng nhập: Tên đăng nhập + Mật khẩu -> OTP qua email.
class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _form = GlobalKey<FormState>();
  final _user = TextEditingController();
  final _pass = TextEditingController();
  bool _obscure = true;
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    _user.text = context.read<Session>().lastUsername;
  }

  @override
  void dispose() {
    _user.dispose();
    _pass.dispose();
    super.dispose();
  }

  Future<void> _login() async {
    if (!_form.currentState!.validate()) return;
    setState(() => _loading = true);
    final username = _user.text.trim().toLowerCase();
    try {
      final res = await Api.I.post('/api/auth/login', {'username': username, 'password': _pass.text});
      if (!mounted) return;
      // API đang tắt OTP đăng nhập (Auth:LoginOtp=false) -> trả JWT luôn, vào thẳng trang theo vai trò
      if (res is Map && res['token'] != null) {
        final session = context.read<Session>();
        await session.saveUser(Map<String, dynamic>.from(res));
        if (!mounted) return;
        await offerFaceEnroll(context, session);
        if (mounted) goHome(context, session.role);
        return;
      }
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => OtpScreen(
            purpose: OtpPurpose.login,
            login: username,
            maskedEmail: res['maskedEmail'] ?? '',
            devOtp: res['devOtp'],
          ),
        ),
      );
    } on ApiException catch (e) {
      if (!mounted) return;
      if (e.statusCode == 409 && e.data is Map && e.data['needVerifyEmail'] == true) {
        showMsg(context, e.message);
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => OtpScreen(
              purpose: OtpPurpose.register,
              login: e.data['email'],
              maskedEmail: e.data['maskedEmail'] ?? '',
              devOtp: e.data['devOtp'],
            ),
          ),
        );
      } else {
        showMsg(context, e.message, error: true);
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  /// Không bắt nhập tên: để trống thì server tự nhận ra tài khoản theo khuôn mặt.
  void _faceLogin() {
    final username = _user.text.trim().toLowerCase();
    Navigator.push(context,
        MaterialPageRoute(builder: (_) => FaceCaptureScreen.login(username: username.isEmpty ? null : username)));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SingleChildScrollView(
        child: Column(
          children: [
            GradientHeader(
              colors: AppColors.parentGradient,
              subtitle: 'Bảo vệ con trong thế giới số',
              title: 'KidGuard',
              trailing: IconButton(
                tooltip: 'Cấu hình máy chủ',
                onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ServerSettingsScreen())),
                icon: const Icon(Icons.settings_ethernet, color: Colors.white),
              ),
              bottom: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.18), borderRadius: BorderRadius.circular(16)),
                    child: const Icon(Icons.shield_moon_rounded, color: Colors.white, size: 34),
                  ),
                  const SizedBox(width: 14),
                  const Expanded(
                    child: Text('Quản lý thời gian, vị trí và an toàn của con – mọi lúc, mọi nơi.',
                        style: TextStyle(color: Colors.white, height: 1.4)),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 24, 20, 20),
              child: Form(
                key: _form,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Text('Đăng nhập', style: TextStyle(fontSize: 24, fontWeight: FontWeight.w800, color: AppColors.text)),
                    const SizedBox(height: 4),
                    const Text('Tên đăng nhập + mật khẩu + mã OTP gửi qua email',
                        style: TextStyle(color: AppColors.muted)),
                    const SizedBox(height: 20),
                    TextFormField(
                      controller: _user,
                      textInputAction: TextInputAction.next,
                      decoration: const InputDecoration(labelText: 'Tên đăng nhập', prefixIcon: Icon(Icons.person_outline)),
                      validator: (v) => (v == null || v.trim().isEmpty) ? 'Nhập tên đăng nhập' : null,
                    ),
                    const SizedBox(height: 14),
                    TextFormField(
                      controller: _pass,
                      obscureText: _obscure,
                      onFieldSubmitted: (_) => _login(),
                      decoration: InputDecoration(
                        labelText: 'Mật khẩu',
                        prefixIcon: const Icon(Icons.lock_outline),
                        suffixIcon: IconButton(
                          icon: Icon(_obscure ? Icons.visibility_outlined : Icons.visibility_off_outlined),
                          onPressed: () => setState(() => _obscure = !_obscure),
                        ),
                      ),
                      validator: (v) => (v == null || v.isEmpty) ? 'Nhập mật khẩu' : null,
                    ),
                    Align(
                      alignment: Alignment.centerRight,
                      child: TextButton(
                        onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ForgotPasswordScreen())),
                        child: const Text('Quên mật khẩu?'),
                      ),
                    ),
                    LoadingButton(loading: _loading, onPressed: _login, text: 'Đăng nhập', icon: Icons.login),
                    const SizedBox(height: 12),
                    OutlinedButton.icon(
                      onPressed: _faceLogin,
                      icon: const Icon(Icons.face_retouching_natural),
                      label: const Text('Đăng nhập bằng khuôn mặt'),
                    ),
                    const SizedBox(height: 20),
                    const Row(children: [
                      Expanded(child: Divider()),
                      Padding(padding: EdgeInsets.symmetric(horizontal: 10), child: Text('hoặc', style: TextStyle(color: AppColors.muted))),
                      Expanded(child: Divider()),
                    ]),
                    const SizedBox(height: 16),
                    Card(
                      color: AppColors.accent.withValues(alpha: 0.08),
                      child: ListTile(
                        leading: const Icon(Icons.qr_code_scanner, color: AppColors.accent, size: 32),
                        title: const Text('Đây là điện thoại của con?', style: TextStyle(fontWeight: FontWeight.w700)),
                        subtitle: const Text('Quét mã QR từ máy bố mẹ để ghép thiết bị'),
                        trailing: const Icon(Icons.chevron_right),
                        onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ChildPairScreen())),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Text('Chưa có tài khoản?'),
                        TextButton(
                          onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const RegisterScreen())),
                          child: const Text('Đăng ký bằng email'),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
