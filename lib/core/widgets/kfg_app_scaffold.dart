import 'package:flutter/material.dart';

import '../../app/kfg_theme.dart';
import '../../features/about/about_screen.dart';
import '../../features/home/home_screen.dart';
import '../../features/settings/settings_screen.dart';
import '../../features/stats/stats_screen.dart';

/// Root scaffold shared by the four main tabs (Home, Stats, Settings, About).
///
/// Game screens are pushed on top of the root Navigator and do not
/// share this scaffold, so the bottom nav disappears while playing.
class KfgAppScaffold extends StatefulWidget {
  const KfgAppScaffold({super.key});

  @override
  State<KfgAppScaffold> createState() => _KfgAppScaffoldState();
}

class _KfgAppScaffoldState extends State<KfgAppScaffold> {
  int _currentIndex = 0;

  // Tabs preserved in memory while switching via IndexedStack.
  static const List<Widget> _tabs = [
    HomeScreen(),
    StatsScreen(),
    SettingsScreen(),
    AboutScreen(),
  ];

  static const List<NavigationDestination> _destinations = [
    NavigationDestination(
      icon: Icon(Icons.grid_view_outlined),
      selectedIcon: Icon(Icons.grid_view),
      label: 'Games',
    ),
    NavigationDestination(
      icon: Icon(Icons.bar_chart_outlined),
      selectedIcon: Icon(Icons.bar_chart),
      label: 'Stats',
    ),
    NavigationDestination(
      icon: Icon(Icons.settings_outlined),
      selectedIcon: Icon(Icons.settings),
      label: 'Settings',
    ),
    NavigationDestination(
      icon: Icon(Icons.info_outline),
      selectedIcon: Icon(Icons.info),
      label: 'About',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: KfgColors.background,
      body: SafeArea(
        bottom: false,
        child: IndexedStack(index: _currentIndex, children: _tabs),
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _currentIndex,
        onDestinationSelected: (index) => setState(() => _currentIndex = index),
        destinations: _destinations,
      ),
    );
  }
}
