import 'package:flutter/material.dart';
import '../services/session_storage.dart';

class RecountSessionManager extends ChangeNotifier {
  final SessionStorage _storage;
  final List<Map<String, dynamic>> _products = [];
  String? _currentSessionId;

  RecountSessionManager(this._storage);

  List<Map<String, dynamic>> get products => List.unmodifiable(_products);
  String? get currentSessionId => _currentSessionId;

  Future<String> startNewSession() async {
    _products.clear();
    _currentSessionId = await _storage.startNewSession();
    notifyListeners();
    return _currentSessionId!;
  }

  Future<void> saveSessionSnapshot() async {
    if (_currentSessionId != null) {
      await _storage.saveProducts(_currentSessionId!, _products);
    }
  }

  void addOrUpdateProduct(Map<String, dynamic> product, {bool replace = false}) {
    final idx = _products.indexWhere((p) => p['barcode'] == product['barcode']);
    if (idx >= 0) {
      final existing = Map<String, dynamic>.from(_products[idx]);
      final int existingActual = existing['actual_count'] ?? 0;
      final int newActual = product['actual_count'] ?? 0;

      existing['actual_count'] = replace ? newActual : existingActual + newActual;
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

  Future<void> completeSession() async {
    if (_currentSessionId != null) {
      await _storage.saveProducts(_currentSessionId!, _products);
      await _storage.completeSession(_currentSessionId!);
    }
    _products.clear();
    _currentSessionId = null;
    notifyListeners();
  }

  Future<void> loadSession(String sessionId) async {
    _products.clear();
    final session = _storage.allSessions.where((s) => s.id == sessionId).firstOrNull;
    if (session != null) {
      _products.addAll(session.products);
      _currentSessionId = sessionId;
      notifyListeners();
    }
  }

  void clear() {
    _products.clear();
    _currentSessionId = null;
    notifyListeners();
  }
}
