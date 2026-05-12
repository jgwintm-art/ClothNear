class UserModel {
  final String uid;
  final String name;
  final String email;
  final String role; // 'customer', 'owner', 'worker'
  final String? storeId; // set for owner and worker
  final bool isActive; // owner can deactivate worker
  final bool firstLogin; // true = worker must set password before dashboard
  final Map<String, bool> permissions; // worker permission toggles

  UserModel({
    required this.uid,
    required this.name,
    required this.email,
    required this.role,
    this.storeId,
    this.isActive = true,
    this.firstLogin = false,
    this.permissions = const {},
  });

  static Map<String, bool> get defaultWorkerPermissions => {
    'canUpdateOrderStatus': false,
    'canConfirmPayments': false,
    'canViewInventory': false,
  };

  factory UserModel.fromMap(Map<String, dynamic> map) {
    return UserModel(
      uid: map['uid'] ?? '',
      name: map['name'] ?? '',
      email: map['email'] ?? '',
      role: map['role'] ?? 'customer',
      storeId: map['storeId'],
      isActive: map['isActive'] ?? true,
      firstLogin: map['firstLogin'] ?? false,
      permissions: map['permissions'] != null
          ? Map<String, bool>.from(map['permissions'])
          : {},
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'uid': uid,
      'name': name,
      'email': email,
      'role': role,
      'storeId': storeId,
      'isActive': isActive,
      'firstLogin': firstLogin,
      'permissions': permissions,
    };
  }

  UserModel copyWith({
    String? uid,
    String? name,
    String? email,
    String? role,
    String? storeId,
    bool? isActive,
    bool? firstLogin,
    Map<String, bool>? permissions,
  }) {
    return UserModel(
      uid: uid ?? this.uid,
      name: name ?? this.name,
      email: email ?? this.email,
      role: role ?? this.role,
      storeId: storeId ?? this.storeId,
      isActive: isActive ?? this.isActive,
      firstLogin: firstLogin ?? this.firstLogin,
      permissions: permissions ?? this.permissions,
    );
  }
}
