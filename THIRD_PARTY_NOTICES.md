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

## Notes

- This product is not endorsed by Tanzil. We make no claim to Tanzil's
  copyright or trademarks.
- If a future change introduces additional Quran editions, translations, or
  audio recitations, a separate entry must be added here in the same change.
