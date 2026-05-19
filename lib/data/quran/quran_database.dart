import 'dart:io';

import 'package:flutter/services.dart' show AssetBundle, ByteData;
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import '../../core/error/failure.dart';
import '../../core/error/result.dart';

const String quranDbAssetPath = 'assets/quran/quran.sqlite';

class QuranDatabase {
  QuranDatabase(this.db, this.filePath);

  final Database db;
  final String filePath;

  Future<void> close() => db.close();
}

class QuranDatabaseFactory {
  QuranDatabaseFactory({this.preparedFilePath});

  /// If non-null, [open] uses this path directly (used by tests). Otherwise
  /// the bundle asset is materialised under app-support on first launch.
  final String? preparedFilePath;

  Future<Result<QuranDatabase>> open(AssetBundle bundle) async {
    try {
      _ensureFfiInitialized();

      final path =
          preparedFilePath ??
          await _materialiseBundleAsset(bundle, quranDbAssetPath);

      final db = await databaseFactoryFfi.openDatabase(
        path,
        options: OpenDatabaseOptions(readOnly: true, singleInstance: false),
      );
      return Result.ok(QuranDatabase(db, path));
    } catch (e, st) {
      return Result.err(
        DataAccessFailure(
          'failed to open Quran database: $e',
          cause: e,
          stackTrace: st,
        ),
      );
    }
  }
}

bool _ffiInitialized = false;
void _ensureFfiInitialized() {
  if (_ffiInitialized) return;
  sqfliteFfiInit();
  _ffiInitialized = true;
}

Future<String> _materialiseBundleAsset(
  AssetBundle bundle,
  String assetPath,
) async {
  final supportDir = await getApplicationSupportDirectory();
  final outDir = Directory(p.join(supportDir.path, 'quran'));
  if (!outDir.existsSync()) outDir.createSync(recursive: true);
  final outFile = File(p.join(outDir.path, 'quran.sqlite'));

  final ByteData bytes = await bundle.load(assetPath);
  final asset = bytes.buffer.asUint8List(
    bytes.offsetInBytes,
    bytes.lengthInBytes,
  );

  // Re-materialise if the on-disk copy doesn't match the asset bytes. Cheap
  // length comparison first; full byte compare on length match.
  final needsWrite =
      !outFile.existsSync() ||
      outFile.lengthSync() != asset.lengthInBytes ||
      !_bytesEqual(outFile.readAsBytesSync(), asset);

  if (needsWrite) {
    outFile.writeAsBytesSync(asset, flush: true);
  }
  return outFile.path;
}

bool _bytesEqual(List<int> a, List<int> b) {
  if (a.length != b.length) return false;
  for (var i = 0; i < a.length; i++) {
    if (a[i] != b[i]) return false;
  }
  return true;
}
