import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:media_kit/media_kit.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'app/app.dart';
import 'app/state/theme_mode_provider.dart';
import 'app/state/user_db_provider.dart';
import 'core/logging/logger.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  initLogging();

  try {
    MediaKit.ensureInitialized();
  } on Object catch (error, stackTrace) {
    appLogger.warning(
      'Audio backend unavailable at startup',
      error,
      stackTrace,
    );
  }

  final prefs = await SharedPreferences.getInstance();

  final container = ProviderContainer(
    overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
  );

  // Kick off user.db open + 7-day audit-log prune as a non-blocking background
  // task. The bundled-DB integrity gates remain on the critical path; user.db
  // is fail-soft (spec mcp-server R5) so we don't gate runApp on its result.
  unawaited(container.read(userDbStateProvider.future));

  runApp(UncontrolledProviderScope(container: container, child: const App()));
}
