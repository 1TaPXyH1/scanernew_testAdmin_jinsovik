import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:printing/printing.dart';

import '../utils/pdf_generator.dart';
import 'recount_session_manager.dart';

class RecountProductListScreen extends StatefulWidget {
  final List<Map<String, dynamic>> products;
  final List<String> sessionNames;

  const RecountProductListScreen({
    Key? key,
    required this.products,
    required this.sessionNames,
  }) : super(key: key);

  @override
  State<RecountProductListScreen> createState() => _RecountProductListScreenState();
}

class _RecountProductListScreenState extends State<RecountProductListScreen> {
  int _toInt(dynamic v) => v is int ? v : int.tryParse(v.toString()) ?? 0;
  double _toDouble(dynamic v) => v is double ? v : double.tryParse(v.toString()) ?? 0.0;
  
  // Визначення статі товару за назвою
  bool _isWomenProduct(Map<String, dynamic> product) {
    final name = (product['name']?.toString() ?? '').toLowerCase();
    return name.startsWith('ж ');
  }
  
  // Групування товарів за статтю
  Map<String, List<Map<String, dynamic>>> _groupProductsByGender(List<Map<String, dynamic>> products) {
    final women = <Map<String, dynamic>>[];
    final men = <Map<String, dynamic>>[];
    
    for (final product in products) {
      if (_isWomenProduct(product)) {
        women.add(product);
      } else {
        men.add(product);
      }
    }
    
    return {
      'Жіночий товар': women,
      'Чоловічий товар': men,
    };
  }

  int _totalCount(List<Map<String, dynamic>> products) => products.fold(0, (sum, p) => sum + _toInt(p['actual']));
  int _totalStock(List<Map<String, dynamic>> products) => products.fold(0, (sum, p) => sum + _toInt(p['stock']));
  int _totalDiff(List<Map<String, dynamic>> products) => products.fold(0, (sum, p) => sum + (_toInt(p['actual']) - _toInt(p['stock'])));
  double _totalStockPrice(List<Map<String, dynamic>> products) => products.fold(0.0, (sum, p) => sum + (_toDouble(p['price']) * _toInt(p['stock'])));
  double _totalActualPrice(List<Map<String, dynamic>> products) => products.fold(0.0, (sum, p) => sum + (_toDouble(p['price']) * _toInt(p['actual'])));
  double _totalPriceDiff(List<Map<String, dynamic>> products) => _totalActualPrice(products) - _totalStockPrice(products);

  Color _diffColor(int diff) {
    if (diff > 0) return Colors.greenAccent;
    if (diff < 0) return Colors.redAccent;
    return Colors.grey;
  }

  @override
  Widget build(BuildContext context) {
    final products = Provider.of<RecountSessionManager>(context).products;
    return Scaffold(
      backgroundColor: const Color(0xFF121212),
      appBar: AppBar(
        backgroundColor: Colors.black,
        title: const Text(
          'Список товарів',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.of(context).pop(),
        ),
        elevation: 0,
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFF121212), Colors.blueGrey],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: Column(
          children: [
            Container(
              margin: const EdgeInsets.all(12),
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [Colors.blueGrey.shade700, Colors.blueGrey.shade800],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(16),
                boxShadow: const [
                  BoxShadow(
                    color: Color(0x4D000000), // 30% opacity black
                    blurRadius: 8,
                    offset: Offset(0, 4),
                  ),
                ],
              ),
              child: const Row(
                children: [
                  SizedBox(width: 20), // Space for color bar
                  Expanded(flex: 3, child: Text('📦 Назва товару', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16))),
                  Expanded(flex: 1, child: Text('💰 Ціна', style: TextStyle(color: Colors.orange, fontWeight: FontWeight.bold, fontSize: 14), textAlign: TextAlign.center)),
                  Expanded(flex: 1, child: Text('🏪 Залишок', style: TextStyle(color: Colors.green, fontWeight: FontWeight.bold, fontSize: 14), textAlign: TextAlign.center)),
                  Expanded(flex: 1, child: Text('📱 По факту', style: TextStyle(color: Colors.blueAccent, fontWeight: FontWeight.bold, fontSize: 14), textAlign: TextAlign.center)),
                  Expanded(flex: 1, child: Text('⚖️ Різниця', style: TextStyle(color: Colors.white70, fontWeight: FontWeight.bold, fontSize: 14), textAlign: TextAlign.center)),
                  SizedBox(width: 80), // Space for action buttons
                ],
              ),
            ),
            Expanded(
              child: _buildGroupedProductList(products),
            ),
            _buildSummary(products),
          ],
        ),
      ),
    );
  }

  Widget _buildGroupedProductList(List<Map<String, dynamic>> products) {
    final groupedProducts = _groupProductsByGender(products);
    
    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 8),
      children: [
        for (final entry in groupedProducts.entries)
          if (entry.value.isNotEmpty) ...[
            // Заголовок групи
            Container(
              margin: const EdgeInsets.fromLTRB(8, 16, 8, 8),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: entry.key == 'Жіночий товар' 
                      ? [Colors.pink.shade600, Colors.pink.shade800]
                      : [Colors.blue.shade600, Colors.blue.shade800],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(12),
                boxShadow: const [
                  BoxShadow(
                    color: Color(0x4D000000),
                    blurRadius: 6,
                    offset: Offset(0, 2),
                  ),
                ],
              ),
              child: Row(
                children: [
                  Icon(
                    entry.key == 'Жіночий товар' ? Icons.female : Icons.male,
                    color: Colors.white,
                    size: 24,
                  ),
                  const SizedBox(width: 12),
                  Text(
                    '${entry.key} (${entry.value.length})',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
            // Товари групи
            ...entry.value.asMap().entries.map((productEntry) {
              final i = productEntry.key;
              final p = productEntry.value;
              final isEven = i % 2 == 0;
              final diff = _toInt(p['actual']) - _toInt(p['stock']);
              final diffColor = diff == 0 ? Colors.transparent : (diff > 0 ? Colors.greenAccent : Colors.redAccent);
              
              return Card(
                elevation: 6,
                margin: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
                shape: const RoundedRectangleBorder(borderRadius: BorderRadius.all(Radius.circular(20))),
                color: isEven ? const Color(0xFF212121) : const Color(0xFF424242),
                shadowColor: const Color(0x66000000),
                child: InkWell(
                  borderRadius: BorderRadius.circular(18),
                  splashColor: const Color(0x1F448AFF),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 18),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Container(
                          width: 8,
                          height: 54,
                          margin: const EdgeInsets.only(right: 12),
                          decoration: BoxDecoration(
                            color: diffColor,
                            borderRadius: BorderRadius.circular(6),
                          ),
                        ),
                        Expanded(
                          flex: 3,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                p['name']?.toString() ?? '',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                ),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                              if ((p['comment'] ?? '').toString().isNotEmpty)
                                Padding(
                                  padding: const EdgeInsets.only(top: 4),
                                  child: Row(
                                    children: [
                                      const Icon(Icons.comment, color: Colors.orange, size: 16),
                                      const SizedBox(width: 4),
                                      Expanded(
                                        child: Text(
                                          p['comment'],
                                          style: const TextStyle(color: Colors.orange, fontSize: 13),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                            ],
                          ),
                        ),
                        Expanded(
                          flex: 1,
                          child: Column(
                            children: [
                              const Icon(Icons.sell, color: Colors.orange, size: 20),
                              const SizedBox(height: 2),
                              Text(
                                _toDouble(p['price']).toStringAsFixed(2),
                                style: const TextStyle(color: Colors.orange, fontWeight: FontWeight.w600, fontSize: 15),
                                textAlign: TextAlign.center,
                              ),
                            ],
                          ),
                        ),
                        Expanded(
                          flex: 1,
                          child: Column(
                            children: [
                              const Icon(Icons.store, color: Colors.green, size: 20),
                              const SizedBox(height: 2),
                              Text(
                                _toInt(p['stock']).toString(),
                                style: const TextStyle(color: Colors.green, fontWeight: FontWeight.w600, fontSize: 15),
                                textAlign: TextAlign.center,
                              ),
                            ],
                          ),
                        ),
                        Expanded(
                          flex: 1,
                          child: Column(
                            children: [
                              const Icon(Icons.qr_code, color: Colors.blueAccent, size: 20),
                              const SizedBox(height: 2),
                              Text(
                                _toInt(p['actual']).toString(),
                                style: const TextStyle(color: Colors.blueAccent, fontWeight: FontWeight.w700, fontSize: 16),
                                textAlign: TextAlign.center,
                              ),
                            ],
                          ),
                        ),
                        Expanded(
                          flex: 1,
                          child: diff == 0
                              ? const SizedBox.shrink()
                              : Text(
                                  '$diff',
                                  style: TextStyle(
                                    color: diff > 0 ? Colors.greenAccent : Colors.redAccent,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 16,
                                  ),
                                  textAlign: TextAlign.center,
                                ),
                        ),
                        const SizedBox(width: 80), // Space for action buttons
                      ],
                    ),
                  ),
                ),
              );
            }),
          ],
      ],
    );
  }

  Widget _buildSummary(List<Map<String, dynamic>> products) {
    final totalCount = _totalCount(products);
    final totalStock = _totalStock(products);
    final totalDiff = _totalDiff(products);
    final totalStockPrice = _totalStockPrice(products);
    final totalActualPrice = _totalActualPrice(products);
    final totalPriceDiff = _totalPriceDiff(products);
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.blueGrey.shade800,
        border: const Border(top: BorderSide(color: Color(0x1AFFFFFF))),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            'Підсумок переобліку',
            style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          _summaryRow('Всього товарів:', '$totalCount'),
          _summaryRow('Загальний залишок:', '$totalStock', color: Colors.green),
          _summaryRow('Проскановано:', '$totalCount', color: Colors.blueAccent),
          _summaryRow('Різниця:', totalDiff > 0 ? '+$totalDiff' : '$totalDiff', color: _diffColor(totalDiff)),
          const Divider(color: Colors.white30, height: 24),
          _summaryRow('Ціна (по залишкам):', '${totalStockPrice.toStringAsFixed(2)} грн', color: Colors.green),
          _summaryRow('Ціна (по факту):', '${totalActualPrice.toStringAsFixed(2)} грн', color: Colors.blueAccent),
          _summaryRow('Різниця в грошах:', '${totalPriceDiff >= 0 ? '+' : ''}${totalPriceDiff.toStringAsFixed(2)} грн', color: totalPriceDiff >= 0 ? Colors.green : Colors.red),
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  icon: const Icon(Icons.qr_code_scanner),
                  label: const Text('Сканувати далі'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blueAccent,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  onPressed: () => Navigator.of(context).pop('scan_more'),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: ElevatedButton.icon(
                  icon: const Icon(Icons.picture_as_pdf),
                  label: const Text('Завершити'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green.shade600,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  onPressed: () async {
                    final file = await PdfGenerator.generateRecountReport(
                      products: products,
                      sessionNames: widget.sessionNames,
                    );
                    if (!mounted) return;
                    showDialog(
                      context: context,
                      barrierDismissible: false,
                      builder: (ctx) => AlertDialog(
                        backgroundColor: const Color(0xFF1E1E1E),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                        title: const Text('PDF звіт створено', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                        content: const Text('Звіт успішно згенеровано. Ви можете поділитися ним через PDF.', style: TextStyle(color: Colors.white70)),
                        actions: [
                          TextButton(
                            onPressed: () {
                              Navigator.pop(ctx);
                              Provider.of<RecountSessionManager>(context, listen: false).clear();
                              Navigator.of(context).pop('finish');
                            },
                            child: const Text('Готово', style: TextStyle(color: Colors.white60)),
                          ),
                          ElevatedButton(
                            onPressed: () {
                              Printing.sharePdf(bytes: file.readAsBytesSync(), filename: 'recount_report.pdf');
                            },
                            style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
                            child: const Text('Відкрити'),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _summaryRow(String title, String value, {Color? color}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(title, style: const TextStyle(color: Colors.white70, fontSize: 14)),
          Text(
            value,
            style: TextStyle(
              color: color ?? Colors.white,
              fontSize: 14,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }
}
