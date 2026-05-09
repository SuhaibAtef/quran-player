import 'package:flutter/material.dart' show ThemeMode;
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:forui/forui.dart';

import '../../app/state/theme_mode_provider.dart';
import '../../core/error/result.dart';
import '../../domain/quran/quran_source.dart';
import 'state/quran_source_provider.dart';

class SettingsPageKeys {
  const SettingsPageKeys._();

  static const title = Key('settings.title');
  static const themeSection = Key('settings.theme_section');
  static const themeOptionLight = Key('settings.theme.light');
  static const themeOptionDark = Key('settings.theme.dark');
  static const themeOptionSystem = Key('settings.theme.system');
  static const darkOnlyMarker = Key('settings.dark_only_marker');
  static const sourceSection = Key('settings.source_section');
  static const sourceName = Key('settings.source.name');
  static const sourceEdition = Key('settings.source.edition');
  static const sourceVersion = Key('settings.source.version');
  static const sourceLicense = Key('settings.source.license');
  static const sourceUrl = Key('settings.source.url');
}

class SettingsPage extends ConsumerWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final mode = ref.watch(themeModeProvider);
    final controller = ref.read(themeModeProvider.notifier);
    final brightness = context.theme.colors.brightness;

    return FScaffold(
      header: const FHeader(
        title: Text('Settings', key: SettingsPageKeys.title),
      ),
      child: ListView(
        children: [
          Container(
            key: SettingsPageKeys.themeSection,
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Padding(
                  padding: EdgeInsets.only(bottom: 8),
                  child: Text(
                    'Theme',
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                  ),
                ),
                _ThemeOptionTile(
                  optionKey: SettingsPageKeys.themeOptionSystem,
                  label: 'System',
                  selected: mode == ThemeMode.system,
                  onPress: () => controller.setMode(ThemeMode.system),
                ),
                _ThemeOptionTile(
                  optionKey: SettingsPageKeys.themeOptionLight,
                  label: 'Light',
                  selected: mode == ThemeMode.light,
                  onPress: () => controller.setMode(ThemeMode.light),
                ),
                _ThemeOptionTile(
                  optionKey: SettingsPageKeys.themeOptionDark,
                  label: 'Dark',
                  selected: mode == ThemeMode.dark,
                  onPress: () => controller.setMode(ThemeMode.dark),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          const _QuranSourceSection(),
          if (brightness == Brightness.dark)
            const SizedBox(key: SettingsPageKeys.darkOnlyMarker, height: 1),
        ],
      ),
    );
  }
}

class _QuranSourceSection extends ConsumerWidget {
  const _QuranSourceSection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(quranSourceProvider);
    return Container(
      key: SettingsPageKeys.sourceSection,
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.only(bottom: 8),
            child: Text(
              'Quran source',
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
            ),
          ),
          async.when(
            loading: () => const Padding(
              padding: EdgeInsets.symmetric(vertical: 8),
              child: FProgress(),
            ),
            error: (e, st) => Text("Couldn't load attribution: $e"),
            data: (result) => switch (result) {
              Ok(:final value) => _QuranSourceCard(source: value),
              Err(:final failure) => Text(
                "Couldn't load attribution: ${failure.message}",
              ),
            },
          ),
        ],
      ),
    );
  }
}

class _QuranSourceCard extends StatelessWidget {
  const _QuranSourceCard({required this.source});

  final QuranSource source;

  @override
  Widget build(BuildContext context) {
    final smallStyle = context.theme.typography.sm;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          source.name,
          key: SettingsPageKeys.sourceName,
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 2),
        Text(
          source.edition,
          key: SettingsPageKeys.sourceEdition,
          style: smallStyle,
        ),
        Text(
          'Version ${source.version}',
          key: SettingsPageKeys.sourceVersion,
          style: smallStyle,
        ),
        const SizedBox(height: 4),
        Text(
          source.license,
          key: SettingsPageKeys.sourceLicense,
          style: smallStyle,
        ),
        const SizedBox(height: 4),
        Text(source.url, key: SettingsPageKeys.sourceUrl, style: smallStyle),
      ],
    );
  }
}

class _ThemeOptionTile extends StatelessWidget {
  const _ThemeOptionTile({
    required this.optionKey,
    required this.label,
    required this.selected,
    required this.onPress,
  });

  final Key optionKey;
  final String label;
  final bool selected;
  final VoidCallback onPress;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: FButton(
        key: optionKey,
        style: selected ? FButtonStyle.primary() : FButtonStyle.outline(),
        onPress: onPress,
        prefix: Icon(selected ? FIcons.circleCheck : FIcons.circle),
        child: Align(
          alignment: AlignmentDirectional.centerStart,
          child: Text(label),
        ),
      ),
    );
  }
}
