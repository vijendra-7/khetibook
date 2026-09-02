import 'dart:convert';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:file_picker/file_picker.dart';
import 'package:sqflite/sqflite.dart';
import '../database/app_database.dart';

class BackupService {
  static final AppDatabase _appDb = AppDatabase.instance;

  /// Exports the entire database to a JSON file and shares it.
  Future<void> exportBackup() async {
    final db = await _appDb.database;
    
    final investments = await db.query('investments');
    final outputs = await db.query('outputs');
    final helpers = await db.query('helper_transactions');
    final options = await db.query('custom_options');
    final investmentItems = await db.query('investment_items');

    final backupData = {
      'version': 2,
      'exportedAt': DateTime.now().millisecondsSinceEpoch,
      'data': {
        'investments': investments,
        'outputs': outputs,
        'helper_transactions': helpers,
        'custom_options': options,
        'investment_items': investmentItems,
      }
    };

    final jsonString = jsonEncode(backupData);
    final directory = await getTemporaryDirectory();
    final file = File('${directory.path}/khetibook_backup_${DateTime.now().millisecondsSinceEpoch}.json');
    
    await file.writeAsString(jsonString);

    await Share.shareXFiles(
      [XFile(file.path)],
      subject: 'KhetiBook Data Backup',
    );
  }

  /// Imports data from a JSON backup file.
  /// Returns a summary message of the import result.
  Future<String> importBackup() async {
    FilePickerResult? result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['json'],
    );

    if (result == null || result.files.single.path == null) {
      return 'Import cancelled';
    }

    final file = File(result.files.single.path!);
    final jsonString = await file.readAsString();
    
    try {
      final Map<String, dynamic> backupData = jsonDecode(jsonString);
      
      if (backupData['data'] == null) {
        return 'Invalid backup file format';
      }

      final data = backupData['data'] as Map<String, dynamic>;
      final db = await _appDb.database;
      
      // Load all existing UUIDs locally to prevent duplicates because our schema
      // does not have a UNIQUE database constraint on the uuid column.
      final existingInvs = { for (var r in await db.query('investments', columns: ['uuid'])) r['uuid'] as String };
      final existingItems = { for (var r in await db.query('investment_items', columns: ['uuid'])) r['uuid'] as String };
      final existingOuts = { for (var r in await db.query('outputs', columns: ['uuid'])) r['uuid'] as String };
      final existingHelpers = { for (var r in await db.query('helper_transactions', columns: ['uuid'])) r['uuid'] as String };
      final existingOptions = { for (var r in await db.query('custom_options', columns: ['uuid'])) r['uuid'] as String };

      final batch = db.batch();
      int importedCount = 0;

      // 1. Process Investments
      if (data['investments'] != null) {
        for (var item in data['investments'] as List) {
          final map = Map<String, dynamic>.from(item);
          map.remove('id');
          // Force 'pending' so every restored record is re-uploaded
          map['syncStatus'] = 'pending';
          
          final uuid = map['uuid'] as String;
          if (existingInvs.contains(uuid)) {
            batch.update('investments', map, where: 'uuid = ?', whereArgs: [uuid]);
          } else {
            batch.insert('investments', map);
          }
          importedCount++;
        }
      }

      // 1b. Process Investment Items
      if (data['investment_items'] != null) {
        for (var item in data['investment_items'] as List) {
          final map = Map<String, dynamic>.from(item);
          map.remove('id');
          
          final uuid = map['uuid'] as String;
          if (existingItems.contains(uuid)) {
            batch.update('investment_items', map, where: 'uuid = ?', whereArgs: [uuid]);
          } else {
            batch.insert('investment_items', map);
          }
          importedCount++;
        }
      }

      // 2. Process Outputs
      if (data['outputs'] != null) {
        for (var item in data['outputs'] as List) {
          final map = Map<String, dynamic>.from(item);
          map.remove('id');
          map['syncStatus'] = 'pending';
          
          final uuid = map['uuid'] as String;
          if (existingOuts.contains(uuid)) {
            batch.update('outputs', map, where: 'uuid = ?', whereArgs: [uuid]);
          } else {
            batch.insert('outputs', map);
          }
          importedCount++;
        }
      }

      // 3. Process Helpers
      if (data['helper_transactions'] != null) {
        for (var item in data['helper_transactions'] as List) {
          final map = Map<String, dynamic>.from(item);
          map.remove('id');
          map['syncStatus'] = 'pending';
          
          final uuid = map['uuid'] as String;
          if (existingHelpers.contains(uuid)) {
            batch.update('helper_transactions', map, where: 'uuid = ?', whereArgs: [uuid]);
          } else {
            batch.insert('helper_transactions', map);
          }
          importedCount++;
        }
      }

      // 4. Process Options
      if (data['custom_options'] != null) {
        for (var item in data['custom_options'] as List) {
          final map = Map<String, dynamic>.from(item);
          map.remove('id');
          map['syncStatus'] = 'pending';
          
          final uuid = map['uuid'] as String;
          if (existingOptions.contains(uuid)) {
            batch.update('custom_options', map, where: 'uuid = ?', whereArgs: [uuid]);
          } else {
            batch.insert('custom_options', map);
          }
          importedCount++;
        }
      }

      await batch.commit(noResult: true);
      
      _appDb.notifyChange();

      return 'Successfully imported $importedCount records';
    } catch (e) {
      return 'Error during import: $e';
    }
  }
}
