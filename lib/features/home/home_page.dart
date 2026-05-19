import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:forui/forui.dart';
import 'package:go_router/go_router.dart';

import '../../app/router/route_names.dart';
import '../../core/error/result.dart';
import '../../core/l10n/display_number.dart';
import '../../domain/quran/surah.dart';
import '../../l10n/app_localizations.dart';
import '../player/state/audio_player_controller.dart';
import '../reader/state/reading_position_controller.dart';
import '../surahs/state/surahs_provider.dart';

class HomePageKeys {
  const HomePageKeys._();

  static const title = Key('home.title');
  static const body = Key('home.body');
  static const list = Key('home.surah_list');
  static const loading = Key('home.surah_loading');
  static const error = Key('home.surah_error');
  static const continueReading = Key('home.continue_reading');

  static Key playSurah(int surah) => ValueKey('home.surah_play.$surah');
}

class HomePage extends ConsumerWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(surahsProvider);

    return FScaffold(
      header: FHeader(
        title: Text(
          AppLocalizations.of(context).surahsTitle,
          key: HomePageKeys.title,
        ),
      ),
      child: KeyedSubtree(
        key: HomePageKeys.body,
        child: async.when(
          loading: () => const _LoadingState(),
          error: (e, st) => _ErrorState(
            message: AppLocalizations.of(context).surahsLoadErrorDetail('$e'),
          ),
          data: (result) => switch (result) {
            Ok(:final value) => Column(
              children: [
                _ContinueReadingCard(surahs: value),
                Expanded(child: _SurahList(surahs: value)),
              ],
            ),
            Err(:final failure) => _ErrorState(message: failure.message),
          },
        ),
      ),
    );
  }
}

class _LoadingState extends StatelessWidget {
  const _LoadingState();

  @override
  Widget build(BuildContext context) {
    return Center(
      key: HomePageKeys.loading,
      child: SizedBox(
        width: 240,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const FProgress(),
            const SizedBox(height: 12),
            Text(AppLocalizations.of(context).surahsLoading),
          ],
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
      key: HomePageKeys.error,
      padding: const EdgeInsets.all(24),
      child: FAlert(
        title: Text(AppLocalizations.of(context).surahsLoadErrorTitle),
        subtitle: Text(message),
      ),
    );
  }
}

/// "Continue reading" entry point shown above the surah list when a reading
/// position has been recorded. Absent otherwise. Opens the existing ayah
/// reader deep link, so no new route or top-level destination is added.
class _ContinueReadingCard extends ConsumerWidget {
  const _ContinueReadingCard({required this.surahs});

  final List<Surah> surahs;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final position = ref.watch(readingPositionProvider).valueOrNull;
    if (position == null) return const SizedBox.shrink();

    final l10n = AppLocalizations.of(context);
    final match = surahs.where((s) => s.number == position.key.surah);
    final surahName = match.isEmpty
        ? l10n.surahFallbackName(position.key.surah)
        : match.first.nameLatin;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
      child: FTile(
        key: HomePageKeys.continueReading,
        prefix: const Icon(FIcons.bookOpen),
        title: Text(l10n.homeContinueReading),
        subtitle: Text(
          l10n.homeContinueReadingSubtitle(surahName, '${position.key}'),
        ),
        suffix: Icon(
          Directionality.of(context) == TextDirection.rtl
              ? FIcons.chevronLeft
              : FIcons.chevronRight,
        ),
        onPress: () => context.go(
          RoutePaths.readerAyahFor(position.key.surah, position.key.ayah),
        ),
      ),
    );
  }
}

class _SurahList extends ConsumerWidget {
  const _SurahList({required this.surahs});

  final List<Surah> surahs;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final localeName = AppLocalizations.of(context).localeName;
    return ListView.builder(
      key: HomePageKeys.list,
      itemCount: surahs.length,
      itemBuilder: (context, i) {
        final s = surahs[i];
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          child: Row(
            children: [
              Expanded(
                child: FTile(
                  key: ValueKey('home.surah_tile.${s.number}'),
                  onPress: () =>
                      context.go(RoutePaths.readerAyahFor(s.number, 1)),
                  prefix: SizedBox(
                    width: 32,
                    child: Text(
                      localizedNumber(s.number, localeName),
                      textAlign: TextAlign.end,
                      style: context.theme.typography.sm,
                    ),
                  ),
                  title: Text(s.nameArabic, textDirection: TextDirection.rtl),
                  subtitle: Text(
                    AppLocalizations.of(
                      context,
                    ).surahListSubtitle(s.nameLatin, s.ayahCount),
                    style: context.theme.typography.sm,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              FButton(
                key: HomePageKeys.playSurah(s.number),
                variant: FButtonVariant.ghost,
                onPress: () => ref
                    .read(audioPlayerControllerProvider.notifier)
                    .startSurah(s.number),
                child: const Icon(FIcons.play),
              ),
            ],
          ),
        );
      },
    );
  }
}
