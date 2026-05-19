import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:forui/forui.dart';
import 'package:go_router/go_router.dart';

import '../../features/player/widgets/mini_player.dart';
import '../../l10n/app_localizations.dart';
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

/// Builds the navigation destinations with localized labels. Resolved per
/// build from [AppLocalizations] so the labels follow the active locale.
List<_Destination> _destinationsFor(AppLocalizations l10n) => <_Destination>[
  _Destination(
    path: RoutePaths.home,
    label: l10n.navSurahs,
    icon: FIcons.bookOpen,
  ),
  _Destination(
    path: RoutePaths.search,
    label: l10n.navSearch,
    icon: FIcons.search,
  ),
  _Destination(
    path: RoutePaths.bookmarks,
    label: l10n.navBookmarks,
    icon: FIcons.bookmark,
  ),
  _Destination(
    path: RoutePaths.settings,
    label: l10n.navSettings,
    icon: FIcons.settings,
  ),
  _Destination(
    path: RoutePaths.mcpStatus,
    label: l10n.navMcp,
    icon: FIcons.plug,
  ),
];

class AppShell extends ConsumerWidget {
  const AppShell({required this.location, required this.child, super.key});

  final String location;
  final Widget child;

  static const double _wideBreakpoint = 768;

  int _selectedIndex(List<_Destination> destinations) {
    for (var i = 0; i < destinations.length; i++) {
      final dest = destinations[i];
      if (dest.path == RoutePaths.home) {
        if (location == '/' || location.startsWith('/surahs')) return i;
      } else if (location == dest.path ||
          location.startsWith('${dest.path}/')) {
        return i;
      }
    }
    return 0;
  }

  void _go(BuildContext context, List<_Destination> destinations, int index) {
    context.go(destinations[index].path);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final destinations = _destinationsFor(l10n);
    final selected = _selectedIndex(destinations);
    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth >= _wideBreakpoint) {
          return Column(
            children: [
              Expanded(
                child: Row(
                  children: [
                    SizedBox(
                      width: 220,
                      child: FSidebar(
                        key: AppShellKeys.sidebar,
                        header: Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 16,
                          ),
                          child: Text(
                            l10n.appTitle,
                            style: const TextStyle(fontWeight: FontWeight.w600),
                          ),
                        ),
                        children: [
                          for (final (i, dest) in destinations.indexed)
                            FSidebarItem(
                              icon: Icon(dest.icon),
                              label: Text(dest.label),
                              selected: i == selected,
                              onPress: () => _go(context, destinations, i),
                            ),
                        ],
                      ),
                    ),
                    Expanded(key: AppShellKeys.content, child: child),
                  ],
                ),
              ),
              const MiniPlayer(),
            ],
          );
        }
        return Column(
          children: [
            Expanded(key: AppShellKeys.content, child: child),
            FBottomNavigationBar(
              key: AppShellKeys.bottomNav,
              index: selected,
              onChange: (i) => _go(context, destinations, i),
              children: [
                for (final dest in destinations)
                  FBottomNavigationBarItem(
                    icon: Icon(dest.icon),
                    label: Text(dest.label),
                  ),
              ],
            ),
            const MiniPlayer(),
          ],
        );
      },
    );
  }
}
