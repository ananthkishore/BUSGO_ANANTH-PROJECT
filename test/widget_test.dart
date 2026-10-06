// This is a basic Flutter widget test.
//
// To perform an interaction with a widget in your test, use the WidgetTester
// utility in the flutter_test package. For example, you can send tap and scroll
// gestures. You can also use WidgetTester to find child widgets in the widget
// tree, read text, and verify that the values of widget properties are correct.

import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:flutter_application_12/app/app.dart';
import 'package:flutter_application_12/app/theme.dart';
import 'package:flutter_application_12/core/constants/app_roles.dart';
import 'package:flutter_application_12/models/notification_model.dart';
import 'package:flutter_application_12/features/auth/forgot_password_screen.dart';
import 'package:flutter_application_12/features/auth/login_screen.dart';
import 'package:flutter_application_12/features/auth/register_screen.dart';
import 'package:flutter_application_12/features/owner/bus_management_details_screen.dart';
import 'package:flutter_application_12/firebase_options.dart';
import 'package:flutter_application_12/providers/auth_provider.dart';
import 'package:flutter_application_12/widgets/busgo_ui.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
  });

  test('Firestore admin role map resolves correctly', () {
    expect(
      AppUserRoleExtension.fromFirestoreMap({'role': 'admin'}),
      AppUserRole.admin,
    );
    expect(
      AppUserRoleExtension.fromFirestoreMap({'admin': true}),
      AppUserRole.admin,
    );
    expect(
      AppUserRoleExtension.fromFirestoreMap({'userType': 'owner'}),
      AppUserRole.owner,
    );
  });

  testWidgets('BUSGO branding renders', (WidgetTester tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: Center(child: BusGoBrandMark())),
      ),
    );

    expect(find.text('BUSGO'), findsOneWidget);
    expect(find.byIcon(Icons.directions_bus_filled_rounded), findsOneWidget);
  });

  testWidgets('theme changes do not recreate the app router', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const BusGoApp());

    final materialApp = tester.widget<MaterialApp>(find.byType(MaterialApp));
    final routerBefore = materialApp.routerConfig;

    final themeController = tester
        .element(find.byType(MaterialApp))
        .read<BusGoThemeController>();
    await themeController.setThemeMode(ThemeMode.dark);
    await tester.pump();

    final materialAppAfter = tester.widget<MaterialApp>(
      find.byType(MaterialApp),
    );
    final routerAfter = materialAppAfter.routerConfig;

    expect(identical(routerBefore, routerAfter), isTrue);
    expect(themeController.themeMode, ThemeMode.dark);
  });

  testWidgets('role selector opens the three BUSGO roles', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: BusGoRoleSelector(selectedRole: null, onChanged: (_) {}),
        ),
      ),
    );

    expect(find.text('Select your role'), findsOneWidget);
    await tester.tap(find.byType(DropdownButton<AppUserRole>));
    await tester.pumpAndSettle();
    expect(find.text('Customer'), findsOneWidget);
    expect(find.text('Bus Owner'), findsOneWidget);
    expect(find.text('Admin'), findsOneWidget);
  });

  testWidgets('login screen follows the BUSGO auth structure', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      ChangeNotifierProvider(
        create: (_) => AuthProvider(),
        child: const MaterialApp(home: LoginScreen()),
      ),
    );

    expect(find.text('BUSGO'), findsWidgets);
    expect(find.text('Welcome Back!'), findsOneWidget);
    expect(find.text('Your journey starts here.'), findsOneWidget);
    expect(find.text('Forgot password?'), findsOneWidget);
    expect(find.text('Create Account'), findsOneWidget);
  });

  testWidgets('signup screen keeps the same BUSGO card structure', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      ChangeNotifierProvider(
        create: (_) => AuthProvider(),
        child: const MaterialApp(home: RegisterScreen()),
      ),
    );

    expect(find.text('Create Account'), findsOneWidget);
    expect(find.text('Join BUSGO and start your journey.'), findsOneWidget);
    expect(find.text('LOGIN'), findsOneWidget);
  });

  testWidgets('forgot password screen uses the polished reset flow', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      ChangeNotifierProvider(
        create: (_) => AuthProvider(),
        child: const MaterialApp(home: ForgotPasswordScreen()),
      ),
    );

    expect(find.text('Forgot your password?'), findsOneWidget);
    expect(find.text('Reset your password'), findsOneWidget);
    expect(find.text('Send reset link'), findsOneWidget);
    expect(find.text('Back to login'), findsOneWidget);
  });

  test('notification model resolves legacy booking and bus ids', () {
    final bookingId = NotificationModel.resolveRelatedId(
      {'bookingId': 'bk_123', 'relatedBookingId': null},
      const ['relatedBookingId', 'bookingId', 'requestId'],
    );
    final busId = NotificationModel.resolveRelatedId(
      {'busId': 'bus_456', 'relatedBusId': null},
      const ['relatedBusId', 'busId'],
    );

    expect(bookingId, 'bk_123');
    expect(busId, 'bus_456');
  });

  testWidgets(
    'owner bus details screen handles empty bus id without blank page',
    (WidgetTester tester) async {
      await tester.pumpWidget(
        ChangeNotifierProvider(
          create: (_) => AuthProvider(),
          child: const MaterialApp(
            home: OwnerBusManagementDetailsScreen(busId: ''),
          ),
        ),
      );

      expect(find.text('Unable to load bus details'), findsOneWidget);
      expect(find.text('Back to my buses'), findsOneWidget);
    },
  );
}
