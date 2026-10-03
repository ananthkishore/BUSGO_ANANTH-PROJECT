import 'package:cloud_firestore/cloud_firestore.dart';

class NotificationModel {
  const NotificationModel({
    required this.id,
    required this.recipientId,
    required this.type,
    required this.title,
    required this.message,
    this.relatedBookingId,
    this.relatedBusId,
    this.relatedOwnerId,
    this.relatedBusName,
    this.relatedRegistrationNumber,
    this.relatedOwnerName,
    this.deletedAt,
    required this.isRead,
    required this.createdAt,
  });

  final String id;
  final String recipientId;
  final String type;
  final String title;
  final String message;
  final String? relatedBookingId;
  final String? relatedBusId;
  final String? relatedOwnerId;
  final String? relatedBusName;
  final String? relatedRegistrationNumber;
  final String? relatedOwnerName;
  final DateTime? deletedAt;
  final bool isRead;
  final DateTime createdAt;

  String? get busIdForNavigation {
    final structuredBusId = relatedBusId?.trim();
    if (structuredBusId != null && structuredBusId.isNotEmpty) {
      return structuredBusId;
    }

    final suffix = switch (type) {
      'bus_approved' => '_status_approved_$recipientId',
      'bus_rejected' => '_status_rejected_$recipientId',
      'bus_update_submitted' => '_update_$recipientId',
      'bus_update_approved' => '_bus_update_approved_$recipientId',
      'bus_update_rejected' => '_bus_update_rejected_$recipientId',
      _ => null,
    };
    if (suffix == null || recipientId.isEmpty) return null;
    if (!id.endsWith(suffix)) return null;
    final legacyBusId = id.substring(0, id.length - suffix.length).trim();
    return legacyBusId.isEmpty ? null : legacyBusId;
  }

  static String? resolveRelatedId(
    Map<String, dynamic> data,
    List<String> candidateKeys,
  ) {
    for (final key in candidateKeys) {
      final value = data[key];
      if (value is String && value.trim().isNotEmpty) {
        return value.trim();
      }
    }

    final nestedCandidates = <Object?>[data['data'], data['payload']];
    for (final candidate in nestedCandidates) {
      if (candidate is! Map) continue;
      final nested = Map<String, dynamic>.from(candidate);
      for (final key in candidateKeys) {
        final value = nested[key];
        if (value is String && value.trim().isNotEmpty) {
          return value.trim();
        }
      }
    }

    return null;
  }

  factory NotificationModel.fromFirestore(
    DocumentSnapshot<Map<String, dynamic>> snapshot,
  ) {
    final data = snapshot.data() ?? <String, dynamic>{};
    final relatedBookingId = resolveRelatedId(data, const [
      'relatedBookingId',
      'bookingId',
      'requestId',
      'booking_request_id',
    ]);
    final relatedBusId = resolveRelatedId(data, const [
      'relatedBusId',
      'busId',
      'bus_id',
    ]);
    return NotificationModel(
      id: snapshot.id,
      recipientId: data['recipientId'] as String? ?? '',
      type: data['type'] as String? ?? 'general',
      title: data['title'] as String? ?? 'BUSGO update',
      message: data['message'] as String? ?? '',
      relatedBookingId: relatedBookingId,
      relatedBusId: relatedBusId,
      relatedOwnerId: resolveRelatedId(data, const [
        'ownerId',
        'relatedOwnerId',
      ]),
      relatedBusName: data['busName'] as String?,
      relatedRegistrationNumber: data['registrationNumber'] as String?,
      relatedOwnerName: data['ownerName'] as String?,
      deletedAt: (data['deletedAt'] as Timestamp?)?.toDate(),
      isRead: data['isRead'] as bool? ?? false,
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toFirestore() => {
    'recipientId': recipientId,
    'type': type,
    'title': title,
    'message': message,
    'relatedBookingId': relatedBookingId,
    'relatedBusId': relatedBusId,
    'ownerId': relatedOwnerId,
    'busName': relatedBusName,
    'registrationNumber': relatedRegistrationNumber,
    'ownerName': relatedOwnerName,
    'deletedAt': deletedAt == null ? null : Timestamp.fromDate(deletedAt!),
    'isRead': isRead,
    'createdAt': FieldValue.serverTimestamp(),
  };
}
