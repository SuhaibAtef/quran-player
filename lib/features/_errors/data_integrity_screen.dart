import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:forui/forui.dart';

import '../../app/state/quran_integrity_provider.dart';

class DataIntegrityScreenKeys {
  const DataIntegrityScreenKeys._();

  static const root = Key('data_integrity.root');
  static const title = Key('data_integrity.title');
  static const detail = Key('data_integrity.detail');
}

class DataIntegrityScreen extends ConsumerWidget {
  const DataIntegrityScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final status = ref.watch(quranIntegrityProvider);
    final detail = status.failure?.message ?? 'unknown';

    return FScaffold(
      key: DataIntegrityScreenKeys.root,
      header: const FHeader(
        title: Text(
          "Quran data couldn't be verified",
          key: DataIntegrityScreenKeys.title,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              "The bundled Quran database failed an integrity check at "
              "startup. To preserve trust in the text, the app refuses to "
              "serve any Quran data until the issue is resolved.",
            ),
            const SizedBox(height: 16),
            Text('Detail:', style: context.theme.typography.sm),
            const SizedBox(height: 4),
            Text(
              detail,
              key: DataIntegrityScreenKeys.detail,
              style: context.theme.typography.sm,
            ),
            const SizedBox(height: 24),
            const Text(
              'Try reinstalling the app, or run `just build-quran-db` if you '
              'are working from source.',
            ),
          ],
        ),
      ),
    );
  }
}
