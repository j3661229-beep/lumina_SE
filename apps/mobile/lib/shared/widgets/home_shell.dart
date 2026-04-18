import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

class HomeShell extends ConsumerWidget {
  final Widget child;
  const HomeShell({super.key, required this.child});

  static const _tabs = [
    (icon: Icons.dashboard_outlined, activeIcon: Icons.dashboard, label: 'Home', path: '/home'),
    (icon: Icons.calendar_month_outlined, activeIcon: Icons.calendar_month, label: 'Calendar', path: '/calendar'),
    (icon: Icons.people_outline, activeIcon: Icons.people, label: 'Groups', path: '/groups'),
    (icon: Icons.view_kanban_outlined, activeIcon: Icons.view_kanban, label: 'Tasks', path: '/kanban'), // Using my-tasks as the shell tab
    (icon: Icons.person_outline, activeIcon: Icons.person, label: 'Profile', path: '/profile'),
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final location = GoRouterState.of(context).uri.path;
    int currentIndex = _tabs.indexWhere((t) => location.startsWith(t.path));
    if (currentIndex < 0) currentIndex = 0;

    return Scaffold(
      extendBody: true,
      body: AnimatedSwitcher(
        duration: const Duration(milliseconds: 300),
        switchInCurve: Curves.easeOutCubic,
        switchOutCurve: Curves.easeInCubic,
        transitionBuilder: (child, animation) {
          return FadeTransition(
            opacity: animation,
            child: SlideTransition(
              position: Tween<Offset>(
                begin: const Offset(0.0, 0.05),
                end: Offset.zero,
              ).animate(animation),
              child: child,
            ),
          );
        },
        child: KeyedSubtree(
          key: ValueKey(currentIndex),
          child: child,
        ),
      ),
      bottomNavigationBar: _ModernBottomNav(
        currentIndex: currentIndex,
        onTap: (i) {
          HapticFeedback.selectionClick();
          // We route to /my-tasks for the tasks tab, but check _tabs[i].path
          final path = _tabs[i].path == '/kanban' ? '/my-tasks' : _tabs[i].path;
          context.go(path);
        },
        tabs: _tabs,
      ),
    );
  }
}

class _ModernBottomNav extends StatelessWidget {
  final int currentIndex;
  final ValueChanged<int> onTap;
  final List<({IconData icon, IconData activeIcon, String label, String path})> tabs;

  const _ModernBottomNav({
    required this.currentIndex,
    required this.onTap,
    required this.tabs,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return ClipRRect(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
        child: Container(
          decoration: BoxDecoration(
            color: theme.colorScheme.surface.withOpacity(isDark ? 0.8 : 0.9),
            border: Border(
              top: BorderSide(
                color: theme.colorScheme.onSurface.withOpacity(0.05),
              ),
            ),
          ),
          child: SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
              child: Row(
                children: List.generate(tabs.length, (i) {
                  final sel = currentIndex == i;
                  return Expanded(
                    child: GestureDetector(
                      onTap: () => onTap(i),
                      behavior: HitTestBehavior.opaque,
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 250),
                        curve: Curves.easeOutCubic,
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            AnimatedScale(
                              scale: sel ? 1.1 : 1.0,
                              duration: const Duration(milliseconds: 200),
                              child: AnimatedContainer(
                                duration: const Duration(milliseconds: 200),
                                padding: const EdgeInsets.all(10),
                                decoration: BoxDecoration(
                                  color: sel ? theme.colorScheme.primary.withOpacity(0.1) : Colors.transparent,
                                  shape: BoxShape.circle,
                                ),
                                child: Icon(
                                  sel ? tabs[i].activeIcon : tabs[i].icon,
                                  size: 22,
                                  color: sel ? theme.colorScheme.primary : theme.colorScheme.onSurface.withOpacity(0.5),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                }),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
