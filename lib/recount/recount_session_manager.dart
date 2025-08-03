import 'package:flutter/material.dart';

class RecountSessionManager extends ChangeNotifier {
  final List<Map<String, dynamic>> _products = [];
  List<Map<String, dynamic>> get products => List.unmodifiable(_products);

  void addOrUpdateProduct(Map<String, dynamic> product, {bool replace = false}) {
    final idx = _products.indexWhere((p) => p['barcode'] == product['barcode']);
    if (idx >= 0) {
      final existing = Map<String, dynamic>.from(_products[idx]);
      final int existingActual = existing['actual_count'] ?? 0;
      final int newActual = product['actual_count'] ?? 0;
      
      // If replace is true, set the actual count to the new value instead of adding
      existing['actual_count'] = replace ? newActual : existingActual + newActual;

      // Update other fields in case they changed (price, stock, name, etc.)
      existing['price'] = product['price'] ?? existing['price'];
      existing['stock_count'] = product['stock_count'] ?? existing['stock_count'];
      existing['name'] = product['name'] ?? existing['name'];
      existing['comment'] = product['comment'] ?? existing['comment'];

      _products[idx] = existing;
    } else {
      _products.add(product);
    }
    notifyListeners();
  }

  void updateProduct(String barcode, int newActualCount, String newComment) {
    final idx = _products.indexWhere((p) => p['barcode'] == barcode);
    if (idx >= 0) {
      _products[idx]['actual_count'] = newActualCount;
      _products[idx]['comment'] = newComment;
      notifyListeners();
    }
  }

  void removeProduct(String barcode) {
    _products.removeWhere((p) => p['barcode'] == barcode);
    notifyListeners();
  }

  void clear() {
    _products.clear();
    notifyListeners();
  }
}

