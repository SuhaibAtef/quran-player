import 'dart:typed_data';

/// Returns a copy of [fontBytes] with `CPAL` palette [paletteIndex] moved into
/// palette slot 0, so Flutter's text engine (which renders palette 0 only)
/// displays the chosen palette.
///
/// Mirrors `selectCpalPalette` in the `tarteel_qul` package — kept as a small
/// independent host copy so the host's header-font registrar
/// ([mushaf_fonts.dart]) does not have to import the rendering package, which
/// is confined to two files by the `mushaf-reader` import-boundary rule.
///
/// The bytes are returned unchanged when [paletteIndex] is 0 or negative, the
/// font carries no `CPAL` table, or the index is out of range.
Uint8List selectCpalPalette(Uint8List fontBytes, int paletteIndex) {
  if (paletteIndex <= 0 || fontBytes.length < 12) return fontBytes;
  final data = ByteData.sublistView(fontBytes);
  final numTables = data.getUint16(4);

  var cpalOffset = -1;
  for (var i = 0; i < numTables; i++) {
    final record = 12 + i * 16;
    if (record + 16 > fontBytes.length) break;
    final tag = String.fromCharCodes(fontBytes, record, record + 4);
    if (tag == 'CPAL') {
      cpalOffset = data.getUint32(record + 8);
      break;
    }
  }
  if (cpalOffset < 0 || cpalOffset + 12 > fontBytes.length) return fontBytes;

  final numPalettes = data.getUint16(cpalOffset + 4);
  if (paletteIndex >= numPalettes) return fontBytes;

  final slot0 = cpalOffset + 12;
  final slotN = cpalOffset + 12 + paletteIndex * 2;
  if (slotN + 2 > fontBytes.length) return fontBytes;

  final out = Uint8List.fromList(fontBytes);
  final outData = ByteData.sublistView(out);
  final atZero = outData.getUint16(slot0);
  final atN = outData.getUint16(slotN);
  outData.setUint16(slot0, atN);
  outData.setUint16(slotN, atZero);
  return out;
}
