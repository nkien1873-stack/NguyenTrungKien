import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../../core/api.dart';
import '../../core/utils.dart';
import '../../theme.dart';

/// Chức năng e – Tạo mã QR để máy của trẻ quét và ghép vào tài khoản.
class PairQrScreen extends StatefulWidget {
  final int childId;
  final String childName;
  const PairQrScreen({super.key, required this.childId, required this.childName});

  @override
  State<PairQrScreen> createState() => _PairQrScreenState();
}

class _PairQrScreenState extends State<PairQrScreen> {
  String? _qr;
  String? _code;
  DateTime? _expires;
  String? _error;
  Timer? _timer;
  Duration _left = Duration.zero;
  int? _devices; // số máy đã ghép lúc mở màn hình, để biết khi máy con quét xong

  @override
  void initState() {
    super.initState();
    _generate();
    _countDevices();
  }

  Future<int?> _countDevices() async {
    try {
      final res = await Api.I.get('/api/children/${widget.childId}');
      final n = (res['devices'] as List).length;
      _devices ??= n;
      return n;
    } catch (_) {
      return null;
    }
  }

  /// Máy con quét QR thành công -> server có thêm thiết bị -> báo và quay lại.
  Future<void> _checkPaired() async {
    final n = await _countDevices();
    if (!mounted || n == null || _devices == null || n <= _devices!) return;
    _timer?.cancel();
    showMsg(context, 'Đã ghép điện thoại của ${widget.childName}!');
    Navigator.pop(context);
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _generate() async {
    setState(() {
      _qr = null;
      _error = null;
    });
    try {
      final res = await Api.I.post('/api/children/${widget.childId}/pairing-code');
      if (!mounted) return;
      setState(() {
        _qr = res['qrData'];
        _code = res['code'];
        _expires = parseDate(res['expiresAt']);
      });
      _timer?.cancel();
      _tick();
      _timer = Timer.periodic(const Duration(seconds: 1), (_) => _tick());
    } on ApiException catch (e) {
      if (mounted) setState(() => _error = e.message);
    }
  }

  void _tick() {
    if (_expires == null || !mounted) return;
    final left = _expires!.difference(DateTime.now());
    setState(() => _left = left.isNegative ? Duration.zero : left);
    if (left.isNegative) {
      _timer?.cancel();
    } else if (left.inSeconds % 3 == 0) {
      _checkPaired();
    }
  }

  @override
  Widget build(BuildContext context) {
    final expired = _qr != null && _left == Duration.zero;
    return Scaffold(
      appBar: AppBar(title: const Text('Ghép điện thoại của con')),
      body: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          Text('Mã QR cho ${widget.childName}',
              textAlign: TextAlign.center, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
          const SizedBox(height: 6),
          const Text('Trên điện thoại của con: mở KidGuard > "Đây là điện thoại của con?" > quét mã này.',
              textAlign: TextAlign.center, style: TextStyle(color: AppColors.muted)),
          const SizedBox(height: 24),
          Center(
            child: Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(24),
                boxShadow: [BoxShadow(color: AppColors.primary.withValues(alpha: 0.15), blurRadius: 30, offset: const Offset(0, 10))],
              ),
              child: _error != null
                  ? SizedBox(width: 240, height: 240, child: Center(child: Text(_error!, textAlign: TextAlign.center)))
                  : _qr == null
                      ? const SizedBox(width: 240, height: 240, child: Center(child: CircularProgressIndicator()))
                      : Opacity(
                          opacity: expired ? 0.15 : 1,
                          child: QrImageView(data: _qr!, size: 240, backgroundColor: Colors.white),
                        ),
            ),
          ),
          const SizedBox(height: 16),
          if (_code != null)
            Center(
              child: InkWell(
                onTap: () {
                  Clipboard.setData(ClipboardData(text: _code!));
                  showMsg(context, 'Đã sao chép mã');
                },
                child: Padding(
                  padding: const EdgeInsets.all(8),
                  child: Text(_code!, style: const TextStyle(fontFamily: 'monospace', letterSpacing: 1.5, color: AppColors.muted)),
                ),
              ),
            ),
          const SizedBox(height: 8),
          Center(
            child: Text(
              expired ? 'Mã đã hết hạn' : 'Hết hạn sau ${_left.inMinutes}:${two(_left.inSeconds % 60)}',
              style: TextStyle(fontWeight: FontWeight.w700, color: expired ? AppColors.danger : AppColors.primary),
            ),
          ),
          const SizedBox(height: 24),
          OutlinedButton.icon(onPressed: _generate, icon: const Icon(Icons.refresh), label: const Text('Tạo mã mới')),
          const SizedBox(height: 12),
          FilledButton(onPressed: () => Navigator.pop(context), child: const Text('Xong')),
        ],
      ),
    );
  }
}
