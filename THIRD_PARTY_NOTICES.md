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

## Tafsir — al-Muyassar (King Fahd Complex)

- **Edition:** al-Tafsir al-Muyassar, prepared under the supervision of the
  King Fahd Complex for the Printing of the Holy Quran (Madinah-mushaf
  margin edition).
- **Upstream publisher:** [King Fahd Complex for the Printing of the Holy
  Quran](https://qurancomplex.gov.sa/).
- **Distribution path used:** the verbatim Arabic tafsir text is fetched at
  maintainer build time from the
  [`spa5k/tafsir_api`](https://github.com/spa5k/tafsir_api) MIT-licensed
  community mirror, slug `ar-tafsir-muyassar`, pinned to a specific commit
  SHA recorded in [`tool/build_tafsir_db.dart`](tool/build_tafsir_db.dart).
  The retrieval timestamp, commit SHA, and SHA-256 of the canonical text
  payload are recorded in [`assets/tafsir/manifest.json`](assets/tafsir/manifest.json)
  and inside the bundled SQLite asset (`meta` table).
- **License:** the tafsir text is the work of the King Fahd Complex; the
  Complex permits free non-commercial redistribution with proper attribution
  and without modification. The redistribution layer (`spa5k/tafsir_api`)
  is independently MIT-licensed.

  Quran Companion bundles the tafsir text **verbatim**. The maintainer build
  tool verifies the parsed entry count (6,236, matching the Quran corpus) and
  cross-checks every `(surah, ayah)` key against the bundled Quran DB before
  emitting output. The runtime app verifies the integrity of the bundled
  tafsir asset on every launch (schema version, row count, orphan-key
  cross-check against the Quran DB, and SHA-256) and refuses to serve tafsir
  data on mismatch.

- **Source policy:** the tafsir corpus is read-only and does not participate
  in keyword search results in this change. Future changes adding tafsir UI
  or tafsir-augmented search must continue to credit both the King Fahd
  Complex (original author) and the `spa5k/tafsir_api` mirror (redistributor).

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

## Audio recitation — Quran.com / Quran Foundation

- **Provider:** Quran.com / Quran Foundation public content API.
- **API docs:** https://api-docs.quran.com/
- **Runtime API base:** https://api.quran.com/api/v4
- **Verse audio CDN base:** https://verses.quran.foundation/
- **Default reciter:** Mohamed Siddiq al-Minshawi, Murattal, Quran.com
  ayah-by-ayah recitation id `9`.
- **Access model:** unauthenticated HTTPS GET requests to public content
  endpoints. The Flutter client does not embed developer credentials or API
  secrets. API errors, including documented rate-limit responses, are treated as
  recoverable audio failures and do not affect the local Quran text database.
- **Artwork:** no approved reciter photography is bundled in this change. The
  app uses neutral local initials/artwork for the player surface.
- **Source policy:** the API supplies recitation audio only. Quran references,
  queue ordering, reader labels, and ayah highlighting are validated against the
  local integrity-checked `QuranRepository`.

## MCP protocol — mcp_dart

- **Package:** [`mcp_dart`](https://pub.dev/packages/mcp_dart) `^2.1.1`
  (MIT, copyright leehack). Source: pub.dev; the only file permitted to
  import it is
  [`packages/quran_mcp_server/lib/src/adapter/mcp_dart_adapter.dart`](packages/quran_mcp_server/lib/src/adapter/mcp_dart_adapter.dart),
  enforced by `packages/quran_mcp_server/test/isolation_test.dart`.
- **Role:** provides the MCP protocol implementation (tool registration,
  `CallToolResult` shape, JSON-RPC framing). The workspace package owns its
  own `HttpServer.bind(InternetAddress.loopbackIPv4, port)` listener and
  validates the bearer token + loopback origin before any request reaches
  mcp_dart.
- **Source policy:** mcp_dart is a protocol library only. It does not bring
  any Quran text, audio, or reciter data into the project. All MCP responses
  are sourced from the same verified `QuranRepository` / `AudioRepository`
  the UI uses, via host adapter ports.

## Notes

- This product is not endorsed by Tanzil or by the King Fahd Complex. We
  make no claim to either party's copyright or trademarks.
- If a future change introduces additional Quran editions, translations, or
  reciters, a separate entry must be added here in the same change.
