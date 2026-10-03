import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

import '../core/constants/booking_status.dart';
import '../core/constants/payment_status.dart';
import '../core/errors/auth_failure.dart';
import '../core/utils/auth_exception_mapper.dart';
import '../models/booking_request_model.dart';
import '../models/notification_model.dart';
import 'notification_repository.dart';

enum BookingTripCategory { upcoming, ongoing, completed, ineligible }

class BookingRequestRepository {
  BookingRequestRepository({
    FirebaseFirestore? firestore,
    NotificationRepository? notificationRepository,
  }) : _firestore = firestore ?? FirebaseFirestore.instance,
       _notificationRepository =
           notificationRepository ??
           NotificationRepository(firestore: firestore);

  final FirebaseFirestore _firestore;
  final NotificationRepository _notificationRepository;

  static bool isEligibleOwnerTrip(BookingRequestModel request) =>
      request.paymentStatus == PaymentStatus.paid &&
      (request.status == BookingRequestStatus.confirmed ||
          request.status == BookingRequestStatus.completed);

  static BookingTripCategory classifyTripByDate(
    BookingRequestModel request, {
    DateTime? referenceDate,
  }) {
    if (!isEligibleOwnerTrip(request)) return BookingTripCategory.ineligible;
    final today = _calendarDate(referenceDate ?? DateTime.now());
    final startDate = _calendarDate(request.startDate);
    final endDate = _calendarDate(request.endDate);
    if (startDate.isAfter(today)) return BookingTripCategory.upcoming;
    if (!endDate.isBefore(today)) return BookingTripCategory.ongoing;
    return BookingTripCategory.completed;
  }

  static DateTime _calendarDate(DateTime value) {
    final local = value.toLocal();
    return DateTime(local.year, local.month, local.day);
  }

  Stream<List<BookingRequestModel>> watchForCustomer(String customerId) =>
      _watchBy('customerId', customerId, logLabel: 'CUSTOMER');

  Stream<List<BookingRequestModel>> watchForOwner(String ownerId) =>
      _watchBy('ownerId', ownerId, logLabel: 'OWNER');

  static bool shouldCompleteTrip(BookingRequestModel request, {DateTime? now}) {
    if (request.status == BookingRequestStatus.completed) return true;
    final referenceTime = now ?? DateTime.now();
    final effectiveTripEnd =
        request.endDate.hour == 0 &&
            request.endDate.minute == 0 &&
            request.endDate.second == 0 &&
            request.endDate.millisecond == 0
        ? DateTime(
            request.endDate.year,
            request.endDate.month,
            request.endDate.day,
            23,
            59,
            59,
            999,
          )
        : request.endDate;
    return request.status == BookingRequestStatus.confirmed &&
        !referenceTime.isBefore(effectiveTripEnd);
  }

  Future<BookingRequestModel> ensureLifecycleState({
    required BookingRequestModel request,
    DateTime? now,
  }) async {
    final referenceTime = now ?? DateTime.now();
    if (request.status != BookingRequestStatus.confirmed ||
        !shouldCompleteTrip(request, now: referenceTime)) {
      return request;
    }

    try {
      BookingRequestModel? updatedRequest;
      await _firestore.runTransaction((transaction) async {
        final reference = _firestore
            .collection('booking_requests')
            .doc(request.id);
        final snapshot = await transaction.get(reference);
        if (!snapshot.exists) return;
        final current = BookingRequestModel.fromFirestore(snapshot);
        if (current.status != BookingRequestStatus.confirmed ||
            !shouldCompleteTrip(current, now: referenceTime)) {
          updatedRequest = current;
          return;
        }
        transaction.update(reference, {
          'status': BookingRequestStatus.completed.value,
          'updatedAt': FieldValue.serverTimestamp(),
        });
        updatedRequest = current.copyWith(
          status: BookingRequestStatus.completed,
          updatedAt: referenceTime,
        );
      });

      final currentRequest = updatedRequest ?? request;
      if (currentRequest.status == BookingRequestStatus.completed) {
        await _createBookingNotification(
          bookingId: request.id,
          recipientId: request.customerId,
          type: 'trip_completed',
          title: 'Trip completed',
          message: 'Your trip is completed. Please share your experience.',
        );
      }
      return currentRequest;
    } on FirebaseException catch (error) {
      throw AuthFailure(AuthExceptionMapper.fromFirestore(error));
    }
  }

  Future<BookingRequestModel?> getById(String requestId) async {
    try {
      final snapshot = await _firestore
          .collection('booking_requests')
          .doc(requestId)
          .get();
      if (!snapshot.exists) return null;
      return BookingRequestModel.fromFirestore(snapshot);
    } on FirebaseException catch (error) {
      throw AuthFailure(AuthExceptionMapper.fromFirestore(error));
    }
  }

  Future<void> submitReview({
    required BookingRequestModel request,
    required int rating,
    required String feedback,
  }) async {
    final normalizedRating = rating.clamp(1, 5);
    final normalizedFeedback = feedback.trim();
    final currentUser = FirebaseAuth.instance.currentUser;
    final authenticatedUid = currentUser?.uid ?? 'null';
    if (currentUser == null || request.customerId != currentUser.uid) {
      throw const AuthFailure(
        'You can only submit a review for your own trip.',
      );
    }
    debugPrint('[BUSGO REVIEW SUBMIT DEBUG]');
    debugPrint('authenticatedUid: $authenticatedUid');
    debugPrint('role: customer');
    debugPrint('bookingId: ${request.id}');
    debugPrint('tripId: ${request.id}');
    debugPrint('ownerId: ${request.ownerId}');
    debugPrint('busId: ${request.busId}');
    debugPrint('rating: $normalizedRating');
    debugPrint('comment: $normalizedFeedback');
    debugPrint('targetCollection: booking_requests');
    debugPrint('operation: REVIEW CREATE/UPDATE');
    debugPrint('[/BUSGO REVIEW SUBMIT DEBUG]');

    if (request.hasSubmittedReview) {
      throw const AuthFailure(
        'You have already submitted a review for this trip.',
      );
    }
    if (request.status != BookingRequestStatus.completed &&
        !shouldCompleteTrip(request)) {
      throw const AuthFailure(
        'Review is only available after the trip is completed.',
      );
    }

    try {
      await _firestore.runTransaction((transaction) async {
        final reference = _firestore
            .collection('booking_requests')
            .doc(request.id);
        final snapshot = await transaction.get(reference);
        if (!snapshot.exists) {
          throw const AuthFailure('This booking request no longer exists.');
        }
        final current = BookingRequestModel.fromFirestore(snapshot);
        if (current.hasSubmittedReview) {
          throw const AuthFailure(
            'You have already submitted a review for this trip.',
          );
        }
        if (current.status != BookingRequestStatus.completed &&
            !shouldCompleteTrip(current)) {
          throw const AuthFailure(
            'Review is only available after the trip is completed.',
          );
        }
        transaction.update(reference, {
          'status': BookingRequestStatus.completed.value,
          'reviewRating': normalizedRating,
          'reviewFeedback': normalizedFeedback,
          'reviewSubmittedAt': FieldValue.serverTimestamp(),
          'updatedAt': FieldValue.serverTimestamp(),
        });
      });
      Future<void> notifyReviewRecipient({
        required String recipientId,
        required String title,
        required String message,
      }) async {
        try {
          await _createBookingNotification(
            bookingId: request.id,
            recipientId: recipientId,
            type: 'trip_review_submitted',
            title: title,
            message: message,
          );
        } catch (error) {
          debugPrint(
            '[REVIEW NOTIFICATION] recipientId=$recipientId failed: $error',
          );
        }
      }

      await notifyReviewRecipient(
        recipientId: request.ownerId,
        title: 'Customer feedback received',
        message: 'A customer has shared feedback for your trip.',
      );
      await notifyReviewRecipient(
        recipientId: request.customerId,
        title: 'Thanks for giving feedback!',
        message: 'Your review has been submitted successfully.',
      );
      try {
        final admins = await _firestore
            .collection('users')
            .where('role', isEqualTo: 'admin')
            .get();
        for (final admin in admins.docs) {
          await notifyReviewRecipient(
            recipientId: admin.id,
            title: 'Customer feedback received',
            message: 'A customer has shared feedback for a trip.',
          );
        }
      } catch (error) {
        debugPrint(
          '[REVIEW NOTIFICATION] Admin recipients could not load: $error',
        );
      }
    } on FirebaseException catch (error) {
      debugPrint('[BUSGO REVIEW ERROR]');
      debugPrint('operation: REVIEW CREATE/UPDATE');
      debugPrint('collection: booking_requests');
      debugPrint('document: ${request.id}');
      debugPrint('errorCode: ${error.code}');
      debugPrint('errorMessage: ${error.message ?? 'null'}');
      debugPrint('[/BUSGO REVIEW ERROR]');
      throw AuthFailure(AuthExceptionMapper.fromFirestore(error));
    }
  }

  Future<BookingRequestModel?> getForOwner({
    required String requestId,
    required String ownerId,
  }) async {
    try {
      final snapshot = await _firestore
          .collection('booking_requests')
          .doc(requestId)
          .get();
      if (!snapshot.exists) return null;
      final request = BookingRequestModel.fromFirestore(snapshot);
      return request.ownerId == ownerId ? request : null;
    } on FirebaseException catch (error) {
      throw AuthFailure(AuthExceptionMapper.fromFirestore(error));
    }
  }

  Future<BookingRequestModel?> getForCustomer({
    required String requestId,
    required String customerId,
  }) async {
    try {
      final snapshot = await _firestore
          .collection('booking_requests')
          .doc(requestId)
          .get();
      if (!snapshot.exists) return null;
      final request = BookingRequestModel.fromFirestore(snapshot);
      return request.customerId == customerId ? request : null;
    } on FirebaseException catch (error) {
      throw AuthFailure(AuthExceptionMapper.fromFirestore(error));
    }
  }

  static List<BookingRequestModel> deduplicateRequestsById(
    List<BookingRequestModel> requests,
  ) {
    final seenIds = <String>{};
    final deduplicated = <BookingRequestModel>[];
    for (final request in requests) {
      if (request.id.trim().isEmpty) continue;
      if (seenIds.add(request.id)) {
        deduplicated.add(request);
      }
    }
    return deduplicated;
  }

  Future<void> cleanupDuplicateLogicalRequests({bool dryRun = true}) async {
    final snapshot = await _firestore.collection('booking_requests').get();
    final requests = snapshot.docs
        .map(BookingRequestModel.fromFirestore)
        .toList();
    final byIdentity = <String, BookingRequestModel>{};
    final duplicates = <BookingRequestModel>[];

    for (final request in requests) {
      final identity = buildRequestIdentity(request);
      final existing = byIdentity[identity];
      if (existing == null) {
        byIdentity[identity] = request;
      } else {
        duplicates.add(request);
      }
    }

    if (dryRun || duplicates.isEmpty) {
      debugPrint(
        '[BOOKING CLEANUP] dryRun=$dryRun duplicateLogicalBookings=${duplicates.length}',
      );
      return;
    }

    final batch = _firestore.batch();
    for (final duplicate in duplicates) {
      final reference = _firestore
          .collection('booking_requests')
          .doc(duplicate.id);
      batch.delete(reference);
    }
    await batch.commit();
    debugPrint(
      '[BOOKING CLEANUP] removed ${duplicates.length} duplicate logical booking records',
    );
  }

  Stream<List<BookingRequestModel>> watchAll() {
    debugPrint('[BusGoOperations] Starting booking_requests query');
    return _firestore
        .collection('booking_requests')
        .snapshots()
        .map((snapshot) {
          final requests = deduplicateRequestsById(
            snapshot.docs.map(BookingRequestModel.fromFirestore).toList(),
          );
          final sorted = sortBookingRequestsByNewestFirst(requests);
          debugPrint(
            '[BusGoOperations] Booking query completed: ${sorted.length} requests',
          );
          return sorted;
        })
        .handleError((Object error, StackTrace stackTrace) {
          debugPrint('[BusGoOperations] Booking query failed: $error');
          debugPrintStack(stackTrace: stackTrace);
        });
  }

  static String buildRequestIdentity(BookingRequestModel request) {
    final startDate = request.startDate;
    final endDate = request.endDate;
    final normalizedPickup = request.pickup.trim().toLowerCase();
    final normalizedDestination = request.destination.trim().toLowerCase();
    final normalizedTripType = request.tripType.trim().toLowerCase();

    return [
      'customer:${request.customerId.trim()}',
      'owner:${request.ownerId.trim()}',
      'bus:${request.busId.trim()}',
      'pickup:$normalizedPickup',
      'destination:$normalizedDestination',
      'start:${startDate.year}-${startDate.month.toString().padLeft(2, '0')}-${startDate.day.toString().padLeft(2, '0')}',
      'end:${endDate.year}-${endDate.month.toString().padLeft(2, '0')}-${endDate.day.toString().padLeft(2, '0')}',
      'trip:$normalizedTripType',
    ].join('|');
  }

  static bool isActiveBookingStatus(BookingRequestStatus status) =>
      switch (status) {
        BookingRequestStatus.pendingOwner ||
        BookingRequestStatus.ownerAccepted ||
        BookingRequestStatus.adminReview ||
        BookingRequestStatus.paymentRequired ||
        BookingRequestStatus.confirmed => true,
        _ => false,
      };

  static String buildRequestDocumentId(
    BookingRequestModel request, {
    BookingRequestStatus? existingStatus,
    DateTime? referenceTime,
  }) {
    final normalized = buildRequestIdentity(request)
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9]+'), '-')
        .replaceAll(RegExp(r'-+'), '-')
        .replaceAll(RegExp(r'(^-|-$)'), '');
    final baseId = normalized.length > 120
        ? normalized.substring(0, 120)
        : normalized;

    if (existingStatus != null && !isActiveBookingStatus(existingStatus)) {
      final stamp = (referenceTime ?? DateTime.now()).microsecondsSinceEpoch
          .toString();
      final candidate = '$baseId-$stamp';
      return candidate.length > 150 ? candidate.substring(0, 150) : candidate;
    }

    return baseId;
  }

  Future<BookingRequestModel?> findExistingActiveRequest(
    BookingRequestModel request,
  ) async {
    final documentId = buildRequestDocumentId(request);
    final reference = _firestore.collection('booking_requests').doc(documentId);
    debugPrint('[BUSGO BOOKING CHECK]');
    debugPrint('[BUSGO BOOKING CHECK] collection: booking_requests');
    debugPrint('[BUSGO BOOKING CHECK] documentId: $documentId');
    debugPrint('[BUSGO BOOKING CHECK] operation: existing-booking-check');
    debugPrint('[BUSGO BOOKING CHECK] customerUid: ${request.customerId}');
    try {
      final snapshot = await reference.get();
      debugPrint(
        '[BUSGO BOOKING CHECK SUCCESS] documentId: $documentId exists=${snapshot.exists}',
      );
      if (snapshot.exists) {
        final existing = BookingRequestModel.fromFirestore(snapshot);
        if (isActiveBookingStatus(existing.status) &&
            buildRequestIdentity(existing) == buildRequestIdentity(request)) {
          debugPrint(
            '[BOOKING DUPLICATE] deterministic document match for requestId=${existing.id}',
          );
          return existing;
        }
      }
    } on FirebaseException catch (error) {
      debugPrint('[BUSGO BOOKING CHECK FAILED]');
      debugPrint('[BUSGO BOOKING CHECK FAILED] documentId: $documentId');
      debugPrint('[BUSGO BOOKING CHECK FAILED] operation: get');
      debugPrint('[BUSGO BOOKING CHECK FAILED] errorCode: ${error.code}');
      debugPrint('[BUSGO BOOKING CHECK FAILED] errorMessage: ${error.message}');
      rethrow;
    }

    final querySnapshot = await _firestore
        .collection('booking_requests')
        .where('customerId', isEqualTo: request.customerId)
        .where('ownerId', isEqualTo: request.ownerId)
        .where('busId', isEqualTo: request.busId)
        .get();

    for (final doc in querySnapshot.docs) {
      final existing = BookingRequestModel.fromFirestore(doc);
      if (existing.id == request.id) continue;
      if (!isActiveBookingStatus(existing.status)) continue;
      if (buildRequestIdentity(existing) == buildRequestIdentity(request)) {
        debugPrint(
          '[BOOKING DUPLICATE] active request found for customerId=${request.customerId} ownerId=${request.ownerId} busId=${request.busId} requestId=${existing.id}',
        );
        return existing;
      }
    }
    return null;
  }

  Future<String> createRequest(BookingRequestModel request) async {
    debugPrint('========== BUSGO FIRESTORE DEBUG ==========');
    debugPrint('[BUSGO FIRESTORE DEBUG] Operation: CREATE');
    debugPrint('[BUSGO FIRESTORE DEBUG] Collection: booking_requests');
    debugPrint(
      '[BUSGO FIRESTORE DEBUG] Authenticated Firebase UID: ${request.customerId}',
    );
    debugPrint('[BUSGO FIRESTORE DEBUG] Role: customer');
    debugPrint(
      '[BUSGO FIRESTORE DEBUG] Document ID: ${request.id.isEmpty ? '<generated>' : request.id}',
    );
    debugPrint('[BUSGO FIRESTORE DEBUG] customerId: ${request.customerId}');
    debugPrint('[BUSGO FIRESTORE DEBUG] ownerId: ${request.ownerId}');
    debugPrint('[BUSGO FIRESTORE DEBUG] busId: ${request.busId}');
    debugPrint('[BUSGO FIRESTORE DEBUG] status: ${request.status.value}');
    debugPrint('[BUSGO FIRESTORE DEBUG] pickup: ${request.pickup}');
    debugPrint('[BUSGO FIRESTORE DEBUG] destination: ${request.destination}');
    debugPrint(
      '[BUSGO FIRESTORE DEBUG] startDate: ${request.startDate.toIso8601String()}',
    );
    debugPrint(
      '[BUSGO FIRESTORE DEBUG] endDate: ${request.endDate.toIso8601String()}',
    );
    debugPrint('==============================================');
    try {
      final duplicate = await findExistingActiveRequest(request);
      if (duplicate != null) {
        debugPrint(
          '[BOOKING CREATE] Duplicate request found; reusing existing id = ${duplicate.id}',
        );
        return duplicate.id;
      }

      final requestId = await _firestore.runTransaction<String>((
        transaction,
      ) async {
        final initialDocumentId = buildRequestDocumentId(request);
        final initialReference = _firestore
            .collection('booking_requests')
            .doc(initialDocumentId);
        debugPrint('[BUSGO BOOKING CREATE]');
        debugPrint('[BUSGO BOOKING CREATE] documentId: $initialDocumentId');
        debugPrint('[BUSGO BOOKING CREATE] customerUid: ${request.customerId}');
        debugPrint('[BUSGO BOOKING CREATE] ownerUid: ${request.ownerId}');
        debugPrint('[BUSGO BOOKING CREATE] busId: ${request.busId}');
        debugPrint('[BUSGO BOOKING CREATE] status: ${request.status.value}');
        final initialSnapshot = await transaction.get(initialReference);

        if (initialSnapshot.exists) {
          final existing = BookingRequestModel.fromFirestore(initialSnapshot);
          if (isActiveBookingStatus(existing.status) &&
              buildRequestIdentity(existing) == buildRequestIdentity(request)) {
            debugPrint(
              '[BOOKING CREATE] Reused active request with id=${existing.id}',
            );
            return existing.id;
          }

          final freshDocumentId = buildRequestDocumentId(
            request,
            existingStatus: existing.status,
            referenceTime: request.createdAt,
          );
          final freshReference = _firestore
              .collection('booking_requests')
              .doc(freshDocumentId);
          final freshSnapshot = await transaction.get(freshReference);
          if (freshSnapshot.exists) {
            final freshExisting = BookingRequestModel.fromFirestore(
              freshSnapshot,
            );
            if (isActiveBookingStatus(freshExisting.status) &&
                buildRequestIdentity(freshExisting) ==
                    buildRequestIdentity(request)) {
              debugPrint(
                '[BOOKING CREATE] Reused active request with id=${freshExisting.id}',
              );
              return freshExisting.id;
            }
          }

          final requestDocument = request.copyWith(
            id: freshReference.id,
            createdAt: DateTime.now(),
            updatedAt: DateTime.now(),
          );
          transaction.set(freshReference, requestDocument.toFirestore());
          debugPrint(
            '[BOOKING CREATE] creating new requestId = ${freshReference.id} after stale match',
          );
          return freshReference.id;
        }

        final requestDocument = request.copyWith(
          id: initialReference.id,
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        );
        transaction.set(initialReference, requestDocument.toFirestore());
        debugPrint(
          '[BOOKING CREATE] creating new requestId = ${initialReference.id}',
        );
        return initialReference.id;
      });

      debugPrint('[BUSGO FIRESTORE DEBUG] Operation: CREATE');
      debugPrint('[BUSGO FIRESTORE DEBUG] Collection: notifications');
      debugPrint('[BUSGO FIRESTORE DEBUG] recipientId: ${request.ownerId}');
      debugPrint('[BUSGO FIRESTORE DEBUG] relatedBookingId: $requestId');
      debugPrint('[BUSGO FIRESTORE DEBUG] Result: SUCCESS');
      await _createBookingNotification(
        bookingId: requestId,
        recipientId: request.ownerId,
        type: 'booking_request',
        title: 'New booking request',
        message:
            '${request.customerName ?? 'A customer'} requested ${request.pickup} to ${request.destination}.',
      );
      final adminSnapshot = await _firestore
          .collection('users')
          .where('role', isEqualTo: 'admin')
          .get();
      for (final admin in adminSnapshot.docs) {
        debugPrint('[BUSGO FIRESTORE DEBUG] Operation: CREATE');
        debugPrint('[BUSGO FIRESTORE DEBUG] Collection: notifications');
        debugPrint('[BUSGO FIRESTORE DEBUG] recipientId: ${admin.id}');
        debugPrint('[BUSGO FIRESTORE DEBUG] relatedBookingId: $requestId');
        await _createBookingNotification(
          bookingId: requestId,
          recipientId: admin.id,
          type: 'booking_request',
          title: 'New booking request',
          message: 'A customer submitted a booking request for admin review.',
        );
        debugPrint('[BUSGO FIRESTORE DEBUG] Result: SUCCESS');
      }
      debugPrint('========== BUSGO FIRESTORE SUCCESS ==========');
      debugPrint('operation: create booking request');
      debugPrint('collection: booking_requests');
      debugPrint('document: $requestId');
      debugPrint('customerId: ${request.customerId}');
      debugPrint('busId: ${request.busId}');
      debugPrint('ownerId: ${request.ownerId}');
      debugPrint('status: ${request.status.value}');
      debugPrint('=============================================');
      debugPrint('[BOOKING CREATE] Request created successfully');
      debugPrint('[BOOKING CREATE] requestId = $requestId');
      return requestId;
    } on FirebaseException catch (error) {
      debugPrint('========== BUSGO FIRESTORE FAILURE ==========');
      debugPrint('operation: create booking request');
      debugPrint('collection: booking_requests');
      debugPrint(
        'document: ${request.id.isEmpty ? request.busId : request.id}',
      );
      debugPrint('code: ${error.code}');
      debugPrint('message: ${error.message}');
      debugPrint('authenticatedUid: ${request.customerId}');
      debugPrint('=============================================');
      debugPrint('[BUSGO FIRESTORE DEBUG] Result: FAILED');
      debugPrint('[BUSGO FIRESTORE DEBUG] Firebase error code: ${error.code}');
      debugPrint(
        '[BUSGO FIRESTORE DEBUG] Firebase error message: ${error.message}',
      );
      debugPrint('[BOOKING CREATE] error = ${error.code}: ${error.message}');
      throw AuthFailure(AuthExceptionMapper.fromFirestore(error));
    }
  }

  Future<void> transitionStatus({
    required String requestId,
    required BookingRequestStatus nextStatus,
    String? rejectionReason,
    String? ownerId,
    String? customerId,
    String? busId,
  }) async {
    BookingRequestModel? request;
    try {
      await _firestore.runTransaction((transaction) async {
        final reference = _firestore
            .collection('booking_requests')
            .doc(requestId);
        final snapshot = await transaction.get(reference);
        if (!snapshot.exists) {
          throw const AuthFailure('This booking request no longer exists.');
        }
        final parsedRequest = BookingRequestModel.fromFirestore(snapshot);
        request = parsedRequest;
        debugPrint(
          '[BOOKING TRANSITION] bookingId=$requestId ownerId=${ownerId ?? parsedRequest.ownerId} currentStatus=${parsedRequest.status.value} targetStatus=${nextStatus.value} paymentStatus=${parsedRequest.paymentStatus.value}',
        );
        if (parsedRequest.status == nextStatus) {
          debugPrint(
            '[BOOKING TRANSITION] No-op transition for bookingId=$requestId, already at ${nextStatus.value}',
          );
          return;
        }
        if (!canTransitionBookingStatus(parsedRequest.status, nextStatus)) {
          throw const AuthFailure(
            'That booking status transition is not allowed.',
          );
        }
        final updates = <String, dynamic>{
          'status': nextStatus.value,
          'updatedAt': FieldValue.serverTimestamp(),
        };
        if (rejectionReason != null && rejectionReason.trim().isNotEmpty) {
          updates['rejectionReason'] = rejectionReason.trim();
        }
        if (nextStatus == BookingRequestStatus.ownerAccepted) {
          updates['ownerDecision'] = 'ACCEPTED';
        } else if (nextStatus == BookingRequestStatus.ownerRejected) {
          updates['ownerDecision'] = 'REJECTED';
        } else if (nextStatus == BookingRequestStatus.paymentRequired) {
          updates['adminDecision'] = 'CONFIRMED';
          updates['paymentStatus'] = PaymentStatus.requested.value;
          updates['paymentRequestedAt'] = FieldValue.serverTimestamp();
        } else if (nextStatus == BookingRequestStatus.adminRejected) {
          updates['adminDecision'] = 'REJECTED';
        }
        transaction.update(reference, updates);
      });
      final savedRequest = request;
      if (savedRequest != null) {
        await _createTransitionNotifications(
          request: savedRequest,
          nextStatus: nextStatus,
          rejectionReason: rejectionReason,
          ownerId: ownerId ?? savedRequest.ownerId,
          customerId: customerId ?? savedRequest.customerId,
          busId: busId ?? savedRequest.busId,
        );
      }
    } on AuthFailure {
      rethrow;
    } on FirebaseException catch (error) {
      throw AuthFailure(AuthExceptionMapper.fromFirestore(error));
    }
  }

  Future<bool> isBusAvailable({
    required String busId,
    required DateTime startDate,
    required DateTime endDate,
    String? excludingRequestId,
  }) async {
    try {
      final snapshot = await _firestore
          .collection('booking_requests')
          .where('busId', isEqualTo: busId)
          .where(
            'status',
            whereIn: [
              BookingRequestStatus.confirmed.value,
              BookingRequestStatus.paymentRequired.value,
            ],
          )
          .get();
      return snapshot.docs.every((document) {
        if (document.id == excludingRequestId) return true;
        final existing = BookingRequestModel.fromFirestore(document);
        return !bookingDatesOverlap(
          existingStart: existing.startDate,
          existingEnd: existing.endDate,
          requestedStart: startDate,
          requestedEnd: endDate,
        );
      });
    } on FirebaseException catch (error) {
      throw AuthFailure(AuthExceptionMapper.fromFirestore(error));
    }
  }

  Future<void> confirmAfterAvailabilityCheck({
    required BookingRequestModel request,
  }) async {
    final available = await isBusAvailable(
      busId: request.busId,
      startDate: request.startDate,
      endDate: request.endDate,
      excludingRequestId: request.id,
    );
    if (!available) {
      throw const AuthFailure('Bus is already booked for the selected dates.');
    }
    await transitionStatus(
      requestId: request.id,
      nextStatus: BookingRequestStatus.adminReview,
      ownerId: request.ownerId,
      customerId: request.customerId,
    );
    await transitionStatus(
      requestId: request.id,
      nextStatus: BookingRequestStatus.paymentRequired,
      ownerId: request.ownerId,
      customerId: request.customerId,
    );
  }

  Future<void> ownerAccept({required BookingRequestModel request}) async {
    await transitionStatus(
      requestId: request.id,
      nextStatus: BookingRequestStatus.ownerAccepted,
      ownerId: request.ownerId,
      customerId: request.customerId,
    );
  }

  Future<void> submitPayment({
    required BookingRequestModel request,
    required String paymentReference,
  }) async {
    final reference = paymentReference.trim();
    if (reference.isEmpty) {
      throw const AuthFailure('Enter the payment reference to continue.');
    }
    debugPrint('[BUSGO PAYMENT SUBMIT]');
    debugPrint('customerUid: ${request.customerId}');
    debugPrint('ownerId: ${request.ownerId}');
    debugPrint('busId: ${request.busId}');
    debugPrint('bookingId: ${request.id}');
    debugPrint('paymentReference: $reference');
    debugPrint('amount: ${request.estimatedAmount}');
    debugPrint('operation: submit payment');
    debugPrint('[/BUSGO PAYMENT SUBMIT]');
    try {
      await _firestore.runTransaction((transaction) async {
        final document = _firestore
            .collection('booking_requests')
            .doc(request.id);
        final snapshot = await transaction.get(document);
        if (!snapshot.exists) {
          throw const AuthFailure('This booking request no longer exists.');
        }
        final current = BookingRequestModel.fromFirestore(snapshot);
        if (current.status != BookingRequestStatus.paymentRequired ||
            current.paymentStatus != PaymentStatus.requested) {
          throw const AuthFailure(
            'Payment is not currently required for this booking.',
          );
        }
        transaction.update(document, {
          'paymentStatus': PaymentStatus.submitted.value,
          'paymentReference': reference,
          'paymentSubmittedAt': FieldValue.serverTimestamp(),
          'updatedAt': FieldValue.serverTimestamp(),
        });
      });
      debugPrint('[BUSGO PAYMENT SUBMIT SUCCESS]');
      debugPrint('bookingId: ${request.id}');
      debugPrint('status: ${PaymentStatus.submitted.value}');
      debugPrint('[/BUSGO PAYMENT SUBMIT SUCCESS]');
      await _createBookingNotification(
        bookingId: request.id,
        recipientId: request.ownerId,
        type: 'payment_submitted',
        title: 'Customer payment submitted for verification',
        message:
            'Customer payment submitted for verification for ${request.pickup} to ${request.destination}.',
      );
      final adminSnapshot = await _firestore
          .collection('users')
          .where('role', isEqualTo: 'admin')
          .get();
      for (final admin in adminSnapshot.docs) {
        await _createBookingNotification(
          bookingId: request.id,
          recipientId: admin.id,
          type: 'payment_submitted',
          title: 'Payment verification required',
          message: 'A customer submitted payment for admin verification.',
        );
      }
    } on FirebaseException catch (error) {
      debugPrint('[BUSGO PAYMENT SUBMIT ERROR]');
      debugPrint('operation: submit payment');
      debugPrint('errorCode: ${error.code}');
      debugPrint('errorMessage: ${error.message ?? error.toString()}');
      debugPrint('[/BUSGO PAYMENT SUBMIT ERROR]');
      throw AuthFailure(AuthExceptionMapper.fromFirestore(error));
    }
  }

  Future<void> markPaymentPaid({required BookingRequestModel request}) async {
    try {
      var changed = false;
      await _firestore.runTransaction((transaction) async {
        final reference = _firestore
            .collection('booking_requests')
            .doc(request.id);
        final snapshot = await transaction.get(reference);
        final current = BookingRequestModel.fromFirestore(snapshot);
        debugPrint(
          '[OWNER PAYMENT] booking ID = ${request.id}, status before update = ${current.status.value}, paymentStatus=${current.paymentStatus.value}',
        );
        if (current.paymentStatus == PaymentStatus.paid) return;
        if (!canTransitionBookingStatus(
          current.status,
          BookingRequestStatus.confirmed,
        )) {
          throw const AuthFailure(
            'This booking is not awaiting payment verification.',
          );
        }
        if (current.status != BookingRequestStatus.paymentRequired ||
            current.paymentStatus != PaymentStatus.submitted) {
          throw const AuthFailure(
            'This booking is not awaiting payment verification.',
          );
        }
        transaction.update(reference, {
          'status': BookingRequestStatus.confirmed.value,
          'paymentStatus': PaymentStatus.paid.value,
          'updatedAt': FieldValue.serverTimestamp(),
        });
        changed = true;
      });
      debugPrint(
        '[OWNER PAYMENT] booking ID = ${request.id}, status after update = ${changed ? PaymentStatus.paid.value : PaymentStatus.paid.value} changed=$changed',
      );
      if (!changed) return;
      await _createBookingNotification(
        bookingId: request.id,
        recipientId: request.customerId,
        type: 'payment_paid',
        title: 'Payment verified',
        message:
            'Your payment for ${request.pickup} to ${request.destination} was verified.',
      );
      await _createBookingNotification(
        bookingId: request.id,
        recipientId: request.ownerId,
        type: 'payment_paid',
        title: 'Payment verified',
        message:
            'Payment for ${request.pickup} to ${request.destination} was verified by BUSGO admin.',
      );
      final adminSnapshot = await _firestore
          .collection('users')
          .where('role', isEqualTo: 'admin')
          .get();
      for (final admin in adminSnapshot.docs) {
        await _createBookingNotification(
          bookingId: request.id,
          recipientId: admin.id,
          type: 'payment_paid',
          title: 'Payment verified',
          message: 'A customer payment was verified by BUSGO admin.',
        );
      }
    } on FirebaseException catch (error) {
      throw AuthFailure(AuthExceptionMapper.fromFirestore(error));
    }
  }

  Future<void> adminAccept({required BookingRequestModel request}) async {
    if (request.status != BookingRequestStatus.ownerAccepted &&
        request.status != BookingRequestStatus.adminReview) {
      throw const AuthFailure('This booking is not ready for admin review.');
    }
    await transitionStatus(
      requestId: request.id,
      nextStatus: BookingRequestStatus.paymentRequired,
      ownerId: request.ownerId,
      customerId: request.customerId,
    );
  }

  Future<void> adminReject({
    required BookingRequestModel request,
    required String reason,
  }) async {
    if (request.status != BookingRequestStatus.ownerAccepted &&
        request.status != BookingRequestStatus.adminReview) {
      throw const AuthFailure('This booking is not ready for admin review.');
    }
    await transitionStatus(
      requestId: request.id,
      nextStatus: BookingRequestStatus.adminRejected,
      rejectionReason: reason,
      ownerId: request.ownerId,
      customerId: request.customerId,
    );
  }

  Future<void> rejectAfterAvailabilityCheck({
    required BookingRequestModel request,
    required String reason,
  }) async {
    if (request.status == BookingRequestStatus.ownerAccepted) {
      await transitionStatus(
        requestId: request.id,
        nextStatus: BookingRequestStatus.adminReview,
        ownerId: request.ownerId,
        customerId: request.customerId,
      );
    }
    await transitionStatus(
      requestId: request.id,
      nextStatus: BookingRequestStatus.adminRejected,
      rejectionReason: reason,
      ownerId: request.ownerId,
      customerId: request.customerId,
    );
  }

  Stream<List<BookingRequestModel>> _watchBy(
    String field,
    String value, {
    required String logLabel,
  }) {
    debugPrint(
      '[${logLabel == 'OWNER' ? 'OWNER REQUESTS' : 'BOOKING $logLabel QUERY'}] collection = booking_requests, field = $field, value = $value',
    );
    return _firestore
        .collection('booking_requests')
        .where(field, isEqualTo: value)
        .snapshots()
        .map((snapshot) {
          final requests = deduplicateRequestsById(
            snapshot.docs.map(BookingRequestModel.fromFirestore).toList(),
          );
          final sorted = sortBookingRequestsByNewestFirst(requests);
          debugPrint('[BOOKING $logLabel QUERY] count = ${sorted.length}');
          debugPrint(
            '[BOOKING $logLabel QUERY] ids = ${sorted.map((request) => request.id).join(',')}',
          );
          return sorted;
        })
        .handleError((Object error, StackTrace stackTrace) {
          debugPrint('[BOOKING $logLabel QUERY] failed = $error');
          debugPrintStack(stackTrace: stackTrace);
        });
  }

  Future<void> _createTransitionNotifications({
    required BookingRequestModel request,
    required BookingRequestStatus nextStatus,
    required String? rejectionReason,
    required String ownerId,
    required String customerId,
    required String busId,
  }) async {
    final notifications = <NotificationModel>[];
    void add({
      required String recipientId,
      required String type,
      required String title,
      required String message,
    }) {
      if (recipientId.isEmpty) return;
      notifications.add(
        NotificationModel(
          id: '${request.id}_${type}_$recipientId',
          recipientId: recipientId,
          type: type,
          title: title,
          message: message,
          relatedBookingId: request.id,
          isRead: false,
          createdAt: DateTime.now(),
        ),
      );
    }

    switch (nextStatus) {
      case BookingRequestStatus.ownerAccepted:
        add(
          recipientId: customerId,
          type: 'owner_accepted',
          title: 'Owner accepted your request',
          message: 'BUSGO is verifying availability for your whole-bus trip.',
        );
        final adminSnapshot = await _firestore
            .collection('users')
            .where('role', isEqualTo: 'admin')
            .get();
        for (final admin in adminSnapshot.docs) {
          add(
            recipientId: admin.id,
            type: 'availability_review',
            title: 'Availability verification required',
            message: 'An owner accepted a whole-bus request.',
          );
        }
      case BookingRequestStatus.ownerRejected:
        add(
          recipientId: customerId,
          type: 'owner_rejected',
          title: 'Request declined by owner',
          message: rejectionReason?.trim().isNotEmpty == true
              ? rejectionReason!.trim()
              : 'Your bus request was declined by the owner.',
        );
        final adminSnapshot = await _firestore
            .collection('users')
            .where('role', isEqualTo: 'admin')
            .get();
        for (final admin in adminSnapshot.docs) {
          add(
            recipientId: admin.id,
            type: 'owner_rejected',
            title: 'Booking request declined by owner',
            message: 'An owner declined a customer booking request.',
          );
        }
      case BookingRequestStatus.adminReview:
        add(
          recipientId: customerId,
          type: 'admin_review',
          title: 'BUSGO is reviewing your request',
          message: 'The owner accepted your request. BUSGO is checking dates.',
        );
      case BookingRequestStatus.paymentRequired:
        add(
          recipientId: customerId,
          type: 'payment_required',
          title: 'Payment requested for your trip',
          message:
              'Your trip is approved. Complete payment from My trips to secure it.',
        );
        add(
          recipientId: ownerId,
          type: 'payment_required',
          title: 'Trip approved for payment',
          message:
              'The admin approved your whole-bus trip for customer payment.',
        );
      case BookingRequestStatus.confirmed:
        add(
          recipientId: customerId,
          type: 'booking_confirmed',
          title: 'Booking confirmed',
          message:
              'Your payment was verified and your whole-bus trip is confirmed.',
        );
        add(
          recipientId: ownerId,
          type: 'booking_confirmed',
          title: 'Booking confirmed',
          message: 'The admin verified payment for your whole-bus booking.',
        );
      case BookingRequestStatus.adminRejected:
        add(
          recipientId: customerId,
          type: 'admin_rejected',
          title: 'Bus unavailable for these dates',
          message: rejectionReason?.trim().isNotEmpty == true
              ? rejectionReason!.trim()
              : 'The bus is unavailable for the selected dates.',
        );
        add(
          recipientId: ownerId,
          type: 'admin_rejected',
          title: 'Trip rejected by BUSGO admin',
          message: rejectionReason?.trim().isNotEmpty == true
              ? rejectionReason!.trim()
              : 'The bus is unavailable for the selected dates.',
        );
      case BookingRequestStatus.pendingOwner:
      case BookingRequestStatus.cancelled:
      case BookingRequestStatus.completed:
        break;
    }
    for (final notification in notifications) {
      await _notificationRepository.create(notification);
    }
  }

  Future<void> _createBookingNotification({
    required String bookingId,
    required String recipientId,
    required String type,
    required String title,
    required String message,
  }) async {
    if (recipientId.isEmpty) return;
    await _notificationRepository.create(
      NotificationModel(
        id: '${bookingId}_${type}_$recipientId',
        recipientId: recipientId,
        type: type,
        title: title,
        message: message,
        relatedBookingId: bookingId,
        isRead: false,
        createdAt: DateTime.now(),
      ),
    );
  }
}
