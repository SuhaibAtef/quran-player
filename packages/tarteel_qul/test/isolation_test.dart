import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Enforces the `mushaf-engine` package boundary: `tarteel_qul` is a
/// standalone, asset-agnostic, publishable package — it must not depend on the
/// host app, and it must bundle no QUL data.
void main() {
  late Directory packageRoot;

  setUpAll(() {
    // `flutter test packages/tarteel_qul/test/` runs with cwd at the package
    // root; a workspace-wide run uses the repo root. Resolve both.
    packageRoot = Directory('packages/tarteel_qul/lib').existsSync()
        ? Directory('packages/tarteel_qul')
        : Directory('.');
    expect(
      Directory('${packageRoot.path}/lib').existsSync(),
      isTrue,
      reason:
          'Could not locate the tarteel_qul package root '
          '(cwd=${Directory.current.path})',
    );
  });

  test('no file under lib/ imports package:quran_player/', () {
    const forbidden = <String>[
      "import 'package:quran_player/",
      'import "package:quran_player/',
      "export 'package:quran_player/",
      'export "package:quran_player/',
    ];

    final libDir = Directory('${packageRoot.path}/lib');
    final offenders = <String>[];
    for (final entity in libDir.listSync(recursive: true).whereType<File>()) {
      if (!entity.path.endsWith('.dart')) continue;
      final source = entity.readAsStringSync();
      for (final needle in forbidden) {
        if (source.contains(needle)) offenders.add('${entity.path}: $needle');
      }
    }

    expect(
      offenders,
      isEmpty,
      reason:
          'tarteel_qul/lib/ must not depend on the host app. Offenders:\n'
          '  ${offenders.join('\n  ')}',
    );
  });

  test('the package bundles no QUL databases or mushaf font files', () {
    // The engine renders only from consumer-supplied bytes — it ships no
    // layout database, word-script database, or font file of its own. (The
    // test stub font in lib/src/fixtures.dart is a base64 string, not a file.)
    const bannedExtensions = <String>[
      '.db',
      '.sqlite',
      '.ttf',
      '.otf',
      '.woff',
      '.woff2',
    ];
    const skipDirs = <String>['.dart_tool', 'build', '.git'];

    final offenders = <String>[];
    for (final entity
        in packageRoot.listSync(recursive: true).whereType<File>()) {
      final path = entity.path.replaceAll(r'\', '/');
      if (skipDirs.any((d) => path.contains('/$d/'))) continue;
      final lower = path.toLowerCase();
      if (bannedExtensions.any(lower.endsWith)) offenders.add(entity.path);
    }

    expect(
      offenders,
      isEmpty,
      reason:
          'tarteel_qul must bundle no QUL data or font files. Offenders:\n'
          '  ${offenders.join('\n  ')}',
    );
  });
}
