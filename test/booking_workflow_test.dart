import 'package:flutter/material.dart';
import 'package:flutter_application_12/core/constants/booking_status.dart';
import 'package:flutter_application_12/core/constants/payment_status.dart';
import 'package:flutter_application_12/features/customer/trip_details_screen.dart';
import 'package:flutter_application_12/models/booking_request_model.dart';
import 'package:flutter_application_12/repositories/booking_request_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

void main() {
  test('whole-bus date ranges detect overlapping bookings', () {
    expect(
      bookingDatesOverlap(
        existingStart: DateTime(2026, 9, 20),
        existingEnd: DateTime(2026, 9, 22),
        requestedStart: DateTime(2026, 9, 21),
        requestedEnd: DateTime(2026, 9, 23),
      ),
      isTrue,
    );
    expect(
      bookingDatesOverlap(
        existingStart: DateTime(2026, 9, 20),
        existingEnd: DateTime(2026, 9, 22),
        requestedStart: DateTime(2026, 9, 22),
        requestedEnd: DateTime(2026, 9, 24),
      ),
      isFalse,
    );
  });

  test('owner trip categories use local calendar dates', () {
    final sameDay = BookingRequestModel(
      id: 'same-day',
      customerId: 'customer',
      ownerId: 'owner',
      busId: 'bus',
      pickup: 'Kinnathukadavu',
      destination: 'Pattukkottai',
      startDate: DateTime(2026, 9, 23, 0, 30),
      endDate: DateTime(2026, 9, 23, 23, 30),
      passengerCount: 50,
      tripType: 'School Trip',
      specialRequirements: '',
      estimatedAmount: 500,
      status: BookingRequestStatus.confirmed,
      paymentStatus: PaymentStatus.paid,
      createdAt: DateTime(2026, 9, 1),
      updatedAt: DateTime(2026, 9, 1),
    );
    final future = sameDay.copyWith(
      id: 'future',
      startDate: DateTime(2026, 9, 24),
      endDate: DateTime(2026, 9, 24),
    );
    final multiDay = sameDay.copyWith(
      id: 'multi-day',
      startDate: DateTime(2026, 9, 24),
      endDate: DateTime(2026, 9, 26),
    );

    expect(
      BookingRequestRepository.classifyTripByDate(
        sameDay,
        referenceDate: DateTime(2026, 9, 23, 23, 59),
      ),
      BookingTripCategory.ongoing,
    );
    expect(
      BookingRequestRepository.classifyTripByDate(
        sameDay,
        referenceDate: DateTime(2026, 9, 24),
      ),
      BookingTripCategory.completed,
    );
    expect(
      BookingRequestRepository.classifyTripByDate(
        future,
        referenceDate: DateTime(2026, 9, 23),
      ),
      BookingTripCategory.upcoming,
    );
    expect(
      BookingRequestRepository.classifyTripByDate(
        multiDay,
        referenceDate: DateTime(2026, 9, 25),
      ),
      BookingTripCategory.ongoing,
    );
    expect(
      BookingRequestRepository.classifyTripByDate(
        multiDay,
        referenceDate: DateTime(2026, 9, 27),
      ),
      BookingTripCategory.completed,
    );
    expect(
      BookingRequestRepository.classifyTripByDate(
        sameDay.copyWith(paymentStatus: PaymentStatus.submitted),
        referenceDate: DateTime(2026, 9, 23),
      ),
      BookingTripCategory.ineligible,
    );
  });

  test('owner acceptance and admin review are distinct workflow stages', () {
    expect(
      canTransitionBookingStatus(
        BookingRequestStatus.pendingOwner,
        BookingRequestStatus.ownerAccepted,
      ),
      isTrue,
    );
    expect(
      canTransitionBookingStatus(
        BookingRequestStatus.ownerAccepted,
        BookingRequestStatus.adminReview,
      ),
      isTrue,
    );
    expect(
      canTransitionBookingStatus(
        BookingRequestStatus.ownerAccepted,
        BookingRequestStatus.paymentRequired,
      ),
      isTrue,
    );
    expect(
      canTransitionBookingStatus(
        BookingRequestStatus.ownerAccepted,
        BookingRequestStatus.adminRejected,
      ),
      isTrue,
    );
    expect(
      canTransitionBookingStatus(
        BookingRequestStatus.adminReview,
        BookingRequestStatus.paymentRequired,
      ),
      isTrue,
    );
    expect(
      canTransitionBookingStatus(
        BookingRequestStatus.paymentRequired,
        BookingRequestStatus.confirmed,
      ),
      isTrue,
    );
    expect(
      canTransitionBookingStatus(
        BookingRequestStatus.ownerAccepted,
        BookingRequestStatus.confirmed,
      ),
      isFalse,
    );
    expect(
      canTransitionBookingStatus(
        BookingRequestStatus.adminReview,
        BookingRequestStatus.confirmed,
      ),
      isFalse,
    );
    expect(
      canTransitionBookingStatus(
        BookingRequestStatus.pendingOwner,
        BookingRequestStatus.confirmed,
      ),
      isFalse,
    );
  });

  test(
    'newer booking requests sort first without requiring composite Firestore index',
    () {
      final older = BookingRequestModel(
        id: 'older',
        customerId: 'customer-a',
        ownerId: 'owner-a',
        busId: 'bus-a',
        pickup: 'Center',
        destination: 'Airport',
        startDate: DateTime(2026, 9, 20),
        endDate: DateTime(2026, 9, 21),
        passengerCount: 12,
        tripType: 'Corporate Trip',
        specialRequirements: '',
        estimatedAmount: 4200,
        status: BookingRequestStatus.pendingOwner,
        createdAt: DateTime(2026, 9, 1, 8),
        updatedAt: DateTime(2026, 9, 1, 8),
      );

      final newer = BookingRequestModel(
        id: 'newer',
        customerId: 'customer-a',
        ownerId: 'owner-a',
        busId: 'bus-a',
        pickup: 'Center',
        destination: 'Airport',
        startDate: DateTime(2026, 9, 22),
        endDate: DateTime(2026, 9, 23),
        passengerCount: 12,
        tripType: 'Corporate Trip',
        specialRequirements: '',
        estimatedAmount: 4200,
        status: BookingRequestStatus.pendingOwner,
        createdAt: DateTime(2026, 9, 10, 15),
        updatedAt: DateTime(2026, 9, 10, 15),
      );

      final sorted = sortBookingRequestsByNewestFirst([older, newer]);
      expect(sorted.first.id, 'newer');
      expect(sorted.last.id, 'older');
    },
  );

  test('payment status values round-trip from Firestore strings', () {
    expect(PaymentStatus.requested.value, 'REQUESTED');
    expect(
      PaymentStatusExtension.fromString('SUBMITTED'),
      PaymentStatus.submitted,
    );
    expect(PaymentStatusExtension.fromString(null), PaymentStatus.notRequested);
  });

  test(
    'confirmed bookings must auto-complete once the trip end date is reached',
    () {
      final request = BookingRequestModel(
        id: 'booking-2',
        customerId: 'customer-2',
        ownerId: 'owner-2',
        busId: 'bus-2',
        pickup: 'Coimbatore',
        destination: 'Pattukkottai',
        startDate: DateTime(2026, 9, 24),
        endDate: DateTime(2026, 9, 25, 18),
        passengerCount: 69,
        tripType: 'School Trip',
        specialRequirements: '',
        estimatedAmount: 1000,
        status: BookingRequestStatus.confirmed,
        paymentStatus: PaymentStatus.paid,
        createdAt: DateTime(2026, 9, 1),
        updatedAt: DateTime(2026, 9, 23),
      );

      expect(
        BookingRequestRepository.shouldCompleteTrip(
          request,
          now: DateTime(2026, 9, 26),
        ),
        isTrue,
      );
      expect(
        BookingRequestRepository.shouldCompleteTrip(
          request,
          now: DateTime(2026, 9, 25, 12),
        ),
        isFalse,
      );
      expect(
        BookingRequestRepository.shouldCompleteTrip(
          request.copyWith(endDate: DateTime(2026, 9, 23)),
          now: DateTime(2026, 9, 23, 23, 59, 59),
        ),
        isFalse,
      );
      expect(
        BookingRequestRepository.shouldCompleteTrip(
          request.copyWith(endDate: DateTime(2026, 9, 23)),
          now: DateTime(2026, 9, 24, 0, 0, 0),
        ),
        isTrue,
      );
    },
  );

  test('reviews are stored on the same booking and cannot be duplicated', () {
    final request = BookingRequestModel(
      id: 'booking-review',
      customerId: 'customer-3',
      ownerId: 'owner-3',
      busId: 'bus-3',
      pickup: 'Town',
      destination: 'Temple',
      startDate: DateTime(2026, 9, 24),
      endDate: DateTime(2026, 9, 25),
      passengerCount: 8,
      tripType: 'Family Trip',
      specialRequirements: '',
      estimatedAmount: 3000,
      status: BookingRequestStatus.completed,
      paymentStatus: PaymentStatus.paid,
      createdAt: DateTime(2026, 9, 1),
      updatedAt: DateTime(2026, 9, 26),
    );

    expect(request.hasSubmittedReview, isFalse);

    final reviewed = request.copyWith(
      reviewRating: 5,
      reviewFeedback: 'Excellent trip',
      reviewSubmittedAt: DateTime(2026, 9, 26, 19),
    );

    expect(reviewed.hasSubmittedReview, isTrue);
    expect(reviewed.reviewRating, 5);
    expect(reviewed.reviewFeedback, 'Excellent trip');
  });

  testWidgets(
    'customer trip details hides pay now when payment is already submitted',
    (tester) async {
      final request = BookingRequestModel(
        id: 'booking-1',
        customerId: 'customer-1',
        ownerId: 'owner-1',
        busId: 'bus-1',
        pickup: 'City Center',
        destination: 'Airport',
        startDate: DateTime(2026, 9, 20),
        endDate: DateTime(2026, 9, 22),
        passengerCount: 12,
        tripType: 'College Tour',
        specialRequirements: '',
        estimatedAmount: 2500,
        status: BookingRequestStatus.paymentRequired,
        paymentStatus: PaymentStatus.submitted,
        createdAt: DateTime(2026, 9, 1),
        updatedAt: DateTime(2026, 9, 10),
      );

      await tester.pumpWidget(
        Provider<BookingRequestRepository>(
          create: (_) => BookingRequestRepository(),
          child: MaterialApp(home: TripDetailsScreen(request: request)),
        ),
      );
      await tester.pump();
      await tester.pumpAndSettle();

      expect(find.text('Pay Now'), findsNothing);
    },
  );
}
