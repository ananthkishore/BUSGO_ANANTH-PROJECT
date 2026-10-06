import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/constants/app_roles.dart';
import '../../core/errors/auth_failure.dart';
import '../../models/support_message_model.dart';
import '../../providers/auth_provider.dart';
import '../../repositories/notification_repository.dart';
import '../../widgets/busgo_ui.dart';

class SupportConversationScreen extends StatefulWidget {
  const SupportConversationScreen({
    super.key,
    required this.conversationId,
  });

  final String conversationId;

  @override
  State<SupportConversationScreen> createState() =>
      _SupportConversationScreenState();
}

class _SupportConversationScreenState extends State<SupportConversationScreen> {
  final _messageController = TextEditingController();
  final _scrollController = ScrollController();
  bool _sending = false;
  bool _readUpdateQueued = false;

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _sendMessage(AppUserRole role, String uid, String name) async {
    if (_sending) return;
    final message = _messageController.text.trim();
    if (message.isEmpty) {
      _showMessage('Write a message before sending.');
      return;
    }
    if (role != AppUserRole.admin && uid != widget.conversationId) {
      _showMessage('You cannot access this support conversation.');
      return;
    }

    setState(() => _sending = true);
    try {
      final repository = context.read<NotificationRepository>();
      if (role == AppUserRole.admin) {
        await repository.sendAdminReply(
          conversationId: widget.conversationId,
          message: message,
        );
      } else {
        await repository.sendMessageToAdmins(
          senderRole: role.value,
          senderId: uid,
          senderName: name,
          message: message,
        );
      }
      if (!mounted) return;
      _messageController.clear();
      _showMessage(
        role == AppUserRole.admin
            ? 'Your reply was sent.'
            : 'Your message was sent to the BUSGO admin.',
      );
      _scrollToLatest();
    } on FirebaseException catch (error) {
      debugPrint(
        '[BUSGO MESSAGE DEBUG] conversationId=${widget.conversationId} operation=send errorCode=${error.code} errorMessage=${error.message}',
      );
      if (mounted) _showMessage(_sendErrorText(error));
    } on AuthFailure catch (error) {
      if (mounted) _showMessage(error.message);
    } catch (error) {
      debugPrint(
        '[BUSGO MESSAGE DEBUG] conversationId=${widget.conversationId} operation=send error=$error',
      );
      if (mounted) _showMessage('Unable to send your message. Please retry.');
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  String _sendErrorText(FirebaseException error) {
    if (error.code == 'permission-denied') {
      return 'You do not have permission to send this support message.';
    }
    return error.message ?? 'Unable to send your message. Please retry.';
  }

  void _queueReadUpdate() {
    if (_readUpdateQueued) return;
    _readUpdateQueued = true;
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;
      try {
        await context.read<NotificationRepository>().markSupportMessagesRead(
          widget.conversationId,
        );
      } catch (error) {
        debugPrint(
          '[BUSGO MESSAGE DEBUG] conversationId=${widget.conversationId} operation=mark_read error=$error',
        );
        if (mounted) {
          _showMessage('Unable to update the message read status.');
        }
      }
    });
  }

  void _scrollToLatest() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeOut,
        );
      }
    });
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    final user = context.watch<AuthProvider>().currentUser;
    if (user == null) {
      return const Scaffold(
        body: Center(child: Text('Please sign in to view support messages.')),
      );
    }
    final isAdmin = user.role == AppUserRole.admin;
    if (!isAdmin && user.uid != widget.conversationId) {
      return const Scaffold(
        body: Center(child: Text('You cannot access this conversation.')),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(
          isAdmin
              ? 'Support conversation'
              : 'Message BUSGO Admin',
        ),
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: StreamBuilder<List<SupportMessageModel>>(
                stream: context
                    .read<NotificationRepository>()
                    .watchSupportMessages(widget.conversationId),
                builder: (context, snapshot) {
                  if (snapshot.hasError) {
                    return BusGoErrorState(
                      title: "Couldn't load support messages",
                      message: 'Please check your connection and retry.',
                      onRetry: () => setState(() {}),
                    );
                  }
                  if (!snapshot.hasData) {
                    return const BusGoLoadingState(
                      label: 'Loading support messages...',
                    );
                  }
                  final messages = snapshot.data!;
                  if (messages.isNotEmpty) {
                    _queueReadUpdate();
                    _scrollToLatest();
                  }
                  if (messages.isEmpty) {
                    return BusGoEmptyState(
                      icon: Icons.support_agent_rounded,
                      title: 'No messages yet',
                      message: isAdmin
                          ? 'This support conversation has no messages.'
                          : 'Send a message to start a conversation with BUSGO Admin.',
                    );
                  }
                  return ListView.builder(
                    controller: _scrollController,
                    padding: const EdgeInsets.all(16),
                    itemCount: messages.length,
                    itemBuilder: (context, index) =>
                        _messageBubble(messages[index], user.uid),
                  );
                },
              ),
            ),
            Material(
              elevation: 4,
              color: Theme.of(context).colorScheme.surface,
              child: SafeArea(
                top: false,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _messageController,
                          enabled: !_sending,
                          minLines: 1,
                          maxLines: 4,
                          maxLength: 2000,
                          decoration: const InputDecoration(
                            hintText: 'Write a message...',
                            counterText: '',
                            border: OutlineInputBorder(),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      IconButton.filled(
                        tooltip: 'Send message',
                        onPressed: _sending
                            ? null
                            : () => _sendMessage(user.role, user.uid, user.name),
                        icon: _sending
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            : const Icon(Icons.send_rounded),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _messageBubble(SupportMessageModel message, String currentUid) {
    final isMine = message.senderId == currentUid;
    final scheme = Theme.of(context).colorScheme;
    return Align(
      alignment: isMine ? Alignment.centerRight : Alignment.centerLeft,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 620),
        child: Container(
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: isMine ? scheme.primaryContainer : scheme.surfaceContainer,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                message.senderRole == 'admin'
                    ? 'BUSGO Admin'
                    : '${message.senderName} (${message.senderRole})',
                style: Theme.of(context).textTheme.labelMedium,
              ),
              const SizedBox(height: 5),
              Text(message.message),
              const SizedBox(height: 5),
              Text(
                message.createdAt.toLocal().toString().split('.').first,
                style: Theme.of(context).textTheme.labelSmall,
              ),
              Text(
                isMine
                    ? (message.isRead ? 'Read' : 'Sent')
                    : (message.isRead ? 'Read' : 'Unread'),
                style: Theme.of(context).textTheme.labelSmall,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
