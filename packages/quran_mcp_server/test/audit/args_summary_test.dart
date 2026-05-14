import 'package:quran_mcp_server/src/audit/args_summary.dart';
import 'package:test/test.dart';

void main() {
  group('truncateForArgsSummary', () {
    test('returns short queries verbatim with no marker (R7 scenario 2)', () {
      final input = 'الله' * 10; // 40 codepoints, well under 128
      final result = truncateForArgsSummary(input);
      expect(result, equals(input));
      expect(result.contains('…[+'), isFalse);
    });

    test('returns exactly 128-codepoint queries verbatim with no marker', () {
      final input = 'a' * 128;
      final result = truncateForArgsSummary(input);
      expect(result, equals(input));
      expect(result.contains('…[+'), isFalse);
    });

    test(
      'truncates 200-codepoint queries to first 128 + …[+72 more] (R7 scenario 1)',
      () {
        final input = 'a' * 200;
        final result = truncateForArgsSummary(input);
        expect(result, equals('${'a' * 128}…[+72 more]'));
      },
    );

    test('counts codepoints (runes), not UTF-16 code units', () {
      // Each Arabic letter is one codepoint but two UTF-16 code units in some
      // measurements. Verify the helper uses runes.
      const arabicLetter = 'ع';
      final input = arabicLetter * 200;
      final result = truncateForArgsSummary(input);
      expect(result, startsWith(arabicLetter * 128));
      expect(result, endsWith('…[+72 more]'));
    });

    test('throws on non-positive maxCodepoints', () {
      expect(
        () => truncateForArgsSummary('x', maxCodepoints: 0),
        throwsArgumentError,
      );
      expect(
        () => truncateForArgsSummary('x', maxCodepoints: -1),
        throwsArgumentError,
      );
    });
  });
}
