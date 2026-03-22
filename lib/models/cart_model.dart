class CartItemModel {
  final String cartItemId;
  final String productId;
  final String storeId;
  final String productName;
  final String color;
  final String size;
  final double price;
  int quantity;
  final String storeStoreName;

  CartItemModel({
    required this.cartItemId,
    required this.productId,
    required this.storeId,
    required this.productName,
    required this.color,
    required this.size,
    required this.price,
    required this.quantity,
    required this.storeStoreName,
  });

  double get totalPrice => price * quantity;

  factory CartItemModel.fromMap(Map<String, dynamic> map, String id) {
    return CartItemModel(
      cartItemId: id,
      productId: map['productId'] ?? '',
      storeId: map['storeId'] ?? '',
      productName: map['productName'] ?? '',
      color: map['color'] ?? '',
      size: map['size'] ?? '',
      price: (map['price'] ?? 0).toDouble(),
      quantity: map['quantity'] ?? 1,
      storeStoreName: map['storeName'] ?? '',
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'productId': productId,
      'storeId': storeId,
      'productName': productName,
      'color': color,
      'size': size,
      'price': price,
      'quantity': quantity,
      'storeName': storeStoreName,
    };
  }
}
