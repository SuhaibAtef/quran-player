import 'dart:io';

import 'package:test/test.dart';

/// Enforces the workspace package boundary from spec mcp-server R1.
///
/// No file under `packages/quran_mcp_server/lib/` may import Flutter, Flutter
/// Riverpod, SharedPreferences, or any path under the host app's
/// `lib/features/` or `lib/app/`. Additionally, only the adapter file is
/// permitted to import `package:mcp_dart`.
void main() {
  late Directory libDir;

  setUpAll(() {
    final cwd = Directory.current.path.replaceAll(r'\', '/');
    // Tests run with cwd at the package root when invoked via
    // `flutter test packages/quran_mcp_server/` and at the repo root for
    // workspace-wide runs. Resolve both.
    final fromPackageRoot = Directory('lib');
    final fromRepoRoot = Directory('packages/quran_mcp_server/lib');
    libDir = fromRepoRoot.existsSync() ? fromRepoRoot : fromPackageRoot;
    expect(
      libDir.existsSync(),
      isTrue,
      reason: 'Could not locate quran_mcp_server lib dir from cwd=$cwd',
    );
  });

  test(
    'no file imports Flutter, Riverpod, SharedPreferences, or host-app modules',
    () {
      const forbidden = <String>[
        "import 'package:flutter/",
        "import \"package:flutter/",
        "import 'package:flutter_riverpod/",
        "import \"package:flutter_riverpod/",
        "import 'package:shared_preferences/",
        "import \"package:shared_preferences/",
        "import 'package:quran_player/features/",
        "import \"package:quran_player/features/",
        "import 'package:quran_player/app/",
        "import \"package:quran_player/app/",
      ];

      final offenders = <String>[];
      for (final entity in libDir.listSync(recursive: true).whereType<File>()) {
        if (!entity.path.endsWith('.dart')) continue;
        final source = entity.readAsStringSync();
        for (final needle in forbidden) {
          if (source.contains(needle)) {
            offenders.add('${entity.path}: $needle');
          }
        }
      }

      expect(
        offenders,
        isEmpty,
        reason:
            'Forbidden imports detected in quran_mcp_server/lib/:\n  ${offenders.join('\n  ')}',
      );
    },
  );

  test('only the mcp_dart adapter file imports package:mcp_dart', () {
    final adapterPath = '${libDir.path}/src/adapter/mcp_dart_adapter.dart'
        .replaceAll(r'\', '/');
    final offenders = <String>[];

    for (final entity in libDir.listSync(recursive: true).whereType<File>()) {
      if (!entity.path.endsWith('.dart')) continue;
      final normalizedPath = entity.path.replaceAll(r'\', '/');
      final source = entity.readAsStringSync();
      final importsMcpDart =
          source.contains("import 'package:mcp_dart") ||
          source.contains('import "package:mcp_dart');
      if (importsMcpDart && normalizedPath != adapterPath) {
        offenders.add(entity.path);
      }
    }

    expect(
      offenders,
      isEmpty,
      reason:
          'Only $adapterPath may import package:mcp_dart. Offenders:\n  ${offenders.join('\n  ')}',
    );
  });
}
