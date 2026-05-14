import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quran_player/domain/mcp/mcp_playback_command.dart';
import 'package:quran_player/domain/quran/ayah_key.dart';
import 'package:quran_player/features/mcp_status/mcp_status_page.dart';
import 'package:quran_player/features/mcp_status/state/mcp_server_controller.dart';

void main() {
  testWidgets(
    'MCP Status renders lifecycle, local mode, tools, and resources',
    (tester) async {
      await tester.pumpWidget(
        const ProviderScope(
          child: Directionality(
            textDirection: TextDirection.ltr,
            child: McpStatusPage(),
          ),
        ),
      );

      expect(find.byKey(McpStatusPageKeys.title), findsOneWidget);
      expect(find.byKey(McpStatusPageKeys.lifecycle), findsOneWidget);
      expect(find.textContaining('State: disabled'), findsOneWidget);
      expect(
        find.textContaining('Local-only stdio MCP transport'),
        findsOneWidget,
      );
      expect(find.textContaining('search_quran'), findsOneWidget);
      expect(find.textContaining('quran://metadata'), findsOneWidget);
    },
  );

  testWidgets('MCP Status approves and denies pending playback commands', (
    tester,
  ) async {
    await tester.pumpWidget(
      const ProviderScope(
        child: Directionality(
          textDirection: TextDirection.ltr,
          child: McpStatusPage(),
        ),
      ),
    );
    final container = ProviderScope.containerOf(
      tester.element(find.byKey(McpStatusPageKeys.title)),
    );
    final controller = container.read(mcpStatusControllerProvider.notifier);

    final approval = controller.request(
      McpPlaybackCommand(
        id: 'cmd-1',
        type: McpPlaybackCommandType.playAyah,
        ayahKey: AyahKey(2, 255),
        clientName: 'Test Client',
      ),
    );
    await tester.pump();

    expect(find.text('Play Ayah 2:255'), findsOneWidget);
    expect(find.byKey(McpStatusPageKeys.approve), findsOneWidget);

    await tester.tap(find.byKey(McpStatusPageKeys.approve));
    await tester.pumpAndSettle(const Duration(milliseconds: 150));
    expect((await approval).isOk, isTrue);
    expect(find.textContaining('approved'), findsOneWidget);

    final denial = controller.request(
      McpPlaybackCommand(
        id: 'cmd-2',
        type: McpPlaybackCommandType.playSurah,
        surah: 36,
      ),
    );
    await tester.pump();
    await tester.tap(find.byKey(McpStatusPageKeys.deny));
    await tester.pumpAndSettle(const Duration(milliseconds: 150));
    expect((await denial).isErr, isTrue);
    expect(find.textContaining('denied'), findsOneWidget);
  });
}
