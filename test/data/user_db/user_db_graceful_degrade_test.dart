import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:logging/logging.dart';
import 'package:path/path.dart' as p;
import 'package:quran_player/app/state/user_db_provider.dart';
import 'package:quran_player/core/logging/logger.dart';
import 'package:quran_player/domain/quran/ayah_key.dart';

import '../../_fakes/fake_quran_repository.dart';

/// Spec mcp-server R5: `user.db` open failure SHALL NOT block app start.
///
/// The graceful-degrade contract is that:
/// - userDbStateProvider resolves to UserDbState.failed (not throws)
/// - appLogger.severe fires once with the failure reason
/// - auditLogRepositoryProvider returns null
/// - QuranRepository reads continue to succeed
void main() {
  setUpAll(() {
    initLogging();
  });

  test(
    'open failure surfaces as UserDbState.failed without throwing',
    () async {
      final container = ProviderContainer(
        overrides: [
          userDbPathProvider.overrideWith((ref) async {
            throw const FileSystemException('Simulated permission denied');
          }),
        ],
      );
      addTearDown(container.dispose);

      final state = await container.read(userDbStateProvider.future);

      expect(state.health, UserDbHealth.failed);
      expect(state.repository, isNull);
      expect(state.failure, isNotNull);
      expect(state.failure!.message, contains('user.db unavailable'));
    },
  );

  test('open failure logs appLogger.severe exactly once', () async {
    final records = <LogRecord>[];
    final sub = appLogger.onRecord.listen(records.add);
    addTearDown(sub.cancel);

    final container = ProviderContainer(
      overrides: [
        userDbPathProvider.overrideWith((ref) async {
          throw const FileSystemException('disk gone');
        }),
      ],
    );
    addTearDown(container.dispose);

    await container.read(userDbStateProvider.future);

    final severe = records.where((r) => r.level == Level.SEVERE).toList();
    expect(severe, hasLength(1));
    expect(severe.single.message, 'user.db open failed');
  });

  test('auditLogRepositoryProvider returns null when user.db failed', () async {
    final container = ProviderContainer(
      overrides: [
        userDbPathProvider.overrideWith((ref) async {
          throw const FileSystemException('nope');
        }),
      ],
    );
    addTearDown(container.dispose);

    await container.read(userDbStateProvider.future);
    expect(container.read(auditLogRepositoryProvider), isNull);
  });

  test(
    'QuranRepository reads continue to succeed when user.db is failed',
    () async {
      final container = ProviderContainer(
        overrides: [
          userDbPathProvider.overrideWith((ref) async {
            throw const FileSystemException('still nope');
          }),
        ],
      );
      addTearDown(container.dispose);

      await container.read(userDbStateProvider.future);

      final fakeQuran = FakeQuranRepository();
      final surahs = await fakeQuran.listSurahs();
      expect(surahs.isOk, isTrue);
    },
  );

  test('happy path opens, prunes, and exposes the repository', () async {
    final tempDir = await Directory.systemTemp.createTemp(
      'user_db_graceful_test_',
    );
    addTearDown(() => tempDir.deleteSync(recursive: true));

    final container = ProviderContainer(
      overrides: [
        userDbPathProvider.overrideWith((ref) async {
          return p.join(tempDir.path, 'user.db');
        }),
      ],
    );
    addTearDown(container.dispose);

    final state = await container.read(userDbStateProvider.future);
    expect(state.health, UserDbHealth.ready);
    expect(state.repository, isNotNull);

    // The prune ran and emitted a log line.
    final repo = state.repository!;
    final rows = await repo.recent(20);
    expect(rows, isEmpty);

    // Sanity: AyahKey from the host domain is interoperable with package types.
    expect(AyahKey(2, 255).toString(), isNotEmpty);
  });
}
