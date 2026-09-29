import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../generated/l10n/app_localizations.dart';
import 'home_screen.dart';
import 'profile_screen.dart';
import '../providers/route_provider.dart';

class MainNavigationScreen extends StatefulWidget {
  final int? initialLaneId;

  const MainNavigationScreen({super.key, this.initialLaneId});

  @override
  State<MainNavigationScreen> createState() => _MainNavigationScreenState();
}

class _MainNavigationScreenState extends State<MainNavigationScreen> {
  int _currentIndex = 0;

  late final List<Widget> _screens = [
    HomeScreen(initialLaneId: widget.initialLaneId),
    const ProfileScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    return Scaffold(
      body: _screens[_currentIndex],
      bottomNavigationBar: NavigationBar(
        selectedIndex: _currentIndex,
        onDestinationSelected: (index) {
          setState(() {
            _currentIndex = index;
          });

          // Refresh routes when returning to the Routes tab (index 0)
          if (index == 0) {
            final routeProvider = Provider.of<RouteProvider>(
              context,
              listen: false,
            );
            routeProvider.refreshRoutes();
          }
        },
        destinations: [
          NavigationDestination(
            icon: const Icon(Icons.explore_outlined),
            selectedIcon: const Icon(Icons.explore),
            label: l10n.navRoutes,
          ),
          NavigationDestination(
            icon: const Icon(Icons.person_outline),
            selectedIcon: const Icon(Icons.person),
            label: l10n.navProfile,
          ),
        ],
      ),
    );
  }
}
