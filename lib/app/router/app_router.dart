import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/error/result.dart';
import '../../data/quran/mushaf_locator_provider.dart';
import '../../data/quran/providers.dart';
import '../../domain/quran/ayah_key.dart';
import '../../domain/quran/mushaf_locator.dart';
import '../../features/_errors/bootstrapping_screen.dart';
import '../../features/_errors/data_integrity_screen.dart';
import '../../features/bookmarks/bookmarks_page.dart';
import '../../features/home/home_page.dart';
import '../../features/mcp_status/mcp_status_page.dart';
import '../../features/reader/reader_screen.dart';
import '../../features/search/search_page.dart';
import '../../features/settings/settings_page.dart';
import '../../features/surah_detail/surah_detail_page.dart';
import '../state/quran_integrity_provider.dart';
import '../state/reader_mode.dart';
import '../state/reader_mode_provider.dart';
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
      if (path.startsWith('/reader/')) return null;
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
          GoRoute(
            path: RoutePaths.readerPagePattern,
            name: RouteNames.readerPage,
            redirect: (context, state) {
              final n = int.tryParse(state.pathParameters['pageNumber'] ?? '');
              if (n == null || n < 1 || n > kMushafPageCount) {
                return RoutePaths.home;
              }
              return null;
            },
            builder: (context, state) {
              final n = int.parse(state.pathParameters['pageNumber']!);
              final anchor = _parseAnchor(state.uri.queryParameters['anchor']);
              return ReaderScreen(
                target: PageReaderTarget(pageNumber: n, anchor: anchor),
              );
            },
          ),
          GoRoute(
            path: RoutePaths.readerSurahPattern,
            name: RouteNames.readerSurah,
            redirect: (context, state) {
              final n = int.tryParse(state.pathParameters['surahNumber'] ?? '');
              if (n == null || n < 1 || n > 114) {
                return RoutePaths.home;
              }
              return null;
            },
            builder: (context, state) {
              final n = int.parse(state.pathParameters['surahNumber']!);
              final anchor = _parseAnchor(state.uri.queryParameters['anchor']);
              return ReaderScreen(
                target: SurahReaderTarget(surahNumber: n, anchor: anchor),
              );
            },
          ),
          GoRoute(
            path: RoutePaths.readerAyahPattern,
            name: RouteNames.readerAyah,
            redirect: (context, state) async {
              final s = int.tryParse(state.pathParameters['surah'] ?? '');
              final a = int.tryParse(state.pathParameters['ayah'] ?? '');
              if (s == null || a == null) return RoutePaths.home;
              final keyResult = AyahKey.tryNew(s, a);
              if (keyResult is Err<AyahKey>) return RoutePaths.home;
              final key = (keyResult as Ok<AyahKey>).value;

              final ayahResult = await ref
                  .read(quranRepositoryProvider)
                  .getAyah(key);
              if (ayahResult is Err) return RoutePaths.home;

              final status = ref.read(mushafLocatorProvider);
              final anchorParam = '$s:$a';
              if (status.usingFallback) {
                // Page rendering unavailable; route the repository-validated
                // ayah to text mode.
                return '${RoutePaths.readerSurahFor(s)}'
                    '?anchor=$anchorParam';
              }
              final pageRes = status.locator.pageForAyah(key);
              if (pageRes is Err<int>) return RoutePaths.home;
              final mode = ref.read(readerModeProvider);
              if (mode == ReaderMode.page) {
                final page = (pageRes as Ok<int>).value;
                return '${RoutePaths.readerPageFor(page)}'
                    '?anchor=$anchorParam';
              }
              return '${RoutePaths.readerSurahFor(s)}?anchor=$anchorParam';
            },
            builder: (context, state) =>
                const SizedBox.shrink(), // never reached: redirect always hits
          ),
        ],
      ),
    ],
  );
}

AyahKey? _parseAnchor(String? raw) {
  if (raw == null || raw.isEmpty) return null;
  return AyahKey.parse(raw).valueOrNull;
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
