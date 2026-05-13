# Audio Source Verification

Verified on 2026-05-13.

## Approved MVP Source

- Provider: Quran Foundation / Quran.com public content API
- Provider URL: https://api-docs.quran.com/
- API base used by the app: https://api.quran.com/api/v4
- Verse audio CDN base for relative URLs: https://verses.quran.foundation/
- Default reciter: Mishari Rashid al-`Afasy
- Quran.com ayah-by-ayah recitation id: `7`
- Style: Murattal
- Access method: unauthenticated HTTPS GET against public content endpoints
- Client secret: none
- Rate-limit posture: numeric limit is not published in the endpoint docs; the
  API documents HTTP 429 `rate_limit_exceeded`, so the app treats it as a
  recoverable network failure and does not retry aggressively.
- Attribution wording: "Verse audio is streamed from Quran.com / Quran
  Foundation public content APIs. Default reciter: Mishari Rashid al-`Afasy."

## Evidence

- Quran Foundation Audio SDK docs describe verse recitations by chapter/key,
  direct audio URLs, optional timing segments, and formats.
- Quran Foundation content API docs for "Get Ayah recitations for specific
  Surah" state that the endpoint returns per-verse audio URLs for a chapter,
  requires an ayah-by-ayah recitation id from `/resources/recitations`, supports
  `verse_key`, `url`, `duration`, `format`, `segments`, and `id` fields, and
  caps `per_page` at 50 records.
- Direct request to
  `https://api.quran.com/api/v4/resources/recitations` returned HTTP 200 without
  authentication and included recitation id `7`, "Mishari Rashid al-`Afasy".
- Direct request to
  `https://api.quran.com/api/v4/quran/recitations/7?chapter_number=1&per_page=50&fields=verse_key,url,duration,format,id`
  returned HTTP 200 without authentication and all seven Al-Fatihah verse audio
  records.

## Reciter Artwork

No approved reciter image source was identified during verification. The MVP
uses local neutral generated artwork/initials rather than scraping or hotlinking
reciter photography.

## Implementation Constraints

- Do not embed Quran Foundation developer credentials or OAuth client secrets in
  the Flutter client.
- Treat 401, 403, 404, 422, 429, and 5xx API responses as recoverable audio
  failures; they must not affect local Quran text availability.
- Validate every returned `verse_key` against the requested local `AyahKey`
  before queueing audio.
