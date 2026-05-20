class StoreModel {
  final String storeId;
  final String ownerUid;
  final String storeName;
  final String location;
  final String contact;
  final String description;
  final String imageUrl;
  final bool isActive;
  final String facebookUrl;
  final String instagramUrl;
  final String tiktokUrl;
  final String businessHours;

  StoreModel({
    required this.storeId,
    required this.ownerUid,
    required this.storeName,
    required this.location,
    required this.contact,
    required this.description,
    this.imageUrl = '',
    this.isActive = true,
    this.facebookUrl = '',
    this.instagramUrl = '',
    this.tiktokUrl = '',
    this.businessHours = '',
  });

  factory StoreModel.fromMap(Map<String, dynamic> map, String id) {
    return StoreModel(
      storeId: id,
      ownerUid: map['ownerUid'] ?? '',
      storeName: map['storeName'] ?? '',
      location: map['location'] ?? '',
      contact: map['contact'] ?? '',
      description: map['description'] ?? '',
      imageUrl: map['imageUrl'] ?? '',
      isActive: map['isActive'] ?? true,
      facebookUrl: map['facebookUrl'] ?? '',
      instagramUrl: map['instagramUrl'] ?? '',
      tiktokUrl: map['tiktokUrl'] ?? '',
      businessHours: map['businessHours'] ?? '',
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'ownerUid': ownerUid,
      'storeName': storeName,
      'location': location,
      'contact': contact,
      'description': description,
      'imageUrl': imageUrl,
      'isActive': isActive,
      'facebookUrl': facebookUrl,
      'instagramUrl': instagramUrl,
      'tiktokUrl': tiktokUrl,
      'businessHours': businessHours,
    };
  }
}
