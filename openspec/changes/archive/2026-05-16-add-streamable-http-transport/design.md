## Context

[`realign-mcp-server-implementation`](../realign-mcp-server-implementation/) shipped a working MCP server but with a custom HTTP request/response shape. That decision was conscious — `mcp_dart`'s `StreamableHTTPServerTransport` API surface looked unstable and we wanted to lock the dispatcher / scope / audit semantics first against a shape we fully controlled. Now that the dispatcher and tests are stable, the transport swap is bounded enough to be its own change.

The realignment design ([`realign-mcp-server-implementation/design.md`](../realign-mcp-server-implementation/design.md) Open Question 1) explicitly noted this: *"we don't use mcp_dart's StreamableHTTPServerTransport at all — the package owns its own HttpServer.bind … re-evaluate when we have a stable target."* This change is the re-evaluation.

Current state on the stacked branch:

- `packages/quran_mcp_server/lib/src/server.dart` — owns `HttpServer.bind(InternetAddress.loopbackIPv4, port)`, validates bearer token + remote loopback, then routes to `_handleMcp` (which parses the custom `{"method":..., "params":...}` shape) or `_handleResource` (which takes a path-based URI).
- `packages/quran_mcp_server/lib/src/adapter/mcp_dart_adapter.dart` — constructs `mcp.McpServer`, registers all 11 tools via `s.registerTool(...)`, and exposes `_runTool` / `readResource` for `server.dart` to call directly.
- `mcp.McpServer` is currently *constructed but not connected to any transport*. We never call `server.connect(...)`. Tool callbacks fire from our custom dispatch path, not from `mcp_dart`'s transport.

Stakeholders: user (asked for "best way to test with Claude Desktop / MCP Inspector"); reviewers (need a small, contained diff); future tool authors (the registration shape they target becomes `mcp_dart`'s standard surface); the MCP-client ecosystem at large (we move from "compatible with curl only" to "compatible with anything that speaks streamable HTTP").

Constraints (carried from the realignment):

- Loopback-only on `127.0.0.1`. Two layers: OS-level bind, plus per-request `connectionInfo.remoteAddress.isLoopback` check.
- Bearer-token gate runs **before** any payload reaches `mcp_dart`. Unauthorized → `401`, no transport invocation.
- Every tool call still flows through `Dispatcher.callTool` (scope check → handler → audit log).
- `package:mcp_dart` only imported by `adapter/mcp_dart_adapter.dart` (enforced by `test/isolation_test.dart`).
- Pre-commit hook runs `flutter test` on host + `flutter test packages/quran_mcp_server/test/` — no `--no-verify`.

## Goals / Non-Goals

**Goals:**

- Speak the standard MCP wire protocol over the existing loopback HTTP listener so MCP Inspector, Cursor's MCP client, Claude Desktop's HTTP transport (as it rolls out), and anything else compliant with streamable HTTP can connect.
- Move resources onto the transport (`resources/list`, `resources/read`) so they're discoverable through the standard channel — no more custom `/resource/<uri>` path.
- Keep the diff bounded to `server.dart` + `mcp_dart_adapter.dart` + tests. No churn in `Dispatcher`, `ToolHandlers`, `ports.dart`, `scopes/`, `audit/`, host adapters, Settings, or MCP Status.
- Preserve every behavioural contract from the realignment spec (R1 isolation, R2 workspace member, R3 scope-denied, R4 prune, R5 graceful-degrade, R6 both-modes audit, R7 args_summary truncation).
- Add a streamable-HTTP integration test that boots a real `HttpServer` and exercises the JSON-RPC roundtrip — proves bearer + loopback + dispatcher + audit all compose correctly with the standard transport.

**Non-Goals:**

- Adding stdio transport. Stdio is a separate follow-up if/when Claude Desktop's HTTP transport doesn't ship in time.
- Adding SSE transport. Legacy; not worth the maintenance.
- Changing the bearer-token model, scope-toggle model, audit-log schema, or `user.db` lifecycle.
- Adding tools or resources. The 11 tools and 5 resources are the surface; only how they're carried changes.
- Multi-client concurrency tuning. The first version assumes one MCP client at a time; if real usage shows session contention, that's a separate change.

## Decisions

### S1: Reuse our `HttpServer.bind`; don't let `mcp_dart` own the listener

The package keeps its own `HttpServer.bind(InternetAddress.loopbackIPv4, port)` listener. When an HTTP request arrives, we run two checks before doing anything else:

1. `connectionInfo.remoteAddress.isLoopback` — defence-in-depth; reject `403` if false.
2. `Authorization: Bearer <token>` matches the per-server-start token — reject `401` if missing or wrong.

Only after both pass do we hand the `HttpRequest` / `HttpResponse` to `transport.handleRequest(...)` (or whatever the per-request entry point is named in `mcp_dart` 2.1.1 — verify during implementation).

**Why:** mcp_dart's example `elicitation_http_server.dart` binds `InternetAddress.anyIPv4` by default. We'd have to subclass or wrap it to enforce loopback at the bind layer. Owning the listener means our existing safety semantics stay intact verbatim — the loopback / token logic doesn't move into `mcp_dart`'s transport configuration where a future package update could regress it. The transport just sees pre-validated requests.

**Alternative considered:** let `mcp_dart` own the listener and pass it pre-configured `InternetAddress.loopbackIPv4`. Rejected because the bearer-token gate would have to live inside the transport's request hook, which is opaque to our `isolation_test`. Keeping the gate in `server.dart` keeps it auditable.

### S2: One transport instance per server lifetime; one `McpServer` per server lifetime

We create one `StreamableHTTPServerTransport` and one `McpServer` when `QuranMcpServer.start(port:)` is called, and tear them down on `stop()`. All client sessions multiplex through the same transport via the `mcp-session-id` header.

**Why:** desktop MCP usage is single-user. There's no scenario where two MCP clients legitimately need isolated `McpServer` instances against the same Quran corpus. One transport simplifies session bookkeeping, lifecycle, and the per-call audit trail (sessions can be correlated by `scope_at_time` even across reconnects).

**Risk:** if a future MCP client opens many concurrent sessions, the transport may serialize them. Documented; revisit when observed.

### S3: Resources via `mcp_dart`'s API, not a parallel HTTP path

The five `quran://...` resources get registered through `mcp_dart`'s resource template surface — `s.registerResourceTemplate(...)` or whatever the package's API names it. Our existing `ToolHandlers.readResource(...)` becomes the callback; the dispatcher still wraps each call with scope + audit (resources count as Mode A, always implicit-readonly).

The hand-rolled `/resource/<uri>` path in `server.dart` is deleted. So is `_handleResource` and the `mcpResourcePathPrefix` constant. The `McpDartAdapter.readResource` shortcut becomes vestigial and is deleted (callers now go through the transport).

**Why:** clients discovering tools via the streamable-HTTP transport will also discover resources through it. A separate HTTP path is only useful for our custom curl smoke; once the transport is the protocol, the side-channel is just confusing.

**Risk:** mcp_dart's resource template API at v2.1.1 may not match what we need (URI templates with `{surah}` / `{ayah}` placeholders). If the API is too thin, we register the static resources only and surface dynamic surah/ayah reads as **tools** (`get_surah`, `get_ayah`) which already exist. Worst case: `quran://surah/{surah}` and `quran://ayah/{surah}/{ayah}` only work for the literal URI strings, and clients use the equivalent tools instead. Document this in the README's resources table if we hit that limit.

### S4: Sessions are short-lived, server-scoped, not persisted

`StreamableHTTPServerTransport` requires a `sessionIdGenerator`. We use `Random.secure()` UUID strings. Sessions live in process memory only — when the server stops, sessions die. No cross-restart session resumption.

**Why:** the server lifecycle is "user opens MCP Status → Start → Stop / app exits." Persisting sessions across restarts adds disk state, recovery edge cases, and a privacy surface (which client connected when). The `audit_log` already captures the per-call ground truth; sessions are an ephemeral routing concern.

### S5: Drop the `GET /mcp` discovery endpoint

The realignment shipped a `GET /mcp` that returned `{tools, resources, scopes}` for clients that wanted a quick capability snapshot. With the streamable-HTTP transport, the standard discovery flow is `initialize` → `tools/list` / `resources/list` over the transport. The `GET` endpoint becomes redundant; remove it to keep the surface area small.

**Migration:** any external doc / smoke recipe that fetched `GET /mcp` needs to be rewritten as a `tools/list` JSON-RPC POST. Update the README's curl examples in this same change.

### S6: Test with a real ephemeral HttpServer, not a mock

The new integration test boots `QuranMcpServer.start(port: 0)` (OS-assigned port), grabs `baseUri` and `bearerToken`, then talks to it via `package:http` or `dart:io`'s `HttpClient`. The fakes are `RecordingQuranPort` / `RecordingAudioPort` (already in `test/_fakes/`), so the test stays fast and offline.

**Why:** the streamable-HTTP behaviour we care about is end-to-end: bearer-token gate fires *before* the transport, the transport produces JSON-RPC envelopes, the dispatcher writes audit rows, scope-denied bubbles through the JSON-RPC error path. Mocking the transport defeats the purpose. Booting a real ephemeral server costs ~50 ms per test and exercises the actual production code path.

## Risks / Trade-offs

- **`mcp_dart`'s `StreamableHTTPServerTransport` API at 2.1.1 may differ from the example.** The example uses `transport.handleRequest(req, res)`-style dispatch in some snippets and event-based dispatch in others. Mitigation: implementation reads the actual package source at the pinned version before writing the integration; if the API is significantly different from what the brief assumed, surface as a blocker rather than guessing.
- **Resource templates with placeholders may not work cleanly.** See S3 — fallback is to expose them as tools only (already exist) and document the limitation.
- **One `McpServer` per server lifetime serializes concurrent MCP sessions.** Acceptable for single-user desktop; revisit if a real user complains.
- **Breaking change for anyone scripting against the custom `POST /mcp` shape.** Mitigation: README gets the JSON-RPC equivalent; the change description calls out the breaking compatibility note. No external consumers exist yet (we just shipped the feature this week).
- **`mcp-session-id` header lifecycle is new state to manage.** mcp_dart manages it inside the transport; we surface the session count via `currentScopesCsv()` if useful but don't block on it.

## Migration Plan

1. Read mcp_dart 2.1.1's `StreamableHTTPServerTransport` source to confirm the per-request dispatch entry point. Write a one-line note in this design if the API differs from the brief.
2. Add resource template registration to `mcp_dart_adapter.dart`. Confirm `resources/list` returns the five entries and `resources/read` for the static URIs returns the right payload.
3. Replace `_handleMcp` in `server.dart` with the transport handoff. Keep bearer + loopback gates verbatim.
4. Delete `_handleResource`, `mcpResourcePathPrefix`, the `GET /mcp` discovery branch, and `McpDartAdapter.readResource`.
5. Add the integration test. Boot the server, exercise the four method roundtrips, assert audit rows.
6. Update README "MCP local integration" with JSON-RPC curl examples and an MCP Inspector connection note.
7. Update AGENTS.md *Project state* one line: "streamable HTTP via mcp_dart's StreamableHTTPServerTransport."
8. Verify: `just check` clean, manual MCP Inspector smoke from the running app.

Rollback: revert this PR. The custom HTTP shape returns. Known curl recipes work again.

## Open Questions

- **Does mcp_dart 2.1.1 expose `transport.handleRequest(HttpRequest, HttpResponse)` or do we need to read body, push to a stream, write back manually?** Resolve in step 1 of the migration. If the API forces us to manually shuffle bytes, the diff grows ~50 lines but the design holds.
- **Does mcp_dart's resource template support URI placeholders for `{surah}`, `{ayah}`?** Resolve in step 2. If not, document the limitation; tools cover the same data.
- **Does `mcp-session-id` need to surface to MCP Status?** Default: no. Add only if a user reports session-debugging confusion.
- **Should the README curl examples include a worked initialize → list → call sequence?** Default: yes, three commands. Inspector users won't need them but curl users will.
