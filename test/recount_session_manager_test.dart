import 'package:flutter_test/flutter_test.dart';
import 'package:jinsovik_scanner/recount/recount_session_manager.dart';
import 'package:jinsovik_scanner/services/session_storage.dart';

void main() {
  group('RecountSessionManager product counts', () {
    test('a manual correction remains the final value after subsequent scans',
        () {
      final manager = RecountSessionManager(SessionStorage());
      final product = <String, dynamic>{
        'barcode': '2107000000000',
        'name': 'Test product',
        'price': 100.0,
        'stock_count': 10,
        'actual_count': 1,
      };

      manager.recordScan(product);
      manager.setActualCount({...product, 'actual_count': 5});
      expect(manager.products.single['actual_count'], 5);

      manager.recordScan(product);
      expect(manager.products.single['actual_count'], 6);

      manager.setActualCount({...product, 'actual_count': 3});
      expect(manager.products.single['actual_count'], 3);
    });
  });
}
