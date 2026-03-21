import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/store_model.dart';

class StoreService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Register a new store
  Future<void> registerStore(StoreModel store) async {
    await _firestore.collection('stores').add(store.toMap());
  }

  // Get all stores
  Stream<List<StoreModel>> getAllStores() {
    return _firestore
        .collection('stores')
        .where('isActive', isEqualTo: true)
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .map((doc) => StoreModel.fromMap(doc.data(), doc.id))
              .toList(),
        );
  }

  // Get store by owner
  Stream<StoreModel?> getStoreByOwner(String ownerUid) {
    return _firestore
        .collection('stores')
        .where('ownerUid', isEqualTo: ownerUid)
        .snapshots()
        .map(
          (snapshot) => snapshot.docs.isEmpty
              ? null
              : StoreModel.fromMap(
                  snapshot.docs.first.data(),
                  snapshot.docs.first.id,
                ),
        );
  }

  // Get single store by ID
  Future<StoreModel?> getStoreById(String storeId) async {
    DocumentSnapshot doc = await _firestore
        .collection('stores')
        .doc(storeId)
        .get();
    if (!doc.exists) return null;
    return StoreModel.fromMap(doc.data() as Map<String, dynamic>, doc.id);
  }

  // Update store details
  Future<void> updateStore(String storeId, Map<String, dynamic> data) async {
    await _firestore.collection('stores').doc(storeId).update(data);
  }
}
