import 'dart:typed_data';

import 'package:flutter/services.dart'
    show AssetBundle, ByteData, FontLoader, rootBundle;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/logging/logger.dart';
import 'cpal.dart';

/// Bundled QUL header-font assets — downloaded by a contributor into the
/// gitignored `assets/qul/` directory alongside the page fonts.
const String surahHeaderFontAsset =
    'assets/qul/surah_headers/QCF_SurahHeader_COLOR-Regular.ttf';
const String quranCommonFontAsset = 'assets/qul/juz_name_font/quran-common.ttf';

/// Font families the QUL header fonts register under. The surah-header font is
/// a `COLR` colour font; its dark variant is a `CPAL`-recoloured copy.
const String surahHeaderFamilyLight = 'qul_surah_header';
const String surahHeaderFamilyDark = 'qul_surah_header_dark';
const String quranCommonFamily = 'qul_common';

/// The bismillah glyph (U+FDFD) — render in [quranCommonFamily].
const String bismillahGlyph = '﷽';

/// Maps a surah number to the glyph string rendered in the surah-header font.
/// From the QUL `surah_headers/ligatures.json` (`surah-1`..`surah-114`).
const Map<int, String> _surahHeaderGlyphs = {
  1: 'ﱅ',
  2: 'ﱆ',
  3: 'ﱇ',
  4: 'ﱊ',
  5: 'ﱋ',
  6: 'ﱎ',
  7: 'ﱏ',
  8: 'ﱑ',
  9: 'ﱒ',
  10: 'ﱓ',
  11: 'ﱕ',
  12: 'ﱖ',
  13: 'ﱘ',
  14: 'ﱚ',
  15: 'ﱛ',
  16: 'ﱜ',
  17: 'ﱝ',
  18: 'ﱞ',
  19: 'ﱡ',
  20: 'ﱢ',
  21: 'ﱤ',
  22: 'ﭑ',
  23: 'ﭒ',
  24: 'ﭔ',
  25: 'ﭕ',
  26: 'ﭗ',
  27: 'ﭘ',
  28: 'ﭚ',
  29: 'ﭛ',
  30: 'ﭝ',
  31: 'ﭞ',
  32: 'ﭠ',
  33: 'ﭡ',
  34: 'ﭣ',
  35: 'ﭤ',
  36: 'ﭦ',
  37: 'ﭧ',
  38: 'ﭩ',
  39: 'ﭪ',
  40: 'ﭬ',
  41: 'ﭭ',
  42: 'ﭯ',
  43: 'ﭰ',
  44: 'ﭲ',
  45: 'ﭳ',
  46: 'ﭵ',
  47: 'ﭶ',
  48: 'ﭸ',
  49: 'ﭹ',
  50: 'ﭻ',
  51: 'ﭼ',
  52: 'ﭾ',
  53: 'ﭿ',
  54: 'ﮁ',
  55: 'ﮂ',
  56: 'ﮄ',
  57: 'ﮅ',
  58: 'ﮇ',
  59: 'ﮈ',
  60: 'ﮊ',
  61: 'ﮋ',
  62: 'ﮍ',
  63: 'ﮎ',
  64: 'ﮐ',
  65: 'ﮑ',
  66: 'ﮓ',
  67: 'ﮔ',
  68: 'ﮖ',
  69: 'ﮗ',
  70: 'ﮙ',
  71: 'ﮚ',
  72: 'ﮜ',
  73: 'ﮝ',
  74: 'ﮟ',
  75: 'ﮠ',
  76: 'ﮢ',
  77: 'ﮣ',
  78: 'ﮥ',
  79: 'ﮦ',
  80: 'ﮨ',
  81: 'ﮩ',
  82: 'ﮫ',
  83: 'ﮬ',
  84: 'ﮮ',
  85: 'ﮯ',
  86: 'ﮱ',
  87: '﮲',
  88: '﮴',
  89: '﮵',
  90: '﮷',
  91: '﮸',
  92: '﮺',
  93: '﮻',
  94: '﮽',
  95: '﮾',
  96: '﯀',
  97: '﯁',
  98: 'ﯓ',
  99: 'ﯔ',
  100: 'ﯖ',
  101: 'ﯗ',
  102: 'ﯙ',
  103: 'ﯚ',
  104: 'ﯜ',
  105: 'ﯝ',
  106: 'ﯟ',
  107: 'ﯠ',
  108: 'ﯢ',
  109: 'ﯣ',
  110: 'ﯥ',
  111: 'ﯦ',
  112: 'ﯨ',
  113: 'ﯩ',
  114: 'ﯫ',
};

/// The ornamental-header glyph for [surah] (1..114), or `null` if unknown.
String? surahHeaderGlyph(int surah) => _surahHeaderGlyphs[surah];

bool _registered = false;

/// Loads and registers the QUL surah-header and `quran-common` fonts once per
/// process. The surah-header `COLR` font is registered twice — a light
/// variant ([surahHeaderFamilyLight], palette 0) and a `CPAL`-recoloured dark
/// variant ([surahHeaderFamilyDark], palette 1).
///
/// Returns `false` on any failure (missing assets, parse error). The reader
/// and the Surahs list branch on the result and fall back to plain text
/// headers — a header-font failure never breaks the reader.
Future<bool> loadMushafHeaderFonts([AssetBundle? bundle]) async {
  if (_registered) return true;
  final assets = bundle ?? rootBundle;
  try {
    final header = await _loadAsset(assets, surahHeaderFontAsset);
    final common = await _loadAsset(assets, quranCommonFontAsset);

    await _register(surahHeaderFamilyLight, header);
    await _register(surahHeaderFamilyDark, selectCpalPalette(header, 1));
    await _register(quranCommonFamily, common);

    _registered = true;
    return true;
  } catch (e, st) {
    appLogger.warning('QUL header fonts failed to load: $e', e, st);
    return false;
  }
}

Future<Uint8List> _loadAsset(AssetBundle bundle, String path) async {
  final ByteData data = await bundle.load(path);
  return data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes);
}

Future<void> _register(String family, Uint8List bytes) {
  return (FontLoader(
    family,
  )..addFont(Future<ByteData>.value(ByteData.sublistView(bytes)))).load();
}

/// Registers the QUL header fonts once per launch, lazily. `false` means the
/// fonts are unavailable and consumers should fall back to plain text.
final mushafHeaderFontsProvider = FutureProvider<bool>(
  (ref) => loadMushafHeaderFonts(),
);
