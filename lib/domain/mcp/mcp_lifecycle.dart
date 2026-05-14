enum McpServerLifecycle { disabled, starting, running, stopped, failed }

class McpServerStatus {
  const McpServerStatus({
    required this.lifecycle,
    this.message,
    this.localOnly = true,
  });

  const McpServerStatus.disabled()
    : lifecycle = McpServerLifecycle.disabled,
      message = null,
      localOnly = true;

  final McpServerLifecycle lifecycle;
  final String? message;
  final bool localOnly;

  McpServerStatus copyWith({
    McpServerLifecycle? lifecycle,
    String? message,
    bool clearMessage = false,
    bool? localOnly,
  }) {
    return McpServerStatus(
      lifecycle: lifecycle ?? this.lifecycle,
      message: clearMessage ? null : message ?? this.message,
      localOnly: localOnly ?? this.localOnly,
    );
  }
}
