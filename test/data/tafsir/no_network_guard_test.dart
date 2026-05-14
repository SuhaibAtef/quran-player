@TestOn('vm')
library;

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

const _watchedDirs = <String>['lib/domain/tafsir', 'lib/data/tafsir'];
const _forbiddenImports = <String>[
  'package:http/',
  'dart:io.*HttpClient',
  'package:web_socket_channel/',
  'package:dio/',
];

void main() {
  test('lib/data/tafsir and lib/domain/tafsir make no network calls', () {
    final offenders = <String>[];
    for (final dir in _watchedDirs) {
      for (final entity in Directory(dir).listSync(recursive: true)) {
        if (entity is! File || !entity.path.endsWith('.dart')) continue;
        final content = entity.readAsStringSync();
        for (final forbidden in _forbiddenImports) {
          if (content.contains("import '$forbidden") ||
              content.contains('import "$forbidden')) {
            offenders.add('${entity.path} imports $forbidden');
          }
        }
        if (content.contains('HttpClient(')) {
          offenders.add('${entity.path} uses HttpClient');
        }
      }
    }
    expect(
      offenders,
      isEmpty,
      reason:
          'data/domain layers must not perform network I/O; offenders:\n${offenders.join("\n")}',
    );
  });
}
