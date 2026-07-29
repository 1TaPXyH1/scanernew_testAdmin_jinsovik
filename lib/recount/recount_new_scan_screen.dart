import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:provider/provider.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;

import 'package:vibration/vibration.dart';
import '../services/network_service.dart';
import '../services/api_config.dart';
import '../services/session_storage.dart';
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

  late final RecountSessionManager _sessionManager;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _borderAnimationController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);
    _borderAnimation = Tween<double>(begin: 3, end: 6).animate(
      CurvedAnimation(
        parent: _borderAnimationController,
        curve: Curves.easeInOut,
      ),
    );
    _controller.start();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _sessionManager = Provider.of<RecountSessionManager>(context, listen: false);
  }

  @override
  void activate() {
    super.activate();
    _controller.start();
  }

  @override
  void deactivate() {
    _controller.stop();
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
    if (_sessionManager.currentSessionId != null) {
      await _sessionManager.saveSessionSnapshot();
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

    final barcode = capture.barcodes.first;
    if (barcode.rawValue == null || barcode.rawValue!.isEmpty) return;

    if (barcode.corners.isNotEmpty && capture.size != Size.zero) {
      final cx = barcode.corners.map((o) => o.dx).reduce((a, b) => a + b) / barcode.corners.length;
      final cy = barcode.corners.map((o) => o.dy).reduce((a, b) => a + b) / barcode.corners.length;
      final zoneW = capture.size.width * 0.4;
      final zoneH = capture.size.height * 0.4;
      final imgCx = capture.size.width / 2;
      final imgCy = capture.size.height / 2;
      if ((cx - imgCx).abs() > zoneW || (cy - imgCy).abs() > zoneH) return;
    }

    setState(() => _isScanning = false);

    try {
      if (await Vibration.hasVibrator()) {
        try { Vibration.vibrate(duration: 100); } catch (_) {}
      }
      await _processBarcode(barcode.rawValue!);
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
      )).timeout(const Duration(seconds: 10));

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
          final existingProduct = _sessionManager.products.firstWhere(
            (p) => p['barcode'] == barcode,
            orElse: () => {},
          );

          final currentActualCount = existingProduct.isNotEmpty
              ? (existingProduct['actual_count'] ?? 0)
              : 0;
          final newActualCount = currentActualCount + 1;

          setState(() {
            _isScanning = false;
            _currentBarcode = barcode;
            _productName = productInfo['good'] ?? 'Невідомий товар';
            _productPrice = double.tryParse(productInfo['price']?.toString() ?? '0') ?? 0.0;
            _stockCount = int.tryParse(storeData['remaining'].toString()) ?? 0;
            _actualCount = newActualCount;
            _actualCountController.text = _actualCount.toString();
            _showProductPanel = true;
          });

          _sessionManager.addOrUpdateProduct({
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
      _sessionManager.addOrUpdateProduct({
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
      _isScanning = false;
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

  void _showManualEntry() {
    final controller = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1E1E1E),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Ввести штрихкод', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        content: TextField(
          controller: controller,
          keyboardType: TextInputType.number,
          style: const TextStyle(color: Colors.white, fontSize: 18),
          decoration: InputDecoration(
            hintText: '2107002621030',
            hintStyle: const TextStyle(color: Colors.white30),
            filled: true,
            fillColor: const Color(0xFF2A2A2A),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          ),
          autofocus: true,
        ),
        actions: [
          TextButton(
            onPressed: () {
              controller.dispose();
              Navigator.pop(ctx);
            },
            child: const Text('Скасувати', style: TextStyle(color: Colors.white54)),
          ),
          ElevatedButton(
            onPressed: () {
              final barcode = controller.text.trim();
              controller.dispose();
              if (barcode.isNotEmpty) {
                Navigator.pop(ctx);
                _startSingleScan();
                _processBarcode(barcode);
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.orangeAccent),
            child: const Text('Пошук', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final screenHeight = MediaQuery.of(context).size.height;
    final boxSize = screenWidth * 0.72;
    final boxTop = screenHeight * 0.1;

    return Scaffold(
      backgroundColor: Colors.black,
      resizeToAvoidBottomInset: false,
      appBar: AppBar(
        backgroundColor: Colors.black,
        elevation: 0,
          leading: IconButton(
            icon: const Icon(Icons.close, color: Colors.white),
            onPressed: () {
              final count = _sessionManager.products.length;
              if (count == 0) {
                final sid = _sessionManager.currentSessionId;
                _sessionManager.clear();
                if (sid != null) {
                  Provider.of<SessionStorage>(context, listen: false).deleteSession(sid);
                }
                Navigator.of(context).pop();
                return;
              }
              showDialog(
                context: context,
                builder: (ctx) => AlertDialog(
                  backgroundColor: const Color(0xFF1E1E1E),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                  title: const Text('Відкласти переоблік?', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18)),
                  content: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(Icons.inventory, size: 18, color: Colors.orangeAccent),
                            const SizedBox(width: 6),
                          Text('$count товарів', style: const TextStyle(color: Colors.white70, fontSize: 14)),
                        ],
                      ),
                    ],
                  ),
                  actions: [
                    TextButton(
                      onPressed: () async {
                        Navigator.pop(ctx);
                        final nav = Navigator.of(context);
                        await _saveSession();
                        nav.pop();
                      },
                      child: const Text('Зберегти та вийти', style: TextStyle(color: Colors.orangeAccent, fontWeight: FontWeight.w600)),
                    ),
                    const SizedBox(height: 4),
                    TextButton(
                      onPressed: () async {
                        Navigator.pop(ctx);
                        final sessionId = _sessionManager.currentSessionId;
                        final storage = Provider.of<SessionStorage>(context, listen: false);
                        final nav = Navigator.of(context);
                        _sessionManager.clear();
                        if (sessionId != null) {
                          await storage.deleteSession(sessionId);
                        }
                        nav.pop();
                      },
                      child: const Text('Не зберігати', style: TextStyle(color: Colors.redAccent)),
                    ),
                    TextButton(
                      onPressed: () => Navigator.pop(ctx),
                      child: const Text('Продовжити', style: TextStyle(color: Colors.white54)),
                    ),
                  ],
                ),
              );
            },
          ),
        actions: [
          IconButton(
            icon: const Icon(Icons.list_alt, color: Colors.white),
            onPressed: () {
              _controller.stop();
              final products = _sessionManager.products;
              final nav = Navigator.of(context);
              nav
                  .push(
                    MaterialPageRoute(
                      builder: (context) => RecountProductListScreen(
                        products: products,
                        sessionNames: widget.sessionNames,
                      ),
                    ),
                  )
                  .then((result) {
                    if (result == 'finish') {
                      nav.pop();
                    } else {
                      _controller.start();
                    }
                  });
            },
          ),
        ],
      ),
      body: GestureDetector(
        onTap: () {
          FocusScope.of(context).unfocus();
          if (_readyToScan) _startSingleScan();
        },
        child: Stack(
          children: [
            MobileScanner(
              controller: _controller,
              onDetect: _onBarcodeDetected,
              errorBuilder: (context, error) => Center(
                child: Padding(
                  padding: const EdgeInsets.all(32),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.videocam_off_outlined, size: 64, color: Color(0xFFCF6679)),
                      const SizedBox(height: 16),
                      const Text(
                        'Камера недоступна',
                        style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'Надайте дозвіл на камеру в налаштуваннях\nабо переконайтесь що вона не зайнята',
                        style: TextStyle(color: Colors.white60, fontSize: 14),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 24),
                      ElevatedButton.icon(
                        onPressed: () => _controller.start(),
                        icon: const Icon(Icons.refresh, size: 20),
                        label: const Text('Спробувати знову'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.orangeAccent,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            ClipPath(
              clipper: _ScanOverlayClipper(boxTop: boxTop, boxSize: boxSize),
              child: Container(color: Colors.black.withAlpha(179)),
            ),
            Positioned(
              top: boxTop,
              left: 0,
              right: 0,
              child: Center(
                child: AnimatedBuilder(
                  animation: _borderAnimation,
                  builder: (context, child) {
                    final color = _hasError ? Colors.redAccent : Colors.orangeAccent;
                    final w = _hasError ? 4.0 : _borderAnimation.value;
                    return CustomPaint(
                      size: Size(boxSize, boxSize),
                      painter: _ScanCornersPainter(color: color, width: w, cornerSize: 30),
                    );
                  },
                ),
              ),
            ),
            if (_readyToScan && !_showProductPanel)
              Positioned(
                top: boxTop + boxSize + 16,
                left: 0,
                right: 0,
                child: Center(
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                    decoration: BoxDecoration(
                      color: Colors.black54,
                      borderRadius: BorderRadius.circular(30),
                    ),
                    child: const Text(
                      'Натисніть на екран для сканування',
                      style: TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w600),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ),
              ),
            if (_isScanning)
              Positioned(
                top: boxTop + boxSize + 16,
                left: 0,
                right: 0,
                child: Center(
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                    decoration: BoxDecoration(
                      color: Colors.orangeAccent.withAlpha(51),
                      borderRadius: BorderRadius.circular(30),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)),
                        SizedBox(width: 10),
                        Text('Сканування...', style: TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w600)),
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
                backgroundColor: _torchOn ? Colors.orangeAccent : Colors.grey,
                child: Icon(_torchOn ? Icons.flash_on : Icons.flash_off),
              ),
            ),
            Positioned(
              right: 24,
              bottom: 48,
              child: TextButton.icon(
                onPressed: _showManualEntry,
                icon: const Icon(Icons.keyboard_outlined, color: Colors.white70, size: 22),
                label: const Text('Ввести', style: TextStyle(color: Colors.white70, fontSize: 14)),
              ),
            ),
            if (_showProductPanel)
              Positioned(
                bottom: 0,
                left: 0,
                right: 0,
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
                  decoration: BoxDecoration(
                    color: const Color(0xFF1E1E1E),
                    borderRadius: const BorderRadius.only(
                      topLeft: Radius.circular(20),
                      topRight: Radius.circular(20),
                    ),
                    boxShadow: [
                      BoxShadow(color: Colors.black.withAlpha(128), blurRadius: 16, offset: const Offset(0, -4)),
                    ],
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.qr_code, size: 14, color: Colors.white38),
                          const SizedBox(width: 4),
                          Text(
                            _currentBarcode ?? '',
                            style: const TextStyle(color: Colors.white38, fontSize: 12),
                          ),
                          const Spacer(),
                          SizedBox(
                            width: 28, height: 28,
                            child: IconButton(
                              padding: EdgeInsets.zero,
                              onPressed: _closeProductPanel,
                              icon: const Icon(Icons.close, color: Colors.white54, size: 18),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Text(
                        _productName ?? '',
                        style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Colors.white),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: Colors.green.withAlpha(25),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          '₴ ${_productPrice?.toStringAsFixed(2) ?? ''}',
                          style: const TextStyle(fontSize: 13, color: Colors.green, fontWeight: FontWeight.w600),
                        ),
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: GestureDetector(
                              onTap: () => _actualCountController.selection = TextSelection(
                                baseOffset: 0,
                                extentOffset: _actualCountController.text.length,
                              ),
                              child: Container(
                                padding: const EdgeInsets.all(10),
                                decoration: BoxDecoration(
                                  color: Colors.blue.withAlpha(25),
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(color: Colors.blue.withAlpha(77)),
                                ),
                                child: Column(
                                  children: [
                                    Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        const Icon(Icons.edit_outlined, size: 14, color: Colors.blue),
                                        const SizedBox(width: 4),
                                        Text(
                                          'Фактично',
                                          style: TextStyle(fontSize: 12, color: Colors.blue.shade200, fontWeight: FontWeight.w600),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 4),
                                    TextField(
                                      controller: _actualCountController,
                                      keyboardType: TextInputType.number,
                                      textInputAction: TextInputAction.done,
                                      onChanged: (value) => _updateActualCount(),
                                      onSubmitted: (_) => FocusScope.of(context).unfocus(),
                                      style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.white),
                                      textAlign: TextAlign.center,
                                      decoration: InputDecoration(
                                        filled: true,
                                        fillColor: Colors.transparent,
                                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide.none),
                                        contentPadding: const EdgeInsets.symmetric(vertical: 4),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Container(
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: Colors.orange.withAlpha(25),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: Colors.orange.withAlpha(77)),
                              ),
                              child: Column(
                                children: [
                                  const Text(
                                    'Залишок',
                                    style: TextStyle(fontSize: 12, color: Colors.orange, fontWeight: FontWeight.w600),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    _stockCount?.toString() ?? '0',
                                    style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.orangeAccent),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Container(
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: (_actualCount ?? 0) >= (_stockCount ?? 0)
                                    ? Colors.green.withAlpha(25)
                                    : Colors.red.withAlpha(25),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: (_actualCount ?? 0) >= (_stockCount ?? 0)
                                      ? Colors.green.withAlpha(77)
                                      : Colors.red.withAlpha(77),
                                ),
                              ),
                              child: Column(
                                children: [
                                  const Text(
                                    'Різниця',
                                    style: TextStyle(fontSize: 12, color: Colors.white54, fontWeight: FontWeight.w600),
                                  ),
                                  const SizedBox(height: 4),
                                  Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(
                                        (_actualCount ?? 0) > (_stockCount ?? 0)
                                            ? Icons.arrow_upward
                                            : (_actualCount ?? 0) < (_stockCount ?? 0)
                                                ? Icons.arrow_downward
                                                : Icons.remove,
                                        size: 16,
                                        color: (_actualCount ?? 0) > (_stockCount ?? 0)
                                            ? Colors.green
                                            : (_actualCount ?? 0) < (_stockCount ?? 0)
                                                ? Colors.red
                                                : Colors.grey,
                                      ),
                                      const SizedBox(width: 2),
                                      Text(
                                        _actualCount != null && _stockCount != null
                                            ? (_actualCount! - _stockCount! >= 0
                                                ? '+${_actualCount! - _stockCount!}'
                                                : '${_actualCount! - _stockCount!}')
                                            : '0',
                                        style: TextStyle(
                                          fontSize: 18,
                                          fontWeight: FontWeight.bold,
                                          color: (_actualCount ?? 0) > (_stockCount ?? 0)
                                              ? Colors.green
                                              : (_actualCount ?? 0) < (_stockCount ?? 0)
                                                  ? Colors.red
                                                  : Colors.grey,
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
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
                    color: const Color(0xFF93000A),
                    borderRadius: BorderRadius.circular(25),
                    boxShadow: const [
                      BoxShadow(color: Color(0xFFCF6679), blurRadius: 12, offset: Offset(0, 3)),
                    ],
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.error_outline, color: Color(0xFFCF6679), size: 22),
                      const SizedBox(width: 10),
                      Flexible(
                        child: Text(
                          _errorMessage.isEmpty ? 'Помилка сканування' : _errorMessage,
                          style: const TextStyle(color: Color(0xFFFFDAD6), fontWeight: FontWeight.w600, fontSize: 14),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _ScanOverlayClipper extends CustomClipper<Path> {
  final double boxTop;
  final double boxSize;

  _ScanOverlayClipper({required this.boxTop, required this.boxSize});

  @override
  Path getClip(Size size) {
    final fullPath = Path()..addRect(Rect.fromLTWH(0, 0, size.width, size.height));
    final centerX = size.width / 2;
    final boxLeft = centerX - boxSize / 2;
    final boxPath = Path()..addRect(Rect.fromLTWH(boxLeft, boxTop, boxSize, boxSize));
    return Path.combine(PathOperation.difference, fullPath, boxPath);
  }

  @override
  bool shouldReclip(_ScanOverlayClipper oldClipper) =>
      oldClipper.boxTop != boxTop || oldClipper.boxSize != boxSize;
}

class _ScanCornersPainter extends CustomPainter {
  final Color color;
  final double width;
  final double cornerSize;

  _ScanCornersPainter({required this.color, required this.width, required this.cornerSize});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = width
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    // Top-left
    canvas.drawLine(Offset(0, cornerSize), Offset.zero, paint);
    canvas.drawLine(Offset.zero, Offset(cornerSize, 0), paint);
    // Top-right
    canvas.drawLine(Offset(size.width - cornerSize, 0), Offset(size.width, 0), paint);
    canvas.drawLine(Offset(size.width, 0), Offset(size.width, cornerSize), paint);
    // Bottom-left
    canvas.drawLine(Offset(0, size.height - cornerSize), Offset(0, size.height), paint);
    canvas.drawLine(Offset(0, size.height), Offset(cornerSize, size.height), paint);
    // Bottom-right
    canvas.drawLine(Offset(size.width - cornerSize, size.height), Offset(size.width, size.height), paint);
    canvas.drawLine(Offset(size.width, size.height), Offset(size.width, size.height - cornerSize), paint);
  }

  @override
  bool shouldRepaint(_ScanCornersPainter oldDelegate) =>
      oldDelegate.color != color || oldDelegate.width != width;
}
