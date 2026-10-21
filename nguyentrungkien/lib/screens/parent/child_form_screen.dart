import 'package:flutter/material.dart';

import '../../core/api.dart';
import '../../core/utils.dart';
import '../../theme.dart';
import '../../widgets/common.dart';

/// Thêm / sửa hồ sơ trẻ.
class ChildFormScreen extends StatefulWidget {
  final Map<String, dynamic>? child;
  const ChildFormScreen({super.key, this.child});

  @override
  State<ChildFormScreen> createState() => _ChildFormScreenState();
}

class _ChildFormScreenState extends State<ChildFormScreen> {
  static const _colors = [
    Color(0xFF4F7CFF), Color(0xFFFF8A4C), Color(0xFF22B07D), Color(0xFFE5484D),
    Color(0xFF7C4DFF), Color(0xFFFFB020), Color(0xFF0F9D8A), Color(0xFFEC4899),
  ];

  final _form = GlobalKey<FormState>();
  late final TextEditingController _name;
  DateTime? _birth;
  late Color _color;
  double _limit = 120;
  TimeOfDay _bed = const TimeOfDay(hour: 21, minute: 30);
  bool _loading = false;

  bool get _isEdit => widget.child != null;

  @override
  void initState() {
    super.initState();
    final c = widget.child ?? {};
    _name = TextEditingController(text: c['name'] ?? '');
    _birth = parseDate(c['birthDate']);
    _color = hexColor(c['avatarColor'], _colors.first);
    _limit = ((c['dailyLimitMinutes'] ?? 120) as int).clamp(0, 480).toDouble();
    final bed = (c['bedTime'] as String?)?.split(':');
    if (bed != null && bed.length == 2) {
      _bed = TimeOfDay(hour: int.tryParse(bed[0]) ?? 21, minute: int.tryParse(bed[1]) ?? 30);
    }
  }

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_form.currentState!.validate()) return;
    setState(() => _loading = true);
    final body = {
      'name': _name.text.trim(),
      'birthDate': _birth == null ? null : DateTime(_birth!.year, _birth!.month, _birth!.day, 12).toIso8601String(),
      'avatarColor': colorHex(_color),
      'dailyLimitMinutes': _limit.round(),
      'bedTime': '${two(_bed.hour)}:${two(_bed.minute)}',
    };
    try {
      final res = _isEdit
          ? await Api.I.put('/api/children/${widget.child!['id']}', body)
          : await Api.I.post('/api/children', body);
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
      appBar: AppBar(title: Text(_isEdit ? 'Sửa hồ sơ' : 'Thêm hồ sơ của con')),
      body: Form(
        key: _form,
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            Center(child: Avatar(name: _name.text.isEmpty ? '?' : _name.text, color: _color, size: 84)),
            const SizedBox(height: 14),
            Wrap(
              alignment: WrapAlignment.center,
              spacing: 10,
              runSpacing: 10,
              children: _colors
                  .map((c) => GestureDetector(
                        onTap: () => setState(() => _color = c),
                        child: Container(
                          width: 34,
                          height: 34,
                          decoration: BoxDecoration(
                            color: c,
                            shape: BoxShape.circle,
                            border: Border.all(color: _color == c ? AppColors.text : Colors.transparent, width: 3),
                          ),
                        ),
                      ))
                  .toList(),
            ),
            const SizedBox(height: 20),
            TextFormField(
              controller: _name,
              onChanged: (_) => setState(() {}),
              textCapitalization: TextCapitalization.words,
              decoration: const InputDecoration(labelText: 'Tên của con', prefixIcon: Icon(Icons.child_care)),
              validator: (v) => (v ?? '').trim().isEmpty ? 'Nhập tên' : null,
            ),
            const SizedBox(height: 14),
            ListTile(
              tileColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14), side: const BorderSide(color: Color(0xFFE2E6F0))),
              leading: const Icon(Icons.cake_outlined),
              title: const Text('Ngày sinh'),
              trailing: Text(_birth == null ? 'Chọn' : fmtDate(_birth), style: const TextStyle(fontWeight: FontWeight.w700)),
              onTap: () async {
                final d = await showDatePicker(
                  context: context,
                  initialDate: _birth ?? DateTime(DateTime.now().year - 8),
                  firstDate: DateTime(2000),
                  lastDate: DateTime.now(),
                );
                if (d != null) setState(() => _birth = d);
              },
            ),
            const SizedBox(height: 12),
            ListTile(
              tileColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14), side: const BorderSide(color: Color(0xFFE2E6F0))),
              leading: const Icon(Icons.bedtime_outlined),
              title: const Text('Giờ đi ngủ (khóa máy)'),
              trailing: Text('${two(_bed.hour)}:${two(_bed.minute)}', style: const TextStyle(fontWeight: FontWeight.w700)),
              onTap: () async {
                final t = await showTimePicker(context: context, initialTime: _bed);
                if (t != null) setState(() => _bed = t);
              },
            ),
            const SizedBox(height: 20),
            Text('Thời gian dùng máy mỗi ngày: ${fmtMinutes(_limit.round())}',
                style: const TextStyle(fontWeight: FontWeight.w700)),
            Slider(
              value: _limit,
              min: 0,
              max: 480,
              divisions: 32,
              label: fmtMinutes(_limit.round()),
              onChanged: (v) => setState(() => _limit = v),
            ),
            const SizedBox(height: 16),
            LoadingButton(loading: _loading, onPressed: _save, text: 'Lưu hồ sơ', icon: Icons.save_outlined),
          ],
        ),
      ),
    );
  }
}
