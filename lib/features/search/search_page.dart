import 'package:flutter/widgets.dart';
import 'package:forui/forui.dart';

class SearchPageKeys {
  const SearchPageKeys._();

  static const title = Key('search.title');
  static const body = Key('search.body');
}

class SearchPage extends StatelessWidget {
  const SearchPage({super.key});

  @override
  Widget build(BuildContext context) {
    return FScaffold(
      header: const FHeader(title: Text('Search', key: SearchPageKeys.title)),
      child: const Center(
        key: SearchPageKeys.body,
        child: Text('Quran search will live here.'),
      ),
    );
  }
}
