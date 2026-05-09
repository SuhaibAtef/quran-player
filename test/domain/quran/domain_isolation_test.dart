@TestOn('vm')
library;

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

const _domainDir = 'lib/domain/quran';
const _forbiddenImports = <String>[
  "package:flutter/",
  "package:flutter_riverpod/",
  "package:sqflite/",
  "package:sqflite_common_ffi/",
];

void main() {
  test('lib/domain/quran has no Flutter / storage imports', () {
    final dir = Directory(_domainDir);
    expect(dir.existsSync(), isTrue, reason: '$_domainDir should exist');

    final offenders = <String>[];
    for (final entity in dir.listSync(recursive: true)) {
      if (entity is! File || !entity.path.endsWith('.dart')) continue;
      final content = entity.readAsStringSync();
      for (final forbidden in _forbiddenImports) {
        if (content.contains("import '$forbidden") ||
            content.contains('import "$forbidden')) {
          offenders.add('${entity.path} imports $forbidden');
        }
      }
    }

    expect(
      offenders,
      isEmpty,
      reason:
          'domain layer must stay framework-free; offenders:\n${offenders.join("\n")}',
    );
  });
}
