import 'dart:async';
import 'dart:convert';

import 'package:battery_plus/battery_plus.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';

import '../../core/api.dart';
import '../../core/biometric.dart';
import '../../core/location_helper.dart';
import '../../core/session.dart';
import '../../core/utils.dart';
import '../../theme.dart';
import '../../widgets/common.dart';
import '../router.dart';

/// MÀN HÌNH CỦA TRẺ (máy đã ghép bằng QR).
class ChildHome extends StatefulWidget {
  const ChildHome({super.key});

  @override
  State<ChildHome> createState() => _ChildHomeState();
}

class _ChildHomeState extends State<ChildHome> with WidgetsBindingObserver {
  int _tab = 0;
  Map<String, dynamic>? _me;
  List<dynamic>? _tasks;
  String? _error;

  // Chia sẻ vị trí
  Timer? _locTimer;
  DateTime? _lastSent;
  String? _zone;
  String? _locError;
  bool _sending = false;

  final _battery = Battery();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _load();
    _startSharing();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _locTimer?.cancel();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _load();
      _sendLocation();
    }
  }

  Future<void> _load() async {
    try {
      final r = await Future.wait([Api.I.get('/api/child/me'), Api.I.get('/api/child/tasks')]);
      if (mounted) {
        setState(() {
          _me = Map<String, dynamic>.from(r[0]);
          _tasks = r[1] as List;
          _error = null;
        });
      }
    } on ApiException catch (e) {
      if (mounted) setState(() => _error = e.message);
    }
  }

  // ---------------- Chức năng b: gửi vị trí định kỳ ----------------
  Future<void> _startSharing() async {
    await _sendLocation();
    _locTimer?.cancel();
    // Mỗi 30 giây: gửi vị trí và tải lại ví/nhiệm vụ (thấy ngay phút thưởng bố mẹ vừa duyệt)
    _locTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      _sendLocation();
      _load();
    });
  }

  Future<int?> _batteryLevel() async {
    try {
      return await _battery.batteryLevel;
    } catch (_) {
      return null;
    }
  }

  Future<void> _sendLocation() async {
    if (_sending) return;
    _sending = true;
    try {
      final loc = await LocationHelper.current();
      if (loc.error != null) {
        if (mounted) setState(() => _locError = loc.error);
        return;
      }
      final p = loc.position!;
      final res = await Api.I.post('/api/child/location', {
        'latitude': p.latitude,
        'longitude': p.longitude,
        'accuracy': p.accuracy,
        'batteryLevel': await _batteryLevel(),
      });
      if (mounted) {
        setState(() {
          _lastSent = DateTime.now();
          _zone = res['insideZone'];
          _locError = null;
        });
      }
    } on ApiException catch (e) {
      if (mounted) setState(() => _locError = e.message);
    } finally {
      _sending = false;
    }
  }

  Future<void> _sos() async {
    final ok = await confirm(context, 'Gửi SOS?', 'Bố mẹ sẽ nhận được cảnh báo khẩn cấp kèm vị trí của con.',
        ok: 'GỬI SOS', danger: true);
    if (!ok) return;
    try {
      final loc = await LocationHelper.current();
      final res = await Api.I.post('/api/child/sos', {
        'latitude': loc.position?.latitude,
        'longitude': loc.position?.longitude,
      });
      if (mounted) showMsg(context, res['message']);
    } on ApiException catch (e) {
      if (mounted) showMsg(context, e.message, error: true);
    }
  }

  Future<void> _redeem() async {
    final bonus = (_me?['bonusMinutes'] ?? 0) as int;
    if (bonus <= 0) {
      showMsg(context, 'Ví đang trống. Làm nhiệm vụ để nhận thêm phút nhé!');
      return;
    }
    var m = bonus >= 15 ? 15.0 : bonus.toDouble();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, set) => AlertDialog(
          title: const Text('Dùng phút trong ví'),
          content: Column(mainAxisSize: MainAxisSize.min, children: [
            Text('${m.round()} phút', style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w800, color: AppColors.accent)),
            if (bonus > 1)
              Slider(value: m, min: 1, max: bonus.toDouble(), divisions: bonus - 1, onChanged: (v) => set(() => m = v)),
            Text('Ví còn $bonus phút'),
          ]),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Hủy')),
            TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Dùng')),
          ],
        ),
      ),
    );
    if (ok != true) return;
    try {
      final res = await Api.I.post('/api/child/wallet/redeem', {'minutes': m.round()});
      if (mounted) showMsg(context, res['message']);
      _load();
    } on ApiException catch (e) {
      if (mounted) showMsg(context, e.message, error: true);
    }
  }

  Future<void> _submitTask(Map<String, dynamic> t) async {
    final note = TextEditingController();
    XFile? photo;
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
              Text(t['title'] ?? '', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
              if ((t['description'] ?? '').toString().isNotEmpty) Text(t['description']),
              if (t['parentComment'] != null) ...[
                const SizedBox(height: 6),
                Text('Bố mẹ nhắn: ${t['parentComment']}', style: const TextStyle(color: AppColors.danger)),
              ],
              const SizedBox(height: 14),
              OutlinedButton.icon(
                onPressed: () async {
                  final f = await ImagePicker().pickImage(source: ImageSource.camera, maxWidth: 1280, imageQuality: 60);
                  if (f != null) set(() => photo = f);
                },
                icon: Icon(photo == null ? Icons.photo_camera : Icons.check_circle, color: photo == null ? null : AppColors.success),
                label: Text(photo == null ? 'Chụp ảnh minh chứng' : 'Đã có ảnh – chụp lại'),
              ),
              // Camera hỏng/mờ thì chọn ảnh có sẵn trong máy
              TextButton.icon(
                onPressed: () async {
                  final f = await ImagePicker().pickImage(source: ImageSource.gallery, maxWidth: 1280, imageQuality: 60);
                  if (f != null) set(() => photo = f);
                },
                icon: const Icon(Icons.photo_library_outlined),
                label: const Text('Chọn từ thư viện'),
              ),
              const SizedBox(height: 12),
              TextField(controller: note, decoration: const InputDecoration(labelText: 'Lời nhắn cho bố mẹ')),
              const SizedBox(height: 16),
              FilledButton(
                style: FilledButton.styleFrom(backgroundColor: AppColors.accent),
                onPressed: () => Navigator.pop(ctx, true),
                child: Text('Gửi để nhận ${t['rewardMinutes']} phút'),
              ),
            ],
          ),
        ),
      ),
    );
    if (ok != true) return;
    try {
      String? b64;
      if (photo != null) b64 = base64Encode(await photo!.readAsBytes());
      final res = await Api.I.post('/api/child/tasks/${t['id']}/submit', {'note': note.text.trim(), 'imageBase64': b64});
      if (mounted) showMsg(context, res['message']);
      _load();
    } on ApiException catch (e) {
      if (mounted) showMsg(context, e.message, error: true);
    }
  }

  Future<void> _exitChildMode() async {
    final ok = await confirm(context, 'Thoát chế độ trẻ em',
        'Cần bố mẹ xác thực vân tay để gỡ máy này khỏi tài khoản.', ok: 'Xác thực');
    if (!ok) return;
    final err = await Biometric.authenticate('Bố mẹ xác thực để thoát chế độ trẻ em');
    if (err != null) {
      if (mounted) showMsg(context, err, error: true);
      return;
    }
    _locTimer?.cancel();
    if (mounted) logout(context);
  }

  @override
  Widget build(BuildContext context) {
    final s = context.watch<Session>();
    return Scaffold(
      body: IndexedStack(index: _tab, children: [
        _homeTab(s),
        _tasksTab(),
        _rulesTab(),
      ]),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _tab,
        onDestinationSelected: (i) => setState(() => _tab = i),
        indicatorColor: AppColors.accent.withValues(alpha: 0.18),
        destinations: [
          const NavigationDestination(icon: Icon(Icons.home_outlined), selectedIcon: Icon(Icons.home), label: 'Của con'),
          NavigationDestination(
            icon: Badge(
              isLabelVisible: (_me?['pendingTasks'] ?? 0) > 0,
              label: Text('${_me?['pendingTasks'] ?? 0}'),
              child: const Icon(Icons.emoji_events_outlined),
            ),
            selectedIcon: const Icon(Icons.emoji_events),
            label: 'Nhiệm vụ',
          ),
          const NavigationDestination(icon: Icon(Icons.apps_outlined), selectedIcon: Icon(Icons.apps), label: 'Ứng dụng'),
        ],
      ),
    );
  }

  // ---------------- Tab Trang chủ ----------------
  Widget _homeTab(Session s) {
    final me = _me;
    final allowance = (me?['todayAllowance'] ?? 0) as int;
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        padding: EdgeInsets.zero,
        children: [
          GradientHeader(
            colors: AppColors.childGradient,
            subtitle: 'Chào bạn nhỏ 🌟',
            title: me?['name'] ?? s.fullName,
            trailing: GestureDetector(
              onLongPress: _exitChildMode,
              child: Avatar(name: me?['name'] ?? s.fullName, color: Colors.white.withValues(alpha: 0.3), size: 52),
            ),
            bottom: Text('Thiết bị được quản lý bởi ${me?['parentName'] ?? s.parentName}',
                style: const TextStyle(color: Colors.white)),
          ),
          if (_error != null)
            ErrorView(message: _error!, onRetry: _load)
          else
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                // Thời gian hôm nay
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(18),
                    child: Row(children: [
                      const Icon(Icons.timer, color: AppColors.primary, size: 44),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          const Text('Thời gian dùng máy hôm nay', style: TextStyle(color: AppColors.muted)),
                          Text(fmtMinutes(allowance), style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w800)),
                          if ((me?['redeemedToday'] ?? 0) > 0)
                            Text('Đã thêm ${me!['redeemedToday']} phút từ ví', style: const TextStyle(color: AppColors.success)),
                          Text('Đi ngủ lúc ${me?['bedTime'] ?? '--:--'}', style: const TextStyle(color: AppColors.muted)),
                        ]),
                      ),
                    ]),
                  ),
                ),
                const SizedBox(height: 12),
                // Ví thời gian
                Card(
                  clipBehavior: Clip.antiAlias,
                  child: Container(
                    decoration: BoxDecoration(gradient: LinearGradient(colors: [
                      AppColors.accent.withValues(alpha: 0.12),
                      AppColors.warning.withValues(alpha: 0.12),
                    ])),
                    padding: const EdgeInsets.all(18),
                    child: Row(children: [
                      const Icon(Icons.savings, color: AppColors.accent, size: 44),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          const Text('Ví thời gian', style: TextStyle(color: AppColors.muted)),
                          Text('${me?['bonusMinutes'] ?? 0} phút',
                              style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w800, color: AppColors.accent)),
                        ]),
                      ),
                      FilledButton(
                        style: FilledButton.styleFrom(backgroundColor: AppColors.accent, minimumSize: const Size(90, 44)),
                        onPressed: _redeem,
                        child: const Text('Dùng'),
                      ),
                    ]),
                  ),
                ),
                const SizedBox(height: 12),
                // Chia sẻ vị trí
                Card(
                  child: ListTile(
                    leading: Icon(_locError == null ? Icons.share_location : Icons.location_disabled,
                        color: _locError == null ? AppColors.success : AppColors.danger, size: 32),
                    title: Text(_locError == null ? 'Đang chia sẻ vị trí với bố mẹ' : 'Chưa chia sẻ được vị trí',
                        style: const TextStyle(fontWeight: FontWeight.w700)),
                    subtitle: Text(_locError ??
                        [
                          if (_lastSent != null) 'Gửi lúc ${two(_lastSent!.hour)}:${two(_lastSent!.minute)}:${two(_lastSent!.second)}',
                          if (_zone != null) 'Đang ở: $_zone',
                        ].join(' • ')),
                    trailing: IconButton(onPressed: _sendLocation, icon: const Icon(Icons.refresh)),
                  ),
                ),
                const SizedBox(height: 24),
                // Nút SOS
                Center(
                  child: GestureDetector(
                    onTap: _sos,
                    child: Container(
                      width: 170,
                      height: 170,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: const RadialGradient(colors: [Color(0xFFFF6B6B), AppColors.danger]),
                        boxShadow: [BoxShadow(color: AppColors.danger.withValues(alpha: 0.45), blurRadius: 30, spreadRadius: 4)],
                      ),
                      child: const Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                        Icon(Icons.sos, color: Colors.white, size: 56),
                        Text('KHẨN CẤP', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 18)),
                      ]),
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                const Text('Bấm khi con gặp nguy hiểm – bố mẹ nhận được ngay',
                    textAlign: TextAlign.center, style: TextStyle(color: AppColors.muted)),
                const SizedBox(height: 16),
                const Text('Nhấn giữ ảnh đại diện để thoát (cần bố mẹ)',
                    textAlign: TextAlign.center, style: TextStyle(color: AppColors.muted, fontSize: 12)),
              ]),
            ),
        ],
      ),
    );
  }

  // ---------------- Tab Nhiệm vụ ----------------
  Widget _tasksTab() {
    final tasks = _tasks;
    return Scaffold(
      appBar: AppBar(title: const Text('Nhiệm vụ của con')),
      body: tasks == null
          ? const Center(child: CircularProgressIndicator())
          : tasks.isEmpty
              ? const EmptyView(icon: Icons.emoji_events_outlined, message: 'Chưa có nhiệm vụ nào.\nHỏi bố mẹ giao nhiệm vụ để nhận phút thưởng!')
              : RefreshIndicator(
                  onRefresh: _load,
                  child: ListView.separated(
                    padding: const EdgeInsets.all(16),
                    itemCount: tasks.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 10),
                    itemBuilder: (_, i) {
                      final t = Map<String, dynamic>.from(tasks[i]);
                      final status = t['status'] as String;
                      final canSubmit = status == 'Assigned' || status == 'Rejected';
                      return Card(
                        child: Padding(
                          padding: const EdgeInsets.all(14),
                          child: Row(children: [
                            Container(
                              width: 52,
                              height: 52,
                              alignment: Alignment.center,
                              decoration: BoxDecoration(
                                color: AppColors.accent.withValues(alpha: 0.12),
                                borderRadius: BorderRadius.circular(14),
                              ),
                              child: Text('+${t['rewardMinutes']}',
                                  style: const TextStyle(color: AppColors.accent, fontWeight: FontWeight.w900, fontSize: 16)),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                                Text(t['title'] ?? '', style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
                                const SizedBox(height: 4),
                                Wrap(spacing: 6, children: [
                                  StatusChip(statusLabels[status] ?? status, statusColor(status)),
                                  if (t['dueDate'] != null) Text('Hạn ${fmtDate(t['dueDate'])}', style: const TextStyle(fontSize: 12)),
                                ]),
                              ]),
                            ),
                            if (canSubmit)
                              FilledButton(
                                style: FilledButton.styleFrom(backgroundColor: AppColors.accent, minimumSize: const Size(70, 40)),
                                onPressed: () => _submitTask(t),
                                child: const Text('Nộp'),
                              ),
                          ]),
                        ),
                      );
                    },
                  ),
                ),
    );
  }

  // ---------------- Tab Ứng dụng (quy tắc từ bố mẹ) ----------------
  Widget _rulesTab() {
    final rules = (_me?['rules'] as List?) ?? [];
    return Scaffold(
      appBar: AppBar(title: const Text('Quy tắc ứng dụng')),
      body: rules.isEmpty
          ? const EmptyView(icon: Icons.apps, message: 'Bố mẹ chưa đặt quy tắc nào')
          : ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: rules.length,
              separatorBuilder: (_, __) => const SizedBox(height: 8),
              itemBuilder: (_, i) {
                final r = rules[i];
                final blocked = r['isBlocked'] == true;
                final limit = r['dailyLimitMinutes'] as int;
                return Card(
                  child: ListTile(
                    leading: Icon(blocked ? Icons.block : Icons.check_circle,
                        color: blocked ? AppColors.danger : AppColors.success),
                    title: Text(r['appName'] ?? ''),
                    subtitle: Text(r['category'] ?? ''),
                    trailing: Text(
                      blocked ? 'Bị chặn' : limit == 0 ? 'Thoải mái' : '${fmtMinutes(limit)}/ngày',
                      style: TextStyle(fontWeight: FontWeight.w700, color: blocked ? AppColors.danger : AppColors.text),
                    ),
                  ),
                );
              },
            ),
    );
  }
}
