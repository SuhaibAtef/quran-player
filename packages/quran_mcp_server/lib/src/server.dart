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
const mcpResourcePathPrefix = '/resource/';

/// Top-level handle for a running MCP server. Constructed by the host app
/// composition layer with the four ports + scope check.
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
  final _Random _random = _Random();

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

      final auth = request.headers.value(HttpHeaders.authorizationHeader);
      final expected = 'Bearer ${_bearerToken ?? ''}';
      if (_bearerToken == null || auth != expected) {
        request.response.statusCode = HttpStatus.unauthorized;
        request.response.headers.add('WWW-Authenticate', 'Bearer');
        await request.response.close();
        continue;
      }

      try {
        await _handle(request);
      } on Object catch (e) {
        request.response.statusCode = HttpStatus.internalServerError;
        request.response.write(jsonEncode({'error': e.toString()}));
        await request.response.close();
      }
    }
  }

  Future<void> _handle(HttpRequest request) async {
    final path = request.uri.path;
    if (path == mcpEndpointPath) {
      return _handleMcp(request);
    }
    if (path.startsWith(mcpResourcePathPrefix)) {
      final uri = path.substring(mcpResourcePathPrefix.length);
      return _handleResource(request, Uri.decodeComponent(uri));
    }
    request.response.statusCode = HttpStatus.notFound;
    await request.response.close();
  }

  Future<void> _handleMcp(HttpRequest request) async {
    if (request.method == 'GET') {
      // Discovery: return tool + resource metadata. Some MCP clients call
      // this before opening the streamable session.
      request.response.headers.contentType = ContentType.json;
      request.response.write(
        jsonEncode({
          'tools': mcpToolDefinitions.map((t) => t.toJson()).toList(),
          'resources': mcpResourceDefinitions.map((r) => r.toJson()).toList(),
          'scopes': currentScopesCsv(),
        }),
      );
      await request.response.close();
      return;
    }

    if (request.method != 'POST') {
      request.response.statusCode = HttpStatus.methodNotAllowed;
      await request.response.close();
      return;
    }

    final body = await utf8.decoder.bind(request).join();
    final payload = body.isEmpty
        ? const <String, Object?>{}
        : jsonDecode(body) as Map<String, Object?>;

    final method = payload['method'] as String?;
    final params =
        (payload['params'] as Map?)?.cast<String, Object?>() ??
        const <String, Object?>{};

    if (method == 'tools/list') {
      request.response.headers.contentType = ContentType.json;
      request.response.write(
        jsonEncode({
          'tools': mcpToolDefinitions.map((t) => t.toJson()).toList(),
        }),
      );
      await request.response.close();
      return;
    }

    if (method == 'resources/list') {
      request.response.headers.contentType = ContentType.json;
      request.response.write(
        jsonEncode({
          'resources': mcpResourceDefinitions.map((r) => r.toJson()).toList(),
        }),
      );
      await request.response.close();
      return;
    }

    if (method == 'tools/call') {
      final name = params['name'] as String? ?? '';
      final args =
          (params['arguments'] as Map?)?.cast<String, Object?>() ??
          const <String, Object?>{};
      final result = await _adapter.dispatcher.callTool(name, args);
      request.response.headers.contentType = ContentType.json;
      if (result.isError) {
        request.response.write(jsonEncode({'error': result.error!.toJson()}));
      } else {
        request.response.write(jsonEncode({'result': result.data}));
      }
      await request.response.close();
      return;
    }

    if (method == 'resources/read') {
      final uri = params['uri'] as String? ?? '';
      final result = await _adapter.readResource(uri);
      request.response.headers.contentType = ContentType.json;
      if (result.isError) {
        request.response.write(jsonEncode({'error': result.error!.toJson()}));
      } else {
        request.response.write(jsonEncode({'result': result.data}));
      }
      await request.response.close();
      return;
    }

    request.response.statusCode = HttpStatus.badRequest;
    request.response.write(
      jsonEncode({
        'error': {
          'code': 'invalid_input',
          'message': 'Unsupported MCP method.',
        },
      }),
    );
    await request.response.close();
  }

  Future<void> _handleResource(HttpRequest request, String uri) async {
    final result = await _adapter.readResource(uri);
    request.response.headers.contentType = ContentType.json;
    if (result.isError) {
      request.response.statusCode = HttpStatus.badRequest;
      request.response.write(jsonEncode({'error': result.error!.toJson()}));
    } else {
      request.response.write(jsonEncode(result.data));
    }
    await request.response.close();
  }

  String _generateToken() {
    final bytes = List<int>.generate(32, (_) => _random.nextInt(256));
    return base64UrlEncode(bytes).replaceAll('=', '');
  }
}

class _Random {
  _Random();
  final Random _rng = Random.secure();
  int nextInt(int max) => _rng.nextInt(max);
}
