import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'MCP implementation does not expose shell, filesystem, or non-loopback listeners',
    () {
      final files = [
        ...Directory('lib/domain/mcp').listSync(recursive: true),
        ...Directory('lib/data/mcp').listSync(recursive: true),
        ...Directory('lib/features/mcp_status').listSync(recursive: true),
      ].whereType<File>().where((f) => f.path.endsWith('.dart'));

      for (final file in files) {
        final text = file.readAsStringSync();
        final path = file.path.replaceAll(r'\', '/');
        expect(text, isNot(contains('Process.')), reason: file.path);
        expect(text, isNot(contains('File(')), reason: file.path);
        expect(text, isNot(contains('Directory(')), reason: file.path);
        final isHttpServerAdapter = path.endsWith(
          'lib/data/mcp/mcp_http_server.dart',
        );
        if (isHttpServerAdapter) {
          expect(text, contains("mcpLocalHost = '127.0.0.1'"));
          expect(text, contains("mcpPublicHost = 'localhost'"));
          expect(text, contains('InternetAddress.loopbackIPv4'));
          expect(text, contains('HttpServer.bindSecure'));
          expect(text, isNot(contains('HttpServer.bind(')), reason: file.path);
        } else {
          expect(text, isNot(contains('ServerSocket')), reason: file.path);
          expect(text, isNot(contains('Socket.bind')), reason: file.path);
          expect(text, isNot(contains('HttpServer.bind')), reason: file.path);
        }
        expect(text, isNot(contains('0.0.0.0')), reason: file.path);
        expect(
          text,
          isNot(contains('InternetAddress.anyIPv4')),
          reason: file.path,
        );
        expect(
          text,
          isNot(contains('InternetAddress.anyIPv6')),
          reason: file.path,
        );
      }
    },
  );
}
