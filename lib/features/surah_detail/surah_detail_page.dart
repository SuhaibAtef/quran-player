import 'package:flutter/widgets.dart';
import 'package:forui/forui.dart';

class SurahDetailPageKeys {
  const SurahDetailPageKeys._();

  static const title = Key('surah_detail.title');
  static const body = Key('surah_detail.body');
}

class SurahDetailPage extends StatelessWidget {
  const SurahDetailPage({required this.surahId, super.key});

  final String surahId;

  @override
  Widget build(BuildContext context) {
    return FScaffold(
      header: FHeader.nested(
        title: Text('Surah $surahId', key: SurahDetailPageKeys.title),
      ),
      child: Center(
        key: SurahDetailPageKeys.body,
        child: Text('Ayahs for surah $surahId will render here.'),
      ),
    );
  }
}
