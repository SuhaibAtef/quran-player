# ForUI quick index

Companion to [SKILL.md](SKILL.md). Read SKILL.md first — it has the *opinions* (project pin, theme choice, when to fall back to Material). This file is the *reference data* — names, constructors, icon list — so an agent can answer "does X exist in 0.17.0?" without grepping the package cache or hitting the network.

Pinned at `forui: ^0.17.0` and `forui_assets: ^0.17.1`. If the pubspec is bumped, regenerate this file or it will lie.

## Theme variants

`FThemes` is a `Never`-extension that exposes nine palettes, each a record with `.light` and `.dark` `FThemeData` fields. Use one consistently — the project uses `zinc`.

| Variant | `FThemes.<name>` |
|---|---|
| zinc *(project default)* | `FThemes.zinc.light` / `FThemes.zinc.dark` |
| slate | `FThemes.slate.light` / `FThemes.slate.dark` |
| red | `FThemes.red.light` / `FThemes.red.dark` |
| rose | `FThemes.rose.light` / `FThemes.rose.dark` |
| orange | `FThemes.orange.light` / `FThemes.orange.dark` |
| green | `FThemes.green.light` / `FThemes.green.dark` |
| blue | `FThemes.blue.light` / `FThemes.blue.dark` |
| yellow | `FThemes.yellow.light` / `FThemes.yellow.dark` |
| violet | `FThemes.violet.light` / `FThemes.violet.dark` |

There is **no** `.touch` / `.desktop` factory in 0.17. (SKILL.md mentions one for newer ForUI; it doesn't exist yet at this pin.)

Brightness is **not** auto-resolved — `FTheme(data: ...)` takes a single concrete `FThemeData`. To honour `ThemeMode.system` you must read `MediaQuery.platformBrightnessOf(context)` yourself and pass the right variant. See [`lib/app/theme/app_theme.dart`](../../../lib/app/theme/app_theme.dart) for the project's resolver and [`lib/app/app.dart`](../../../lib/app/app.dart) for how it's wired inside `MaterialApp.builder`.

## Widget cheat sheet

Every ForUI widget exported by `package:forui/forui.dart` in 0.17.0, grouped by where you'd reach for it. Pattern column lists the *common* required args plus the most useful named args; check the package source or [llms-full.txt](https://forui.dev/docs/llms-full.txt) for the complete signature.

### Page chrome

| Widget | When to reach for it | Pattern |
|---|---|---|
| `FScaffold` | Page shell. Always. | `FScaffold({required Widget child, Widget? header, Widget? sidebar, Widget? footer, bool childPad = true})` |
| `FHeader` | Top bar on root pages. | `FHeader({required Widget title, List<Widget>? suffixes})` |
| `FHeader.nested` | Top bar on nested pages (centered title, prefix for back). | `FHeader.nested({required Widget title, List<Widget>? prefixes, List<Widget>? suffixes})` |
| `FDivider` | Horizontal/vertical separator. | `FDivider({Axis axis = Axis.horizontal})` |
| `FResizable` | Split panes with draggable dividers. | `FResizable({required Axis axis, required List<FResizableRegion> children})` |

### Navigation

| Widget | When | Pattern |
|---|---|---|
| `FSidebar` | Desktop side nav (use as `FScaffold.sidebar`, or standalone in a `Row`). | `FSidebar({required List<Widget> children, Widget? header, Widget? footer})` |
| `FSidebarItem` | Item inside `FSidebar`. | `FSidebarItem({Widget? icon, Widget? label, bool selected, VoidCallback? onPress, List<Widget> children})` |
| `FBottomNavigationBar` | Phone-style tab bar (use as `FScaffold.footer`, or standalone in a `Column`). | `FBottomNavigationBar({required List<Widget> children, required int index, ValueChanged<int>? onChange})` |
| `FBottomNavigationBarItem` | Item inside `FBottomNavigationBar`. | `FBottomNavigationBarItem({required Widget icon, Widget? label})` |
| `FTabs` | In-page tabs. | `FTabs({required List<FTabEntry> children, FTabsController? controller})` |
| `FBreadcrumb` | Trail of locations. | `FBreadcrumb({required List<FBreadcrumbItem> children})` |
| `FPagination` | Page navigation for lists. | `FPagination({required FPaginationController controller})` |

### Forms

| Widget | When | Pattern |
|---|---|---|
| `FButton` | Default action button. | `FButton({required Widget child, VoidCallback? onPress, FButtonStyle Function(FButtonStyle)? style, Widget? prefix, Widget? suffix})` |
| `FButton.raw` | Button with full custom content. | `FButton.raw({required Widget child, VoidCallback? onPress})` |
| `FTextField` | Single-line text input. | `FTextField({TextEditingController? controller, String? hint, Widget? label})` |
| `FTextFormField` | Form-aware text input. | `FTextFormField({String? Function(String?)? validator, ...})` |
| `FOTPField` | One-time-password digit boxes. | `FOTPField({required int length, ValueChanged<String>? onChange})` |
| `FAutocomplete` | Text input with suggestion list. | `FAutocomplete<T>({required Iterable<T> Function(String) optionsBuilder, required Widget Function(BuildContext, T) optionBuilder})` |
| `FCheckbox` | Toggle. | `FCheckbox({required bool value, ValueChanged<bool>? onChange, Widget? label})` |
| `FRadio` | Single-choice toggle. | `FRadio<T>({required T value, required T groupValue, ValueChanged<T?>? onChange})` |
| `FSwitch` | Boolean switch (looks like iOS toggle). | `FSwitch({required bool value, ValueChanged<bool>? onChange, Widget? label})` |
| `FSelect` | Dropdown / combobox. | `FSelect<T>({required List<T> items, T? value, ValueChanged<T?>? onChange, Widget Function(T)? format})` |
| `FSelectGroup` | Group of radio/checkbox tiles for a single field. | `FSelectGroup<T>({required FSelectGroupController<T> control, required List<FSelectTile<T>> children})` |
| `FMultiSelect` | Multi-pick dropdown. | `FMultiSelect<T>({required List<T> items, required Set<T> values, ValueChanged<Set<T>>? onChange})` |
| `FPicker` | Wheel picker. | `FPicker({required List<FPickerWheel> children, FPickerController? controller})` |
| `FSlider` | Range/value slider. | `FSlider({required FSliderController controller})` |
| `FDateField` | Inline calendar input. | `FDateField({DateTime? value, ValueChanged<DateTime?>? onChange})` |
| `FTimeField` | Inline time input. | `FTimeField({FTimeFieldController? controller})` |
| `FDateTimePicker` | Combined date+time picker. | `FDateTimePicker({DateTime? value, ValueChanged<DateTime?>? onChange})` |
| `FTimePicker` | Standalone time picker. | `FTimePicker({DateTime? value, ValueChanged<DateTime?>? onChange})` |
| `FLabel` | Wraps an input with label + helper/error text. | `FLabel({required Widget child, Widget? label, Widget? description})` |

### Data presentation

| Widget | When | Pattern |
|---|---|---|
| `FCard` | Bordered container with optional header. | `FCard({required Widget child, Widget? title, Widget? subtitle})` |
| `FAvatar` | Circular user avatar. | `FAvatar({Widget? child, ImageProvider? image})` |
| `FBadge` | Small status pill. | `FBadge({required Widget child, FBadgeStyle Function(FBadgeStyle)? style})` |
| `FAccordion` | Collapsible sections. | `FAccordion({required List<FAccordionItem> children, FAccordionController? controller})` |
| `FCalendar` | Full calendar view. | `FCalendar({required FCalendarController controller})` |
| `FLineCalendar` | Single-row date selector. | `FLineCalendar({DateTime? value, ValueChanged<DateTime?>? onChange})` |
| `FItem` | List row with leading/trailing slots. | `FItem({Widget? prefix, required Widget title, Widget? subtitle, Widget? suffix, VoidCallback? onPress})` |
| `FItemGroup` | Group of `FItem`s with a shared label/description. | `FItemGroup({required List<FItem> children, Widget? label})` |

### Tile family (settings rows)

| Widget | When | Pattern |
|---|---|---|
| `FTile` | Settings-screen row. | `FTile({Widget? prefix, required Widget title, Widget? subtitle, Widget? details, Widget? suffix, VoidCallback? onPress})` |
| `FTileGroup` | Group of tiles with optional header label. | `FTileGroup({required List<FTile> children, Widget? label})` |
| `FSelectTile` | Tile with selectable state (used inside `FSelectTileGroup`). | `FSelectTile<T>({required Widget title, required T value, Widget? subtitle, Widget? suffix})` |
| `FSelectTileGroup` | Selectable list of tiles bound to a controller. | `FSelectTileGroup<T>({required List<FSelectTile<T>> children, FSelectGroupController<T>? control})` |
| `FSelectMenuTile` | Tile that opens a popover menu on tap. | `FSelectMenuTile<T>({required Widget title, required FSelectMenuTileMenu<T> menu})` |

### Overlays

| Widget | When | Pattern |
|---|---|---|
| `FDialog` | Modal dialog. | `showAdaptiveDialog(context: ..., builder: (_) => FDialog(...))` |
| `FSheet` | Bottom or side sheet. | `showFSheet(context: ..., builder: (_) => FSheet(...))` |
| `FPopover` | Anchored popover. | `FPopover({required FPopoverController controller, required Widget popoverBuilder, required Widget child})` |
| `FPopoverMenu` | Popover with menu items. | `FPopoverMenu({required List<FTile> menu, required Widget child})` |
| `FTooltip` | Hover/long-press tooltip. | `FTooltip({required String tipBuilder, required Widget child})` |
| `FToaster` | Toast host (wrap inside `MaterialApp.builder`). | `FToaster({required Widget child})` |

### Feedback

| Widget | When | Pattern |
|---|---|---|
| `FAlert` | Inline status alert. | `FAlert({required Widget title, Widget? subtitle, FAlertStyle Function(FAlertStyle)? style})` |
| `FProgress` | Linear progress bar. | `FProgress({double? value})` |

## Icons (`FIcons`)

`FIcons` is a class with **1666** static `IconData` members defined in **`forui_assets`** (not `forui`). Names are camelCase mirrors of [Lucide](https://lucide.dev/icons) icon slugs — `book-open` becomes `FIcons.bookOpen`, `circle-check` becomes `FIcons.circleCheck`. The slug-to-name conversion is mechanical: split on `-`, lower-case the first segment, capitalize each subsequent.

**Common naming gotchas at this version:**

- `circleCheck` ✅ — `checkCircle` ✗ (the project's first guess)
- `circleX` ✅ — `xCircle` ✗
- `circleAlert` ✅ — `alertCircle` ✗
- `circleArrowLeft` ✅ — `arrowCircleLeft` ✗

Pattern: when an icon is "thing inside a circle", the prefix is `circle*`, not `*Circle`.

### Source

- Generated file: `%LOCALAPPDATA%\Pub\Cache\hosted\pub.dev\forui_assets-0.17.1\lib\src\assets.g.dart` (Windows). On macOS/Linux: `~/.pub-cache/hosted/pub.dev/forui_assets-0.17.1/lib/src/assets.g.dart`.
- To check whether an icon exists by name without grepping: search the slug at <https://lucide.dev/icons>; if Lucide has it, ForUI does too.

### Curated subset for Quran Companion

Picked from `assets.g.dart` for the IDEA.md MVP feature areas. Use these names verbatim — they are confirmed present in 0.17.1.

**Reading / surahs**
`book` · `bookOpen` · `bookOpenText` · `bookText` · `bookHeart` · `bookCheck` · `bookmark` · `bookmarkCheck` · `bookmarkPlus` · `bookmarkMinus` · `bookmarkX` · `scrollText` · `pilcrow`

**Audio**
`play` · `pause` · `square` *(stop)* · `skipBack` · `skipForward` · `rewind` · `fastForward` · `repeat` · `repeat1` · `repeat2` · `shuffle` · `volume` · `volume1` · `volume2` · `volumeX` · `mic` · `headphones` · `music` · `music2` · `audioLines` · `audioWaveform`

**Search**
`search` · `searchSlash` · `searchX` · `bookSearch` · `filter` · `slidersHorizontal`

**App / nav**
`house` · `settings` · `settings2` · `userCog` · `info` · `circleHelp` · `chevronLeft` · `chevronRight` · `chevronUp` · `chevronDown` · `arrowLeft` · `arrowRight` · `arrowUpRight` · `menu` · `panelLeft` · `panelLeftOpen` · `panelLeftClose`

**MCP / connectivity**
`plug` · `plug2` · `plugZap` · `cable` · `network` · `unplug` · `wifi` · `wifiOff` · `serverCog`

**State / status**
`check` · `circleCheck` · `circleCheckBig` · `x` · `circleX` · `circleAlert` · `triangleAlert` · `circle` · `circleDot` · `circleSlash` · `loader` · `loaderCircle`

**Theme switcher**
`sun` · `moon` · `monitor` · `sunMoon`

**Misc UI**
`pencil` · `trash2` · `copy` · `share2` · `download` · `upload` · `plus` · `minus` · `ellipsis` · `ellipsisVertical` · `eye` · `eyeOff` · `lock` · `unlock` · `star` · `heart`

If you need an icon not on this list, search Lucide first and convert the slug. If still unsure, grep `assets.g.dart` directly — but it's almost always faster to check Lucide.

## Common pitfalls (cribbed from SKILL.md, kept here for one-stop scanning)

- **`FTheme` placement.** Put it inside `MaterialApp.builder`, never above `MaterialApp`. Overlays (dialogs, sheets, snack bars, pushed routes) live in a subtree rooted at `MaterialApp` — anything outside is invisible to them.
- **Brightness.** ForUI 0.17 doesn't read `MediaQuery.platformBrightnessOf` for you. `ThemeMode.system` must be resolved manually in the builder before passing `FThemeData` into `FTheme`.
- **`FLocalizations`.** Wire `FLocalizations.localizationsDelegates` and `supportedLocales` into `MaterialApp` or date/time pickers crash with locale errors at runtime.
- **Material vs ForUI.** `toApproximateMaterialTheme()` lets framework chrome (snack bars, third-party Material widgets) inherit close-enough styling, but it is *not* a license to keep using `ElevatedButton`/`Switch`/`AppBar` when ForUI has an equivalent.
- **Version pin.** `forui: ^0.17.0` is locked because 0.18+ requires Flutter 3.41+. Bumping ForUI requires bumping Flutter first.
- **`FButton(child: ..., onPress: ...)` formatting.** `dart format` collapses single-arg cases to one line. Don't fight it.
- **Style overrides.** `style:` is a `Style Function(Style)` callback — mutate the passed-in style with `copyWith`, don't construct one from scratch.

## When this index isn't enough

- **All ~60 widgets, every constructor:** [`forui.dev/docs/llms-full.txt`](https://forui.dev/docs/llms-full.txt) — concatenated full docs. Read once, cache the answer back into this file if a question comes up repeatedly.
- **Pages by URL:** [`forui.dev/docs/llms.txt`](https://forui.dev/docs/llms.txt) — small index of every page.
- **CLI to scaffold a custom style:** `dart run forui style create <widget>` (e.g. `scaffold`, `button`).
- **Source of truth at this pin:** the local cache under `%LOCALAPPDATA%\Pub\Cache\hosted\pub.dev\forui-0.17.0\lib\` — the public surface is `lib/forui.dart` (the barrel) and individual `lib/widgets/<name>.dart` re-exports.
