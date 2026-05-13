import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:media_kit/media_kit.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'app/app.dart';
import 'app/state/theme_mode_provider.dart';
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

  runApp(
    ProviderScope(
      overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
      child: const App(),
    ),
  );
}
