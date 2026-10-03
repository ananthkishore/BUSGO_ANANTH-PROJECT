import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

import '../core/constants/app_roles.dart';
import '../core/errors/auth_failure.dart';
import '../core/utils/auth_exception_mapper.dart';
import '../models/user_model.dart';

class AuthRepository {
  AuthRepository({FirebaseAuth? firebaseAuth, FirebaseFirestore? firestore})
    : _firebaseAuth = firebaseAuth ?? FirebaseAuth.instance,
      _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseAuth _firebaseAuth;
  final FirebaseFirestore _firestore;

  User? get currentUser => _firebaseAuth.currentUser;

  Stream<User?> get authStateChanges => _firebaseAuth.authStateChanges();

  Future<AppUser?> getCurrentUserProfile() async {
    final user = _firebaseAuth.currentUser;
    if (user == null) return null;

    try {
      debugPrint(
        '[AUTH] Loading Firestore profile for current UID: ${user.uid}',
      );
      final snapshot = await _firestore.collection('users').doc(user.uid).get();
      if (!snapshot.exists) {
        debugPrint('[AUTH] Profile exists = false for UID: ${user.uid}');
        return null;
      }
      final profile = AppUser.fromFirestore(snapshot);
      debugPrint(
        '[AUTH] Profile exists = true for UID: ${user.uid}; role = ${profile.role.name}',
      );
      return profile;
    } on FirebaseException catch (e) {
      debugPrint(
        '[AUTH ERROR] Firestore profile load failed: ${e.code} ${e.message}',
      );
      throw AuthFailure(AuthExceptionMapper.fromFirestore(e));
    }
  }

  Future<void> signInWithEmailPassword({
    required String email,
    required String password,
  }) async {
    try {
      debugPrint('[AUTH] Firebase sign-in started');
      await _firebaseAuth.signInWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );
      final uid = _firebaseAuth.currentUser?.uid;
      debugPrint('[AUTH] Firebase sign-in successful');
      debugPrint('[AUTH] UID = ${uid ?? 'unknown'}');
    } on FirebaseAuthException catch (e) {
      debugPrint('[AUTH ERROR] FirebaseException code = ${e.code}');
      debugPrint('[AUTH ERROR] FirebaseException message = ${e.message}');
      throw AuthFailure(AuthExceptionMapper.fromFirebaseAuth(e));
    } on FirebaseException catch (e) {
      debugPrint('[AUTH ERROR] FirestoreException code = ${e.code}');
      debugPrint('[AUTH ERROR] FirestoreException message = ${e.message}');
      throw AuthFailure(AuthExceptionMapper.fromFirestore(e));
    }
  }

  Future<void> registerCustomer({
    required String name,
    required String email,
    required String phone,
    required String password,
    AppUserRole role = AppUserRole.customer,
  }) async {
    try {
      final credential = await _firebaseAuth.createUserWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );

      final uid = credential.user?.uid;
      if (uid == null) {
        throw const AuthFailure('User registration failed. Please try again.');
      }

      try {
        final now = DateTime.now();
        final userModel = AppUser(
          uid: uid,
          name: name.trim(),
          email: email.trim(),
          phone: phone.trim(),
          role: role,
          approvalStatus: role == AppUserRole.owner ? 'pending' : null,
          createdAt: now,
          updatedAt: now,
        );

        await _firestore
            .collection('users')
            .doc(uid)
            .set(userModel.toFirestore());
      } on FirebaseException {
        final user = _firebaseAuth.currentUser;
        if (user != null && user.uid == uid) {
          try {
            await user.delete();
          } catch (_) {}
        }
        throw AuthFailure(
          'Account created, but your profile could not be saved. Please try again.',
        );
      }
    } on FirebaseAuthException catch (e) {
      throw AuthFailure(AuthExceptionMapper.fromFirebaseAuth(e));
    } on FirebaseException catch (e) {
      throw AuthFailure(AuthExceptionMapper.fromFirestore(e));
    }
  }

  Future<void> sendPasswordResetEmail({required String email}) async {
    try {
      await _firebaseAuth.sendPasswordResetEmail(email: email.trim());
    } on FirebaseAuthException catch (e) {
      throw AuthFailure(AuthExceptionMapper.fromFirebaseAuth(e));
    } on FirebaseException catch (e) {
      throw AuthFailure(AuthExceptionMapper.fromFirestore(e));
    }
  }

  Future<void> signOut() async {
    await _firebaseAuth.signOut();
  }
}
