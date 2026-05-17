import 'package:flutter/material.dart' show ThemeMode, showDialog;
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:forui/forui.dart';

import '../../app/state/mcp_settings_provider.dart';
import '../../app/state/mushaf_color_scheme.dart';
import '../../app/state/reader_mode.dart';
import '../../app/state/reader_mode_provider.dart';
import '../../app/state/theme_mode_provider.dart';
import '../../app/state/user_db_provider.dart';
import '../../core/error/result.dart';
import '../../data/audio/quran_com_audio_source.dart';
import '../../data/quran/mushaf_locator_provider.dart';
import '../../domain/quran/quran_source.dart';
import '../../domain/tafsir/tafsir_source.dart';
import '../reader/widgets/page_mushaf_view.dart' show MushafStylePreview;
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
  static const appearanceSection = Key('settings.appearance_section');
  static const appearancePreview = Key('settings.appearance.preview');

  static Key appearanceOption(String schemeKey) =>
      ValueKey('settings.appearance.$schemeKey');
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
  static const mushafSection = Key('settings.mushaf_section');
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
      // A SingleChildScrollView + Column (not a lazy ListView) so every
      // section is mounted regardless of scroll position — keeps section
      // lookups stable as the page grows.
      child: SingleChildScrollView(
        key: SettingsPageKeys.list,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
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
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
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
            const _MushafAppearanceSection(),
            const SizedBox(height: 16),
            const _QuranSourceSection(),
            const SizedBox(height: 16),
            const _TafsirSourceSection(),
            const SizedBox(height: 16),
            const _AudioAttributionSection(),
            const SizedBox(height: 16),
            const _McpSection(),
            const SizedBox(height: 16),
            const _MushafAttributionSection(),
          ],
        ),
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
        ],
      ),
    );
  }
}

/// Mushaf colour-style picker — a live preview of a real verse (Sūrat
/// al-Fātiḥah, page 1) above every selectable QUL colour style. Replaces the
/// former tajweed toggle.
class _MushafAppearanceSection extends ConsumerWidget {
  const _MushafAppearanceSection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = ref.watch(mushafColorSchemeProvider);
    final controller = ref.read(mushafColorSchemeProvider.notifier);
    final engine = ref.watch(mushafEngineProvider).valueOrNull;
    final previewReady = engine != null && !engine.usingFallback;

    return Container(
      key: SettingsPageKeys.appearanceSection,
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.only(bottom: 8),
            child: Text(
              'Mushaf colours',
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
            ),
          ),
          ClipRRect(
            key: SettingsPageKeys.appearancePreview,
            borderRadius: BorderRadius.circular(8),
            child: SizedBox(
              height: 220,
              width: double.infinity,
              child: previewReady
                  ? MushafStylePreview(engine: engine)
                  : const _PreviewUnavailable(),
            ),
          ),
          const SizedBox(height: 12),
          for (final option in MushafColorScheme.values)
            _ReaderModeTile(
              optionKey: SettingsPageKeys.appearanceOption(option.storageKey),
              label: option.label,
              selected: scheme == option,
              onPress: () => controller.select(option),
            ),
        ],
      ),
    );
  }
}

/// Placeholder shown in the colour-style preview when the QUL engine is
/// unavailable (e.g. the QUL assets are missing).
class _PreviewUnavailable extends StatelessWidget {
  const _PreviewUnavailable();

  @override
  Widget build(BuildContext context) {
    return const ColoredBox(
      color: Color(0xFFEDE6D6),
      child: Center(
        child: Text(
          'Mushaf preview unavailable',
          style: TextStyle(fontSize: 12, color: Color(0xFF6B6B6B)),
        ),
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

class _MushafAttributionSection extends StatelessWidget {
  const _MushafAttributionSection();

  @override
  Widget build(BuildContext context) {
    final small = context.theme.typography.sm;
    return Container(
      key: SettingsPageKeys.mushafSection,
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.only(bottom: 8),
            child: Text(
              'Mushaf page rendering',
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
            ),
          ),
          const Text(
            'Tarteel QUL — QPC V4',
            style: TextStyle(fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 2),
          Text(
            'Mushaf page layout and word-by-word glyph script from the '
            'Tarteel Quran Universal Library (qul.tarteel.ai).',
            style: small,
          ),
          Text(
            'Rendered with KFGQPC (King Fahd Glorious Qur’an Printing '
            'Complex) V4 per-page fonts.',
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
