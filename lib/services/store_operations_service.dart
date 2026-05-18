import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/store_operations_model.dart';

/// Reads/writes optional operational settings used by analytics.
/// Path: stores/{storeId}/settings/operations
class StoreOperationsService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  Future<StoreOperationsModel> getOperations(String storeId) async {
    final doc = await _firestore
        .collection('stores')
        .doc(storeId)
        .collection('settings')
        .doc('operations')
        .get();
    if (!doc.exists) return const StoreOperationsModel();
    return StoreOperationsModel.fromMap(doc.data());
  }

  Future<void> saveOperations(
    String storeId,
    StoreOperationsModel operations,
  ) async {
    await _firestore
        .collection('stores')
        .doc(storeId)
        .collection('settings')
        .doc('operations')
        .set(operations.toMap(), SetOptions(merge: true));
  }
}
