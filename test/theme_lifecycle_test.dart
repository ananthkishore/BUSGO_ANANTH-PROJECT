import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:flutter_application_12/app/theme.dart';
import 'package:flutter_application_12/features/profile/settings_screen.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('theme changes keep Settings mounted on the current route', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({'busgo_theme_mode': 'light'});
    final router = GoRouter(
      initialLocation: '/settings',
      routes: [
        GoRoute(
          path: '/settings',
          builder: (context, state) => const SettingsScreen(),
        ),
      ],
    );

    addTearDown(router.dispose);

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider(create: (_) => BusGoThemeController()),
          Provider<GoRouter>.value(value: router),
        ],
        child: Builder(
          builder: (context) {
            final themeController = context.watch<BusGoThemeController>();
            return MaterialApp.router(
              theme: BusGoTheme.light,
              darkTheme: BusGoTheme.dark,
              themeMode: themeController.themeMode,
              routerConfig: context.read<GoRouter>(),
            );
          },
        ),
      ),
    );
    await tester.pumpAndSettle();

    final materialApp = tester.widget<MaterialApp>(find.byType(MaterialApp));
    final routerBefore = materialApp.routerConfig;
    expect(find.text('Settings'), findsOneWidget);

    for (final mode in [ThemeMode.dark, ThemeMode.light, ThemeMode.dark]) {
      await tester.tap(find.text(mode == ThemeMode.dark ? 'Dark' : 'Light'));
      await tester.pumpAndSettle();

      expect(find.text('Settings'), findsOneWidget);
      expect(router.routerDelegate.currentConfiguration.uri.path, '/settings');
      expect(
        tester.widget<MaterialApp>(find.byType(MaterialApp)).routerConfig,
        same(routerBefore),
      );
    }

    expect(
      Theme.of(tester.element(find.byType(SettingsScreen))).brightness,
      Brightness.dark,
    );
  });
}
