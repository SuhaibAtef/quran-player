import 'package:flutter/widgets.dart';
import 'package:go_router/go_router.dart';

import '../../features/bookmarks/bookmarks_page.dart';
import '../../features/home/home_page.dart';
import '../../features/mcp_status/mcp_status_page.dart';
import '../../features/search/search_page.dart';
import '../../features/settings/settings_page.dart';
import '../../features/surah_detail/surah_detail_page.dart';
import '../widgets/app_shell.dart';
import 'route_names.dart';

GoRouter buildAppRouter() {
  return GoRouter(
    initialLocation: RoutePaths.home,
    errorBuilder: (context, state) => const _RouteErrorRedirect(),
    redirect: (context, state) {
      const known = <String>{
        RoutePaths.home,
        RoutePaths.search,
        RoutePaths.bookmarks,
        RoutePaths.settings,
        RoutePaths.mcpStatus,
      };
      final path = state.uri.path;
      if (known.contains(path)) return null;
      if (path.startsWith('/surahs/')) return null;
      return RoutePaths.home;
    },
    routes: [
      ShellRoute(
        builder: (context, state, child) =>
            AppShell(location: state.uri.path, child: child),
        routes: [
          GoRoute(
            path: RoutePaths.home,
            name: RouteNames.home,
            builder: (context, state) => const HomePage(),
            routes: [
              GoRoute(
                path: 'surahs/:id',
                name: RouteNames.surahDetail,
                builder: (context, state) =>
                    SurahDetailPage(surahId: state.pathParameters['id'] ?? ''),
              ),
            ],
          ),
          GoRoute(
            path: RoutePaths.search,
            name: RouteNames.search,
            builder: (context, state) => const SearchPage(),
          ),
          GoRoute(
            path: RoutePaths.bookmarks,
            name: RouteNames.bookmarks,
            builder: (context, state) => const BookmarksPage(),
          ),
          GoRoute(
            path: RoutePaths.settings,
            name: RouteNames.settings,
            builder: (context, state) => const SettingsPage(),
          ),
          GoRoute(
            path: RoutePaths.mcpStatus,
            name: RouteNames.mcpStatus,
            builder: (context, state) => const McpStatusPage(),
          ),
        ],
      ),
    ],
  );
}

class _RouteErrorRedirect extends StatelessWidget {
  const _RouteErrorRedirect();

  @override
  Widget build(BuildContext context) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (context.mounted) context.go(RoutePaths.home);
    });
    return const SizedBox.shrink();
  }
}
