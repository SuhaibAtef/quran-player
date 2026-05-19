import 'dart:io' show Platform;

import 'package:flutter/foundation.dart' show kDebugMode, kReleaseMode;

class AppEnvironment {
  const AppEnvironment._();

  static const AppEnvironment instance = AppEnvironment._();

  String get appName => 'Quran Companion';

  String get dataSubdirectory => 'QuranCompanion';

  bool get isDebug => kDebugMode;

  bool get isRelease => kReleaseMode;

  bool get isWindows => Platform.isWindows;

  bool get isMacOS => Platform.isMacOS;

  bool get isLinux => Platform.isLinux;
}
