import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/auth_service.dart';

import '../services/firebase_init.dart';

/// Key used to persist login state across cold starts.
const _kIsLoggedIn = 'is_logged_in';

class AuthProvider extends ChangeNotifier {
  final AuthService _authService = AuthService();
  User? _user;
  bool _isLoading = false;
  bool _isInitialized = false;

  // True once the Firebase auth stream has emitted at least one event.
  bool _isStreamReady = false;

  // True if SharedPreferences cache says the user was logged in last session.
  // Used to skip the loading spinner and go straight to HomeScreen.
  bool _cachedLoggedIn = false;

  User? get user => _user;
  bool get isLoading => _isLoading;
  bool get isInitialized => _isInitialized;

  /// Auth state is "determined" if either:
  ///   a) The local cache already told us the answer, OR
  ///   b) The Firebase stream has fired.
  /// When true, the UI should show HomeScreen or LoginScreen — never a spinner.
  bool get isAuthDetermined => _cachedLoggedIn || _isStreamReady;

  /// Whether the cache believes the user is logged in.
  /// The UI uses this to decide which screen to show before Firebase responds.
  bool get isCachedLoggedIn => _cachedLoggedIn;

  AuthProvider() {
    _init();
  }

  Future<void> _init() async {
    // ── Step 0: Read local cache (instant, < 1ms) ──────────────────────────
    // This is the key to eliminating the startup spinner for returning users.
    final prefs = await SharedPreferences.getInstance();
    _cachedLoggedIn = prefs.getBool(_kIsLoggedIn) ?? false;
    if (_cachedLoggedIn) {
      _isInitialized = true;
      notifyListeners(); // UI immediately shows HomeScreen (no spinner)
    }

    // WAIT for Firebase to finish booting in the background before touching it.
    await FirebaseInit.initialize();

    // ── Step 1: Check FirebaseAuth synchronous cache ───────────────────────
    _user = _authService.currentUser;
    if (_user != null && !_cachedLoggedIn) {
      // Firebase already has the user — update cache and notify
      _isInitialized = true;
      _isStreamReady = true;
      _cachedLoggedIn = true;
      await prefs.setBool(_kIsLoggedIn, true);
      notifyListeners();
    }

    // ── Step 2: Listen to auth stream (authoritative source) ───────────────
    _authService.user.listen((User? user) async {
      final bool userChanged = user?.uid != _user?.uid;
      _user = user;
      _isInitialized = true;
      _isStreamReady = true;

      if (user != null) {
        // Session confirmed — refresh cache
        _cachedLoggedIn = true;
        await prefs.setBool(_kIsLoggedIn, true);
      } else {
        // Session expired or signed out — clear cache
        // UI will redirect from HomeScreen to LoginScreen
        _cachedLoggedIn = false;
        await prefs.remove(_kIsLoggedIn);
      }

      if (userChanged) notifyListeners();
    });

    // ── Step 3: Failsafe silent sign-in ────────────────────────────────────
    // Only runs if stream hasn't fired yet after 400ms.
    // 400ms is enough for Firebase on any real device; was 1200ms (too slow).
    if (_user == null) {
      await Future.delayed(const Duration(milliseconds: 400));
      if (!_isStreamReady) {
        final silentUser = await _authService.signInSilently();
        if (silentUser != null) {
          _user = silentUser;
          _cachedLoggedIn = true;
          await prefs.setBool(_kIsLoggedIn, true);
        }
        // ✦ FIX: Do NOT clear prefs cache here even if silentUser == null.
        //   The prefs cache reflects what the user explicitly did (login/logout).
        //   signInSilently() can return null simply because there is no Google
        //   account cached on the device, OR because of a transient network
        //   failure — neither means the Firebase session has expired.
        //   Only the authoritative auth stream (Step 2) is allowed to clear it.
        _isInitialized = true;
        _isStreamReady = true;
        // Only notify if _user is still null — if the stream already set it,
        // it already notified and we don't want to push a stale null back.
        if (_user == null) notifyListeners();
      }
    }
  }

  Future<bool> signInWithGoogle() async {
    _setLoading(true);
    final userCredential = await _authService.signInWithGoogle();
    if (userCredential != null) {
      // Persist login state so next cold start is instant
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_kIsLoggedIn, true);
      _cachedLoggedIn = true;
    }
    _setLoading(false);
    return userCredential != null;
  }

  Future<bool> signInWithApple() async {
    _setLoading(true);
    final userCredential = await _authService.signInWithApple();
    if (userCredential != null) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_kIsLoggedIn, true);
      _cachedLoggedIn = true;
    }
    _setLoading(false);
    return userCredential != null;
  }

  Future<bool> signInAnonymously() async {
    _setLoading(true);
    final userCredential = await _authService.signInAnonymously();
    if (userCredential != null) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_kIsLoggedIn, true);
      _cachedLoggedIn = true;
    }
    _setLoading(false);
    return userCredential != null;
  }

  Future<void> signOut() async {
    _setLoading(true);
    // Clear cache before signing out
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_kIsLoggedIn);
    _cachedLoggedIn = false;
    await _authService.signOut();
    _setLoading(false);
  }

  void _setLoading(bool value) {
    _isLoading = value;
    notifyListeners();
  }
}
