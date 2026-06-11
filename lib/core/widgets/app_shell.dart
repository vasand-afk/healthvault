import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:healthvault/core/theme/app_theme.dart';

class AppShell extends StatelessWidget {
  final Widget child;
  const AppShell({super.key, required this.child});

  static const _navItems = [
    _NavItem(icon: Icons.dashboard_outlined, activeIcon: Icons.dashboard, label: 'Home', path: '/'),
    _NavItem(icon: Icons.lock_outline, activeIcon: Icons.lock, label: 'Vault', path: '/vault'),
    _NavItem(icon: Icons.restaurant_outlined, activeIcon: Icons.restaurant, label: 'Nutrition', path: '/nutrition'),
    _NavItem(icon: Icons.directions_run_outlined, activeIcon: Icons.directions_run, label: 'Fitness', path: '/fitness'),
    _NavItem(icon: Icons.bedtime_outlined, activeIcon: Icons.bedtime, label: 'Sleep', path: '/sleep'),
    _NavItem(icon: Icons.fitness_center_outlined, activeIcon: Icons.fitness_center, label: 'Strength', path: '/strength'),
    _NavItem(icon: Icons.favorite_outline, activeIcon: Icons.favorite, label: 'Symptoms', path: '/symptoms'),
    _NavItem(icon: Icons.science_outlined, activeIcon: Icons.science, label: 'Stack', path: '/stack'),
    _NavItem(icon: Icons.auto_awesome_outlined, activeIcon: Icons.auto_awesome, label: 'AI Coach', path: '/ai-coach'),
    _NavItem(icon: Icons.menu_book_outlined, activeIcon: Icons.menu_book, label: 'Library', path: '/library'),
    _NavItem(icon: Icons.upload_outlined, activeIcon: Icons.upload, label: 'Import', path: '/import'),
    _NavItem(icon: Icons.settings_outlined, activeIcon: Icons.settings, label: 'Settings', path: '/settings'),
  ];

  @override
  Widget build(BuildContext context) {
    final isWide = MediaQuery.of(context).size.width >= 800;
    final location = GoRouterState.of(context).uri.toString();
    final selectedIndex = _selectedIndex(location);

    if (isWide) {
      return Scaffold(
        body: Row(
          children: [
            SizedBox(
              width: 220,
              child: _SideNav(items: _navItems, selectedIndex: selectedIndex),
            ),
            const VerticalDivider(width: 1),
            Expanded(child: child),
          ],
        ),
      );
    }

    return Scaffold(
      body: child,
      bottomNavigationBar: _BottomNav(items: _navItems, selectedIndex: selectedIndex),
    );
  }

  int _selectedIndex(String location) {
    for (int i = _navItems.length - 1; i >= 0; i--) {
      if (location.startsWith(_navItems[i].path)) return i;
    }
    return 0;
  }
}

class _NavItem {
  final IconData icon;
  final IconData activeIcon;
  final String label;
  final String path;
  const _NavItem({required this.icon, required this.activeIcon, required this.label, required this.path});
}

class _SideNav extends StatelessWidget {
  final List<_NavItem> items;
  final int selectedIndex;
  const _SideNav({required this.items, required this.selectedIndex});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: AppTheme.surface,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 16),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(
              children: [
                Container(
                  width: 36, height: 36,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [AppTheme.primary, AppTheme.secondary],
                    ),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.health_and_safety, color: Colors.white, size: 20),
                ),
                const SizedBox(width: 10),
                const Text(
                  'HealthVault',
                  style: TextStyle(
                    color: AppTheme.textPrimary,
                    fontWeight: FontWeight.w700,
                    fontSize: 16,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              itemCount: items.length,
              itemBuilder: (context, i) {
                final item = items[i];
                final selected = i == selectedIndex;
                return _SideNavTile(item: item, selected: selected);
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _SideNavTile extends StatelessWidget {
  final _NavItem item;
  final bool selected;
  const _SideNavTile({required this.item, required this.selected});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap: () => context.go(item.path),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            color: selected ? AppTheme.primary.withValues(alpha: 0.15) : Colors.transparent,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Row(
            children: [
              Icon(
                selected ? item.activeIcon : item.icon,
                color: selected ? AppTheme.primary : AppTheme.textSecondary,
                size: 20,
              ),
              const SizedBox(width: 12),
              Text(
                item.label,
                style: TextStyle(
                  color: selected ? AppTheme.primary : AppTheme.textSecondary,
                  fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
                  fontSize: 14,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _BottomNav extends StatelessWidget {
  final List<_NavItem> items;
  final int selectedIndex;
  const _BottomNav({required this.items, required this.selectedIndex});

  // Show only key tabs on mobile
  static const _mobileIndices = [0, 1, 2, 5, 8];

  @override
  Widget build(BuildContext context) {
    final mobileItems = _mobileIndices.map((i) => items[i]).toList();
    final mobileSelected = _mobileIndices.indexOf(selectedIndex);

    return BottomNavigationBar(
      currentIndex: mobileSelected < 0 ? 0 : mobileSelected,
      onTap: (i) => context.go(mobileItems[i].path),
      items: mobileItems
          .map((item) => BottomNavigationBarItem(
                icon: Icon(item.icon),
                activeIcon: Icon(item.activeIcon),
                label: item.label,
              ))
          .toList(),
    );
  }
}
