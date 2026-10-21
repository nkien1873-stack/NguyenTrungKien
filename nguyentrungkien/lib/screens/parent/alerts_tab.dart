import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import '../../core/api.dart';
import '../../core/utils.dart';
import '../../theme.dart';
import '../../widgets/common.dart';

/// Cảnh báo: SOS, rời vùng an toàn, pin yếu, minh chứng mới...
class AlertsTab extends StatefulWidget {
  final VoidCallback onChanged;
  final bool active;
  const AlertsTab({super.key, required this.onChanged, required this.active});

  @override
  State<AlertsTab> createState() => _AlertsTabState();
}

class _AlertsTabState extends State<AlertsTab> {
  List<dynamic>? _alerts;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didUpdateWidget(covariant AlertsTab old) {
    super.didUpdateWidget(old);
    if (widget.active && !old.active) _load();
  }

  Future<void> _load() async {
    try {
      final res = await Api.I.get('/api/alerts');
      if (mounted) {
        setState(() {
          _alerts = res as List;
          _error = null;
        });
      }
    } on ApiException catch (e) {
      if (mounted) setState(() => _error = e.message);
    }
  }

  Future<void> _readAll() async {
    try {
      final res = await Api.I.post('/api/alerts/read-all');
      if (mounted) showMsg(context, res['message']);
      await _load();
      widget.onChanged();
    } on ApiException catch (e) {
      if (mounted) showMsg(context, e.message, error: true);
    }
  }

  Future<void> _open(Map<String, dynamic> a) async {
    if (a['isRead'] != true) {
      try {
        await Api.I.patch('/api/alerts/${a['id']}/read');
        widget.onChanged();
        _load();
      } catch (_) {}
    }
    if (a['latitude'] == null || !mounted) return;
    final p = LatLng((a['latitude'] as num).toDouble(), (a['longitude'] as num).toDouble());
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      clipBehavior: Clip.antiAlias,
      builder: (ctx) => SizedBox(
        height: 420,
        child: Column(children: [
          ListTile(
            leading: Icon(_icon(a['type']), color: _color(a['type'])),
            title: Text(a['message'] ?? ''),
            subtitle: Text(fmtDateTime(a['createdAt'])),
          ),
          Expanded(
            child: FlutterMap(
              options: MapOptions(initialCenter: p, initialZoom: 16),
              children: [
                mapTiles(),
                MarkerLayer(markers: [
                  Marker(point: p, width: 48, height: 48, child: Icon(Icons.location_on, color: _color(a['type']), size: 48)),
                ]),
              ],
            ),
          ),
        ]),
      ),
    );
  }

  Future<void> _delete(Map a) async {
    try {
      await Api.I.delete('/api/alerts/${a['id']}');
      widget.onChanged();
    } on ApiException catch (e) {
      if (mounted) showMsg(context, e.message, error: true);
      _load();
    }
  }

  IconData _icon(String? type) => switch (type) {
        'SOS' => Icons.sos,
        'LeaveZone' => Icons.wrong_location,
        'LowBattery' => Icons.battery_alert,
        'TaskSubmitted' => Icons.assignment_turned_in,
        _ => Icons.info_outline,
      };

  Color _color(String? type) => switch (type) {
        'SOS' => AppColors.danger,
        'LeaveZone' => AppColors.warning,
        'LowBattery' => AppColors.accent,
        'TaskSubmitted' => AppColors.success,
        _ => AppColors.primary,
      };

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Cảnh báo'),
        actions: [
          TextButton.icon(onPressed: _readAll, icon: const Icon(Icons.done_all), label: const Text('Đọc hết')),
        ],
      ),
      body: _error != null
          ? ErrorView(message: _error!, onRetry: _load)
          : _alerts == null
              ? const Center(child: CircularProgressIndicator())
              : _alerts!.isEmpty
                  ? const EmptyView(icon: Icons.notifications_none, message: 'Không có cảnh báo nào.\nMọi thứ đều ổn!')
                  : RefreshIndicator(
                      onRefresh: _load,
                      child: ListView.separated(
                        padding: const EdgeInsets.fromLTRB(16, 4, 16, 20),
                        itemCount: _alerts!.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 8),
                        itemBuilder: (_, i) {
                          final a = Map<String, dynamic>.from(_alerts![i]);
                          final unread = a['isRead'] != true;
                          final color = _color(a['type']);
                          return Dismissible(
                            key: ValueKey(a['id']),
                            direction: DismissDirection.endToStart,
                            background: Container(
                              alignment: Alignment.centerRight,
                              padding: const EdgeInsets.only(right: 20),
                              decoration: BoxDecoration(color: AppColors.danger, borderRadius: BorderRadius.circular(18)),
                              child: const Icon(Icons.delete, color: Colors.white),
                            ),
                            onDismissed: (_) {
                              setState(() => _alerts!.removeAt(i));
                              _delete(a);
                            },
                            child: Card(
                              color: unread ? color.withValues(alpha: 0.07) : null,
                              child: ListTile(
                                onTap: () => _open(a),
                                leading: CircleAvatar(
                                  backgroundColor: color.withValues(alpha: 0.15),
                                  child: Icon(_icon(a['type']), color: color),
                                ),
                                title: Text(a['message'] ?? '',
                                    style: TextStyle(fontWeight: unread ? FontWeight.w800 : FontWeight.w500)),
                                subtitle: Text('${a['childName']} • ${timeAgo(a['createdAt'])}'),
                                trailing: a['latitude'] != null ? const Icon(Icons.map_outlined) : null,
                              ),
                            ),
                          );
                        },
                      ),
                    ),
    );
  }
}
