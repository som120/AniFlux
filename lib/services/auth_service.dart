import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/foundation.dart';

class AuthService {
  static final FirebaseAuth _auth = FirebaseAuth.instance;
  static final GoogleSignIn _googleSignIn = GoogleSignIn();

  /// Track true historical DAU by incrementing activeUsers for today's date
  static Future<void> trackDailyActiveUser() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final todayStr = DateTime.now().toIso8601String().substring(0, 10);
      final lastLoggedDate = prefs.getString('lastLoggedDate');

      if (lastLoggedDate != todayStr) {
        await FirebaseFirestore.instance
            .collection('DailyActiveUsers')
            .doc(todayStr)
            .set({
          'activeUsers': FieldValue.increment(1),
        }, SetOptions(merge: true));

        await prefs.setString('lastLoggedDate', todayStr);
        if (kDebugMode) {
          debugPrint('Incremented DAU count for today: $todayStr');
        }
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('Error tracking daily active user: $e');
      }
    }
  }

  /// Update the user's lastActive timestamp in Firestore
  static Future<void> updateLastActive() async {
    final user = _auth.currentUser;
    if (user == null) return;

    try {
      await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .set({
        'lastActive': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
      if (kDebugMode) {
        debugPrint('Updated lastActive for user: ${user.uid}');
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('Error updating lastActive: $e');
      }
    }
  }

  /// Get the current user
  static User? get currentUser => _auth.currentUser;

  /// Stream of authentication state changes
  static Stream<User?> get authStateChanges => _auth.authStateChanges();

  /// Check if user is logged in
  static bool get isLoggedIn => _auth.currentUser != null;

  /// Sign out and clear all cache
  static Future<void> signOut() async {
    try {
      // Clear cached images
      await CachedNetworkImage.evictFromCache('');

      // Sign out from Google if signed in with Google
      if (await _googleSignIn.isSignedIn()) {
        await _googleSignIn.signOut();
      }

      // Sign out from Firebase
      await _auth.signOut();
    } catch (e) {
      debugPrint('Error during sign out: $e');
      rethrow;
    }
  }

  /// Get user display name
  static String? get displayName => _auth.currentUser?.displayName;

  /// Get user email
  static String? get email => _auth.currentUser?.email;

  /// Get user photo URL
  static String? get photoURL => _auth.currentUser?.photoURL;
}
