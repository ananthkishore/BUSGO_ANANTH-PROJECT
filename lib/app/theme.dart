import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class BusGoTokens {
  static const navy = Color(0xFF081A33);
  static const navySoft = Color(0xFF0F2A4D);
  static const blue = Color(0xFF246BFE);
  static const teal = Color(0xFF0E9AA2);
  static const orange = Color(0xFFFFB547);
  static const canvas = Color(0xFFF7F9FC);
  static const muted = Color(0xFF64748B);
  static const border = Color(0xFFE5EAF2);

  static const radiusSmall = 12.0;
  static const radiusMedium = 18.0;
  static const radiusLarge = 24.0;
  static const pagePadding = 20.0;
}

class BusGoThemeController extends ChangeNotifier {
  BusGoThemeController() {
    _loadThemeMode();
  }

  static const String _storageKey = 'busgo_theme_mode';

  ThemeMode _themeMode = ThemeMode.system;

  ThemeMode get themeMode => _themeMode;

  Future<void> _loadThemeMode() async {
    final prefs = await SharedPreferences.getInstance();
    final rawValue = prefs.getString(_storageKey);
    _themeMode = _resolveThemeMode(rawValue);
    notifyListeners();
  }

  Future<void> setThemeMode(ThemeMode themeMode) async {
    if (_themeMode == themeMode) return;

    _themeMode = themeMode;
    notifyListeners();

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_storageKey, themeMode.name);
  }

  static ThemeMode _resolveThemeMode(String? rawValue) {
    switch (rawValue) {
      case 'light':
        return ThemeMode.light;
      case 'dark':
        return ThemeMode.dark;
      case 'system':
      default:
        return ThemeMode.system;
    }
  }
}

class BusGoTheme {
  static ThemeData get light {
    const primary = BusGoTokens.blue;
    const secondary = BusGoTokens.navy;
    const surface = BusGoTokens.canvas;
    const accent = BusGoTokens.orange;
    const inkMuted = BusGoTokens.muted;

    final colorScheme = ColorScheme.fromSeed(
      seedColor: primary,
      brightness: Brightness.light,
      primary: primary,
      secondary: secondary,
      tertiary: accent,
      surface: surface,
    ).copyWith(outline: BusGoTokens.teal, outlineVariant: BusGoTokens.teal);

    return ThemeData(
      useMaterial3: true,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: surface,
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.transparent,
        foregroundColor: secondary,
        elevation: 0,
        centerTitle: false,
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        margin: EdgeInsets.zero,
        color: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      ),
      chipTheme: const ChipThemeData(
        side: BorderSide(color: BusGoTokens.teal),
      ),
      iconTheme: const IconThemeData(color: secondary),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: const Color(0xFFF1F5FA),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: primary, width: 1.5),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: Colors.red, width: 1.2),
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 18,
          vertical: 17,
        ),
        labelStyle: const TextStyle(
          color: inkMuted,
          fontWeight: FontWeight.w600,
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          minimumSize: const Size.fromHeight(52),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: const Size.fromHeight(52),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          textStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          minimumSize: const Size.fromHeight(52),
          foregroundColor: secondary,
          side: const BorderSide(color: Color(0xFFD6DFEC)),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          textStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
        ),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: Colors.white,
        elevation: 8,
        indicatorColor: primary.withValues(alpha: 0.10),
        labelTextStyle: WidgetStateProperty.all(
          const TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
        ),
      ),
      textTheme: const TextTheme(
        headlineLarge: TextStyle(
          fontSize: 30,
          fontWeight: FontWeight.w800,
          color: secondary,
          letterSpacing: 0,
          height: 1.18,
        ),
        headlineMedium: TextStyle(
          fontSize: 23,
          fontWeight: FontWeight.w700,
          color: secondary,
          letterSpacing: 0,
          height: 1.2,
        ),
        headlineSmall: TextStyle(
          fontSize: 20,
          fontWeight: FontWeight.w800,
          color: secondary,
          letterSpacing: 0,
          height: 1.2,
        ),
        titleLarge: TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.w700,
          color: secondary,
          letterSpacing: 0,
          height: 1.28,
        ),
        titleMedium: TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w700,
          color: secondary,
          height: 1.28,
        ),
        bodyLarge: TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w400,
          color: secondary,
          height: 1.5,
        ),
        bodyMedium: TextStyle(fontSize: 14, color: inkMuted, height: 1.5),
        bodySmall: TextStyle(fontSize: 12, color: inkMuted, height: 1.45),
      ),
      dividerTheme: const DividerThemeData(color: Color(0xFFE5EAF2)),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
    );
  }

  static ThemeData get dark {
    const primary = Color(0xFF2563EB);
    const neutralText = Color(0xFFF8FAFC);
    const muted = Color(0xFFB8C4D1);
    const background = Color(0xFF061A2A);
    const primarySurface = Color(0xFF0B2033);
    const elevated = Color(0xFF12263D);
    const inputSurface = Color(0xFF1A324C);
    const accent = Color(0xFF123B63);

    final colorScheme = ColorScheme(
      brightness: Brightness.dark,
      primary: primary,
      onPrimary: Colors.white,
      secondary: accent,
      onSecondary: Colors.white,
      tertiary: const Color(0xFF22C55E),
      onTertiary: Colors.white,
      error: const Color(0xFFEF4444),
      onError: Colors.white,
      surface: background,
      onSurface: neutralText,
      surfaceContainerLowest: const Color(0xFF071B2C),
      surfaceContainerLow: primarySurface,
      surfaceContainer: primarySurface,
      surfaceContainerHigh: elevated,
      surfaceContainerHighest: inputSurface,
      onSurfaceVariant: muted,
      outline: BusGoTokens.teal,
      outlineVariant: BusGoTokens.teal,
      shadow: const Color(0xFF020B13),
      scrim: const Color(0xFF020B13),
      inverseSurface: const Color(0xFFF8FAFC),
      onInverseSurface: const Color(0xFF061A2A),
      primaryContainer: primary.withValues(alpha: 0.18),
      onPrimaryContainer: neutralText,
      secondaryContainer: accent.withValues(alpha: 0.18),
      onSecondaryContainer: neutralText,
      tertiaryContainer: const Color(0xFF22C55E).withValues(alpha: 0.18),
      onTertiaryContainer: const Color(0xFFE6FFF0),
      errorContainer: const Color(0xFFEF4444).withValues(alpha: 0.18),
      onErrorContainer: const Color(0xFFFFE7E7),
    );

    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: background,
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.transparent,
        foregroundColor: Color(0xFFF8FAFC),
        elevation: 0,
        centerTitle: false,
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        margin: EdgeInsets.zero,
        color: elevated,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: elevated,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      ),
      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: elevated,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
      ),
      iconTheme: const IconThemeData(color: Color(0xFFF8FAFC)),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: inputSurface,
        hintStyle: const TextStyle(color: muted),
        labelStyle: const TextStyle(
          color: neutralText,
          fontWeight: FontWeight.w600,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: primary, width: 1.5),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: Color(0xFFF87171), width: 1.2),
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 18,
          vertical: 17,
        ),
      ),
      segmentedButtonTheme: SegmentedButtonThemeData(
        style: ButtonStyle(
          backgroundColor: WidgetStateProperty.resolveWith((states) {
            if (states.contains(WidgetState.selected)) {
              return primary;
            }
            return inputSurface;
          }),
          foregroundColor: WidgetStateProperty.resolveWith((states) {
            if (states.contains(WidgetState.selected)) {
              return Colors.white;
            }
            return neutralText;
          }),
          side: WidgetStateProperty.all(
            const BorderSide(color: Color(0xFF31506C)),
          ),
          textStyle: WidgetStateProperty.all(
            const TextStyle(inherit: false, fontWeight: FontWeight.w700),
          ),
        ),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: inputSurface,
        selectedColor: primary,
        labelStyle: const TextStyle(
          color: neutralText,
          fontWeight: FontWeight.w700,
        ),
        secondaryLabelStyle: const TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.w800,
        ),
        side: const BorderSide(color: BusGoTokens.teal),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          minimumSize: const Size.fromHeight(52),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          backgroundColor: primary,
          foregroundColor: Colors.white,
          textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: const Size.fromHeight(52),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          backgroundColor: primary,
          foregroundColor: Colors.white,
          textStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          minimumSize: const Size.fromHeight(52),
          foregroundColor: neutralText,
          side: const BorderSide(color: Color(0xFF31506C)),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          textStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
        ),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: primarySurface,
        surfaceTintColor: Colors.transparent,
        elevation: 8,
        indicatorColor: primary.withValues(alpha: 0.18),
        shadowColor: const Color(0x33000000),
        iconTheme: WidgetStateProperty.resolveWith((states) {
          return IconThemeData(
            color: states.contains(WidgetState.selected) ? neutralText : muted,
          );
        }),
        labelTextStyle: WidgetStateProperty.all(
          const TextStyle(
            color: neutralText,
            fontSize: 12,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
      navigationRailTheme: NavigationRailThemeData(
        backgroundColor: primarySurface,
        indicatorColor: primary.withValues(alpha: 0.18),
        selectedIconTheme: const IconThemeData(color: neutralText),
        unselectedIconTheme: const IconThemeData(color: muted),
        selectedLabelTextStyle: const TextStyle(
          color: neutralText,
          fontWeight: FontWeight.w700,
        ),
        unselectedLabelTextStyle: const TextStyle(
          color: muted,
          fontWeight: FontWeight.w600,
        ),
      ),
      popupMenuTheme: PopupMenuThemeData(
        color: elevated,
        surfaceTintColor: Colors.transparent,
        iconColor: muted,
        textStyle: const TextStyle(color: neutralText),
      ),
      listTileTheme: const ListTileThemeData(
        textColor: neutralText,
        iconColor: neutralText,
      ),
      textTheme: const TextTheme(
        headlineLarge: TextStyle(
          fontSize: 30,
          fontWeight: FontWeight.w800,
          color: Color(0xFFF8FAFC),
          letterSpacing: 0,
          height: 1.18,
        ),
        headlineMedium: TextStyle(
          fontSize: 23,
          fontWeight: FontWeight.w700,
          color: Color(0xFFF8FAFC),
          letterSpacing: 0,
          height: 1.2,
        ),
        headlineSmall: TextStyle(
          fontSize: 20,
          fontWeight: FontWeight.w800,
          color: Color(0xFFF8FAFC),
          letterSpacing: 0,
          height: 1.2,
        ),
        titleLarge: TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.w700,
          color: Color(0xFFF8FAFC),
          letterSpacing: 0,
          height: 1.28,
        ),
        titleMedium: TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w700,
          color: Color(0xFFF8FAFC),
          height: 1.28,
        ),
        bodyLarge: TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w400,
          color: Color(0xFFE2E8F0),
          height: 1.5,
        ),
        bodyMedium: TextStyle(
          fontSize: 14,
          color: Color(0xFFE2E8F0),
          height: 1.5,
        ),
        bodySmall: TextStyle(fontSize: 12, color: muted, height: 1.45),
      ),
      dividerTheme: const DividerThemeData(color: Color(0xFF334155)),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: elevated,
        contentTextStyle: const TextStyle(color: Color(0xFFF8FAFC)),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
    );
  }
}
