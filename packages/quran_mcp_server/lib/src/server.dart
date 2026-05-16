import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'adapter/mcp_dart_adapter.dart';
import 'audit/audit_log_repository.dart';
import 'dispatcher.dart';
import 'mcp_lifecycle.dart';
import 'ports.dart';
import 'scopes/scope.dart';
import 'tools/tool_handlers.dart';

const mcpEndpointPath = '/mcp';

/// Top-level handle for a running MCP server. Constructed by the host app
/// composition layer with the four ports + scope check.
///
/// Spec mcp-server (post `add-streamable-http-transport`):
/// - Plain HTTP on `127.0.0.1` (loopback enforced at bind + per-request).
/// - Bearer-token gate runs *before* mcp_dart's `StreamableHTTPServerTransport`
///   sees a request. Unauthorized → `401`, no transport invocation, no
///   `mcp-session-id` issued.
/// - Standard JSON-RPC `2.0` wire protocol via mcp_dart's transport.
/// - Per-tool/per-resource calls flow through [Dispatcher] for scope check
///   + audit log.
class QuranMcpServer {
  QuranMcpServer({
    required McpQuranDataPort quran,
    required McpAudioPort audio,
    required ScopeCheck scopeCheck,
    AuditLogRepository? audit,
    String name = 'quran-companion',
    String version = '0.1.0',
  }) : _scopeCheck = scopeCheck,
       _adapter = McpDartAdapter(
         dispatcher: Dispatcher(
           handlers: ToolHandlers(quran: quran, audio: audio),
           scopeCheck: scopeCheck,
           audit: audit,
         ),
         serverName: name,
         serverVersion: version,
       );

  final ScopeCheck _scopeCheck;
  final McpDartAdapter _adapter;
  final Random _random = Random.secure();

  HttpServer? _httpServer;
  String? _bearerToken;
  Uri? _baseUri;

  /// Spec mcp-server: server SHALL bind plain HTTP to 127.0.0.1 only.
  static final InternetAddress _loopback = InternetAddress.loopbackIPv4;

  String? get bearerToken => _bearerToken;
  Uri? get baseUri => _baseUri;
  bool get isRunning => _httpServer != null;

  /// Snapshot of the scopes that are currently ON. Re-evaluated on each call
  /// so the MCP Status page can render live state.
  String currentScopesCsv() => _scopeCheck.snapshotCsv();

  /// Starts the listener. Returns lifecycle status describing the bound URL
  /// and the per-server-start bearer token. Throws on bind failure (caller
  /// should surface a `failed` lifecycle).
  Future<McpServerStatus> start({required int port}) async {
    if (_httpServer != null) {
      throw StateError('QuranMcpServer.start called while already running');
    }

    // Wire mcp_dart's McpServer + StreamableHTTPServerTransport BEFORE
    // accepting any requests so the very first authorized request finds the
    // transport ready.
    await _adapter.start();

    final server = await HttpServer.bind(_loopback, port);
    final boundPort = server.port;
    _httpServer = server;
    _bearerToken = _generateToken();
    _baseUri = Uri.parse('http://127.0.0.1:$boundPort$mcpEndpointPath');

    // ignore: unawaited_futures
    _serve(server);

    return McpServerStatus(
      lifecycle: McpServerLifecycle.running,
      uri: _baseUri,
      authToken: _bearerToken,
    );
  }

  Future<void> stop() async {
    final server = _httpServer;
    _httpServer = null;
    _bearerToken = null;
    _baseUri = null;
    if (server != null) {
      await server.close(force: true);
    }
    await _adapter.stop();
  }

  Future<void> _serve(HttpServer server) async {
    await for (final request in server) {
      // Defence-in-depth: even though we bind 127.0.0.1, double-check the
      // remote address is loopback before accepting any payload.
      final remote = request.connectionInfo?.remoteAddress;
      if (remote == null || !remote.isLoopback) {
        request.response.statusCode = HttpStatus.forbidden;
        await request.response.close();
        continue;
      }

      // Bearer-token gate runs BEFORE mcp_dart sees the request. Unauthorized
      // requests never reach the transport, never create a session, never
      // touch the dispatcher.
      final auth = request.headers.value(HttpHeaders.authorizationHeader);
      final expected = 'Bearer ${_bearerToken ?? ''}';
      if (_bearerToken == null || auth != expected) {
        request.response.statusCode = HttpStatus.unauthorized;
        request.response.headers.add('WWW-Authenticate', 'Bearer');
        await request.response.close();
        continue;
      }

      // Only the MCP endpoint path is exposed. Everything else 404s without
      // the transport seeing it.
      if (request.uri.path != mcpEndpointPath) {
        request.response.statusCode = HttpStatus.notFound;
        await request.response.close();
        continue;
      }

      try {
        await _adapter.handleRequest(request);
      } on Object catch (e) {
        // mcp_dart's transport is responsible for writing JSON-RPC error
        // responses for protocol-level failures. This catch is for failures
        // upstream of the transport (e.g., the response was already started
        // and the underlying connection dropped). We log and move on.
        _logTransportFailure(e);
      }
    }
  }

  void _logTransportFailure(Object error) {
    // The package is Flutter-free; no appLogger here. The host app reads
    // mcpServerControllerProvider for lifecycle state and surfaces failures
    // via that channel. Stderr is the only thing available cross-platform.
    stderr.writeln('[quran_mcp_server] transport failure: $error');
  }

  String _generateToken() {
    final bytes = List<int>.generate(32, (_) => _random.nextInt(256));
    return base64UrlEncode(bytes).replaceAll('=', '');
  }
}
