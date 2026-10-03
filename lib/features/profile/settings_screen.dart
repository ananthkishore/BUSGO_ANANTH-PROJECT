import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../widgets/busgo_ui.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    const items = [
      ('Personal information', Icons.person_outline_rounded, '/edit-profile'),
      ('Security', Icons.lock_outline_rounded, '/change-password'),
      ('Help & Support', Icons.support_agent_rounded, '/help'),
      ('About BUSGO', Icons.info_outline_rounded, '/legal/agreement'),
      ('Terms of Service', Icons.description_outlined, '/legal/terms'),
      ('Privacy Policy', Icons.privacy_tip_outlined, '/legal/privacy'),
      (
        'Cancellation Policy',
        Icons.assignment_late_outlined,
        '/legal/cancellation',
      ),
    ];

    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings'),
        leading: IconButton(
          tooltip: 'Back',
          onPressed: () => Navigator.of(context).maybePop(),
          icon: const Icon(Icons.arrow_back_rounded),
        ),
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 28),
          children: [
            Text(
              'Account & information',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 10),
            BusGoSurface(
              padding: EdgeInsets.zero,
              child: Column(
                children: [
                  for (final item in items)
                    BusGoSectionTile(
                      title: item.$1,
                      icon: item.$2,
                      onTap: () => context.push(item.$3),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
