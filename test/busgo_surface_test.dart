import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_application_12/features/owner/owner_message_screen.dart';
import 'package:flutter_application_12/widgets/busgo_ui.dart';

void main() {
  testWidgets('owner message screen fits a compact phone width', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(320, 640);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(const MaterialApp(home: OwnerMessageScreen()));

    expect(find.text('Message Admin'), findsOneWidget);
    expect(find.text('Your message'), findsOneWidget);
    expect(find.text('Send message'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('adaptive dashboard navigation follows available width', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(390, 844);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    var selectedIndex = 0;
    final destinations = [
      const NavigationDestination(
        icon: Icon(Icons.home_outlined),
        label: 'Home',
      ),
      const NavigationDestination(
        icon: Icon(Icons.person_outline),
        label: 'Profile',
      ),
      const NavigationDestination(
        icon: Icon(Icons.directions_bus_outlined),
        label: 'My Buses',
      ),
      const NavigationDestination(
        icon: Icon(Icons.inbox_outlined),
        label: 'Requests',
      ),
      const NavigationDestination(
        icon: Icon(Icons.route_outlined),
        label: 'Trips',
      ),
      const NavigationDestination(
        icon: Icon(Icons.notifications_none),
        label: 'Alerts',
      ),
    ];

    Widget buildApp() => MaterialApp(
      home: BusGoAdaptiveScaffold(
        body: const Center(child: Text('Dashboard content')),
        selectedIndex: selectedIndex,
        items: destinations,
        onSelected: (index) => selectedIndex = index,
      ),
    );

    await tester.pumpWidget(buildApp());
    expect(find.byType(NavigationBar), findsOneWidget);
    expect(find.byType(NavigationRail), findsNothing);
    expect(tester.takeException(), isNull);

    tester.view.physicalSize = const Size(768, 1024);
    await tester.pumpWidget(buildApp());
    expect(find.byType(NavigationRail), findsOneWidget);
    expect(find.byType(NavigationBar), findsNothing);
    await tester.tap(find.byIcon(Icons.person_outline));
    await tester.pumpWidget(buildApp());
    expect(selectedIndex, 1);
    expect(tester.takeException(), isNull);
  });

  testWidgets('BusGoSurface provides Material for nested ListTiles', (
    tester,
  ) async {
    var tapped = false;
    await tester.pumpWidget(
      MaterialApp(
        home: BusGoSurface(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                tileColor: Colors.white,
                title: const Text('Surface list tile'),
                onTap: () => tapped = true,
              ),
            ],
          ),
        ),
      ),
    );

    expect(tester.takeException(), isNull);
    await tester.tap(find.text('Surface list tile'));
    await tester.pump();

    expect(tapped, isTrue);
    expect(tester.takeException(), isNull);
  });
}
