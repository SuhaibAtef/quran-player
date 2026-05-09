import 'package:flutter/foundation.dart';
import 'package:logging/logging.dart';

import '../env/app_environment.dart';

final Logger appLogger = Logger('QuranCompanion');

bool _initialized = false;

void initLogging({Level? level}) {
  if (_initialized) return;
  _initialized = true;

  Logger.root.level =
      level ?? (AppEnvironment.instance.isDebug ? Level.FINE : Level.INFO);

  Logger.root.onRecord.listen((record) {
    if (!kDebugMode && record.level < Level.INFO) return;

    final buffer = StringBuffer()
      ..write('[${record.level.name}] ')
      ..write('${record.loggerName}: ')
      ..write(record.message);
    if (record.error != null) buffer.write(' | error=${record.error}');

    debugPrint(buffer.toString());
    if (record.stackTrace != null) {
      debugPrint(record.stackTrace.toString());
    }
  });
}
