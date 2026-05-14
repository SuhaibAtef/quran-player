import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:mcp_server/mcp_server.dart' as mcp;

import '../../domain/mcp/mcp_error.dart' as app_mcp;
import 'mcp_server_service.dart';

const mcpLocalHost = '127.0.0.1';
const mcpEndpointPath = '/mcp';

class McpHttpServerHandle {
  McpHttpServerHandle({
    required this.uri,
    required this.authToken,
    required mcp.Server server,
  }) : _server = server;

  final Uri uri;
  final String authToken;
  final mcp.Server _server;
  bool _stopped = false;

  Future<void> stop() async {
    if (_stopped) return;
    _stopped = true;
    _server.dispose();
  }
}

class McpHttpServerFactory {
  const McpHttpServerFactory();

  Future<McpHttpServerHandle> start(McpServerService service) async {
    final port = await _reserveLoopbackPort();
    final token = generateMcpAuthToken();
    final uri = Uri.parse('http://$mcpLocalHost:$port$mcpEndpointPath');
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
      resource: uri.toString(),
      authorizationServers: const ['urn:quran-companion:local-token'],
      bearerMethodsSupported: const ['header'],
      scopesSupported: const ['quran:read', 'playback:control'],
    );
    _registerTools(server, service);
    _registerResources(server, service);

    final transportResult =
        await mcp.McpServer.createStreamableHttpTransportAsync(
          port,
          host: mcpLocalHost,
          endpoint: mcpEndpointPath,
          fallbackPorts: const [],
          isJsonResponseEnabled: true,
          authToken: token,
        );
    final transport = transportResult.get();
    server.connect(transport);
    return McpHttpServerHandle(uri: uri, authToken: token, server: server);
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
