class CartItem {
  final String productDocId;
  final String productId;
  final String title;
  final String imageUrl;
  final String selectedSize;
  final int quantity;
  final double unitPrice;

  const CartItem({
    required this.productDocId,
    required this.productId,
    required this.title,
    required this.imageUrl,
    required this.selectedSize,
    required this.quantity,
    required this.unitPrice,
  });

  String get cartKey => '$productDocId::$selectedSize';

  double get lineTotal => unitPrice * quantity;

  CartItem copyWith({int? quantity}) {
    return CartItem(
      productDocId: productDocId,
      productId: productId,
      title: title,
      imageUrl: imageUrl,
      selectedSize: selectedSize,
      quantity: quantity ?? this.quantity,
      unitPrice: unitPrice,
    );
  }

  Map<String, dynamic> toMap() => {
        'productDocId': productDocId,
        'productId': productId,
        'title': title,
        'imageUrl': imageUrl,
        'selectedSize': selectedSize,
        'quantity': quantity,
        'unitPrice': unitPrice,
      };

  factory CartItem.fromMap(Map<String, dynamic> map) {
    return CartItem(
      productDocId: (map['productDocId'] ?? '').toString(),
      productId: (map['productId'] ?? '').toString(),
      title: (map['title'] ?? 'Item').toString(),
      imageUrl: (map['imageUrl'] ?? '').toString(),
      selectedSize: (map['selectedSize'] ?? 'One size').toString(),
      quantity: (map['quantity'] is int) ? map['quantity'] as int : int.tryParse('${map['quantity']}') ?? 1,
      unitPrice: (map['unitPrice'] is num) ? (map['unitPrice'] as num).toDouble() : double.tryParse('${map['unitPrice']}') ?? 0,
    );
  }
}
