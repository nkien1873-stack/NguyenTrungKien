import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/api.dart';
import '../../core/session.dart';
import '../../core/utils.dart';
import '../../theme.dart';
import '../../widgets/common.dart';
import '../common/account_screen.dart';

/// DASHBOARD NHÂN VIÊN HỖ TRỢ: xử lý ticket + tra cứu phụ huynh.
class StaffHome extends StatefulWidget {
  const StaffHome({super.key});

  @override
  State<StaffHome> createState() => _StaffHomeState();
}

class _StaffHomeState extends State<StaffHome> {
  int _tab = 0;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(index: _tab, children: const [
        _TicketsTab(),
        _ParentsTab(),
        AccountScreen(gradient: AppColors.staffGradient),
      ]),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _tab,
        onDestinationSelected: (i) => setState(() => _tab = i),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.support_agent_outlined), selectedIcon: Icon(Icons.support_agent), label: 'Hỗ trợ'),
          NavigationDestination(icon: Icon(Icons.family_restroom_outlined), selectedIcon: Icon(Icons.family_restroom), label: 'Phụ huynh'),
          NavigationDestination(icon: Icon(Icons.manage_accounts_outlined), selectedIcon: Icon(Icons.manage_accounts), label: 'Tài khoản'),
        ],
      ),
    );
  }
}

class _TicketsTab extends StatefulWidget {
  const _TicketsTab();

  @override
  State<_TicketsTab> createState() => _TicketsTabState();
}

class _TicketsTabState extends State<_TicketsTab> {
  Map<String, dynamic>? _stats;
  List<dynamic>? _tickets;
  String? _status;
  bool _mine = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final results = await Future.wait([
        Api.I.get('/api/support/dashboard'),
        Api.I.get('/api/support/tickets', query: {'status': _status, 'mine': _mine}),
      ]);
      if (mounted) {
        setState(() {
          _stats = Map<String, dynamic>.from(results[0]);
          _tickets = results[1] as List;
          _error = null;
        });
      }
    } on ApiException catch (e) {
      if (mounted) setState(() => _error = e.message);
    }
  }

  Future<void> _handle(Map<String, dynamic> t) async {
    final reply = TextEditingController(text: t['staffReply'] ?? '');
    var status = t['status'] as String;
    final ok = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheet) => Padding(
          padding: EdgeInsets.fromLTRB(20, 20, 20, MediaQuery.of(ctx).viewInsets.bottom + 20),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(t['subject'] ?? '', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
                const SizedBox(height: 6),
                Text('${t['parentName']} • ${t['parentEmail']}${t['parentPhone'] != null ? ' • ${t['parentPhone']}' : ''}',
                    style: const TextStyle(color: AppColors.muted)),
                const SizedBox(height: 12),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(color: AppColors.bg, borderRadius: BorderRadius.circular(12)),
                  child: Text(t['content'] ?? ''),
                ),
                const SizedBox(height: 14),
                TextField(
                  controller: reply,
                  maxLines: 4,
                  decoration: const InputDecoration(labelText: 'Phản hồi cho phụ huynh'),
                ),
                const SizedBox(height: 12),
                SegmentedButton<String>(
                  segments: const [
                    ButtonSegment(value: 'Open', label: Text('Mới')),
                    ButtonSegment(value: 'InProgress', label: Text('Đang xử lý')),
                    ButtonSegment(value: 'Resolved', label: Text('Đã xong')),
                  ],
                  selected: {status},
                  onSelectionChanged: (v) => setSheet(() => status = v.first),
                ),
                const SizedBox(height: 16),
                FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Lưu')),
              ],
            ),
          ),
        ),
      ),
    );
    if (ok != true) return;
    try {
      final res = await Api.I.put('/api/support/tickets/${t['id']}', {'reply': reply.text, 'status': status});
      if (mounted) showMsg(context, res['message']);
      _load();
    } on ApiException catch (e) {
      if (mounted) showMsg(context, e.message, error: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = context.watch<Session>();
    final st = _stats;
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        padding: EdgeInsets.zero,
        children: [
          GradientHeader(
            colors: AppColors.staffGradient,
            subtitle: 'Dashboard nhân viên hỗ trợ',
            title: s.fullName,
            trailing: const Icon(Icons.support_agent, color: Colors.white, size: 36),
            bottom: st == null
                ? null
                : Row(children: [
                    _pill('Mới', st['open']),
                    _pill('Đang xử lý', st['inProgress']),
                    _pill('Của tôi', st['mine']),
                    _pill('Xong hôm nay', st['resolvedToday']),
                  ]),
          ),
          if (_error != null)
            ErrorView(message: _error!, onRetry: _load)
          else ...[
            SizedBox(
              height: 56,
              child: ListView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                children: [
                  FilterChip(
                    label: const Text('Của tôi'),
                    selected: _mine,
                    onSelected: (v) {
                      setState(() => _mine = v);
                      _load();
                    },
                  ),
                  const SizedBox(width: 8),
                  ...[null, 'Open', 'InProgress', 'Resolved'].map((x) => Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: ChoiceChip(
                          label: Text(x == null ? 'Tất cả' : statusLabels[x]!),
                          selected: _status == x,
                          onSelected: (_) {
                            setState(() => _status = x);
                            _load();
                          },
                        ),
                      )),
                ],
              ),
            ),
            if (_tickets == null)
              const Padding(padding: EdgeInsets.all(40), child: Center(child: CircularProgressIndicator()))
            else if (_tickets!.isEmpty)
              const EmptyView(icon: Icons.inbox_outlined, message: 'Không có yêu cầu hỗ trợ nào')
            else
              ..._tickets!.map((raw) {
                final t = Map<String, dynamic>.from(raw);
                return Padding(
                  padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
                  child: Card(
                    child: ListTile(
                      contentPadding: const EdgeInsets.all(14),
                      onTap: () => _handle(t),
                      title: Row(children: [
                        if (t['priority'] == 'High')
                          const Padding(
                            padding: EdgeInsets.only(right: 6),
                            child: Icon(Icons.priority_high, color: AppColors.danger, size: 18),
                          ),
                        Expanded(child: Text(t['subject'] ?? '', style: const TextStyle(fontWeight: FontWeight.w700))),
                        StatusChip(statusLabels[t['status']] ?? t['status'], statusColor(t['status'])),
                      ]),
                      subtitle: Padding(
                        padding: const EdgeInsets.only(top: 6),
                        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Text(t['content'] ?? '', maxLines: 2, overflow: TextOverflow.ellipsis),
                          const SizedBox(height: 6),
                          Text('${t['parentName']} • ${timeAgo(t['createdAt'])}'
                              '${t['staffName'] != null ? ' • NV: ${t['staffName']}' : ''}',
                              style: const TextStyle(fontSize: 12, color: AppColors.muted)),
                        ]),
                      ),
                    ),
                  ),
                );
              }),
            const SizedBox(height: 20),
          ],
        ],
      ),
    );
  }

  Widget _pill(String label, dynamic value) => Expanded(
        child: Container(
          margin: const EdgeInsets.only(right: 8),
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.18), borderRadius: BorderRadius.circular(14)),
          child: Column(children: [
            Text('$value', style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w800)),
            Text(label, textAlign: TextAlign.center, style: const TextStyle(color: Colors.white70, fontSize: 11)),
          ]),
        ),
      );
}

class _ParentsTab extends StatefulWidget {
  const _ParentsTab();

  @override
  State<_ParentsTab> createState() => _ParentsTabState();
}

class _ParentsTabState extends State<_ParentsTab> {
  final _search = TextEditingController();
  List<dynamic>? _list;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final res = await Api.I.get('/api/support/parents', query: {'search': _search.text});
      if (mounted) {
        setState(() {
          _list = res as List;
          _error = null;
        });
      }
    } on ApiException catch (e) {
      if (mounted) setState(() => _error = e.message);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Tra cứu phụ huynh')),
      body: Column(children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
          child: TextField(
            controller: _search,
            onSubmitted: (_) => _load(),
            decoration: InputDecoration(
              hintText: 'Tên, email, tên đăng nhập',
              prefixIcon: const Icon(Icons.search),
              suffixIcon: IconButton(onPressed: _load, icon: const Icon(Icons.arrow_forward)),
            ),
          ),
        ),
        Expanded(
          child: _error != null
              ? ErrorView(message: _error!, onRetry: _load)
              : _list == null
                  ? const Center(child: CircularProgressIndicator())
                  : _list!.isEmpty
                      ? const EmptyView(icon: Icons.person_search, message: 'Không tìm thấy phụ huynh')
                      : RefreshIndicator(
                          onRefresh: _load,
                          child: ListView.separated(
                            padding: const EdgeInsets.fromLTRB(16, 8, 16, 20),
                            itemCount: _list!.length,
                            separatorBuilder: (_, __) => const SizedBox(height: 10),
                            itemBuilder: (_, i) {
                              final p = Map<String, dynamic>.from(_list![i]);
                              return Card(
                                child: ListTile(
                                  leading: Avatar(name: p['fullName'] ?? '', color: const Color(0xFF0F9D8A)),
                                  title: Text(p['fullName'] ?? '', style: const TextStyle(fontWeight: FontWeight.w700)),
                                  subtitle: Text('${p['email']}\n${p['childCount']} trẻ • ${p['deviceCount']} thiết bị'
                                      '${p['isLocked'] == true ? ' • ĐÃ KHÓA' : ''}'),
                                  isThreeLine: true,
                                  trailing: Text(fmtDate(p['createdAt']), style: const TextStyle(fontSize: 12, color: AppColors.muted)),
                                ),
                              );
                            },
                          ),
                        ),
        ),
      ]),
    );
  }
}
