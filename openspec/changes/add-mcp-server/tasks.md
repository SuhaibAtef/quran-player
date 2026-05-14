## 1. Protocol and Lifecycle

- [ ] 1.1 Evaluate the current Dart MCP package ecosystem and choose either an isolated dependency adapter or a minimal in-repo stdio JSON-RPC transport.
- [ ] 1.2 Add MCP server module structure for protocol routing, DTOs, validation, errors, lifecycle state, and tests.
- [ ] 1.3 Implement local-only server startup/shutdown with states `disabled`, `starting`, `running`, `stopped`, and `failed`.
- [ ] 1.4 Add import/security boundary tests proving MCP code exposes no arbitrary file, shell, or remote network listener capability.

## 2. Read-only Tools and Resources

- [ ] 2.1 Implement explicit MCP DTOs for Quran source metadata, surahs, ayahs, search results, and reciters.
- [ ] 2.2 Implement `list_surahs`, `get_ayah`, `get_surah`, `search_quran`, and `list_reciters` by reusing existing repository contracts.
- [ ] 2.3 Implement resources `quran://metadata`, `quran://surahs`, `quran://surah/{surah}`, `quran://ayah/{surah}/{ayah}`, and `quran://reciters`.
- [ ] 2.4 Add schema validation and structured error mapping for malformed inputs, out-of-range references, repository failures, and bootstrap failures.
- [ ] 2.5 Add fixture-style tests for tool listing, resource listing, successful read-only calls, and read-only failure cases.

## 3. Playback Permission and Bridge

- [ ] 3.1 Add a playback command model covering `play_surah`, `play_ayah`, `pause_playback`, `resume_playback`, `stop_playback`, and `set_repeat`.
- [ ] 3.2 Add an MCP playback permission state model for pending, approved, denied, timed-out, and unavailable commands.
- [ ] 3.3 Implement the app/player bridge so approved playback commands reuse the existing audio repository and player controller behavior.
- [ ] 3.4 Validate playback command inputs before prompting, including Quran references and supported repeat modes.
- [ ] 3.5 Return structured errors for denied, timed-out, app-unavailable, player-unavailable, and playback failure cases.
- [ ] 3.6 Add tests proving unapproved commands do not change player state and approved commands invoke the existing player path.

## 4. MCP Status UI

- [ ] 4.1 Replace the MCP Status placeholder with a ForUI-based status page showing lifecycle state, local-only mode, exposed tools/resources, and playback permission state.
- [ ] 4.2 Add approve/deny controls for pending playback commands with enough command detail for informed user review.
- [ ] 4.3 Show recent in-session command decisions without adding a persistent audit log.
- [ ] 4.4 Add widget tests for lifecycle states, local-only copy, pending command approval/denial, and recent decision rendering.

## 5. Tooling and Documentation

- [ ] 5.1 Add a Justfile recipe for launching or smoke-testing the local MCP server in development.
- [ ] 5.2 Update README.md and AGENTS.md with the shipped MCP data/playback behavior, local-only safety model, and verification commands.
- [ ] 5.3 Document any MCP client configuration needed to launch the server locally.

## 6. Verification

- [ ] 6.1 Run focused MCP data, playback bridge, and MCP Status widget tests.
- [ ] 6.2 Run `just check`.
- [ ] 6.3 Manually exercise the app MCP Status flow on Windows when possible, including approving and denying a playback command.
