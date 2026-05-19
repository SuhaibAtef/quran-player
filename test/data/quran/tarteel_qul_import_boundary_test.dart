@TestOn('vm')
library;

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// `package:tarteel_qul/` is the printed-mushaf rendering engine. At most two
/// host files may import it: the engine adapter (the `MushafAssetSource`
/// implementation + the `MushafLocator` coordinate translation) and the
/// page-mode reader widget (rendering). Every other layer drives the
/// printed-mushaf coordinate system through the framework-free `MushafLocator`
/// contract and the opaque `MushafEngine` handle.
const _allowedRelativePaths = <String>[
  'lib/data/quran/mushaf_engine.dart',
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
  test('only the engine adapter and page-mode widget import tarteel_qul', () {
    final offenders = <String>[];
    for (final dir in _watchedDirs) {
      for (final entity in Directory(dir).listSync(recursive: true)) {
        if (entity is! File || !entity.path.endsWith('.dart')) continue;
        final relative = entity.path.replaceAll('\\', '/');
        final content = entity.readAsStringSync();
        final importsEngine =
            content.contains("import 'package:tarteel_qul/") ||
            content.contains('import "package:tarteel_qul/');
        if (importsEngine && !_isAllowed(relative)) {
          offenders.add(relative);
        }
      }
    }
    expect(
      offenders,
      isEmpty,
      reason:
          'package:tarteel_qul/ must be confined to '
          '${_allowedRelativePaths.join(", ")}; '
          'offenders:\n${offenders.join("\n")}',
    );
  });
}
