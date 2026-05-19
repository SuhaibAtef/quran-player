import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quran_mcp_server/quran_mcp_server.dart';
import 'package:quran_player/app/state/mcp_server_provider.dart';
import 'package:quran_player/app/state/mcp_settings_provider.dart';
import 'package:quran_player/features/mcp_status/mcp_status_page.dart';

import '../../_support/localized.dart';

class _FakeMcpServerController extends McpServerController {
  _FakeMcpServerController(super.ref) {
    state = McpServerStatus(
      lifecycle: McpServerLifecycle.running,
      uri: Uri.parse('http://127.0.0.1:8765/mcp'),
      authToken: 'test-token-1234',
    );
  }

  @override
  Future<void> start() async {}

  @override
  Future<void> stop() async {}
}

void main() {
  testWidgets(
    'MCP Status renders lifecycle, URL, token, scope state, tool counts, and audit list',
    (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            mcpServerControllerProvider.overrideWith(
              _FakeMcpServerController.new,
            ),
            mcpRecentAuditProvider.overrideWith((ref) async => const []),
            mcpSettingsControllerProvider.overrideWith(
              (ref) => _ConfigurableSettings(
                const McpSettings(
                  enabled: true,
                  scopePlayback: true,
                  scopeBookmark: false,
                  port: 8765,
                ),
              ),
            ),
          ],
          child: localized(
            const Directionality(
              textDirection: TextDirection.ltr,
              child: MediaQuery(
                data: MediaQueryData(size: Size(800, 1200)),
                child: McpStatusPage(),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byKey(McpStatusPageKeys.title), findsOneWidget);
      expect(find.byKey(McpStatusPageKeys.body), findsOneWidget);
      expect(find.byKey(McpStatusPageKeys.lifecycle), findsOneWidget);
      expect(find.byKey(McpStatusPageKeys.uri), findsOneWidget);
      expect(find.byKey(McpStatusPageKeys.token), findsOneWidget);
      expect(find.byKey(McpStatusPageKeys.scopes), findsOneWidget);
      expect(find.byKey(McpStatusPageKeys.tools), findsOneWidget);
      expect(find.byKey(McpStatusPageKeys.resources), findsOneWidget);
      expect(find.byKey(McpStatusPageKeys.recent), findsOneWidget);

      // Tool / resource definitions are static — verify the count rendered.
      expect(find.text('Tools (${mcpToolDefinitions.length})'), findsOneWidget);
      expect(
        find.text('Resources (${mcpResourceDefinitions.length})'),
        findsOneWidget,
      );
    },
  );

  testWidgets(
    'MCP Status renders the empty audit-log message when user.db has no rows',
    (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            mcpServerControllerProvider.overrideWith(
              _FakeMcpServerController.new,
            ),
            mcpRecentAuditProvider.overrideWith((ref) async => const []),
            mcpSettingsControllerProvider.overrideWith(
              (ref) => _ConfigurableSettings(
                const McpSettings(
                  enabled: true,
                  scopePlayback: false,
                  scopeBookmark: false,
                  port: 0,
                ),
              ),
            ),
          ],
          child: localized(
            const Directionality(
              textDirection: TextDirection.ltr,
              child: MediaQuery(
                data: MediaQueryData(size: Size(800, 1200)),
                child: McpStatusPage(),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.pumpAndSettle();

      expect(
        find.text('No MCP activity yet, or audit log unavailable.'),
        findsOneWidget,
      );
    },
  );
}

/// Riverpod test seam — exposes the controller without touching SharedPreferences.
class _ConfigurableSettings extends StateNotifier<McpSettings>
    implements McpSettingsController {
  _ConfigurableSettings(super.initial);

  @override
  Future<void> setEnabled(bool value) async {}

  @override
  Future<void> setScopePlayback(bool value) async {}

  @override
  Future<void> setScopeBookmark(bool value) async {}

  @override
  Future<void> setPort(int value) async {}
}
