import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

import '../core/constants/app_roles.dart';
import '../core/errors/auth_failure.dart';
import '../core/utils/auth_exception_mapper.dart';
import '../models/notification_model.dart';
import '../models/support_message_model.dart';

class NotificationRepository {
  NotificationRepository({
    FirebaseFirestore? firestore,
    FirebaseAuth? firebaseAuth,
  }) : _firestore = firestore ?? FirebaseFirestore.instance,
       _firebaseAuth = firebaseAuth ?? FirebaseAuth.instance;

  final FirebaseFirestore _firestore;
  final FirebaseAuth _firebaseAuth;

  Stream<List<NotificationModel>> watchForUser(String recipientId) => _firestore
      .collection('notifications')
      .where('recipientId', isEqualTo: recipientId)
      .snapshots()
      .map((snapshot) {
        final notifications =
            snapshot.docs.map(NotificationModel.fromFirestore).toList()
              ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
        return notifications;
      });

  Future<void> create(NotificationModel notification) async {
    try {
      await _firestore
          .collection('notifications')
          .doc(notification.id.isEmpty ? null : notification.id)
          .set(notification.toFirestore());
    } on FirebaseException catch (error) {
      throw AuthFailure(AuthExceptionMapper.fromFirestore(error));
    }
  }

  Future<int> sendMessageToAdmins({
    required String senderRole,
    required String senderId,
    required String senderName,
    required String message,
  }) async {
    final trimmedMessage = message.trim();
    if (trimmedMessage.isEmpty) {
      throw AuthFailure('Please write a message before sending.');
    }

    var operation = 'load_sender_profile';
    var authenticatedRole = 'unknown';
    var receiverId = 'unresolved';
    var conversationId = 'unresolved';
    try {
      final authUser = _firebaseAuth.currentUser;
      if (authUser == null || authUser.uid != senderId) {
        throw const AuthFailure(
          'Your signed-in account could not be verified. Please sign in again.',
        );
      }
      final userSnapshot = await _firestore
          .collection('users')
          .doc(authUser.uid)
          .get();
      final userData = userSnapshot.data();
      final normalizedRole = (userData?['role'] as String? ?? '')
          .trim()
          .toLowerCase();
      authenticatedRole = normalizedRole;
      if (normalizedRole != 'owner' && normalizedRole != 'customer') {
        throw const AuthFailure(
          'Only owners and customers can send messages to BUSGO admin.',
        );
      }
      if (senderRole.trim().toLowerCase() != normalizedRole) {
        throw const AuthFailure(
          'Your account role changed. Please reload and try again.',
        );
      }

      operation = 'find_admin_recipients';
      final admins = await _firestore
          .collection('users')
          .where('role', isEqualTo: 'admin')
          .get();
      if (admins.docs.isEmpty) {
        throw const AuthFailure('No admin account is available right now.');
      }

      conversationId = authUser.uid;
      receiverId = admins.docs.first.id;
      operation = 'ensure_support_conversation';
      final conversation = _firestore
          .collection('support_conversations')
          .doc(authUser.uid);
      await _firestore.runTransaction((transaction) async {
        final existing = await transaction.get(conversation);
        if (existing.exists) {
          final existingData = existing.data() ?? <String, dynamic>{};
          if (existingData['participantId'] != authUser.uid ||
              existingData['participantRole'] != normalizedRole) {
            throw const AuthFailure(
              'The support conversation could not be verified.',
            );
          }
          return;
        }
        transaction.set(conversation, {
          'participantId': authUser.uid,
          'participantRole': normalizedRole,
          'participantName': userData?['name'] as String? ?? senderName.trim(),
          'createdAt': FieldValue.serverTimestamp(),
        });
      });

      operation = 'commit_support_message_and_notifications';
      final batch = _firestore.batch();
      final messageReference = conversation.collection('messages').doc();
      batch.set(messageReference, {
        'conversationId': conversationId,
        'senderId': authUser.uid,
        'senderRole': normalizedRole,
        'senderName': userData?['name'] as String? ?? senderName.trim(),
        'receiverId': receiverId,
        'receiverRole': 'admin',
        'message': trimmedMessage,
        'isRead': false,
        'createdAt': FieldValue.serverTimestamp(),
      });
      for (final admin in admins.docs) {
        final reference = _firestore.collection('notifications').doc();
        final notification = NotificationModel(
          id: reference.id,
          recipientId: admin.id,
          type: normalizedRole == 'owner'
              ? 'owner_message'
              : 'customer_message',
          title: normalizedRole == 'owner'
              ? 'Message from bus owner'
              : 'Message from customer',
          message: trimmedMessage,
          conversationId: conversationId,
          senderId: authUser.uid,
          relatedOwnerId: normalizedRole == 'owner' ? authUser.uid : null,
          relatedOwnerName: normalizedRole == 'owner'
              ? (userData?['name'] as String? ?? senderName.trim())
              : null,
          relatedCustomerId: normalizedRole == 'customer' ? authUser.uid : null,
          relatedCustomerName: normalizedRole == 'customer'
              ? (userData?['name'] as String? ?? senderName.trim())
              : null,
          isRead: false,
          createdAt: DateTime.now(),
        );
        batch.set(reference, notification.toFirestore());
      }
      await batch.commit();
      return admins.docs.length;
    } on FirebaseException catch (error) {
      debugPrint(
        '[BUSGO MESSAGE DEBUG] authenticatedUid=${_firebaseAuth.currentUser?.uid ?? 'none'} authenticatedRole=$authenticatedRole senderRole=$senderRole receiverRole=admin receiverId=$receiverId conversationId=$conversationId collection=support_conversations operation=$operation errorCode=${error.code} errorMessage=${error.message}',
      );
      throw AuthFailure(AuthExceptionMapper.fromFirestore(error));
    }
  }

  Stream<List<SupportMessageModel>> watchSupportMessages(
    String conversationId,
  ) => _firestore
      .collection('support_conversations')
      .doc(conversationId)
      .collection('messages')
      .orderBy('createdAt')
      .snapshots()
      .map(
        (snapshot) =>
            snapshot.docs.map(SupportMessageModel.fromFirestore).toList(),
      );

  Stream<List<SupportConversationModel>> watchSupportConversations() => _firestore
      .collection('support_conversations')
      .snapshots()
      .map((snapshot) {
        final conversations = snapshot.docs
            .map(SupportConversationModel.fromFirestore)
            .toList();
        conversations.sort((left, right) => right.createdAt.compareTo(left.createdAt));
        return conversations;
      });

  Future<void> sendAdminReply({
    required String conversationId,
    required String message,
  }) async {
    final trimmedMessage = message.trim();
    if (trimmedMessage.isEmpty) {
      throw const AuthFailure('Please write a message before sending.');
    }
    final authUser = _firebaseAuth.currentUser;
    if (authUser == null) {
      throw const AuthFailure('Please sign in again to reply.');
    }

    try {
      final adminSnapshot = await _firestore
          .collection('users')
          .doc(authUser.uid)
          .get();
      if ((adminSnapshot.data()?['role'] as String? ?? '').toLowerCase() !=
          AppUserRole.admin.value) {
        throw const AuthFailure('Only BUSGO admins can reply to support.');
      }
      final conversation = _firestore
          .collection('support_conversations')
          .doc(conversationId);
      final conversationSnapshot = await conversation.get();
      final conversationData = conversationSnapshot.data();
      if (!conversationSnapshot.exists ||
          conversationData?['participantId'] != conversationId ||
          !{
            'customer',
            'owner',
          }.contains(conversationData?['participantRole'])) {
        throw const AuthFailure('This support conversation is unavailable.');
      }

      final batch = _firestore.batch();
      final messageReference = conversation.collection('messages').doc();
      batch.set(messageReference, {
        'conversationId': conversationId,
        'senderId': authUser.uid,
        'senderRole': 'admin',
        'senderName': adminSnapshot.data()?['name'] as String? ?? 'BUSGO Admin',
        'receiverId': conversationId,
        'receiverRole': conversationData!['participantRole'],
        'message': trimmedMessage,
        'isRead': false,
        'createdAt': FieldValue.serverTimestamp(),
      });
      final notificationReference = _firestore
          .collection('notifications')
          .doc();
      batch.set(
        notificationReference,
        NotificationModel(
          id: notificationReference.id,
          recipientId: conversationId,
          type: 'support_reply',
          title: 'BUSGO Admin replied to your message',
          message: trimmedMessage,
          conversationId: conversationId,
          senderId: authUser.uid,
          relatedOwnerId: conversationData['participantRole'] == 'owner'
              ? conversationId
              : null,
          relatedCustomerId: conversationData['participantRole'] == 'customer'
              ? conversationId
              : null,
          isRead: false,
          createdAt: DateTime.now(),
        ).toFirestore(),
      );
      await batch.commit();
    } on FirebaseException catch (error) {
      debugPrint(
        '[BUSGO MESSAGE DEBUG] authenticatedUid=${authUser.uid} senderRole=admin receiverId=$conversationId conversationId=$conversationId collection=support_conversations operation=reply errorCode=${error.code} errorMessage=${error.message}',
      );
      throw AuthFailure(AuthExceptionMapper.fromFirestore(error));
    }
  }

  Future<void> markSupportMessagesRead(String conversationId) async {
    final authUser = _firebaseAuth.currentUser;
    if (authUser == null) {
      throw const AuthFailure('Please sign in again to view support messages.');
    }
    final roleSnapshot = await _firestore
        .collection('users')
        .doc(authUser.uid)
        .get();
    final role = (roleSnapshot.data()?['role'] as String? ?? '')
        .trim()
        .toLowerCase();
    if (role != 'admin' && authUser.uid != conversationId) {
      throw const AuthFailure('You cannot access this support conversation.');
    }

    final snapshot = await _firestore
        .collection('support_conversations')
        .doc(conversationId)
        .collection('messages')
        .where('isRead', isEqualTo: false)
        .get();
    final unreadMessages = snapshot.docs
        .where((document) => document.data()['senderId'] != authUser.uid)
        .toList();
    for (var start = 0; start < unreadMessages.length; start += 400) {
      final batch = _firestore.batch();
      final end = start + 400 < unreadMessages.length
          ? start + 400
          : unreadMessages.length;
      for (final message in unreadMessages.sublist(start, end)) {
        batch.update(message.reference, {'isRead': true});
      }
      await batch.commit();
    }
  }

  Future<int> sendOwnerMessageToAdmins({
    required String ownerId,
    required String ownerName,
    required String message,
  }) async {
    return sendMessageToAdmins(
      senderRole: 'owner',
      senderId: ownerId,
      senderName: ownerName,
      message: message,
    );
  }

  Future<void> markAsRead(String notificationId) async {
    try {
      await _firestore.collection('notifications').doc(notificationId).update({
        'isRead': true,
      });
    } on FirebaseException catch (error) {
      throw AuthFailure(AuthExceptionMapper.fromFirestore(error));
    }
  }

  Future<void> markAllAsRead(String recipientId) async {
    try {
      final snapshot = await _firestore
          .collection('notifications')
          .where('recipientId', isEqualTo: recipientId)
          .where('isRead', isEqualTo: false)
          .get();
      if (snapshot.docs.isEmpty) return;
      final batch = _firestore.batch();
      for (final document in snapshot.docs) {
        batch.update(document.reference, {'isRead': true});
      }
      await batch.commit();
    } on FirebaseException catch (error) {
      throw AuthFailure(AuthExceptionMapper.fromFirestore(error));
    }
  }
}
