import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Global theme provider using ChangeNotifier for efficient rebuilds.
/// Persists the user's theme choice to SharedPreferences.
class ThemeProvider extends ChangeNotifier {
  static const String _keyTheme = 'theme_mode';
  static const String _keyAmoled = 'amoled_mode';

  /// Singleton instance — accessible globally without context.
  static final ThemeProvider instance = ThemeProvider._internal();

  ThemeMode _themeMode = ThemeMode.system;
  bool _isAmoled = false;

  ThemeProvider._internal() {
    _loadFromPrefs();
  }

  ThemeMode get themeMode => _themeMode;
  bool get isAmoled => _isAmoled;

  /// Loads the persisted theme mode from SharedPreferences.
  Future<void> _loadFromPrefs() async {
    // 🔥 If no user is logged in, always default to light mode
    if (FirebaseAuth.instance.currentUser == null) {
      _themeMode = ThemeMode.light;
      _isAmoled = false;
      notifyListeners();
      return;
    }

    final prefs = await SharedPreferences.getInstance();
    final stored = prefs.getString(_keyTheme);
    if (stored != null) {
      _themeMode = ThemeMode.values.firstWhere(
        (m) => m.name == stored,
        orElse: () => ThemeMode.light, // Default to light instead of system
      );
    } else {
      _themeMode = ThemeMode.light; // Ensure light mode if no preference exists
    }
    
    _isAmoled = prefs.getBool(_keyAmoled) ?? false;
    notifyListeners();
  }

  /// Public method to reload the theme (e.g., after login).
  Future<void> refresh() async {
    await _loadFromPrefs();
  }

  /// Updates the theme mode and persists the choice.
  Future<void> setThemeMode(ThemeMode mode) async {
    _themeMode = mode;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyTheme, mode.name);
    notifyListeners();
  }

  /// Updates the amoled mode and persists the choice.
  Future<void> toggleAmoled(bool value) async {
    _isAmoled = value;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keyAmoled, value);
    notifyListeners();
  }

  /// Resets the theme to light mode (used on logout).
  Future<void> resetToDefault() async {
    await setThemeMode(ThemeMode.light);
    await toggleAmoled(false);
  }

  /// Whether the app is currently in dark mode (resolved against platform).
  bool isDark(BuildContext context) {
    if (_themeMode == ThemeMode.system) {
      return MediaQuery.platformBrightnessOf(context) == Brightness.dark;
    }
    return _themeMode == ThemeMode.dark;
  }
}
