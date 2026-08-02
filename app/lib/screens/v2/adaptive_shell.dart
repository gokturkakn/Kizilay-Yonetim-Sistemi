import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/layout.dart';
import '../../core/session.dart';
import '../../theme/tokens.dart';
import '../profile/profile_screen.dart';
import 'admin/admin_panel_screen.dart';
import 'dashboard/dashboard_screen.dart';
import 'field/field_home_screen_v2.dart';
import 'logistics/logistics_home_screen.dart';
import 'more_screen.dart';
import 'org/org_home_screen.dart';

/// Ana iskelet — docs/UX-V2.md §2.
///
/// `< 600` alt çubuk (5 sekme, 5.si `Daha Fazla`) · `600–1239` gezinme rayı
/// (6 hedef) · `>= 1240` genişletilmiş ray. Her hedef kendi `Navigator`'ına
/// sahiptir ve **kırılma noktası geçişinde yığınlar korunur** (§2.2, §10/17).
class AdaptiveShell extends StatefulWidget {
  const AdaptiveShell({super.key});

  @override
  State<AdaptiveShell> createState() => _AdaptiveShellState();
}

class _AdaptiveShellState extends State<AdaptiveShell> {
  late final String _role;
  late final List<AppDestination> _destinations;
  late final Map<AppDestination, GlobalKey<NavigatorState>> _navKeys;

  late AppDestination _selected;

  /// `< 600`'de `Daha Fazla` sekmesi etkin mi.
  bool _moreTab = false;

  /// `Daha Fazla` içinden girilen hedef (yığın korunur, §2.2).
  AppDestination? _moreEntered;

  @override
  void initState() {
    super.initState();
    _role = context.read<Session>().user?.role ?? 'saha';
    _destinations = destinationsForRole(_role);
    _navKeys = {
      for (final d in _destinations) d: GlobalKey<NavigatorState>(),
    };
    _selected = initialDestinationForRole(_role);
  }

  Widget _rootFor(AppDestination d) {
    switch (d) {
      case AppDestination.panel:
        return const DashboardScreen();
      case AppDestination.teskilat:
        return const OrgHomeScreen();
      case AppDestination.saha:
        return const FieldHomeScreenV2();
      case AppDestination.lojistik:
        return const LogisticsHomeScreen();
      case AppDestination.yonetim:
        return const AdminPanelScreen();
      case AppDestination.profil:
        return const ProfileScreen();
    }
  }

  void _selectDestination(AppDestination d) {
    if (_selected == d && !_moreTab) {
      // Aynı sekmeye tekrar dokunuş: yığını köke döndür (v1 davranışı).
      _navKeys[d]?.currentState?.popUntil((r) => r.isFirst);
      return;
    }
    setState(() {
      _selected = d;
      _moreTab = false;
    });
  }

  void _openFromMore(AppDestination d) {
    setState(() {
      _moreEntered = d;
      _selected = d;
    });
  }

  void _backToMoreRoot() {
    setState(() => _moreEntered = null);
  }

  /// §2.2 — kırılma noktası geçişinde hedef taşınır, ekran değişmez.
  void _reconcile(LayoutClass layout) {
    final compact = layout.usesBottomBar;
    final plan = bottomBarPlanForRole(_role);
    if (!compact && _moreTab) {
      // `Daha Fazla` kaybolur: girilen yığın varsa ona, yoksa varsayılana.
      _moreTab = false;
      _selected = _moreEntered ?? destinationAfterMoreCollapse(_role);
    } else if (compact &&
        !_moreTab &&
        plan.hasMore &&
        !plan.destinations.contains(_selected)) {
      // Ray hedefi alt çubukta yok → `Daha Fazla` yığınına taşınır.
      _moreTab = true;
      _moreEntered = _selected;
    }
  }

  @override
  Widget build(BuildContext context) {
    final layout = layoutOf(context);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final before = (_moreTab, _selected);
      _reconcile(layout);
      if (mounted && before != (_moreTab, _selected)) setState(() {});
    });

    final body = _buildBody(layout);

    if (layout.usesBottomBar) {
      final plan = bottomBarPlanForRole(_role);
      final selectedIndex = _moreTab
          ? plan.destinations.length
          : plan.destinations.indexOf(_selected).clamp(0, plan.itemCount - 1);
      return PopScope(
        canPop: false,
        onPopInvokedWithResult: (didPop, _) {
          if (didPop) return;
          _handleBack();
        },
        child: Scaffold(
          body: body,
          bottomNavigationBar: NavigationBar(
            selectedIndex: selectedIndex,
            onDestinationSelected: (i) {
              if (plan.hasMore && i == plan.destinations.length) {
                setState(() => _moreTab = true);
                return;
              }
              _selectDestination(plan.destinations[i]);
            },
            destinations: [
              for (final d in plan.destinations)
                NavigationDestination(
                  icon: Icon(d.icon),
                  selectedIcon: Icon(d.selectedIcon),
                  label: d.shortLabel,
                ),
              if (plan.hasMore)
                const NavigationDestination(
                  icon: Icon(Icons.more_horiz),
                  label: 'Daha Fazla',
                ),
            ],
          ),
        ),
      );
    }

    // 600+ : gezinme rayı (6 hedef; `Daha Fazla` yok).
    final extended = layout.usesExtendedRail;
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) return;
        _handleBack();
      },
      child: Scaffold(
        body: Row(
          children: [
            NavigationRail(
              extended: extended,
              minWidth: kRailWidth,
              minExtendedWidth: kSidebarWidth,
              labelType: extended
                  ? NavigationRailLabelType.none
                  : NavigationRailLabelType.all,
              backgroundColor: kSurface,
              selectedIndex: _destinations.indexOf(_selected).clamp(
                  0, _destinations.length - 1),
              onDestinationSelected: (i) =>
                  _selectDestination(_destinations[i]),
              selectedIconTheme: const IconThemeData(color: kPrimary),
              unselectedIconTheme:
                  const IconThemeData(color: kTextSecondary),
              selectedLabelTextStyle: const TextStyle(
                  color: kPrimary, fontWeight: FontWeight.w600, fontSize: 12),
              unselectedLabelTextStyle:
                  const TextStyle(color: kTextSecondary, fontSize: 12),
              destinations: [
                for (final d in _destinations)
                  NavigationRailDestination(
                    icon: Icon(d.icon),
                    selectedIcon: Icon(d.selectedIcon),
                    label: Text(extended ? d.fullLabel : d.shortLabel),
                  ),
              ],
            ),
            const VerticalDivider(width: 1, color: kBorder),
            Expanded(child: body),
          ],
        ),
      ),
    );
  }

  void _handleBack() {
    if (_moreTab && _moreEntered != null) {
      final nav = _navKeys[_moreEntered]?.currentState;
      if (nav != null && nav.canPop()) {
        nav.pop();
        return;
      }
      _backToMoreRoot();
      return;
    }
    final nav = _navKeys[_selected]?.currentState;
    if (nav != null && nav.canPop()) nav.pop();
  }

  Widget _buildBody(LayoutClass layout) {
    final showMoreRoot = layout.usesBottomBar && _moreTab && _moreEntered == null;
    final activeDestination =
        layout.usesBottomBar && _moreTab ? _moreEntered : _selected;

    return IndexedStack(
      index: showMoreRoot
          ? _destinations.length
          : _destinations.indexOf(activeDestination ?? _selected),
      children: [
        for (final d in _destinations)
          Navigator(
            key: _navKeys[d],
            onGenerateRoute: (settings) => MaterialPageRoute(
              settings: settings,
              builder: (_) => _rootFor(d),
            ),
          ),
        MoreScreen(onOpen: _openFromMore),
      ],
    );
  }
}
