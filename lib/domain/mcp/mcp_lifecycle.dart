enum McpServerLifecycle { disabled, starting, running, stopped, failed }

class McpServerStatus {
  const McpServerStatus({
    required this.lifecycle,
    this.message,
    this.localOnly = true,
    this.uri,
    this.authToken,
  });

  const McpServerStatus.disabled()
    : lifecycle = McpServerLifecycle.disabled,
      message = null,
      localOnly = true,
      uri = null,
      authToken = null;

  final McpServerLifecycle lifecycle;
  final String? message;
  final bool localOnly;
  final Uri? uri;
  final String? authToken;

  McpServerStatus copyWith({
    McpServerLifecycle? lifecycle,
    String? message,
    bool clearMessage = false,
    bool? localOnly,
    Uri? uri,
    String? authToken,
    bool clearConnection = false,
  }) {
    return McpServerStatus(
      lifecycle: lifecycle ?? this.lifecycle,
      message: clearMessage ? null : message ?? this.message,
      localOnly: localOnly ?? this.localOnly,
      uri: clearConnection ? null : uri ?? this.uri,
      authToken: clearConnection ? null : authToken ?? this.authToken,
    );
  }
}
