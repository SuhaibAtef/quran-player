import 'package:flutter/material.dart' show ThemeMode;
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:forui/forui.dart';

import '../../app/state/theme_mode_provider.dart';

class SettingsPageKeys {
  const SettingsPageKeys._();

  static const title = Key('settings.title');
  static const themeSection = Key('settings.theme_section');
  static const themeOptionLight = Key('settings.theme.light');
  static const themeOptionDark = Key('settings.theme.dark');
  static const themeOptionSystem = Key('settings.theme.system');
  static const darkOnlyMarker = Key('settings.dark_only_marker');
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
          if (brightness == Brightness.dark)
            const SizedBox(key: SettingsPageKeys.darkOnlyMarker, height: 1),
        ],
      ),
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
