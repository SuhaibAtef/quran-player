import 'package:flutter/widgets.dart';
import 'package:forui/forui.dart';

class McpStatusPageKeys {
  const McpStatusPageKeys._();

  static const title = Key('mcp_status.title');
  static const body = Key('mcp_status.body');
}

class McpStatusPage extends StatelessWidget {
  const McpStatusPage({super.key});

  @override
  Widget build(BuildContext context) {
    return FScaffold(
      header: const FHeader(
        title: Text('MCP Status', key: McpStatusPageKeys.title),
      ),
      child: const Center(
        key: McpStatusPageKeys.body,
        child: Text('Local MCP server status and toggles will live here.'),
      ),
    );
  }
}
