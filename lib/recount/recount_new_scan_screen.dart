import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:provider/provider.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;

import 'package:vibration/vibration.dart';
import '../services/network_service.dart';
import '../services/api_config.dart';
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
  final MobileScannerController _controller = MobileScannerController(
    detectionSpeed: DetectionSpeed.noDuplicates,
    facing: CameraFacing.back,
    torchEnabled: false,
  );
  bool _isScanning = false;
  bool _torchOn = false;
  bool _showProductPanel = false;
  bool _readyToScan = true;

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
    _controller.start();
  }

  @override
  void activate() {
    super.activate();
    _controller.start();
  }

  @override
  void deactivate() {
    WidgetsBinding.instance.addPostFrameCallback((_) => _controller.stop());
    super.deactivate();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _saveSession();
    _borderAnimationController.dispose();
    _controller.stop();
    _controller.dispose();
    _actualCountController.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    switch (state) {
      case AppLifecycleState.resumed:
        _controller.start();
        break;
      case AppLifecycleState.inactive:
      case AppLifecycleState.paused:
      case AppLifecycleState.detached:
        _saveSession();
        _controller.stop();
        break;
      case AppLifecycleState.hidden:
        break;
    }
  }

  Future<void> _saveSession() async {
    final sessionManager = Provider.of<RecountSessionManager>(context, listen: false);
    if (sessionManager.currentSessionId != null) {
      await sessionManager.saveSessionSnapshot();
    }
  }

  void _toggleTorch() {
    _controller.toggleTorch();
    setState(() => _torchOn = !_torchOn);
  }

  void _startSingleScan() {
    if (_isScanning || _showProductPanel) return;
    setState(() {
      _readyToScan = false;
      _isScanning = true;
    });
  }

  Future<void> _onBarcodeDetected(BarcodeCapture capture) async {
    if (!_isScanning || _showProductPanel) return;

    final barcode = capture.barcodes.first.rawValue;
    if (barcode == null || barcode.isEmpty) return;

    setState(() => _isScanning = false);

    try {
      if (await Vibration.hasVibrator()) {
        try { Vibration.vibrate(duration: 100); } catch (_) {}
      }
      await _processBarcode(barcode);
      if (!mounted) return;
    } catch (_) {
      _showError('Помилка при обробці штрихкоду');
    }
  }

  Future<void> _processBarcode(String barcode) async {
    final networkService = NetworkService();
    final isConnected = await networkService.isConnected();

    if (!isConnected) {
      _showError("Помилка інтернет з'єднання");
      return;
    }

    if (!barcode.startsWith('210700')) {
      _showError("Невірний штрихкод");
      return;
    }

    try {
      final response = await http.get(Uri.parse(
        ApiConfig.productUrl(barcode),
      ));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['success'] == true &&
            data['response'] is List &&
            data['response'].length == 2 &&
            data['response'][1] is List) {
          final productInfo = data['response'][0];
          final storesList = data['response'][1] as List;

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
            _showProductPanel = true;
          });

          sessionManager.addOrUpdateProduct({
            'barcode': barcode,
            'name': _productName!,
            'price': _productPrice!,
            'stock_count': _stockCount!,
            'actual_count': 1,
            'replace': false,
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

  void _showError(String message) {
    setState(() {
      _errorMessage = message;
      _hasError = true;
      _readyToScan = true;
      _isScanning = false;
    });
    Future.delayed(const Duration(milliseconds: 1500), () {
      if (mounted) {
        setState(() {
          _hasError = false;
          _errorMessage = '';
        });
      }
    });
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
      setState(() => _actualCount = newCount);
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
      _readyToScan = true;
    });
  }

  int get _productCount {
    try {
      return Provider.of<RecountSessionManager>(context, listen: false).products.length;
    } catch (_) {
      return 0;
    }
  }

  @override
  Widget build(BuildContext context) {
    final productCount = _productCount;

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.close, color: Colors.white),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: productCount > 0
            ? Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.orangeAccent.withAlpha(38),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Text(
                  '$productCount',
                  style: const TextStyle(
                    color: Colors.orangeAccent,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              )
            : null,
        actions: [
          IconButton(
            icon: const Icon(Icons.list_alt, color: Colors.white),
            onPressed: () {
              _controller.stop();
              final products =
                  Provider.of<RecountSessionManager>(context, listen: false).products;
              Navigator.of(context)
                  .push(
                    MaterialPageRoute(
                      builder: (context) => RecountProductListScreen(
                        products: products,
                        sessionNames: widget.sessionNames,
                      ),
                    ),
                  )
                  .then((_) => _controller.start());
            },
          ),
        ],
      ),
      body: GestureDetector(
        onTap: _readyToScan && !_showProductPanel ? _startSingleScan : null,
        child: Stack(
          children: [
            MobileScanner(
              controller: _controller,
              onDetect: _onBarcodeDetected,
            ),
            Container(color: Colors.black.withAlpha(179)),
            Center(
              child: AnimatedBuilder(
                animation: _borderAnimation,
                builder: (context, child) {
                  return Container(
                    width: 280,
                    height: 280,
                    decoration: BoxDecoration(
                      border: Border.all(
                        color: _hasError
                            ? Colors.redAccent
                            : (_isScanning ? Colors.greenAccent : Colors.orangeAccent),
                        width: _isScanning ? 3 : _borderAnimation.value,
                      ),
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [
                        BoxShadow(
                          color: (_hasError
                              ? Colors.redAccent
                              : (_isScanning ? Colors.greenAccent : Colors.orangeAccent))
                              .withAlpha(77),
                          blurRadius: 20,
                          spreadRadius: 2,
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
            if (_readyToScan && !_showProductPanel)
              Positioned(
                top: MediaQuery.of(context).padding.top + 60,
                left: 0,
                right: 0,
                child: Center(
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                    decoration: BoxDecoration(
                      color: Colors.black54,
                      borderRadius: BorderRadius.circular(30),
                    ),
                    child: const Text(
                      'Натисніть на екран для сканування',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ),
              ),
            if (_isScanning && !_showProductPanel)
              Positioned(
                top: MediaQuery.of(context).padding.top + 60,
                left: 0,
                right: 0,
                child: Center(
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                    decoration: BoxDecoration(
                      color: Colors.green.withAlpha(51),
                      borderRadius: BorderRadius.circular(30),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)),
                        SizedBox(width: 12),
                        Text(
                          'Сканування...',
                          style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w600),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            Positioned(
              left: 24,
              bottom: 48,
              child: FloatingActionButton(
                onPressed: _toggleTorch,
                tooltip: _torchOn ? 'Вимкнути ліхтарик' : 'Увімкнути ліхтарик',
                backgroundColor: _torchOn ? Colors.blueAccent : Colors.grey,
                child: Icon(_torchOn ? Icons.flash_on : Icons.flash_off),
              ),
            ),
            if (_showProductPanel)
              Positioned(
                bottom: 0,
                left: 0,
                right: 0,
                child: Container(
                  decoration: BoxDecoration(
                    color: const Color(0xFF1E1E1E),
                    borderRadius: const BorderRadius.only(
                      topLeft: Radius.circular(24),
                      topRight: Radius.circular(24),
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withAlpha(128),
                        blurRadius: 20,
                        offset: const Offset(0, -5),
                      ),
                    ],
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        padding: const EdgeInsets.fromLTRB(20, 16, 16, 12),
                        decoration: const BoxDecoration(
                          color: Color(0xFF2E7D32),
                          borderRadius: BorderRadius.only(
                            topLeft: Radius.circular(24),
                            topRight: Radius.circular(24),
                          ),
                        ),
                        child: Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: Colors.white.withAlpha(38),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: const Icon(Icons.check_circle, color: Colors.white, size: 20),
                            ),
                            const SizedBox(width: 12),
                            const Expanded(
                              child: Text(
                                'Відскановано',
                                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white),
                              ),
                            ),
                            Container(
                              decoration: BoxDecoration(
                                color: Colors.white.withAlpha(38),
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: IconButton(
                                onPressed: _closeProductPanel,
                                icon: const Icon(Icons.close, color: Colors.white, size: 20),
                              ),
                            ),
                          ],
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Container(
                              width: double.infinity,
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: Colors.green.withAlpha(25),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: Colors.green.withAlpha(77)),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    _productName ?? '',
                                    style: const TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w600,
                                      color: Colors.white,
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                    decoration: BoxDecoration(
                                      color: Colors.green,
                                      borderRadius: BorderRadius.circular(20),
                                    ),
                                    child: Text(
                                      'Ціна: ${_productPrice?.toStringAsFixed(2) ?? ''} грн',
                                      style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Colors.white),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 12),
                            Row(
                              children: [
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                        decoration: BoxDecoration(
                                          color: Colors.blue,
                                          borderRadius: BorderRadius.circular(16),
                                        ),
                                        child: const Text(
                                          'Фактична кількість',
                                          style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.white),
                                        ),
                                      ),
                                      const SizedBox(height: 6),
                                      Container(
                                        decoration: BoxDecoration(
                                          color: const Color(0xFF2A2A2A),
                                          borderRadius: BorderRadius.circular(12),
                                          border: Border.all(color: Colors.blue.withAlpha(77)),
                                        ),
                                        child: TextField(
                                          controller: _actualCountController,
                                          keyboardType: TextInputType.number,
                                          onChanged: (value) => _updateActualCount(),
                                          style: const TextStyle(
                                            fontSize: 24,
                                            fontWeight: FontWeight.bold,
                                            color: Colors.white,
                                          ),
                                          textAlign: TextAlign.center,
                                          decoration: InputDecoration(
                                            filled: true,
                                            fillColor: const Color(0xFF2A2A2A),
                                            border: OutlineInputBorder(
                                              borderRadius: BorderRadius.circular(12),
                                              borderSide: BorderSide.none,
                                            ),
                                            contentPadding: const EdgeInsets.symmetric(vertical: 16),
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
                                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                        decoration: BoxDecoration(
                                          color: Colors.orange,
                                          borderRadius: BorderRadius.circular(16),
                                        ),
                                        child: const Text(
                                          'Залишок по базі',
                                          style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.white),
                                        ),
                                      ),
                                      const SizedBox(height: 6),
                                      Container(
                                        padding: const EdgeInsets.symmetric(vertical: 16),
                                        decoration: BoxDecoration(
                                          color: const Color(0xFF2A2A2A),
                                          borderRadius: BorderRadius.circular(12),
                                          border: Border.all(color: Colors.orange.withAlpha(77)),
                                        ),
                                        width: double.infinity,
                                        child: Text(
                                          _stockCount?.toString() ?? '0',
                                          style: const TextStyle(
                                            fontSize: 24,
                                            fontWeight: FontWeight.bold,
                                            color: Colors.orangeAccent,
                                          ),
                                          textAlign: TextAlign.center,
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
                    ],
                  ),
                ),
              ),
            if (_hasError && !_showProductPanel)
              Positioned(
                bottom: 100,
                left: 24,
                right: 24,
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 20),
                  decoration: BoxDecoration(
                    color: Colors.redAccent.withAlpha(229),
                    borderRadius: BorderRadius.circular(25),
                    boxShadow: const [
                      BoxShadow(color: Colors.redAccent, blurRadius: 12, offset: Offset(0, 3)),
                    ],
                  ),
                  child: Text(
                    _errorMessage.isEmpty ? 'Помилка сканування' : _errorMessage,
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 16),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
