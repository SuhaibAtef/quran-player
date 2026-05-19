import 'package:flutter/material.dart' show ThemeMode, showDialog;
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:forui/forui.dart';

import '../../app/state/locale_provider.dart';
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
import '../../l10n/app_localizations.dart';
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
  static const languageSection = Key('settings.language_section');
  static const languageOptionSystem = Key('settings.language.system');
  static const languageOptionEnglish = Key('settings.language.english');
  static const languageOptionArabic = Key('settings.language.arabic');
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
    final l10n = AppLocalizations.of(context);

    return FScaffold(
      header: FHeader(
        title: Text(l10n.settingsTitle, key: SettingsPageKeys.title),
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
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Text(
                      l10n.settingsThemeSection,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  _ThemeOptionTile(
                    optionKey: SettingsPageKeys.themeOptionSystem,
                    label: l10n.settingsThemeSystem,
                    selected: mode == ThemeMode.system,
                    onPress: () => controller.setMode(ThemeMode.system),
                  ),
                  _ThemeOptionTile(
                    optionKey: SettingsPageKeys.themeOptionLight,
                    label: l10n.settingsThemeLight,
                    selected: mode == ThemeMode.light,
                    onPress: () => controller.setMode(ThemeMode.light),
                  ),
                  _ThemeOptionTile(
                    optionKey: SettingsPageKeys.themeOptionDark,
                    label: l10n.settingsThemeDark,
                    selected: mode == ThemeMode.dark,
                    onPress: () => controller.setMode(ThemeMode.dark),
                  ),
                ],
              ),
            ),
            if (brightness == Brightness.dark)
              const SizedBox(key: SettingsPageKeys.darkOnlyMarker, height: 1),
            const SizedBox(height: 16),
            const _LanguageSection(),
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
    final l10n = AppLocalizations.of(context);

    return Container(
      key: SettingsPageKeys.mcpSection,
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Text(
              l10n.settingsMcpSection,
              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
            ),
          ),
          Text(l10n.settingsMcpDescription),
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Row(
              children: [
                Expanded(child: Text(l10n.settingsMcpEnable)),
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
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(l10n.settingsMcpPlaybackTitle),
                      const SizedBox(height: 2),
                      Text(
                        l10n.settingsMcpPlaybackDescription,
                        style: const TextStyle(fontSize: 12),
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
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(l10n.settingsMcpBookmarkTitle),
                      const SizedBox(height: 2),
                      Text(
                        l10n.settingsMcpBookmarkDescription,
                        style: const TextStyle(fontSize: 12),
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
                child: Text(l10n.settingsMcpClearAudit),
              ),
            ],
          ),
          const SizedBox(height: 8),
          auditAsync.when(
            loading: () => const SizedBox.shrink(),
            error: (e, st) => Text(
              l10n.settingsMcpAuditStatus('$e'),
              key: SettingsPageKeys.mcpUserDbNotice,
              style: small,
            ),
            data: (state) {
              if (state.health == UserDbHealth.failed) {
                return Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text(
                    l10n.settingsMcpAuditUnavailable,
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
    final l10n = AppLocalizations.of(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => FDialog(
        title: Text(l10n.settingsMcpClearAuditDialogTitle),
        body: Text(l10n.settingsMcpClearAuditDialogBody),
        actions: [
          FButton(
            variant: FButtonVariant.outline,
            onPress: () => Navigator.of(dialogContext).pop(false),
            child: Text(l10n.settingsCancel),
          ),
          FButton(
            onPress: () => Navigator.of(dialogContext).pop(true),
            child: Text(l10n.settingsClear),
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
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Text(
              AppLocalizations.of(context).settingsAudioSection,
              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
            ),
          ),
          Text(
            source.providerName,
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 2),
          Text(
            AppLocalizations.of(
              context,
            ).settingsAudioDefaultReciter(reciter.name, reciter.style),
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
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Text(
              AppLocalizations.of(context).settingsReaderSection,
              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
            ),
          ),
          _ReaderModeTile(
            optionKey: SettingsPageKeys.readerOptionPage,
            label: AppLocalizations.of(context).settingsReaderModePage,
            selected: mode == ReaderMode.page,
            onPress: () => controller.setMode(ReaderMode.page),
          ),
          _ReaderModeTile(
            optionKey: SettingsPageKeys.readerOptionText,
            label: AppLocalizations.of(context).settingsReaderModeText,
            selected: mode == ReaderMode.text,
            onPress: () => controller.setMode(ReaderMode.text),
          ),
        ],
      ),
    );
  }
}

/// Interface-language picker — System / English / العربية, persisted via
/// `localeProvider`. Mirrors the theme picker above it.
class _LanguageSection extends ConsumerWidget {
  const _LanguageSection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final option = ref.watch(localeProvider);
    final controller = ref.read(localeProvider.notifier);
    final l10n = AppLocalizations.of(context);

    return Container(
      key: SettingsPageKeys.languageSection,
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Text(
              l10n.settingsLanguageSection,
              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
            ),
          ),
          _ThemeOptionTile(
            optionKey: SettingsPageKeys.languageOptionSystem,
            label: l10n.settingsLanguageSystem,
            selected: option == AppLocaleOption.system,
            onPress: () => controller.setOption(AppLocaleOption.system),
          ),
          _ThemeOptionTile(
            optionKey: SettingsPageKeys.languageOptionEnglish,
            label: l10n.settingsLanguageEnglish,
            selected: option == AppLocaleOption.english,
            onPress: () => controller.setOption(AppLocaleOption.english),
          ),
          _ThemeOptionTile(
            optionKey: SettingsPageKeys.languageOptionArabic,
            label: l10n.settingsLanguageArabic,
            selected: option == AppLocaleOption.arabic,
            onPress: () => controller.setOption(AppLocaleOption.arabic),
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
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Text(
              AppLocalizations.of(context).settingsMushafColoursSection,
              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
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
    return ColoredBox(
      color: const Color(0xFFEDE6D6),
      child: Center(
        child: Text(
          AppLocalizations.of(context).settingsMushafPreviewUnavailable,
          style: const TextStyle(fontSize: 12, color: Color(0xFF6B6B6B)),
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
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Text(
              AppLocalizations.of(context).settingsMushafSection,
              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
            ),
          ),
          Text(
            AppLocalizations.of(context).settingsMushafProvider,
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 2),
          Text(
            AppLocalizations.of(context).settingsMushafDescription1,
            style: small,
          ),
          Text(
            AppLocalizations.of(context).settingsMushafDescription2,
            style: small,
          ),
          Text(
            AppLocalizations.of(context).settingsMushafDescription3,
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
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Text(
              AppLocalizations.of(context).settingsQuranSourceSection,
              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
            ),
          ),
          async.when(
            loading: () => const Padding(
              padding: EdgeInsets.symmetric(vertical: 8),
              child: FProgress(),
            ),
            error: (e, st) => Text(
              AppLocalizations.of(context).settingsAttributionLoadError('$e'),
            ),
            data: (result) => switch (result) {
              Ok(:final value) => _QuranSourceCard(source: value),
              Err(:final failure) => Text(
                AppLocalizations.of(
                  context,
                ).settingsAttributionLoadError(failure.message),
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
          AppLocalizations.of(context).settingsVersionLabel(source.version),
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
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Text(
              AppLocalizations.of(context).settingsTafsirSourceSection,
              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
            ),
          ),
          async.when(
            loading: () => const Padding(
              padding: EdgeInsets.symmetric(vertical: 8),
              child: FProgress(),
            ),
            error: (e, st) => Text(
              AppLocalizations.of(context).settingsAttributionLoadError('$e'),
            ),
            data: (result) => switch (result) {
              Ok(:final value) => _TafsirSourceCard(source: value),
              Err(:final failure) => Text(
                AppLocalizations.of(
                  context,
                ).settingsAttributionLoadError(failure.message),
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
          AppLocalizations.of(context).settingsVersionLabel(source.version),
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
