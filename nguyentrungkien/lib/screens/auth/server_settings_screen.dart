import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/api.dart';
import '../../core/config.dart';
import '../../core/session.dart';
import '../../core/utils.dart';
import '../../theme.dart';
import '../../widgets/common.dart';

/// Cấu hình địa chỉ Web API – giúp cả nhóm chạy được trên emulator lẫn máy thật.
class ServerSettingsScreen extends StatefulWidget {
  const ServerSettingsScreen({super.key});

  @override
  State<ServerSettingsScreen> createState() => _ServerSettingsScreenState();
}

class _ServerSettingsScreenState extends State<ServerSettingsScreen> {
  late final TextEditingController _url;
  bool _testing = false;
  String? _result;
  bool _ok = false;

  @override
  void initState() {
    super.initState();
    _url = TextEditingController(text: context.read<Session>().baseUrl);
  }

  @override
  void dispose() {
    _url.dispose();
    super.dispose();
  }

  /// Chỉ kiểm tra đúng địa chỉ đang nhập (không tự dò sang địa chỉ khác).
  Future<void> _test() async {
    setState(() {
      _testing = true;
      _result = null;
    });
    final ok = await Api.I.probe(_url.text.trim());
    if (!mounted) return;
    setState(() {
      _testing = false;
      _ok = ok;
      _result = ok ? 'Kết nối thành công: NguyenTrungKien' : 'Không kết nối được ${_url.text.trim()}';
    });
  }

  /// Dò USB -> emulator -> Wi-Fi, tìm được thì điền và lưu luôn.
  Future<void> _discover() async {
    setState(() {
      _testing = true;
      _result = null;
    });
    final url = await Api.I.discover();
    if (!mounted) return;
    setState(() {
      _testing = false;
      _ok = url != null;
      if (url != null) _url.text = url;
      _result = url != null
          ? 'Đã tìm thấy và lưu: $url'
          : 'Không tìm thấy máy chủ. Kiểm tra API đã chạy; điện thoại cắm USB, hoặc cùng Wi-Fi '
              'và máy tính đã chạy mo-firewall.ps1.';
    });
  }

  Future<void> _save() async {
    await context.read<Session>().setBaseUrl(_url.text.trim());
    if (!mounted) return;
    showMsg(context, 'Đã lưu địa chỉ máy chủ');
    Navigator.pop(context);
  }

  Widget _preset(String label, String url) => ActionChip(
        label: Text(label),
        onPressed: () => setState(() => _url.text = url),
      );

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Cấu hình máy chủ')),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          TextField(
            controller: _url,
            keyboardType: TextInputType.url,
            decoration: const InputDecoration(labelText: 'Địa chỉ Web API', prefixIcon: Icon(Icons.dns_outlined)),
          ),
          const SizedBox(height: 12),
          Wrap(spacing: 8, runSpacing: 8, children: [
            if (kPublicApiUrl.isNotEmpty) _preset('Máy chủ online', kPublicApiUrl),
            _preset('Emulator Android', 'http://10.0.2.2:5080'),
            _preset('USB / iOS Simulator', 'http://localhost:5080'),
            _preset('Máy thật (sửa IP)', 'http://192.168.1.10:5080'),
          ]),
          const SizedBox(height: 16),
          const Card(
            child: Padding(
              padding: EdgeInsets.all(14),
              child: Text(
                'Thường không cần nhập: app tự tìm máy chủ qua USB, emulator hoặc cùng mạng Wi-Fi. '
                'Dùng Wi-Fi thì máy tính chạy API phải chạy mo-firewall.ps1 một lần. '
                'Tìm không được thì nhập tay http://<IPv4 máy tính>:5080 (xem IPv4 bằng "ipconfig").',
                style: TextStyle(color: AppColors.muted, height: 1.4),
              ),
            ),
          ),
          if (_result != null) ...[
            const SizedBox(height: 14),
            Row(children: [
              Icon(_ok ? Icons.check_circle : Icons.error, color: _ok ? AppColors.success : AppColors.danger),
              const SizedBox(width: 8),
              Expanded(child: Text(_result!)),
            ]),
          ],
          const SizedBox(height: 20),
          FilledButton.tonalIcon(
            onPressed: _testing ? null : _discover,
            icon: const Icon(Icons.travel_explore),
            label: const Text('Tự tìm máy chủ'),
          ),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: _testing ? null : _test,
            icon: const Icon(Icons.wifi_tethering),
            label: Text(_testing ? 'Đang kiểm tra...' : 'Kiểm tra kết nối'),
          ),
          const SizedBox(height: 12),
          LoadingButton(loading: false, onPressed: _save, text: 'Lưu', icon: Icons.save_outlined),
        ],
      ),
    );
  }
}
