# ForUI Reference Index

This index is for Quran Companion's current ForUI stack:

- `forui: ^0.21.3` in `pubspec.yaml`
- `forui_assets: 0.21.0` in `pubspec.lock`
- Local source: `%LOCALAPPDATA%\Pub\Cache\hosted\pub.dev\forui-0.21.3\lib\`
- Local icons: `%LOCALAPPDATA%\Pub\Cache\hosted\pub.dev\forui_assets-0.21.0\lib\src\assets.g.dart`

Use this file for fast orientation. For exact constructor arguments, open the
local source file listed by the `lib/forui.dart` barrel or the upstream
LLM docs linked from `SKILL.md`.

## Project Wiring

Quran Companion centralizes ForUI theme selection in
`lib/app/theme/app_theme.dart`:

```dart
static FThemeData get light => FThemes.zinc.light.desktop;
static FThemeData get dark => FThemes.zinc.dark.desktop;
```

`lib/app/app.dart` derives the Material themes from those ForUI desktop themes
and wraps routes in `FTheme` from `MaterialApp.router.builder`.

Do not hardcode `FThemes.zinc.*` in feature widgets. Read colors, typography,
spacing, and styles through `context.theme` or the project theme helper.

## Theme Variants

`FThemes.<variant>.<brightness>` returns `FPlatformThemeData`, not `FThemeData`.
Pick `.desktop` for this desktop app, or `.touch` only when a future mobile
target is intentionally reintroduced.

Available variants in ForUI 0.21.3:

- `FThemes.neutral.light.desktop` / `.touch`
- `FThemes.neutral.dark.desktop` / `.touch`
- `FThemes.zinc.light.desktop` / `.touch`
- `FThemes.zinc.dark.desktop` / `.touch`
- `FThemes.slate.light.desktop` / `.touch`
- `FThemes.slate.dark.desktop` / `.touch`
- `FThemes.blue.light.desktop` / `.touch`
- `FThemes.blue.dark.desktop` / `.touch`
- `FThemes.green.light.desktop` / `.touch`
- `FThemes.green.dark.desktop` / `.touch`
- `FThemes.orange.light.desktop` / `.touch`
- `FThemes.orange.dark.desktop` / `.touch`
- `FThemes.red.light.desktop` / `.touch`
- `FThemes.red.dark.desktop` / `.touch`
- `FThemes.rose.light.desktop` / `.touch`
- `FThemes.rose.dark.desktop` / `.touch`
- `FThemes.violet.light.desktop` / `.touch`
- `FThemes.violet.dark.desktop` / `.touch`
- `FThemes.yellow.light.desktop` / `.touch`
- `FThemes.yellow.dark.desktop` / `.touch`

## Public Barrel Exports

`package:forui/forui.dart` exports:

- Core: `assets.dart`, `foundation.dart`, `localizations.dart`, `theme.dart`
- Widgets: `accordion`, `autocomplete`, `alert`, `avatar`, `badge`,
  `bottom_navigation_bar`, `breadcrumb`, `button`, `calendar`, `card`,
  `checkbox`, `date_field`, `date_time_picker`, `dialog`, `divider`, `header`,
  `item`, `label`, `line_calendar`, `otp_field`, `pagination`, `picker`,
  `popover`, `popover_menu`, `progress`, `radio`, `resizable`, `scaffold`,
  `select`, `select_group`, `select_menu_tile`, `select_tile_group`, `sheet`,
  `sidebar`, `slider`, `toast`, `switch`, `tabs`, `text_field`, `tile`,
  `time_picker`, `time_field`, `tooltip`

## Widget Map

Prefer these before reaching for Material or Cupertino chrome:

- Layout: `FScaffold`, `FDivider`, `FResizable`
- Navigation: `FHeader`, `FBottomNavigationBar`, `FSidebar`, `FTabs`,
  `FBreadcrumb`, `FPagination`
- Actions: `FButton`, `FButton.raw`
- Form controls: `FTextField`, `FTextFormField`, `FOTPField`, `FAutocomplete`,
  `FCheckbox`, `FRadio`, `FSwitch`, `FSelect`, `FSelectGroup`, `FMultiSelect`,
  `FPicker`, `FSlider`, `FDateField`, `FTimeField`, `FDateTimePicker`,
  `FTimePicker`, `FLabel`
- Data display: `FCard`, `FAvatar`, `FBadge`, `FAccordion`, `FCalendar`,
  `FLineCalendar`, `FItem`, `FItemGroup`
- Settings/list tiles: `FTile`, `FTileGroup`, `FSelectMenuTile`,
  `FSelectTileGroup`
- Overlays: `FDialog`, `FSheet`, `FPopover`, `FPopoverMenu`, `FTooltip`,
  `FTooltipGroup`, `FToaster`
- Feedback: `FAlert`, `FProgress`

## API Notes

- `FButton` styling uses `variant: FButtonVariant.primary | .outline |
  .secondary | .ghost | .destructive`. The old `FButtonStyle.primary()` style
  factories are not available at this pin.
- Use `prefix:` / `suffix:` on `FButton` for icons when the constructor offers
  them. Use `FButton.raw` only when the standard content slots are insufficient.
- ForUI localizations must stay registered on `MaterialApp.router` via
  `FLocalizations.localizationsDelegates` and `FLocalizations.supportedLocales`.
- `toApproximateMaterialTheme()` is for app chrome and third-party widgets. It
  is not a reason to use Material buttons, switches, cards, tabs, dialogs, or
  navigation bars when ForUI has an equivalent.
- Per-widget style overrides use the widget's generated `*StyleDelta` shape.
  For larger style work, prefer `dart run forui style create <widget>` and keep
  the generated style in a narrow, reviewed surface.

## Icons

ForUI's icon data lives in `package:forui_assets`, re-exported through
`package:forui/forui.dart` as `FIcons`. Use `FIcons.<name>` in ForUI controls.

Curated icons verified in `forui_assets-0.21.0`:

- Navigation/app: `house`, `search`, `bookmark`, `settings`, `plug`, `list`,
  `panelLeft`, `panelRight`
- Reader: `bookOpen`, `chevronLeft`, `chevronRight`
- Feedback/theme: `triangleAlert`, `sun`, `moon`, `monitor`
- Audio-ready names: `play`, `pause`, `square`, `skipBack`, `skipForward`,
  `volume2`

Lucide kebab-case names are converted to lowerCamelCase:

- `book-open` -> `FIcons.bookOpen`
- `triangle-alert` -> `FIcons.triangleAlert`
- `skip-forward` -> `FIcons.skipForward`
- `volume-2` -> `FIcons.volume2`

## Local Lookup

Useful local files:

- Theme variants:
  `%LOCALAPPDATA%\Pub\Cache\hosted\pub.dev\forui-0.21.3\lib\src\theme\themes.dart`
- Public exports:
  `%LOCALAPPDATA%\Pub\Cache\hosted\pub.dev\forui-0.21.3\lib\forui.dart`
- Icons:
  `%LOCALAPPDATA%\Pub\Cache\hosted\pub.dev\forui_assets-0.21.0\lib\src\assets.g.dart`

PowerShell examples:

```powershell
rg -n "class FButton|FButton\\(" "$env:LOCALAPPDATA\Pub\Cache\hosted\pub.dev\forui-0.21.3\lib"
rg -n "static const bookOpen\\b" "$env:LOCALAPPDATA\Pub\Cache\hosted\pub.dev\forui_assets-0.21.0\lib\src\assets.g.dart"
```
