import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:package_info_plus/package_info_plus.dart';
import '../services/firebase_init.dart';
import '../services/sync_service.dart';
import '../database/app_database.dart';


class SyncProvider extends ChangeNotifier {
  final SyncService _syncService = SyncService();
  final Connectivity _connectivity = Connectivity();
  
  bool _isSyncing = false;
  bool _syncRequestedDuringActiveSync = false;
  DateTime? _lastSyncTime;
  String? _lastSyncError;
  StreamSubscription? _dbSubscription;
  StreamSubscription? _connectivitySubscription;
  StreamSubscription? _authSubscription;
  StreamSubscription? _profileSubscription;
  Timer? _debounceTimer;
  
  bool get isSyncing => _isSyncing;
  DateTime? get lastSyncTime => _lastSyncTime;
  /// Non-null when the most recent sync attempt failed.
  String? get lastSyncError => _lastSyncError;

  SyncProvider() {
    _init();
    
    // Manual/Connectivity syncs only
  }

  @override
  void dispose() {
    _dbSubscription?.cancel();
    _connectivitySubscription?.cancel();
    _authSubscription?.cancel();
    _profileSubscription?.cancel();
    _debounceTimer?.cancel();
    super.dispose();
  }

  void _init() async {
    // Listen for connectivity changes to trigger sync when coming back online
    _connectivitySubscription = _connectivity.onConnectivityChanged.listen((List<ConnectivityResult> results) {
      // Bug fix: use .any() instead of checking only results.first.
      // On Android/iOS the list can contain multiple connection types
      // (e.g. [wifi, mobile]). We are online if ANY result is not 'none'.
      if (results.any((r) => r != ConnectivityResult.none)) {
        requestSync(immediate: true);
      }
    });

    // Wait for Firebase to initialize in background before checking auth
    await FirebaseInit.initialize();

    // Initial sync on app launch if authenticated
    _authSubscription = FirebaseAuth.instance.authStateChanges().listen((user) async {
      if (user != null) {
        requestSync(immediate: true);
        
        try {
          final pkgInfo = await PackageInfo.fromPlatform();
          await FirebaseFirestore.instance.collection('users_profiles').doc(user.uid).set({
            'appVersion': pkgInfo.version,
          }, SetOptions(merge: true));
        } catch (e) {
          debugPrint('Error saving app version: $e');
        }
        
        _profileSubscription?.cancel();
        _profileSubscription = FirebaseFirestore.instance.collection('users_profiles').doc(user.uid).snapshots().listen((doc) async {
          if (doc.exists && doc.data() != null && doc.data()!['forceResync'] == true) {
            debugPrint('Admin triggered remote force re-sync! Resetting local data...');
            // 1. Clear flag to prevent loop
            await doc.reference.update({'forceResync': false});
            
            // 2. Clear local sync timer to force full historical download
            final prefs = await SharedPreferences.getInstance();
            await prefs.remove('lastSyncTime');
            _lastSyncTime = null;
            
            // 3. Set all existing local records to pending to ensure they merge correctly
            final db = await AppDatabase.instance.database;
            for (final table in ['investments', 'outputs', 'helper_transactions', 'custom_options']) {
              await db.update(table, {'syncStatus': 'pending'});
            }
            
            // 4. Trigger sync
            requestSync(immediate: true);
          }
        });
      } else {
        _profileSubscription?.cancel();
      }
    });
  }

  /// Requests a synchronization. 
  /// If [immediate] is true, it triggers sync now.
  /// Otherwise, it uses a 5-second debounce to batch multiple changes.
  Future<void> requestSync({bool immediate = false}) async {
    if (_isSyncing) {
      _syncRequestedDuringActiveSync = true;
      return;
    }

    if (_debounceTimer?.isActive ?? false) {
      _debounceTimer!.cancel();
    }

    if (immediate) {
      await _performSync();
    } else {
      _debounceTimer = Timer(const Duration(seconds: 5), () {
        _performSync();
      });
    }
  }

  Future<void> _performSync() async {
    if (_isSyncing) return;
    
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final connectivityResult = await _connectivity.checkConnectivity();
    if (connectivityResult.every((r) => r == ConnectivityResult.none)) return;

    try {
      _isSyncing = true;
      _lastSyncError = null;
      notifyListeners();

      final prefs = await SharedPreferences.getInstance();
      final lastTime = prefs.getInt('lastSyncTime');

      await _syncService.syncAll(lastSyncTime: lastTime);
      
      final now = DateTime.now();
      _lastSyncTime = now;
      await prefs.setInt('lastSyncTime', now.millisecondsSinceEpoch);
      
      debugPrint('Sync successful at $_lastSyncTime');
    } catch (e) {
      _lastSyncError = e.toString();
      debugPrint('Sync failed: $e');
    } finally {
      _isSyncing = false;
      if (_syncRequestedDuringActiveSync) {
        _syncRequestedDuringActiveSync = false;
        // Bug fix: trigger immediately instead of re-debouncing — we already
        // waited through one full sync cycle; there is no reason to wait 5 more
        // seconds for the queued follow-up sync.
        requestSync(immediate: true);
      }
      notifyListeners();
    }
  }
}
