import 'dart:io';

import 'package:flutter/services.dart' show AssetBundle, ByteData;
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import '../../core/error/failure.dart';
import '../../core/error/result.dart';

const String tafsirDbAssetPath = 'assets/tafsir/muyassar.sqlite';

class TafsirDatabase {
  TafsirDatabase(this.db, this.filePath);

  final Database db;
  final String filePath;

  Future<void> close() => db.close();
}

class TafsirDatabaseFactory {
  TafsirDatabaseFactory({this.preparedFilePath});

  /// If non-null, [open] uses this path directly (used by tests). Otherwise
  /// the bundle asset is materialised under app-support on first launch.
  final String? preparedFilePath;

  Future<Result<TafsirDatabase>> open(AssetBundle bundle) async {
    try {
      _ensureFfiInitialized();

      final path =
          preparedFilePath ??
          await _materialiseBundleAsset(bundle, tafsirDbAssetPath);

      final db = await databaseFactoryFfi.openDatabase(
        path,
        options: OpenDatabaseOptions(readOnly: true, singleInstance: false),
      );
      return Result.ok(TafsirDatabase(db, path));
    } catch (e, st) {
      return Result.err(
        DataAccessFailure(
          'failed to open Tafsir database: $e',
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
  final outDir = Directory(p.join(supportDir.path, 'tafsir'));
  if (!outDir.existsSync()) outDir.createSync(recursive: true);
  final outFile = File(p.join(outDir.path, 'muyassar.sqlite'));

  final ByteData bytes = await bundle.load(assetPath);
  final asset = bytes.buffer.asUint8List(
    bytes.offsetInBytes,
    bytes.lengthInBytes,
  );

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
