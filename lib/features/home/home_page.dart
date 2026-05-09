import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:forui/forui.dart';

import '../../core/error/result.dart';
import '../../domain/quran/surah.dart';
import '../surahs/state/surahs_provider.dart';

class HomePageKeys {
  const HomePageKeys._();

  static const title = Key('home.title');
  static const body = Key('home.body');
  static const list = Key('home.surah_list');
  static const loading = Key('home.surah_loading');
  static const error = Key('home.surah_error');
}

class HomePage extends ConsumerWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(surahsProvider);

    return FScaffold(
      header: const FHeader(title: Text('Surahs', key: HomePageKeys.title)),
      child: KeyedSubtree(
        key: HomePageKeys.body,
        child: async.when(
          loading: () => const _LoadingState(),
          error: (e, st) => _ErrorState(message: 'Could not load surahs: $e'),
          data: (result) => switch (result) {
            Ok(:final value) => _SurahList(surahs: value),
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
          children: const [
            FProgress(),
            SizedBox(height: 12),
            Text('Loading surahs…'),
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
        title: const Text("Couldn't load the surah list"),
        subtitle: Text(message),
      ),
    );
  }
}

class _SurahList extends StatelessWidget {
  const _SurahList({required this.surahs});

  final List<Surah> surahs;

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      key: HomePageKeys.list,
      itemCount: surahs.length,
      itemBuilder: (context, i) {
        final s = surahs[i];
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          child: FTile(
            prefix: SizedBox(
              width: 32,
              child: Text(
                '${s.number}',
                textAlign: TextAlign.end,
                style: context.theme.typography.sm,
              ),
            ),
            title: Text(s.nameArabic, textDirection: TextDirection.rtl),
            subtitle: Text(
              '${s.nameLatin} · ${s.ayahCount} ayahs',
              style: context.theme.typography.sm,
            ),
          ),
        );
      },
    );
  }
}
