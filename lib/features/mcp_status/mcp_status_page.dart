import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:forui/forui.dart';
import 'package:quran_mcp_server/quran_mcp_server.dart';

import '../../app/state/mcp_server_provider.dart';
import '../../app/state/mcp_settings_provider.dart';

class McpStatusPageKeys {
  const McpStatusPageKeys._();

  static const title = Key('mcp_status.title');
  static const body = Key('mcp_status.body');
  static const lifecycle = Key('mcp_status.lifecycle');
  static const localOnly = Key('mcp_status.local_only');
  static const uri = Key('mcp_status.uri');
  static const token = Key('mcp_status.token');
  static const tools = Key('mcp_status.tools');
  static const resources = Key('mcp_status.resources');
  static const scopes = Key('mcp_status.scopes');
  static const recent = Key('mcp_status.recent');
}

class McpStatusPage extends ConsumerWidget {
  const McpStatusPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final status = ref.watch(mcpServerControllerProvider);
    final controller = ref.read(mcpServerControllerProvider.notifier);
    final settings = ref.watch(mcpSettingsControllerProvider);
    final small = context.theme.typography.sm;
    final starting = status.lifecycle == McpServerLifecycle.starting;
    final running = status.lifecycle == McpServerLifecycle.running;

    return FScaffold(
      header: const FHeader(
        title: Text('MCP Status', key: McpStatusPageKeys.title),
      ),
      child: SingleChildScrollView(
        key: McpStatusPageKeys.body,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _Section(
              key: McpStatusPageKeys.lifecycle,
              title: 'Server',
              children: [
                Text('State: ${_lifecycleLabel(status.lifecycle)}'),
                if (status.message != null) Text(status.message!),
                const SizedBox(height: 8),
                Row(
                  children: [
                    if (!running)
                      FButton(
                        onPress: starting ? null : controller.start,
                        prefix: const Icon(FIcons.play),
                        child: const Text('Start MCP Server'),
                      )
                    else
                      FButton(
                        variant: FButtonVariant.outline,
                        onPress: controller.stop,
                        prefix: const Icon(FIcons.square),
                        child: const Text('Stop MCP Server'),
                      ),
                  ],
                ),
              ],
            ),
            _Section(
              key: McpStatusPageKeys.localOnly,
              title: 'Transport',
              children: [
                const Text(
                  'Local-only HTTP MCP transport on the loopback interface. '
                  'Bearer-token auth gates every request before mcp_dart sees it.',
                ),
                const SizedBox(height: 2),
                const Text(
                  'Remote access, filesystem tools, and shell commands are not '
                  'exposed. Use the URL and bearer token with a local MCP client '
                  'while this app is running.',
                ),
                if (status.uri != null && status.authToken != null) ...[
                  const SizedBox(height: 8),
                  _ConnectionValueField(
                    key: McpStatusPageKeys.uri,
                    label: 'URL',
                    value: '${status.uri}',
                  ),
                  const SizedBox(height: 2),
                  _ConnectionValueField(
                    key: McpStatusPageKeys.token,
                    label: 'Token',
                    value: status.authToken!,
                  ),
                ],
              ],
            ),
            _Section(
              key: McpStatusPageKeys.scopes,
              title: 'Active scopes',
              children: [
                if (!settings.enabled)
                  const Text(
                    'MCP is disabled. Enable it in Settings to grant scopes.',
                  )
                else ...[
                  Text('readonly: on (master toggle implies)'),
                  Text('playback: ${settings.scopePlayback ? 'on' : 'off'}'),
                  Text(
                    'bookmark: ${settings.scopeBookmark ? 'on' : 'off'} '
                    '(reserved — no tools gate on this yet)',
                  ),
                ],
              ],
            ),
            _Section(
              key: McpStatusPageKeys.tools,
              title: 'Tools (${mcpToolDefinitions.length})',
              children: [
                Text(
                  mcpToolDefinitions.map((t) => t.name).join(', '),
                  style: small,
                ),
              ],
            ),
            _Section(
              key: McpStatusPageKeys.resources,
              title: 'Resources (${mcpResourceDefinitions.length})',
              children: [
                Text(
                  mcpResourceDefinitions.map((r) => r.uri).join(', '),
                  style: small,
                ),
              ],
            ),
            const _RecentAuditSection(),
          ],
        ),
      ),
    );
  }
}

class _RecentAuditSection extends ConsumerWidget {
  const _RecentAuditSection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(mcpRecentAuditProvider);
    final small = context.theme.typography.sm;
    return _Section(
      key: McpStatusPageKeys.recent,
      title: 'Recent audit log (last 20)',
      children: [
        async.when(
          loading: () => const FProgress(),
          error: (e, st) => Text('Could not load audit log: $e', style: small),
          data: (rows) {
            if (rows.isEmpty) {
              return const Text(
                'No MCP activity yet, or audit log unavailable.',
              );
            }
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                for (final row in rows)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 2),
                    child: Text(_formatAuditRow(row), style: small),
                  ),
              ],
            );
          },
        ),
      ],
    );
  }

  String _formatAuditRow(AuditEntry entry) {
    final ts = DateTime.fromMillisecondsSinceEpoch(
      entry.tsUtcMillis,
      isUtc: true,
    ).toLocal();
    final hh = ts.hour.toString().padLeft(2, '0');
    final mm = ts.minute.toString().padLeft(2, '0');
    final ss = ts.second.toString().padLeft(2, '0');
    return '$hh:$mm:$ss  ${entry.toolName}  '
        '[${entry.resultStatus.sqlValue}]  '
        '<${entry.scopeAtTime}>';
  }
}

class _ConnectionValueField extends StatelessWidget {
  const _ConnectionValueField({
    super.key,
    required this.label,
    required this.value,
  });

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return FTextField(
      control: FTextFieldControl.managed(
        initial: TextEditingValue(text: value),
      ),
      label: Text(label),
      readOnly: true,
      maxLines: 2,
    );
  }
}

class _Section extends StatelessWidget {
  const _Section({super.key, required this.title, required this.children});

  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Text(
              title,
              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
            ),
          ),
          ...children,
        ],
      ),
    );
  }
}

String _lifecycleLabel(McpServerLifecycle lifecycle) {
  return switch (lifecycle) {
    McpServerLifecycle.disabled => 'disabled',
    McpServerLifecycle.starting => 'starting',
    McpServerLifecycle.running => 'running',
    McpServerLifecycle.stopped => 'stopped',
    McpServerLifecycle.failed => 'failed',
  };
}
