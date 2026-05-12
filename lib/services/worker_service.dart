import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/worker_model.dart';

class WorkerService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // ─── READ ────────────────────────────────────────────────────────────────────

  // Stream of all workers for a store (live updates).
  // NOTE: Sorting is done client-side to avoid requiring a composite Firestore
  // index for the (role + ownerUid + createdAt) combination, which was the
  // root cause of the "Failed to display Workers" error.
  Stream<List<WorkerModel>> getStoreWorkers(String ownerUid) {
    return _firestore
        .collection('users')
        .where('role', isEqualTo: 'worker')
        .where('ownerUid', isEqualTo: ownerUid)
        .snapshots()
        .map((snap) {
          final workers = snap.docs
              .map((doc) => WorkerModel.fromMap(doc.data(), doc.id))
              .toList();
          // Sort by createdAt ascending — same order as the original orderBy
          workers.sort((a, b) => a.createdAt.compareTo(b.createdAt));
          return workers;
        });
  }

  // Fetch a single worker by uid
  Future<WorkerModel?> getWorker(String storeId, String workerUid) async {
    final doc = await _firestore
        .collection('stores')
        .doc(storeId)
        .collection('workers')
        .doc(workerUid)
        .get();
    if (!doc.exists) return null;
    return WorkerModel.fromMap(doc.data()!, doc.id);
  }

  // ─── UPDATE PERMISSIONS ──────────────────────────────────────────────────────

  Future<void> updatePermissions(
    String storeId,
    String workerUid,
    Map<String, bool> permissions,
  ) async {
    // Update both documents atomically using a batch
    final batch = _firestore.batch();

    batch.update(
      _firestore
          .collection('stores')
          .doc(storeId)
          .collection('workers')
          .doc(workerUid),
      {'permissions': permissions},
    );
    batch.update(_firestore.collection('users').doc(workerUid), {
      'permissions': permissions,
    });

    await batch.commit();
  }

  // ─── TOGGLE ACTIVE STATUS ────────────────────────────────────────────────────

  Future<void> toggleWorkerActive(
    String storeId,
    String workerUid,
    bool isActive,
  ) async {
    final batch = _firestore.batch();

    batch.update(
      _firestore
          .collection('stores')
          .doc(storeId)
          .collection('workers')
          .doc(workerUid),
      {'isActive': isActive},
    );
    batch.update(_firestore.collection('users').doc(workerUid), {
      'isActive': isActive,
    });

    await batch.commit();
  }

  // ─── DELETE WORKER ───────────────────────────────────────────────────────────
  // Note: This only removes Firestore records.
  // Firebase Auth account deletion requires Admin SDK (Blaze plan).
  // On Spark: deactivate instead of delete for full removal.

  Future<void> deleteWorker(String storeId, String workerUid) async {
    final batch = _firestore.batch();

    batch.delete(
      _firestore
          .collection('stores')
          .doc(storeId)
          .collection('workers')
          .doc(workerUid),
    );
    batch.delete(_firestore.collection('users').doc(workerUid));

    await batch.commit();
  }

  // ─── UPDATE NAME ─────────────────────────────────────────────────────────────

  Future<void> updateWorkerName(
    String storeId,
    String workerUid,
    String newName,
  ) async {
    final batch = _firestore.batch();

    batch.update(
      _firestore
          .collection('stores')
          .doc(storeId)
          .collection('workers')
          .doc(workerUid),
      {'name': newName},
    );
    batch.update(_firestore.collection('users').doc(workerUid), {
      'name': newName,
    });

    await batch.commit();
  }
}
