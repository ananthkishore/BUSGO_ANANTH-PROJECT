import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../core/constants/app_roles.dart';
import '../../models/support_message_model.dart';
import '../../providers/auth_provider.dart';
import '../../repositories/notification_repository.dart';
import '../../widgets/busgo_ui.dart';

class AdminSupportInboxScreen extends StatefulWidget {
  const AdminSupportInboxScreen({super.key});

  @override
  State<AdminSupportInboxScreen> createState() =>
      _AdminSupportInboxScreenState();
}

class _AdminSupportInboxScreenState extends State<AdminSupportInboxScreen> {
  String _filter = 'all';

  @override
  Widget build(BuildContext context) {
    final user = context.watch<AuthProvider>().currentUser;
    if (user == null || user.role != AppUserRole.admin) {
      return const Scaffold(
        body: Center(child: Text('Admin access is required for the support inbox.')),
      );
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Messages / Support Inbox')),
      body: StreamBuilder<List<SupportConversationModel>>(
        stream: context
            .read<NotificationRepository>()
            .watchSupportConversations(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return BusGoErrorState(
              title: "Couldn't load support conversations",
              message: 'Check your admin access and connection, then retry.',
              onRetry: () => setState(() {}),
            );
          }
          if (!snapshot.hasData) {
            return const BusGoLoadingState(
              label: 'Loading support conversations...',
            );
          }

          final conversations = snapshot.data!;
          final filtered = conversations.where(_matchesFilter).toList();
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
                child: Wrap(
                  spacing: 8,
                  children: [
                    _filterChip('all', 'All'),
                    _filterChip('customer', 'Customers'),
                    _filterChip('owner', 'Bus Owners'),
                  ],
                ),
              ),
              Expanded(
                child: filtered.isEmpty
                    ? BusGoEmptyState(
                        icon: Icons.forum_outlined,
                        title: conversations.isEmpty
                            ? 'No support conversations'
                            : 'No conversations in this filter',
                        message: conversations.isEmpty
                            ? 'Customer and bus owner messages will appear here.'
                            : 'Choose another filter to see conversations.',
                      )
                    : ListView.separated(
                        padding: const EdgeInsets.all(16),
                        itemCount: filtered.length,
                        separatorBuilder: (_, _) =>
                            const SizedBox(height: 8),
                        itemBuilder: (context, index) =>
                            _conversationTile(filtered[index]),
                      ),
              ),
            ],
          );
        },
      ),
    );
  }

  bool _matchesFilter(SupportConversationModel conversation) =>
      _filter == 'all' ||
      _filter == conversation.participantRole;

  Widget _filterChip(String value, String label) => FilterChip(
    label: Text(label),
    selected: _filter == value,
    onSelected: (_) => setState(() => _filter = value),
  );

  Widget _conversationTile(SupportConversationModel conversation) =>
      StreamBuilder<List<SupportMessageModel>>(
        stream: context
            .read<NotificationRepository>()
            .watchSupportMessages(conversation.id),
        builder: (context, snapshot) {
          final messages = snapshot.data ?? const <SupportMessageModel>[];
          final latest = messages.isEmpty ? null : messages.last;
          final hasUnread = messages.any(
            (message) => !message.isRead && message.senderRole != 'admin',
          );
          final roleName = conversation.participantRole == 'owner'
              ? 'Bus Owner'
              : 'Customer';
          return BusGoSurface(
            padding: EdgeInsets.zero,
            child: ListTile(
              leading: CircleAvatar(
                child: Icon(
                  conversation.participantRole == 'owner'
                      ? Icons.directions_bus_rounded
                      : Icons.person_rounded,
                ),
              ),
              title: Text(
                conversation.participantName.trim().isEmpty
                    ? roleName
                    : conversation.participantName,
              ),
              subtitle: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(roleName),
                  Text(
                    latest?.message ?? 'No messages yet',
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
              trailing: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  if (hasUnread)
                    const Chip(
                      label: Text('Unread'),
                      visualDensity: VisualDensity.compact,
                    ),
                  if (latest != null)
                    Text(
                      latest.createdAt.toLocal().toString().split('.').first,
                      style: Theme.of(context).textTheme.labelSmall,
                    ),
                ],
              ),
              isThreeLine: true,
              onTap: () => context.push('/support/${conversation.id}'),
            ),
          );
        },
      );
}
