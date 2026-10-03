import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

import '../core/errors/auth_failure.dart';
import '../core/utils/auth_exception_mapper.dart';
import '../models/bus_model.dart';
import '../models/notification_model.dart';
import 'notification_repository.dart';

class BusRepository {
  BusRepository({
    FirebaseFirestore? firestore,
    FirebaseAuth? firebaseAuth,
    NotificationRepository? notificationRepository,
  }) : _firestore = firestore ?? FirebaseFirestore.instance,
       _firebaseAuth = firebaseAuth ?? FirebaseAuth.instance,
       _notificationRepository =
           notificationRepository ??
           NotificationRepository(firestore: firestore);

  final FirebaseFirestore _firestore;
  final FirebaseAuth _firebaseAuth;
  final NotificationRepository _notificationRepository;

  Stream<List<BusModel>> watchAvailableBuses({
    String? serviceLocation,
    int? minimumCapacity,
  }) {
    Query<Map<String, dynamic>> query = _firestore
        .collection('buses')
        .where('status', isEqualTo: 'approved');
    return query.snapshots().map((snapshot) {
      final buses = snapshot.docs.map(BusModel.fromFirestore).toList();
      return _filterBuses(
        buses,
        serviceLocation: serviceLocation,
        minimumCapacity: minimumCapacity,
      );
    });
  }

  Future<List<BusModel>> findAvailableBuses({
    String? serviceLocation,
    String? destination,
    int? minimumCapacity,
    required DateTime startDate,
    required DateTime endDate,
  }) async {
    try {
      Query<Map<String, dynamic>> query = _firestore
          .collection('buses')
          .where('status', isEqualTo: 'approved');
      final buses = (await query.get()).docs.map((document) {
        debugPrint(
          'Customer search bus: id=${document.id}, data=${document.data()}',
        );
        return BusModel.fromFirestore(document);
      }).toList();
      debugPrint('Customer search approved bus count: ${buses.length}');
      return _filterBuses(
        buses,
        serviceLocation: serviceLocation,
        destination: destination,
        minimumCapacity: minimumCapacity,
      );
    } on FirebaseException catch (error) {
      throw AuthFailure(AuthExceptionMapper.fromFirestore(error));
    }
  }

  Future<void> saveBus(BusModel bus) async {
    try {
      await _firestore.collection('buses').doc(bus.id).set(bus.toFirestore());
    } on FirebaseException catch (error) {
      throw AuthFailure(AuthExceptionMapper.fromFirestore(error));
    }
  }

  Future<void> updateOwnerBus(BusModel bus) async {
    try {
      final user = _firebaseAuth.currentUser;
      if (user == null || user.uid != bus.ownerId) {
        throw const AuthFailure('You can only update your own bus.');
      }
      final reference = _firestore.collection('buses').doc(bus.id);
      final snapshot = await reference.get();
      if (!snapshot.exists) {
        throw const AuthFailure('This bus no longer exists.');
      }
      final existing = BusModel.fromFirestore(snapshot);
      if (existing.ownerId != user.uid) {
        throw const AuthFailure('You can only update your own bus.');
      }
      final data = bus.toFirestore()
        ..['ownerId'] = existing.ownerId
        ..['status'] = existing.status
        ..['createdAt'] = existing.createdAt == null
            ? FieldValue.serverTimestamp()
            : Timestamp.fromDate(existing.createdAt!);
      await reference.update(data);
    } on FirebaseException catch (error) {
      throw AuthFailure(AuthExceptionMapper.fromFirestore(error));
    }
  }

  Future<void> deleteOwnerBus({required String busId}) async {
    final user = _firebaseAuth.currentUser;
    if (user == null) {
      throw const AuthFailure('Please login as a bus owner.');
    }
    final normalizedBusId = busId.trim();
    if (normalizedBusId.isEmpty) {
      throw const AuthFailure('Bus details not found.');
    }

    try {
      final ownerSnapshot = await _firestore
          .collection('users')
          .doc(user.uid)
          .get();
      if (!ownerSnapshot.exists || ownerSnapshot.data()?['role'] != 'owner') {
        throw const AuthFailure('Please login as a bus owner.');
      }
      final admins = await _firestore
          .collection('users')
          .where('role', isEqualTo: 'admin')
          .get();
      if (admins.docs.isEmpty) {
        throw const AuthFailure(
          'Unable to notify Admin. The bus was not deleted.',
        );
      }

      final ownerName = (ownerSnapshot.data()?['name'] as String?)?.trim();
      final displayOwnerName = ownerName == null || ownerName.isEmpty
          ? 'Bus owner'
          : ownerName;
      final deletedAt = DateTime.now();
      final busReference = _firestore.collection('buses').doc(normalizedBusId);
      late BusModel bus;
      await _firestore.runTransaction((transaction) async {
        final busSnapshot = await transaction.get(busReference);
        if (!busSnapshot.exists) {
          throw const AuthFailure('Bus has already been deleted.');
        }
        bus = BusModel.fromFirestore(busSnapshot);
        if (bus.ownerId != user.uid) {
          throw const AuthFailure('You can only delete your own bus.');
        }

        for (final admin in admins.docs) {
          final notification = NotificationModel(
            id: '${bus.id}_deleted_${admin.id}',
            recipientId: admin.id,
            type: 'bus_deleted_by_owner',
            title: 'Bus deleted by owner',
            message: '${bus.name} was deleted by $displayOwnerName.',
            relatedBusId: bus.id,
            relatedOwnerId: user.uid,
            relatedBusName: bus.name,
            relatedRegistrationNumber: bus.registrationNumber,
            relatedOwnerName: displayOwnerName,
            deletedAt: deletedAt,
            isRead: false,
            createdAt: deletedAt,
          );
          transaction.set(
            _firestore.collection('notifications').doc(notification.id),
            notification.toFirestore(),
          );
        }
        transaction.delete(busReference);
      });
      debugPrint('[BUSGO BUS DELETE RESULT]');
      debugPrint('busId: ${bus.id}');
      debugPrint('ownerUid: ${user.uid}');
      debugPrint('deletedOrArchived: deleted');
      debugPrint('success: true');
      debugPrint('notificationSent: true');
      debugPrint('errorCode: none');
      debugPrint('errorMessage: none');
      debugPrint('[/BUSGO BUS DELETE RESULT]');
    } on AuthFailure catch (error) {
      debugPrint('[BUSGO BUS DELETE RESULT]');
      debugPrint('busId: $normalizedBusId');
      debugPrint('ownerUid: ${user.uid}');
      debugPrint('deletedOrArchived: none');
      debugPrint('success: false');
      debugPrint('notificationSent: false');
      debugPrint('errorCode: AuthFailure');
      debugPrint('errorMessage: ${error.message}');
      debugPrint('[/BUSGO BUS DELETE RESULT]');
      rethrow;
    } on FirebaseException catch (error) {
      debugPrint('[BUSGO BUS DELETE RESULT]');
      debugPrint('busId: $normalizedBusId');
      debugPrint('ownerUid: ${user.uid}');
      debugPrint('deletedOrArchived: none');
      debugPrint('success: false');
      debugPrint('notificationSent: false');
      debugPrint('errorCode: ${error.code}');
      debugPrint('errorMessage: ${error.message ?? error.code}');
      debugPrint('[/BUSGO BUS DELETE RESULT]');
      throw AuthFailure(AuthExceptionMapper.fromFirestore(error));
    } catch (error) {
      debugPrint('[BUSGO BUS DELETE RESULT]');
      debugPrint('busId: $normalizedBusId');
      debugPrint('ownerUid: ${user.uid}');
      debugPrint('deletedOrArchived: none');
      debugPrint('success: false');
      debugPrint('notificationSent: false');
      debugPrint('errorCode: ${error.runtimeType}');
      debugPrint('errorMessage: $error');
      debugPrint('[/BUSGO BUS DELETE RESULT]');
      throw const AuthFailure('Unable to delete this bus. Please try again.');
    }
  }

  Future<void> submitOwnerBusUpdate(BusModel bus) async {
    try {
      final user = _firebaseAuth.currentUser;
      if (user == null || user.uid != bus.ownerId) {
        throw const AuthFailure('You can only update your own bus.');
      }
      final reference = _firestore.collection('buses').doc(bus.id);
      final snapshot = await reference.get();
      if (!snapshot.exists) {
        throw const AuthFailure('This bus no longer exists.');
      }
      final existing = BusModel.fromFirestore(snapshot);
      if (existing.ownerId != user.uid) {
        throw const AuthFailure('You can only update your own bus.');
      }
      if (existing.hasPendingUpdate) {
        throw const AuthFailure(
          'This bus update is already pending Admin approval.',
        );
      }
      final pending = bus.toFirestore()
        ..remove('ownerId')
        ..remove('status')
        ..remove('createdAt')
        ..remove('updatedAt');
      await reference.update({
        'pendingUpdate': pending,
        'pendingUpdateStatus': 'pending_approval',
        'pendingUpdateReason': null,
        'pendingUpdateSubmittedAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });
      final admins = await _firestore
          .collection('users')
          .where('role', isEqualTo: 'admin')
          .get();
      for (final admin in admins.docs) {
        await _notificationRepository.create(
          NotificationModel(
            id: '${bus.id}_update_${admin.id}',
            recipientId: admin.id,
            type: 'bus_update_submitted',
            title: 'Bus update requires review',
            message: '${bus.name} has an updated version waiting for approval.',
            relatedBusId: bus.id,
            isRead: false,
            createdAt: DateTime.now(),
          ),
        );
      }
    } on AuthFailure {
      rethrow;
    } on FirebaseException catch (error) {
      throw AuthFailure(AuthExceptionMapper.fromFirestore(error));
    }
  }

  Future<void> approveBusUpdate(String busId) async {
    final reference = _firestore.collection('buses').doc(busId);
    final snapshot = await reference.get();
    if (!snapshot.exists) throw const AuthFailure('This bus no longer exists.');
    final bus = BusModel.fromFirestore(snapshot);
    final pending = bus.pendingUpdate;
    if (!bus.hasPendingUpdate || pending == null) {
      throw const AuthFailure('This bus has no pending update.');
    }
    await reference.update({
      ...pending,
      'pendingUpdate': FieldValue.delete(),
      'pendingUpdateStatus': FieldValue.delete(),
      'pendingUpdateReason': FieldValue.delete(),
      'pendingUpdateSubmittedAt': FieldValue.delete(),
      'status': 'approved',
      'updatedAt': FieldValue.serverTimestamp(),
    });
    await _notifyBusOwner(
      bus,
      type: 'bus_update_approved',
      title: 'Bus update approved',
      message: '${bus.name} was approved and is active again.',
    );
  }

  Future<void> rejectBusUpdate(String busId, {String? reason}) async {
    final reference = _firestore.collection('buses').doc(busId);
    final snapshot = await reference.get();
    if (!snapshot.exists) throw const AuthFailure('This bus no longer exists.');
    final bus = BusModel.fromFirestore(snapshot);
    if (!bus.hasPendingUpdate) {
      throw const AuthFailure('This bus has no pending update.');
    }
    await reference.update({
      'pendingUpdateStatus': 'rejected',
      'pendingUpdateReason': reason?.trim().isEmpty == true
          ? null
          : reason?.trim(),
      'updatedAt': FieldValue.serverTimestamp(),
    });
    await _notifyBusOwner(
      bus,
      type: 'bus_update_rejected',
      title: 'Bus update rejected',
      message: '${bus.name} update was rejected by BUSGO admin.',
    );
  }

  Future<void> _notifyBusOwner(
    BusModel bus, {
    required String type,
    required String title,
    required String message,
  }) => _notificationRepository.create(
    NotificationModel(
      id: '${bus.id}_${type}_${bus.ownerId}',
      recipientId: bus.ownerId,
      type: type,
      title: title,
      message: message,
      relatedBusId: bus.id,
      isRead: false,
      createdAt: DateTime.now(),
    ),
  );

  Stream<List<BusModel>> watchForOwner(String ownerId) {
    debugPrint(
      '[MY BUSES] collection = buses, field = ownerId, value = $ownerId',
    );
    return _firestore
        .collection('buses')
        .where('ownerId', isEqualTo: ownerId)
        .snapshots()
        .map((snapshot) {
          final buses = snapshot.docs.map(BusModel.fromFirestore).toList();
          debugPrint(
            '[MY BUSES] returned=${buses.length} ids=${buses.map((bus) => bus.id).join(',')}',
          );
          return buses;
        })
        .handleError((Object error, StackTrace stackTrace) {
          debugPrint('[MY BUSES] query failed = $error');
          debugPrintStack(stackTrace: stackTrace);
        });
  }

  Stream<BusModel> watchOwnerBus({
    required String busId,
    required String ownerId,
  }) {
    return _firestore.collection('buses').doc(busId).snapshots().asyncMap((
      snapshot,
    ) {
      if (!snapshot.exists) {
        throw const AuthFailure('Bus details not found.');
      }
      final bus = BusModel.fromFirestore(snapshot);
      if (bus.ownerId != ownerId) {
        throw const AuthFailure('You can only view your own buses.');
      }
      return bus;
    });
  }

  Future<BusModel?> getById(String busId) async {
    try {
      final snapshot = await _firestore.collection('buses').doc(busId).get();
      return snapshot.exists ? BusModel.fromFirestore(snapshot) : null;
    } on FirebaseException catch (error) {
      throw AuthFailure(AuthExceptionMapper.fromFirestore(error));
    }
  }

  Stream<List<BusModel>> watchAll() {
    debugPrint('[BusGoOperations] Starting buses query');
    return _firestore
        .collection('buses')
        .snapshots()
        .map((snapshot) {
          final buses = snapshot.docs.map(BusModel.fromFirestore).toList();
          debugPrint(
            '[BusGoOperations] Query completed: ${buses.length} buses',
          );
          return buses;
        })
        .handleError((Object error, StackTrace stackTrace) {
          debugPrint('[BusGoOperations] Buses query failed: $error');
          debugPrintStack(stackTrace: stackTrace);
        });
  }

  Future<void> updateStatus({
    required String busId,
    required String status,
  }) async {
    try {
      final reference = _firestore.collection('buses').doc(busId);
      final snapshot = await reference.get();
      if (!snapshot.exists) {
        throw const AuthFailure('This bus no longer exists.');
      }
      final bus = BusModel.fromFirestore(snapshot);
      if (bus.status == status) return;
      await reference.update({
        'status': status,
        'updatedAt': FieldValue.serverTimestamp(),
      });
      if (status == 'approved' || status == 'rejected') {
        try {
          await _notificationRepository.create(
            NotificationModel(
              id: '${bus.id}_status_${status}_${bus.ownerId}',
              recipientId: bus.ownerId,
              type: 'bus_$status',
              title: status == 'approved'
                  ? 'Bus approved'
                  : 'Bus submission rejected',
              message: status == 'approved'
                  ? '${bus.name} is now approved and can be discovered by customers.'
                  : '${bus.name} was rejected by BUSGO admin.',
              relatedBusId: bus.id,
              isRead: false,
              createdAt: DateTime.now(),
            ),
          );
        } catch (error) {
          debugPrint('[BUS STATUS] notification failed after update: $error');
        }
      }
    } on FirebaseException catch (error) {
      throw AuthFailure(AuthExceptionMapper.fromFirestore(error));
    }
  }

  Future<String> createBus(BusModel bus) async {
    try {
      final user = _firebaseAuth.currentUser;
      if (user == null) {
        throw const AuthFailure('Please login as a bus owner.');
      }
      debugPrint('Add bus auth user: uid=${user.uid}, email=${user.email}');
      if (bus.ownerId != user.uid) {
        throw const AuthFailure('The signed-in owner does not match this bus.');
      }
      final profile = await _firestore.collection('users').doc(user.uid).get();
      if (!profile.exists || profile.data()?['role'] != 'owner') {
        throw const AuthFailure('Please login as a bus owner.');
      }
      debugPrint('Add bus owner profile role: ${profile.data()?['role']}');
      final ownerBuses = await _firestore
          .collection('buses')
          .where('ownerId', isEqualTo: user.uid)
          .get();
      final registration = bus.registrationNumber.trim().toUpperCase();
      final duplicate = ownerBuses.docs.any(
        (document) =>
            (document.data()['registrationNumber'] as String?)
                ?.trim()
                .toUpperCase() ==
            registration,
      );
      if (duplicate) {
        throw const AuthFailure('This bus registration number already exists.');
      }
      final reference = _firestore.collection('buses').doc();
      await reference.set({
        ...bus.toFirestore(),
        'id': reference.id,
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });
      try {
        final adminSnapshot = await _firestore
            .collection('users')
            .where('role', isEqualTo: 'admin')
            .get();
        for (final admin in adminSnapshot.docs) {
          await _notificationRepository.create(
            NotificationModel(
              id: '${reference.id}_submission_${admin.id}',
              recipientId: admin.id,
              type: 'bus_submission',
              title: 'New bus submission',
              message: '${bus.name} is waiting for approval.',
              relatedBusId: reference.id,
              isRead: false,
              createdAt: DateTime.now(),
            ),
          );
        }
      } catch (error) {
        debugPrint('[BUS CREATE] admin notification failed: $error');
      }
      debugPrint('Add bus Firestore write complete: buses/${reference.id}');
      return reference.id;
    } on AuthFailure {
      rethrow;
    } on FirebaseException catch (error) {
      debugPrint('Creating bus failed: ${error.code} ${error.message}');
      if (error.code == 'permission-denied') {
        throw const AuthFailure('Firestore permission denied.');
      }
      if (error.code == 'unavailable') {
        throw const AuthFailure(
          'Firebase is currently unavailable. Check your internet connection.',
        );
      }
      throw AuthFailure(AuthExceptionMapper.fromFirestore(error));
    }
  }

  List<BusModel> _filterBuses(
    List<BusModel> buses, {
    String? serviceLocation,
    String? destination,
    int? minimumCapacity,
  }) {
    final requestedLocation = serviceLocation?.trim().toLowerCase();
    final requestedDestination = destination?.trim().toLowerCase();
    return buses.where((bus) {
      final capacityMatches =
          minimumCapacity == null || bus.capacity >= minimumCapacity;
      final locations = [
        ...bus.serviceLocations,
        if (bus.pickupLocation != null) bus.pickupLocation!,
        if (bus.destination != null) bus.destination!,
        bus.serviceLocation,
      ].map((location) => location.trim().toLowerCase()).toSet();
      final locationMatches =
          requestedLocation == null ||
          requestedLocation.isEmpty ||
          locations.any((location) => location.contains(requestedLocation));
      final destinationMatches =
          requestedDestination == null ||
          requestedDestination.isEmpty ||
          (bus.destination?.trim().toLowerCase().contains(
                requestedDestination,
              ) ??
              locations.any(
                (location) => location.contains(requestedDestination),
              ));
      return capacityMatches && locationMatches && destinationMatches;
    }).toList();
  }
}
