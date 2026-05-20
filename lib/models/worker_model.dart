import 'package:cloud_firestore/cloud_firestore.dart';

class WorkerModel {
  final String uid;
  final String name;
  final String email;
  final String storeId;
  final bool isActive;
  final bool firstLogin;
  final Map<String, bool> permissions;
  final DateTime createdAt;
  final String createdBy; // owner uid

  WorkerModel({
    required this.uid,
    required this.name,
    required this.email,
    required this.storeId,
    this.isActive = true,
    this.firstLogin = true,
    required this.permissions,
    required this.createdAt,
    required this.createdBy,
  });

  bool get canUpdateOrderStatus => permissions['canUpdateOrderStatus'] ?? false;
  bool get canConfirmPayments => permissions['canConfirmPayments'] ?? false;
  bool get canViewInventory => permissions['canViewInventory'] ?? false;
  bool get canUsePOS => permissions['canUsePOS'] ?? false;
  // canProcessSales removed — canonical name is canUsePOS everywhere.
  int get activePermissionCount => permissions.values.where((v) => v).length;

  /// Ensures legacy permission documents that pre-date a given permission key
  /// are backfilled with a safe [false] default rather than omitting the key
  /// entirely. Called from [fromMap] on every deserialization.
  static const Map<String, bool> _knownPermissions = {
    'canUpdateOrderStatus': false,
    'canConfirmPayments': false,
    'canViewInventory': false,
    'canUsePOS': false,
  };

  static Map<String, bool> _migratePermissions(Map<String, dynamic> raw) {
    // Start with all known keys defaulted to false.
    final result = Map<String, bool>.from(_knownPermissions);
    // Overwrite with whatever is actually stored in Firestore.
    raw.forEach((key, value) {
      if (value is bool) result[key] = value;
    });
    return result;
  }

  factory WorkerModel.fromMap(Map<String, dynamic> map, String id) {
    DateTime parsedDate;
    final raw = map['createdAt'];
    if (raw is int) {
      parsedDate = DateTime.fromMillisecondsSinceEpoch(raw);
    } else if (raw is DateTime) {
      parsedDate = raw;
    } else if (raw is Timestamp) {
      parsedDate = raw.toDate();
    } else {
      parsedDate = DateTime.now();
    }

    return WorkerModel(
      uid: id,
      name: map['name'] ?? '',
      email: map['email'] ?? '',
      storeId: map['storeId'] ?? '',
      isActive: map['isActive'] ?? true,
      firstLogin: map['firstLogin'] ?? true,
      permissions: map['permissions'] != null
          ? _migratePermissions(Map<String, dynamic>.from(map['permissions']))
          : {
              'canUpdateOrderStatus': false,
              'canConfirmPayments': false,
              'canViewInventory': false,
              'canUsePOS': false,
            },
      createdAt: parsedDate,
      createdBy: map['createdBy'] ?? '',
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'uid': uid,
      'name': name,
      'email': email,
      'storeId': storeId,
      'isActive': isActive,
      'firstLogin': firstLogin,
      'permissions': permissions,
      'createdAt': createdAt.millisecondsSinceEpoch,
      'createdBy': createdBy,
    };
  }

  WorkerModel copyWith({
    String? uid,
    String? name,
    String? email,
    String? storeId,
    bool? isActive,
    bool? firstLogin,
    Map<String, bool>? permissions,
    DateTime? createdAt,
    String? createdBy,
  }) {
    return WorkerModel(
      uid: uid ?? this.uid,
      name: name ?? this.name,
      email: email ?? this.email,
      storeId: storeId ?? this.storeId,
      isActive: isActive ?? this.isActive,
      firstLogin: firstLogin ?? this.firstLogin,
      permissions: permissions ?? this.permissions,
      createdAt: createdAt ?? this.createdAt,
      createdBy: createdBy ?? this.createdBy,
    );
  }
}
