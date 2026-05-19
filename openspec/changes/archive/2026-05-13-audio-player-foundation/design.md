## Context

Quran Companion has a verified local Quran text layer and a reader that can be
driven by `AyahKey` through the existing repository and `MushafLocator` seams.
The app still lacks the product's defining "player" behavior: recitation audio,
playback controls, queue state, and ayah-aware playback.

The audio source must meet the same trust bar as the text source: clear
attribution, acceptable usage terms, strict schemas, and no hidden mutation of
Quran data. The preferred source candidate is Quran Foundation/Quran.com because
its published audio API documents chapter recitations, verse recitations by
chapter or verse key, direct audio URLs, and optional timing segments. The
implementation must verify terms, reciter availability, and auth requirements
before hard-coding this source.

Stakeholders: readers/listeners (usable desktop playback), memorization users
(ayah-level progress), maintainers (clean dependency and download-manager seam),
future MCP work (safe playback controls), and reviewers (license/security
clarity).

## Goals / Non-Goals

**Goals:**

- Add a first usable audio player around one approved default reciter.
- Stream verse-level Quran recitation from an API-backed source.
- Maintain a playback queue that can advance across ayahs and expose the active
  ayah to the rest of the app.
- Highlight the active ayah in the reader when verse-level playback state is
  available and the current render mode can represent that ayah.
- Add a persistent bottom mini player with reciter image/artwork, current ayah
  label, progress, and core controls.
- Allow the mini player to expand into a queue/player panel without adding a new
  top-level navigation item.
- Keep the playback source abstraction compatible with a future download manager
  that resolves queue entries to local files.

**Non-Goals:**

- Multiple reciters or reciter switching.
- Offline downloads, cache eviction, or a download manager.
- Repeat modes, playback speed, sleep timer, or media-key/background playback.
- MCP playback controls or permission flows.
- Word-level highlighting. Timing segments may be stored for later, but this
  change highlights ayahs only.
- Translation, tafsir, or synchronized translation playback.

## Decisions

### 1. Verse-level queue first, with chapter audio as a fallback only

Use verse audio as the primary unit of playback. A queue entry represents an
`AyahKey`, the selected reciter, a remote playable URI, duration if available,
and optional timing metadata. Surah playback is modeled as a generated queue of
the surah's ayahs.

Why: ayah-level playback is the only reliable way to highlight the active ayah
without inventing timings. It also matches future bookmarks, search results, MCP
commands, and repeat-range features.

Alternatives considered:

- Whole-surah tracks first: simpler transport setup, but active ayah highlighting
  would require timing metadata that may not exist for every reciter.
- Word-level segments first: richer, but expands scope into renderer-specific
  highlighting and timing edge cases before the basic player exists.

### 2. Source-specific API mapping stays behind `AudioRepository`

Create framework-free domain types under `lib/domain/audio/`:

```text
Reciter
AudioSourceAttribution
AudioTrack
AudioQueueItem
AudioPlaybackState
AudioRepository
```

`AudioRepository` returns `Result<T, Failure>` and exposes methods such as:

```text
getDefaultReciter()
getSourceAttribution()
getAyahAudio(AyahKey key, ReciterId reciterId)
getSurahAudioQueue(int surahNumber, ReciterId reciterId)
```

The data layer owns HTTP, JSON parsing, response validation, URL construction,
and source-specific IDs. UI and player state never parse API responses directly.

Why: the future download manager can replace remote URLs with local file URIs at
this boundary, and MCP can reuse the domain model without importing Flutter UI.

Alternatives considered:

- Put audio methods on `QuranRepository`: convenient, but mixes verified local
  Quran text with remote mutable audio metadata.
- Fetch directly from widgets/controllers: faster initially, but hard to test,
  hard to attribute, and hard to swap for downloads.

### 3. Player engine is wrapped behind an adapter

Add a playback adapter interface owned by the feature/data layer instead of
exposing a third-party player package throughout the app. The likely runtime
choice is `just_audio` with a Windows-capable backend such as
`just_audio_media_kit` or another maintained Windows implementation, verified
during implementation.

Why: package support for Flutter desktop audio changes over time. Wrapping the
engine contains dependency churn and lets tests use a fake player.

Alternatives considered:

- Use the package directly in Riverpod controllers: less code, but all state and
  tests become coupled to the package API.
- Build on platform channels now: too much native surface for the first MVP
  player.

### 4. App-level mini player, expanded as an overlay/panel

Render the mini player from the app shell composition so it persists across
Home/Surahs, Search, Bookmarks, Settings, MCP Status, and reader routes. The mini
player remains hidden until a queue exists. Clicking the non-control area opens
an expanded queue/player panel, preferably a ForUI sheet or similarly integrated
panel.

Why: this matches desktop music-player expectations, avoids another top-level
destination, and keeps playback visible while the user reads or navigates.

Alternatives considered:

- Dedicated player page: easier layout, but hides playback when the user returns
  to reading.
- Reader-only controls: insufficient for a product-level player and would not
  support future search/bookmark/MCP playback entry points.

### 5. Reader highlight observes active ayah state

Expose the active playback ayah through Riverpod state. Text mode highlights the
matching ayah tile when the current surah is visible. Page mode highlights only
if the renderer supports ayah highlighting without treating QCF glyphs as
canonical text; otherwise it may show page-level context and defer precise page
highlighting.

Why: active ayah state belongs to playback, while visual representation belongs
to the reader. This keeps the QCF import boundary intact.

Alternatives considered:

- Push highlight commands directly from the player into reader widgets: brittle
  cross-feature coupling.
- Require page-mode highlighting in this change: desirable, but only safe if the
  existing renderer exposes a stable ayah highlight API.

### 6. Reciter image must be licensed or replaced with approved artwork

The mini player requires reciter visual identity. The implementation must either
use a licensed/attributed reciter image from the selected source or ship a
locally owned neutral artwork/avatar for the default reciter. Do not scrape or
hotlink arbitrary images.

Why: images are copyright-sensitive, and the project already treats source
attribution as part of product trust.

## Risks / Trade-offs

- API terms or auth are incompatible with a desktop client -> Stop before
  implementation and revise the source decision; never embed a client secret in
  Flutter.
- Verse audio exists but duration/timing metadata is incomplete -> Use
  player-reported position for progress and ayah-level queue advancement; do not
  invent timing.
- Network failure interrupts playback -> Surface a non-fatal player error and
  keep Quran text/reader usable.
- Desktop audio backend instability -> Keep the third-party package behind an
  adapter, add fake-player tests, and run a Windows smoke test before shipping.
- Per-ayah HTTP fetches may be slow -> Prefetch the next small batch of ayah
  audio metadata for the current queue, but do not cache audio files in this
  change.
- Bottom player may fight existing narrow layout -> Use responsive constraints;
  controls can collapse to icon-only at narrow widths while preserving labels in
  the expanded panel.
- Page-mode ayah highlighting may be limited by `qcf_quran_plus` -> Implement
  text-mode highlighting first and only add page-mode precise highlighting if it
  preserves the existing QCF boundary.

## Migration Plan

1. Verify the audio API source, default reciter, terms, attribution, image rights,
   and auth model.
2. Add domain contracts and fakes first.
3. Add source-specific data mapping with fixture tests.
4. Add playback adapter and controller using a fake engine in unit/widget tests.
5. Add mini player and expanded queue UI behind empty-state behavior so the shell
   is unchanged until a queue starts.
6. Wire Surahs/reader entry points to start a verse queue.
7. Add active ayah highlighting in supported reader modes.
8. Update docs and notices.

Rollback: remove the shell mini-player composition and provider wiring; the
reader and Quran data layer remain usable because audio lives in separate
domain/data/features folders.

## Open Questions

- Which exact reciter should be the default for MVP after license/source
  verification?
- Does the chosen API require per-user authentication, an application token, or
  no auth for audio content?
- Does the chosen reciter provide verse-level files for all 6,236 ayahs?
- Does the source provide approved reciter imagery, or should the MVP ship local
  neutral artwork instead?
- Can page mode safely highlight individual ayahs through `qcf_quran_plus`, or
  should precise highlight initially be text-mode only?
