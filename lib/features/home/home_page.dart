import 'package:flutter/widgets.dart';
import 'package:forui/forui.dart';

class HomePageKeys {
  const HomePageKeys._();

  static const title = Key('home.title');
  static const body = Key('home.body');
}

class HomePage extends StatelessWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context) {
    return FScaffold(
      header: const FHeader(title: Text('Surahs', key: HomePageKeys.title)),
      child: const Center(
        key: HomePageKeys.body,
        child: Text('The Quran reader will live here.'),
      ),
    );
  }
}
