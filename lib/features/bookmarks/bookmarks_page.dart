import 'package:flutter/widgets.dart';
import 'package:forui/forui.dart';

class BookmarksPageKeys {
  const BookmarksPageKeys._();

  static const title = Key('bookmarks.title');
  static const body = Key('bookmarks.body');
}

class BookmarksPage extends StatelessWidget {
  const BookmarksPage({super.key});

  @override
  Widget build(BuildContext context) {
    return FScaffold(
      header: const FHeader(
        title: Text('Bookmarks', key: BookmarksPageKeys.title),
      ),
      child: const Center(
        key: BookmarksPageKeys.body,
        child: Text('Saved ayahs will live here.'),
      ),
    );
  }
}
