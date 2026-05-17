# Changelog

## 0.1.0

Initial release — a Flutter rendering engine for Tarteel QUL printed-mushaf data.

- `MushafAssetSource` — the sole consumer data contract: layout database bytes,
  word-script database bytes, and per-page font bytes (fetched lazily).
- `MushafLayoutRepository` — parses a QUL layout (`pages`) + word (`words`)
  database into typed `MushafPage` / `MushafLine` / `MushafWord` models, with
  schema validation that surfaces a structured failure rather than throwing.
- Page↔ayah coordinate API — `pageForAyah`, `firstAyahOnPage`, `ayahsOnPage`,
  `pageForSurah`.
- `MushafController` — page navigation (open / next / previous / current page).
- `MushafView` — a mode-agnostic widget that renders a page in its per-page
  font with right-to-left paging, emits `onWordTap` / `onAyahTap` events,
  accepts ayah-highlight decorations, takes a `headerBuilder` for
  surah-name / basmala lines, and renders on a configurable light `pageColor`.
- Per-page fonts are loaded lazily and cached for the lifetime of the process.
- Bundles no QUL data or fonts.
