// ignore_for_file: avoid_dynamic_calls
//
// THIS FILE is the only file in `packages/quran_mcp_server/lib/` permitted to
// import `package:mcp_dart`. The package's `test/isolation_test.dart` enforces
// that constraint at CI time. If the protocol package is ever swapped, the
// adapter is the only file that needs to change.
import 'dart:convert';

import 'package:mcp_dart/mcp_dart.dart' as mcp;

import '../dispatcher.dart';
import '../tools/tool_handlers.dart';

class McpDartAdapter {
  McpDartAdapter({
    required this.dispatcher,
    required this.serverName,
    required this.serverVersion,
  });

  final Dispatcher dispatcher;
  final String serverName;
  final String serverVersion;

  late final mcp.McpServer _server = _build();

  mcp.McpServer get protocolServer => _server;

  mcp.McpServer _build() {
    final s = mcp.McpServer(
      mcp.Implementation(name: serverName, version: serverVersion),
      options: mcp.McpServerOptions(
        capabilities: mcp.ServerCapabilities(
          tools: mcp.ServerCapabilitiesTools(),
          resources: mcp.ServerCapabilitiesResources(),
        ),
      ),
    );

    for (final def in mcpToolDefinitions) {
      final name = def.name;
      s.registerTool(
        name,
        description: def.description,
        callback: (args, extra) => _runTool(name, args),
      );
    }

    for (final def in mcpResourceDefinitions) {
      // mcp_dart's resource template registration shape varies between
      // versions; we expose resources via a dedicated read-resource
      // endpoint on the HTTP layer until we have a stable surface here.
      // The server's tool surface still includes get_ayah / get_surah /
      // list_surahs which cover the same data.
      assert(def.uri.startsWith('quran://'));
    }

    return s;
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

  /// Convenience for direct resource reads from the HTTP layer (the package
  /// keeps the resource read path off mcp_dart's surface for now — see the
  /// note in [_build]).
  Future<DispatchResult> readResource(String uri) {
    return dispatcher.readResource(uri);
  }
}
