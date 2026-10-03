import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_application_12/core/constants/booking_status.dart';
import 'package:flutter_application_12/core/constants/payment_status.dart';
import 'package:flutter_application_12/models/booking_request_model.dart';
import 'package:flutter_application_12/repositories/booking_request_repository.dart';

void main() {
  final baseRequest = BookingRequestModel(
    id: 'old-doc-id',
    customerId: 'customer-1',
    customerName: 'Kishore',
    ownerId: 'owner-1',
    busId: 'bus-1',
    busName: 'City Express',
    pickup: 'Airport',
    destination: 'Munnar',
    startDate: DateTime(2026, 2, 10),
    endDate: DateTime(2026, 2, 12),
    passengerCount: 12,
    tripType: 'Family Trip',
    specialRequirements: 'AC preferred',
    estimatedAmount: 2400,
    status: BookingRequestStatus.pendingOwner,
    paymentStatus: PaymentStatus.notRequested,
    createdAt: DateTime(2026, 1, 1),
    updatedAt: DateTime(2026, 1, 1),
  );

  test('same logical booking generates the same request identity', () {
    final duplicate = baseRequest.copyWith(id: 'new-id');

    expect(
      BookingRequestRepository.buildRequestIdentity(baseRequest),
      equals(BookingRequestRepository.buildRequestIdentity(duplicate)),
    );
  });

  test('active booking statuses are treated as an existing request', () {
    expect(
      BookingRequestRepository.isActiveBookingStatus(
        BookingRequestStatus.pendingOwner,
      ),
      isTrue,
    );
    expect(
      BookingRequestRepository.isActiveBookingStatus(
        BookingRequestStatus.ownerAccepted,
      ),
      isTrue,
    );
    expect(
      BookingRequestRepository.isActiveBookingStatus(
        BookingRequestStatus.adminReview,
      ),
      isTrue,
    );
    expect(
      BookingRequestRepository.isActiveBookingStatus(
        BookingRequestStatus.paymentRequired,
      ),
      isTrue,
    );
    expect(
      BookingRequestRepository.isActiveBookingStatus(
        BookingRequestStatus.confirmed,
      ),
      isTrue,
    );
    expect(
      BookingRequestRepository.isActiveBookingStatus(
        BookingRequestStatus.ownerRejected,
      ),
      isFalse,
    );
  });

  test(
    'inactive historical requests get a fresh document id instead of reusing stale data',
    () {
      final staleId = BookingRequestRepository.buildRequestDocumentId(
        baseRequest,
        existingStatus: BookingRequestStatus.ownerRejected,
        referenceTime: DateTime(2026, 2, 1, 10, 0, 0),
      );

      final activeId = BookingRequestRepository.buildRequestDocumentId(
        baseRequest,
        existingStatus: BookingRequestStatus.pendingOwner,
        referenceTime: DateTime(2026, 2, 1, 10, 0, 0),
      );

      expect(staleId, isNot(equals(activeId)));
      expect(staleId.length, greaterThan(activeId.length));
      expect(staleId, contains('-'));
    },
  );
}
