import 'package:flutter/material.dart';

import '../theme.dart';

String two(int n) => n.toString().padLeft(2, '0');

DateTime? parseDate(dynamic v) {
  if (v == null) return null;
  final s = v.toString();
  // API trả giờ UTC (không có hậu tố Z) -> chuyển về giờ máy
  final d = DateTime.tryParse(s.endsWith('Z') || s.contains('+') ? s : '${s}Z');
  return d?.toLocal();
}

String fmtDate(dynamic v) {
  final d = v is DateTime ? v : parseDate(v);
  if (d == null) return '';
  return '${two(d.day)}/${two(d.month)}/${d.year}';
}

String fmtDateTime(dynamic v) {
  final d = v is DateTime ? v : parseDate(v);
  if (d == null) return '';
  return '${two(d.hour)}:${two(d.minute)} ${two(d.day)}/${two(d.month)}/${d.year}';
}

String timeAgo(dynamic v) {
  final d = v is DateTime ? v : parseDate(v);
  if (d == null) return '';
  final diff = DateTime.now().difference(d);
  if (diff.inSeconds < 60) return 'vừa xong';
  if (diff.inMinutes < 60) return '${diff.inMinutes} phút trước';
  if (diff.inHours < 24) return '${diff.inHours} giờ trước';
  if (diff.inDays < 7) return '${diff.inDays} ngày trước';
  return fmtDate(d);
}

String fmtMinutes(int m) {
  if (m <= 0) return '0 phút';
  final h = m ~/ 60;
  final r = m % 60;
  if (h == 0) return '$r phút';
  return r == 0 ? '$h giờ' : '$h giờ $r phút';
}

Color hexColor(String? hex, [Color fallback = AppColors.primary]) {
  if (hex == null || hex.isEmpty) return fallback;
  final h = hex.replaceAll('#', '');
  final v = int.tryParse(h.length == 6 ? 'FF$h' : h, radix: 16);
  return v == null ? fallback : Color(v);
}

String colorHex(Color c) {
  final argb = c.toARGB32();
  return '#${(argb & 0xFFFFFF).toRadixString(16).padLeft(6, '0').toUpperCase()}';
}

void showMsg(BuildContext context, String msg, {bool error = false}) {
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(
      content: Text(msg),
      backgroundColor: error ? AppColors.danger : AppColors.text,
    ));
}

Future<bool> confirm(BuildContext context, String title, String message,
    {String ok = 'Đồng ý', bool danger = false}) async {
  final res = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text(title),
      content: Text(message),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Hủy')),
        FilledButton(
          style: danger ? FilledButton.styleFrom(backgroundColor: AppColors.danger, minimumSize: const Size(90, 44)) : FilledButton.styleFrom(minimumSize: const Size(90, 44)),
          onPressed: () => Navigator.pop(ctx, true),
          child: Text(ok),
        ),
      ],
    ),
  );
  return res == true;
}

const statusLabels = {
  'Assigned': 'Chưa làm',
  'Submitted': 'Chờ duyệt',
  'Approved': 'Đã duyệt',
  'Rejected': 'Làm lại',
  'Open': 'Mới',
  'InProgress': 'Đang xử lý',
  'Resolved': 'Đã xong',
};

Color statusColor(String? s) {
  switch (s) {
    case 'Submitted':
    case 'InProgress':
      return AppColors.warning;
    case 'Approved':
    case 'Resolved':
      return AppColors.success;
    case 'Rejected':
      return AppColors.danger;
    default:
      return AppColors.primary;
  }
}
