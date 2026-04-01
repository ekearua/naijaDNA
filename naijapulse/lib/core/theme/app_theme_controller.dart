import 'package:flutter/material.dart';

class AppThemeController extends ChangeNotifier {
  ThemeMode _themeMode = ThemeMode.system;
  String _textSizeKey = 'small';
  double _textScaleFactor = 0.92;

  ThemeMode get themeMode => _themeMode;
  String get textSizeKey => _textSizeKey;
  double get textScaleFactor => _textScaleFactor;

  void setThemeMode(ThemeMode mode) {
    if (_themeMode == mode) {
      return;
    }
    _themeMode = mode;
    notifyListeners();
  }

  Brightness resolveBrightness(Brightness systemBrightness) {
    switch (_themeMode) {
      case ThemeMode.light:
        return Brightness.light;
      case ThemeMode.dark:
        return Brightness.dark;
      case ThemeMode.system:
        return systemBrightness;
    }
  }

  void toggleDarkMode(Brightness systemBrightness) {
    final currentBrightness = resolveBrightness(systemBrightness);
    if (currentBrightness == Brightness.dark) {
      setThemeMode(ThemeMode.light);
      return;
    }
    setThemeMode(ThemeMode.dark);
  }

  void setThemeModeFromKey(String key) {
    final normalized = key.trim().toLowerCase();
    switch (normalized) {
      case 'light':
        setThemeMode(ThemeMode.light);
        return;
      case 'dark':
        setThemeMode(ThemeMode.dark);
        return;
      case 'system':
      default:
        setThemeMode(ThemeMode.system);
        return;
    }
  }

  String themeModeKey() {
    switch (_themeMode) {
      case ThemeMode.light:
        return 'light';
      case ThemeMode.dark:
        return 'dark';
      case ThemeMode.system:
        return 'system';
    }
  }

  void setTextSizeFromKey(String key) {
    final normalized = _normalizeTextSizeKey(key);
    final scale = _textScaleForKey(normalized);

    if (_textSizeKey == normalized && _textScaleFactor == scale) {
      return;
    }

    _textSizeKey = normalized;
    _textScaleFactor = scale;
    notifyListeners();
  }

  String _normalizeTextSizeKey(String key) {
    final normalized = key.trim().toLowerCase();
    switch (normalized) {
      case 'small':
      case 'normal':
      case 'large':
        return normalized;
      default:
        return 'small';
    }
  }

  double _textScaleForKey(String key) {
    switch (key) {
      case 'small':
        return 0.92;
      case 'large':
        return 1.08;
      case 'normal':
      default:
        return 1.0;
    }
  }
}
