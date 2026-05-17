/// A Flutter rendering engine for Tarteel QUL printed-mushaf data.
///
/// The engine bundles no QUL data. A consumer supplies the QUL layout
/// database, word-script database, and per-page fonts through a
/// [MushafAssetSource]; the engine parses them into typed [MushafPage] models,
/// exposes a page↔ayah coordinate API on [MushafLayoutRepository], and renders
/// pages through the mode-agnostic [MushafView] widget driven by a
/// [MushafController].
library;

export 'src/asset_source.dart';
export 'src/ayah_key.dart';
export 'src/controller.dart';
export 'src/decoration.dart';
export 'src/layout_repository.dart';
export 'src/models.dart';
export 'src/result.dart';
export 'src/view.dart';
