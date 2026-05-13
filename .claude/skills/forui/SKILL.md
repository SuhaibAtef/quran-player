---
name: forui
description: >-
  ForUI Flutter widget library - the project's chosen UI toolkit. Use whenever building or editing Flutter UI in this repo: picking a widget (button, scaffold, header, dialog, sheet, tabs, navigation, form input, calendar, list/settings rows, etc.), wiring app-level theming, switching light/dark, adding a new screen or route, fixing ForUI layout/theming issues, or considering whether to reach for Material / Cupertino primitives. Trigger this skill even when the user just describes UI work (add a settings page, show a list of surahs, I want a tab bar) without saying ForUI - the project standard is ForUI-first, so the right answer almost always lives here. Do not hand-roll widgets or fall back to Material/Cupertino when a ForUI equivalent exists.
user-invocable: true
---

# ForUI

ForUI is the project's UI library ([forui.dev](https://forui.dev/docs)). It ships ~60 shadcn-inspired widgets covering layout, forms, navigation, data presentation, overlays, and feedback.

This skill captures the wiring, conventions, and gotchas specific to **this project** plus a map for finding upstream docs fast. When in doubt, consult the canonical docs — see [Authoritative references](#authoritative-references). Current quick-reference data for the pinned package lives in [INDEX.md](INDEX.md).

## Project-specific constraints

These are the rules that apply *to this repo*. Don't deviate without an explicit reason.

| Constraint | Value | Why |
|---|---|---|
| Pinned version | `forui: ^0.21.3` ([pubspec.yaml](../../../pubspec.yaml#L37)) | Current project pin after the mushaf-reader change. Future bumps may include breaking API changes; centralize ForUI usage in app theme/shell code where practical. |
| Theme | `FThemes.zinc.light.desktop` ([lib/app/theme/app_theme.dart](../../../lib/app/theme/app_theme.dart)) | Project default. `FThemes.zinc.light` returns platform theme data at this pin; the desktop app resolves `.desktop`. Centralize theme changes — don't hardcode `FThemes.*` in individual widgets. |
| Material fallback | Material theme derived from the resolved ForUI desktop theme | Lets non-ForUI widgets (`MaterialApp` chrome, third-party Material widgets) inherit close-enough styling. |
| Localizations | `FLocalizations.localizationsDelegates` + `supportedLocales` registered on `MaterialApp` | Required for ForUI widgets that surface user-facing strings (date pickers, etc.). |
| Widget choice | Prefer ForUI components over hand-rolled widgets and over `material`/`cupertino` primitives where a ForUI equivalent exists ([AGENTS.md](../../../AGENTS.md)). | Consistent design language; cheap to re-skin later. |

If you find yourself reaching for `Scaffold`, `AppBar`, `ElevatedButton`, `TextButton`, `IconButton`, `Drawer`, `BottomNavigationBar`, `TabBar`, `Card`, `AlertDialog`, `BottomSheet`, `Switch`, `Checkbox`, `Radio`, `Slider`, `TextField`, etc. — stop and check the ForUI equivalent first.

### When Material/Cupertino primitives are still appropriate

The "ForUI-first" rule is about **styled** widgets — components that carry a visual identity. Plenty of Flutter framework primitives are unstyled or structural and stay in play:

- **Layout primitives** that don't have a ForUI counterpart: `Row`, `Column`, `Stack`, `Padding`, `Align`, `Center`, `Expanded`, `Flexible`, `SizedBox`, `ConstrainedBox`, `LayoutBuilder`, `SafeArea`, `MediaQuery`.
- **Scrolling/list primitives**: `ListView`, `GridView`, `CustomScrollView`, `Sliver*` — wrap their *children* in ForUI widgets, but the scrolling machinery is fine.
- **Text and gestures**: `Text`, `RichText`, `GestureDetector`, `InkWell` (only if you actually want a ripple — otherwise prefer ForUI's interactive widgets).
- **Routing/Navigation infrastructure**: `Navigator`, `MaterialPageRoute`, `Hero`, `PageView`. ForUI is widget-level, not routing-level.
- **Third-party packages** that ship Material widgets internally — leave them alone, the `toApproximateMaterialTheme` hand-off keeps them visually close.
- **Material-only behaviors with no ForUI replacement yet** in 0.21 (e.g. specific platform haptics) — use the Material widget and leave a comment so we revisit when ForUI grows the equivalent.

Rule of thumb: if the framework primitive has *no* visible chrome or you're using it to compose ForUI widgets together, use it. If it has chrome you can see (border, fill, shadow, ripple, typography), prefer ForUI.

## Canonical app wiring

The app shell is set up in [lib/app/app.dart](../../../lib/app/app.dart), with the concrete theme in [lib/app/theme/app_theme.dart](../../../lib/app/theme/app_theme.dart). Match this pattern when adding new entry points (e.g. integration test harnesses):

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:forui/forui.dart';

import 'app/router/app_router.dart';
import 'app/state/theme_mode_provider.dart';
import 'app/theme/app_theme.dart';

class QuranPlayerApp extends ConsumerWidget {
  const QuranPlayerApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final mode = ref.watch(themeModeProvider);
    final router = ref.watch(appRouterProvider);

    return MaterialApp.router(
      title: 'Quran Companion',
      debugShowCheckedModeBanner: false,
      themeMode: mode,
      theme: AppTheme.light.toApproximateMaterialTheme(),
      darkTheme: AppTheme.dark.toApproximateMaterialTheme(),
      localizationsDelegates: FLocalizations.localizationsDelegates,
      supportedLocales: FLocalizations.supportedLocales,
      builder: (context, child) {
        final platformBrightness = MediaQuery.platformBrightnessOf(context);
        final theme = AppTheme.resolve(mode, platformBrightness);
        return FTheme(data: theme, child: child!);
      },
      routerConfig: router,
    );
  }
}
```

Place `FTheme` inside `builder`, not above `MaterialApp`. The reason: `Navigator` pushes routes (dialogs, sheets, snack bars, full-screen pages) into a subtree rooted at `MaterialApp`, so any inherited widget — including `FTheme` — placed *outside* `MaterialApp` won't be visible to those overlays. The `builder` slot wraps every route, so it's the only place that reaches both the home widget and pushed routes.

## Page skeleton

Every page should use `FScaffold`. The minimum:

```dart
FScaffold(
  header: const FHeader(title: Text('Page title')),
  child: const Center(child: Text('Body')),
)
```

- `FHeader` for root pages (title left-aligned, suffix actions on the right).
- `FHeader.nested` for non-root pages (centered title, prefixes for back, suffixes for actions).
- `footer:` is for `FBottomNavigationBar` or persistent action bars — it's fixed at the bottom of the scaffold.
- `sidebar:` for desktop side nav. Pair with [responsive guidance](#responsive--platform-controls) so phones still get bottom-nav.
- `childPad: false` if you want to draw to the edges (e.g. a full-bleed list); otherwise leave the default page padding.

## Theming

- **Brightness is resolved by app state.** Unlike `ThemeData`'s `brightness: Brightness.system`, ForUI does not read `MediaQuery.platformBrightnessOf` for you — `FTheme(data: …)` takes a single concrete theme. Quran Companion stores the selected `ThemeMode` in `themeModeProvider`, then `AppTheme.resolve()` chooses `FThemes.zinc.light.desktop` or `FThemes.zinc.dark.desktop` for `FTheme`.
- **Touch vs desktop variants.** Each preset has `.touch` (mobile) and `.desktop` (mouse) variants with different font sizes / paddings. This desktop app resolves `.desktop`; if a widget feels too tight or too loose for a future platform, compare the touch/desktop variants deliberately.
- **Customize via `copyWith`** on `FThemeData` rather than building a theme from scratch. Keep all theme overrides in one place so the swap stays cheap (per [AGENTS.md](../../../AGENTS.md)).
- **Per-widget style overrides** use the widget's `style:` parameter, usually a generated `*StyleDelta`. Most widgets also expose a CLI to scaffold a custom style (`dart run forui style create <widget>`).

## Widget map

Reach for these instead of Material/Cupertino. URLs are `https://forui.dev/docs/<path>`.

### Layout — `layout/*`
- `FScaffold` — page shell. *Always use this.*
- `FDivider` — horizontal/vertical separator.
- `FResizable` — split panes with draggable dividers (good for desktop player + reader views).

### Navigation — `navigation/*`
- `FHeader` / `FHeader.nested` — top bar.
- `FBottomNavigationBar` — phone-style tab bar (use as `FScaffold.footer`).
- `FSidebar` — desktop side nav (use as `FScaffold.sidebar`).
- `FTabs` — in-page tabs.
- `FBreadcrumb`, `FPagination` — secondary navigation.

### Form — `form/*`
- `FButton` (default factory: `child` + `onPress`; also `prefix`/`suffix` for icons; `FButton.raw` for full custom content).
- `FTextField`, `FTextFormField`, `FOTPField`, `FAutocomplete`.
- `FCheckbox`, `FRadio`, `FSwitch`, `FSelectGroup`, `FMultiSelect`.
- `FSelect`, `FPicker`, `FSlider`.
- `FDateField`, `FTimeField`, `FDateTimePicker`, `FTimePicker`.
- `FLabel` — paired label + helper/error text wrapper.

### Data presentation — `data/*`
- `FCard`, `FAvatar`, `FBadge`.
- `FAccordion` — collapsible sections.
- `FCalendar`, `FLineCalendar`.
- `FItem`, `FItemGroup` — list rows (good for a surah list).

### Tile — `tile/*`
- `FTile`, `FTileGroup`, `FSelectMenuTile`, `FSelectTileGroup` — settings-screen rows with leading/trailing widgets.

### Overlay — `overlay/*`
- `FDialog` — modal dialog.
- `FSheet` — bottom/side sheet.
- `FPopover`, `FPopoverMenu` — anchored popovers.
- `FTooltip` — wrap with `FTooltipGroup` near the app root if you use them.
- `FToaster` — toast host. Wrap inside `builder` like `FToaster(child: FTooltipGroup(child: child!))` if you adopt toasts/tooltips later.

### Feedback — `feedback/*`
- `FAlert`, `FProgress`.

### Foundation — `foundation/*`
- Low-level primitives. Rarely needed unless building a custom widget; check before you hand-roll one.

### Icons — `reference/icon-library`
- Use `FIcons.<name>` (Lucide). Examples: `FIcons.house`, `FIcons.search`, `FIcons.settings`, `FIcons.play`, `FIcons.pause`. Material `Icons.*` works through `toApproximateMaterialTheme` but for consistency with the design language, prefer `FIcons` inside ForUI widgets.

## Responsive / platform controls

ForUI doesn't auto-switch between `FBottomNavigationBar` and `FSidebar` for you. Use `LayoutBuilder` (see the `flutter-build-responsive-layout` skill) and pick the right scaffold slot at build time:

- Width ≥ 600 (or whichever breakpoint we settle on): pass `sidebar:` with `FSidebar`, drop the bottom bar.
- Below: omit `sidebar:`, pass `footer: FBottomNavigationBar(...)`.

## Controls (controllers vs. lifted state)

Most ForUI inputs accept either a managed controller (widget owns state) or a "lifted" pattern (you own state and pass values down). Default to **managed with internal controller** for prototyping, switch to lifted when you need to sync with a state-management library (Riverpod, Bloc, etc.) or programmatically trigger UI (e.g. open a popover from outside). See https://forui.dev/docs/concepts/controls.

## Common pitfalls

- `FTheme` placed at the root instead of inside `builder` ⇒ overlays unstyled.
- Forgetting `FLocalizations.localizationsDelegates` ⇒ runtime errors in date/time pickers.
- Mixing `Material` widgets where ForUI has an equivalent ⇒ inconsistent look. The `toApproximateMaterialTheme()` is for *third-party* / framework chrome, not an excuse to keep using `ElevatedButton`.
- Future ForUI bumps can include breaking API changes. Keep theme and shell wiring centralized, and re-run analyze/tests after any bump.
- Hardcoding `FThemes.zinc.light` outside of one place ⇒ painful to swap themes later. Read the active theme via `context.theme` instead (`FThemeData` is exposed through an inherited widget by `FTheme`).
- `dart format` will reformat single-arg `FButton(child: ..., onPress: ...)` to one line. Don't fight it.

## Authoritative references

When this skill doesn't answer the question, escalate in this order — local first, network last:

- **[INDEX.md](INDEX.md)** *(local — try first)* — every theme variant, every public widget's constructor pattern, the location of `FIcons` (forui_assets, not forui), curated icon list, and naming-gotcha cheatsheet at the pinned version. Avoids cache-grep and network calls for the questions that come up every session.

When INDEX.md isn't enough, ForUI maintains LLM-friendly docs:

- **Index (small)** — https://forui.dev/docs/llms.txt — list of every page with title + URL.
- **Full docs (large)** — https://forui.dev/docs/llms-full.txt — every page concatenated as Markdown. Prefer this when you need exact API for a specific widget (e.g. all `FCalendar` props).
- **Topical docs**:
  - Getting started: https://forui.dev/docs/getting-started
  - Themes: https://forui.dev/docs/concepts/themes
  - Controls: https://forui.dev/docs/concepts/controls
  - Localization: https://forui.dev/docs/concepts/localization
  - Responsive: https://forui.dev/docs/concepts/responsive
  - Icons: https://forui.dev/docs/reference/icon-library
  - CLI (style scaffolds): https://forui.dev/docs/reference/cli
  - Per-widget pages: `https://forui.dev/docs/<category>/<widget>` — e.g. `/docs/layout/scaffold`, `/docs/form/button`, `/docs/navigation/header`.

Local source is also available — when reading the docs is overkill, grep the cached package directly:

```
%LOCALAPPDATA%\Pub\Cache\hosted\pub.dev\forui-0.21.3\lib\
```

The `lib/forui.dart` barrel lists every public widget; each `lib/widgets/<name>.dart` re-exports `lib/src/widgets/<name>.dart` where the implementation and docstring live.

## Workflow when adding ForUI to a new screen

- [ ] Identify the closest ForUI widget for each piece of UI (use the [Widget map](#widget-map)). If unsure, fetch `https://forui.dev/docs/llms.txt` and pick.
- [ ] If you can't find one, fetch `https://forui.dev/docs/llms-full.txt` and search before hand-rolling.
- [ ] Wrap the screen in `FScaffold` with appropriate `header` / `footer` / `sidebar`.
- [ ] Use `context.theme` for any color/spacing instead of hardcoded values.
- [ ] Use `FIcons.*` for iconography.
- [ ] Run `just check` — `dart format` + `flutter analyze` + `flutter test` must all pass.
- [ ] If new user-facing strings appear in a date/time/calendar widget, confirm `FLocalizations` is still wired into the entry point.
