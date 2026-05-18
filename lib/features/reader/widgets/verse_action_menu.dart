import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:forui/forui.dart';

import '../../../app/state/user_db_provider.dart';
import '../../../domain/quran/ayah_key.dart';
import '../../bookmarks/state/bookmarks_controller.dart';
import '../../player/state/audio_player_controller.dart';

class VerseActionMenuKeys {
  const VerseActionMenuKeys._();

  static const sheet = Key('reader.verse_menu');
  static const play = Key('reader.verse_menu.play');
  static const bookmark = Key('reader.verse_menu.bookmark');
  static const highlight = Key('reader.verse_menu.highlight');
}

/// Opens the verse action menu for [ayah] as a modal sheet.
///
/// Offered from both reader modes when the user taps a verse — text mode taps
/// the ayah row, page mode forwards `MushafView.onAyahTap`.
Future<void> showVerseActionMenu(BuildContext context, AyahKey ayah) {
  return showFSheet<void>(
    context: context,
    side: FLayout.btt,
    builder: (context) => _VerseActionSheet(ayah: ayah),
  );
}

class _VerseActionSheet extends ConsumerWidget {
  const _VerseActionSheet({required this.ayah});

  final AyahKey ayah;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final bookmarked = ref.watch(bookmarkedKeysProvider).contains(ayah);
    final bookmarksAvailable = ref.watch(bookmarkRepositoryProvider) != null;

    return KeyedSubtree(
      key: VerseActionMenuKeys.sheet,
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 8, 12, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(8, 8, 8, 12),
                child: Text(
                  'Ayah $ayah',
                  style: context.theme.typography.sm.copyWith(
                    color: context.theme.colors.mutedForeground,
                  ),
                ),
              ),
              FTile(
                key: VerseActionMenuKeys.play,
                prefix: const Icon(FIcons.play),
                title: const Text('Play from here'),
                onPress: () {
                  Navigator.of(context).pop();
                  ref
                      .read(audioPlayerControllerProvider.notifier)
                      .startAyah(ayah);
                },
              ),
              if (bookmarksAvailable)
                FTile(
                  key: VerseActionMenuKeys.bookmark,
                  prefix: Icon(
                    bookmarked ? FIcons.bookmarkCheck : FIcons.bookmark,
                  ),
                  title: Text(bookmarked ? 'Remove bookmark' : 'Bookmark'),
                  onPress: () {
                    Navigator.of(context).pop();
                    ref.read(bookmarksProvider.notifier).toggle(ayah);
                  },
                ),
              FTile(
                key: VerseActionMenuKeys.highlight,
                enabled: false,
                prefix: const Icon(FIcons.highlighter),
                title: const Text('Highlight'),
                subtitle: const Text('Coming soon'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
