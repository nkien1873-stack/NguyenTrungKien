import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../core/api.dart';
import '../../core/session.dart';
import '../../core/utils.dart';
import '../../theme.dart';
import '../../widgets/common.dart';
import '../router.dart';
import 'face_capture_screen.dart';

enum OtpPurpose { register, login }

/// Nhập mã OTP 6 số được gửi qua email.
class OtpScreen extends StatefulWidget {
  final OtpPurpose purpose;

  /// register: email; login: tên đăng nhập
  final String login;
  final String maskedEmail;
  final String? devOtp;

  const OtpScreen({super.key, required this.purpose, required this.login, required this.maskedEmail, this.devOtp});

  @override
  State<OtpScreen> createState() => _OtpScreenState();
}

class _OtpScreenState extends State<OtpScreen> {
  final _code = TextEditingController();
  bool _loading = false;
  int _countdown = 60;
  Timer? _timer;
  String? _devOtp;

  @override
  void initState() {
    super.initState();
    _devOtp = widget.devOtp;
    _startTimer();
  }

  void _startTimer() {
    _timer?.cancel();
    setState(() => _countdown = 60);
    _timer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) return t.cancel();
      if (_countdown <= 1) t.cancel();
      setState(() => _countdown--);
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _code.dispose();
    super.dispose();
  }

  Future<void> _verify() async {
    if (_loading) return;
    final code = _code.text.trim();
    if (code.length != 6) {
      showMsg(context, 'Mã OTP gồm 6 chữ số', error: true);
      return;
    }
    final session = context.read<Session>();
    setState(() => _loading = true);
    try {
      if (widget.purpose == OtpPurpose.register) {
        final res = await Api.I.post('/api/auth/verify-email', {'email': widget.login, 'code': code});
        if (!mounted) return;
        showMsg(context, res['message'] ?? 'Xác thực thành công');
        Navigator.of(context).popUntil((r) => r.isFirst);
      } else {
        final res = await Api.I.post('/api/auth/verify-login-otp', {'username': widget.login, 'code': code});
        await session.saveUser(Map<String, dynamic>.from(res));
        if (!mounted) return;
        await offerFaceEnroll(context, session);
        if (!mounted) return;
        goHome(context, session.role);
      }
    } on ApiException catch (e) {
      if (mounted) showMsg(context, e.message, error: true);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _resend() async {
    try {
      final res = await Api.I.post('/api/auth/resend-otp', {
        'login': widget.login,
        'purpose': widget.purpose == OtpPurpose.register ? 'Register' : 'Login',
      });
      if (!mounted) return;
      setState(() => _devOtp = res['devOtp']);
      showMsg(context, res['message'] ?? 'Đã gửi lại mã');
      _startTimer();
    } on ApiException catch (e) {
      if (mounted) showMsg(context, e.message, error: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isRegister = widget.purpose == OtpPurpose.register;
    return Scaffold(
      appBar: AppBar(title: Text(isRegister ? 'Xác thực email' : 'Xác thực đăng nhập')),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Center(
            child: Container(
              padding: const EdgeInsets.all(22),
              decoration: BoxDecoration(color: AppColors.primary.withValues(alpha: 0.1), shape: BoxShape.circle),
              child: const Icon(Icons.mark_email_read_outlined, size: 54, color: AppColors.primary),
            ),
          ),
          const SizedBox(height: 20),
          Text('Nhập mã gồm 6 chữ số đã gửi tới',
              textAlign: TextAlign.center, style: TextStyle(color: Colors.grey.shade700)),
          const SizedBox(height: 4),
          Text(widget.maskedEmail,
              textAlign: TextAlign.center, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
          const SizedBox(height: 24),
          TextField(
            controller: _code,
            autofocus: true,
            keyboardType: TextInputType.number,
            textAlign: TextAlign.center,
            maxLength: 6,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            style: const TextStyle(fontSize: 30, letterSpacing: 14, fontWeight: FontWeight.w800),
            decoration: const InputDecoration(counterText: '', hintText: '••••••'),
            onChanged: (v) {
              if (v.length == 6) _verify();
            },
          ),
          if (_devOtp != null) ...[
            const SizedBox(height: 12),
            Card(
              color: AppColors.warning.withValues(alpha: 0.12),
              child: ListTile(
                dense: true,
                leading: const Icon(Icons.science_outlined, color: AppColors.warning),
                title: Text('Chế độ demo – mã OTP: $_devOtp'),
                subtitle: const Text('Chạm để điền. Tắt "ReturnOtpInResponse" khi dùng email thật.'),
                onTap: () {
                  _code.text = _devOtp!;
                  _verify();
                },
              ),
            ),
          ],
          const SizedBox(height: 20),
          LoadingButton(loading: _loading, onPressed: _verify, text: 'Xác nhận', icon: Icons.verified_user_outlined),
          const SizedBox(height: 8),
          TextButton(
            onPressed: _countdown > 0 ? null : _resend,
            child: Text(_countdown > 0 ? 'Gửi lại mã sau ${_countdown}s' : 'Gửi lại mã OTP'),
          ),
        ],
      ),
    );
  }
}
