import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../utils/app_semantic_colors.dart';

class ThemeProvider with ChangeNotifier {
  static const String _themeKey = 'theme_mode';
  bool _isDarkMode = false;

  bool get isDarkMode => _isDarkMode;

  ThemeProvider() {
    _loadThemeMode();
  }

  /// Load the saved theme mode from shared preferences
  Future<void> _loadThemeMode() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      _isDarkMode = prefs.getBool(_themeKey) ?? false;
      notifyListeners();
    } catch (e) {
      // If there's an error loading preferences, use default (light mode)
      _isDarkMode = false;
    }
  }

  /// Toggle between light and dark mode
  Future<void> toggleTheme() async {
    _isDarkMode = !_isDarkMode;
    notifyListeners();
    await _saveThemeMode();
  }

  /// Save the current theme mode to shared preferences
  Future<void> _saveThemeMode() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_themeKey, _isDarkMode);
    } catch (e) {
      // If there's an error saving preferences, continue without saving
      debugPrint('Error saving theme preference: $e');
    }
  }

  /// Get the current theme data based on the mode
  ThemeData get themeData {
    const accentColor = Color(0xFFFCB900);
    const lightSurface = Color(0xFFFBFBF7);
    const lightBackground = Color(0xFFF5F6F1);
    const darkSurface = Color(0xFF242821);

    if (_isDarkMode) {
      final colorScheme = ColorScheme.fromSeed(
        seedColor: accentColor,
        brightness: Brightness.dark,
        surface: darkSurface,
      ).copyWith(primary: accentColor, onPrimary: const Color(0xFF26240E));

      return ThemeData(
        colorScheme: colorScheme,
        useMaterial3: true,
        brightness: Brightness.dark,
        scaffoldBackgroundColor: const Color(0xFF191C18),
        extensions: <ThemeExtension<dynamic>>[
          AppSemanticColors.dark(colorScheme),
        ],
        appBarTheme: const AppBarTheme(
          centerTitle: false,
          elevation: 0,
          scrolledUnderElevation: 0,
          backgroundColor: Color(0xFF191C18),
        ),
        cardTheme: CardThemeData(
          elevation: 0,
          color: const Color(0xFF242821),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
          ),
        ),
      );
    } else {
      final colorScheme =
          ColorScheme.fromSeed(
            seedColor: accentColor,
            brightness: Brightness.light,
            surface: lightSurface,
          ).copyWith(
            primary: const Color(0xFF8A6500),
            onPrimary: Colors.white,
            primaryContainer: const Color(0xFFFFE08A),
            onPrimaryContainer: const Color(0xFF2B2200),
            surfaceContainer: const Color(0xFFF0F1EB),
            surfaceContainerHighest: const Color(0xFFE7E9E2),
            outlineVariant: const Color(0xFFD9DCD3),
          );

      return ThemeData(
        colorScheme: colorScheme,
        useMaterial3: true,
        brightness: Brightness.light,
        scaffoldBackgroundColor: lightBackground,
        extensions: <ThemeExtension<dynamic>>[
          AppSemanticColors.light(colorScheme),
        ],
        appBarTheme: const AppBarTheme(
          centerTitle: false,
          elevation: 0,
          scrolledUnderElevation: 0,
          backgroundColor: lightSurface,
          foregroundColor: Color(0xFF20231F),
        ),
        cardTheme: CardThemeData(
          elevation: 0,
          color: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
        ),
        navigationBarTheme: NavigationBarThemeData(
          height: 72,
          backgroundColor: lightSurface,
          indicatorColor: const Color(0xFFFFE9A8),
          labelTextStyle: WidgetStateProperty.resolveWith(
            (states) => TextStyle(
              fontSize: 12,
              fontWeight: states.contains(WidgetState.selected)
                  ? FontWeight.w700
                  : FontWeight.w500,
            ),
          ),
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
          ),
        ),
      );
    }
  }
}
