import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:forui/forui.dart';

import '../../app/state/app_bootstrap_status_provider.dart';
import '../../l10n/app_localizations.dart';

class DataIntegrityScreenKeys {
  const DataIntegrityScreenKeys._();

  static const root = Key('data_integrity.root');
  static const title = Key('data_integrity.title');
  static const detail = Key('data_integrity.detail');
  static const dataset = Key('data_integrity.dataset');
}

class DataIntegrityScreen extends ConsumerWidget {
  const DataIntegrityScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final status = ref.watch(appBootstrapStatusProvider);
    final dataset = status.failingDataset ?? 'Quran';
    final l10n = AppLocalizations.of(context);
    final detail = status.failure?.message ?? l10n.dataIntegrityUnknownDetail;

    return FScaffold(
      key: DataIntegrityScreenKeys.root,
      header: FHeader(
        title: Text(
          l10n.dataIntegrityTitle(dataset),
          key: DataIntegrityScreenKeys.title,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              l10n.dataIntegrityBody(dataset),
              key: DataIntegrityScreenKeys.dataset,
            ),
            const SizedBox(height: 16),
            Text(
              l10n.dataIntegrityDetailLabel,
              style: context.theme.typography.sm,
            ),
            const SizedBox(height: 4),
            Text(
              detail,
              key: DataIntegrityScreenKeys.detail,
              style: context.theme.typography.sm,
            ),
            const SizedBox(height: 24),
            Text(l10n.dataIntegrityHint(dataset.toLowerCase())),
          ],
        ),
      ),
    );
  }
}
