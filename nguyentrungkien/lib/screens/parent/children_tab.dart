import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/api.dart';
import '../../core/session.dart';
import '../../core/utils.dart';
import '../../theme.dart';
import '../../widgets/common.dart';
import 'child_detail_screen.dart';
import 'child_form_screen.dart';

/// Trang chủ phụ huynh: danh sách các con.
class ChildrenTab extends StatefulWidget {
  const ChildrenTab({super.key});

  @override
  State<ChildrenTab> createState() => _ChildrenTabState();
}

class _ChildrenTabState extends State<ChildrenTab> {
  List<dynamic>? _children;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final res = await Api.I.get('/api/children');
      if (mounted) {
        setState(() {
          _children = res as List;
          _error = null;
        });
      }
    } on ApiException catch (e) {
      if (mounted) setState(() => _error = e.message);
    }
  }

  Future<void> _add() async {
    final ok = await Navigator.push<bool>(context, MaterialPageRoute(builder: (_) => const ChildFormScreen()));
    if (ok == true) _load();
  }

  Future<void> _open(Map<String, dynamic> c) async {
    await Navigator.push(context, MaterialPageRoute(builder: (_) => ChildDetailScreen(childId: c['id'], name: c['name'])));
    _load();
  }

  @override
  Widget build(BuildContext context) {
    final s = context.watch<Session>();
    final list = _children;
    final totalPending = list?.fold<int>(0, (sum, c) => sum + (c['pendingTasks'] as int)) ?? 0;
    final totalAlerts = list?.fold<int>(0, (sum, c) => sum + (c['unreadAlerts'] as int)) ?? 0;

    return Scaffold(
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _add,
        icon: const Icon(Icons.add),
        label: const Text('Thêm con'),
      ),
      body: RefreshIndicator(
        onRefresh: _load,
        child: ListView(
          padding: EdgeInsets.zero,
          children: [
            GradientHeader(
              colors: AppColors.parentGradient,
              subtitle: 'Xin chào phụ huynh 👋',
              title: s.fullName,
              trailing: const Icon(Icons.shield_moon_rounded, color: Colors.white, size: 36),
              bottom: Row(children: [
                _summary(Icons.child_care, '${list?.length ?? 0}', 'Con'),
                _summary(Icons.pending_actions, '$totalPending', 'Chờ duyệt'),
                _summary(Icons.notifications_active, '$totalAlerts', 'Cảnh báo'),
              ]),
            ),
            if (_error != null)
              ErrorView(message: _error!, onRetry: _load)
            else if (list == null)
              const Padding(padding: EdgeInsets.all(40), child: Center(child: CircularProgressIndicator()))
            else if (list.isEmpty)
              EmptyView(
                icon: Icons.child_friendly,
                message: 'Chưa có hồ sơ của con.\nThêm hồ sơ rồi ghép điện thoại của con bằng mã QR.',
                action: FilledButton.icon(
                  style: FilledButton.styleFrom(minimumSize: const Size(180, 48)),
                  onPressed: _add,
                  icon: const Icon(Icons.add),
                  label: const Text('Thêm hồ sơ'),
                ),
              )
            else ...[
              const Padding(padding: EdgeInsets.fromLTRB(16, 0, 16, 0), child: SectionTitle('Các con của bạn')),
              ...list.map((raw) {
                final c = Map<String, dynamic>.from(raw);
                return Padding(padding: const EdgeInsets.fromLTRB(16, 0, 16, 12), child: _childCard(c));
              }),
              const SizedBox(height: 80),
            ],
          ],
        ),
      ),
    );
  }

  Widget _summary(IconData icon, String value, String label) => Expanded(
        child: Container(
          margin: const EdgeInsets.only(right: 8),
          padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 10),
          decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.18), borderRadius: BorderRadius.circular(14)),
          child: Row(children: [
            Icon(icon, color: Colors.white, size: 22),
            const SizedBox(width: 8),
            Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(value, style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w800)),
              Text(label, style: const TextStyle(color: Colors.white70, fontSize: 11)),
            ]),
          ]),
        ),
      );

  Widget _childCard(Map<String, dynamic> c) {
    final color = hexColor(c['avatarColor']);
    final last = c['lastLocation'] as Map?;
    final battery = last?['batteryLevel'];
    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => _open(c),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(children: [
            Row(children: [
              Avatar(name: c['name'] ?? '', color: color, size: 54),
              const SizedBox(width: 14),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(c['name'] ?? '', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
                  const SizedBox(height: 4),
                  Row(children: [
                    Icon(Icons.location_on, size: 16, color: last == null ? AppColors.muted : AppColors.success),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        last == null ? 'Chưa có vị trí' : 'Cập nhật ${timeAgo(last['recordedAt'])}',
                        style: const TextStyle(color: AppColors.muted, fontSize: 13),
                      ),
                    ),
                  ]),
                ]),
              ),
              if (battery != null)
                Row(children: [
                  Icon(battery <= 15 ? Icons.battery_alert : Icons.battery_5_bar,
                      color: battery <= 15 ? AppColors.danger : AppColors.success, size: 20),
                  Text('$battery%', style: const TextStyle(fontWeight: FontWeight.w700)),
                ]),
            ]),
            const SizedBox(height: 14),
            Row(children: [
              _chip(Icons.timer_outlined, fmtMinutes(c['dailyLimitMinutes'] ?? 0), AppColors.primary),
              _chip(Icons.savings_outlined, '+${c['bonusMinutes']} phút', AppColors.accent),
              _chip(Icons.phone_android, '${c['deviceCount']} máy', AppColors.success),
            ]),
            if ((c['pendingTasks'] ?? 0) > 0 || (c['unreadAlerts'] ?? 0) > 0) ...[
              const SizedBox(height: 10),
              Row(children: [
                if ((c['pendingTasks'] ?? 0) > 0)
                  StatusChip('${c['pendingTasks']} nhiệm vụ chờ duyệt', AppColors.warning),
                const SizedBox(width: 6),
                if ((c['unreadAlerts'] ?? 0) > 0)
                  StatusChip('${c['unreadAlerts']} cảnh báo mới', AppColors.danger),
              ]),
            ],
          ]),
        ),
      ),
    );
  }

  Widget _chip(IconData icon, String text, Color color) => Expanded(
        child: Container(
          margin: const EdgeInsets.only(right: 6),
          padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 6),
          decoration: BoxDecoration(color: color.withValues(alpha: 0.08), borderRadius: BorderRadius.circular(12)),
          child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            Icon(icon, size: 16, color: color),
            const SizedBox(width: 4),
            Flexible(
              child: Text(text, overflow: TextOverflow.ellipsis, style: TextStyle(color: color, fontWeight: FontWeight.w700, fontSize: 12)),
            ),
          ]),
        ),
      );
}
