class RecountItem {
  final String name;
  final String barcode;
  final int expectedQuantity;
  final int countedQuantity;
  final String? comment;

  RecountItem({
    required this.name,
    required this.barcode,
    required this.expectedQuantity,
    required this.countedQuantity,
    this.comment,
  });

  factory RecountItem.fromMap(Map<String, dynamic> map) {
    int parseInt(dynamic v) => v is int ? v : int.tryParse(v.toString()) ?? 0;
    return RecountItem(
      name: map['name'] ?? '',
      barcode: map['barcode'] ?? '',
      expectedQuantity: parseInt(map['stock']),
      countedQuantity: parseInt(map['actual']),
      comment: map['comment'],
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'barcode': barcode,
      'stock': expectedQuantity,
      'actual': countedQuantity,
      'comment': comment,
    };
  }
}

