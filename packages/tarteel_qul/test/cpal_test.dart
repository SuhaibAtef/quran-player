import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
// `selectCpalPalette` is internal to the engine; the test reaches it directly.
import 'package:tarteel_qul/src/cpal.dart';

/// Builds a minimal sfnt buffer carrying just a `CPAL` table with the given
/// `colorRecordIndices`. Enough to exercise [selectCpalPalette]'s byte swap.
Uint8List _fontWithCpal(List<int> colorRecordIndices) {
  const cpalOffset = 28; // 12-byte sfnt header + one 16-byte table record
  final numPalettes = colorRecordIndices.length;
  const cpalHeaderLen = 12;
  final indicesLen = numPalettes * 2;
  const recordsLen = 6 * 4;
  final cpalLen = cpalHeaderLen + indicesLen + recordsLen;
  final bytes = Uint8List(cpalOffset + cpalLen);
  final data = ByteData.sublistView(bytes);

  data.setUint32(0, 0x00010000); // sfnt version
  data.setUint16(4, 1); // numTables
  bytes.setRange(12, 16, 'CPAL'.codeUnits);
  data.setUint32(12 + 8, cpalOffset);
  data.setUint32(12 + 12, cpalLen);

  // CPAL header: version@0, numPaletteEntries@2, numPalettes@4,
  // numColorRecords@6, offsetFirstColorRecord@8.
  data.setUint16(cpalOffset + 2, 2); // numPaletteEntries
  data.setUint16(cpalOffset + 4, numPalettes);
  data.setUint16(cpalOffset + 6, 6); // numColorRecords
  data.setUint32(cpalOffset + 8, cpalHeaderLen + indicesLen);
  for (var i = 0; i < numPalettes; i++) {
    data.setUint16(cpalOffset + 12 + i * 2, colorRecordIndices[i]);
  }
  return bytes;
}

List<int> _indices(Uint8List bytes, int numPalettes) {
  final data = ByteData.sublistView(bytes);
  final cpalOffset = data.getUint32(12 + 8);
  return [
    for (var i = 0; i < numPalettes; i++)
      data.getUint16(cpalOffset + 12 + i * 2),
  ];
}

void main() {
  test('selectCpalPalette swaps the chosen palette into slot 0', () {
    final out = selectCpalPalette(_fontWithCpal([0, 2, 4]), 1);
    expect(_indices(out, 3), [2, 0, 4]);
  });

  test('selectCpalPalette with index 2 swaps slot 0 and 2', () {
    final out = selectCpalPalette(_fontWithCpal([0, 2, 4]), 2);
    expect(_indices(out, 3), [4, 2, 0]);
  });

  test('palette 0 returns the bytes unchanged', () {
    final font = _fontWithCpal([0, 2, 4]);
    expect(identical(selectCpalPalette(font, 0), font), isTrue);
  });

  test('an out-of-range palette index returns the bytes unchanged', () {
    final out = selectCpalPalette(_fontWithCpal([0, 2, 4]), 9);
    expect(_indices(out, 3), [0, 2, 4]);
  });

  test('a font with no CPAL table is returned unchanged', () {
    final noCpal = Uint8List(12);
    ByteData.sublistView(noCpal).setUint16(4, 0);
    expect(identical(selectCpalPalette(noCpal, 1), noCpal), isTrue);
  });
}
