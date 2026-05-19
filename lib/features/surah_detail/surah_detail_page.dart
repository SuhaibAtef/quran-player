import 'package:flutter/widgets.dart';
import 'package:forui/forui.dart';

import '../../l10n/app_localizations.dart';

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
    final l10n = AppLocalizations.of(context);
    return FScaffold(
      header: FHeader.nested(
        title: Text(
          l10n.surahDetailTitle(surahId),
          key: SurahDetailPageKeys.title,
        ),
      ),
      child: Center(
        key: SurahDetailPageKeys.body,
        child: Text(l10n.surahDetailPlaceholder(surahId)),
      ),
    );
  }
}
