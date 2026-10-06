import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

import '../core/constants/app_roles.dart';
import '../core/errors/auth_failure.dart';
import '../core/utils/auth_exception_mapper.dart';
import '../core/utils/profile_image_storage.dart';
import '../models/user_model.dart';
import '../repositories/auth_repository.dart';
import '../repositories/user_repository.dart';

class AuthProvider extends ChangeNotifier {
  AuthProvider({AuthRepository? authRepository, UserRepository? userRepository})
    : _authRepository = authRepository ?? AuthRepository(),
      _userRepository = userRepository ?? UserRepository() {
    _subscribeToAuthChanges();
  }

  final AuthRepository _authRepository;
  final UserRepository _userRepository;

  bool _isLoading = true;
  bool _isBusy = false;
  AppUser? _currentUser;
  String? _errorMessage;
  StreamSubscription<User?>? _authSubscription;

  bool get isLoading => _isLoading;
  bool get isBusy => _isBusy;
  AppUser? get currentUser => _currentUser;
  String? get authenticatedUid => _authRepository.currentUser?.uid;
  bool get isAuthenticated =>
      _authRepository.currentUser != null && _currentUser != null;
  String? get errorMessage => _errorMessage;

  Future<AppUser?> _loadProfileForUid(
    String uid, {
    AppUserRole? expectedRole,
  }) async {
    debugPrint(
      '[AUTH] Loading Firestore profile for UID: $uid expectedRole=${expectedRole?.name ?? 'none'}',
    );
    try {
      final profile = await _userRepository
          .getUserByUid(uid)
          .timeout(
            const Duration(seconds: 12),
            onTimeout: () {
              throw const AuthFailure(
                'Unable to load your account. Please check your internet connection and try again.',
              );
            },
          );

      if (profile == null) {
        debugPrint('[AUTH] Profile exists = false for UID: $uid');
        if (expectedRole == null) {
          throw const AuthFailure('Your profile was not found.');
        }
        throw AuthFailure('${expectedRole.label} profile was not found.');
      }

      debugPrint('[AUTH] Profile exists = true; role = ${profile.role.name}');

      if (expectedRole != null && profile.role != expectedRole) {
        throw AuthFailure(
          'This account is registered as a ${profile.role.label}. Please select ${profile.role.label}.',
        );
      }

      return profile;
    } catch (error) {
      debugPrint('[AUTH ERROR] Profile load failed: $error');
      rethrow;
    }
  }

  void _subscribeToAuthChanges() {
    _authSubscription = _authRepository.authStateChanges.listen((user) async {
      if (_isBusy) {
        debugPrint(
          '[AUTH] Ignoring auth-state change while login is in progress',
        );
        return;
      }

      debugPrint('[AUTH] Auth state changed. User present = ${user != null}');

      if (user == null) {
        _currentUser = null;
        _isLoading = false;
        _errorMessage = null;
        notifyListeners();
        return;
      }

      final activeUid = _authRepository.currentUser?.uid;
      if (activeUid != null && activeUid != user.uid) {
        debugPrint(
          '[AUTH] Ignoring stale auth event for ${user.uid}; active user is $activeUid',
        );
        return;
      }

      try {
        _isLoading = true;
        _errorMessage = null;
        notifyListeners();

        debugPrint(
          '[AUTH] Restoring session for UID: ${user.uid}; email=${user.email ?? 'unknown'}',
        );
        final profile = await _loadProfileForUid(user.uid);
        _currentUser = profile;
        debugPrint(
          '[AUTH] Session restored for UID: ${user.uid} role=${profile?.role.name ?? 'none'}',
        );
      } catch (error) {
        _currentUser = null;
        _errorMessage = error is AuthFailure
            ? error.message
            : 'Unable to load your account. Please check your internet connection and try again.';
        debugPrint('[AUTH ERROR] $_errorMessage');
        await _authRepository.signOut();
      } finally {
        _isLoading = false;
        notifyListeners();
      }
    });
  }

  Future<void> signInWithEmailPassword({
    required String email,
    required String password,
    AppUserRole? expectedRole,
  }) async {
    if (_isBusy) return;

    _isBusy = true;
    _isLoading = true;
    _currentUser = null;
    _errorMessage = null;
    debugPrint('[AUTH] Login started');
    notifyListeners();

    try {
      debugPrint('[AUTH] Firebase sign-in started');
      await _authRepository.signInWithEmailPassword(
        email: email,
        password: password,
      );

      final user = _authRepository.currentUser;
      debugPrint('[AUTH] Firebase sign-in successful');
      debugPrint('[AUTH] UID = ${user?.uid ?? 'unknown'}');

      if (user == null) {
        throw const AuthFailure('Unable to sign in. Please try again.');
      }

      final profile = await _loadProfileForUid(
        user.uid,
        expectedRole: expectedRole,
      );
      if (profile == null) {
        await _authRepository.signOut();
        throw AuthFailure(
          expectedRole == null
              ? 'Your profile was not found.'
              : '${expectedRole.label} profile was not found.',
        );
      }

      debugPrint('[AUTH] Firestore role = ${profile.role.name}');
      debugPrint(
        '[AUTH] Selected role = ${expectedRole?.name ?? 'none'}; resolved role = ${profile.role.name}',
      );

      if (expectedRole != null && profile.role != expectedRole) {
        await _authRepository.signOut();
        throw AuthFailure(
          'This account is registered as a ${profile.role.label}. Please select ${profile.role.label}.',
        );
      }

      _currentUser = profile;
      debugPrint(
        '[AUTH] Login completed for UID: ${user.uid} role=${profile.role.name}',
      );
      final targetRoute = profile.role == AppUserRole.admin
          ? '/admin'
          : profile.role == AppUserRole.owner
          ? '/owner'
          : '/customer';
      debugPrint('[ROUTER] Navigating to $targetRoute');
    } on FirebaseAuthException catch (error) {
      final message = AuthExceptionMapper.fromFirebaseAuth(error);
      _errorMessage = message;
      debugPrint('[AUTH ERROR] FirebaseException code = ${error.code}');
      debugPrint('[AUTH ERROR] FirebaseException message = ${error.message}');
      rethrow;
    } on FirebaseException catch (error) {
      final message = AuthExceptionMapper.fromFirestore(error);
      _errorMessage = message;
      debugPrint('[AUTH ERROR] FirestoreException code = ${error.code}');
      debugPrint('[AUTH ERROR] FirestoreException message = ${error.message}');
      rethrow;
    } on AuthFailure catch (error) {
      _errorMessage = error.message;
      debugPrint('[AUTH ERROR] ${error.message}');
      rethrow;
    } catch (error) {
      _errorMessage = 'Unable to sign in. Please try again.';
      debugPrint('[AUTH ERROR] ${error.toString()}');
      rethrow;
    } finally {
      _isLoading = false;
      _isBusy = false;
      notifyListeners();
    }
  }

  Future<void> updateProfile({
    required String name,
    String? phone,
    String? profileImageUrl,
  }) async {
    final currentUser = _currentUser;
    if (currentUser == null) {
      throw const AuthFailure('Your profile is not available right now.');
    }
    if (_authRepository.currentUser?.uid != currentUser.uid) {
      throw const AuthFailure(
        'Your signed-in account changed. Please sign in again.',
      );
    }

    final sanitizedPhone = (phone ?? '').trim();
    final nextProfileImageUrl = profileImageUrl == null
        ? currentUser.profileImageUrl
        : sanitizeProfileImageUrl(profileImageUrl);
    if (profileImageUrl != null && nextProfileImageUrl == null) {
      throw const AuthFailure('The selected profile image URL is invalid.');
    }
    final nextUser = AppUser(
      uid: currentUser.uid,
      name: name.trim(),
      email: currentUser.email,
      phone: sanitizedPhone.isEmpty ? null : sanitizedPhone,
      role: currentUser.role,
      approvalStatus: currentUser.approvalStatus,
      profileImageUrl: nextProfileImageUrl,
      createdAt: currentUser.createdAt,
      updatedAt: DateTime.now(),
    );

    await _userRepository.updateUserProfile(
      uid: currentUser.uid,
      name: nextUser.name,
      email: nextUser.email,
      phone: nextUser.phone,
      profileImageUrl: nextUser.profileImageUrl,
    );

    final persistedUser = await _userRepository.getUserByUid(currentUser.uid);
    if (persistedUser == null ||
        persistedUser.profileImageUrl != nextUser.profileImageUrl) {
      throw const AuthFailure(
        'Your profile update could not be confirmed. Please retry.',
      );
    }

    _currentUser = persistedUser;
    debugPrint(
      '[PROFILE IMAGE] Firestore profile reloaded and provider synchronized',
    );
    notifyListeners();
  }

  Future<void> changePassword({
    required String currentPassword,
    required String newPassword,
  }) async {
    final user = _authRepository.currentUser;
    if (user == null || user.email == null) {
      throw const AuthFailure(
        'Please sign in again before changing your password.',
      );
    }

    final credential = EmailAuthProvider.credential(
      email: user.email!,
      password: currentPassword,
    );

    try {
      await user.reauthenticateWithCredential(credential);
      await user.updatePassword(newPassword);
    } on FirebaseAuthException catch (error) {
      throw AuthFailure(AuthExceptionMapper.fromFirebaseAuth(error));
    } catch (error) {
      throw AuthFailure(
        error is AuthFailure
            ? error.message
            : 'Unable to change your password right now.',
      );
    }
  }

  Future<void> registerCustomer({
    required String name,
    required String email,
    required String phone,
    required String password,
    AppUserRole role = AppUserRole.customer,
  }) async {
    if (_isBusy) return;

    if (role == AppUserRole.admin) {
      throw const AuthFailure(
        'Admin signup requires an authorized invitation. Contact a BUSGO administrator.',
      );
    }

    _isBusy = true;
    _errorMessage = null;
    notifyListeners();

    try {
      await _authRepository.registerCustomer(
        name: name,
        email: email,
        phone: phone,
        password: password,
        role: role,
      );

      final user = _authRepository.currentUser;
      if (user == null) {
        throw const AuthFailure(
          'Registration was incomplete. Please try again.',
        );
      }

      final profile = await _userRepository.getUserByUid(user.uid);
      if (profile == null) {
        throw const AuthFailure('Your account could not be confirmed.');
      }
      _currentUser = profile;
    } on AuthFailure catch (error) {
      _errorMessage = error.message;
      rethrow;
    } catch (error) {
      _errorMessage = 'Registration failed. Please try again.';
      rethrow;
    } finally {
      _isBusy = false;
      notifyListeners();
    }
  }

  Future<void> resetPassword({required String email}) async {
    if (_isBusy) return;

    _isBusy = true;
    _errorMessage = null;
    notifyListeners();

    try {
      await _authRepository.sendPasswordResetEmail(email: email);
    } on AuthFailure catch (error) {
      _errorMessage = error.message;
      rethrow;
    } finally {
      _isBusy = false;
      notifyListeners();
    }
  }

  Future<void> signOut() async {
    if (_isBusy) return;

    _isBusy = true;
    notifyListeners();

    try {
      await _authRepository.signOut();
      _currentUser = null;
      _errorMessage = null;
    } finally {
      _isBusy = false;
      notifyListeners();
    }
  }

  void clearError() {
    _errorMessage = null;
    notifyListeners();
  }

  AppUserRole get role => _currentUser?.role ?? AppUserRole.customer;

  @override
  void dispose() {
    _authSubscription?.cancel();
    super.dispose();
  }
}
