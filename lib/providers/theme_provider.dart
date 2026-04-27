import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Global theme provider using ValueNotifier for efficient rebuilds.
/// Persists the user's theme choice to SharedPreferences.
class ThemeProvider extends ValueNotifier<ThemeMode> {
  static const String _key = 'theme_mode';

  /// Singleton instance — accessible globally without context.
  static final ThemeProvider instance = ThemeProvider._internal();

  ThemeProvider._internal() : super(ThemeMode.system) {
    _loadFromPrefs();
  }

  /// Loads the persisted theme mode from SharedPreferences.
  Future<void> _loadFromPrefs() async {
    // 🔥 If no user is logged in, always default to light mode
    if (FirebaseAuth.instance.currentUser == null) {
      value = ThemeMode.light;
      return;
    }

    final prefs = await SharedPreferences.getInstance();
    final stored = prefs.getString(_key);
    if (stored != null) {
      value = ThemeMode.values.firstWhere(
        (m) => m.name == stored,
        orElse: () => ThemeMode.light, // Default to light instead of system
      );
    } else {
      value = ThemeMode.light; // Ensure light mode if no preference exists
    }
  }

  /// Public method to reload the theme (e.g., after login).
  Future<void> refresh() async {
    await _loadFromPrefs();
  }

  /// Updates the theme mode and persists the choice.
  Future<void> setThemeMode(ThemeMode mode) async {
    value = mode;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key, mode.name);
  }

  /// Resets the theme to light mode (used on logout).
  Future<void> resetToDefault() async {
    await setThemeMode(ThemeMode.light);
  }

  /// Whether the app is currently in dark mode (resolved against platform).
  bool isDark(BuildContext context) {
    if (value == ThemeMode.system) {
      return MediaQuery.platformBrightnessOf(context) == Brightness.dark;
    }
    return value == ThemeMode.dark;
  }
}
