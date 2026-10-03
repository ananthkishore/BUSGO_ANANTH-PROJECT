import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/constants/app_roles.dart';
import '../../providers/auth_provider.dart';
import '../../widgets/busgo_ui.dart';

class HelpSupportScreen extends StatelessWidget {
  const HelpSupportScreen({super.key});

  static const _faqs = [
    (
      'How does a BUSGO booking work?',
      'A customer requests an entire bus for a group trip. The bus owner reviews the request, then BUSGO verifies availability before a trip is confirmed.',
    ),
    (
      'When is my trip confirmed?',
      'A request is not confirmed when it is submitted or accepted by an owner. Confirmation happens only after BUSGO completes the availability review.',
    ),
    (
      'Where can I find my trip updates?',
      'Open Notifications in your role dashboard to read updates. Customer and owner notifications can link back to their related trip or request.',
    ),
    (
      'How do I update my account details?',
      'Open Profile, choose Personal Information, update your name or phone number, then save. Your email address is managed by Firebase Authentication.',
    ),
    (
      'How do I change my password?',
      'Open Profile or Settings, choose Change password, and verify your current password before saving the new one.',
    ),
    (
      'How can a bus owner respond to a request?',
      'Open Requests in the owner dashboard. Accepting sends the request to BUSGO for availability review; it does not confirm the trip.',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final user = context.watch<AuthProvider>().currentUser;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Help & Support'),
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
            BusGoSurface(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.support_agent_rounded, size: 30),
                  const SizedBox(height: 10),
                  Text(
                    'BUSGO help',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 6),
                  Text(
                    user == null
                        ? 'Guidance for whole-bus group travel and account access.'
                        : 'Guidance for your ${user.role.label.toLowerCase()} account and whole-bus trips.',
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 22),
            Text(
              'Frequently asked questions',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 8),
            for (final faq in _faqs)
              BusGoSurface(
                padding: EdgeInsets.zero,
                child: Material(
                  color: Colors.transparent,
                  child: ExpansionTile(
                    title: Text(faq.$1),
                    childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                    expandedCrossAxisAlignment: CrossAxisAlignment.start,
                    children: [Text(faq.$2)],
                  ),
                ),
              ),
            const SizedBox(height: 16),
            Text(
              'For account-specific issues, include your registered email and request ID when contacting your organization’s BUSGO administrator.',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ),
      ),
    );
  }
}
