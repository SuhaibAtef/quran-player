import 'package:flutter/material.dart' show ThemeMode, showDialog;
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:forui/forui.dart';

import '../../app/state/mcp_settings_provider.dart';
import '../../app/state/reader_mode.dart';
import '../../app/state/reader_mode_provider.dart';
import '../../app/state/tajweed_provider.dart';
import '../../app/state/theme_mode_provider.dart';
import '../../app/state/user_db_provider.dart';
import '../../core/error/result.dart';
import '../../data/audio/quran_com_audio_source.dart';
import '../../domain/quran/quran_source.dart';
import '../../domain/tafsir/tafsir_source.dart';
import 'state/quran_source_provider.dart';
import 'state/tafsir_source_provider.dart';

class SettingsPageKeys {
  const SettingsPageKeys._();

  static const title = Key('settings.title');
  static const list = Key('settings.list');
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
  static const tafsirSection = Key('settings.tafsir_section');
  static const tafsirName = Key('settings.tafsir.name');
  static const tafsirPublisher = Key('settings.tafsir.publisher');
  static const tafsirVersion = Key('settings.tafsir.version');
  static const tafsirLicense = Key('settings.tafsir.license');
  static const tafsirUrl = Key('settings.tafsir.url');
  static const qcfSection = Key('settings.qcf_section');
  static const audioSection = Key('settings.audio_section');
  static const mcpSection = Key('settings.mcp_section');
  static const mcpEnableSwitch = Key('settings.mcp.enable_switch');
  static const mcpPlaybackSwitch = Key('settings.mcp.playback_switch');
  static const mcpBookmarkSwitch = Key('settings.mcp.bookmark_switch');
  static const mcpClearAuditButton = Key('settings.mcp.clear_audit_button');
  static const mcpUserDbNotice = Key('settings.mcp.user_db_notice');
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
        key: SettingsPageKeys.list,
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
          if (brightness == Brightness.dark)
            const SizedBox(key: SettingsPageKeys.darkOnlyMarker, height: 1),
          const SizedBox(height: 16),
          const _ReaderModeSection(),
          const SizedBox(height: 16),
          const _QuranSourceSection(),
          const SizedBox(height: 16),
          const _TafsirSourceSection(),
          const SizedBox(height: 16),
          const _AudioAttributionSection(),
          const SizedBox(height: 16),
          const _McpSection(),
          const SizedBox(height: 16),
          const _QcfAttributionSection(),
        ],
      ),
    );
  }
}

class _McpSection extends ConsumerWidget {
  const _McpSection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(mcpSettingsControllerProvider);
    final controller = ref.read(mcpSettingsControllerProvider.notifier);
    final auditAsync = ref.watch(userDbStateProvider);
    final small = context.theme.typography.sm;

    return Container(
      key: SettingsPageKeys.mcpSection,
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.only(bottom: 8),
            child: Text(
              'MCP server',
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
            ),
          ),
          const Text(
            'Loopback-only HTTP server that lets local MCP clients query the '
            'Quran corpus and (when granted) control playback. Disable to '
            'stop the server entirely.',
          ),
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Row(
              children: [
                const Expanded(child: Text('Enable MCP')),
                FSwitch(
                  key: SettingsPageKeys.mcpEnableSwitch,
                  value: settings.enabled,
                  onChange: (v) => controller.setEnabled(v),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Row(
              children: [
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Allow MCP playback control'),
                      SizedBox(height: 2),
                      Text(
                        'Grants Mode B tools (play/pause/seek). When off, '
                        'playback tools return scope_denied without changing '
                        'player state.',
                        style: TextStyle(fontSize: 12),
                      ),
                    ],
                  ),
                ),
                FSwitch(
                  key: SettingsPageKeys.mcpPlaybackSwitch,
                  value: settings.scopePlayback,
                  onChange: settings.enabled
                      ? (v) => controller.setScopePlayback(v)
                      : null,
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Row(
              children: [
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Allow MCP bookmark access'),
                      SizedBox(height: 2),
                      Text(
                        'Reserved for future bookmark tools. Toggle has no '
                        'effect today.',
                        style: TextStyle(fontSize: 12),
                      ),
                    ],
                  ),
                ),
                FSwitch(
                  key: SettingsPageKeys.mcpBookmarkSwitch,
                  value: settings.scopeBookmark,
                  // Disabled until bookmarks ship — but persisted shape stays
                  // stable so the toggle row doesn't shift when it lands.
                  onChange: null,
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              FButton(
                key: SettingsPageKeys.mcpClearAuditButton,
                variant: FButtonVariant.outline,
                onPress: () => _confirmClearAudit(context, ref),
                prefix: const Icon(FIcons.eraser),
                child: const Text('Clear MCP audit log'),
              ),
            ],
          ),
          const SizedBox(height: 8),
          auditAsync.when(
            loading: () => const SizedBox.shrink(),
            error: (e, st) => Text(
              'Audit log status: $e',
              key: SettingsPageKeys.mcpUserDbNotice,
              style: small,
            ),
            data: (state) {
              if (state.health == UserDbHealth.failed) {
                return Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text(
                    'MCP audit log unavailable — restart the app or check '
                    'disk permissions. The Quran reader and audio player are '
                    'unaffected.',
                    key: SettingsPageKeys.mcpUserDbNotice,
                    style: small,
                  ),
                );
              }
              return const SizedBox.shrink();
            },
          ),
        ],
      ),
    );
  }

  Future<void> _confirmClearAudit(BuildContext context, WidgetRef ref) async {
    final repo = ref.read(auditLogRepositoryProvider);
    if (repo == null) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => FDialog(
        title: const Text('Clear MCP audit log?'),
        body: const Text(
          'This deletes every recorded MCP tool call. Cannot be undone.',
        ),
        actions: [
          FButton(
            variant: FButtonVariant.outline,
            onPress: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Cancel'),
          ),
          FButton(
            onPress: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Clear'),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      await repo.clear();
    }
  }
}

class _AudioAttributionSection extends StatelessWidget {
  const _AudioAttributionSection();

  @override
  Widget build(BuildContext context) {
    final small = context.theme.typography.sm;
    final reciter = QuranComAudioSource.defaultReciter;
    final source = QuranComAudioSource.attribution;
    return Container(
      key: SettingsPageKeys.audioSection,
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.only(bottom: 8),
            child: Text(
              'Audio source',
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
            ),
          ),
          Text(
            source.providerName,
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 2),
          Text(
            'Default reciter: ${reciter.name} (${reciter.style})',
            style: small,
          ),
          Text(source.terms, style: small),
          Text(source.providerUrl, style: small),
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

class _TafsirSourceSection extends ConsumerWidget {
  const _TafsirSourceSection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(tafsirSourceProvider);
    return Container(
      key: SettingsPageKeys.tafsirSection,
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.only(bottom: 8),
            child: Text(
              'Tafsir source',
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
              Ok(:final value) => _TafsirSourceCard(source: value),
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

class _TafsirSourceCard extends StatelessWidget {
  const _TafsirSourceCard({required this.source});

  final TafsirSource source;

  @override
  Widget build(BuildContext context) {
    final smallStyle = context.theme.typography.sm;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          source.name,
          key: SettingsPageKeys.tafsirName,
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 2),
        Text(
          source.publisher,
          key: SettingsPageKeys.tafsirPublisher,
          style: smallStyle,
        ),
        Text(
          'Version ${source.version}',
          key: SettingsPageKeys.tafsirVersion,
          style: smallStyle,
        ),
        const SizedBox(height: 4),
        Text(
          source.license,
          key: SettingsPageKeys.tafsirLicense,
          style: smallStyle,
        ),
        const SizedBox(height: 4),
        Text(source.url, key: SettingsPageKeys.tafsirUrl, style: smallStyle),
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
