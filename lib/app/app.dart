import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../providers/auth_provider.dart';
import '../providers/booking_workflow_provider.dart';
import '../repositories/booking_request_repository.dart';
import '../repositories/bus_repository.dart';
import '../repositories/notification_repository.dart';
import '../repositories/user_repository.dart';
import 'routes.dart';
import 'theme.dart';

class BusGoApp extends StatelessWidget {
  const BusGoApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AuthProvider()),
        ChangeNotifierProvider(create: (_) => BusGoThemeController()),
        Provider(create: (_) => BusRepository()),
        Provider(create: (_) => BookingRequestRepository()),
        Provider(create: (_) => NotificationRepository()),
        Provider(create: (_) => UserRepository()),
        ChangeNotifierProvider(create: (_) => BookingWorkflowProvider()),
        Provider<GoRouter>(
          create: (context) => createAppRouter(context.read<AuthProvider>()),
        ),
      ],
      child: Builder(
        builder: (context) {
          final themeController = context.watch<BusGoThemeController>();
          final router = context.read<GoRouter>();

          return MaterialApp.router(
            title: 'BUSGO',
            debugShowCheckedModeBanner: false,
            themeMode: themeController.themeMode,
            theme: BusGoTheme.light,
            darkTheme: BusGoTheme.dark,
            routerConfig: router,
          );
        },
      ),
    );
  }
}
