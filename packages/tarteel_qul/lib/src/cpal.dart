import 'dart:typed_data';

/// Returns a copy of [fontBytes] with `CPAL` palette [paletteIndex] moved into
/// palette slot 0.
///
/// Flutter's text engine renders a colour font using palette 0 only — it
/// exposes no runtime palette selection. Swapping the two entries of the
/// `CPAL` `colorRecordIndices` array (a list of `uint16`s, one per palette)
/// makes "palette 0" point at the chosen palette's colour records, so the
/// engine displays it.
///
/// The bytes are returned unchanged when [paletteIndex] is 0 or negative, the
/// font carries no `CPAL` table, or the index is out of range. Table
/// checksums are intentionally not recomputed — sfnt loaders do not validate
/// them, and `CPAL` is not covered by `head.checkSumAdjustment`.
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

  // colorRecordIndices[] — one uint16 per palette — starts at cpalOffset + 12
  // in both CPAL v0 and v1.
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
