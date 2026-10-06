import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

import '../core/errors/auth_failure.dart';
import '../core/utils/auth_exception_mapper.dart';
import '../core/utils/profile_image_storage.dart';
import '../models/user_model.dart';
import 'notification_repository.dart';
import '../models/notification_model.dart';

class UserRepository {
  UserRepository({FirebaseFirestore? firestore})
    : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  Stream<List<AppUser>> watchAll() => _firestore
      .collection('users')
      .snapshots()
      .map((snapshot) => snapshot.docs.map(AppUser.fromFirestore).toList());

  Stream<List<AppUser>> watchOwners() {
    debugPrint('[OwnerApprovals] Starting users query: role == owner');
    return _firestore
        .collection('users')
        .where('role', isEqualTo: 'owner')
        .snapshots()
        .map((snapshot) {
          final owners = snapshot.docs.map(AppUser.fromFirestore).toList();
          debugPrint(
            '[OwnerApprovals] Query completed: ${owners.length} owners',
          );
          return owners;
        })
        .handleError((Object error, StackTrace stackTrace) {
          debugPrint('[OwnerApprovals] Query failed: $error');
          debugPrintStack(stackTrace: stackTrace);
        });
  }

  Future<void> updateOwnerApproval({
    required String uid,
    required String status,
  }) async {
    try {
      await _firestore.collection('users').doc(uid).update({
        'approvalStatus': status,
        'updatedAt': FieldValue.serverTimestamp(),
      });
      await NotificationRepository(firestore: _firestore).create(
        NotificationModel(
          id: '${uid}_owner_approval_$status',
          recipientId: uid,
          type: 'owner_approval_$status',
          title: status == 'approved'
              ? 'Owner application approved'
              : 'Owner application rejected',
          message: status == 'approved'
              ? 'Your BUSGO owner application has been approved.'
              : 'Your BUSGO owner application was rejected. Please contact BUSGO support for details.',
          isRead: false,
          createdAt: DateTime.now(),
        ),
      );
    } on FirebaseException catch (e) {
      throw AuthFailure(AuthExceptionMapper.fromFirestore(e));
    }
  }

  Future<AppUser?> getUserByUid(String uid) async {
    try {
      final snapshot = await _firestore.collection('users').doc(uid).get();
      if (!snapshot.exists) {
        return null;
      }
      return AppUser.fromFirestore(snapshot);
    } on FirebaseException catch (e) {
      throw AuthFailure(AuthExceptionMapper.fromFirestore(e));
    }
  }

  Future<void> updateUserProfile({
    required String uid,
    required String name,
    required String email,
    String? phone,
    String? profileImageUrl,
  }) async {
    try {
      final normalizedImageUrl = sanitizeProfileImageUrl(profileImageUrl);
      final data = {
        'name': name.trim(),
        'email': email.trim(),
        'phone': phone,
        'profileImageUrl': normalizedImageUrl,
        'profileImage': normalizedImageUrl,
        'updatedAt': FieldValue.serverTimestamp(),
      };

      await _firestore
          .collection('users')
          .doc(uid)
          .set(data, SetOptions(merge: true));
    } on FirebaseException catch (e) {
      throw AuthFailure(AuthExceptionMapper.fromFirestore(e));
    }
  }

  Future<void> setUserRole({required String uid, required String role}) async {
    try {
      await _firestore.collection('users').doc(uid).update({
        'role': role,
        'updatedAt': FieldValue.serverTimestamp(),
      });
    } on FirebaseException catch (e) {
      throw AuthFailure(AuthExceptionMapper.fromFirestore(e));
    }
  }
}
