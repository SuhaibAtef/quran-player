import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:forui/forui.dart';

import '../l10n/app_localizations.dart';
import 'router/app_router.dart';
import 'state/locale_provider.dart';
import 'state/theme_mode_provider.dart';
import 'theme/app_theme.dart';

class App extends ConsumerStatefulWidget {
  const App({super.key});

  @override
  ConsumerState<App> createState() => _AppState();
}

class _AppState extends ConsumerState<App> {
  @override
  Widget build(BuildContext context) {
    final mode = ref.watch(themeModeProvider);
    final localeOption = ref.watch(localeProvider);
    final router = ref.watch(appRouterProvider);

    return MaterialApp.router(
      onGenerateTitle: (context) => AppLocalizations.of(context).appTitle,
      debugShowCheckedModeBanner: false,
      themeMode: mode,
      theme: AppTheme.light.toApproximateMaterialTheme(),
      darkTheme: AppTheme.dark.toApproximateMaterialTheme(),
      locale: localeOption.locale,
      localizationsDelegates: [
        AppLocalizations.delegate,
        ...FLocalizations.localizationsDelegates,
      ],
      supportedLocales: AppLocalizations.supportedLocales,
      routerConfig: router,
      builder: (context, child) {
        final platformBrightness = MediaQuery.platformBrightnessOf(context);
        final theme = AppTheme.resolve(mode, platformBrightness);
        return FTheme(data: theme, child: child!);
      },
    );
  }
}
