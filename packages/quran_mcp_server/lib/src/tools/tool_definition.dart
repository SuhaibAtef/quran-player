/// Tool / resource metadata surfaced via the MCP `list_tools` /
/// `list_resources` calls.
class McpToolDefinition {
  const McpToolDefinition({
    required this.name,
    required this.description,
    required this.inputSchema,
  });

  final String name;
  final String description;
  final Map<String, Object?> inputSchema;

  Map<String, Object?> toJson() => {
    'name': name,
    'description': description,
    'inputSchema': inputSchema,
  };
}

class McpResourceDefinition {
  const McpResourceDefinition({required this.uri, required this.name});

  final String uri;
  final String name;

  Map<String, Object?> toJson() => {'uri': uri, 'name': name};
}
