import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/error/failure.dart';
import '../../../core/error/result.dart';
import '../../../data/quran/providers.dart';
import '../../../domain/quran/quran_search_result.dart';

const kQuranSearchResultLimit = 50;

final quranSearchProvider =
    NotifierProvider<QuranSearchController, QuranSearchState>(
      QuranSearchController.new,
    );

class QuranSearchController extends Notifier<QuranSearchState> {
  @override
  QuranSearchState build() => const QuranSearchState.idle();

  Future<void> submit(String query) async {
    if (state.isLoading) {
      return;
    }

    final trimmed = query.trim();
    if (trimmed.isEmpty) {
      state = const QuranSearchState.invalid(
        message: 'Enter Arabic text to search.',
      );
      return;
    }

    state = QuranSearchState.loading(query: trimmed);
    final result = await ref
        .read(quranRepositoryProvider)
        .searchAyahs(trimmed, limit: kQuranSearchResultLimit);

    state = switch (result) {
      Ok(:final value) when value.isEmpty => QuranSearchState.empty(
        query: trimmed,
      ),
      Ok(:final value) => QuranSearchState.results(
        query: trimmed,
        results: value,
      ),
      Err(:final failure) => QuranSearchState.failure(
        query: trimmed,
        failure: failure,
      ),
    };
  }

  void clear() {
    state = const QuranSearchState.idle();
  }
}

enum QuranSearchStatus { idle, loading, results, empty, invalid, failure }

class QuranSearchState {
  const QuranSearchState._({
    required this.status,
    required this.query,
    required this.results,
    required this.message,
    required this.failure,
  });

  const QuranSearchState.idle()
    : this._(
        status: QuranSearchStatus.idle,
        query: '',
        results: const [],
        message: null,
        failure: null,
      );

  const QuranSearchState.loading({required String query})
    : this._(
        status: QuranSearchStatus.loading,
        query: query,
        results: const [],
        message: null,
        failure: null,
      );

  const QuranSearchState.results({
    required String query,
    required List<QuranSearchResult> results,
  }) : this._(
         status: QuranSearchStatus.results,
         query: query,
         results: results,
         message: null,
         failure: null,
       );

  const QuranSearchState.empty({required String query})
    : this._(
        status: QuranSearchStatus.empty,
        query: query,
        results: const [],
        message: null,
        failure: null,
      );

  const QuranSearchState.invalid({required String message})
    : this._(
        status: QuranSearchStatus.invalid,
        query: '',
        results: const [],
        message: message,
        failure: null,
      );

  const QuranSearchState.failure({
    required String query,
    required Failure failure,
  }) : this._(
         status: QuranSearchStatus.failure,
         query: query,
         results: const [],
         message: null,
         failure: failure,
       );

  final QuranSearchStatus status;
  final String query;
  final List<QuranSearchResult> results;
  final String? message;
  final Failure? failure;

  bool get isLoading => status == QuranSearchStatus.loading;
}
