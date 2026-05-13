@TestOn('vm')
library;

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// `qcf_quran_plus` is a rendering-only dependency. At most two files in the
/// project may import it: the locator implementation (coordinate
/// translation) and the page-mode reader widget (rendering). Every other
/// layer goes through the framework-free [MushafLocator] contract.
const _allowedRelativePaths = <String>[
  'lib/data/quran/mushaf_locator_qcf.dart',
  'lib/features/reader/widgets/page_mushaf_view.dart',
];

const _watchedDirs = <String>['lib'];

bool _isAllowed(String relative) {
  for (final allowed in _allowedRelativePaths) {
    if (relative.endsWith(allowed)) return true;
  }
  return false;
}

void main() {
  test('only the locator and page-mode widget import qcf_quran_plus', () {
    final offenders = <String>[];
    for (final dir in _watchedDirs) {
      for (final entity in Directory(dir).listSync(recursive: true)) {
        if (entity is! File || !entity.path.endsWith('.dart')) continue;
        final relative = entity.path.replaceAll('\\', '/');
        final content = entity.readAsStringSync();
        final importsQcf =
            content.contains("import 'package:qcf_quran_plus/") ||
            content.contains('import "package:qcf_quran_plus/');
        if (importsQcf && !_isAllowed(relative)) {
          offenders.add(relative);
        }
      }
    }
    expect(
      offenders,
      isEmpty,
      reason:
          'qcf_quran_plus must be confined to ${_allowedRelativePaths.join(", ")}; '
          'offenders:\n${offenders.join("\n")}',
    );
  });
}
