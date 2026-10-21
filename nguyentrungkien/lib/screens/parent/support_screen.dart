import 'package:flutter/material.dart';

import '../../core/api.dart';
import '../../core/utils.dart';
import '../../theme.dart';
import '../../widgets/common.dart';

/// Phụ huynh gửi / sửa / xóa yêu cầu hỗ trợ, xem phản hồi của nhân viên.
class SupportScreen extends StatefulWidget {
  const SupportScreen({super.key});

  @override
  State<SupportScreen> createState() => _SupportScreenState();
}

class _SupportScreenState extends State<SupportScreen> {
  List<dynamic>? _list;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final res = await Api.I.get('/api/support/my-tickets');
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

  Future<void> _form([Map<String, dynamic>? t]) async {
    final subject = TextEditingController(text: t?['subject'] ?? '');
    final content = TextEditingController(text: t?['content'] ?? '');
    var priority = (t?['priority'] as String?) ?? 'Normal';
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
              Text(t == null ? 'Gửi yêu cầu hỗ trợ' : 'Sửa yêu cầu', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
              const SizedBox(height: 14),
              TextField(controller: subject, decoration: const InputDecoration(labelText: 'Tiêu đề')),
              const SizedBox(height: 12),
              TextField(controller: content, maxLines: 4, decoration: const InputDecoration(labelText: 'Nội dung')),
              const SizedBox(height: 12),
              SegmentedButton<String>(
                segments: const [
                  ButtonSegment(value: 'Low', label: Text('Thấp')),
                  ButtonSegment(value: 'Normal', label: Text('Thường')),
                  ButtonSegment(value: 'High', label: Text('Gấp')),
                ],
                selected: {priority},
                onSelectionChanged: (v) => set(() => priority = v.first),
              ),
              const SizedBox(height: 16),
              FilledButton(
                onPressed: () {
                  if (subject.text.trim().isEmpty || content.text.trim().isEmpty) return;
                  Navigator.pop(ctx, true);
                },
                child: const Text('Gửi'),
              ),
            ],
          ),
        ),
      ),
    );
    if (ok != true) return;
    final body = {'subject': subject.text.trim(), 'content': content.text.trim(), 'priority': priority};
    try {
      final res = t == null
          ? await Api.I.post('/api/support/my-tickets', body)
          : await Api.I.put('/api/support/my-tickets/${t['id']}', body);
      if (mounted) showMsg(context, res['message']);
      _load();
    } on ApiException catch (e) {
      if (mounted) showMsg(context, e.message, error: true);
    }
  }

  Future<void> _delete(Map t) async {
    if (!await confirm(context, 'Xóa yêu cầu', 'Xóa yêu cầu "${t['subject']}"?', danger: true)) return;
    try {
      final res = await Api.I.delete('/api/support/my-tickets/${t['id']}');
      if (mounted) showMsg(context, res['message']);
      _load();
    } on ApiException catch (e) {
      if (mounted) showMsg(context, e.message, error: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Hỗ trợ')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _form(),
        icon: const Icon(Icons.add_comment_outlined),
        label: const Text('Gửi yêu cầu'),
      ),
      body: _error != null
          ? ErrorView(message: _error!, onRetry: _load)
          : _list == null
              ? const Center(child: CircularProgressIndicator())
              : _list!.isEmpty
                  ? const EmptyView(icon: Icons.support_agent, message: 'Bạn chưa gửi yêu cầu hỗ trợ nào')
                  : RefreshIndicator(
                      onRefresh: _load,
                      child: ListView.separated(
                        padding: const EdgeInsets.fromLTRB(16, 4, 16, 90),
                        itemCount: _list!.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 10),
                        itemBuilder: (_, i) {
                          final t = Map<String, dynamic>.from(_list![i]);
                          final open = t['status'] == 'Open';
                          return Card(
                            child: Padding(
                              padding: const EdgeInsets.all(14),
                              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                                Row(children: [
                                  Expanded(child: Text(t['subject'] ?? '', style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16))),
                                  StatusChip(statusLabels[t['status']] ?? t['status'], statusColor(t['status'])),
                                ]),
                                const SizedBox(height: 6),
                                Text(t['content'] ?? ''),
                                const SizedBox(height: 6),
                                Text(fmtDateTime(t['createdAt']), style: const TextStyle(fontSize: 12, color: AppColors.muted)),
                                if (t['staffReply'] != null) ...[
                                  const SizedBox(height: 10),
                                  Container(
                                    width: double.infinity,
                                    padding: const EdgeInsets.all(12),
                                    decoration: BoxDecoration(
                                      color: AppColors.success.withValues(alpha: 0.08),
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: Text('💬 ${t['staffName'] ?? 'Nhân viên'}: ${t['staffReply']}'),
                                  ),
                                ],
                                if (open)
                                  Row(mainAxisAlignment: MainAxisAlignment.end, children: [
                                    TextButton(onPressed: () => _form(t), child: const Text('Sửa')),
                                    TextButton(
                                      onPressed: () => _delete(t),
                                      child: const Text('Xóa', style: TextStyle(color: AppColors.danger)),
                                    ),
                                  ]),
                              ]),
                            ),
                          );
                        },
                      ),
                    ),
    );
  }
}
