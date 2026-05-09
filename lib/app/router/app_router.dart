import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/_errors/bootstrapping_screen.dart';
import '../../features/_errors/data_integrity_screen.dart';
import '../../features/bookmarks/bookmarks_page.dart';
import '../../features/home/home_page.dart';
import '../../features/mcp_status/mcp_status_page.dart';
import '../../features/search/search_page.dart';
import '../../features/settings/settings_page.dart';
import '../../features/surah_detail/surah_detail_page.dart';
import '../state/quran_integrity_provider.dart';
import '../widgets/app_shell.dart';
import 'route_names.dart';

final appRouterProvider = Provider<GoRouter>((ref) => buildAppRouter(ref));

GoRouter buildAppRouter(Ref ref) {
  return GoRouter(
    initialLocation: RoutePaths.home,
    refreshListenable: _IntegrityListenable(ref),
    errorBuilder: (context, state) => const _RouteErrorRedirect(),
    redirect: (context, state) {
      final status = ref.read(quranIntegrityProvider).state;
      final path = state.uri.path;

      // Boot phase: while the bootstrap future is pending, send everything
      // (except the bootstrapping page itself) to the bootstrapping screen.
      if (status == QuranIntegrityState.loading) {
        return path == RoutePaths.bootstrapping
            ? null
            : RoutePaths.bootstrapping;
      }

      // Fatal phase: integrity failed. Lock the app to the error screen.
      if (status == QuranIntegrityState.fatal) {
        return path == RoutePaths.dataIntegrityError
            ? null
            : RoutePaths.dataIntegrityError;
      }

      // OK phase: never let the user linger on the boot/error screens.
      if (path == RoutePaths.bootstrapping ||
          path == RoutePaths.dataIntegrityError) {
        return RoutePaths.home;
      }

      const known = <String>{
        RoutePaths.home,
        RoutePaths.search,
        RoutePaths.bookmarks,
        RoutePaths.settings,
        RoutePaths.mcpStatus,
      };
      if (known.contains(path)) return null;
      if (path.startsWith('/surahs/')) return null;
      return RoutePaths.home;
    },
    routes: [
      GoRoute(
        path: RoutePaths.bootstrapping,
        name: RouteNames.bootstrapping,
        builder: (context, state) => const BootstrappingScreen(),
      ),
      GoRoute(
        path: RoutePaths.dataIntegrityError,
        name: RouteNames.dataIntegrityError,
        builder: (context, state) => const DataIntegrityScreen(),
      ),
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

/// Bridges the integrity Riverpod provider into go_router's
/// `refreshListenable`. Triggers redirect re-evaluation whenever the boot
/// status flips (loading → ok or loading → fatal).
class _IntegrityListenable extends ChangeNotifier {
  _IntegrityListenable(this._ref) {
    _sub = _ref.listen<QuranIntegrityStatus>(quranIntegrityProvider, (
      prev,
      next,
    ) {
      if (prev?.state != next.state) notifyListeners();
    }, fireImmediately: false);
  }

  final Ref _ref;
  late final ProviderSubscription<QuranIntegrityStatus> _sub;

  @override
  void dispose() {
    _sub.close();
    super.dispose();
  }
}
