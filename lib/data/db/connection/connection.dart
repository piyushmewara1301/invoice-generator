import 'dart:io';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:drift_flutter/drift_flutter.dart';
import 'package:path_provider/path_provider.dart';

import '../app_database.dart';

/// Opens (or creates) the local Drift database for [businessId].
///
/// Each business (and each paired employee) gets its own database file,
/// mirroring the `_iKey`/`_cKey` SharedPreferences convention used elsewhere
/// in [AppProvider] so owner and employee data never collide on-device.
AppDatabase openAppDatabase(String businessId) {
  final name = 'billbook_$businessId';
  return AppDatabase(driftDatabase(
    name: name,
    web: DriftWebOptions(
      sqlite3Wasm: Uri.parse('sqlite3.wasm'),
      driftWorker: Uri.parse('drift_worker.js'),
    ),
  ));
}

/// One-time upgrade for devices that were already paired as an employee
/// before owner/employee data was split into separate database files.
///
/// Such a device's cached clients/items currently live in `billbook_default`
/// (the only file that ever existed). If `billbook_emp_default` doesn't
/// exist yet, copy `billbook_default` to it so the employee's offline cache
/// survives the switch instead of starting empty — the next Drive sync
/// reconciles it with the owner's data either way. No-op on web, where Drift
/// uses OPFS/IndexedDB instead of plain files (web always syncs from Drive
/// before showing data, so an empty start there is not user-visible).
Future<void> migrateToEmployeeDbIfNeeded() async {
  if (kIsWeb) return;
  try {
    final dir = await getApplicationDocumentsDirectory();
    final target = File('${dir.path}/billbook_emp_default.sqlite');
    if (await target.exists()) return;
    final source = File('${dir.path}/billbook_default.sqlite');
    if (!await source.exists()) return;
    await source.copy(target.path);
    for (final suffix in ['-wal', '-shm']) {
      final sidecar = File('${dir.path}/billbook_default.sqlite$suffix');
      if (await sidecar.exists()) {
        await sidecar.copy('${dir.path}/billbook_emp_default.sqlite$suffix');
      }
    }
  } catch (_) {
    // Best-effort — on failure the employee DB just starts empty and is
    // repopulated by the next Drive sync.
  }
}
