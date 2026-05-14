import 'dart:convert';

import '../../domain/mcp/mcp_error.dart';
import 'mcp_server_service.dart';

class McpProtocolHandler {
  const McpProtocolHandler(this._service);

  final McpServerService _service;

  Future<String> handleLine(String line) async {
    final decoded = jsonDecode(line);
    if (decoded is! Map<String, Object?>) {
      return _error(null, 'invalidInput', 'Request must be a JSON object.');
    }
    final id = decoded['id'];
    final method = decoded['method'];
    if (method is! String) {
      return _error(id, 'invalidInput', 'Request method must be a string.');
    }
    try {
      final result = await _dispatch(method, decoded['params']);
      return jsonEncode({'jsonrpc': '2.0', 'id': id, 'result': result});
    } on McpException catch (e) {
      return _error(id, e.error.code.name, e.error.message);
    } on Object catch (e) {
      return _error(id, 'unknown', '$e');
    }
  }

  Future<Object?> _dispatch(String method, Object? params) async {
    return switch (method) {
      'initialize' => {
        'serverInfo': {'name': 'quran-companion', 'version': '0.1.0'},
        'capabilities': {
          'tools': true,
          'resources': true,
          'transport': 'stdio',
          'localOnly': true,
        },
      },
      'tools/list' => {
        'tools': _service.listTools().map((t) => t.toJson()).toList(),
      },
      'resources/list' => {
        'resources': _service.listResources().map((r) => r.toJson()).toList(),
      },
      'tools/call' => _callTool(params),
      'resources/read' => _readResource(params),
      _ => throw McpException(
        McpError(McpErrorCode.invalidInput, 'Unknown method: $method'),
      ),
    };
  }

  Future<Map<String, Object?>> _callTool(Object? params) async {
    if (params is! Map<String, Object?>) {
      throw const McpException(
        McpError(McpErrorCode.invalidInput, 'tools/call params are required.'),
      );
    }
    final name = params['name'];
    if (name is! String) {
      throw const McpException(
        McpError(McpErrorCode.invalidInput, 'Tool name is required.'),
      );
    }
    final args = params['arguments'];
    return _service.callTool(
      name,
      args is Map<String, Object?> ? args : const {},
    );
  }

  Future<Map<String, Object?>> _readResource(Object? params) async {
    if (params is! Map<String, Object?>) {
      throw const McpException(
        McpError(
          McpErrorCode.invalidInput,
          'resources/read params are required.',
        ),
      );
    }
    final uri = params['uri'];
    if (uri is! String) {
      throw const McpException(
        McpError(McpErrorCode.invalidInput, 'Resource uri is required.'),
      );
    }
    return _service.readResource(uri);
  }

  String _error(Object? id, String code, String message) {
    return jsonEncode({
      'jsonrpc': '2.0',
      'id': id,
      'error': {'code': code, 'message': message},
    });
  }
}
