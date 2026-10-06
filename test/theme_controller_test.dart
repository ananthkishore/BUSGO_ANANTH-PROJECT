import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:flutter_application_12/app/theme.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('theme controller stores and exposes the selected theme mode', () async {
    SharedPreferences.setMockInitialValues({});

    final controller = BusGoThemeController();
    await controller.setThemeMode(ThemeMode.dark);

    expect(controller.themeMode, ThemeMode.dark);

    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString('busgo_theme_mode'), 'dark');
  });

  test('dark theme uses readable text roles on navy surfaces', () {
    final theme = BusGoTheme.dark;

    expect(theme.scaffoldBackgroundColor, const Color(0xFF061A2A));
    expect(theme.cardTheme.color, const Color(0xFF12263D));
    expect(theme.colorScheme.onSurface, const Color(0xFFF8FAFC));
    expect(theme.colorScheme.onSurfaceVariant, const Color(0xFFB8C4D1));
    expect(theme.textTheme.bodyMedium?.color, const Color(0xFFE2E8F0));
    expect(theme.textTheme.bodySmall?.color, const Color(0xFFB8C4D1));
  });
}
