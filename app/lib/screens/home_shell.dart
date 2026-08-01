import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/session.dart';
import 'admin/admin_home_screen.dart';
import 'field/field_home_screen.dart';
import 'profile/profile_screen.dart';
import 'reports/reports_screen.dart';

/// Alt gezinme iskeleti — UX §2.1, §5.
///
/// `genel_merkez`: Yönetim Paneli · Saha Çalışmaları · Raporlar · Profil
/// `saha`: Saha Çalışmaları · Profil (diğer sekmeler hiç render edilmez)
class HomeShell extends StatefulWidget {
  const HomeShell({super.key});

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _TabSpec {
  const _TabSpec({
    required this.label,
    required this.icon,
    required this.selectedIcon,
    required this.builder,
  });

  final String label;
  final IconData icon;
  final IconData selectedIcon;
  final WidgetBuilder builder;
}

class _HomeShellState extends State<HomeShell> {
  int _index = 0;
  late final List<_TabSpec> _tabs;
  late final List<GlobalKey<NavigatorState>> _navKeys;

  @override
  void initState() {
    super.initState();
    final isAdmin = context.read<Session>().isAdmin;
    _tabs = [
      if (isAdmin)
        _TabSpec(
          label: 'Yönetim Paneli',
          icon: Icons.dashboard_outlined,
          selectedIcon: Icons.dashboard,
          builder: (_) => const AdminHomeScreen(),
        ),
      _TabSpec(
        label: 'Saha Çalışmaları',
        icon: Icons.groups_outlined,
        selectedIcon: Icons.groups,
        builder: (_) => const FieldHomeScreen(),
      ),
      if (isAdmin)
        _TabSpec(
          label: 'Raporlar',
          icon: Icons.insert_chart_outlined,
          selectedIcon: Icons.insert_chart,
          builder: (_) => const ReportsScreen(),
        ),
      _TabSpec(
        label: 'Profil',
        icon: Icons.person_outline,
        selectedIcon: Icons.person,
        builder: (_) => const ProfileScreen(),
      ),
    ];
    _navKeys =
        List.generate(_tabs.length, (_) => GlobalKey<NavigatorState>());
  }

  void _onTabSelected(int i) {
    if (i == _index) {
      // Aynı sekmeye tekrar dokunuş: yığını köke döndür.
      _navKeys[i].currentState?.popUntil((r) => r.isFirst);
      return;
    }
    setState(() => _index = i);
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) return;
        final nav = _navKeys[_index].currentState;
        if (nav != null && nav.canPop()) {
          nav.pop();
        }
      },
      child: Scaffold(
        body: IndexedStack(
          index: _index,
          children: [
            for (var i = 0; i < _tabs.length; i++)
              Navigator(
                key: _navKeys[i],
                onGenerateRoute: (settings) => MaterialPageRoute(
                  settings: settings,
                  builder: _tabs[i].builder,
                ),
              ),
          ],
        ),
        bottomNavigationBar: NavigationBar(
          selectedIndex: _index,
          onDestinationSelected: _onTabSelected,
          destinations: [
            for (final t in _tabs)
              NavigationDestination(
                icon: Icon(t.icon),
                selectedIcon: Icon(t.selectedIcon),
                label: t.label,
              ),
          ],
        ),
      ),
    );
  }
}
