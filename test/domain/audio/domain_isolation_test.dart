import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'audio domain does not import Flutter, Riverpod, HTTP, storage, or player packages',
    () {
      final dir = Directory('lib/domain/audio');
      expect(dir.existsSync(), isTrue);

      final forbidden = RegExp(
        r"package:(flutter|flutter_riverpod|http|shared_preferences|"
        r"sqflite|sqflite_common_ffi|media_kit|just_audio)",
      );
      for (final file in dir.listSync(recursive: true).whereType<File>()) {
        if (!file.path.endsWith('.dart')) continue;
        final contents = file.readAsStringSync();
        expect(
          forbidden.hasMatch(contents),
          isFalse,
          reason: '${file.path} imports a forbidden package',
        );
      }
    },
  );
}
