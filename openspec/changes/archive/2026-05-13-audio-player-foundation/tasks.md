## 1. Source Verification

- [x] 1.1 Verify the preferred audio API source terms, auth model, rate limits, and attribution requirements.
- [x] 1.2 Choose the default MVP reciter and confirm verse-level audio exists for all 6,236 ayahs.
- [x] 1.3 Confirm whether approved reciter imagery is available; otherwise define the local neutral artwork fallback.
- [x] 1.4 Record the approved source, reciter, URL, terms, and attribution wording in implementation notes before coding against the API.

## 2. Dependencies and Boundaries

- [x] 2.1 Evaluate and add the runtime HTTP dependency needed by the audio data layer.
- [x] 2.2 Evaluate and add the Windows-capable audio playback dependency and native backend.
- [x] 2.3 Create a playback adapter interface so feature state does not depend directly on the player package.
- [x] 2.4 Add dependency/import boundary tests for `lib/domain/audio/` and for the QCF renderer boundary.

## 3. Audio Domain

- [x] 3.1 Add `lib/domain/audio/` models for reciter, source attribution, audio track, queue item, playback state, and player status.
- [x] 3.2 Add audio repository contracts returning `Result<T, Failure>` for source attribution, default reciter, ayah audio, and surah queue resolution.
- [x] 3.3 Add validation helpers for source verse keys, reciter IDs, playable URIs, and queue ordering.
- [x] 3.4 Add unit tests for domain validation and failure behavior.

## 4. API Data Layer

- [x] 4.1 Implement an injectable audio API client with strict JSON parsing and no embedded secrets.
- [x] 4.2 Implement source-specific response mapping into domain models.
- [x] 4.3 Implement ayah audio resolution that rejects mismatched source verse keys.
- [x] 4.4 Implement surah queue resolution ordered by local `QuranRepository` ayah keys.
- [x] 4.5 Add fixture-based tests for healthy responses, malformed responses, mismatched verse keys, invalid input, and network failures.

## 5. Playback State

- [x] 5.1 Implement fakeable playback engine adapter methods for load, play, pause, seek, next/current-item completion, and dispose.
- [x] 5.2 Implement Riverpod player controller/state providers for idle, loading, playing, paused, buffering, completed, and error states.
- [x] 5.3 Wire queue advancement from current ayah completion to the next queue item.
- [x] 5.4 Expose active playback `AyahKey` as derived app state for reader highlighting.
- [x] 5.5 Add unit tests for queue load, play/pause, seek, next/previous, completion, error, and clear/stop behavior.

## 6. Player UI

- [x] 6.1 Add a persistent bottom mini player to the app shell that appears only when a queue is loaded.
- [x] 6.2 Build mini player layout with reciter image/artwork, reciter name, current ayah label, progress, and play/pause/seek/next/previous controls.
- [x] 6.3 Add responsive constraints so the mini player remains usable on narrow and desktop widths.
- [x] 6.4 Add expanded queue/player panel opened by clicking the non-control area of the mini player.
- [x] 6.5 Ensure transport controls do not also open the expanded panel.
- [x] 6.6 Add widget tests for hidden empty state, visible loaded state, route persistence, control actions, and expanded queue interactions.

## 7. Playback Entry Points and Reader Highlight

- [x] 7.1 Add a play action from Surah list or reader surfaces to start a surah verse queue for the default reciter.
- [x] 7.2 Add optional ayah-level play action where the reader already has stable `AyahKey` context.
- [x] 7.3 Highlight the active ayah in text reader mode from the derived active playback ayah state.
- [x] 7.4 Investigate page-mode precise highlighting; implement only if it preserves the existing QCF import boundary.
- [x] 7.5 Add widget tests for starting playback from UI and for active ayah highlighting/clearing.

## 8. Attribution and Documentation

- [x] 8.1 Add Settings attribution for the audio source and default reciter.
- [x] 8.2 Update `THIRD_PARTY_NOTICES.md` with the approved audio source, reciter, terms/license, and image/artwork attribution.
- [x] 8.3 Update `AGENTS.md` with the audio player architecture, source policy, dependency choices, and current limitations.
- [x] 8.4 Update `README.md` with the player capability, runtime network requirement for streaming, and future download-manager note.

## 9. Verification

- [x] 9.1 Run `just format`.
- [x] 9.2 Run `just analyze`.
- [x] 9.3 Run focused audio/player/reader tests.
- [x] 9.4 Run `just test`.
- [x] 9.5 Run a Windows manual smoke: start a surah queue, play/pause, seek, next/previous, navigate routes, expand queue, and verify reader highlight.
