import 'package:flutter/material.dart';

import '../../core/api.dart';
import '../../core/session.dart';
import '../../core/utils.dart';
import '../../widgets/common.dart';

/// Thêm / sửa người dùng (Admin).
class UserFormScreen extends StatefulWidget {
  final Map<String, dynamic>? user;
  const UserFormScreen({super.key, this.user});

  @override
  State<UserFormScreen> createState() => _UserFormScreenState();
}

class _UserFormScreenState extends State<UserFormScreen> {
  final _form = GlobalKey<FormState>();
  late final TextEditingController _username, _email, _name, _phone, _password;
  late String _role;
  bool _locked = false;
  bool _confirmed = true;
  bool _loading = false;

  bool get _isEdit => widget.user != null;

  @override
  void initState() {
    super.initState();
    final u = widget.user ?? {};
    _username = TextEditingController(text: u['username'] ?? '');
    _email = TextEditingController(text: u['email'] ?? '');
    _name = TextEditingController(text: u['fullName'] ?? '');
    _phone = TextEditingController(text: u['phone'] ?? '');
    _password = TextEditingController();
    _role = u['role'] ?? Roles.staff;
    _locked = u['isLocked'] == true;
    _confirmed = u['emailConfirmed'] ?? true;
  }

  @override
  void dispose() {
    for (final c in [_username, _email, _name, _phone, _password]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _save() async {
    if (!_form.currentState!.validate()) return;
    setState(() => _loading = true);
    try {
      dynamic res;
      if (_isEdit) {
        res = await Api.I.put('/api/admin/users/${widget.user!['id']}', {
          'fullName': _name.text.trim(),
          'email': _email.text.trim(),
          'phone': _phone.text.trim(),
          'role': _role,
          'isLocked': _locked,
          'emailConfirmed': _confirmed,
          'newPassword': _password.text.isEmpty ? null : _password.text,
        });
      } else {
        res = await Api.I.post('/api/admin/users', {
          'username': _username.text.trim(),
          'email': _email.text.trim(),
          'fullName': _name.text.trim(),
          'phone': _phone.text.trim(),
          'password': _password.text,
          'role': _role,
        });
      }
      if (!mounted) return;
      showMsg(context, res['message'] ?? 'Đã lưu');
      Navigator.pop(context, true);
    } on ApiException catch (e) {
      if (mounted) showMsg(context, e.message, error: true);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(_isEdit ? 'Sửa người dùng' : 'Thêm người dùng')),
      body: Form(
        key: _form,
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            TextFormField(
              controller: _username,
              enabled: !_isEdit,
              decoration: const InputDecoration(labelText: 'Tên đăng nhập', prefixIcon: Icon(Icons.person_outline)),
              validator: (v) => (v ?? '').trim().length < 4 ? 'Tối thiểu 4 ký tự' : null,
            ),
            const SizedBox(height: 14),
            TextFormField(
              controller: _name,
              decoration: const InputDecoration(labelText: 'Họ tên', prefixIcon: Icon(Icons.badge_outlined)),
              validator: (v) => (v ?? '').trim().isEmpty ? 'Nhập họ tên' : null,
            ),
            const SizedBox(height: 14),
            TextFormField(
              controller: _email,
              keyboardType: TextInputType.emailAddress,
              decoration: const InputDecoration(labelText: 'Email', prefixIcon: Icon(Icons.email_outlined)),
              validator: (v) => (v ?? '').contains('@') ? null : 'Email không hợp lệ',
            ),
            const SizedBox(height: 14),
            TextFormField(
              controller: _phone,
              keyboardType: TextInputType.phone,
              decoration: const InputDecoration(labelText: 'Số điện thoại', prefixIcon: Icon(Icons.phone_outlined)),
            ),
            const SizedBox(height: 14),
            DropdownButtonFormField<String>(
              initialValue: _role,
              decoration: const InputDecoration(labelText: 'Vai trò', prefixIcon: Icon(Icons.verified_user_outlined)),
              items: [Roles.admin, Roles.staff, Roles.parent]
                  .map((r) => DropdownMenuItem(value: r, child: Text(Roles.label(r))))
                  .toList(),
              onChanged: (v) => setState(() => _role = v ?? _role),
            ),
            const SizedBox(height: 14),
            TextFormField(
              controller: _password,
              obscureText: true,
              decoration: InputDecoration(
                labelText: _isEdit ? 'Mật khẩu mới (để trống nếu không đổi)' : 'Mật khẩu',
                prefixIcon: const Icon(Icons.lock_outline),
              ),
              validator: (v) {
                if (_isEdit && (v ?? '').isEmpty) return null;
                return (v ?? '').length < 6 ? 'Tối thiểu 6 ký tự' : null;
              },
            ),
            if (_isEdit) ...[
              const SizedBox(height: 8),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Khóa tài khoản'),
                value: _locked,
                onChanged: (v) => setState(() => _locked = v),
              ),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Email đã xác thực'),
                value: _confirmed,
                onChanged: (v) => setState(() => _confirmed = v),
              ),
            ],
            const SizedBox(height: 20),
            LoadingButton(loading: _loading, onPressed: _save, text: 'Lưu', icon: Icons.save_outlined),
          ],
        ),
      ),
    );
  }
}
