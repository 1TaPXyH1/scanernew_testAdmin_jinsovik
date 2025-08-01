import 'package:flutter/material.dart';

class RecountSessionManager extends ChangeNotifier {
  final List<Map<String, dynamic>> _products = [];
  List<Map<String, dynamic>> get products => List.unmodifiable(_products);

  void addOrUpdateProduct(Map<String, dynamic> product, {bool replace = false}) {
    final idx = _products.indexWhere((p) => p['barcode'] == product['barcode']);
    if (idx >= 0) {
      final existing = Map<String, dynamic>.from(_products[idx]);
      final int existingActual = existing['actual'] ?? 0;
      final int newActual = product['actual'] ?? 0;
      
      // If replace is true, set the actual count to the new value instead of adding
      existing['actual'] = replace ? newActual : existingActual + newActual;

      // Update other fields in case they changed (price, stock, name, etc.)
      existing['price'] = product['price'] ?? existing['price'];
      existing['stock'] = product['stock'] ?? existing['stock'];
      existing['name'] = product['name'] ?? existing['name'];
      existing['comment'] = product['comment'] ?? existing['comment'];

      _products[idx] = existing;
    } else {
      _products.add(product);
    }
    notifyListeners();
  }

  void clear() {
    _products.clear();
    notifyListeners();
  }
}

