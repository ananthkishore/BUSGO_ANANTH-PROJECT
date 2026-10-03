import 'package:cloud_firestore/cloud_firestore.dart';

class BusModel {
  const BusModel({
    required this.id,
    required this.ownerId,
    required this.name,
    required this.busType,
    required this.capacity,
    required this.isAc,
    required this.serviceLocation,
    this.tripTypes = const [],
    this.pickupLocation,
    this.destination,
    this.registrationNumber = '',
    this.amenities = const [],
    this.serviceLocations = const [],
    this.description = '',
    this.status = 'pending_approval',
    this.createdAt,
    this.updatedAt,
    this.imageUrl,
    this.rating,
    this.estimatedPricePerDay,
    this.pendingUpdate,
    this.pendingUpdateStatus,
    this.pendingUpdateReason,
    this.pendingUpdateSubmittedAt,
  });

  final String id;
  final String ownerId;
  final String name;
  final String busType;
  final int capacity;
  final bool isAc;
  final String serviceLocation;
  final List<String> tripTypes;
  final String? pickupLocation;
  final String? destination;
  final String registrationNumber;
  final List<String> amenities;
  final List<String> serviceLocations;
  final String description;
  final String status;
  final DateTime? createdAt;
  final DateTime? updatedAt;
  final String? imageUrl;
  final double? rating;
  final double? estimatedPricePerDay;
  final Map<String, dynamic>? pendingUpdate;
  final String? pendingUpdateStatus;
  final String? pendingUpdateReason;
  final DateTime? pendingUpdateSubmittedAt;

  bool get hasPendingUpdate => pendingUpdateStatus == 'pending_approval';
  bool get hasRejectedUpdate => pendingUpdateStatus == 'rejected';

  factory BusModel.fromFirestore(
    DocumentSnapshot<Map<String, dynamic>> snapshot,
  ) {
    final data = snapshot.data() ?? <String, dynamic>{};
    final serviceLocations = _stringList(data['serviceLocations']);
    return BusModel(
      id: snapshot.id,
      ownerId: _stringValue(data['ownerId']),
      name: _stringValue(data['name']).isNotEmpty
          ? _stringValue(data['name'])
          : (_stringValue(data['busName']).isNotEmpty
                ? _stringValue(data['busName'])
                : 'BUSGO bus'),
      busType: _stringValue(data['busType'], fallback: 'Whole bus'),
      capacity: (data['capacity'] as num?)?.toInt() ?? 0,
      isAc: data['isAc'] is bool
          ? data['isAc'] as bool
          : data['ac'] is bool && data['ac'] as bool,
      serviceLocation: _stringValue(data['serviceLocation']).isNotEmpty
          ? _stringValue(data['serviceLocation'])
          : serviceLocations.firstOrNull ?? '',
      tripTypes: _stringList(data['tripTypes']),
      pickupLocation: _nullableString(data['pickupLocation']),
      destination: _nullableString(data['destination']),
      registrationNumber: _stringValue(data['registrationNumber']),
      amenities: _stringList(data['amenities']),
      serviceLocations: serviceLocations,
      description: _stringValue(data['description']),
      status: _stringValue(data['status'], fallback: 'pending_approval'),
      createdAt: _dateValue(data['createdAt']),
      updatedAt: _dateValue(data['updatedAt']),
      imageUrl: _nullableString(data['imageUrl']),
      rating: (data['rating'] as num?)?.toDouble(),
      estimatedPricePerDay:
          (data['estimatedPricePerDay'] as num?)?.toDouble() ??
          (data['pricePerDay'] as num?)?.toDouble(),
      pendingUpdate: data['pendingUpdate'] is Map
          ? Map<String, dynamic>.from(data['pendingUpdate'] as Map)
          : null,
      pendingUpdateStatus: _nullableString(data['pendingUpdateStatus']),
      pendingUpdateReason: _nullableString(data['pendingUpdateReason']),
      pendingUpdateSubmittedAt: _dateValue(data['pendingUpdateSubmittedAt']),
    );
  }

  static String _stringValue(Object? value, {String fallback = ''}) =>
      value is String ? value : fallback;

  static String? _nullableString(Object? value) =>
      value is String ? value : null;

  static List<String> _stringList(Object? value) =>
      value is List ? value.whereType<String>().toList() : const [];

  static DateTime? _dateValue(Object? value) => value is Timestamp
      ? value.toDate()
      : value is DateTime
      ? value
      : null;

  Map<String, dynamic> toFirestore() => {
    'ownerId': ownerId,
    'name': name,
    'busName': name,
    'busType': busType,
    'capacity': capacity,
    'isAc': isAc,
    'ac': isAc,
    'serviceLocation': serviceLocation,
    'tripTypes': tripTypes,
    'pickupLocation': pickupLocation ?? serviceLocation,
    'destination': destination,
    'serviceLocations': serviceLocations.isEmpty
        ? [serviceLocation]
        : serviceLocations,
    'registrationNumber': registrationNumber,
    'amenities': amenities,
    'description': description,
    'status': status,
    'imageUrl': imageUrl,
    'rating': rating,
    'estimatedPricePerDay': estimatedPricePerDay,
    'pricePerDay': estimatedPricePerDay,
    'createdAt': createdAt == null
        ? FieldValue.serverTimestamp()
        : Timestamp.fromDate(createdAt!),
    'updatedAt': FieldValue.serverTimestamp(),
  };
}
