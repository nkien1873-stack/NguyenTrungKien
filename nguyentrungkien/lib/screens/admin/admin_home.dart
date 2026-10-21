import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/api.dart';
import '../../core/session.dart';
import '../../core/utils.dart';
import '../../theme.dart';
import '../../widgets/common.dart';
import '../common/account_screen.dart';
import 'user_form_screen.dart';

/// TRANG QUẢN TRỊ (Admin): thống kê + CRUD người dùng.
class AdminHome extends StatefulWidget {
  const AdminHome({super.key});

  @override
  State<AdminHome> createState() => _AdminHomeState();
}

class _AdminHomeState extends State<AdminHome> {
  int _tab = 0;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(index: _tab, children: const [
        _AdminDashboard(),
        _UserManagement(),
        AccountScreen(gradient: AppColors.adminGradient),
      ]),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _tab,
        onDestinationSelected: (i) => setState(() => _tab = i),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.space_dashboard_outlined), selectedIcon: Icon(Icons.space_dashboard), label: 'Tổng quan'),
          NavigationDestination(icon: Icon(Icons.group_outlined), selectedIcon: Icon(Icons.group), label: 'Người dùng'),
          NavigationDestination(icon: Icon(Icons.manage_accounts_outlined), selectedIcon: Icon(Icons.manage_accounts), label: 'Tài khoản'),
        ],
      ),
    );
  }
}

// ======================= DASHBOARD =======================

class _AdminDashboard extends StatefulWidget {
  const _AdminDashboard();

  @override
  State<_AdminDashboard> createState() => _AdminDashboardState();
}

class _AdminDashboardState extends State<_AdminDashboard> {
  Map<String, dynamic>? _stats;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final res = await Api.I.get('/api/admin/stats');
      if (mounted) {
        setState(() {
          _stats = Map<String, dynamic>.from(res);
          _error = null;
        });
      }
    } on ApiException catch (e) {
      if (mounted) setState(() => _error = e.message);
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = context.watch<Session>();
    final st = _stats;
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        padding: EdgeInsets.zero,
        children: [
          GradientHeader(
            colors: AppColors.adminGradient,
            subtitle: 'Trang quản trị hệ thống',
            title: 'Chào ${s.fullName}',
            trailing: const Icon(Icons.admin_panel_settings, color: Colors.white, size: 36),
          ),
          if (_error != null)
            ErrorView(message: _error!, onRetry: _load)
          else if (st == null)
            const Padding(padding: EdgeInsets.all(40), child: Center(child: CircularProgressIndicator()))
          else
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  GridView.count(
                    crossAxisCount: 2,
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    mainAxisSpacing: 12,
                    crossAxisSpacing: 12,
                    childAspectRatio: 1.15,
                    children: [
                      StatCard(icon: Icons.people_alt, label: 'Tổng người dùng', value: '${st['totalUsers']}', color: AppColors.primary),
                      StatCard(icon: Icons.family_restroom, label: 'Phụ huynh', value: '${st['parents']}', color: const Color(0xFF7C4DFF)),
                      StatCard(icon: Icons.child_care, label: 'Hồ sơ trẻ', value: '${st['children']}', color: AppColors.accent),
                      StatCard(icon: Icons.phone_android, label: 'Thiết bị đã ghép', value: '${st['devices']}', color: AppColors.success),
                      StatCard(icon: Icons.support_agent, label: 'Nhân viên', value: '${st['staffs']}', color: const Color(0xFF0F9D8A)),
                      StatCard(icon: Icons.lock_person, label: 'Tài khoản bị khóa', value: '${st['lockedUsers']}', color: AppColors.danger),
                      StatCard(icon: Icons.sos, label: 'SOS hôm nay', value: '${st['sosToday']}', color: AppColors.danger),
                      StatCard(icon: Icons.confirmation_number_outlined, label: 'Ticket chưa xong', value: '${st['openTickets']}', color: AppColors.warning),
                    ],
                  ),
                  const SectionTitle('Đăng ký mới 7 ngày qua'),
                  _BarChart(data: List<Map<String, dynamic>>.from(
                      (st['registrationsLast7Days'] as List).map((e) => Map<String, dynamic>.from(e)))),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

/// Biểu đồ cột đơn giản (không cần thư viện).
class _BarChart extends StatelessWidget {
  final List<Map<String, dynamic>> data;
  const _BarChart({required this.data});

  @override
  Widget build(BuildContext context) {
    final maxV = data.fold<int>(1, (m, e) => (e['count'] as int) > m ? e['count'] as int : m);
    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 18, 12, 12),
        child: SizedBox(
          height: 170,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: data.map((e) {
              final c = e['count'] as int;
              return Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    Text('$c', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
                    const SizedBox(height: 4),
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 500),
                      height: 110 * c / maxV + 4,
                      margin: const EdgeInsets.symmetric(horizontal: 6),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                            colors: [AppColors.primary, Color(0xFF7C4DFF)], begin: Alignment.bottomCenter, end: Alignment.topCenter),
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text('${e['date']}', style: const TextStyle(fontSize: 11, color: AppColors.muted)),
                  ],
                ),
              );
            }).toList(),
          ),
        ),
      ),
    );
  }
}

// ======================= CRUD NGƯỜI DÙNG =======================

class _UserManagement extends StatefulWidget {
  const _UserManagement();

  @override
  State<_UserManagement> createState() => _UserManagementState();
}

class _UserManagementState extends State<_UserManagement> {
  final _search = TextEditingController();
  String? _role;
  List<dynamic>? _users;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final res = await Api.I.get('/api/admin/users', query: {'search': _search.text, 'role': _role});
      if (mounted) {
        setState(() {
          _users = res as List;
          _error = null;
        });
      }
    } on ApiException catch (e) {
      if (mounted) setState(() => _error = e.message);
    }
  }

  Future<void> _openForm([Map<String, dynamic>? user]) async {
    final changed = await Navigator.push<bool>(context, MaterialPageRoute(builder: (_) => UserFormScreen(user: user)));
    if (changed == true) _load();
  }

  Future<void> _toggleLock(Map u) async {
    try {
      final res = await Api.I.patch('/api/admin/users/${u['id']}/lock');
      if (mounted) showMsg(context, res['message']);
      _load();
    } on ApiException catch (e) {
      if (mounted) showMsg(context, e.message, error: true);
    }
  }

  Future<void> _delete(Map u) async {
    if (!await confirm(context, 'Xóa người dùng', 'Xóa "${u['fullName']}"? Toàn bộ dữ liệu liên quan sẽ bị xóa.', ok: 'Xóa', danger: true)) return;
    try {
      final res = await Api.I.delete('/api/admin/users/${u['id']}');
      if (mounted) showMsg(context, res['message']);
      _load();
    } on ApiException catch (e) {
      if (mounted) showMsg(context, e.message, error: true);
    }
  }

  Color _roleColor(String r) => switch (r) {
        Roles.admin => AppColors.text,
        Roles.staff => const Color(0xFF0F9D8A),
        _ => AppColors.primary,
      };

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Quản lý người dùng')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _openForm(),
        icon: const Icon(Icons.person_add),
        label: const Text('Thêm'),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            child: TextField(
              controller: _search,
              textInputAction: TextInputAction.search,
              onSubmitted: (_) => _load(),
              decoration: InputDecoration(
                hintText: 'Tìm theo tên, email, tên đăng nhập',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: IconButton(icon: const Icon(Icons.arrow_forward), onPressed: _load),
              ),
            ),
          ),
          SizedBox(
            height: 44,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              children: [null, Roles.admin, Roles.staff, Roles.parent].map((r) {
                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: ChoiceChip(
                    label: Text(r == null ? 'Tất cả' : Roles.label(r)),
                    selected: _role == r,
                    onSelected: (_) {
                      setState(() => _role = r);
                      _load();
                    },
                  ),
                );
              }).toList(),
            ),
          ),
          Expanded(
            child: _error != null
                ? ErrorView(message: _error!, onRetry: _load)
                : _users == null
                    ? const Center(child: CircularProgressIndicator())
                    : _users!.isEmpty
                        ? const EmptyView(icon: Icons.person_search, message: 'Không có người dùng phù hợp')
                        : RefreshIndicator(
                            onRefresh: _load,
                            child: ListView.separated(
                              padding: const EdgeInsets.fromLTRB(16, 8, 16, 90),
                              itemCount: _users!.length,
                              separatorBuilder: (_, __) => const SizedBox(height: 10),
                              itemBuilder: (_, i) {
                                final u = Map<String, dynamic>.from(_users![i]);
                                final locked = u['isLocked'] == true;
                                return Card(
                                  child: ListTile(
                                    contentPadding: const EdgeInsets.fromLTRB(14, 6, 4, 6),
                                    leading: Avatar(name: u['fullName'] ?? '', color: locked ? Colors.grey : _roleColor(u['role'])),
                                    title: Text(u['fullName'] ?? '', style: const TextStyle(fontWeight: FontWeight.w700)),
                                    subtitle: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                                      Text('@${u['username']} • ${u['email']}', maxLines: 1, overflow: TextOverflow.ellipsis),
                                      const SizedBox(height: 4),
                                      Wrap(spacing: 6, runSpacing: 4, children: [
                                        StatusChip(Roles.label(u['role']), _roleColor(u['role'])),
                                        if (locked) const StatusChip('Đã khóa', AppColors.danger),
                                        if (u['emailConfirmed'] != true) const StatusChip('Chưa xác thực', AppColors.warning),
                                        if (u['hasFace'] == true) const StatusChip('Face ID', AppColors.success),
                                      ]),
                                    ]),
                                    onTap: () => _openForm(u),
                                    trailing: PopupMenuButton<String>(
                                      onSelected: (v) {
                                        if (v == 'edit') _openForm(u);
                                        if (v == 'lock') _toggleLock(u);
                                        if (v == 'delete') _delete(u);
                                      },
                                      itemBuilder: (_) => [
                                        const PopupMenuItem(value: 'edit', child: Text('Sửa')),
                                        PopupMenuItem(value: 'lock', child: Text(locked ? 'Mở khóa' : 'Khóa')),
                                        const PopupMenuItem(value: 'delete', child: Text('Xóa', style: TextStyle(color: AppColors.danger))),
                                      ],
                                    ),
                                  ),
                                );
                              },
                            ),
                          ),
          ),
        ],
      ),
    );
  }
}
