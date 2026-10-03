enum PaymentStatus { notRequested, requested, submitted, paid, rejected }

extension PaymentStatusExtension on PaymentStatus {
  String get value {
    switch (this) {
      case PaymentStatus.notRequested:
        return 'NOT_REQUESTED';
      case PaymentStatus.requested:
        return 'REQUESTED';
      case PaymentStatus.submitted:
        return 'SUBMITTED';
      case PaymentStatus.paid:
        return 'PAID';
      case PaymentStatus.rejected:
        return 'REJECTED';
    }
  }

  String get label {
    switch (this) {
      case PaymentStatus.notRequested:
        return 'Payment not requested';
      case PaymentStatus.requested:
        return 'Payment requested';
      case PaymentStatus.submitted:
        return 'Payment submitted';
      case PaymentStatus.paid:
        return 'Payment paid';
      case PaymentStatus.rejected:
        return 'Payment needs attention';
    }
  }

  static PaymentStatus fromString(String? value) =>
      PaymentStatus.values.firstWhere(
        (status) => status.value == value,
        orElse: () => PaymentStatus.notRequested,
      );
}
