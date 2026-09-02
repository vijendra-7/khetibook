import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';

class FirebaseInit {
  static Future<void>? _initFuture;

  /// Starts Firebase initialization in the background and returns a Future
  /// that resolves when complete. Safe to call multiple times.
  static Future<void> initialize() {
    if (_initFuture != null) return _initFuture!;
    
    _initFuture = Firebase.initializeApp().then((_) {
      // Set up Crashlytics error handlers once Firebase is confirmed ready.
      FlutterError.onError = FirebaseCrashlytics.instance.recordFlutterFatalError;
      PlatformDispatcher.instance.onError = (error, stack) {
        FirebaseCrashlytics.instance.recordError(error, stack, fatal: true);
        return true;
      };
    }).catchError((e) {
      debugPrint('Firebase init failed: $e');
    });

    return _initFuture!;
  }
}
