import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../services/notification_service.dart';

/// App-wide settings, saved with shared_preferences.
class SettingsProvider extends ChangeNotifier {
  static const _kTheme = 'theme_mode';
  static const _kSound = 'sound_enabled';
  static const _kAccent = 'accent_index';

  /// Accent colour choices shown on the Settings screen.
  static const List<Color> accents = [
    Color(0xFFE85D9A), // Bubblegum Pink
    Color(0xFF8E7CF0), // Lavender
    Color(0xFF2FBF9F), // Mint
    Color(0xFFFF8A65), // Peach
    Color(0xFF4DA3F5), // Sky Blue
  ];

  SharedPreferences? _prefs;
  ThemeMode _themeMode = ThemeMode.system;
  bool _soundEnabled = true;
  int _accentIndex = 0;

  ThemeMode get themeMode => _themeMode;

  bool get soundEnabled => _soundEnabled;

  int get accentIndex => _accentIndex;

  Color get accentColor => accents[_accentIndex];

  /// Reads saved values. Call once in main() before runApp().
  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    _prefs = prefs;

    final saved = prefs.getString(_kTheme);
    _themeMode = ThemeMode.values.firstWhere(
          (m) => m.name == saved,
      orElse: () => ThemeMode.system,
    );
    _soundEnabled = prefs.getBool(_kSound) ?? true;

    final i = prefs.getInt(_kAccent) ?? 0;
    _accentIndex = (i >= 0 && i < accents.length) ? i : 0;

    NotificationService.instance.soundEnabled = _soundEnabled;
  }

  // Each setter updates the UI first, then saves to disk.

  Future<void> setThemeMode(ThemeMode mode) async {
    _themeMode = mode;
    notifyListeners();
    await _prefs?.setString(_kTheme, mode.name);
  }

  Future<void> setSoundEnabled(bool value) async {
    _soundEnabled = value;
    NotificationService.instance.soundEnabled = value;
    notifyListeners();
    await _prefs?.setBool(_kSound, value);
  }

  Future<void> setAccent(int index) async {
    _accentIndex = index;
    notifyListeners();
    await _prefs?.setInt(_kAccent, index);
  }
}