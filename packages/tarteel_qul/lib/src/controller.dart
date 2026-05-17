import 'package:flutter/foundation.dart';

/// Drives `MushafView`'s page navigation: open a page, step forward/back,
/// observe the current page.
///
/// A [ChangeNotifier] so a `MushafView` listening to it re-renders when the
/// current page changes — whether the change came from a swipe inside the view
/// or a programmatic [openPage] from the consumer (a deep link, audio-follow).
class MushafController extends ChangeNotifier {
  MushafController({required int pageCount, int initialPage = 1})
    : assert(pageCount > 0, 'pageCount must be positive'),
      _pageCount = pageCount,
      _currentPage = initialPage.clamp(1, pageCount);

  final int _pageCount;
  int _currentPage;

  /// Total page count of the loaded layout.
  int get pageCount => _pageCount;

  /// The 1-based page currently shown.
  int get currentPage => _currentPage;

  /// Whether a [next] step is possible.
  bool get canGoNext => _currentPage < _pageCount;

  /// Whether a [previous] step is possible.
  bool get canGoPrevious => _currentPage > 1;

  /// Jumps to [page], clamped into `1..pageCount`. No-op (and no notification)
  /// when already on the resolved page.
  void openPage(int page) {
    final clamped = page.clamp(1, _pageCount);
    if (clamped == _currentPage) return;
    _currentPage = clamped;
    notifyListeners();
  }

  /// Advances one page toward the end of the mushaf.
  void next() {
    if (canGoNext) openPage(_currentPage + 1);
  }

  /// Steps back one page toward the start of the mushaf.
  void previous() {
    if (canGoPrevious) openPage(_currentPage - 1);
  }
}
