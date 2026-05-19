import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/services.dart' show TextInputAction;
import 'package:forui/forui.dart';
import 'package:go_router/go_router.dart';

import '../../app/router/route_names.dart';
import '../../domain/quran/quran_search_result.dart';
import '../../l10n/app_localizations.dart';
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
    final l10n = AppLocalizations.of(context);

    return FScaffold(
      header: FHeader(title: Text(l10n.searchTitle, key: SearchPageKeys.title)),
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
                      hint: l10n.searchHint,
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
                    child: Text(l10n.searchButton),
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
    final l10n = AppLocalizations.of(context);
    return switch (state.status) {
      QuranSearchStatus.idle => _MessageState(
        key: SearchPageKeys.idle,
        title: l10n.searchIdleTitle,
        message: l10n.searchIdleMessage,
      ),
      QuranSearchStatus.loading => const _LoadingState(),
      QuranSearchStatus.empty => _MessageState(
        key: SearchPageKeys.empty,
        title: l10n.searchEmptyTitle,
        message: l10n.searchEmptyMessage(state.query),
      ),
      QuranSearchStatus.invalid => _MessageState(
        key: SearchPageKeys.error,
        title: l10n.searchInvalidTitle,
        message: state.message ?? l10n.searchInvalidMessage,
      ),
      QuranSearchStatus.failure => _FailureState(
        message: state.failure?.message ?? l10n.searchFailureFallback,
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
          children: [
            const FProgress(),
            const SizedBox(height: 12),
            Text(AppLocalizations.of(context).searchLoading),
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
        title: Text(AppLocalizations.of(context).searchFailureTitle),
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
            title: Text(
              AppLocalizations.of(
                context,
              ).searchResultTitle('${result.key}', result.surahNameLatin),
            ),
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
