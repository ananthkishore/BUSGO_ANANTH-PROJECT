import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../core/constants/app_roles.dart';
import '../../providers/auth_provider.dart';
import '../../repositories/notification_repository.dart';
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
    final colorScheme = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Help & Support'),
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
            BusGoSurface(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    Icons.support_agent_rounded,
                    size: 30,
                    color: colorScheme.primary,
                  ),
                  const SizedBox(height: 10),
                  Text(
                    'BUSGO help',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      color: colorScheme.onSurface,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    user == null
                        ? 'Guidance for whole-bus group travel and account access.'
                        : 'Guidance for your ${user.role.label.toLowerCase()} account and whole-bus trips.',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 22),
            Text(
              'Frequently asked questions',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                color: colorScheme.onSurface,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 8),
            for (final faq in _faqs)
              BusGoSurface(
                padding: EdgeInsets.zero,
                child: Material(
                  color: Colors.transparent,
                  child: ExpansionTile(
                    title: Text(
                      faq.$1,
                      style: TextStyle(color: colorScheme.onSurface),
                    ),
                    iconColor: colorScheme.primary,
                    collapsedIconColor: colorScheme.onSurfaceVariant,
                    childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                    expandedCrossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        faq.$2,
                        style: TextStyle(color: colorScheme.onSurfaceVariant),
                      ),
                    ],
                  ),
                ),
              ),
            const SizedBox(height: 16),
            if (user?.role == AppUserRole.admin)
              FilledButton.icon(
                onPressed: () => context.push('/admin/support'),
                icon: const Icon(Icons.inbox_rounded),
                label: const Text('Open Support Inbox'),
              )
            else ...[
              FilledButton.icon(
                onPressed: () => _showMessageAdminDialog(context),
                icon: const Icon(Icons.send_rounded),
                label: const Text('Message BUSGO Admin'),
              ),
              if (user != null &&
                  (user.role == AppUserRole.customer ||
                      user.role == AppUserRole.owner)) ...[
                const SizedBox(height: 8),
                OutlinedButton.icon(
                  onPressed: () => context.push('/support/${user.uid}'),
                  icon: const Icon(Icons.forum_outlined),
                  label: const Text('View support conversation'),
                ),
              ],
            ],
            const SizedBox(height: 16),
            Text(
              'For account-specific issues, include your registered email and request ID when contacting your organization’s BUSGO administrator.',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showMessageAdminDialog(BuildContext context) {
    final user = context.read<AuthProvider>().currentUser;
    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please sign in to message the BUSGO admin.'),
        ),
      );
      return;
    }

    final controller = TextEditingController();
    final repository = context.read<NotificationRepository>();
    final role = user.role.name.toLowerCase();
    final pageContext = context;

    showDialog<void>(
      context: context,
      builder: (dialogContext) {
        var sending = false;
        return StatefulBuilder(
          builder: (context, setState) {
            Future<void> submit() async {
              final message = controller.text.trim();
              if (message.isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Write a message before sending.'),
                  ),
                );
                return;
              }

              setState(() => sending = true);
              try {
                final recipientCount = await repository.sendMessageToAdmins(
                  senderRole: role,
                  senderId: user.uid,
                  senderName: user.name,
                  message: message,
                );
                if (!context.mounted) return;
                if (recipientCount == 0) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('No admin account is available right now.'),
                    ),
                  );
                  return;
                }
                if (dialogContext.mounted) Navigator.of(dialogContext).pop();
                if (pageContext.mounted) {
                  ScaffoldMessenger.of(pageContext).showSnackBar(
                    const SnackBar(
                      content: Text(
                        'Your message was sent to the BUSGO admin.',
                      ),
                    ),
                  );
                  pageContext.push('/support/${user.uid}');
                }
              } catch (error) {
                if (!context.mounted) return;
                final messageText = error is Exception
                    ? error.toString().replaceFirst('Exception: ', '')
                    : 'Unable to send your message. Please retry.';
                ScaffoldMessenger.of(
                  context,
                ).showSnackBar(SnackBar(content: Text(messageText)));
              } finally {
                if (context.mounted) {
                  setState(() => sending = false);
                }
              }
            }

            return AlertDialog(
              title: const Text('Message BUSGO Admin'),
              content: SizedBox(
                width: 420,
                child: TextField(
                  controller: controller,
                  autofocus: true,
                  minLines: 4,
                  maxLines: 6,
                  maxLength: 2000,
                  textCapitalization: TextCapitalization.sentences,
                  decoration: const InputDecoration(
                    hintText: 'Hi',
                    border: OutlineInputBorder(),
                    alignLabelWithHint: true,
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: sending
                      ? null
                      : () => Navigator.of(dialogContext).pop(),
                  child: const Text('Cancel'),
                ),
                FilledButton(
                  onPressed: sending ? null : submit,
                  child: Text(sending ? 'Sending...' : 'Send message'),
                ),
              ],
            );
          },
        );
      },
    );
  }
}
