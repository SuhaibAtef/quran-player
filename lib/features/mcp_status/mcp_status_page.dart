import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:forui/forui.dart';
import 'package:quran_mcp_server/quran_mcp_server.dart';

import '../../app/state/mcp_server_provider.dart';
import '../../app/state/mcp_settings_provider.dart';
import '../../l10n/app_localizations.dart';

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
    final l10n = AppLocalizations.of(context);

    return FScaffold(
      header: FHeader(
        title: Text(l10n.mcpStatusTitle, key: McpStatusPageKeys.title),
      ),
      child: SingleChildScrollView(
        key: McpStatusPageKeys.body,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _Section(
              key: McpStatusPageKeys.lifecycle,
              title: l10n.mcpStatusServerSection,
              children: [
                Text(
                  l10n.mcpStatusState(_lifecycleLabel(status.lifecycle, l10n)),
                ),
                if (status.message != null) Text(status.message!),
                const SizedBox(height: 8),
                Row(
                  children: [
                    if (!running)
                      FButton(
                        onPress: starting ? null : controller.start,
                        prefix: const Icon(FIcons.play),
                        child: Text(l10n.mcpStatusStartButton),
                      )
                    else
                      FButton(
                        variant: FButtonVariant.outline,
                        onPress: controller.stop,
                        prefix: const Icon(FIcons.square),
                        child: Text(l10n.mcpStatusStopButton),
                      ),
                  ],
                ),
              ],
            ),
            _Section(
              key: McpStatusPageKeys.localOnly,
              title: l10n.mcpStatusTransportSection,
              children: [
                Text(l10n.mcpStatusTransportLine1),
                const SizedBox(height: 2),
                Text(l10n.mcpStatusTransportLine2),
                if (status.uri != null && status.authToken != null) ...[
                  const SizedBox(height: 8),
                  _ConnectionValueField(
                    key: McpStatusPageKeys.uri,
                    label: l10n.mcpStatusUrlLabel,
                    value: '${status.uri}',
                  ),
                  const SizedBox(height: 2),
                  _ConnectionValueField(
                    key: McpStatusPageKeys.token,
                    label: l10n.mcpStatusTokenLabel,
                    value: status.authToken!,
                  ),
                ],
              ],
            ),
            _Section(
              key: McpStatusPageKeys.scopes,
              title: l10n.mcpStatusScopesSection,
              children: [
                if (!settings.enabled)
                  Text(l10n.mcpStatusScopesDisabled)
                else ...[
                  Text(l10n.mcpStatusScopeReadonly),
                  Text(
                    l10n.mcpStatusScopePlayback(
                      settings.scopePlayback
                          ? l10n.mcpStatusOn
                          : l10n.mcpStatusOff,
                    ),
                  ),
                  Text(
                    l10n.mcpStatusScopeBookmark(
                      settings.scopeBookmark
                          ? l10n.mcpStatusOn
                          : l10n.mcpStatusOff,
                    ),
                  ),
                ],
              ],
            ),
            _Section(
              key: McpStatusPageKeys.tools,
              title: l10n.mcpStatusToolsSection(mcpToolDefinitions.length),
              children: [
                Text(
                  mcpToolDefinitions.map((t) => t.name).join(', '),
                  style: small,
                ),
              ],
            ),
            _Section(
              key: McpStatusPageKeys.resources,
              title: l10n.mcpStatusResourcesSection(
                mcpResourceDefinitions.length,
              ),
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
    final l10n = AppLocalizations.of(context);
    return _Section(
      key: McpStatusPageKeys.recent,
      title: l10n.mcpStatusRecentSection,
      children: [
        async.when(
          loading: () => const FProgress(),
          error: (e, st) =>
              Text(l10n.mcpStatusAuditLoadError('$e'), style: small),
          data: (rows) {
            if (rows.isEmpty) {
              return Text(l10n.mcpStatusAuditEmpty);
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

String _lifecycleLabel(McpServerLifecycle lifecycle, AppLocalizations l10n) {
  return switch (lifecycle) {
    McpServerLifecycle.disabled => l10n.mcpLifecycleDisabled,
    McpServerLifecycle.starting => l10n.mcpLifecycleStarting,
    McpServerLifecycle.running => l10n.mcpLifecycleRunning,
    McpServerLifecycle.stopped => l10n.mcpLifecycleStopped,
    McpServerLifecycle.failed => l10n.mcpLifecycleFailed,
  };
}
