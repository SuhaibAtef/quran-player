import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'mushaf_engine.dart';

/// Opens the QUL mushaf engine once per launch — lazily, the first time a
/// consumer (the reader, the `/reader/ayah` route redirect) reads it.
///
/// [openMushafEngine] never throws and never fails closed: on any QUL asset,
/// schema, or smoke-test problem it yields a text-only [MushafEngine] with
/// `usingFallback == true`. The reader branches on that to degrade to text
/// mode for the session without ever triggering the data-integrity fatal
/// screen — QUL page rendering is a progressive enhancement over the always
/// available Tanzil text mode.
final mushafEngineProvider = FutureProvider<MushafEngine>(
  (ref) => openMushafEngine(rootBundle),
);
