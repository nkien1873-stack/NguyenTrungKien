import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/api.dart';
import '../../core/utils.dart';
import '../../theme.dart';
import '../../widgets/common.dart';

/// Quên mật khẩu: nhập email -> nhận OTP -> đặt mật khẩu mới.
class ForgotPasswordScreen extends StatefulWidget {
  const ForgotPasswordScreen({super.key});

  @override
  State<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen> {
  final _email = TextEditingController();
  final _code = TextEditingController();
  final _pass = TextEditingController();
  bool _sent = false;
  bool _loading = false;
  String? _devOtp;

  @override
  void dispose() {
    _email.dispose();
    _code.dispose();
    _pass.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    if (!_email.text.contains('@')) {
      showMsg(context, 'Email không hợp lệ', error: true);
      return;
    }
    setState(() => _loading = true);
    try {
      final res = await Api.I.post('/api/auth/forgot-password', {'email': _email.text.trim().toLowerCase()});
      if (!mounted) return;
      setState(() {
        _sent = true;
        _devOtp = res['devOtp'];
      });
      showMsg(context, res['message'] ?? 'Đã gửi mã');
    } on ApiException catch (e) {
      if (mounted) showMsg(context, e.message, error: true);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _reset() async {
    if (_code.text.length != 6 || _pass.text.length < 6) {
      showMsg(context, 'Nhập mã 6 số và mật khẩu mới tối thiểu 6 ký tự', error: true);
      return;
    }
    setState(() => _loading = true);
    try {
      final res = await Api.I.post('/api/auth/reset-password', {
        'email': _email.text.trim().toLowerCase(),
        'code': _code.text,
        'newPassword': _pass.text,
      });
      if (!mounted) return;
      showMsg(context, res['message'] ?? 'Đổi mật khẩu thành công');
      Navigator.pop(context);
    } on ApiException catch (e) {
      if (mounted) showMsg(context, e.message, error: true);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Quên mật khẩu')),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          const Icon(Icons.lock_reset, size: 72, color: AppColors.primary),
          const SizedBox(height: 16),
          TextField(
            controller: _email,
            enabled: !_sent,
            keyboardType: TextInputType.emailAddress,
            decoration: const InputDecoration(labelText: 'Email đã đăng ký', prefixIcon: Icon(Icons.email_outlined)),
          ),
          if (_sent) ...[
            const SizedBox(height: 14),
            TextField(
              controller: _code,
              keyboardType: TextInputType.number,
              maxLength: 6,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              decoration: const InputDecoration(labelText: 'Mã OTP', prefixIcon: Icon(Icons.pin_outlined), counterText: ''),
            ),
            if (_devOtp != null)
              Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Text('Chế độ demo – mã OTP: $_devOtp', style: const TextStyle(color: AppColors.warning)),
              ),
            const SizedBox(height: 14),
            TextField(
              controller: _pass,
              obscureText: true,
              decoration: const InputDecoration(labelText: 'Mật khẩu mới', prefixIcon: Icon(Icons.lock_outline)),
            ),
          ],
          const SizedBox(height: 20),
          LoadingButton(
            loading: _loading,
            onPressed: _sent ? _reset : _send,
            text: _sent ? 'Đặt lại mật khẩu' : 'Gửi mã OTP',
          ),
        ],
      ),
    );
  }
}
