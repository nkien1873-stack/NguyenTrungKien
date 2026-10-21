import 'package:flutter/material.dart';

import '../../core/api.dart';
import '../../core/utils.dart';
import '../../theme.dart';
import '../../widgets/common.dart';
import 'otp_screen.dart';

/// Đăng ký tài khoản phụ huynh qua email (xác thực bằng OTP).
class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _form = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _user = TextEditingController();
  final _email = TextEditingController();
  final _phone = TextEditingController();
  final _pass = TextEditingController();
  final _pass2 = TextEditingController();
  bool _obscure = true;
  bool _agree = false;
  bool _loading = false;

  @override
  void dispose() {
    for (final c in [_name, _user, _email, _phone, _pass, _pass2]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_form.currentState!.validate()) return;
    if (!_agree) {
      showMsg(context, 'Vui lòng đồng ý điều khoản sử dụng', error: true);
      return;
    }
    setState(() => _loading = true);
    final email = _email.text.trim().toLowerCase();
    try {
      final res = await Api.I.post('/api/auth/register', {
        'username': _user.text.trim().toLowerCase(),
        'email': email,
        'password': _pass.text,
        'fullName': _name.text.trim(),
        'phone': _phone.text.trim().isEmpty ? null : _phone.text.trim(),
      });
      if (!mounted) return;
      showMsg(context, res['message'] ?? 'Đăng ký thành công');
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => OtpScreen(
            purpose: OtpPurpose.register,
            login: email,
            maskedEmail: res['maskedEmail'] ?? email,
            devOtp: res['devOtp'],
          ),
        ),
      );
    } on ApiException catch (e) {
      if (mounted) showMsg(context, e.message, error: true);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Tạo tài khoản phụ huynh')),
      body: Form(
        key: _form,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 4, 20, 30),
          children: [
            const Text('Mã xác thực sẽ được gửi tới email của bạn.', style: TextStyle(color: AppColors.muted)),
            const SizedBox(height: 18),
            TextFormField(
              controller: _name,
              textCapitalization: TextCapitalization.words,
              decoration: const InputDecoration(labelText: 'Họ và tên', prefixIcon: Icon(Icons.badge_outlined)),
              validator: (v) => (v == null || v.trim().length < 2) ? 'Nhập họ tên' : null,
            ),
            const SizedBox(height: 14),
            TextFormField(
              controller: _user,
              decoration: const InputDecoration(labelText: 'Tên đăng nhập', prefixIcon: Icon(Icons.person_outline)),
              validator: (v) {
                final s = v?.trim() ?? '';
                if (s.length < 4) return 'Tối thiểu 4 ký tự';
                if (!RegExp(r'^[a-zA-Z0-9_.]+$').hasMatch(s)) return 'Chỉ gồm chữ không dấu, số, _ và .';
                return null;
              },
            ),
            const SizedBox(height: 14),
            TextFormField(
              controller: _email,
              keyboardType: TextInputType.emailAddress,
              decoration: const InputDecoration(labelText: 'Email', prefixIcon: Icon(Icons.email_outlined)),
              validator: (v) =>
                  RegExp(r'^[\w.+-]+@[\w-]+(\.[\w-]+)+$').hasMatch(v?.trim() ?? '') ? null : 'Email không hợp lệ',
            ),
            const SizedBox(height: 14),
            TextFormField(
              controller: _phone,
              keyboardType: TextInputType.phone,
              decoration: const InputDecoration(labelText: 'Số điện thoại (không bắt buộc)', prefixIcon: Icon(Icons.phone_outlined)),
            ),
            const SizedBox(height: 14),
            TextFormField(
              controller: _pass,
              obscureText: _obscure,
              decoration: InputDecoration(
                labelText: 'Mật khẩu',
                prefixIcon: const Icon(Icons.lock_outline),
                suffixIcon: IconButton(
                  icon: Icon(_obscure ? Icons.visibility_outlined : Icons.visibility_off_outlined),
                  onPressed: () => setState(() => _obscure = !_obscure),
                ),
              ),
              validator: (v) {
                final s = v ?? '';
                if (s.length < 6) return 'Tối thiểu 6 ký tự';
                if (!RegExp(r'[0-9]').hasMatch(s) || !RegExp(r'[A-Za-z]').hasMatch(s)) return 'Cần có cả chữ và số';
                return null;
              },
            ),
            const SizedBox(height: 14),
            TextFormField(
              controller: _pass2,
              obscureText: _obscure,
              decoration: const InputDecoration(labelText: 'Nhập lại mật khẩu', prefixIcon: Icon(Icons.lock_reset)),
              validator: (v) => v != _pass.text ? 'Mật khẩu nhập lại không khớp' : null,
            ),
            const SizedBox(height: 8),
            CheckboxListTile(
              value: _agree,
              onChanged: (v) => setState(() => _agree = v ?? false),
              controlAffinity: ListTileControlAffinity.leading,
              contentPadding: EdgeInsets.zero,
              title: const Text('Tôi đồng ý với điều khoản sử dụng và chính sách bảo vệ dữ liệu trẻ em'),
            ),
            const SizedBox(height: 8),
            LoadingButton(loading: _loading, onPressed: _submit, text: 'Đăng ký', icon: Icons.person_add_alt_1),
          ],
        ),
      ),
    );
  }
}
