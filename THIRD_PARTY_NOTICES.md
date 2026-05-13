# Third-Party Notices

Quran Companion bundles or depends on the third-party content listed below.
This file is the canonical attribution surface; the in-app Settings screen
mirrors the Quran-source entry. Pub-package licenses ship under each package's
own LICENSE file.

## Quran text — Tanzil Uthmani

- **Edition:** Tanzil Quran Text — Uthmani plain text
- **Version:** 1.0.2
- **Upstream project:** [tanzil.net](https://tanzil.net/download/)
- **Distribution path used:** the verbatim Uthmani edition is fetched at
  maintainer build time via the [Islamic Network alquran.cloud API](https://alquran.cloud/api),
  which redistributes Tanzil's `quran-uthmani` edition. The fetch URL,
  retrieval timestamp, and SHA-256 of the canonical text payload are recorded
  in [`assets/quran/manifest.json`](assets/quran/manifest.json) and inside
  the bundled SQLite asset (`meta` table).
- **License:** Tanzil Quran Text License — see
  https://tanzil.net/docs/tanzil_license.

  Excerpt (full text at the URL above):

  > Permission is granted to copy and distribute verbatim copies of the Quran
  > text provided here, but **changing the text is not allowed**.
  > Redistribution must include attribution to Tanzil and a link to
  > tanzil.net.

  Quran Companion bundles the text **verbatim**. The maintainer build tool
  ([`tool/build_quran_db.dart`](tool/build_quran_db.dart)) verifies the
  SHA-256 of the canonical text against the pin recorded in the tool source
  and aborts the build on any mismatch. The runtime app additionally verifies
  the integrity of the bundled SQLite asset on every launch and refuses to
  render Quran data on mismatch.

## Mushaf rendering — qcf_quran_plus + QCF glyph fonts

- **Package:** [`qcf_quran_plus`](https://pub.dev/packages/qcf_quran_plus)
  v0.0.8 (MIT, copyright Hussein). Source: pub.dev; consumed only by
  [`lib/data/quran/mushaf_locator_qcf.dart`](lib/data/quran/mushaf_locator_qcf.dart)
  and [`lib/features/reader/widgets/page_mushaf_view.dart`](lib/features/reader/widgets/page_mushaf_view.dart).
- **Bundled fonts:** the package ships QCF (King Fahd Glorious Qur'an Complex)
  glyph fonts and the standard 604-page Madani mushaf metadata. The package's
  own LICENSE file (MIT) does not separately reproduce the QCF font license.
- **License status:** maintainer verified during the `mushaf-reader` change
  that the bundled QCF fonts are allowed for this project and may be
  redistributed with the desktop app. Keep this attribution with any release
  that includes the page-mode reader assets.

- **Source policy:** the package supplies *layout and glyphs only*. Canonical
  Quran text remains the integrity-checked Tanzil corpus described in the
  previous section. Selection, copy, search, and MCP responses always go
  through `QuranRepository` — never through QCF glyph data.

## Notes

- This product is not endorsed by Tanzil or by the King Fahd Complex. We
  make no claim to either party's copyright or trademarks.
- If a future change introduces additional Quran editions, translations, or
  audio recitations, a separate entry must be added here in the same change.
