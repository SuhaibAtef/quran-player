import 'package:flutter/widgets.dart';
import 'package:forui/forui.dart';

import 'package:quran_player/l10n/app_localizations.dart';

/// Wraps [child] with the app's localization delegates and [locale] so a
/// bare-widget test — one that pumps a screen directly instead of the full
/// `App` — can resolve `AppLocalizations.of(context)` and `FLocalizations`.
///
/// Pass `locale: const Locale('ar')` to exercise an Arabic build. This only
/// supplies `Localizations`; callers keep their own `Directionality`.
Widget localized(Widget child, {Locale locale = const Locale('en')}) {
  return Localizations(
    locale: locale,
    delegates: [
      AppLocalizations.delegate,
      ...FLocalizations.localizationsDelegates,
    ],
    child: child,
  );
}
