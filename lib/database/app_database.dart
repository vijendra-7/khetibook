import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import 'package:uuid/uuid.dart';
import '../models/investment.dart';
import '../models/investment_item.dart';
import '../models/output.dart';
import '../models/helper_transaction.dart';
import '../models/custom_option.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AppDatabase {
  static final AppDatabase instance = AppDatabase._();
  static Database? _db;

  AppDatabase._();

  /// Stream for data changes (broadcast so multiple providers can listen)
  final StreamController<void> _changeController = StreamController<void>.broadcast();
  Stream<void> get onDataChangedStream => _changeController.stream;

  void notifyChange() => _notifyChange();

  void _notifyChange() {
    _changeController.add(null);
  }

  Future<Database> get database async {
    _db ??= await _initDb();
    return _db!;
  }

  Future<Database> _initDb() async {
    final path = join(await getDatabasesPath(), 'farmer_accounting.db');
    return openDatabase(
      path,
      version: 10,
      onCreate: _create,
      onUpgrade: _onUpgrade,
    );
  }

  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 3) {
      // Version 3: Add sync metadata (uuid, updatedAt, syncStatus)
      const tables = ['investments', 'outputs', 'helper_transactions'];
      for (final table in tables) {
        await db.execute('ALTER TABLE $table ADD COLUMN uuid TEXT');
        await db.execute('ALTER TABLE $table ADD COLUMN updatedAt INTEGER');
        await db.execute(
            'ALTER TABLE $table ADD COLUMN syncStatus TEXT DEFAULT "pending"');

        // Backfill UUIDs and updatedAt for existing records
        final List<Map<String, dynamic>> records = await db.query(table);
        for (final record in records) {
          final id = record['id'];
          final date = record['date'] as int;
          await db.update(
            table,
            {
              'uuid': const Uuid().v4(),
              'updatedAt': date,
            },
            where: 'id = ?',
            whereArgs: [id],
          );
        }
      }
    }
    if (oldVersion < 4) {
      await _createCustomOptionsTable(db);
      await _migrateSharedPreferencesToSqlite(db);
    }
    if (oldVersion < 5) {
      // Version 5: Add crop field to helper_transactions
      await db.execute(
          'ALTER TABLE helper_transactions ADD COLUMN crop TEXT DEFAULT ""');
    }
    if (oldVersion < 6) {
      // Version 6: Add investment_items table
      await db.execute('''
        CREATE TABLE investment_items (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          uuid TEXT NOT NULL,
          investmentUuid TEXT NOT NULL,
          itemName TEXT NOT NULL,
          quantity REAL NOT NULL,
          pricePerUnit REAL NOT NULL,
          updatedAt INTEGER NOT NULL
        )
      ''');
    }
    if (oldVersion < 7) {
      await db.execute(
          'ALTER TABLE investments ADD COLUMN biyaranCompany TEXT DEFAULT ""');
      await db.execute(
          'ALTER TABLE investments ADD COLUMN fieldName TEXT DEFAULT ""');
    }
    if (oldVersion < 8) {
      await db.execute('ALTER TABLE outputs ADD COLUMN vigha TEXT DEFAULT ""');
    }
    if (oldVersion < 9) {
      await db.execute(
          'ALTER TABLE helper_transactions ADD COLUMN vigha TEXT DEFAULT ""');
    }
    if (oldVersion < 10) {
      // Version 10: Performance Indices
      await db.execute(
          'CREATE INDEX IF NOT EXISTS idx_investments_crop_deleted_date ON investments (crop, isDeleted, date)');
      await db.execute(
          'CREATE INDEX IF NOT EXISTS idx_outputs_crop_deleted_date ON outputs (crop, isDeleted, date)');
      await db.execute(
          'CREATE INDEX IF NOT EXISTS idx_helper_transactions_type_deleted_date ON helper_transactions (transactionType, isDeleted, date)');
      await db.execute(
          'CREATE INDEX IF NOT EXISTS idx_investment_items_investmentUuid ON investment_items (investmentUuid)');
      await db.execute(
          'CREATE INDEX IF NOT EXISTS idx_custom_options_category ON custom_options (category, isDeleted)');
    }
  }

  Future<void> _create(Database db, int version) async {
    await db.execute('''
      CREATE TABLE investments (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        uuid TEXT NOT NULL,
        crop TEXT NOT NULL,
        investmentType TEXT NOT NULL,
        investmentTypeOther TEXT DEFAULT '',
        seedType TEXT DEFAULT '',
        biyaranCompany TEXT DEFAULT '',
        fieldName TEXT DEFAULT '',
        kataQuantity REAL DEFAULT 0,
        pricePerKata REAL DEFAULT 0,
        vigha TEXT DEFAULT '',
        cost REAL DEFAULT 0,
        serviceProvider TEXT DEFAULT '',
        isPaid INTEGER DEFAULT 1,
        pendingAmount REAL DEFAULT 0,
        date INTEGER NOT NULL,
        updatedAt INTEGER NOT NULL,
        syncStatus TEXT DEFAULT 'pending',
        isDeleted INTEGER DEFAULT 0,
        deletedAt INTEGER
      )
    ''');
    await db.execute('''
      CREATE TABLE outputs (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        uuid TEXT NOT NULL,
        crop TEXT NOT NULL,
        field TEXT NOT NULL,
        vigha TEXT DEFAULT '',
        bharati INTEGER NOT NULL,
        remainingKg REAL DEFAULT 0,
        pricePer20kg REAL NOT NULL,
        soldTo TEXT DEFAULT '',
        totalKata REAL DEFAULT 0,
        date INTEGER NOT NULL,
        updatedAt INTEGER NOT NULL,
        syncStatus TEXT DEFAULT 'pending',
        isDeleted INTEGER DEFAULT 0,
        deletedAt INTEGER
      )
    ''');
    await db.execute('''
      CREATE TABLE helper_transactions (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        uuid TEXT NOT NULL,
        transactionType TEXT NOT NULL,
        helperName TEXT NOT NULL,
        amount REAL DEFAULT 0,
        workerCount INTEGER DEFAULT 0,
        amountPerWorker REAL DEFAULT 0,
        field TEXT DEFAULT '',
        vigha TEXT DEFAULT '',
        equipmentType TEXT DEFAULT '',
        crop TEXT DEFAULT '',
        hours REAL DEFAULT 0,
        pricePerHour REAL DEFAULT 0,
        date INTEGER NOT NULL,
        updatedAt INTEGER NOT NULL,
        syncStatus TEXT DEFAULT 'pending',
        isDeleted INTEGER DEFAULT 0,
        deletedAt INTEGER
      )
    ''');
    await _createCustomOptionsTable(db);
    await db.execute('''
      CREATE TABLE investment_items (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        uuid TEXT NOT NULL,
        investmentUuid TEXT NOT NULL,
        itemName TEXT NOT NULL,
        quantity REAL NOT NULL,
        pricePerUnit REAL NOT NULL,
        updatedAt INTEGER NOT NULL
      )
    ''');

    // Performance Indices
    await db.execute(
        'CREATE INDEX idx_investments_crop_deleted_date ON investments (crop, isDeleted, date)');
    await db.execute(
        'CREATE INDEX idx_outputs_crop_deleted_date ON outputs (crop, isDeleted, date)');
    await db.execute(
        'CREATE INDEX idx_helper_transactions_type_deleted_date ON helper_transactions (transactionType, isDeleted, date)');
    await db.execute(
        'CREATE INDEX idx_investment_items_investmentUuid ON investment_items (investmentUuid)');
    await db.execute(
        'CREATE INDEX idx_custom_options_category ON custom_options (category, isDeleted)');
  }

  Future<void> _createCustomOptionsTable(Database db) async {
    await db.execute('''
      CREATE TABLE custom_options (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        uuid TEXT NOT NULL,
        category TEXT NOT NULL,
        value TEXT NOT NULL,
        updatedAt INTEGER NOT NULL,
        syncStatus TEXT DEFAULT 'pending',
        isDeleted INTEGER DEFAULT 0
      )
    ''');
  }

  Future<void> _migrateSharedPreferencesToSqlite(Database db) async {
    final prefs = await SharedPreferences.getInstance();
    const categories = [
      'crops',
      'service_providers',
      'tractor_providers',
      'investment_types',
      'equipment_types',
      'buyers',
      'drivers',
      'dawa',
      'khatar',
      'fields',
      'helpers',
      'bataka_seeds',
      'magfali_seeds',
      'ghau_seeds',
      'tarbuch_seeds',
      'bajari_seeds'
    ];

    for (final cat in categories) {
      final key = 'custom_$cat';
      final List<String>? options = prefs.getStringList(key);
      if (options != null) {
        for (final val in options) {
          final now = DateTime.now().millisecondsSinceEpoch;
          await db.insert('custom_options', {
            'uuid': const Uuid().v4(),
            'category': cat,
            'value': val,
            'updatedAt': now,
            'syncStatus': 'pending',
            'isDeleted': 0,
          });
        }
      }
    }
  }

  // ────────── Investments ──────────

  Future<List<Investment>> getInvestmentsByCrop(String crop) async {
    final db = await database;
    final maps = await db.query(
      'investments',
      where: 'crop = ? AND isDeleted = 0',
      whereArgs: [crop],
      orderBy: 'date DESC',
    );
    final investments = maps.map(Investment.fromMap).toList();
    for (int i = 0; i < investments.length; i++) {
      investments[i] = investments[i].copyWith(
        items: await getInvestmentItems(investments[i].uuid),
      );
    }
    return investments;
  }

  Future<double> getTotalInvestmentByCrop(String crop) async {
    final db = await database;
    // Biyaran: kataQuantity * pricePerKata, others: cost
    final rows = await db.query(
      'investments',
      where: 'crop = ? AND isDeleted = 0',
      whereArgs: [crop],
    );
    double total = 0;
    for (final map in rows) {
      final inv = Investment.fromMap(map);
      final hydratedInv =
          inv.copyWith(items: await getInvestmentItems(inv.uuid));
      total += hydratedInv.totalAmount;
    }
    return total;
  }

  Future<List<Investment>> getInvestmentsByCropAndYear(
      String? crop, int startDate, int endDate) async {
    final db = await database;
    final whereClause = crop == null 
        ? 'isDeleted = 0 AND date >= ? AND date <= ?'
        : 'crop = ? AND isDeleted = 0 AND date >= ? AND date <= ?';
    final whereArgs = crop == null 
        ? [startDate, endDate]
        : [crop, startDate, endDate];

    final maps = await db.query(
      'investments',
      where: whereClause,
      whereArgs: whereArgs,
      orderBy: 'date ASC',
    );
    final investments = maps.map(Investment.fromMap).toList();
    for (int i = 0; i < investments.length; i++) {
      investments[i] = investments[i].copyWith(
        items: await getInvestmentItems(investments[i].uuid),
      );
    }
    return investments;
  }

  Future<List<Investment>> getDeletedInvestments() async {
    final db = await database;
    final maps = await db.query(
      'investments',
      where: 'isDeleted = 1',
      orderBy: 'deletedAt DESC',
    );
    final investments = maps.map(Investment.fromMap).toList();
    for (int i = 0; i < investments.length; i++) {
      investments[i] = investments[i].copyWith(
        items: await getInvestmentItems(investments[i].uuid),
      );
    }
    return investments;
  }

  Future<int> insertInvestment(Investment inv) async {
    final db = await database;
    final id = await db.transaction((txn) async {
      final toInsert = inv.copyWith(syncStatus: 'pending');
      final investmentId =
          await txn.insert('investments', toInsert.toSqlMap()..remove('id'));

      for (final item in inv.items) {
        await txn.insert('investment_items',
            item.copyWith(investmentUuid: inv.uuid).toMap()..remove('id'));
      }
      return investmentId;
    });
    _notifyChange();
    return id;
  }

  Future<Investment?> getInvestmentById(int id) async {
    final db = await database;
    final maps =
        await db.query('investments', where: 'id = ?', whereArgs: [id]);
    if (maps.isEmpty) return null;
    final inv = Investment.fromMap(maps.first);
    return inv.copyWith(items: await getInvestmentItems(inv.uuid));
  }

  Future<void> updateInvestment(Investment inv) async {
    final db = await database;
    await db.transaction((txn) async {
      final toUpdate = inv.copyWith(
        updatedAt: DateTime.now().millisecondsSinceEpoch,
        syncStatus: 'pending',
      );
      await txn.update('investments', toUpdate.toSqlMap(),
          where: 'id = ?', whereArgs: [inv.id]);

      // Refresh items: delete existing and insert new
      await txn.delete('investment_items',
          where: 'investmentUuid = ?', whereArgs: [inv.uuid]);
      for (final item in inv.items) {
        await txn.insert('investment_items',
            item.copyWith(investmentUuid: inv.uuid).toMap()..remove('id'));
      }
    });
    _notifyChange();
  }

  Future<void> softDeleteInvestment(int id) async {
    final db = await database;
    final now = DateTime.now().millisecondsSinceEpoch;
    await db.update(
      'investments',
      {
        'isDeleted': 1,
        'deletedAt': now,
        'updatedAt': now,
        'syncStatus': 'pending',
      },
      where: 'id = ?',
      whereArgs: [id],
    );
    _notifyChange();
  }

  Future<void> restoreInvestment(int id) async {
    final db = await database;
    final now = DateTime.now().millisecondsSinceEpoch;
    await db.update(
      'investments',
      {
        'isDeleted': 0,
        'deletedAt': null,
        'updatedAt': now,
        'syncStatus': 'pending',
      },
      where: 'id = ?',
      whereArgs: [id],
    );
    _notifyChange();
  }

  Future<void> permanentDeleteInvestment(int id) async {
    final db = await database;
    final inv = await getInvestmentById(id);
    await db.transaction((txn) async {
      if (inv != null) {
        await txn.delete('investment_items',
            where: 'investmentUuid = ?', whereArgs: [inv.uuid]);
      }
      await txn.delete('investments', where: 'id = ?', whereArgs: [id]);
    });
    _notifyChange();
  }

  Future<List<InvestmentItem>> getInvestmentItems(String investmentUuid) async {
    final db = await database;
    final maps = await db.query(
      'investment_items',
      where: 'investmentUuid = ?',
      whereArgs: [investmentUuid],
    );
    return maps.map(InvestmentItem.fromMap).toList();
  }

  Future<List<String>> getUsedCrops() async {
    final db = await database;
    final invList = await db.rawQuery('SELECT DISTINCT crop FROM investments WHERE isDeleted = 0');
    final outList = await db.rawQuery('SELECT DISTINCT crop FROM outputs WHERE isDeleted = 0');
    final helperList = await db.rawQuery('SELECT DISTINCT crop FROM helper_transactions WHERE isDeleted = 0');
    
    final all = <String>{};
    for (var m in invList) {
      final c = m['crop']?.toString().trim();
      if (c != null && c.isNotEmpty) all.add(c);
    }
    for (var m in outList) {
      final c = m['crop']?.toString().trim();
      if (c != null && c.isNotEmpty) all.add(c);
    }
    for (var m in helperList) {
      final c = m['crop']?.toString().trim();
      if (c != null && c.isNotEmpty) all.add(c);
    }
    return all.toList();
  }

  // ────────── Outputs ──────────

  Future<List<Output>> getOutputsByCrop(String crop) async {
    final db = await database;
    final maps = await db.query(
      'outputs',
      where: 'crop = ? AND isDeleted = 0',
      whereArgs: [crop],
      orderBy: 'date DESC',
    );
    return maps.map(Output.fromMap).toList();
  }

  Future<List<Output>> getOutputsByCropAndYear(
      String? crop, int startDate, int endDate) async {
    final db = await database;
    final whereClause = crop == null 
        ? 'isDeleted = 0 AND date >= ? AND date <= ?'
        : 'crop = ? AND isDeleted = 0 AND date >= ? AND date <= ?';
    final whereArgs = crop == null 
        ? [startDate, endDate]
        : [crop, startDate, endDate];

    final maps = await db.query(
      'outputs',
      where: whereClause,
      whereArgs: whereArgs,
      orderBy: 'date ASC',
    );
    return maps.map(Output.fromMap).toList();
  }

  Future<List<Output>> getDeletedOutputs() async {
    final db = await database;
    final maps = await db.query(
      'outputs',
      where: 'isDeleted = 1',
      orderBy: 'deletedAt DESC',
    );
    return maps.map(Output.fromMap).toList();
  }

  Future<Output?> getOutputById(int id) async {
    final db = await database;
    final maps = await db.query('outputs', where: 'id = ?', whereArgs: [id]);
    if (maps.isEmpty) return null;
    return Output.fromMap(maps.first);
  }

  Future<int> insertOutput(Output out) async {
    final db = await database;
    final toInsert = out.copyWith(syncStatus: 'pending');
    final id = await db.insert('outputs', toInsert.toMap()..remove('id'));
    _notifyChange();
    return id;
  }

  Future<void> updateOutput(Output out) async {
    final db = await database;
    final toUpdate = out.copyWith(
      updatedAt: DateTime.now().millisecondsSinceEpoch,
      syncStatus: 'pending',
    );
    await db.update('outputs', toUpdate.toMap(),
        where: 'id = ?', whereArgs: [out.id]);
    _notifyChange();
  }

  Future<void> softDeleteOutput(int id) async {
    final db = await database;
    final now = DateTime.now().millisecondsSinceEpoch;
    await db.update(
      'outputs',
      {
        'isDeleted': 1,
        'deletedAt': now,
        'updatedAt': now,
        'syncStatus': 'pending',
      },
      where: 'id = ?',
      whereArgs: [id],
    );
    _notifyChange();
  }

  Future<void> restoreOutput(int id) async {
    final db = await database;
    final now = DateTime.now().millisecondsSinceEpoch;
    await db.update(
      'outputs',
      {
        'isDeleted': 0,
        'deletedAt': null,
        'updatedAt': now,
        'syncStatus': 'pending',
      },
      where: 'id = ?',
      whereArgs: [id],
    );
    _notifyChange();
  }

  Future<void> permanentDeleteOutput(int id) async {
    final db = await database;
    await db.delete('outputs', where: 'id = ?', whereArgs: [id]);
    _notifyChange();
  }

  // ────────── Helper Transactions ──────────

  Future<List<HelperTransaction>> getTransactionsByType(String type) async {
    final db = await database;
    final maps = await db.query(
      'helper_transactions',
      where: 'transactionType = ? AND isDeleted = 0',
      whereArgs: [type],
      orderBy: 'date DESC',
    );
    return maps.map(HelperTransaction.fromMap).toList();
  }

  Future<List<HelperTransaction>> getTransactionsByTypeAndYear(
      String type, int startDate, int endDate) async {
    final db = await database;
    final maps = await db.query(
      'helper_transactions',
      where:
          'transactionType = ? AND isDeleted = 0 AND date >= ? AND date <= ?',
      whereArgs: [type, startDate, endDate],
      orderBy: 'date ASC',
    );
    return maps.map(HelperTransaction.fromMap).toList();
  }

  Future<List<HelperTransaction>> getDeletedTransactions() async {
    final db = await database;
    final maps = await db.query(
      'helper_transactions',
      where: 'isDeleted = 1',
      orderBy: 'deletedAt DESC',
    );
    return maps.map(HelperTransaction.fromMap).toList();
  }

  Future<HelperTransaction?> getTransactionById(int id) async {
    final db = await database;
    final maps =
        await db.query('helper_transactions', where: 'id = ?', whereArgs: [id]);
    if (maps.isEmpty) return null;
    return HelperTransaction.fromMap(maps.first);
  }

  Future<int> insertTransaction(HelperTransaction txn) async {
    final db = await database;
    final toInsert = txn.copyWith(syncStatus: 'pending');
    final id =
        await db.insert('helper_transactions', toInsert.toMap()..remove('id'));
    _notifyChange();
    return id;
  }

  Future<void> updateTransaction(HelperTransaction txn) async {
    final db = await database;
    final toUpdate = txn.copyWith(
      updatedAt: DateTime.now().millisecondsSinceEpoch,
      syncStatus: 'pending',
    );
    await db.update('helper_transactions', toUpdate.toMap(),
        where: 'id = ?', whereArgs: [txn.id]);
    _notifyChange();
  }

  Future<void> softDeleteTransaction(int id) async {
    final db = await database;
    final now = DateTime.now().millisecondsSinceEpoch;
    await db.update(
      'helper_transactions',
      {
        'isDeleted': 1,
        'deletedAt': now,
        'updatedAt': now,
        'syncStatus': 'pending',
      },
      where: 'id = ?',
      whereArgs: [id],
    );
    _notifyChange();
  }

  Future<void> restoreTransaction(int id) async {
    final db = await database;
    final now = DateTime.now().millisecondsSinceEpoch;
    await db.update(
      'helper_transactions',
      {
        'isDeleted': 0,
        'deletedAt': null,
        'updatedAt': now,
        'syncStatus': 'pending',
      },
      where: 'id = ?',
      whereArgs: [id],
    );
    _notifyChange();
  }

  Future<void> permanentDeleteTransaction(int id) async {
    final db = await database;
    await db.delete('helper_transactions', where: 'id = ?', whereArgs: [id]);
    _notifyChange();
  }

  // ────────── Recent Activity ──────────

  Future<List<RecentActivity>> getRecentActivity({int limit = 3}) async {
    final db = await database;
    // Union the 3 tables with calculated amounts
    // We fetch raw columns so we can calculate the exact amount and subtitle in Dart,
    // ensuring consistency with the main models (especially for multi-item Khatar/Dawa).
    final List<Map<String, dynamic>> results = await db.rawQuery('''
      SELECT 'investment' as sourceTable, id, uuid, crop, date, 
             investmentType, investmentTypeOther, biyaranCompany, fieldName, vigha, 
             kataQuantity, pricePerKata, cost, serviceProvider, isPaid, pendingAmount,
             NULL as field, NULL as bharati, NULL as remainingKg, NULL as pricePer20kg,
             NULL as helperName, NULL as workerCount, NULL as amountPerWorker, NULL as hours, NULL as pricePerHour, NULL as equipmentType, NULL as transactionType, NULL as amount
      FROM investments WHERE isDeleted = 0
      UNION ALL
      SELECT 'output' as sourceTable, id, uuid, crop, date,
             '' as investmentType, '' as investmentTypeOther, '' as biyaranCompany, '' as fieldName, vigha,
             0 as kataQuantity, 0 as pricePerKata, 0 as cost, '' as serviceProvider, 0 as isPaid, 0 as pendingAmount,
             field, bharati, remainingKg, pricePer20kg,
             '' as helperName, NULL as workerCount, NULL as amountPerWorker, NULL as hours, NULL as pricePerHour, NULL as equipmentType, NULL as transactionType, NULL as amount
      FROM outputs WHERE isDeleted = 0
      UNION ALL
      SELECT 'helper' as sourceTable, id, uuid, crop, date,
             '' as investmentType, '' as investmentTypeOther, '' as biyaranCompany, '' as fieldName, vigha,
             0 as kataQuantity, 0 as pricePerKata, 0 as cost, '' as serviceProvider, 0 as isPaid, 0 as pendingAmount,
             '' as field, NULL as bharati, NULL as remainingKg, NULL as pricePer20kg,
             helperName, workerCount, amountPerWorker, hours, pricePerHour, equipmentType, transactionType, amount
      FROM helper_transactions WHERE isDeleted = 0
      ORDER BY date DESC
      LIMIT ?
    ''', [limit]);

    final List<RecentActivity> activities = [];
    try {
      for (final row in results) {
        final mutableRow = Map<String, dynamic>.from(row);
        final table = mutableRow['sourceTable'] as String? ?? '';
        final type = mutableRow['investmentType'] as String? ?? '';
        final uuid = mutableRow['uuid'] as String? ?? '';

        if (table == 'investment' &&
            (type == 'Dawa' || type == 'Khatar') &&
            uuid.isNotEmpty) {
          try {
            final items = await getInvestmentItems(uuid);
            mutableRow['items'] = items.map((e) => e.toMap()).toList();
          } catch (e) {
            debugPrint('Error fetching investment items for $uuid: $e');
            mutableRow['items'] = [];
          }
        }
        activities.add(RecentActivity.fromMap(mutableRow));
      }
    } catch (e, stack) {
      debugPrint('Error processing recent activities: $e\n$stack');
    }
    return activities;
  }

  /// Generic method to get unique values for a column from a table with a filter.
  Future<List<String>> getUniqueValues(String table, String column,
      {String? where, List<Object?>? whereArgs}) async {
    final db = await database;
    final res = await db.query(table,
        columns: [column],
        distinct: true,
        where:
            'isDeleted = 0 AND $column != "" ${where != null ? " AND $where" : ""}',
        whereArgs: whereArgs);
    return res.map((r) => r[column].toString()).toList();
  }

  // ────────── Custom Options ──────────

  Future<List<CustomOption>> getCustomOptionsByCategory(String category) async {
    final db = await database;
    final maps = await db.query(
      'custom_options',
      where: 'category = ? AND isDeleted = 0',
      whereArgs: [category],
    );
    return maps.map(CustomOption.fromMap).toList();
  }

  Future<List<CustomOption>> getDeletedCustomOptionsByCategory(
      String category) async {
    final db = await database;
    final maps = await db.query(
      'custom_options',
      where: 'category = ? AND isDeleted = 1',
      whereArgs: [category],
    );
    return maps.map(CustomOption.fromMap).toList();
  }

  Future<bool> restoreDeletedCustomOption(String category, String value) async {
    final db = await database;
    final now = DateTime.now().millisecondsSinceEpoch;
    final res = await db.update(
      'custom_options',
      {
        'isDeleted': 0,
        'updatedAt': now,
        'syncStatus': 'pending',
      },
      where: 'category = ? AND value = ? AND isDeleted = 1',
      whereArgs: [category, value],
    );
    if (res > 0) {
      _notifyChange();
      return true;
    }
    return false;
  }

  /// Checks if a crop has any associated entries in investments or outputs.
  Future<bool> hasEntriesForCrop(String cropName) async {
    final db = await database;

    // Check investments
    final invCount = Sqflite.firstIntValue(await db.rawQuery(
          'SELECT COUNT(*) FROM investments WHERE crop = ? AND isDeleted = 0',
          [cropName],
        )) ??
        0;
    if (invCount > 0) return true;

    // Check outputs
    final outCount = Sqflite.firstIntValue(await db.rawQuery(
          'SELECT COUNT(*) FROM outputs WHERE crop = ? AND isDeleted = 0',
          [cropName],
        )) ??
        0;
    if (outCount > 0) return true;

    // Check helper_transactions
    final helperCount = Sqflite.firstIntValue(await db.rawQuery(
          'SELECT COUNT(*) FROM helper_transactions WHERE crop = ? AND isDeleted = 0',
          [cropName],
        )) ??
        0;
    if (helperCount > 0) return true;

    return false;
  }

  Future<int> insertCustomOption(CustomOption opt) async {
    final db = await database;
    final toInsert = opt.copyWith(syncStatus: 'pending');
    final id =
        await db.insert('custom_options', toInsert.toMap()..remove('id'));
    _notifyChange();
    return id;
  }

  Future<void> softDeleteCustomOption(String category, String value) async {
    final db = await database;
    final now = DateTime.now().millisecondsSinceEpoch;

    // First, check if it exists in DB. If not (it's a predefined info), we insert it as deleted.
    final existing = await db.query(
      'custom_options',
      where: 'category = ? AND value = ?',
      whereArgs: [category, value],
    );

    if (existing.isEmpty) {
      await insertCustomOption(CustomOption(
        category: category,
        value: value,
        isDeleted: true,
        updatedAt: now,
      ));
    } else {
      await db.update(
        'custom_options',
        {
          'isDeleted': 1,
          'updatedAt': now,
          'syncStatus': 'pending',
        },
        where: 'category = ? AND value = ?',
        whereArgs: [category, value],
      );
    }
    _notifyChange();
  }

  // ────────── AI Assistant Summary ──────────
}

class RecentActivity {
  final String sourceTable; // 'investment', 'output', 'helper'
  final int id;
  final String uuid;
  final String title;
  final String subtitle;
  final String type; // Raw type for icon mapping
  final String crop;
  final int date;
  final double amount;

  RecentActivity({
    required this.sourceTable,
    required this.id,
    required this.uuid,
    required this.title,
    required this.subtitle,
    required this.type,
    required this.crop,
    required this.date,
    required this.amount,
  });

  factory RecentActivity.fromMap(Map<String, dynamic> map) {
    try {
      final table = map['sourceTable'] as String? ?? '';
      double calculatedAmount = 0;
      String displaySubtitle = '';
      String displayTitle = map['crop'] as String? ?? '';
      String rawType = '';

      if (table == 'investment') {
        final inv = Investment.fromMap(map);
        calculatedAmount = inv.totalAmount;
        displaySubtitle = inv.displayInvestmentType;
        rawType = inv.investmentType;
      } else if (table == 'output') {
        final out = Output.fromMap(map);
        calculatedAmount = out.revenue;
        displaySubtitle = 'Harvest';
        rawType = 'Harvest';
      } else if (table == 'helper') {
        final txn = HelperTransaction.fromMap(map);
        calculatedAmount = txn.totalAmount;
        displayTitle = txn.helperName;
        displaySubtitle = txn.transactionType;
        rawType = txn.transactionType;
      }

      return RecentActivity(
        sourceTable: table,
        id: (map['id'] as num?)?.toInt() ?? 0,
        uuid: map['uuid'] as String? ?? '',
        title: displayTitle,
        subtitle: displaySubtitle,
        type: rawType,
        crop: map['crop'] as String? ?? '',
        date: (map['date'] as num?)?.toInt() ?? 0,
        amount: calculatedAmount,
      );
    } catch (e, stack) {
      debugPrint('Error in RecentActivity.fromMap: $e\n$stack');
      // Return a dummy activity instead of crashing the list
      return RecentActivity(
        sourceTable: 'error',
        id: 0,
        uuid: '',
        title: 'Error loading',
        subtitle: '',
        type: '',
        crop: '',
        date: 0,
        amount: 0,
      );
    }
  }
}
