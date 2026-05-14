import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:forui/forui.dart';

import '../../data/mcp/mcp_server_service.dart';
import 'package:quran_mcp_server/quran_mcp_server.dart';

import '../../domain/mcp/mcp_playback_command.dart';
import 'state/mcp_server_controller.dart';

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
  static const pending = Key('mcp_status.pending');
  static const approve = Key('mcp_status.approve');
  static const deny = Key('mcp_status.deny');
  static const recent = Key('mcp_status.recent');
}

class McpStatusPage extends ConsumerWidget {
  const McpStatusPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(mcpStatusControllerProvider);
    final controller = ref.read(mcpStatusControllerProvider.notifier);
    final small = context.theme.typography.sm;
    final starting = state.server.lifecycle == McpServerLifecycle.starting;
    final running = state.server.lifecycle == McpServerLifecycle.running;

    return FScaffold(
      header: const FHeader(
        title: Text('MCP Status', key: McpStatusPageKeys.title),
      ),
      child: ListView(
        key: McpStatusPageKeys.body,
        children: [
          _Section(
            key: McpStatusPageKeys.lifecycle,
            title: 'Server',
            children: [
              Text('State: ${_lifecycleLabel(state.server.lifecycle)}'),
              if (state.server.message != null) Text(state.server.message!),
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
              const Text('Local-only HTTPS Streamable HTTP MCP transport'),
              SizedBox(height: 2),
              const Text(
                'Remote access, filesystem tools, and shell commands are not exposed. Use the URL and bearer token with a local MCP client while this app is running.',
              ),
              if (state.server.uri != null &&
                  state.server.authToken != null) ...[
                const SizedBox(height: 8),
                _ConnectionValueField(
                  key: McpStatusPageKeys.uri,
                  label: 'URL',
                  value: '${state.server.uri}',
                ),
                const SizedBox(height: 2),
                _ConnectionValueField(
                  key: McpStatusPageKeys.token,
                  label: 'Token',
                  value: state.server.authToken!,
                ),
              ],
            ],
          ),
          _Section(
            key: McpStatusPageKeys.tools,
            title: 'Tools',
            children: [
              Text(McpServerService.toolNames.join(', '), style: small),
            ],
          ),
          _Section(
            key: McpStatusPageKeys.resources,
            title: 'Resources',
            children: [
              Text(McpServerService.resourceUris.join(', '), style: small),
            ],
          ),
          _PendingCommandSection(state: state, controller: controller),
          _RecentDecisionsSection(records: state.permissions.recent),
        ],
      ),
    );
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

class _PendingCommandSection extends StatelessWidget {
  const _PendingCommandSection({required this.state, required this.controller});

  final McpStatusState state;
  final McpStatusController controller;

  @override
  Widget build(BuildContext context) {
    final pending = state.permissions.pending;
    return _Section(
      key: McpStatusPageKeys.pending,
      title: 'Playback permission',
      children: [
        if (pending == null)
          const Text('No pending playback command')
        else ...[
          Text(pending.label),
          if (pending.clientName != null) Text('Client: ${pending.clientName}'),
          const SizedBox(height: 8),
          Row(
            children: [
              FButton(
                key: McpStatusPageKeys.approve,
                onPress: controller.approvePending,
                prefix: const Icon(FIcons.circleCheck),
                child: const Text('Approve'),
              ),
              const SizedBox(width: 8),
              FButton(
                key: McpStatusPageKeys.deny,
                variant: FButtonVariant.outline,
                onPress: controller.denyPending,
                prefix: const Icon(FIcons.circleX),
                child: const Text('Deny'),
              ),
            ],
          ),
        ],
      ],
    );
  }
}

class _RecentDecisionsSection extends StatelessWidget {
  const _RecentDecisionsSection({required this.records});

  final List<McpPlaybackDecisionRecord> records;

  @override
  Widget build(BuildContext context) {
    return _Section(
      key: McpStatusPageKeys.recent,
      title: 'Recent decisions',
      children: [
        if (records.isEmpty)
          const Text('No MCP playback decisions this session')
        else
          for (final record in records)
            Text('${record.command.label}: ${record.decision.name}'),
      ],
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
