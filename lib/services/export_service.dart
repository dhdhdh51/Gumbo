import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import 'database.dart';
import 'prefs_service.dart';

/// "Export my data" and "delete all my data".
///
/// The export is a plain JSON file written to the app's own directory and then
/// handed to the Android share sheet, so the user chooses where it goes. The
/// app never uploads anything by itself.
class ExportService {
  const ExportService(this._prefs, this._db);

  final PrefsService _prefs;
  final AppDatabase _db;

  /// Build the export document.
  Future<Map<String, dynamic>> buildExport() async => {
    'app': 'TrainerApp',
    'exportVersion': 1,
    'exportedAt': DateTime.now().toIso8601String(),
    'note':
        'All data in this file was stored only on your device. '
        'TrainerApp has no backend and never uploaded it.',
    'settingsAndProfile': _prefs.exportAll(),
    'records': await _db.exportAll(),
  };

  Future<String> buildExportJson() async =>
      const JsonEncoder.withIndent('  ').convert(await buildExport());

  /// Write the export to a file and return it.
  Future<File> writeExportFile() async {
    final json = await buildExportJson();
    final dir = await getApplicationDocumentsDirectory();
    final stamp =
        DateTime.now().toIso8601String().replaceAll(':', '-').split('.').first;
    final file = File(p.join(dir.path, 'trainerapp-export-$stamp.json'));
    await file.writeAsString(json, flush: true);
    return file;
  }

  /// Write the export and open the share sheet.
  Future<void> shareExport({required String subject}) async {
    final file = await writeExportFile();
    await Share.shareXFiles([
      XFile(file.path, mimeType: 'application/json'),
    ], subject: subject);
  }

  /// Delete everything the user ever entered, on device.
  Future<void> deleteAllData() async {
    await _db.deleteEverything();
    await _prefs.clearAll();
  }
}
