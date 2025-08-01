import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:provider/provider.dart';
import 'recount_session_manager.dart';

class RecountProductScreen extends StatefulWidget {
  final String barcode;
  final List<String> sessionNames;
  const RecountProductScreen({Key? key, required this.barcode, required this.sessionNames}) : super(key: key);

  @override
  State<RecountProductScreen> createState() => _RecountProductScreenState();
}

class _RecountProductScreenState extends State<RecountProductScreen> {
  Map<String, dynamic>? productData;
  bool isLoading = true;
  bool isError = false;
  int actualCount = 1;
  int _previousActual = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final products = Provider.of<RecountSessionManager>(context, listen: false).products;
      final existing = products.firstWhere(
        (p) => p['barcode'] == widget.barcode,
        orElse: () => {},
      );
      if (existing.isNotEmpty && existing['actual'] != null) {
        final prev = existing['actual'] is int
            ? existing['actual']
            : int.tryParse(existing['actual'].toString()) ?? 0;
        setState(() {
          actualCount = prev + 1; // increment by 1 after scan
          _previousActual = prev;
        });
      } else {
        setState(() {
          actualCount = 1;
          _previousActual = 0;
        });
      }
    });
    fetchProductData();
  }

  Future<void> fetchProductData() async {
    setState(() {
      isLoading = true;
      isError = false;
    });
    try {
      final response = await http.get(Uri.parse(
        'https://static.88-198-21-139.clients.your-server.de:956/REST/hs/prices/product_new/${widget.barcode}/',
      ));
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['success'] == true &&
            data['response'] is List &&
            data['response'].length == 2 &&
            data['response'][1] is List) {
          final productInfo = data['response'][0];
          final storesList = data['response'][1] as List;
          final filteredStores = storesList.where((store) {
            final name = (store['name']?.toString() ?? '').toLowerCase();
            return name.contains('харківське шосе');
          }).toList();
          if (filteredStores.isEmpty) {
            setState(() {
              isError = true;
              isLoading = false;
            });
          } else {
            final store = filteredStores.first;
            setState(() {
              productData = {
                'good': productInfo['good'],
                'price': productInfo['price'],
                'barcode': widget.barcode,
                'remaining': store['remaining'],
                'size': store['size'],
                'store': store['name'],
                'telephone': store['telephone'],
              };
              isLoading = false;
            });
          }
        } else {
          setState(() {
            isError = true;
            isLoading = false;
          });
        }
      } else {
        setState(() {
          isError = true;
          isLoading = false;
        });
      }
    } catch (_) {
      setState(() {
        isError = true;
        isLoading = false;
      });
    }
  }

  void _increment() => setState(() => actualCount++);
  void _decrement() => setState(() {
        if (actualCount > 0) actualCount--;
      });
  void _editCount() async {
    final controller = TextEditingController(text: actualCount.toString());
    final res = await showDialog<int>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Вкажіть кількість'),
        content: TextField(
          controller: controller,
          keyboardType: TextInputType.number,
          autofocus: true,
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Скасувати')),
          ElevatedButton(
            onPressed: () {
              final val = int.tryParse(controller.text);
              if (val != null && val >= 0) Navigator.pop(ctx, val);
            },
            child: const Text('OK'),
          ),
        ],
      ),
    );
    if (res != null) setState(() => actualCount = res);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF121212),
      appBar: AppBar(
        backgroundColor: Colors.black,
        title: const Text(
          'Переоблік товару',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.of(context).pop(),
        ),
        elevation: 0,
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [const Color(0xFF121212), Colors.blueGrey.shade900],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: isLoading
            ? const Center(
                child: CircularProgressIndicator(
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.blueAccent),
                ),
              )
            : isError
                ? const Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.error_outline,
                          color: Colors.redAccent,
                          size: 80,
                        ),
                        SizedBox(height: 20),
                        Text(
                          'Товар не знайдено',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        SizedBox(height: 8),
                        Text(
                          'Перевірте штрихкод або спробуйте ще раз',
                          style: TextStyle(
                            color: Colors.white70,
                            fontSize: 14,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  )
                : SafeArea(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          const SizedBox(height: 20),

                          // Назва товару (великим шрифтом)
                          Container(
                            padding: const EdgeInsets.all(20),
                            decoration: BoxDecoration(
                              color: const Color(0xFFFFFFFF).withValues(alpha: 13), // 0.05 * 255 ≈ 13
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(
                                color: const Color(0xFFFFFFFF).withValues(alpha: 26), // 0.1 * 255 ≈ 26
                              ),
                            ),
                            child: Text(
                              productData?['good'] ?? '',
                              style: const TextStyle(
                                fontSize: 24,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                                height: 1.3,
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ),

                          const SizedBox(height: 24),

                          // Ціна товару
                          Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: const Color(0xFFFFA500).withValues(alpha: 26), // orange 0.1 opacity
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const Icon(
                                  Icons.attach_money,
                                  color: Color(0xFFFFA500),
                                  size: 20,
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  'Ціна: ${productData?['price'] ?? '-'} грн',
                                  style: const TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.w600,
                                    color: Color(0xFFFFA500),
                                  ),
                                ),
                              ],
                            ),
                          ),

                          const SizedBox(height: 32),

                          // Лічильники кількості
                          Row(
                            children: [
                              // По факту (зліва, редаговано)
                              Expanded(
                                child: GestureDetector(
                                  onTap: _editCount,
                                  child: Container(
                                    padding: const EdgeInsets.all(20),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFF2196F3).withValues(alpha: 38), // blueAccent 0.15 opacity
                                      borderRadius: BorderRadius.circular(16),
                                      border: Border.all(
                                        color: const Color(0xFF2196F3).withValues(alpha: 77), // blueAccent 0.3 opacity
                                      ),
                                    ),
                                    child: Column(
                                      children: [
                                        const Text(
                                          'По факту',
                                          style: TextStyle(
                                            color: Color(0xFF2196F3),
                                            fontSize: 14,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                        const SizedBox(height: 12),
                                        SingleChildScrollView(
                                          scrollDirection: Axis.horizontal,
                                          child: Row(
                                            mainAxisSize: MainAxisSize.min,
                                            mainAxisAlignment: MainAxisAlignment.center,
                                            children: [
                                              IconButton(
                                                icon: const Icon(
                                                  Icons.remove_circle,
                                                  color: Color(0xFF2196F3),
                                                  size: 28,
                                                ),
                                                onPressed: _decrement,
                                              ),
                                              Container(
                                                padding: const EdgeInsets.symmetric(
                                                  horizontal: 12,
                                                  vertical: 8,
                                                ),
                                                decoration: BoxDecoration(
                                                  color: const Color(0xFF2196F3).withValues(alpha: 51), // blueAccent 0.2 opacity
                                                  borderRadius: BorderRadius.circular(8),
                                                ),
                                                child: Text(
                                                  '$actualCount',
                                                  style: const TextStyle(
                                                    fontSize: 26,
                                                    fontWeight: FontWeight.bold,
                                                    color: Colors.white,
                                                  ),
                                                ),
                                              ),
                                              IconButton(
                                                icon: const Icon(
                                                  Icons.add_circle,
                                                  color: Color(0xFF2196F3),
                                                  size: 28,
                                                ),
                                                onPressed: _increment,
                                              ),
                                            ],
                                          ),
                                        ),
                                        const SizedBox(height: 8),
                                        const Text(
                                          'Натисніть для редагування',
                                          style: TextStyle(
                                            color: Color(0xFF2196F3),
                                            fontSize: 12,
                                          ),
                                          textAlign: TextAlign.center,
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),

                              const SizedBox(width: 16),

                              // Залишок (справа, незмінний)
                              Expanded(
                                child: Container(
                                  padding: const EdgeInsets.all(20),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFF4CAF50).withValues(alpha: 38), // green 0.15 opacity
                                    borderRadius: BorderRadius.circular(16),
                                    border: Border.all(
                                      color: const Color(0xFF4CAF50).withValues(alpha: 77), // green 0.3 opacity
                                    ),
                                  ),
                                  child: Column(
                                    children: [
                                      const Text(
                                        'Залишок',
                                        style: TextStyle(
                                          color: Color(0xFF4CAF50),
                                          fontSize: 14,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                      const SizedBox(height: 12),
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 16,
                                          vertical: 12,
                                        ),
                                        decoration: BoxDecoration(
                                          color: const Color(0xFF4CAF50).withValues(alpha: 51), // green 0.2 opacity
                                          borderRadius: BorderRadius.circular(8),
                                        ),
                                        child: Text(
                                          (productData?['remaining']?.toString() ?? '-'),
                                          style: const TextStyle(
                                            fontSize: 28,
                                            fontWeight: FontWeight.bold,
                                            color: Colors.white,
                                          ),
                                        ),
                                      ),
                                      const SizedBox(height: 16),
                                      const Text(
                                        'З системи',
                                        style: TextStyle(
                                          color: Color(0xFF4CAF50),
                                          fontSize: 12,
                                        ),
                                        textAlign: TextAlign.center,
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ),

                          const SizedBox(height: 40),

                          // Кнопки дій
                          Row(
                            children: [
                              Expanded(
                                child: ElevatedButton.icon(
                                  icon: const Icon(Icons.qr_code_scanner),
                                  label: const Text('Сканувати далі'),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: const Color(0xFF2196F3),
                                    foregroundColor: Colors.white,
                                    padding: const EdgeInsets.symmetric(vertical: 16),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    elevation: 4,
                                  ),
                                  onPressed: () {
                                    if (productData != null) {
                                      final product = {
                                        'barcode': widget.barcode,
                                        'name': productData?['good'] ?? '',
                                        'price': productData?['price'],
                                        'stock': productData?['remaining'] ?? 0,
                                        'actual': actualCount - _previousActual,
                                        'comment': '',
                                      };
                                      Provider.of<RecountSessionManager>(context, listen: false)
                                          .addOrUpdateProduct(product);
                                    }
                                    Navigator.of(context).pop('scan_more');
                                  },
                                ),
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: OutlinedButton.icon(
                                  icon: const Icon(Icons.list_alt),
                                  label: const Text('Список'),
                                  style: OutlinedButton.styleFrom(
                                    foregroundColor: Colors.white70,
                                    side: const BorderSide(color: Colors.white30),
                                    padding: const EdgeInsets.symmetric(vertical: 16),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                  ),
                                  onPressed: () {
                                    if (productData != null) {
                                      final product = {
                                        'barcode': widget.barcode,
                                        'name': productData?['good'] ?? '',
                                        'price': productData?['price'],
                                        'stock': productData?['remaining'] ?? 0,
                                        'actual': actualCount - _previousActual,
                                        'comment': '',
                                      };
                                      Provider.of<RecountSessionManager>(context, listen: false)
                                          .addOrUpdateProduct(product);
                                    }
                                    Navigator.of(context).pop('show_list');
                                  },
                                ),
                              ),
                            ],
                          ),

                          const Spacer(),
                        ],
                      ),
                    ),
                  ),
      ),
    );
  }
}
