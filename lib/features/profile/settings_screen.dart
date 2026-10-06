import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../app/theme.dart';
import '../../widgets/busgo_ui.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final themeController = context.watch<BusGoThemeController>();
    final themeOptions = [
      _ThemeOption(
        label: 'Light',
        mode: ThemeMode.light,
        icon: Icons.light_mode_rounded,
      ),
      _ThemeOption(
        label: 'Dark',
        mode: ThemeMode.dark,
        icon: Icons.dark_mode_rounded,
      ),
      _ThemeOption(
        label: 'System',
        mode: ThemeMode.system,
        icon: Icons.brightness_auto_rounded,
      ),
    ];

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

    final colorScheme = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings'),
        leading: IconButton(
          tooltip: 'Back',
          onPressed: () => Navigator.of(context).maybePop(),
          icon: Icon(Icons.arrow_back_rounded, color: colorScheme.onSurface),
        ),
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 28),
          children: [
            Text(
              'Appearance',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                color: colorScheme.onSurface,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 10),
            BusGoSurface(
              padding: const EdgeInsets.all(16),
              child: SegmentedButton<ThemeMode>(
                segments: [
                  for (final option in themeOptions)
                    ButtonSegment<ThemeMode>(
                      value: option.mode,
                      label: Text(option.label),
                      icon: Icon(option.icon),
                    ),
                ],
                selected: {themeController.themeMode},
                onSelectionChanged: (selection) {
                  if (selection.isNotEmpty) {
                    themeController.setThemeMode(selection.first);
                  }
                },
              ),
            ),
            const SizedBox(height: 18),
            Text(
              'Account & information',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                color: colorScheme.onSurface,
                fontWeight: FontWeight.w800,
              ),
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

class _ThemeOption {
  const _ThemeOption({
    required this.label,
    required this.mode,
    required this.icon,
  });

  final String label;
  final ThemeMode mode;
  final IconData icon;
}
