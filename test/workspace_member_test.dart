import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:yaml/yaml.dart';

/// Enforces spec mcp-server R2: the root pubspec.yaml MUST declare
/// `packages/quran_mcp_server` as a workspace member.
void main() {
  test(
    'root pubspec.yaml lists packages/quran_mcp_server as a workspace member',
    () {
      final file = File('pubspec.yaml');
      expect(
        file.existsSync(),
        isTrue,
        reason: 'pubspec.yaml not found at repo root',
      );

      final doc = loadYaml(file.readAsStringSync());
      expect(
        doc,
        isA<YamlMap>(),
        reason: 'pubspec.yaml does not parse as a YAML map',
      );

      final workspace = (doc as YamlMap)['workspace'];
      expect(
        workspace,
        isA<YamlList>(),
        reason: 'pubspec.yaml does not declare a `workspace:` list',
      );

      final members = (workspace as YamlList).map((e) => e.toString()).toList();
      expect(
        members,
        contains('packages/quran_mcp_server'),
        reason:
            'pubspec.yaml workspace list does not include packages/quran_mcp_server; got: $members',
      );
    },
  );
}
