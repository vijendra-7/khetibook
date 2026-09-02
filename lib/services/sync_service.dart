import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../database/app_database.dart';
import '../models/investment.dart';
import '../models/output.dart';
import '../models/helper_transaction.dart';
import '../models/custom_option.dart';

import '../services/auth_service.dart';

class SyncService {
  FirebaseFirestore get _firestore => FirebaseFirestore.instance;
  FirebaseAuth get _auth => FirebaseAuth.instance;
  final AuthService _authService = AuthService();
  final AppDatabase _db = AppDatabase.instance;

  String? get _userId => _auth.currentUser?.uid;

  // Collection names in Firestore
  static const String _investmentsColl = 'investments';
  static const String _outputsColl = 'outputs';
  static const String _helpersColl = 'helper_transactions';
  static const String _optionsColl = 'custom_options';
  static const String _globalColl = 'global_metadata';

  /// Uploads all records marked as 'pending' to Firestore using WriteBatch.
  Future<void> uploadPending() async {
    final uid = _userId;
    if (uid == null) return;

    final db = await _db.database;
    final writeBatch = _firestore.batch();
    final dbBatch = db.batch();
    bool hasChanges = false;

    // Helper to process each collection
    Future<void> processCollection(String table, String collection) async {
      final pending = await db.query(table, where: 'syncStatus = ?', whereArgs: ['pending']);
      for (var m in pending) {
        Map<String, dynamic> map = Map<String, dynamic>.from(m);
        hasChanges = true;

        // For investments, we must include child items for cloud sync
        if (table == 'investments') {
          final inv = Investment.fromMap(map);
          final items = await _db.getInvestmentItems(inv.uuid);
          map = inv.copyWith(items: items).toMap();
        }

        final docRef = _firestore.collection('users').doc(uid).collection(collection).doc(map['uuid'] as String);
        writeBatch.set(docRef, map);
        // Bug fix: match on uuid only — updatedAt may have changed if the user
        // edited the record while this sync was in flight, causing the old
        // 'AND updatedAt = ?' condition to silently match 0 rows.
        dbBatch.update(table, {'syncStatus': 'synced'}, where: 'uuid = ?', whereArgs: [map['uuid'] as String]);
      }
    }

    await processCollection('investments', _investmentsColl);
    await processCollection('outputs', _outputsColl);
    await processCollection('helper_transactions', _helpersColl);
    await processCollection('custom_options', _optionsColl);

    if (hasChanges) {
      // Bug fix: commit sequentially — Firestore first, then local SQLite.
      // If we ran them in parallel and Firestore succeeded but SQLite failed
      // (or vice versa), the two stores would end up permanently out of sync.
      await writeBatch.commit();
      await dbBatch.commit(noResult: true);
      _db.notifyChange();
    }
  }

  /// Downloads latest records from Firestore and merges them locally using batching and parallel fetches.
  /// If [since] is provided, only records updated after that timestamp are fetched.
  Future<void> downloadAndMerge({int? since}) async {
    final uid = _userId;
    if (uid == null) return;

    final db = await _db.database;

    // Helper to create filtered query
    Query query(String collection) {
      Query q = _firestore.collection('users').doc(uid).collection(collection);
      if (since != null) {
        q = q.where('updatedAt', isGreaterThan: since);
      }
      return q;
    }

    // 1. Fetch remote data first to determine which local records we actually need to check
    final remoteResults = await Future.wait([
      query(_investmentsColl).get(),
      query(_outputsColl).get(),
      query(_helpersColl).get(),
      query(_optionsColl).get(),
      _firestore.collection(_globalColl).get(), // 1e. Fetch Global Admin Options
    ]);

    final invSnapshot = remoteResults[0];
    final outSnapshot = remoteResults[1];
    final helperSnapshot = remoteResults[2];
    final optSnapshot = remoteResults[3];
    // globalSnapshot (remoteResults[4]) is fetched to warm the Firestore cache;
    // its contents are consumed by GlobalOptionsProvider's real-time stream.

    // 2. Extract UUIDs to perform targeted local queries
    final invUuids = invSnapshot.docs.map((d) => d.id).toList();
    final outUuids = outSnapshot.docs.map((d) => d.id).toList();
    final helperUuids = helperSnapshot.docs.map((d) => d.id).toList();
    final optUuids = optSnapshot.docs.map((d) => d.id).toList();

    // 3. Fetch ONLY the specific local records we are syncing
    Future<Map<String, T>> fetchLocal<T>(String table, List<String> uuids, T Function(Map<String, dynamic>) fromMap) async {
      if (uuids.isEmpty) return {};
      
      final Map<String, T> results = {};
      
      // SQLite has a limit (usually 999) on the number of host variables in a single query.
      // We chunk the UUIDs into batches of 900 to stay safely below this limit.
      const int batchSize = 900;
      for (var i = 0; i < uuids.length; i += batchSize) {
        final end = (i + batchSize < uuids.length) ? i + batchSize : uuids.length;
        final chunk = uuids.sublist(i, end);
        
        final placeholders = List.generate(chunk.length, (_) => '?').join(',');
        final List<Map<String, dynamic>> maps = await db.query(
          table, 
          where: 'uuid IN ($placeholders)', 
          whereArgs: chunk,
        );
        
        for (var m in maps) {
          results[m['uuid'] as String] = fromMap(m);
        }
      }
      
      return results;
    }

    final localResults = await Future.wait([
      fetchLocal('investments', invUuids, Investment.fromMap),
      fetchLocal('outputs', outUuids, Output.fromMap),
      fetchLocal('helper_transactions', helperUuids, HelperTransaction.fromMap),
      fetchLocal('custom_options', optUuids, CustomOption.fromMap),
    ]);

    final localInvs = localResults[0] as Map<String, Investment>;
    final localOuts = localResults[1] as Map<String, Output>;
    final localHelpers = localResults[2] as Map<String, HelperTransaction>;
    final localOpts = localResults[3] as Map<String, CustomOption>;

    final batch = db.batch();

    // 2. Process Investments
    for (var doc in invSnapshot.docs) {
      final remote = Investment.fromMap(doc.data() as Map<String, dynamic>).copyWith(syncStatus: 'synced');
      final local = localInvs[remote.uuid];
      
      if (local == null) {
        batch.insert('investments', remote.toSqlMap()..remove('id'));
        for (final item in remote.items) {
          batch.insert('investment_items', item.toMap()..remove('id'));
        }
      } else if (remote.updatedAt > local.updatedAt) {
        batch.update('investments', remote.toSqlMap(), where: 'uuid = ?', whereArgs: [remote.uuid]);
        batch.delete('investment_items', where: 'investmentUuid = ?', whereArgs: [remote.uuid]);
        for (final item in remote.items) {
          batch.insert('investment_items', item.toMap()..remove('id'));
        }
      }
    }

    // 3. Process Outputs
    for (var doc in outSnapshot.docs) {
      final remote = Output.fromMap(doc.data() as Map<String, dynamic>).copyWith(syncStatus: 'synced');
      final local = localOuts[remote.uuid];
      
      if (local == null) {
        batch.insert('outputs', remote.toMap()..remove('id'));
      } else if (remote.updatedAt > local.updatedAt) {
        batch.update('outputs', remote.toMap(), where: 'uuid = ?', whereArgs: [remote.uuid]);
      }
    }

    // 4. Process Helpers
    for (var doc in helperSnapshot.docs) {
      final remote = HelperTransaction.fromMap(doc.data() as Map<String, dynamic>).copyWith(syncStatus: 'synced');
      final local = localHelpers[remote.uuid];
      
      if (local == null) {
        batch.insert('helper_transactions', remote.toMap()..remove('id'));
      } else if (remote.updatedAt > local.updatedAt) {
        batch.update('helper_transactions', remote.toMap(), where: 'uuid = ?', whereArgs: [remote.uuid]);
      }
    }

    // 5. Process Options
    for (var doc in optSnapshot.docs) {
      final remote = CustomOption.fromMap(doc.data() as Map<String, dynamic>).copyWith(syncStatus: 'synced');
      final local = localOpts[remote.uuid];
      
      if (local == null) {
        batch.insert('custom_options', remote.toMap()..remove('id'));
      } else if (remote.updatedAt > local.updatedAt) {
        batch.update('custom_options', remote.toMap(), where: 'uuid = ?', whereArgs: [remote.uuid]);
      }
    }

    // 6. Global Admin Options are handled by GlobalOptionsProvider stream
    // No longer auto-adding to user's local custom_options to keep a clean slate.

    await batch.commit(noResult: true);
    _db.notifyChange();
  }

  /// Performs a full sync: upload then download.
  Future<void> syncAll({int? lastSyncTime}) async {
    final user = _auth.currentUser;
    if (user != null) {
      unawaited(_authService.updateUserProfile(user));
    }
    await uploadPending();
    await downloadAndMerge(since: lastSyncTime);
  }

  /// Permanently deletes a record from Firestore.
  Future<void> deleteRemote(String table, String uuid) async {
    final uid = _userId;
    if (uid == null) return;

    String collection;
    switch (table) {
      case 'investments': collection = _investmentsColl; break;
      case 'outputs': collection = _outputsColl; break;
      case 'helper_transactions': collection = _helpersColl; break;
      case 'custom_options': collection = _optionsColl; break;
      default: return;
    }

    try {
      await _firestore.collection('users').doc(uid).collection(collection).doc(uuid).delete();
      debugPrint('Remote delete successful: $collection/$uuid');
    } catch (e) {
      debugPrint('Remote delete failed: $e');
    }
  }
}
