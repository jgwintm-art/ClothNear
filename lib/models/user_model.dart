class UserModel {
  final String uid;
  final String name;
  final String email;
  final String role; // 'customer', 'owner', 'worker'

  UserModel({
    required this.uid,
    required this.name,
    required this.email,
    required this.role,
  });

  // Convert Firestore data to UserModel
  factory UserModel.fromMap(Map<String, dynamic> map) {
    return UserModel(
      uid: map['uid'] ?? '',
      name: map['name'] ?? '',
      email: map['email'] ?? '',
      role: map['role'] ?? 'customer',
    );
  }

  // Convert UserModel to Firestore data
  Map<String, dynamic> toMap() {
    return {'uid': uid, 'name': name, 'email': email, 'role': role};
  }
}
