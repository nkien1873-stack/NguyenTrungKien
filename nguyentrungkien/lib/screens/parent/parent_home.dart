import 'dart:async';

import 'package:flutter/material.dart';

import '../../core/api.dart';
import '../../theme.dart';
import '../common/account_screen.dart';
import 'alerts_tab.dart';
import 'children_tab.dart';
import 'map_tab.dart';
import 'support_screen.dart';
import 'tasks_tab.dart';

/// TRANG PHỤ HUYNH (khách hàng).
class ParentHome extends StatefulWidget {
  const ParentHome({super.key});

  @override
  State<ParentHome> createState() => _ParentHomeState();
}

class _ParentHomeState extends State<ParentHome> {
  int _tab = 0;
  int _unread = 0;
  int _lastSos = 0;
  Timer? _poll;

  @override
  void initState() {
    super.initState();
    _checkAlerts();
    // Kiểm tra cảnh báo mới mỗi 15 giây (SOS hiện popup ngay)
    _poll = Timer.periodic(const Duration(seconds: 15), (_) => _checkAlerts());
  }

  @override
  void dispose() {
    _poll?.cancel();
    super.dispose();
  }

  Future<void> _checkAlerts() async {
    try {
      final res = await Api.I.get('/api/alerts/unread-count');
      if (!mounted) return;
      final sos = res['sos'] as int;
      setState(() => _unread = res['count'] as int);
      if (sos > _lastSos) {
        _showSos();
      }
      _lastSos = sos;
    } catch (_) {}
  }

  void _showSos() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        icon: const Icon(Icons.sos, color: AppColors.danger, size: 48),
        title: const Text('CẢNH BÁO SOS'),
        content: const Text('Con bạn vừa gửi tín hiệu khẩn cấp. Xem vị trí ngay!'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Đóng')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppColors.danger, minimumSize: const Size(120, 44)),
            onPressed: () {
              Navigator.pop(ctx);
              setState(() => _tab = 3);
            },
            child: const Text('Xem cảnh báo'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final pages = [
      const ChildrenTab(),
      MapTab(active: _tab == 1),
      const TasksTab(),
      AlertsTab(onChanged: _checkAlerts, active: _tab == 3),
      AccountScreen(
        gradient: AppColors.parentGradient,
        extraItems: [
          ListTile(
            leading: const Icon(Icons.support_agent, color: AppColors.primary),
            title: const Text('Yêu cầu hỗ trợ'),
            subtitle: const Text('Gửi câu hỏi tới nhân viên KidGuard'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const SupportScreen())),
          ),
        ],
      ),
    ];

    return Scaffold(
      body: IndexedStack(index: _tab, children: pages),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _tab,
        onDestinationSelected: (i) => setState(() => _tab = i),
        destinations: [
          const NavigationDestination(icon: Icon(Icons.home_outlined), selectedIcon: Icon(Icons.home), label: 'Trang chủ'),
          const NavigationDestination(icon: Icon(Icons.map_outlined), selectedIcon: Icon(Icons.map), label: 'Bản đồ'),
          const NavigationDestination(icon: Icon(Icons.task_alt_outlined), selectedIcon: Icon(Icons.task_alt), label: 'Nhiệm vụ'),
          NavigationDestination(
            icon: Badge(isLabelVisible: _unread > 0, label: Text('$_unread'), child: const Icon(Icons.notifications_outlined)),
            selectedIcon: Badge(isLabelVisible: _unread > 0, label: Text('$_unread'), child: const Icon(Icons.notifications)),
            label: 'Cảnh báo',
          ),
          const NavigationDestination(icon: Icon(Icons.person_outline), selectedIcon: Icon(Icons.person), label: 'Tài khoản'),
        ],
      ),
    );
  }
}
