import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ThemeController {
  ThemeController._();
  static final ThemeController instance = ThemeController._();
  final ValueNotifier<bool> isDark = ValueNotifier<bool>(false);
  static const _prefKey = 'is_dark_theme';

  Future<void> load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final v = prefs.getBool(_prefKey) ?? false;
      isDark.value = v;
    } catch (_) {}
  }

  void toggle() {
    isDark.value = !isDark.value;
    SharedPreferences.getInstance().then((prefs) => prefs.setBool(_prefKey, isDark.value));
  }
}
