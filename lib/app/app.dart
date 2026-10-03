import 'package:flutter/material.dart';
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
        Provider(create: (_) => BusRepository()),
        Provider(create: (_) => BookingRequestRepository()),
        Provider(create: (_) => NotificationRepository()),
        Provider(create: (_) => UserRepository()),
        ChangeNotifierProvider(create: (_) => BookingWorkflowProvider()),
      ],
      child: Builder(
        builder: (context) {
          final authProvider = context.read<AuthProvider>();
          final router = createAppRouter(authProvider);

          return MaterialApp.router(
            title: 'BUSGO',
            debugShowCheckedModeBanner: false,
            theme: BusGoTheme.light,
            routerConfig: router,
          );
        },
      ),
    );
  }
}
