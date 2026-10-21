import 'package:flutter/material.dart';

import '../../core/api.dart';
import '../../core/biometric.dart';
import '../../core/utils.dart';
import '../../theme.dart';
import '../../widgets/common.dart';
import 'child_form_screen.dart';
import 'pair_qr_screen.dart';
import 'zone_form_screen.dart';

/// Chi tiết 1 trẻ: thiết bị, vùng an toàn (CRUD), quy tắc ứng dụng (CRUD), ví thời gian.
class ChildDetailScreen extends StatefulWidget {
  final int childId;
  final String name;
  const ChildDetailScreen({super.key, required this.childId, required this.name});

  @override
  State<ChildDetailScreen> createState() => _ChildDetailScreenState();
}

class _ChildDetailScreenState extends State<ChildDetailScreen> {
  Map<String, dynamic>? _c;
  Map<String, dynamic>? _wallet;
  String? _error;

  String get _base => '/api/children/${widget.childId}';

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final r = await Future.wait([Api.I.get(_base), Api.I.get('$_base/wallet')]);
      if (mounted) {
        setState(() {
          _c = Map<String, dynamic>.from(r[0]);
          _wallet = Map<String, dynamic>.from(r[1]);
          _error = null;
        });
      }
    } on ApiException catch (e) {
      if (mounted) setState(() => _error = e.message);
    }
  }

  Future<void> _run(Future<dynamic> Function() call) async {
    try {
      final res = await call();
      if (mounted && res is Map && res['message'] != null) showMsg(context, res['message']);
      _load();
    } on ApiException catch (e) {
      if (mounted) showMsg(context, e.message, error: true);
    }
  }

  // ---------- Hồ sơ ----------
  Future<void> _edit() async {
    final ok = await Navigator.push<bool>(context, MaterialPageRoute(builder: (_) => ChildFormScreen(child: _c)));
    if (ok == true) _load();
  }

  Future<void> _delete() async {
    if (!await confirm(context, 'Xóa hồ sơ', 'Xóa hồ sơ "${_c!['name']}" và toàn bộ dữ liệu (vị trí, nhiệm vụ, thiết bị)?',
        ok: 'Xóa', danger: true)) {
      return;
    }
    // Xác nhận bằng vân tay trước thao tác nguy hiểm
    final err = await Biometric.authenticate('Xác nhận vân tay để xóa hồ sơ');
    if (err != null) {
      if (mounted) showMsg(context, err, error: true);
      return;
    }
    try {
      await Api.I.delete(_base);
      if (!mounted) return;
      showMsg(context, 'Đã xóa hồ sơ');
      Navigator.pop(context);
    } on ApiException catch (e) {
      if (mounted) showMsg(context, e.message, error: true);
    }
  }

  // ---------- Vùng an toàn ----------
  Future<void> _zoneForm([Map<String, dynamic>? zone]) async {
    final ok = await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (_) => ZoneFormScreen(childId: widget.childId, zone: zone)),
    );
    if (ok == true) _load();
  }

  // ---------- Quy tắc ứng dụng ----------
  Future<void> _ruleForm([Map<String, dynamic>? rule]) async {
    final name = TextEditingController(text: rule?['appName'] ?? '');
    var category = (rule?['category'] as String?) ?? 'Giải trí';
    var limit = ((rule?['dailyLimitMinutes'] ?? 30) as int).toDouble();
    var blocked = rule?['isBlocked'] == true;
    const categories = ['Giải trí', 'Mạng xã hội', 'Trò chơi', 'Học tập', 'Khác'];
    if (!categories.contains(category)) category = 'Khác';

    final ok = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, set) => Padding(
          padding: EdgeInsets.fromLTRB(20, 20, 20, MediaQuery.of(ctx).viewInsets.bottom + 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(rule == null ? 'Thêm quy tắc ứng dụng' : 'Sửa quy tắc',
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
              const SizedBox(height: 14),
              TextField(controller: name, decoration: const InputDecoration(labelText: 'Tên ứng dụng (VD: YouTube)')),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                initialValue: category,
                decoration: const InputDecoration(labelText: 'Nhóm'),
                items: categories.map((c) => DropdownMenuItem(value: c, child: Text(c))).toList(),
                onChanged: (v) => set(() => category = v ?? category),
              ),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Chặn hoàn toàn'),
                value: blocked,
                onChanged: (v) => set(() => blocked = v),
              ),
              if (!blocked) ...[
                Text(limit == 0 ? 'Không giới hạn thời gian' : 'Giới hạn: ${fmtMinutes(limit.round())}/ngày'),
                Slider(value: limit, min: 0, max: 240, divisions: 16, onChanged: (v) => set(() => limit = v)),
              ],
              const SizedBox(height: 8),
              FilledButton(
                onPressed: () {
                  if (name.text.trim().isEmpty) return;
                  Navigator.pop(ctx, true);
                },
                child: const Text('Lưu'),
              ),
            ],
          ),
        ),
      ),
    );
    if (ok != true) return;
    final body = {
      'appName': name.text.trim(),
      'category': category,
      'dailyLimitMinutes': blocked ? 0 : limit.round(),
      'isBlocked': blocked,
    };
    await _run(() => rule == null
        ? Api.I.post('$_base/rules', body)
        : Api.I.put('$_base/rules/${rule['id']}', body));
  }

  // ---------- Ví thời gian ----------
  Future<void> _adjustWallet() async {
    final reason = TextEditingController();
    var minutes = 15.0;
    var add = true;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, set) => AlertDialog(
          title: const Text('Điều chỉnh ví thời gian'),
          content: Column(mainAxisSize: MainAxisSize.min, children: [
            SegmentedButton<bool>(
              segments: const [
                ButtonSegment(value: true, label: Text('Thưởng'), icon: Icon(Icons.add)),
                ButtonSegment(value: false, label: Text('Trừ'), icon: Icon(Icons.remove)),
              ],
              selected: {add},
              onSelectionChanged: (v) => set(() => add = v.first),
            ),
            const SizedBox(height: 10),
            Text('${minutes.round()} phút', style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800)),
            Slider(value: minutes, min: 5, max: 120, divisions: 23, onChanged: (v) => set(() => minutes = v)),
            TextField(controller: reason, decoration: const InputDecoration(labelText: 'Lý do')),
          ]),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Hủy')),
            TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Xác nhận')),
          ],
        ),
      ),
    );
    if (ok != true) return;
    final m = minutes.round() * (add ? 1 : -1);
    await _run(() => Api.I.post('$_base/wallet/adjust', {
          'minutes': m,
          'reason': reason.text.trim().isEmpty ? (add ? 'Bố mẹ thưởng' : 'Bố mẹ trừ') : reason.text.trim(),
        }));
  }

  @override
  Widget build(BuildContext context) {
    final c = _c;
    return Scaffold(
      appBar: AppBar(
        title: Text(c?['name'] ?? widget.name),
        actions: [
          if (c != null) IconButton(tooltip: 'Sửa hồ sơ', onPressed: _edit, icon: const Icon(Icons.edit_outlined)),
          if (c != null)
            IconButton(tooltip: 'Xóa hồ sơ', onPressed: _delete, icon: const Icon(Icons.delete_outline, color: AppColors.danger)),
        ],
      ),
      body: _error != null
          ? ErrorView(message: _error!, onRetry: _load)
          : c == null
              ? const Center(child: CircularProgressIndicator())
              : RefreshIndicator(
                  onRefresh: _load,
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 30),
                    children: [
                      _profileCard(c),
                      const SizedBox(height: 12),
                      _pairCard(c),
                      _devicesSection(c),
                      _zonesSection(c),
                      _rulesSection(c),
                      _walletSection(),
                    ],
                  ),
                ),
    );
  }

  Widget _profileCard(Map<String, dynamic> c) => Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(children: [
            Avatar(name: c['name'] ?? '', color: hexColor(c['avatarColor']), size: 60),
            const SizedBox(width: 16),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(c['name'] ?? '', style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
                if (c['birthDate'] != null) Text('Sinh ngày ${fmtDate(c['birthDate'])}', style: const TextStyle(color: AppColors.muted)),
                const SizedBox(height: 6),
                Wrap(spacing: 6, runSpacing: 6, children: [
                  StatusChip('${fmtMinutes(c['dailyLimitMinutes'] ?? 0)}/ngày', AppColors.primary),
                  StatusChip('Ngủ lúc ${c['bedTime']}', const Color(0xFF7C4DFF)),
                ]),
              ]),
            ),
          ]),
        ),
      );

  Widget _pairCard(Map<String, dynamic> c) => Card(
        color: AppColors.primary,
        child: ListTile(
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
          leading: const Icon(Icons.qr_code_2, color: Colors.white, size: 36),
          title: const Text('Ghép điện thoại của con', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
          subtitle: const Text('Hiện mã QR để máy của con quét', style: TextStyle(color: Colors.white70)),
          trailing: const Icon(Icons.chevron_right, color: Colors.white),
          onTap: () async {
            await Navigator.push(context,
                MaterialPageRoute(builder: (_) => PairQrScreen(childId: widget.childId, childName: c['name'] ?? '')));
            _load();
          },
        ),
      );

  Widget _devicesSection(Map<String, dynamic> c) {
    final devices = (c['devices'] as List?) ?? [];
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      SectionTitle('Thiết bị đã ghép (${devices.length})'),
      if (devices.isEmpty)
        const Card(child: ListTile(leading: Icon(Icons.phonelink_off), title: Text('Chưa có thiết bị nào')))
      else
        Card(
          child: Column(
            children: devices.map((d) {
              return ListTile(
                leading: const Icon(Icons.phone_android, color: AppColors.success),
                title: Text(d['deviceName'] ?? ''),
                subtitle: Text('Hoạt động ${timeAgo(d['lastSeenAt'] ?? d['pairedAt'])}'
                    '${d['batteryLevel'] != null ? ' • Pin ${d['batteryLevel']}%' : ''}'),
                trailing: IconButton(
                  tooltip: 'Gỡ thiết bị',
                  icon: const Icon(Icons.link_off, color: AppColors.danger),
                  onPressed: () async {
                    if (await confirm(context, 'Gỡ thiết bị', 'Máy này sẽ bị đăng xuất khỏi tài khoản của con.', danger: true)) {
                      _run(() => Api.I.delete('$_base/devices/${d['id']}'));
                    }
                  },
                ),
              );
            }).toList(),
          ),
        ),
    ]);
  }

  Widget _zonesSection(Map<String, dynamic> c) {
    final zones = (c['safeZones'] as List?) ?? [];
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      SectionTitle(
        'Vùng an toàn (${zones.length})',
        action: TextButton.icon(onPressed: () => _zoneForm(), icon: const Icon(Icons.add_location_alt_outlined), label: const Text('Thêm')),
      ),
      if (zones.isEmpty)
        const Card(child: ListTile(leading: Icon(Icons.location_off_outlined), title: Text('Chưa có vùng an toàn')))
      else
        Card(
          child: Column(
            children: zones.map((raw) {
              final z = Map<String, dynamic>.from(raw);
              final active = z['isActive'] == true;
              return ListTile(
                leading: CircleAvatar(
                  backgroundColor: (active ? AppColors.success : AppColors.muted).withValues(alpha: 0.12),
                  child: Icon(Icons.home_work_outlined, color: active ? AppColors.success : AppColors.muted),
                ),
                title: Text(z['name'] ?? ''),
                subtitle: Text('Bán kính ${(z['radiusMeters'] as num).round()} m${active ? '' : ' • Đang tắt'}'),
                onTap: () => _zoneForm(z),
                trailing: IconButton(
                  icon: const Icon(Icons.delete_outline),
                  onPressed: () async {
                    if (await confirm(context, 'Xóa vùng', 'Xóa vùng "${z['name']}"?', danger: true)) {
                      _run(() => Api.I.delete('$_base/zones/${z['id']}'));
                    }
                  },
                ),
              );
            }).toList(),
          ),
        ),
    ]);
  }

  Widget _rulesSection(Map<String, dynamic> c) {
    final rules = (c['appRules'] as List?) ?? [];
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      SectionTitle(
        'Quy tắc ứng dụng (${rules.length})',
        action: TextButton.icon(onPressed: () => _ruleForm(), icon: const Icon(Icons.add), label: const Text('Thêm')),
      ),
      if (rules.isEmpty)
        const Card(child: ListTile(leading: Icon(Icons.apps), title: Text('Chưa có quy tắc nào')))
      else
        Card(
          child: Column(
            children: rules.map((raw) {
              final r = Map<String, dynamic>.from(raw);
              final blocked = r['isBlocked'] == true;
              final limit = r['dailyLimitMinutes'] as int;
              return ListTile(
                leading: CircleAvatar(
                  backgroundColor: (blocked ? AppColors.danger : AppColors.primary).withValues(alpha: 0.12),
                  child: Icon(blocked ? Icons.block : Icons.apps, color: blocked ? AppColors.danger : AppColors.primary),
                ),
                title: Text(r['appName'] ?? ''),
                subtitle: Text('${r['category']} • ${blocked ? 'Bị chặn' : limit == 0 ? 'Không giới hạn' : '${fmtMinutes(limit)}/ngày'}'),
                onTap: () => _ruleForm(r),
                trailing: PopupMenuButton<String>(
                  onSelected: (v) async {
                    if (v == 'toggle') {
                      _run(() => Api.I.put('$_base/rules/${r['id']}', {
                            'appName': r['appName'],
                            'category': r['category'],
                            'dailyLimitMinutes': limit,
                            'isBlocked': !blocked,
                          }));
                    } else if (v == 'delete' &&
                        await confirm(context, 'Xóa quy tắc', 'Xóa quy tắc cho "${r['appName']}"?', danger: true)) {
                      _run(() => Api.I.delete('$_base/rules/${r['id']}'));
                    }
                  },
                  itemBuilder: (_) => [
                    PopupMenuItem(value: 'toggle', child: Text(blocked ? 'Bỏ chặn' : 'Chặn ngay')),
                    const PopupMenuItem(value: 'delete', child: Text('Xóa')),
                  ],
                ),
              );
            }).toList(),
          ),
        ),
    ]);
  }

  Widget _walletSection() {
    final w = _wallet;
    if (w == null) return const SizedBox.shrink();
    final tx = (w['transactions'] as List?) ?? [];
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      SectionTitle(
        'Ví thời gian',
        action: TextButton.icon(onPressed: _adjustWallet, icon: const Icon(Icons.tune), label: const Text('Điều chỉnh')),
      ),
      Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(children: [
            Row(children: [
              const Icon(Icons.savings, color: AppColors.accent, size: 36),
              const SizedBox(width: 12),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('${w['bonusMinutes']} phút', style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w800)),
                  const Text('Phút thưởng con đang có', style: TextStyle(color: AppColors.muted)),
                ]),
              ),
            ]),
            if (tx.isNotEmpty) const Divider(height: 24),
            ...tx.take(8).map((t) {
              final m = t['minutes'] as int;
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Row(children: [
                  Expanded(child: Text(t['reason'] ?? '', maxLines: 1, overflow: TextOverflow.ellipsis)),
                  Text(timeAgo(t['createdAt']), style: const TextStyle(fontSize: 12, color: AppColors.muted)),
                  const SizedBox(width: 10),
                  Text('${m > 0 ? '+' : ''}$m',
                      style: TextStyle(fontWeight: FontWeight.w800, color: m > 0 ? AppColors.success : AppColors.danger)),
                ]),
              );
            }),
          ]),
        ),
      ),
    ]);
  }
}
