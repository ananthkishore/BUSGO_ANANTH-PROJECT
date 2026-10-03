enum AppUserRole { customer, owner, admin }

extension AppUserRoleExtension on AppUserRole {
  String get label {
    switch (this) {
      case AppUserRole.customer:
        return 'Customer';
      case AppUserRole.owner:
        return 'Bus Owner';
      case AppUserRole.admin:
        return 'Admin';
    }
  }

  String get value {
    switch (this) {
      case AppUserRole.customer:
        return 'customer';
      case AppUserRole.owner:
        return 'owner';
      case AppUserRole.admin:
        return 'admin';
    }
  }

  static AppUserRole fromString(String? value) {
    switch (value?.trim().toLowerCase()) {
      case 'owner':
        return AppUserRole.owner;
      case 'admin':
        return AppUserRole.admin;
      case 'customer':
        return AppUserRole.customer;
      default:
        throw FormatException('Invalid BUSGO role: $value');
    }
  }

  static AppUserRole fromFirestoreMap(Map<String, dynamic>? data) {
    if (data == null || data.isEmpty) {
      throw const FormatException('Invalid BUSGO role in Firestore: null');
    }

    final rawRoleCandidates = [
      data['role'],
      data['userType'],
      data['type'],
      data['accountType'],
      data['admin'],
      data['owner'],
      data['customer'],
    ];

    for (final candidate in rawRoleCandidates) {
      if (candidate is String) {
        final normalized = candidate.trim().toLowerCase();
        if (normalized == 'admin' || normalized == 'administrator') {
          return AppUserRole.admin;
        }
        if (normalized == 'owner') {
          return AppUserRole.owner;
        }
        if (normalized == 'customer' || normalized == 'traveler') {
          return AppUserRole.customer;
        }
        if (normalized.contains('admin')) {
          return AppUserRole.admin;
        }
      }

      if (candidate is bool && candidate) {
        final key = rawRoleCandidates.indexOf(candidate) == 4
            ? 'admin'
            : rawRoleCandidates.indexOf(candidate) == 5
            ? 'owner'
            : 'customer';
        switch (key) {
          case 'admin':
            return AppUserRole.admin;
          case 'owner':
            return AppUserRole.owner;
          case 'customer':
            return AppUserRole.customer;
        }
      }
    }

    final roleString = data['role'] is String ? data['role'] as String : null;
    if (roleString != null) {
      return AppUserRoleExtension.fromString(roleString);
    }

    throw FormatException('Invalid BUSGO role in Firestore: $data');
  }
}
