import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/user_profile.dart';

class UserService {
  static const String _prefKeyUserId = 'abalone_user_id';
  static const String _prefKeyProfile = 'abalone_user_profile';
  static const String _firestoreCollection = 'users';

  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Cache to avoid repeated disk reads
  static UserProfile? _cachedProfile;
  static String? _cachedUserId;

  // SharedPreferences singleton cache
  static SharedPreferences? _prefsCache;

  static Future<SharedPreferences> get _prefs async {
    _prefsCache ??= await SharedPreferences.getInstance();
    return _prefsCache!;
  }

  static Future<String> generateDeviceUserId() async {
    try {
      final deviceInfo = DeviceInfoPlugin();
      String rawId = '';

      if (defaultTargetPlatform == TargetPlatform.android) {
        final android = await deviceInfo.androidInfo;
        rawId = '${android.id}-${android.fingerprint}-${android.model}-${android.brand}';
      } else if (defaultTargetPlatform == TargetPlatform.iOS) {
        final ios = await deviceInfo.iosInfo;
        rawId = '${ios.identifierForVendor ?? ''}-${ios.name}-${ios.model}';
      } else {
        rawId = 'web-${DateTime.now().microsecondsSinceEpoch}';
      }

      final bytes = utf8.encode(rawId);
      final hash = sha256.convert(bytes);
      return hash.toString().substring(0, 16);
    } catch (e) {
      final fallback = 'fallback-${DateTime.now().microsecondsSinceEpoch}';
      final bytes = utf8.encode(fallback);
      final hash = sha256.convert(bytes);
      return hash.toString().substring(0, 16);
    }
  }

  static Future<String> getOrCreateUserId() async {
    // Return cached if available
    if (_cachedUserId != null) return _cachedUserId!;

    final prefs = await _prefs;
    String? existing = prefs.getString(_prefKeyUserId);

    if (existing != null && existing.isNotEmpty) {
      _cachedUserId = existing;
      return existing;
    }

    final newId = await generateDeviceUserId();
    await prefs.setString(_prefKeyUserId, newId);
    _cachedUserId = newId;
    return newId;
  }

  static Future<void> saveProfileLocal(UserProfile profile) async {
    _cachedProfile = profile;
    final prefs = await _prefs;
    final json = jsonEncode(profile.toMap());
    // Don't await - fire and forget for speed
    prefs.setString(_prefKeyProfile, json);
  }

  static Future<UserProfile?> loadProfileLocal() async {
    // Return cached if available
    if (_cachedProfile != null) return _cachedProfile;

    final prefs = await _prefs;
    final json = prefs.getString(_prefKeyProfile);
    if (json == null) return null;

    try {
      final map = jsonDecode(json) as Map<String, dynamic>;
      _cachedProfile = UserProfile.fromMap(map);
      return _cachedProfile;
    } catch (e) {
      return null;
    }
  }

  static Future<void> saveProfileToFirestore(UserProfile profile) async {
    try {
      await _firestore
          .collection(_firestoreCollection)
          .doc(profile.userId)
          .set(profile.toMap(), SetOptions(merge: true));
    } catch (_) {
      // Silently fail - local profile still works
    }
  }

  static Future<UserProfile?> loadProfileFromFirestore(String userId) async {
    try {
      final doc = await _firestore
          .collection(_firestoreCollection)
          .doc(userId)
          .get()
          .timeout(const Duration(seconds: 3));

      if (doc.exists && doc.data() != null) {
        return UserProfile.fromMap(doc.data()!);
      }
    } catch (_) {
      // Timeout or network error - use local
    }
    return null;
  }

  static Future<bool> isNameAvailable(String name, String currentUserId) async {
    if (name.trim().isEmpty) return false;
    if (name.trim().length < 3) return false;
    if (name.trim().length > 16) return false;

    try {
      final query = await _firestore
          .collection(_firestoreCollection)
          .where('displayName', isEqualTo: name.trim())
          .limit(1)
          .get()
          .timeout(const Duration(seconds: 3));

      if (query.docs.isEmpty) return true;
      return query.docs.first.id == currentUserId;
    } catch (_) {
      return true; // Allow offline
    }
  }

  static Future<UserProfile?> getProfile(String userId) async {
    return loadProfileFromFirestore(userId);
  }

  static Future<void> saveProfile(UserProfile profile) async {
    await saveProfileLocal(profile);
    // Save to firestore in background - don't wait
    saveProfileToFirestore(profile);
  }

  /// Pre-warm the SharedPreferences cache during splash
  static Future<void> preWarm() async {
    // Start loading prefs + userId in parallel
    final prefsFuture = _prefs;
    final idFuture = getOrCreateUserId();
    await Future.wait([prefsFuture, idFuture]);
  }

  /// Fast initialization - local first, firestore in background
  static Future<UserProfile> initializeUser() async {
    // 1. Get userId (may already be cached from preWarm)
    final userId = await getOrCreateUserId();

    // 2. Try cache first (instant)
    if (_cachedProfile != null && _cachedProfile!.userId == userId) {
      // Still sync in background but return immediately
      _syncFromFirestoreInBackground(userId);
      return _cachedProfile!;
    }

    // 3. Try local storage (very fast - prefs may be pre-warmed)
    UserProfile? profile = await loadProfileLocal();
    if (profile != null && profile.userId == userId) {
      _cachedProfile = profile;
      // Sync from firestore in background (don't block UI)
      _syncFromFirestoreInBackground(userId);
      return profile;
    }

    // 4. Create new profile immediately (don't wait for firestore)
    profile = UserProfile.defaultProfile(userId);
    _cachedProfile = profile;
    await saveProfileLocal(profile);

    // Try firestore in background
    _syncFromFirestoreInBackground(userId);

    return profile;
  }

  /// Background sync - doesn't block UI
  static Future<void> _syncFromFirestoreInBackground(String userId) async {
    try {
      final remote = await loadProfileFromFirestore(userId);
      if (remote != null) {
        // If remote has newer data, update local
        if (_cachedProfile != null &&
            remote.updatedAt.isAfter(_cachedProfile!.updatedAt)) {
          _cachedProfile = remote;
          await saveProfileLocal(remote);
        }
      } else if (_cachedProfile != null) {
        // Push local to firestore
        saveProfileToFirestore(_cachedProfile!);
      }
    } catch (_) {
      // Network error - ignore, local works fine
    }
  }

  /// Clear cache (for testing)
  static void clearCache() {
    _cachedProfile = null;
    _cachedUserId = null;
    _prefsCache = null;
  }
}