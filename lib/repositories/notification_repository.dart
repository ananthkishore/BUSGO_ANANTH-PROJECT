import 'package:cloud_firestore/cloud_firestore.dart';

import '../core/errors/auth_failure.dart';
import '../core/utils/auth_exception_mapper.dart';
import '../models/notification_model.dart';

class NotificationRepository {
  NotificationRepository({FirebaseFirestore? firestore})
    : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

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

  Future<int> sendOwnerMessageToAdmins({
    required String ownerId,
    required String ownerName,
    required String message,
  }) async {
    try {
      final admins = await _firestore
          .collection('users')
          .where('role', isEqualTo: 'admin')
          .get();
      if (admins.docs.isEmpty) return 0;

      final batch = _firestore.batch();
      for (final admin in admins.docs) {
        final reference = _firestore.collection('notifications').doc();
        batch.set(
          reference,
          NotificationModel(
            id: reference.id,
            recipientId: admin.id,
            type: 'owner_message',
            title: 'Message from bus owner',
            message: message.trim(),
            relatedOwnerId: ownerId,
            relatedOwnerName: ownerName.trim(),
            isRead: false,
            createdAt: DateTime.now(),
          ).toFirestore(),
        );
      }
      await batch.commit();
      return admins.docs.length;
    } on FirebaseException catch (error) {
      throw AuthFailure(AuthExceptionMapper.fromFirestore(error));
    }
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
