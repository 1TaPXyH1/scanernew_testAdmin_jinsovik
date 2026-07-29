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
        child: _buildGroupedProductList(products),
      ),
    );
  }

  Widget _buildGroupedProductList(List<Map<String, dynamic>> products) {
    final groupedProducts = _groupProductsByGender(products);
    
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // Простий список карток замість таблиці
        ...groupedProducts.entries.expand((entry) {
          if (entry.value.isEmpty) return <Widget>[];
          
          final widgets = <Widget>[];
          
          // Заголовок групи
          widgets.add(
            Container(
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: entry.key == 'Жіночий товар' 
                      ? [Colors.pink.shade600, Colors.pink.shade700]
                      : [Colors.blue.shade600, Colors.blue.shade700],
                  begin: Alignment.centerLeft,
                  end: Alignment.centerRight,
                ),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  Icon(
                    entry.key == 'Жіночий товар' ? Icons.female : Icons.male,
                    color: Colors.white,
                    size: 20,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    '${entry.key} (${entry.value.length})',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
          );
          
          // Картки товарів
          for (final product in entry.value) {
            final diff = _toInt(product['actual_count']) - _toInt(product['stock_count']);
            
            widgets.add(
              Card(
                margin: const EdgeInsets.only(bottom: 8),
                color: const Color(0xFF1E1E1E),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Назва товару
                      Text(
                        product['name']?.toString() ?? '',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Row(
                        children: [
                          const Icon(Icons.qr_code, size: 14, color: Colors.white38),
                          const SizedBox(width: 4),
                          Text(
                            product['barcode']?.toString() ?? '',
                            style: const TextStyle(color: Colors.white38, fontSize: 12),
                          ),
                        ],
                      ),
                      if ((product['comment'] ?? '').toString().isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(top: 4),
                          child: Text(
                            product['comment'],
                            style: TextStyle(
                              color: Colors.orange.shade300,
                              fontSize: 12,
                            ),
                          ),
                        ),
                      const SizedBox(height: 12),
                      // Інформація про товар
                      Row(
                        children: [
                          Expanded(
                            child: _buildInfoChip(
                              'Ціна', 
                              '${_toDouble(product['price']).toStringAsFixed(0)}₴',
                              Colors.orange,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: _buildInfoChip(
                              'Залишок', 
                              _toInt(product['stock_count']).toString(),
                              Colors.green,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          Expanded(
                            child: _buildInfoChip(
                              'По факту', 
                              _toInt(product['actual_count']).toString(),
                              Colors.blue,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: _buildInfoChip(
                              'Різниця', 
                              diff == 0 ? '=' : diff.toString(),
                              diff == 0 ? Colors.grey : (diff > 0 ? Colors.green : Colors.red),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      // Кнопки дій
                      Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          TextButton.icon(
                            onPressed: () => _editProduct(product),
                            icon: const Icon(Icons.edit, color: Colors.blue, size: 16),
                            label: const Text('Редагувати', style: TextStyle(color: Colors.blue)),
                          ),
                          TextButton.icon(
                            onPressed: () => _deleteProduct(product),
                            icon: const Icon(Icons.delete, color: Colors.red, size: 16),
                            label: const Text('Видалити', style: TextStyle(color: Colors.red)),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            );
          }
          
          widgets.add(const SizedBox(height: 16));
          return widgets;
        }),
      const SizedBox(height: 16),
        // Підсумок переобліку
        Container(
          margin: const EdgeInsets.symmetric(horizontal: 12),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: const Color(0xFF1E1E1E),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.grey.shade700, width: 1),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Row(
                children: [
                  Icon(Icons.bar_chart, color: Colors.white, size: 20),
                  SizedBox(width: 8),
                  Text(
                    'ПІДСУМОК ПЕРЕОБЛІКУ',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Column(
                children: [
                  SingleChildScrollView(
                    child: _buildSummaryStats(products),
                  ),
                  const SizedBox(height: 16),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        // Кнопки дій
        Container(
          margin: const EdgeInsets.all(12),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: const Color(0xFF1E1E1E),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.grey.shade700, width: 1),
          ),
          child: Column(
            children: [
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      icon: const Icon(Icons.qr_code_scanner, size: 20),
                      label: const Text('Сканувати далі'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blueAccent,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                      onPressed: () => Navigator.of(context).pop('scan_more'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton.icon(
                      icon: const Icon(Icons.picture_as_pdf, size: 20),
                      label: const Text('Завершити'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green.shade600,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
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
                                onPressed: () async {
                                  Navigator.pop(ctx);
                                  final manager = Provider.of<RecountSessionManager>(context, listen: false);
                                  await manager.completeSession();
                                  if (!mounted) return;
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
        ),
      ],
    );
  }

  Widget _buildInfoChip(String label, String value, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      decoration: BoxDecoration(
        color: color.withAlpha(25),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withAlpha(77), width: 1),
      ),
      child: Column(
        children: [
          Text(
            label,
            style: TextStyle(
              color: color,
              fontSize: 10,
              fontWeight: FontWeight.w500,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 2),
          Text(
            value,
            style: TextStyle(
              color: color,
              fontSize: 14,
              fontWeight: FontWeight.bold,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  void _editProduct(Map<String, dynamic> product) {
    final TextEditingController actualCountController = TextEditingController(
      text: product['actual_count']?.toString() ?? '0',
    );
    final TextEditingController commentController = TextEditingController(
      text: product['comment']?.toString() ?? '',
    );

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF1E1E1E),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => Padding(
        padding: EdgeInsets.fromLTRB(24, 24, 24, 24 + MediaQuery.of(ctx).viewInsets.bottom),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40, height: 4,
                decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(2)),
              ),
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.blue.withAlpha(25),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.edit, color: Colors.blue, size: 20),
                ),
                const SizedBox(width: 12),
                const Expanded(
                  child: Text('Редагувати товар',
                    style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.grey.withAlpha(25),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  const Icon(Icons.qr_code, size: 16, color: Colors.white54),
                  const SizedBox(width: 8),
                  Text(product['barcode']?.toString() ?? '',
                    style: const TextStyle(color: Colors.white54, fontSize: 13)),
                ],
              ),
            ),
            const SizedBox(height: 8),
            Text(product['name']?.toString() ?? '',
              style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w600)),
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Кількість по факту', style: TextStyle(color: Colors.white70, fontSize: 13)),
                      const SizedBox(height: 6),
                      Container(
                        decoration: BoxDecoration(
                          color: const Color(0xFF2A2A2A),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.blue.withAlpha(77)),
                        ),
                        child: TextField(
                          controller: actualCountController,
                          keyboardType: TextInputType.number,
                          style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.white),
                          textAlign: TextAlign.center,
                          decoration: InputDecoration(
                            filled: true,
                            fillColor: Colors.transparent,
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                            contentPadding: const EdgeInsets.symmetric(vertical: 14),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Залишок', style: TextStyle(color: Colors.white70, fontSize: 13)),
                      const SizedBox(height: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        decoration: BoxDecoration(
                          color: const Color(0xFF2A2A2A),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.orange.withAlpha(77)),
                        ),
                        width: double.infinity,
                        child: Text(
                          _toInt(product['stock_count']).toString(),
                          style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.orangeAccent),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            TextField(
              controller: commentController,
              style: const TextStyle(color: Colors.white, fontSize: 14),
              maxLines: 2,
              decoration: InputDecoration(
                hintText: 'Коментар',
                hintStyle: const TextStyle(color: Colors.white38),
                filled: true,
                fillColor: const Color(0xFF2A2A2A),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              ),
            ),
            const SizedBox(height: 24),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () {
                      actualCountController.dispose();
                      commentController.dispose();
                      Navigator.pop(ctx);
                    },
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: Colors.white24),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                    child: const Text('Скасувати', style: TextStyle(color: Colors.white54, fontSize: 16)),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () {
                      final newActualCount = int.tryParse(actualCountController.text) ?? 0;
                      final newComment = commentController.text.trim();
                      actualCountController.dispose();
                      commentController.dispose();
                      final sessionManager = Provider.of<RecountSessionManager>(context, listen: false);
                      sessionManager.updateProduct(product['barcode'], newActualCount, newComment);
                      Navigator.pop(ctx);
                      setState(() {});
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blue,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                    child: const Text('Зберегти', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
                  ),
                ),
              ],
            ),
            ],
          ),
        ),
      ),
    );
  }

  void _deleteProduct(Map<String, dynamic> product) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF424242),
        title: const Text('Видалити товар?', style: TextStyle(color: Colors.white)),
        content: Text(
          'Ви впевнені, що хочете видалити "${product['name']}"?',
          style: const TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Скасувати', style: TextStyle(color: Colors.grey)),
          ),
          TextButton(
            onPressed: () {
              // Видаляємо товар з сесії
              final sessionManager = Provider.of<RecountSessionManager>(context, listen: false);
              sessionManager.removeProduct(product['barcode']);
              
              Navigator.pop(context);
              setState(() {}); // Оновлюємо UI
              
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Row(
                    children: [
                      const Icon(Icons.check_circle_outline, color: Color(0xFFFFDAD6), size: 20),
                      const SizedBox(width: 10),
                      Flexible(child: Text('Товар "${product['name']}" видалено', style: const TextStyle(color: Color(0xFFFFDAD6)))),
                    ],
                  ),
                  backgroundColor: const Color(0xFF93000A),
                  behavior: SnackBarBehavior.floating,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  duration: const Duration(seconds: 3),
                ),
              );
            },
            child: const Text('Видалити', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryStats(List<Map<String, dynamic>> products) {
    final totalProducts = products.length;
    final totalStock = products.fold<int>(0, (sum, p) => sum + _toInt(p['stock_count']));
    final totalActual = products.fold<int>(0, (sum, p) => sum + _toInt(p['actual_count']));
    final totalDiff = totalActual - totalStock;
    final totalStockPrice = products.fold<double>(0.0, (sum, p) => sum + (_toDouble(p['price']) * _toInt(p['stock_count'])));
    final totalActualPrice = products.fold<double>(0.0, (sum, p) => sum + (_toDouble(p['price']) * _toInt(p['actual_count'])));
    final totalPriceDiff = totalActualPrice - totalStockPrice;

    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: _buildStatCard(Icons.inventory_2_outlined, 'Товарів', '$totalProducts', Colors.blue),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _buildStatCard(Icons.store_outlined, 'Залишок', '$totalStock', Colors.green),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _buildStatCard(Icons.checklist_outlined, 'По факту', '$totalActual', Colors.orange),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: _buildStatCard(Icons.balance_outlined, 'Різниця', totalDiff >= 0 ? '+$totalDiff' : '$totalDiff', 
                totalDiff > 0 ? Colors.green : (totalDiff < 0 ? Colors.red : Colors.grey)),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _buildStatCard(Icons.attach_money_outlined, 'Вартість', '${totalPriceDiff >= 0 ? '+' : ''}${totalPriceDiff.toStringAsFixed(0)}₴', 
                totalPriceDiff >= 0 ? Colors.green : Colors.red),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildStatCard(IconData icon, String label, String value, Color color) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withAlpha(25),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withAlpha(77), width: 1),
      ),
      child: Column(
        children: [
          Icon(icon, size: 20, color: color),
          const SizedBox(height: 2),
          Text(
            value,
            style: TextStyle(
              color: color,
              fontSize: 14,
              fontWeight: FontWeight.bold,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }


}
