import 'package:flutter/material.dart';

import '../../core/api.dart';
import '../../core/biometric.dart';
import '../../core/utils.dart';
import '../../theme.dart';
import '../../widgets/common.dart';

/// TÍNH NĂNG MỚI – Ví thời gian: giao nhiệm vụ, duyệt minh chứng (xác nhận vân tay) để cộng phút.
class TasksTab extends StatefulWidget {
  const TasksTab({super.key});

  @override
  State<TasksTab> createState() => _TasksTabState();
}

class _TasksTabState extends State<TasksTab> {
  List<dynamic>? _tasks;
  List<dynamic> _children = [];
  String? _status;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final r = await Future.wait([
        Api.I.get('/api/tasks', query: {'status': _status}),
        Api.I.get('/api/children'),
      ]);
      if (mounted) {
        setState(() {
          _tasks = r[0] as List;
          _children = r[1] as List;
          _error = null;
        });
      }
    } on ApiException catch (e) {
      if (mounted) setState(() => _error = e.message);
    }
  }

  Future<void> _form([Map<String, dynamic>? task]) async {
    await _load(); // lấy lại danh sách con (tên có thể vừa được sửa ở tab khác)
    if (!mounted) return;
    if (_children.isEmpty) {
      showMsg(context, 'Hãy thêm hồ sơ của con trước', error: true);
      return;
    }
    final title = TextEditingController(text: task?['title'] ?? '');
    final desc = TextEditingController(text: task?['description'] ?? '');
    int childId = task?['childId'] ?? _children.first['id'];
    var reward = ((task?['rewardMinutes'] ?? 15) as int).toDouble();
    DateTime? due = parseDate(task?['dueDate']);

    final ok = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, set) => Padding(
          padding: EdgeInsets.fromLTRB(20, 20, 20, MediaQuery.of(ctx).viewInsets.bottom + 20),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(task == null ? 'Giao nhiệm vụ mới' : 'Sửa nhiệm vụ',
                    style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
                const SizedBox(height: 14),
                DropdownButtonFormField<int>(
                  initialValue: childId,
                  decoration: const InputDecoration(labelText: 'Giao cho'),
                  items: _children
                      .map((c) => DropdownMenuItem<int>(value: c['id'] as int, child: Text(c['name'] ?? '')))
                      .toList(),
                  onChanged: task != null ? null : (v) => set(() => childId = v ?? childId),
                ),
                const SizedBox(height: 12),
                TextField(controller: title, decoration: const InputDecoration(labelText: 'Nhiệm vụ (VD: Đọc sách 30 phút)')),
                const SizedBox(height: 12),
                TextField(controller: desc, maxLines: 2, decoration: const InputDecoration(labelText: 'Mô tả / yêu cầu minh chứng')),
                const SizedBox(height: 12),
                Text('Phần thưởng: ${reward.round()} phút', style: const TextStyle(fontWeight: FontWeight.w700)),
                Slider(value: reward, min: 5, max: 120, divisions: 23, onChanged: (v) => set(() => reward = v)),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.event),
                  title: Text(due == null ? 'Không có hạn chót' : 'Hạn: ${fmtDate(due)}'),
                  trailing: due == null ? null : IconButton(icon: const Icon(Icons.close), onPressed: () => set(() => due = null)),
                  onTap: () async {
                    final d = await showDatePicker(
                      context: ctx,
                      initialDate: due ?? DateTime.now().add(const Duration(days: 1)),
                      firstDate: DateTime.now().subtract(const Duration(days: 1)),
                      lastDate: DateTime.now().add(const Duration(days: 365)),
                    );
                    if (d != null) set(() => due = d);
                  },
                ),
                const SizedBox(height: 8),
                FilledButton(
                  onPressed: () {
                    if (title.text.trim().isEmpty) return;
                    Navigator.pop(ctx, true);
                  },
                  child: Text(task == null ? 'Giao nhiệm vụ' : 'Lưu'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
    if (ok != true) return;
    final body = {
      'childId': childId,
      'title': title.text.trim(),
      'description': desc.text.trim(),
      'rewardMinutes': reward.round(),
      'dueDate': due == null ? null : DateTime(due!.year, due!.month, due!.day, 23, 59).toUtc().toIso8601String(),
    };
    try {
      final res = task == null ? await Api.I.post('/api/tasks', body) : await Api.I.put('/api/tasks/${task['id']}', body);
      if (mounted) showMsg(context, res['message']);
      _load();
    } on ApiException catch (e) {
      if (mounted) showMsg(context, e.message, error: true);
    }
  }

  Future<void> _delete(Map t) async {
    if (!await confirm(context, 'Xóa nhiệm vụ', 'Xóa "${t['title']}"?', danger: true)) return;
    try {
      final res = await Api.I.delete('/api/tasks/${t['id']}');
      if (mounted) showMsg(context, res['message']);
      _load();
    } on ApiException catch (e) {
      if (mounted) showMsg(context, e.message, error: true);
    }
  }

  Future<void> _review(Map<String, dynamic> t) async {
    final comment = TextEditingController();
    final approve = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) => Padding(
        padding: EdgeInsets.fromLTRB(20, 20, 20, MediaQuery.of(ctx).viewInsets.bottom + 20),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(t['title'] ?? '', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
              Text('${t['childName']} • thưởng ${t['rewardMinutes']} phút', style: const TextStyle(color: AppColors.muted)),
              const SizedBox(height: 12),
              if (t['proofImageUrl'] != null)
                ClipRRect(
                  borderRadius: BorderRadius.circular(16),
                  child: Image.network(
                    Api.I.fileUrl(t['proofImageUrl']),
                    height: 260,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => const SizedBox(height: 80, child: Center(child: Text('Không tải được ảnh'))),
                  ),
                )
              else
                const Card(child: ListTile(leading: Icon(Icons.image_not_supported), title: Text('Không có ảnh minh chứng'))),
              if ((t['childNote'] ?? '').toString().isNotEmpty) ...[
                const SizedBox(height: 10),
                Text('Con nhắn: "${t['childNote']}"', style: const TextStyle(fontStyle: FontStyle.italic)),
              ],
              const SizedBox(height: 12),
              TextField(controller: comment, decoration: const InputDecoration(labelText: 'Nhận xét cho con')),
              const SizedBox(height: 14),
              Row(children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => Navigator.pop(ctx, false),
                    icon: const Icon(Icons.close, color: AppColors.danger),
                    label: const Text('Làm lại'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: FilledButton.icon(
                    style: FilledButton.styleFrom(backgroundColor: AppColors.success),
                    onPressed: () => Navigator.pop(ctx, true),
                    icon: const Icon(Icons.fingerprint),
                    label: const Text('Duyệt'),
                  ),
                ),
              ]),
            ],
          ),
        ),
      ),
    );
    if (approve == null) return;
    if (approve) {
      // Chức năng e: duyệt cộng phút phải xác nhận vân tay -> con không tự duyệt được trên máy bố mẹ
      final err = await Biometric.authenticate('Xác nhận vân tay để cộng ${t['rewardMinutes']} phút cho ${t['childName']}');
      if (err != null) {
        if (mounted) showMsg(context, err, error: true);
        return;
      }
    }
    try {
      final res = await Api.I.post('/api/tasks/${t['id']}/review', {'approve': approve, 'comment': comment.text.trim()});
      if (mounted) showMsg(context, res['message']);
      _load();
    } on ApiException catch (e) {
      if (mounted) showMsg(context, e.message, error: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final filters = <String?, String>{null: 'Tất cả', 'Submitted': 'Chờ duyệt', 'Assigned': 'Chưa làm', 'Approved': 'Đã duyệt'};
    return Scaffold(
      appBar: AppBar(title: const Text('Nhiệm vụ & Ví thời gian')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _form(),
        icon: const Icon(Icons.add_task),
        label: const Text('Giao nhiệm vụ'),
      ),
      body: Column(children: [
        Container(
          margin: const EdgeInsets.fromLTRB(16, 0, 16, 8),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            gradient: const LinearGradient(colors: AppColors.childGradient),
            borderRadius: BorderRadius.circular(18),
          ),
          child: const Row(children: [
            Icon(Icons.savings, color: Colors.white, size: 34),
            SizedBox(width: 12),
            Expanded(
              child: Text(
                'Con làm nhiệm vụ → gửi ảnh minh chứng → bạn duyệt bằng vân tay → con được cộng phút vào Ví thời gian.',
                style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600, height: 1.35),
              ),
            ),
          ]),
        ),
        SizedBox(
          height: 44,
          child: ListView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            children: filters.entries
                .map((e) => Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: ChoiceChip(
                        label: Text(e.value),
                        selected: _status == e.key,
                        onSelected: (_) {
                          setState(() => _status = e.key);
                          _load();
                        },
                      ),
                    ))
                .toList(),
          ),
        ),
        Expanded(
          child: _error != null
              ? ErrorView(message: _error!, onRetry: _load)
              : _tasks == null
                  ? const Center(child: CircularProgressIndicator())
                  : _tasks!.isEmpty
                      ? const EmptyView(icon: Icons.task_alt, message: 'Chưa có nhiệm vụ nào')
                      : RefreshIndicator(
                          onRefresh: _load,
                          child: ListView.separated(
                            padding: const EdgeInsets.fromLTRB(16, 8, 16, 90),
                            itemCount: _tasks!.length,
                            separatorBuilder: (_, __) => const SizedBox(height: 10),
                            itemBuilder: (_, i) => _taskCard(Map<String, dynamic>.from(_tasks![i])),
                          ),
                        ),
        ),
      ]),
    );
  }

  Widget _taskCard(Map<String, dynamic> t) {
    final status = t['status'] as String;
    final submitted = status == 'Submitted';
    return Card(
      color: submitted ? AppColors.warning.withValues(alpha: 0.08) : null,
      child: ListTile(
        contentPadding: const EdgeInsets.fromLTRB(14, 8, 4, 8),
        onTap: submitted ? () => _review(t) : (status == 'Approved' ? null : () => _form(t)),
        leading: CircleAvatar(
          backgroundColor: statusColor(status).withValues(alpha: 0.12),
          child: Icon(
            status == 'Approved'
                ? Icons.verified
                : submitted
                    ? Icons.hourglass_top
                    : status == 'Rejected'
                        ? Icons.replay
                        : Icons.flag_outlined,
            color: statusColor(status),
          ),
        ),
        title: Text(t['title'] ?? '', style: const TextStyle(fontWeight: FontWeight.w700)),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 4),
          child: Wrap(spacing: 6, runSpacing: 4, crossAxisAlignment: WrapCrossAlignment.center, children: [
            Text('${t['childName']}', style: const TextStyle(fontWeight: FontWeight.w600)),
            StatusChip(statusLabels[status] ?? status, statusColor(status)),
            StatusChip('+${t['rewardMinutes']}p', AppColors.accent),
            if (t['dueDate'] != null) Text('Hạn ${fmtDate(t['dueDate'])}', style: const TextStyle(fontSize: 12)),
          ]),
        ),
        trailing: PopupMenuButton<String>(
          onSelected: (v) {
            if (v == 'review') _review(t);
            if (v == 'edit') _form(t);
            if (v == 'delete') _delete(t);
          },
          itemBuilder: (_) => [
            if (submitted) const PopupMenuItem(value: 'review', child: Text('Duyệt minh chứng')),
            if (status != 'Approved') const PopupMenuItem(value: 'edit', child: Text('Sửa')),
            const PopupMenuItem(value: 'delete', child: Text('Xóa')),
          ],
        ),
      ),
    );
  }
}
