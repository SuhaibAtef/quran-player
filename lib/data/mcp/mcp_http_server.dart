import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:basic_utils/basic_utils.dart';
import 'package:mcp_server/mcp_server.dart' as mcp;

import '../../domain/mcp/mcp_error.dart' as app_mcp;
import 'mcp_server_service.dart';

const mcpLocalHost = '127.0.0.1';
const mcpPublicHost = 'localhost';
const mcpEndpointPath = '/mcp';

class McpHttpServerHandle {
  McpHttpServerHandle._({
    required this.uri,
    required this.authToken,
    required mcp.Server server,
    required _LoopbackHttpsProxy proxy,
  }) : _server = server,
       _proxy = proxy;

  final Uri uri;
  final String authToken;
  final mcp.Server _server;
  final _LoopbackHttpsProxy _proxy;
  bool _stopped = false;

  Future<void> stop() async {
    if (_stopped) return;
    _stopped = true;
    await _proxy.close();
    _server.dispose();
  }
}

class McpHttpServerFactory {
  const McpHttpServerFactory();

  Future<McpHttpServerHandle> start(McpServerService service) async {
    final backendPort = await _reserveLoopbackPort();
    final proxyPort = await _reserveLoopbackPort();
    final token = generateMcpAuthToken();
    final publicUri = Uri.parse(
      'https://$mcpPublicHost:$proxyPort$mcpEndpointPath',
    );
    final server = mcp.Server(
      name: 'Quran Companion',
      version: '0.1.0',
      capabilities: mcp.ServerCapabilities.simple(
        tools: true,
        toolsListChanged: true,
        resources: true,
        resourcesListChanged: true,
      ),
    );
    server.configureProtectedResource(
      resource: publicUri.toString(),
      authorizationServers: const ['urn:quran-companion:local-token'],
      bearerMethodsSupported: const ['header'],
      scopesSupported: const ['quran:read', 'playback:control'],
    );
    _registerTools(server, service);
    _registerResources(server, service);

    final transportResult =
        await mcp.McpServer.createStreamableHttpTransportAsync(
          backendPort,
          host: mcpLocalHost,
          endpoint: mcpEndpointPath,
          fallbackPorts: const [],
          isJsonResponseEnabled: true,
          authToken: token,
        );
    final transport = transportResult.get();
    server.connect(transport);
    try {
      final proxy = await _LoopbackHttpsProxy.start(
        port: proxyPort,
        targetPort: backendPort,
        context: _ephemeralLocalhostSecurityContext(),
      );
      return McpHttpServerHandle._(
        uri: publicUri,
        authToken: token,
        server: server,
        proxy: proxy,
      );
    } on Object {
      server.dispose();
      rethrow;
    }
  }
}

String generateMcpAuthToken({int byteLength = 32}) {
  final random = Random.secure();
  final bytes = List<int>.generate(byteLength, (_) => random.nextInt(256));
  return base64Url.encode(bytes).replaceAll('=', '');
}

Future<int> _reserveLoopbackPort() async {
  final socket = await ServerSocket.bind(InternetAddress.loopbackIPv4, 0);
  final port = socket.port;
  await socket.close();
  return port;
}

SecurityContext _ephemeralLocalhostSecurityContext() {
  final keyPair = CryptoUtils.generateRSAKeyPair(keySize: 2048);
  final privateKey = keyPair.privateKey as RSAPrivateKey;
  final publicKey = keyPair.publicKey as RSAPublicKey;
  final sans = [mcpPublicHost];
  final csr = X509Utils.generateRsaCsrPem(
    {'CN': mcpPublicHost},
    privateKey,
    publicKey,
    san: sans,
  );
  final certificate = X509Utils.generateSelfSignedCertificate(
    privateKey,
    csr,
    1,
    sans: sans,
    extKeyUsage: [ExtendedKeyUsage.SERVER_AUTH],
    cA: false,
    serialNumber: _positiveSerialNumber(),
    notBefore: DateTime.now().subtract(const Duration(minutes: 5)),
  );
  final privateKeyPem = CryptoUtils.encodeRSAPrivateKeyToPem(privateKey);
  final context = SecurityContext();
  context.useCertificateChainBytes(utf8.encode(certificate));
  context.usePrivateKeyBytes(utf8.encode(privateKeyPem));
  return context;
}

String _positiveSerialNumber() {
  final random = Random.secure();
  final high = random.nextInt(1 << 31);
  final low = random.nextInt(1 << 31);
  return ((BigInt.from(high) << 31) | BigInt.from(low)).toString();
}

class _LoopbackHttpsProxy {
  _LoopbackHttpsProxy._(this._server, this._targetPort);

  final HttpServer _server;
  final int _targetPort;
  final HttpClient _client = HttpClient();

  static Future<_LoopbackHttpsProxy> start({
    required int port,
    required int targetPort,
    required SecurityContext context,
  }) async {
    final server = await HttpServer.bindSecure(
      InternetAddress.loopbackIPv4,
      port,
      context,
    );
    final proxy = _LoopbackHttpsProxy._(server, targetPort);
    server.listen(proxy._handleRequest);
    return proxy;
  }

  Future<void> close() async {
    _client.close(force: true);
    await _server.close(force: true);
  }

  Future<void> _handleRequest(HttpRequest request) async {
    try {
      final target = Uri(
        scheme: 'http',
        host: mcpLocalHost,
        port: _targetPort,
        path: request.uri.path,
        query: request.uri.query,
      );
      final upstreamRequest = await _client.openUrl(request.method, target);
      _copyHeaders(request.headers, upstreamRequest.headers);
      await for (final chunk in request) {
        upstreamRequest.add(chunk);
      }
      final upstreamResponse = await upstreamRequest.close();
      request.response.statusCode = upstreamResponse.statusCode;
      _copyHeaders(upstreamResponse.headers, request.response.headers);
      await upstreamResponse.pipe(request.response);
    } on Object catch (e) {
      request.response.statusCode = HttpStatus.badGateway;
      request.response.headers.contentType = ContentType.json;
      request.response.write(
        jsonEncode({'error': 'MCP HTTPS proxy failed: $e'}),
      );
      await request.response.close();
    }
  }
}

void _copyHeaders(HttpHeaders from, HttpHeaders to) {
  from.forEach((name, values) {
    if (_hopByHopHeaders.contains(name.toLowerCase())) return;
    to.set(name, values);
  });
}

const _hopByHopHeaders = {
  'connection',
  'content-length',
  'host',
  'keep-alive',
  'proxy-authenticate',
  'proxy-authorization',
  'te',
  'trailer',
  'transfer-encoding',
  'upgrade',
};

void _registerTools(mcp.Server server, McpServerService service) {
  for (final tool in service.listTools()) {
    server.addTool(
      name: tool.name,
      description: tool.description,
      inputSchema: _inputSchemaFor(tool.name),
      handler: (arguments) async {
        try {
          final result = await service.callTool(tool.name, arguments);
          return _toolOk(result);
        } on app_mcp.McpException catch (e) {
          return _toolError(e.error.toJson());
        } on Object catch (e) {
          return _toolError({'code': 'unknown', 'message': '$e'});
        }
      },
    );
  }
}

void _registerResources(mcp.Server server, McpServerService service) {
  for (final resource in service.listResources()) {
    server.addResource(
      uri: resource.uri,
      name: resource.name,
      description: resource.name,
      mimeType: 'application/json',
      uriTemplate: resource.uri.contains('{') ? {'isTemplate': true} : null,
      handler: (uri, params) async {
        try {
          final result = await service.readResource(uri);
          return mcp.ReadResourceResult(
            contents: [
              mcp.ResourceContentInfo(
                uri: uri,
                mimeType: 'application/json',
                text: jsonEncode(_jsonMap(result)),
              ),
            ],
          );
        } on app_mcp.McpException catch (e) {
          throw mcp.McpError(e.error.message);
        }
      },
    );
  }
}

mcp.CallToolResult _toolOk(Map<String, Object?> result) {
  final structured = _jsonMap(result);
  return mcp.CallToolResult(
    content: [mcp.TextContent(text: jsonEncode(structured))],
    structuredContent: structured,
  );
}

mcp.CallToolResult _toolError(Map<String, Object?> error) {
  final structured = {'error': _jsonMap(error)};
  return mcp.CallToolResult(
    content: [mcp.TextContent(text: jsonEncode(structured))],
    structuredContent: structured,
    isError: true,
  );
}

Map<String, dynamic> _jsonMap(Map<String, Object?> value) {
  return jsonDecode(jsonEncode(value)) as Map<String, dynamic>;
}

Map<String, dynamic> _inputSchemaFor(String toolName) {
  return switch (toolName) {
    'search_quran' => _objectSchema(
      {
        'query': _stringSchema('Arabic search query'),
        'limit': _integerSchema(
          'Maximum results, 1..50',
          minimum: 1,
          maximum: 50,
        ),
      },
      required: ['query'],
    ),
    'get_ayah' || 'play_ayah' => _objectSchema(
      {
        'surah': _integerSchema(
          'Surah number, 1..114',
          minimum: 1,
          maximum: 114,
        ),
        'ayah': _integerSchema('Ayah number', minimum: 1),
        'clientName': _stringSchema('Local MCP client name'),
      },
      required: ['surah', 'ayah'],
    ),
    'get_surah' || 'play_surah' => _objectSchema(
      {
        'surah': _integerSchema(
          'Surah number, 1..114',
          minimum: 1,
          maximum: 114,
        ),
        'clientName': _stringSchema('Local MCP client name'),
      },
      required: ['surah'],
    ),
    'set_repeat' => _objectSchema(
      {
        'mode': {
          'type': 'string',
          'enum': ['off'],
          'description': 'Repeat mode. Only off is supported today.',
        },
        'clientName': _stringSchema('Local MCP client name'),
      },
      required: ['mode'],
    ),
    _ => _objectSchema({'clientName': _stringSchema('Local MCP client name')}),
  };
}

Map<String, dynamic> _objectSchema(
  Map<String, dynamic> properties, {
  List<String> required = const [],
}) {
  return {
    'type': 'object',
    'properties': properties,
    'required': required,
    'additionalProperties': false,
  };
}

Map<String, dynamic> _stringSchema(String description) {
  return {'type': 'string', 'description': description};
}

Map<String, dynamic> _integerSchema(
  String description, {
  int? minimum,
  int? maximum,
}) {
  final schema = <String, dynamic>{
    'type': 'integer',
    'description': description,
  };
  if (minimum != null) schema['minimum'] = minimum;
  if (maximum != null) schema['maximum'] = maximum;
  return schema;
}
