import 'package:flutter/material.dart' show ThemeMode;
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:forui/forui.dart';

import '../../app/state/reader_mode.dart';
import '../../app/state/reader_mode_provider.dart';
import '../../app/state/tajweed_provider.dart';
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
  static const readerSection = Key('settings.reader_section');
  static const readerOptionPage = Key('settings.reader.page');
  static const readerOptionText = Key('settings.reader.text');
  static const readerTajweedSwitch = Key('settings.reader.tajweed_switch');
  static const sourceSection = Key('settings.source_section');
  static const sourceName = Key('settings.source.name');
  static const sourceEdition = Key('settings.source.edition');
  static const sourceVersion = Key('settings.source.version');
  static const sourceLicense = Key('settings.source.license');
  static const sourceUrl = Key('settings.source.url');
  static const qcfSection = Key('settings.qcf_section');
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
          const _ReaderModeSection(),
          const SizedBox(height: 16),
          const _QuranSourceSection(),
          const SizedBox(height: 16),
          const _QcfAttributionSection(),
          if (brightness == Brightness.dark)
            const SizedBox(key: SettingsPageKeys.darkOnlyMarker, height: 1),
        ],
      ),
    );
  }
}

class _ReaderModeSection extends ConsumerWidget {
  const _ReaderModeSection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final mode = ref.watch(readerModeProvider);
    final controller = ref.read(readerModeProvider.notifier);
    final tajweed = ref.watch(tajweedEnabledProvider);
    final tajweedController = ref.read(tajweedEnabledProvider.notifier);

    return Container(
      key: SettingsPageKeys.readerSection,
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.only(bottom: 8),
            child: Text(
              'Reader',
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
            ),
          ),
          _ReaderModeTile(
            optionKey: SettingsPageKeys.readerOptionPage,
            label: 'Mushaf page (recommended)',
            selected: mode == ReaderMode.page,
            onPress: () => controller.setMode(ReaderMode.page),
          ),
          _ReaderModeTile(
            optionKey: SettingsPageKeys.readerOptionText,
            label: 'Plain text scroll',
            selected: mode == ReaderMode.text,
            onPress: () => controller.setMode(ReaderMode.text),
          ),
          const SizedBox(height: 12),
          // Tajweed colouring is a presentation flag honoured only by the
          // page-mode renderer; we still surface it here so the user can flip
          // it before switching modes.
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Row(
              children: [
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Tajweed colouring'),
                      SizedBox(height: 2),
                      Text(
                        'Highlights tajweed rules in the printed mushaf '
                        'view. No effect in plain-text mode.',
                        style: TextStyle(fontSize: 12),
                      ),
                    ],
                  ),
                ),
                FSwitch(
                  key: SettingsPageKeys.readerTajweedSwitch,
                  value: tajweed,
                  onChange: (v) => tajweedController.setEnabled(v),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ReaderModeTile extends StatelessWidget {
  const _ReaderModeTile({
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
        variant: selected ? FButtonVariant.primary : FButtonVariant.outline,
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

class _QcfAttributionSection extends StatelessWidget {
  const _QcfAttributionSection();

  @override
  Widget build(BuildContext context) {
    final small = context.theme.typography.sm;
    return Container(
      key: SettingsPageKeys.qcfSection,
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.only(bottom: 8),
            child: Text(
              'QCF mushaf rendering',
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
            ),
          ),
          const Text(
            'qcf_quran_plus',
            style: TextStyle(fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 2),
          Text('Version 0.0.8 (MIT)', style: small),
          Text(
            'Bundles QCF (King Fahd Glorious Qur’an Complex) glyph fonts and '
            'standard 604-page mushaf metadata.',
            style: small,
          ),
          Text(
            'Layout and glyphs only — canonical text comes from Tanzil above.',
            style: small,
          ),
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
        variant: selected ? FButtonVariant.primary : FButtonVariant.outline,
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
