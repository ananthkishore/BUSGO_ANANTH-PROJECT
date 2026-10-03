import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

import '../core/constants/app_roles.dart';

class AppUser {
  final String uid;
  final String name;
  final String email;
  final String? phone;
  final AppUserRole role;
  final String? approvalStatus;
  final String? profileImageUrl;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  const AppUser({
    required this.uid,
    required this.name,
    required this.email,
    this.phone,
    required this.role,
    this.approvalStatus,
    this.profileImageUrl,
    this.createdAt,
    this.updatedAt,
  });

  factory AppUser.fromFirestore(
    DocumentSnapshot<Map<String, dynamic>> snapshot,
  ) {
    final data = snapshot.data() ?? <String, dynamic>{};
    final resolvedEmail = (_stringValue(data['email']) ?? '').trim().isNotEmpty
        ? (_stringValue(data['email']) ?? '').trim()
        : ((_stringValue(data['admin']) ?? '').trim().isNotEmpty
              ? (_stringValue(data['admin']) ?? '').trim()
              : ((_stringValue(data['adminEmail']) ?? '').trim()));

    debugPrint(
      '[BUSGO ADMIN PROFILE DEBUG] uid=${snapshot.id} role=${AppUserRoleExtension.fromFirestoreMap(data).name} name=${(_stringValue(data['name']) ?? '').trim()} email=${resolvedEmail.isEmpty ? 'empty' : resolvedEmail} admin=${(_stringValue(data['admin']) ?? '').trim().isEmpty ? 'empty' : (_stringValue(data['admin']) ?? '').trim()} phone=${(_stringValue(data['phone']) ?? '').trim().isEmpty ? 'empty' : (_stringValue(data['phone']) ?? '').trim()} profileImage=${(_stringValue(data['profileImage']) ?? '').trim().isEmpty ? 'empty' : (_stringValue(data['profileImage']) ?? '').trim()} profileImageUrl=${(_stringValue(data['profileImageUrl']) ?? '').trim().isEmpty ? 'empty' : (_stringValue(data['profileImageUrl']) ?? '').trim()} createdAt=${(data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now()} updatedAt=${(data['updatedAt'] as Timestamp?)?.toDate() ?? DateTime.now()}',
    );

    return AppUser(
      uid: snapshot.id,
      name: (_stringValue(data['name']) ?? '').trim(),
      email: resolvedEmail,
      phone: _stringValue(data['phone']),
      role: AppUserRoleExtension.fromFirestoreMap(data),
      approvalStatus: _stringValue(data['approvalStatus']),
      profileImageUrl: _stringValue(
        data['profileImageUrl'] ?? data['profileImage'],
      ),
      createdAt: (data['createdAt'] as Timestamp?)?.toDate(),
      updatedAt: (data['updatedAt'] as Timestamp?)?.toDate(),
    );
  }

  static String? _stringValue(Object? value) => value?.toString();

  Map<String, dynamic> toFirestore() {
    return {
      'uid': uid,
      'name': name,
      'email': email,
      'phone': phone,
      'role': role.value,
      if (role == AppUserRole.owner)
        'approvalStatus': approvalStatus ?? 'approved',
      'profileImageUrl': profileImageUrl,
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    };
  }

  AppUser copyWith({
    String? uid,
    String? name,
    String? email,
    String? phone,
    AppUserRole? role,
    String? approvalStatus,
    String? profileImageUrl,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return AppUser(
      uid: uid ?? this.uid,
      name: name ?? this.name,
      email: email ?? this.email,
      phone: phone ?? this.phone,
      role: role ?? this.role,
      approvalStatus: approvalStatus ?? this.approvalStatus,
      profileImageUrl: profileImageUrl ?? this.profileImageUrl,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
