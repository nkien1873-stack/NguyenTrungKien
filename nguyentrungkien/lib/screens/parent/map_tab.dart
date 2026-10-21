import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import '../../core/api.dart';
import '../../core/utils.dart';
import '../../theme.dart';
import '../../widgets/common.dart';

/// Chức năng b – Xem vị trí của con theo thời gian thực + vùng an toàn + lộ trình 24h.
class MapTab extends StatefulWidget {
  final bool active;
  const MapTab({super.key, required this.active});

  @override
  State<MapTab> createState() => _MapTabState();
}

class _MapTabState extends State<MapTab> {
  final _map = MapController();
  List<Map<String, dynamic>> _kids = [];
  int? _selected;
  List<LatLng> _trail = [];
  bool _showTrail = false;
  Timer? _timer;
  String? _error;
  DateTime? _updated;
  bool _centered = false; // đã đưa bản đồ về vị trí thật của con chưa

  @override
  void initState() {
    super.initState();
    if (widget.active) _start();
  }

  @override
  void didUpdateWidget(covariant MapTab old) {
    super.didUpdateWidget(old);
    if (widget.active && !old.active) _start();
    if (!widget.active && old.active) _timer?.cancel();
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _start() {
    _load(center: _kids.isEmpty);
    _timer?.cancel();
    // Làm mới vị trí mỗi 10 giây
    _timer = Timer.periodic(const Duration(seconds: 10), (_) => _load());
  }

  Future<void> _load({bool center = false}) async {
    try {
      final res = await Api.I.get('/api/children/locations/latest');
      if (!mounted) return;
      setState(() {
        _kids = (res as List).map((e) => Map<String, dynamic>.from(e)).toList();
        _error = null;
        _updated = DateTime.now();
        _selected ??= _kids.isNotEmpty ? _kids.first['childId'] as int : null;
      });
      // Lần đầu nhận được vị trí của con thì tự đưa bản đồ tới đó
      final sel = _sel;
      if (center || (!_centered && sel != null && _pos(sel) != null)) _focusSelected();
      if (_showTrail) _loadTrail();
    } on ApiException catch (e) {
      if (mounted) setState(() => _error = e.message);
    }
  }

  Future<void> _loadTrail() async {
    if (_selected == null) return;
    try {
      final res = await Api.I.get('/api/children/$_selected/locations', query: {'hours': 24});
      if (!mounted) return;
      setState(() {
        _trail = (res as List)
            .map((e) => LatLng((e['latitude'] as num).toDouble(), (e['longitude'] as num).toDouble()))
            .toList();
      });
    } catch (_) {}
  }

  Map<String, dynamic>? get _sel {
    for (final k in _kids) {
      if (k['childId'] == _selected) return k;
    }
    return null;
  }

  LatLng? _pos(Map<String, dynamic> k) {
    final l = k['last'];
    if (l == null) return null;
    return LatLng((l['latitude'] as num).toDouble(), (l['longitude'] as num).toDouble());
  }

  void _focusSelected() {
    final k = _sel;
    if (k == null) return;
    final p = _pos(k);
    if (p != null) {
      _map.move(p, 16);
      _centered = true;
    } else {
      final zones = (k['zones'] as List?) ?? [];
      if (zones.isNotEmpty) {
        _map.move(LatLng((zones.first['latitude'] as num).toDouble(), (zones.first['longitude'] as num).toDouble()), 15);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final circles = <CircleMarker>[];
    final markers = <Marker>[];
    for (final k in _kids) {
      final color = hexColor(k['avatarColor']);
      for (final z in (k['zones'] as List? ?? [])) {
        circles.add(CircleMarker(
          point: LatLng((z['latitude'] as num).toDouble(), (z['longitude'] as num).toDouble()),
          radius: (z['radiusMeters'] as num).toDouble(),
          useRadiusInMeter: true,
          color: color.withValues(alpha: 0.12),
          borderColor: color.withValues(alpha: 0.6),
          borderStrokeWidth: 1.5,
        ));
      }
      final p = _pos(k);
      if (p != null) {
        markers.add(Marker(
          point: p,
          width: 60,
          height: 70,
          alignment: Alignment.topCenter,
          child: GestureDetector(
            onTap: () {
              setState(() => _selected = k['childId']);
              _focusSelected();
              if (_showTrail) _loadTrail();
            },
            child: Column(children: [
              Container(
                padding: const EdgeInsets.all(3),
                decoration: BoxDecoration(color: Colors.white, shape: BoxShape.circle, boxShadow: [
                  BoxShadow(color: Colors.black.withValues(alpha: 0.2), blurRadius: 6),
                ]),
                child: Avatar(name: k['name'] ?? '', color: color, size: 40),
              ),
              Icon(Icons.arrow_drop_down, color: color, size: 22),
            ]),
          ),
        ));
      }
    }

    final sel = _sel;
    final last = sel?['last'];

    return Scaffold(
      body: Stack(
        children: [
          FlutterMap(
            mapController: _map,
            options: const MapOptions(initialCenter: LatLng(10.7769, 106.7009), initialZoom: 13),
            children: [
              mapTiles(),
              CircleLayer(circles: circles),
              if (_showTrail && _trail.length > 1)
                PolylineLayer(polylines: [
                  Polyline(points: _trail, strokeWidth: 4, color: AppColors.primary.withValues(alpha: 0.7)),
                ]),
              MarkerLayer(markers: markers),
            ],
          ),
          // Chọn con
          Positioned(
            top: MediaQuery.of(context).padding.top + 10,
            left: 12,
            right: 12,
            child: Card(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                child: _error != null
                    ? Row(children: [
                        const Icon(Icons.error_outline, color: AppColors.danger),
                        const SizedBox(width: 8),
                        Expanded(child: Text(_error!, maxLines: 2)),
                        IconButton(onPressed: _load, icon: const Icon(Icons.refresh)),
                      ])
                    : _kids.isEmpty
                        ? const ListTile(dense: true, title: Text('Chưa có hồ sơ trẻ để theo dõi'))
                        : SingleChildScrollView(
                            scrollDirection: Axis.horizontal,
                            child: Row(
                              children: _kids
                                  .map((k) => Padding(
                                        padding: const EdgeInsets.only(right: 6),
                                        child: ChoiceChip(
                                          avatar: Avatar(name: k['name'] ?? '', color: hexColor(k['avatarColor']), size: 22),
                                          label: Text(k['name'] ?? ''),
                                          selected: _selected == k['childId'],
                                          onSelected: (_) {
                                            setState(() => _selected = k['childId']);
                                            _focusSelected();
                                            if (_showTrail) _loadTrail();
                                          },
                                        ),
                                      ))
                                  .toList(),
                            ),
                          ),
              ),
            ),
          ),
          // Thông tin vị trí
          if (sel != null)
            Positioned(
              left: 12,
              right: 12,
              bottom: 12,
              child: Card(
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Column(mainAxisSize: MainAxisSize.min, children: [
                    Row(children: [
                      Avatar(name: sel['name'] ?? '', color: hexColor(sel['avatarColor'])),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Text(sel['name'] ?? '', style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
                          Text(
                            last == null
                                ? 'Chưa nhận được vị trí – hãy ghép máy và mở app trên máy con'
                                : 'Cập nhật ${timeAgo(last['recordedAt'])}'
                                    '${last['batteryLevel'] != null ? ' • Pin ${last['batteryLevel']}%' : ''}',
                            style: const TextStyle(color: AppColors.muted, fontSize: 13),
                          ),
                        ]),
                      ),
                      IconButton.filledTonal(
                        tooltip: 'Đến vị trí',
                        onPressed: _focusSelected,
                        icon: const Icon(Icons.center_focus_strong),
                      ),
                    ]),
                    const SizedBox(height: 8),
                    Row(children: [
                      Expanded(
                        child: Text(
                          last == null ? '' : '${(last['latitude'] as num).toStringAsFixed(5)}, ${(last['longitude'] as num).toStringAsFixed(5)}',
                          style: const TextStyle(fontSize: 12, color: AppColors.muted),
                        ),
                      ),
                      const Text('Lộ trình 24h', style: TextStyle(fontSize: 13)),
                      Switch(
                        value: _showTrail,
                        onChanged: (v) {
                          setState(() => _showTrail = v);
                          if (v) _loadTrail();
                        },
                      ),
                    ]),
                    if (_updated != null)
                      Align(
                        alignment: Alignment.centerLeft,
                        child: Text('Tự làm mới mỗi 10 giây • ${two(_updated!.hour)}:${two(_updated!.minute)}:${two(_updated!.second)}',
                            style: const TextStyle(fontSize: 11, color: AppColors.muted)),
                      ),
                  ]),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
