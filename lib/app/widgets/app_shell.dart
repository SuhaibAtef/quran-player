import 'package:flutter/widgets.dart';
import 'package:forui/forui.dart';
import 'package:go_router/go_router.dart';

import '../router/route_names.dart';

class AppShellKeys {
  const AppShellKeys._();

  static const sidebar = Key('app_shell.sidebar');
  static const bottomNav = Key('app_shell.bottom_nav');
  static const content = Key('app_shell.content');
}

class _Destination {
  const _Destination({
    required this.path,
    required this.label,
    required this.icon,
  });

  final String path;
  final String label;
  final IconData icon;
}

const _destinations = <_Destination>[
  _Destination(path: RoutePaths.home, label: 'Surahs', icon: FIcons.bookOpen),
  _Destination(path: RoutePaths.search, label: 'Search', icon: FIcons.search),
  _Destination(
    path: RoutePaths.bookmarks,
    label: 'Bookmarks',
    icon: FIcons.bookmark,
  ),
  _Destination(
    path: RoutePaths.settings,
    label: 'Settings',
    icon: FIcons.settings,
  ),
  _Destination(path: RoutePaths.mcpStatus, label: 'MCP', icon: FIcons.plug),
];

class AppShell extends StatelessWidget {
  const AppShell({required this.location, required this.child, super.key});

  final String location;
  final Widget child;

  static const double _wideBreakpoint = 768;

  int _selectedIndex() {
    for (var i = 0; i < _destinations.length; i++) {
      final dest = _destinations[i];
      if (dest.path == RoutePaths.home) {
        if (location == '/' || location.startsWith('/surahs')) return i;
      } else if (location == dest.path ||
          location.startsWith('${dest.path}/')) {
        return i;
      }
    }
    return 0;
  }

  void _go(BuildContext context, int index) {
    context.go(_destinations[index].path);
  }

  @override
  Widget build(BuildContext context) {
    final selected = _selectedIndex();
    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth >= _wideBreakpoint) {
          return Row(
            children: [
              SizedBox(
                width: 220,
                child: FSidebar(
                  key: AppShellKeys.sidebar,
                  header: const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 12, vertical: 16),
                    child: Text(
                      'Quran Companion',
                      style: TextStyle(fontWeight: FontWeight.w600),
                    ),
                  ),
                  children: [
                    for (final (i, dest) in _destinations.indexed)
                      FSidebarItem(
                        icon: Icon(dest.icon),
                        label: Text(dest.label),
                        selected: i == selected,
                        onPress: () => _go(context, i),
                      ),
                  ],
                ),
              ),
              Expanded(key: AppShellKeys.content, child: child),
            ],
          );
        }
        return Column(
          children: [
            Expanded(key: AppShellKeys.content, child: child),
            FBottomNavigationBar(
              key: AppShellKeys.bottomNav,
              index: selected,
              onChange: (i) => _go(context, i),
              children: [
                for (final dest in _destinations)
                  FBottomNavigationBarItem(
                    icon: Icon(dest.icon),
                    label: Text(dest.label),
                  ),
              ],
            ),
          ],
        );
      },
    );
  }
}
