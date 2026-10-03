import 'package:cloud_firestore/cloud_firestore.dart';

import '../core/constants/booking_status.dart';
import '../core/constants/payment_status.dart';

List<BookingRequestModel> sortBookingRequestsByNewestFirst(
  List<BookingRequestModel> requests,
) {
  final sorted = List<BookingRequestModel>.from(requests);
  sorted.sort((a, b) {
    final left = a.updatedAt.millisecondsSinceEpoch;
    final right = b.updatedAt.millisecondsSinceEpoch;
    if (left == right) {
      return b.createdAt.compareTo(a.createdAt);
    }
    return right.compareTo(left);
  });
  return sorted;
}

class BookingRequestModel {
  const BookingRequestModel({
    required this.id,
    required this.customerId,
    this.customerName,
    required this.ownerId,
    required this.busId,
    this.busName,
    required this.pickup,
    required this.destination,
    required this.startDate,
    required this.endDate,
    required this.passengerCount,
    required this.tripType,
    required this.specialRequirements,
    required this.estimatedAmount,
    required this.status,
    this.paymentStatus = PaymentStatus.notRequested,
    this.paymentReference,
    this.paymentRequestedAt,
    this.paymentSubmittedAt,
    this.ownerDecision,
    this.adminDecision,
    this.rejectionReason,
    this.reviewRating,
    this.reviewFeedback,
    this.reviewSubmittedAt,
    required this.createdAt,
    required this.updatedAt,
  });

  final String id;
  final String customerId;
  final String? customerName;
  final String ownerId;
  final String busId;
  final String? busName;
  final String pickup;
  final String destination;
  final DateTime startDate;
  final DateTime endDate;
  final int passengerCount;
  final String tripType;
  final String specialRequirements;
  final double estimatedAmount;
  final BookingRequestStatus status;
  final PaymentStatus paymentStatus;
  final String? paymentReference;
  final DateTime? paymentRequestedAt;
  final DateTime? paymentSubmittedAt;
  final String? ownerDecision;
  final String? adminDecision;
  final String? rejectionReason;
  final int? reviewRating;
  final String? reviewFeedback;
  final DateTime? reviewSubmittedAt;
  final DateTime createdAt;
  final DateTime updatedAt;

  bool get hasSubmittedReview =>
      reviewSubmittedAt != null ||
      (reviewRating != null && reviewRating! > 0) ||
      (reviewFeedback ?? '').trim().isNotEmpty;

  factory BookingRequestModel.fromFirestore(
    DocumentSnapshot<Map<String, dynamic>> snapshot,
  ) {
    final data = snapshot.data() ?? <String, dynamic>{};
    DateTime readDate(String key) =>
        (data[key] as Timestamp?)?.toDate() ?? DateTime.now();
    DateTime? readOptionalDate(String key) =>
        (data[key] as Timestamp?)?.toDate();

    return BookingRequestModel(
      id: snapshot.id,
      customerId: data['customerId'] as String? ?? '',
      customerName: data['customerName'] as String?,
      ownerId: data['ownerId'] as String? ?? '',
      busId: data['busId'] as String? ?? '',
      busName: data['busName'] as String?,
      pickup: data['pickup'] as String? ?? '',
      destination: data['destination'] as String? ?? '',
      startDate: readDate('startDate'),
      endDate: readDate('endDate'),
      passengerCount: (data['passengerCount'] as num?)?.toInt() ?? 0,
      tripType: data['tripType'] as String? ?? 'Other',
      specialRequirements: data['specialRequirements'] as String? ?? '',
      estimatedAmount: (data['estimatedAmount'] as num?)?.toDouble() ?? 0,
      status: BookingRequestStatusExtension.fromString(
        data['status'] as String?,
      ),
      paymentStatus: PaymentStatusExtension.fromString(
        data['paymentStatus'] as String?,
      ),
      paymentReference: data['paymentReference'] as String?,
      paymentRequestedAt: readOptionalDate('paymentRequestedAt'),
      paymentSubmittedAt: readOptionalDate('paymentSubmittedAt'),
      ownerDecision: data['ownerDecision'] as String?,
      adminDecision: data['adminDecision'] as String?,
      rejectionReason: data['rejectionReason'] as String?,
      reviewRating: (data['reviewRating'] as num?)?.toInt(),
      reviewFeedback: data['reviewFeedback'] as String?,
      reviewSubmittedAt: readOptionalDate('reviewSubmittedAt'),
      createdAt: readDate('createdAt'),
      updatedAt: readDate('updatedAt'),
    );
  }

  BookingRequestModel copyWith({
    String? id,
    String? customerId,
    String? customerName,
    String? ownerId,
    String? busId,
    String? busName,
    String? pickup,
    String? destination,
    DateTime? startDate,
    DateTime? endDate,
    int? passengerCount,
    String? tripType,
    String? specialRequirements,
    double? estimatedAmount,
    BookingRequestStatus? status,
    PaymentStatus? paymentStatus,
    String? paymentReference,
    DateTime? paymentRequestedAt,
    DateTime? paymentSubmittedAt,
    String? ownerDecision,
    String? adminDecision,
    String? rejectionReason,
    int? reviewRating,
    String? reviewFeedback,
    DateTime? reviewSubmittedAt,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) => BookingRequestModel(
    id: id ?? this.id,
    customerId: customerId ?? this.customerId,
    customerName: customerName ?? this.customerName,
    ownerId: ownerId ?? this.ownerId,
    busId: busId ?? this.busId,
    busName: busName ?? this.busName,
    pickup: pickup ?? this.pickup,
    destination: destination ?? this.destination,
    startDate: startDate ?? this.startDate,
    endDate: endDate ?? this.endDate,
    passengerCount: passengerCount ?? this.passengerCount,
    tripType: tripType ?? this.tripType,
    specialRequirements: specialRequirements ?? this.specialRequirements,
    estimatedAmount: estimatedAmount ?? this.estimatedAmount,
    status: status ?? this.status,
    paymentStatus: paymentStatus ?? this.paymentStatus,
    paymentReference: paymentReference ?? this.paymentReference,
    paymentRequestedAt: paymentRequestedAt ?? this.paymentRequestedAt,
    paymentSubmittedAt: paymentSubmittedAt ?? this.paymentSubmittedAt,
    ownerDecision: ownerDecision ?? this.ownerDecision,
    adminDecision: adminDecision ?? this.adminDecision,
    rejectionReason: rejectionReason ?? this.rejectionReason,
    reviewRating: reviewRating ?? this.reviewRating,
    reviewFeedback: reviewFeedback ?? this.reviewFeedback,
    reviewSubmittedAt: reviewSubmittedAt ?? this.reviewSubmittedAt,
    createdAt: createdAt ?? this.createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
  );

  Map<String, dynamic> toFirestore() => {
    'customerId': customerId,
    'customerName': customerName,
    'ownerId': ownerId,
    'busId': busId,
    'busName': busName,
    'pickup': pickup,
    'destination': destination,
    'startDate': Timestamp.fromDate(startDate),
    'endDate': Timestamp.fromDate(endDate),
    'passengerCount': passengerCount,
    'tripType': tripType,
    'specialRequirements': specialRequirements,
    'estimatedAmount': estimatedAmount,
    'status': status.value,
    'paymentStatus': paymentStatus.value,
    'paymentReference': paymentReference,
    'paymentRequestedAt': paymentRequestedAt == null
        ? null
        : Timestamp.fromDate(paymentRequestedAt!),
    'paymentSubmittedAt': paymentSubmittedAt == null
        ? null
        : Timestamp.fromDate(paymentSubmittedAt!),
    'ownerDecision': ownerDecision,
    'adminDecision': adminDecision,
    'rejectionReason': rejectionReason,
    'reviewRating': reviewRating,
    'reviewFeedback': reviewFeedback,
    'reviewSubmittedAt': reviewSubmittedAt == null
        ? null
        : Timestamp.fromDate(reviewSubmittedAt!),
    'createdAt': FieldValue.serverTimestamp(),
    'updatedAt': FieldValue.serverTimestamp(),
  };
}
