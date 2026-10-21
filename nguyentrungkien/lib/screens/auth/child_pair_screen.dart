import 'dart:io';

import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:provider/provider.dart';

import '../../core/api.dart';
import '../../core/session.dart';
import '../../core/utils.dart';
import '../../theme.dart';
import '../router.dart';

/// Chức năng e – Máy của trẻ quét QR do phụ huynh tạo để ghép thiết bị.
class ChildPairScreen extends StatefulWidget {
  const ChildPairScreen({super.key});

  @override
  State<ChildPairScreen> createState() => _ChildPairScreenState();
}

class _ChildPairScreenState extends State<ChildPairScreen> {
  final _controller = MobileScannerController(detectionSpeed: DetectionSpeed.noDuplicates);
  bool _busy = false;
  String? _status;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _pair(String raw) async {
    if (_busy) return;
    final code = raw.trim();
    if (!code.startsWith('KIDGUARD:') && code.length < 16) {
      setState(() => _status = 'Đây không phải mã QR của KidGuard.');
      return;
    }
    final session = context.read<Session>();
    setState(() {
      _busy = true;
      _status = 'Đang ghép thiết bị...';
    });
    try {
      final res = await Api.I.post('/api/auth/pair-child', {
        'code': code,
        'deviceName': '${Platform.isAndroid ? 'Android' : Platform.isIOS ? 'iPhone' : 'Thiết bị'} ${Platform.operatingSystemVersion.split(' ').first}',
        'platform': Platform.operatingSystem,
      });
      await session.saveChild(Map<String, dynamic>.from(res));
      if (!mounted) return;
      showMsg(context, 'Ghép thành công với tài khoản của ${session.parentName}');
      goHome(context, session.role);
    } on ApiException catch (e) {
      if (mounted) setState(() => _status = e.message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _manualInput() async {
    final ctrl = TextEditingController();
    final code = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Nhập mã ghép'),
        content: TextField(
          controller: ctrl,
          textCapitalization: TextCapitalization.characters,
          decoration: const InputDecoration(hintText: 'Mã 24 ký tự hiển thị dưới QR'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Hủy')),
          TextButton(onPressed: () => Navigator.pop(ctx, ctrl.text), child: const Text('Ghép')),
        ],
      ),
    );
    if (code != null && code.trim().isNotEmpty) _pair(code);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        title: const Text('Quét mã ghép thiết bị', style: TextStyle(color: Colors.white)),
        actions: [
          IconButton(
            tooltip: 'Đèn flash',
            onPressed: () => _controller.toggleTorch(),
            icon: const Icon(Icons.flash_on, color: Colors.white),
          ),
        ],
      ),
      body: Stack(
        children: [
          MobileScanner(
            controller: _controller,
            onDetect: (capture) {
              for (final b in capture.barcodes) {
                final v = b.rawValue;
                if (v != null) {
                  _pair(v);
                  break;
                }
              }
            },
          ),
          Center(
            child: Container(
              width: 250,
              height: 250,
              decoration: BoxDecoration(
                border: Border.all(color: AppColors.accent, width: 4),
                borderRadius: BorderRadius.circular(24),
              ),
            ),
          ),
          Positioned(
            left: 16,
            right: 16,
            bottom: 24,
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20)),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    _status ?? 'Trên máy bố mẹ: Hồ sơ con > "Ghép điện thoại của con" để hiện mã QR.',
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 10),
                  if (_busy) const LinearProgressIndicator(),
                  TextButton.icon(
                    onPressed: _busy ? null : _manualInput,
                    icon: const Icon(Icons.keyboard),
                    label: const Text('Nhập mã thủ công'),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
