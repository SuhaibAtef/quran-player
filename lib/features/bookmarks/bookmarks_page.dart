import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:forui/forui.dart';
import 'package:go_router/go_router.dart';

import '../../app/router/route_names.dart';
import '../../app/state/user_db_provider.dart';
import '../../l10n/app_localizations.dart';
import 'state/bookmark_rows.dart';
import 'state/bookmarks_controller.dart';

class BookmarksPageKeys {
  const BookmarksPageKeys._();

  static const title = Key('bookmarks.title');
  static const body = Key('bookmarks.body');
  static const loading = Key('bookmarks.loading');
  static const empty = Key('bookmarks.empty');
  static const unavailable = Key('bookmarks.unavailable');
  static const error = Key('bookmarks.error');
  static const list = Key('bookmarks.list');

  static Key tile(int surah, int ayah) =>
      ValueKey('bookmarks.tile.$surah.$ayah');

  static Key remove(int surah, int ayah) =>
      ValueKey('bookmarks.remove.$surah.$ayah');
}

class BookmarksPage extends ConsumerWidget {
  const BookmarksPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final health = ref.watch(userDbHealthProvider);

    return FScaffold(
      header: FHeader(
        title: Text(
          AppLocalizations.of(context).bookmarksTitle,
          key: BookmarksPageKeys.title,
        ),
      ),
      child: KeyedSubtree(
        key: BookmarksPageKeys.body,
        child: health.when(
          loading: () => const _Loading(),
          // userDbStateProvider catches its own failures, so this branch is
          // defensive — treat it the same as an unavailable user.db.
          error: (_, _) => const _UnavailableNotice(),
          data: (status) => status == UserDbHealth.failed
              ? const _UnavailableNotice()
              : const _BookmarksBody(),
        ),
      ),
    );
  }
}

class _BookmarksBody extends ConsumerWidget {
  const _BookmarksBody();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final rows = ref.watch(bookmarkRowsProvider);
    return rows.when(
      loading: () => const _Loading(),
      error: (error, _) => _ErrorState(message: '$error'),
      data: (rows) =>
          rows.isEmpty ? const _EmptyState() : _BookmarksList(rows: rows),
    );
  }
}

class _BookmarksList extends ConsumerWidget {
  const _BookmarksList({required this.rows});

  final List<BookmarkRow> rows;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ListView.builder(
      key: BookmarksPageKeys.list,
      itemCount: rows.length,
      itemBuilder: (context, i) {
        final row = rows[i];
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          child: FTile(
            key: BookmarksPageKeys.tile(row.key.surah, row.key.ayah),
            onPress: () => context.go(
              RoutePaths.readerAyahFor(row.key.surah, row.key.ayah),
            ),
            title: Text(
              AppLocalizations.of(
                context,
              ).bookmarkTileTitle('${row.key}', row.surahName),
            ),
            subtitle: Text(
              row.ayahText,
              textDirection: TextDirection.rtl,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            suffix: FButton.icon(
              key: BookmarksPageKeys.remove(row.key.surah, row.key.ayah),
              variant: FButtonVariant.ghost,
              onPress: () =>
                  ref.read(bookmarksProvider.notifier).remove(row.key),
              child: const Icon(FIcons.trash2),
            ),
          ),
        );
      },
    );
  }
}

class _Loading extends StatelessWidget {
  const _Loading();

  @override
  Widget build(BuildContext context) {
    return Center(
      key: BookmarksPageKeys.loading,
      child: SizedBox(
        width: 240,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const FProgress(),
            const SizedBox(height: 12),
            Text(AppLocalizations.of(context).bookmarksLoading),
          ],
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    return Center(
      key: BookmarksPageKeys.empty,
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              FIcons.bookmark,
              size: 32,
              color: context.theme.colors.mutedForeground,
            ),
            const SizedBox(height: 12),
            Text(
              AppLocalizations.of(context).bookmarksEmptyTitle,
              style: context.theme.typography.lg,
            ),
            const SizedBox(height: 8),
            Text(
              AppLocalizations.of(context).bookmarksEmptyMessage,
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

class _UnavailableNotice extends StatelessWidget {
  const _UnavailableNotice();

  @override
  Widget build(BuildContext context) {
    return Padding(
      key: BookmarksPageKeys.unavailable,
      padding: const EdgeInsets.all(16),
      child: FAlert(
        icon: const Icon(FIcons.triangleAlert),
        title: Text(AppLocalizations.of(context).bookmarksUnavailableTitle),
        subtitle: Text(
          AppLocalizations.of(context).bookmarksUnavailableMessage,
        ),
      ),
    );
  }
}

class _ErrorState extends StatelessWidget {
  const _ErrorState({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Padding(
      key: BookmarksPageKeys.error,
      padding: const EdgeInsets.all(16),
      child: FAlert(
        icon: const Icon(FIcons.triangleAlert),
        title: Text(AppLocalizations.of(context).bookmarksLoadErrorTitle),
        subtitle: Text(message),
      ),
    );
  }
}
