import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';

import '../../core/api.dart';
import '../../core/location_helper.dart';
import '../../core/utils.dart';
import '../../theme.dart';
import '../../widgets/common.dart';

/// Thêm / sửa vùng an toàn – chạm lên bản đồ để chọn tâm.
class ZoneFormScreen extends StatefulWidget {
  final int childId;
  final Map<String, dynamic>? zone;
  const ZoneFormScreen({super.key, required this.childId, this.zone});

  @override
  State<ZoneFormScreen> createState() => _ZoneFormScreenState();
}

class _ZoneFormScreenState extends State<ZoneFormScreen> {
  final _map = MapController();
  late final TextEditingController _name;
  late LatLng _center;
  double _radius = 200;
  bool _active = true;
  bool _loading = false;

  bool get _isEdit => widget.zone != null;

  @override
  void initState() {
    super.initState();
    final z = widget.zone;
    _name = TextEditingController(text: z?['name'] ?? '');
    _center = z == null
        ? const LatLng(10.7769, 106.7009)
        : LatLng((z['latitude'] as num).toDouble(), (z['longitude'] as num).toDouble());
    _radius = ((z?['radiusMeters'] ?? 200) as num).toDouble().clamp(50, 2000).toDouble();
    _active = z?['isActive'] ?? true;
    if (z == null) WidgetsBinding.instance.addPostFrameCallback((_) => _myLocation());
  }

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  Future<void> _myLocation() async {
    final res = await LocationHelper.current();
    if (!mounted) return;
    if (res.error != null) {
      showMsg(context, res.error!, error: true);
      return;
    }
    final Position p = res.position!;
    setState(() => _center = LatLng(p.latitude, p.longitude));
    _map.move(_center, 16);
  }

  Future<void> _save() async {
    if (_name.text.trim().isEmpty) {
      showMsg(context, 'Nhập tên vùng (VD: Nhà, Trường)', error: true);
      return;
    }
    setState(() => _loading = true);
    final body = {
      'name': _name.text.trim(),
      'latitude': _center.latitude,
      'longitude': _center.longitude,
      'radiusMeters': _radius.roundToDouble(),
      'isActive': _active,
    };
    final base = '/api/children/${widget.childId}/zones';
    try {
      final res = _isEdit ? await Api.I.put('$base/${widget.zone!['id']}', body) : await Api.I.post(base, body);
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
      appBar: AppBar(title: Text(_isEdit ? 'Sửa vùng an toàn' : 'Thêm vùng an toàn')),
      body: Column(
        children: [
          Expanded(
            child: Stack(
              children: [
                FlutterMap(
                  mapController: _map,
                  options: MapOptions(
                    initialCenter: _center,
                    initialZoom: 16,
                    onTap: (_, point) => setState(() => _center = point),
                  ),
                  children: [
                    mapTiles(),
                    CircleLayer(circles: [
                      CircleMarker(
                        point: _center,
                        radius: _radius,
                        useRadiusInMeter: true,
                        color: AppColors.success.withValues(alpha: 0.18),
                        borderColor: AppColors.success,
                        borderStrokeWidth: 2,
                      ),
                    ]),
                    MarkerLayer(markers: [
                      Marker(
                        point: _center,
                        width: 44,
                        height: 44,
                        child: const Icon(Icons.location_on, color: AppColors.success, size: 44),
                      ),
                    ]),
                  ],
                ),
                Positioned(
                  top: 12,
                  left: 12,
                  right: 12,
                  child: Card(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      child: Row(children: [
                        const Icon(Icons.touch_app, color: AppColors.primary),
                        const SizedBox(width: 8),
                        const Expanded(child: Text('Chạm lên bản đồ để chọn tâm vùng an toàn')),
                        IconButton(tooltip: 'Vị trí của tôi', onPressed: _myLocation, icon: const Icon(Icons.my_location)),
                      ]),
                    ),
                  ),
                ),
              ],
            ),
          ),
          Container(
            color: Colors.white,
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
            child: SafeArea(
              top: false,
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                TextField(
                  controller: _name,
                  decoration: const InputDecoration(labelText: 'Tên vùng', prefixIcon: Icon(Icons.label_outline)),
                ),
                const SizedBox(height: 10),
                Row(children: [
                  const Text('Bán kính'),
                  Expanded(
                    child: Slider(
                      value: _radius,
                      min: 50,
                      max: 2000,
                      divisions: 39,
                      label: '${_radius.round()} m',
                      onChanged: (v) => setState(() => _radius = v),
                    ),
                  ),
                  Text('${_radius.round()} m', style: const TextStyle(fontWeight: FontWeight.w700)),
                ]),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  dense: true,
                  title: const Text('Bật cảnh báo khi rời vùng'),
                  value: _active,
                  onChanged: (v) => setState(() => _active = v),
                ),
                LoadingButton(loading: _loading, onPressed: _save, text: 'Lưu vùng an toàn', icon: Icons.save_outlined),
              ]),
            ),
          ),
        ],
      ),
    );
  }
}
