import 'package:flutter_test/flutter_test.dart';

import 'package:quran_player/core/l10n/display_number.dart';

void main() {
  group('localizedNumber', () {
    test('renders ASCII digits under English', () {
      expect(localizedNumber(0, 'en'), '0');
      expect(localizedNumber(7, 'en'), '7');
      expect(localizedNumber(255, 'en'), '255');
    });

    test('renders Eastern Arabic digits under Arabic', () {
      expect(localizedNumber(0, 'ar'), '٠');
      expect(localizedNumber(7, 'ar'), '٧');
      expect(localizedNumber(255, 'ar'), '٢٥٥');
    });
  });
}
