import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;

import 'package:vibration/vibration.dart';
import '../services/network_service.dart';
import '../widgets/platform_barcode_scanner.dart';
import 'recount_session_manager.dart';
import 'recount_product_list_screen.dart';

class RecountNewScanScreen extends StatefulWidget {
  final String sessionId;
  final List<String> sessionNames;

  const RecountNewScanScreen({
    Key? key,
    required this.sessionId,
    required this.sessionNames,
  }) : super(key: key);

  @override
  State<RecountNewScanScreen> createState() => _RecountNewScanScreenState();
}

class _RecountNewScanScreenState extends State<RecountNewScanScreen>
    with SingleTickerProviderStateMixin, WidgetsBindingObserver {
  bool _isScanning = false;
  bool _torchOn = false;
  bool _showProductPanel = false;
  
  // Error and success states to match scan.dart design
  bool _showSuccess = false;
  bool _hasError = false;
  String _errorMessage = '';

  String? _currentBarcode;
  String? _productName;
  double? _productPrice;
  int? _stockCount;
  int? _actualCount;
  final TextEditingController _actualCountController = TextEditingController();

  late AnimationController _borderAnimationController;
  late Animation<double> _borderAnimation;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _borderAnimationController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);
    _borderAnimation = Tween<double>(begin: 2, end: 5).animate(
      CurvedAnimation(
        parent: _borderAnimationController,
        curve: Curves.easeInOut,
      ),
    );
  }

  @override
  void deactivate() {
    // Platform scanner handles lifecycle automatically
    super.deactivate();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _borderAnimationController.dispose();
    _actualCountController.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Platform scanner handles lifecycle automatically
  }

  void _onTorchToggle(bool enabled) {
    setState(() {
      _torchOn = enabled;
    });
  }

  Future<void> _onBarcodeDetected(String barcode) async {
    if (_isScanning) return;

    if (barcode.isEmpty) return;

    setState(() {
      _isScanning = true;
    });

    try {
      if (await Vibration.hasVibrator()) {
        Vibration.vibrate(duration: 100);
      }
      await _processBarcode(barcode);
      if (!mounted) return;
    } catch (_) {
      _showError('Помилка при обробці штрихкоду');
    } finally {
      // Add small delay to reduce camera buffer issues
      await Future.delayed(const Duration(milliseconds: 500));
      if (mounted) {
        setState(() {
          _isScanning = false;
        });
      }
    }
  }

  Future<void> _processBarcode(String barcode) async {
    // Check network connection
    final networkService = NetworkService();
    final isConnected = await networkService.isConnected();
    
    if (!isConnected) {
      _showError("Помилка інтернет з'єднання");
      return;
    }
    
    // Validate barcode format
    if (!barcode.startsWith('210700')) {
      _showError("Невірний штрихкод");
      return;
    }
    
    try {
      final response = await http.get(Uri.parse(
        'https://static.88-198-21-139.clients.your-server.de:956/REST/hs/prices/product_new/$barcode/',
      ));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['success'] == true &&
            data['response'] is List &&
            data['response'].length == 2 &&
            data['response'][1] is List) {
          final productInfo = data['response'][0];
          final storesList = data['response'][1] as List;
          
          // Filter for Харківське шосе store only - same logic as result screen
          final filteredStores = storesList.where((store) {
            final storeName = (store['name']?.toString().toLowerCase()) ?? '';
            return storeName.contains('харківське шосе');
          }).toList();
          
          if (filteredStores.isEmpty) {
            _showError('Товар не знайдено в магазині Харківське шосе');
            return;
          }
          
          final storeData = filteredStores.first;

          if (!mounted) return;
          final sessionManager =
              Provider.of<RecountSessionManager>(context, listen: false);
          final existingProduct = sessionManager.products.firstWhere(
            (p) => p['barcode'] == barcode,
            orElse: () => {},
          );

          // Show success state first
          setState(() {
            _showSuccess = true;
            _hasError = false;
          });
          
          await Future.delayed(const Duration(milliseconds: 800));
          
          if (!mounted) return;
          
          // Get current actual count and increment by 1
          final currentActualCount = existingProduct.isNotEmpty
              ? (existingProduct['actual_count'] ?? 0)
              : 0;
          final newActualCount = currentActualCount + 1;
          
          setState(() {
            _currentBarcode = barcode;
            _productName = productInfo['good'] ?? 'Невідомий товар';
            _productPrice = double.tryParse(productInfo['price']?.toString() ?? '0') ?? 0.0;
            _stockCount = int.tryParse(storeData['remaining'].toString()) ?? 0;
            _actualCount = newActualCount;
            _actualCountController.text = _actualCount.toString();
            _showSuccess = false;
            _showProductPanel = true;
          });

          // Add/update product with correct actual count
          sessionManager.addOrUpdateProduct({
            'barcode': barcode,
            'name': _productName!,
            'price': _productPrice!,
            'stock_count': _stockCount!,
            'actual_count': 1, // Add 1 to existing count
            'replace': false, // Don't replace, add to existing
          });
        } else {
          _showError('Товар не знайдено в базі даних');
        }
      } else {
        _showError('Помилка сервера: ${response.statusCode}');
      }
    } catch (e) {
      _showError('Помилка при отриманні інформації про товар: $e');
    }
  }

  void _showError(String message) async {
    setState(() {
      _errorMessage = message;
      _hasError = true;
      _showSuccess = false;
      _isScanning = false;
    });
    await Future.delayed(const Duration(milliseconds: 800));
    if (mounted) {
      setState(() {
        _hasError = false;
        _errorMessage = '';
      });
    }
  }

  void _updateActualCount() {
    final newCount = int.tryParse(_actualCountController.text) ?? 0;
    if (_currentBarcode != null) {
      final sessionManager =
          Provider.of<RecountSessionManager>(context, listen: false);
      sessionManager.addOrUpdateProduct({
        'barcode': _currentBarcode!,
        'name': _productName!,
        'price': _productPrice!,
        'stock_count': _stockCount!,
        'actual_count': newCount,
        'replace': true,
      });
      setState(() {
        _actualCount = newCount;
      });
    }
  }

  void _closeProductPanel() {
    setState(() {
      _showProductPanel = false;
      _currentBarcode = null;
      _productName = null;
      _productPrice = null;
      _stockCount = null;
      _actualCount = null;
      _actualCountController.clear();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.close, color: Colors.white),
          onPressed: () => Navigator.of(context).pop(),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.list_alt, color: Colors.white),
            onPressed: () {
              final products =
                  Provider.of<RecountSessionManager>(context, listen: false)
                      .products;
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (context) => RecountProductListScreen(
                    products: products,
                    sessionNames: widget.sessionNames,
                  ),
                ),
              );
            },
          ),
        ],
      ),
      body: Stack(
        children: [
          PlatformBarcodeScanner(
            onBarcodeDetected: _onBarcodeDetected,
            torchEnabled: _torchOn,
            onTorchToggle: _onTorchToggle,
          ),
          Container(
            decoration: const BoxDecoration(
              color: Color.fromARGB(128, 0, 0, 0),
            ),
            child: Stack(
              children: [
                Center(
                  child: AnimatedBuilder(
                    animation: _borderAnimation,
                    builder: (context, child) {
                      return Container(
                        width: 250,
                        height: 250,
                        decoration: BoxDecoration(
                          border: Border.all(
                            color: _isScanning ? Colors.green : Colors.white,
                            width: _borderAnimation.value,
                          ),
                          borderRadius: BorderRadius.circular(12),
                        ),
                      );
                    },
                  ),
                ),
                Positioned(
                  top: MediaQuery.of(context).padding.top + 60,
                  left: 0,
                  right: 0,
                  child: Center(
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 20, vertical: 10),
                      decoration: BoxDecoration(
                        color: const Color.fromARGB(204, 38, 50, 56), // blueGrey.shade900.withOpacity(0.8)
                        borderRadius: BorderRadius.circular(30),
                      ),
                      child: Text(
                        _isScanning ? 'Обробка...' : 'Наведіть камеру на штрихкод у рамці',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          shadows: [
                            Shadow(
                              blurRadius: 3,
                              color: Colors.black54,
                              offset: Offset(0, 1),
                            )
                          ],
                        ),
                      ),
                    ),
                  ),
                ),

              ],
            ),
          ),
          if (_showProductPanel)
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              child: Container(
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Color(0xFFF8F9FA), // Light grey-white
                      Color(0xFFFFFFFF), // Pure white
                    ],
                  ),
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(24),
                    topRight: Radius.circular(24),
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withAlpha(63),
                      blurRadius: 20,
                      offset: const Offset(0, -5),
                      spreadRadius: 0,
                    ),
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      padding: const EdgeInsets.fromLTRB(20, 20, 16, 16),
                      decoration: const BoxDecoration(
                        color: Color(0xFF2E7D32), // Dark green
                        borderRadius: BorderRadius.only(
                          topLeft: Radius.circular(24),
                          topRight: Radius.circular(24),
                        ),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: Colors.white.withAlpha(63),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: const Icon(
                                  Icons.check_circle,
                                  color: Colors.white,
                                  size: 20,
                                ),
                              ),
                              const SizedBox(width: 12),
                              const Text(
                                'Товар знайдено',
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                ),
                              ),
                            ],
                          ),
                          Container(
                            decoration: BoxDecoration(
                              color: Colors.white.withAlpha(63),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: IconButton(
                              onPressed: _closeProductPanel,
                              icon: const Icon(
                                Icons.close,
                                color: Colors.white,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: const Color(0xFFF1F8E9), // Light green background
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: const Color(0xFF4CAF50).withAlpha(63),
                                width: 1,
                              ),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  _productName ?? '',
                                  style: const TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w600,
                                    color: Color(0xFF1B5E20), // Dark green text
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 12,
                                    vertical: 6,
                                  ),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFF4CAF50),
                                    borderRadius: BorderRadius.circular(20),
                                  ),
                                  child: Text(
                                    'Ціна: ${_productPrice?.toStringAsFixed(2) ?? ''} грн',
                                    style: const TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w600,
                                      color: Colors.white,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 8,
                                        vertical: 4,
                                      ),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFF1976D2),
                                        borderRadius: BorderRadius.circular(16),
                                      ),
                                      child: const Text(
                                        'Фактична кількість',
                                        style: TextStyle(
                                          fontSize: 12,
                                          fontWeight: FontWeight.w600,
                                          color: Colors.white,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Container(
                                      decoration: BoxDecoration(
                                        borderRadius: BorderRadius.circular(12),
                                        boxShadow: [
                                          BoxShadow(
                                            color: Colors.black.withAlpha(13),
                                            blurRadius: 8,
                                            offset: const Offset(0, 2),
                                          ),
                                        ],
                                      ),
                                      child: TextField(
                                        controller: _actualCountController,
                                        keyboardType: TextInputType.number,
                                        onChanged: (value) => _updateActualCount(),
                                        style: const TextStyle(
                                          fontSize: 16,
                                          fontWeight: FontWeight.w600,
                                          color: Color(0xFF1976D2),
                                        ),
                                        decoration: InputDecoration(
                                          filled: true,
                                          fillColor: Colors.white,
                                          border: OutlineInputBorder(
                                            borderRadius: BorderRadius.circular(12),
                                            borderSide: BorderSide(
                                              color: const Color(0xFF1976D2).withAlpha(63),
                                              width: 2,
                                            ),
                                          ),
                                          enabledBorder: OutlineInputBorder(
                                            borderRadius: BorderRadius.circular(12),
                                            borderSide: BorderSide(
                                              color: const Color(0xFF1976D2).withAlpha(63),
                                              width: 2,
                                            ),
                                          ),
                                          focusedBorder: OutlineInputBorder(
                                            borderRadius: BorderRadius.circular(12),
                                            borderSide: const BorderSide(
                                              color: Color(0xFF1976D2),
                                              width: 2,
                                            ),
                                          ),
                                          contentPadding: const EdgeInsets.symmetric(
                                            horizontal: 16,
                                            vertical: 16,
                                          ),
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
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 8,
                                        vertical: 4,
                                      ),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFFFF9800),
                                        borderRadius: BorderRadius.circular(16),
                                      ),
                                      child: const Text(
                                        'Залишок по базі',
                                        style: TextStyle(
                                          fontSize: 12,
                                          fontWeight: FontWeight.w600,
                                          color: Colors.white,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 16,
                                        vertical: 16,
                                      ),
                                      decoration: BoxDecoration(
                                        gradient: const LinearGradient(
                                          colors: [
                                            Color(0xFFFFF3E0),
                                            Color(0xFFFFE0B2),
                                          ],
                                        ),
                                        border: Border.all(
                                          color: const Color(0xFFFF9800).withAlpha(63),
                                          width: 2,
                                        ),
                                        borderRadius: BorderRadius.circular(12),
                                        boxShadow: [
                                          BoxShadow(
                                            color: Colors.black.withAlpha(13), // 0.05 * 255 ≈ 13
                                            blurRadius: 8,
                                            offset: const Offset(0, 2),
                                          ),
                                        ],
                                      ),
                                      width: double.infinity,
                                      child: Text(
                                        _stockCount?.toString() ?? '0',
                                        style: const TextStyle(
                                          fontSize: 16,
                                          fontWeight: FontWeight.w600,
                                          color: Color(0xFFE65100),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 8),
                  ],
                ),
              ),
            ),
          // Success overlay - matching scan.dart design
          if (_showSuccess)
            Positioned.fill(
              child: AnimatedOpacity(
                duration: const Duration(milliseconds: 300),
                opacity: _showSuccess ? 1.0 : 0.0,
                child: Container(
                  color: Colors.black54,
                  child: const Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.check_circle,
                          color: Colors.greenAccent,
                          size: 80,
                        ),
                        SizedBox(height: 16),
                        Text(
                          'УСПІШНО СКАНОВАНО',
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 18,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          // Error overlay - matching scan.dart design
          if (_hasError)
            Positioned(
              bottom: 80,
              left: 24,
              right: 24,
              child: Container(
                padding: const EdgeInsets.symmetric(
                    vertical: 12, horizontal: 20),
                decoration: BoxDecoration(
                  color: const Color.fromARGB(229, 255, 82, 82), // redAccent.withOpacity(0.9)
                  borderRadius: BorderRadius.circular(25),
                  boxShadow: const [
                    BoxShadow(
                      color: Color.fromARGB(128, 255, 82, 82), // redAccent.withOpacity(0.5)
                      blurRadius: 12,
                      offset: Offset(0, 3),
                    ),
                  ],
                ),
                child: Text(
                  _errorMessage.isEmpty
                      ? 'Помилка сканування'
                      : _errorMessage,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                    fontSize: 16,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
