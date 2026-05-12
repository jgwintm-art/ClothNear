import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/user_model.dart';
import '../firebase_options.dart';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // ─── CURRENT USER ───────────────────────────────────────────────────────────

  User? get currentUser => _auth.currentUser;

  Future<UserModel?> getCurrentUserModel() async {
    final user = _auth.currentUser;
    if (user == null) return null;
    final doc = await _firestore.collection('users').doc(user.uid).get();
    if (!doc.exists) return null;
    return UserModel.fromMap(doc.data()!);
  }

  // ─── LOGIN ───────────────────────────────────────────────────────────────────

  Future<UserModel?> login(String email, String password) async {
    final credential = await _auth.signInWithEmailAndPassword(
      email: email.trim(),
      password: password.trim(),
    );
    final uid = credential.user!.uid;
    final doc = await _firestore.collection('users').doc(uid).get();
    if (!doc.exists) return null;
    return UserModel.fromMap(doc.data()!);
  }

  // ─── REGISTER (customers and owners only) ────────────────────────────────────

  Future<UserModel?> register(
    String name,
    String email,
    String password,
    String role,
  ) async {
    final credential = await _auth.createUserWithEmailAndPassword(
      email: email.trim(),
      password: password.trim(),
    );
    final uid = credential.user!.uid;
    final userModel = UserModel(
      uid: uid,
      name: name.trim(),
      email: email.trim(),
      role: role,
      isActive: true,
      firstLogin: false,
    );
    await _firestore.collection('users').doc(uid).set(userModel.toMap());
    return userModel;
  }

  // ─── CREATE WORKER ACCOUNT (Secondary FirebaseApp pattern) ──────────────────
  // Creates a Firebase Auth account for the worker WITHOUT logging out the owner.

  Future<UserModel?> createWorkerAccount({
    required String name,
    required String email,
    required String tempPassword,
    required String storeId,
    required String ownerUid,
    required Map<String, bool> permissions,
  }) async {
    // Step 1: Initialize a secondary, isolated Firebase app instance
    FirebaseApp? secondaryApp;
    try {
      secondaryApp = await Firebase.initializeApp(
        name: 'workerCreation_${DateTime.now().millisecondsSinceEpoch}',
        options: DefaultFirebaseOptions.currentPlatform,
      );

      // Step 2: Get a secondary auth instance — completely isolated from the owner's session
      final secondaryAuth = FirebaseAuth.instanceFor(app: secondaryApp);

      // Step 3: Create the worker's Firebase Auth account
      final credential = await secondaryAuth.createUserWithEmailAndPassword(
        email: email.trim(),
        password: tempPassword.trim(),
      );
      final workerUid = credential.user!.uid;

      // Step 4: Sign out of the secondary app immediately — we only needed the uid
      await secondaryAuth.signOut();

      // Step 5: Write the worker's user document to Firestore
      final workerUserModel = UserModel(
        uid: workerUid,
        name: name.trim(),
        email: email.trim(),
        role: 'worker',
        storeId: storeId,
        isActive: true,
        firstLogin: true, // forces password change on first login
        permissions: permissions,
      );
      await _firestore
          .collection('users')
          .doc(workerUid)
          .set(workerUserModel.toMap());

      // Step 6: Write to the store's workers subcollection for easy store-scoped queries
      await _firestore
          .collection('stores')
          .doc(storeId)
          .collection('workers')
          .doc(workerUid)
          .set({
            'uid': workerUid,
            'name': name.trim(),
            'email': email.trim(),
            'storeId': storeId,
            'isActive': true,
            'firstLogin': true,
            'permissions': permissions,
            'createdAt': DateTime.now().millisecondsSinceEpoch,
            'createdBy': ownerUid,
          });

      return workerUserModel;
    } finally {
      // Step 7: Always delete the secondary app to free resources
      await secondaryApp?.delete();
    }
  }

  // ─── SET PASSWORD (used by worker on first login) ────────────────────────────

  Future<void> setNewPassword(String newPassword) async {
    final user = _auth.currentUser;
    if (user == null) throw Exception('No user is currently logged in.');
    await user.updatePassword(newPassword);
  }

  // ─── MARK FIRST LOGIN COMPLETE ───────────────────────────────────────────────

  Future<void> completeFirstLogin(String uid, String storeId) async {
    // Update /users/{uid}
    await _firestore.collection('users').doc(uid).update({'firstLogin': false});
    // Update /stores/{storeId}/workers/{uid}
    await _firestore
        .collection('stores')
        .doc(storeId)
        .collection('workers')
        .doc(uid)
        .update({'firstLogin': false});
  }

  // ─── LOGOUT ──────────────────────────────────────────────────────────────────

  Future<void> logout() async {
    await _auth.signOut();
  }
}
