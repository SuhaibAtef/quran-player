# `lib/domain/`

Pure Dart entities and use-cases — `Surah`, `Ayah`, `Reciter`, `Bookmark`, etc. — and the contracts repositories must satisfy. Currently empty; the first feature change to need a domain model will populate this folder.

Code in here MUST NOT depend on Flutter, on any data source, or on any UI library (including ForUI). Keeping `domain/` framework-free is what lets us swap data sources or UI without rewriting the model layer.
