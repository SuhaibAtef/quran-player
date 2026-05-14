import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'MCP implementation does not expose shell, filesystem, or listeners',
    () {
      final files = [
        ...Directory('lib/domain/mcp').listSync(recursive: true),
        ...Directory('lib/data/mcp').listSync(recursive: true),
        ...Directory('lib/features/mcp_status').listSync(recursive: true),
      ].whereType<File>().where((f) => f.path.endsWith('.dart'));

      for (final file in files) {
        final text = file.readAsStringSync();
        expect(text, isNot(contains('Process.')), reason: file.path);
        expect(text, isNot(contains('File(')), reason: file.path);
        expect(text, isNot(contains('Directory(')), reason: file.path);
        expect(text, isNot(contains('ServerSocket')), reason: file.path);
        expect(text, isNot(contains('Socket.bind')), reason: file.path);
        expect(text, isNot(contains('HttpServer')), reason: file.path);
      }
    },
  );
}
