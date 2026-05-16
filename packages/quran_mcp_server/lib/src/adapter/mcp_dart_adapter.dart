// ignore_for_file: avoid_dynamic_calls
//
// THIS FILE is the only file in `packages/quran_mcp_server/lib/` permitted to
// import `package:mcp_dart`. The package's `test/isolation_test.dart` enforces
// that constraint at CI time. If the protocol package is ever swapped, the
// adapter is the only file that needs to change.
import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:mcp_dart/mcp_dart.dart' as mcp;

import '../dispatcher.dart';
import '../mcp_error.dart';
import '../tools/tool_handlers.dart';

/// Wraps `package:mcp_dart`'s [mcp.McpServer] + [mcp.StreamableHTTPServerTransport]
/// behind a small surface the HTTP listener in `server.dart` can use.
///
/// Lifecycle: the host owns the [HttpServer.bind] socket and the bearer-token
/// + loopback gates. Once a request passes the gates, it's forwarded to
/// [handleRequest]. Tool and resource registration both wrap their handlers
/// in [Dispatcher] so scope check + audit log run on every call regardless of
/// whether mcp_dart triggers the callback or our test code does.
class McpDartAdapter {
  McpDartAdapter({
    required this.dispatcher,
    required this.serverName,
    required this.serverVersion,
  });

  final Dispatcher dispatcher;
  final String serverName;
  final String serverVersion;

  final Random _rng = Random.secure();

  mcp.McpServer? _server;
  mcp.StreamableHTTPServerTransport? _transport;

  /// Wires the protocol server, registers all tools / resources, instantiates
  /// the streamable HTTP transport, and connects them. Idempotent: calling
  /// twice is a no-op.
  Future<void> start() async {
    if (_server != null) return;

    final s = mcp.McpServer(
      mcp.Implementation(name: serverName, version: serverVersion),
      options: mcp.McpServerOptions(
        capabilities: mcp.ServerCapabilities(
          tools: mcp.ServerCapabilitiesTools(),
          resources: mcp.ServerCapabilitiesResources(),
        ),
      ),
    );

    _registerTools(s);
    _registerResources(s);

    final transport = mcp.StreamableHTTPServerTransport(
      options: mcp.StreamableHTTPServerTransportOptions(
        sessionIdGenerator: _generateSessionId,
        // We already enforce loopback on the listener AND per-request via
        // connectionInfo.remoteAddress.isLoopback. Disabling mcp_dart's
        // built-in DNS-rebinding/host-allowlist check avoids spurious
        // rejections when a local client doesn't set Host: localhost
        // (e.g., curl with the IP literal in the URL).
        enableDnsRebindingProtection: false,
        // Plain JSON responses are simpler than SSE for our request/response
        // workload. Streaming MCP features (notifications, progress) work
        // either way; the choice only affects single-call response framing.
        enableJsonResponse: true,
      ),
    );

    await s.connect(transport);

    _server = s;
    _transport = transport;
  }

  /// Tears down the protocol server and transport. Safe to call before
  /// [start] (no-op).
  Future<void> stop() async {
    final transport = _transport;
    final server = _server;
    _transport = null;
    _server = null;
    if (transport != null) {
      await transport.close();
    }
    if (server != null) {
      await server.close();
    }
  }

  /// Forwards an authorized HTTP request to the streamable HTTP transport.
  /// Caller MUST have already verified the bearer token + loopback origin.
  Future<void> handleRequest(HttpRequest request) async {
    final transport = _transport;
    if (transport == null) {
      request.response.statusCode = HttpStatus.serviceUnavailable;
      await request.response.close();
      return;
    }
    await transport.handleRequest(request);
  }

  void _registerTools(mcp.McpServer s) {
    for (final def in mcpToolDefinitions) {
      final name = def.name;
      s.registerTool(
        name,
        description: def.description,
        callback: (args, extra) => _runTool(name, args),
      );
    }
  }

  void _registerResources(mcp.McpServer s) {
    for (final def in mcpResourceDefinitions) {
      assert(def.uri.startsWith('quran://'));
      // Templated URIs (`quran://surah/{surah}`, `quran://ayah/{surah}/{ayah}`)
      // are intentionally not registered as mcp_dart resource templates in
      // this first cut. Clients use the equivalent tools (`get_surah`,
      // `get_ayah`) — same dispatcher, same audit row. A follow-up can
      // promote them via `s.registerResourceTemplate(...)` once we want
      // resource-style enumeration.
      if (def.uri.contains('{')) continue;

      s.registerResource(
        def.name,
        def.uri,
        const (description: null, mimeType: 'application/json'),
        (uri, extra) async {
          final result = await dispatcher.readResource(uri.toString());
          if (result.isError) {
            // mcp_dart catches the throw and wraps it as a JSON-RPC error.
            // The dispatcher already wrote the audit row before we got here.
            throw McpException(result.error!);
          }
          return mcp.ReadResourceResult(
            contents: [
              mcp.TextResourceContents(
                uri: uri.toString(),
                mimeType: 'application/json',
                text: jsonEncode(result.data),
              ),
            ],
          );
        },
      );
    }
  }

  Future<mcp.CallToolResult> _runTool(
    String name,
    Map<String, dynamic> args,
  ) async {
    final result = await dispatcher.callTool(
      name,
      Map<String, Object?>.from(args),
    );
    if (result.isError) {
      return mcp.CallToolResult(
        isError: true,
        content: [mcp.TextContent(text: jsonEncode(result.error!.toJson()))],
      );
    }
    return mcp.CallToolResult(
      content: [mcp.TextContent(text: jsonEncode(result.data))],
    );
  }

  String _generateSessionId() {
    // 16 random bytes rendered as a 32-char lowercase hex string.
    final bytes = List<int>.generate(16, (_) => _rng.nextInt(256));
    return bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
  }
}
