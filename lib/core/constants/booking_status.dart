enum BookingRequestStatus {
  pendingOwner,
  ownerAccepted,
  ownerRejected,
  adminReview,
  adminRejected,
  confirmed,
  paymentRequired,
  cancelled,
  completed,
}

extension BookingRequestStatusExtension on BookingRequestStatus {
  String get value {
    switch (this) {
      case BookingRequestStatus.pendingOwner:
        return 'PENDING_OWNER';
      case BookingRequestStatus.ownerAccepted:
        return 'OWNER_ACCEPTED';
      case BookingRequestStatus.ownerRejected:
        return 'OWNER_REJECTED';
      case BookingRequestStatus.adminReview:
        return 'ADMIN_REVIEW';
      case BookingRequestStatus.adminRejected:
        return 'ADMIN_REJECTED';
      case BookingRequestStatus.confirmed:
        return 'CONFIRMED';
      case BookingRequestStatus.paymentRequired:
        return 'PAYMENT_REQUIRED';
      case BookingRequestStatus.cancelled:
        return 'CANCELLED';
      case BookingRequestStatus.completed:
        return 'COMPLETED';
    }
  }

  String get label {
    switch (this) {
      case BookingRequestStatus.pendingOwner:
        return 'Owner Pending';
      case BookingRequestStatus.ownerAccepted:
        return 'Owner Accepted';
      case BookingRequestStatus.ownerRejected:
        return 'Owner Rejected';
      case BookingRequestStatus.adminReview:
        return 'Admin Review';
      case BookingRequestStatus.adminRejected:
        return 'Admin Rejected';
      case BookingRequestStatus.confirmed:
        return 'Confirmed';
      case BookingRequestStatus.paymentRequired:
        return 'Payment Required';
      case BookingRequestStatus.cancelled:
        return 'Cancelled';
      case BookingRequestStatus.completed:
        return 'Completed';
    }
  }

  static BookingRequestStatus fromString(String? value) {
    return BookingRequestStatus.values.firstWhere(
      (status) => status.value == value,
      orElse: () => BookingRequestStatus.pendingOwner,
    );
  }
}

bool canTransitionBookingStatus(
  BookingRequestStatus from,
  BookingRequestStatus to,
) {
  switch (from) {
    case BookingRequestStatus.pendingOwner:
      return to == BookingRequestStatus.ownerAccepted ||
          to == BookingRequestStatus.ownerRejected;
    case BookingRequestStatus.ownerAccepted:
      return to == BookingRequestStatus.adminReview ||
          to == BookingRequestStatus.paymentRequired ||
          to == BookingRequestStatus.adminRejected;
    case BookingRequestStatus.adminReview:
      return to == BookingRequestStatus.paymentRequired ||
          to == BookingRequestStatus.adminRejected;
    case BookingRequestStatus.paymentRequired:
      return to == BookingRequestStatus.confirmed ||
          to == BookingRequestStatus.completed ||
          to == BookingRequestStatus.cancelled;
    case BookingRequestStatus.confirmed:
      return to == BookingRequestStatus.completed ||
          to == BookingRequestStatus.cancelled;
    case BookingRequestStatus.ownerRejected:
    case BookingRequestStatus.adminRejected:
    case BookingRequestStatus.cancelled:
    case BookingRequestStatus.completed:
      return false;
  }
}

bool bookingDatesOverlap({
  required DateTime existingStart,
  required DateTime existingEnd,
  required DateTime requestedStart,
  required DateTime requestedEnd,
}) =>
    existingStart.isBefore(requestedEnd) && existingEnd.isAfter(requestedStart);
