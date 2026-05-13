import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/services.dart' show TextInputAction;
import 'package:forui/forui.dart';
import 'package:go_router/go_router.dart';

import '../../app/router/route_names.dart';
import '../../domain/quran/quran_search_result.dart';
import 'state/quran_search_controller.dart';

class SearchPageKeys {
  const SearchPageKeys._();

  static const title = Key('search.title');
  static const body = Key('search.body');
  static const input = Key('search.input');
  static const submit = Key('search.submit');
  static const idle = Key('search.idle');
  static const loading = Key('search.loading');
  static const error = Key('search.error');
  static const empty = Key('search.empty');
  static const results = Key('search.results');

  static Key resultTile(int surah, int ayah) =>
      ValueKey('search.result.$surah.$ayah');
}

class SearchPage extends ConsumerStatefulWidget {
  const SearchPage({super.key});

  @override
  ConsumerState<SearchPage> createState() => _SearchPageState();
}

class _SearchPageState extends ConsumerState<SearchPage> {
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _submit() {
    ref.read(quranSearchProvider.notifier).submit(_controller.text);
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(quranSearchProvider);

    return FScaffold(
      header: const FHeader(title: Text('Search', key: SearchPageKeys.title)),
      child: KeyedSubtree(
        key: SearchPageKeys.body,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: FTextField(
                      key: SearchPageKeys.input,
                      control: FTextFieldControl.managed(
                        controller: _controller,
                      ),
                      hint: 'Search Arabic Quran text',
                      textInputAction: TextInputAction.search,
                      textDirection: TextDirection.rtl,
                      onSubmit: (_) => _submit(),
                    ),
                  ),
                  const SizedBox(width: 8),
                  FButton(
                    key: SearchPageKeys.submit,
                    onPress: state.isLoading ? null : _submit,
                    prefix: const Icon(FIcons.search),
                    child: const Text('Search'),
                  ),
                ],
              ),
            ),
            Expanded(child: _SearchBody(state: state)),
          ],
        ),
      ),
    );
  }
}

class _SearchBody extends StatelessWidget {
  const _SearchBody({required this.state});

  final QuranSearchState state;

  @override
  Widget build(BuildContext context) {
    return switch (state.status) {
      QuranSearchStatus.idle => const _MessageState(
        key: SearchPageKeys.idle,
        title: 'Search the Quran',
        message: 'Enter Arabic text to find matching ayahs.',
      ),
      QuranSearchStatus.loading => const _LoadingState(),
      QuranSearchStatus.empty => _MessageState(
        key: SearchPageKeys.empty,
        title: 'No matches',
        message: 'No ayahs matched "${state.query}".',
      ),
      QuranSearchStatus.invalid => _MessageState(
        key: SearchPageKeys.error,
        title: 'Search query needed',
        message: state.message ?? 'Enter Arabic text to search.',
      ),
      QuranSearchStatus.failure => _FailureState(
        message: state.failure?.message ?? 'Search failed.',
      ),
      QuranSearchStatus.results => _ResultsList(results: state.results),
    };
  }
}

class _LoadingState extends StatelessWidget {
  const _LoadingState();

  @override
  Widget build(BuildContext context) {
    return Center(
      key: SearchPageKeys.loading,
      child: SizedBox(
        width: 240,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: const [
            FProgress(),
            SizedBox(height: 12),
            Text('Searching…'),
          ],
        ),
      ),
    );
  }
}

class _MessageState extends StatelessWidget {
  const _MessageState({super.key, required this.title, required this.message});

  final String title;
  final String message;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(title, style: context.theme.typography.lg),
            const SizedBox(height: 8),
            Text(message, textAlign: TextAlign.center),
          ],
        ),
      ),
    );
  }
}

class _FailureState extends StatelessWidget {
  const _FailureState({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Padding(
      key: SearchPageKeys.error,
      padding: const EdgeInsets.all(16),
      child: FAlert(
        title: const Text("Couldn't search the Quran"),
        subtitle: Text(message),
      ),
    );
  }
}

class _ResultsList extends StatelessWidget {
  const _ResultsList({required this.results});

  final List<QuranSearchResult> results;

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      key: SearchPageKeys.results,
      itemCount: results.length,
      itemBuilder: (context, i) {
        final result = results[i];
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          child: FTile(
            key: SearchPageKeys.resultTile(result.key.surah, result.key.ayah),
            onPress: () => context.go(
              RoutePaths.readerAyahFor(result.key.surah, result.key.ayah),
            ),
            title: Text('${result.key} · ${result.surahNameLatin}'),
            subtitle: Text(
              '${result.surahNameArabic}\n${result.text}',
              textDirection: TextDirection.rtl,
            ),
          ),
        );
      },
    );
  }
}
