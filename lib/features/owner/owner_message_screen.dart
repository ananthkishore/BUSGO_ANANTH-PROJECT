import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../providers/auth_provider.dart';
import '../../repositories/notification_repository.dart';
import '../../widgets/busgo_ui.dart';

class OwnerMessageScreen extends StatefulWidget {
  const OwnerMessageScreen({super.key});

  @override
  State<OwnerMessageScreen> createState() => _OwnerMessageScreenState();
}

class _OwnerMessageScreenState extends State<OwnerMessageScreen> {
  final _messageController = TextEditingController();
  bool _isSending = false;

  @override
  void dispose() {
    _messageController.dispose();
    super.dispose();
  }

  Future<void> _sendMessage() async {
    if (_isSending) return;

    final message = _messageController.text.trim();
    if (message.isEmpty) {
      _showMessage('Write a message before sending.');
      return;
    }

    final user = context.read<AuthProvider>().currentUser;
    if (user == null) {
      _showMessage('Sign in again to message the BUSGO admin.');
      return;
    }

    final role = user.role.name.toLowerCase();
    if (role != 'owner' && role != 'customer') {
      _showMessage('Only owner and customer accounts can contact BUSGO admin.');
      return;
    }

    setState(() => _isSending = true);
    try {
      final recipientCount = await context
          .read<NotificationRepository>()
          .sendMessageToAdmins(
            senderRole: role,
            senderId: user.uid,
            senderName: user.name,
            message: message,
          );
      if (!mounted) return;
      if (recipientCount == 0) {
        _showMessage('No admin account is available right now.');
        return;
      }
      _messageController.clear();
      _showMessage('Your message was sent to the BUSGO admin.');
      context.push('/support/${user.uid}');
    } catch (error) {
      if (!mounted) return;
      final messageText = error is Exception
          ? error.toString().replaceFirst('Exception: ', '')
          : 'Unable to send your message. Please retry.';
      _showMessage(messageText);
    } finally {
      if (mounted) setState(() => _isSending = false);
    }
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Message Admin')),
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) => SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 640),
                child: SizedBox(
                  width: double.infinity,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      BusGoSurface(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Icon(
                              Icons.support_agent_rounded,
                              color: Theme.of(context).colorScheme.primary,
                              size: 30,
                            ),
                            const SizedBox(height: 12),
                            Text(
                              'Message BUSGO Admin',
                              style: Theme.of(context).textTheme.titleLarge,
                            ),
                            const SizedBox(height: 6),
                            Text(
                              'Your message will be sent to the BUSGO admin team.',
                              style: Theme.of(context).textTheme.bodyMedium,
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 18),
                      TextField(
                        controller: _messageController,
                        enabled: !_isSending,
                        minLines: 6,
                        maxLines: 10,
                        maxLength: 2000,
                        textCapitalization: TextCapitalization.sentences,
                        decoration: const InputDecoration(
                          labelText: 'Your message',
                          hintText: 'How can the admin team help?',
                          alignLabelWithHint: true,
                          border: OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(height: 12),
                      BusGoPrimaryButton(
                        label: 'Send message',
                        icon: Icons.send_rounded,
                        loading: _isSending,
                        onPressed: _isSending ? null : _sendMessage,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
