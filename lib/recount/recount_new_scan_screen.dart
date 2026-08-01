import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:provider/provider.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;

import 'package:vibration/vibration.dart';
import '../services/network_service.dart';
import '../services/api_config.dart';
import '../services/session_storage.dart';
import '../utils/scan_window.dart';
import 'recount_session_manager.dart';
import 'recount_product_list_screen.dart';

class RecountNewScanScreen extends StatefulWidget {
  final String sessionId;
  final List<String> sessionIds;

  const RecountNewScanScreen({
    Key? key,
    required this.sessionId,
    required this.sessionIds,
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

  late RecountSessionManager _sessionManager;

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
    _sessionManager =
        Provider.of<RecountSessionManager>(context, listen: false);
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

    setState(() => _isScanning = false);

    try {
      if (await Vibration.hasVibrator()) {
        try {
          Vibration.vibrate(duration: 100);
        } catch (_) {}
      }
      await _processBarcode(barcode.rawValue!);
      if (!mounted) return;
    } catch (_) {
      _showError('Помилка при обробці штрихкоду');
    }
  }

  Future<void> _processBarcode(String barcode) async {
    final networkService = NetworkService.instance;
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
      final response = await http
          .get(Uri.parse(
            ApiConfig.productUrl(barcode),
          ))
          .timeout(const Duration(seconds: 10));

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
            _productPrice =
                double.tryParse(productInfo['price']?.toString() ?? '0') ?? 0.0;
            _stockCount = int.tryParse(storeData['remaining'].toString()) ?? 0;
            _actualCount = newActualCount;
            _actualCountController.text = _actualCount.toString();
            _showProductPanel = true;
          });

          _sessionManager.recordScan({
            'barcode': barcode,
            'name': _productName!,
            'price': _productPrice!,
            'stock_count': _stockCount!,
            'actual_count': 1,
          });
        } else {
          _showError('Товар не знайдено в базі даних');
        }
      } else {
        _showError('Сервер тимчасово недоступний. Спробуйте ще раз.');
      }
    } catch (_) {
      _showError('Не вдалося отримати інформацію про товар. Спробуйте ще раз.');
    }
  }

  void _showError(String message) {
    setState(() {
      _errorMessage = message;
      _hasError = true;
      _readyToScan = true;
      _isScanning = false;
    });
    Future.delayed(const Duration(milliseconds: 2500), () {
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
      _sessionManager.setActualCount({
        'barcode': _currentBarcode!,
        'name': _productName!,
        'price': _productPrice!,
        'stock_count': _stockCount!,
        'actual_count': newCount,
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
    setState(() {
      _isScanning = false;
      _readyToScan = true;
    });
    final controller = TextEditingController();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF1E1E1E),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (sheetContext) => Padding(
        padding: EdgeInsets.fromLTRB(
          20,
          12,
          20,
          20 + MediaQuery.viewInsetsOf(sheetContext).bottom,
        ),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 38,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.white24,
                  borderRadius: BorderRadius.circular(99),
                ),
              ),
              const SizedBox(height: 20),
              Container(
                width: 50,
                height: 50,
                decoration: BoxDecoration(
                  color: Colors.orangeAccent.withAlpha(32),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.keyboard_outlined,
                  color: Colors.orangeAccent,
                  size: 26,
                ),
              ),
              const SizedBox(height: 12),
              const Text(
                'Ввести штрихкод',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 6),
              const Text(
                'Введіть цифри зі штрихкоду товару',
                style: TextStyle(color: Colors.white60, fontSize: 14),
              ),
              const SizedBox(height: 20),
              TextField(
                controller: controller,
                keyboardType: TextInputType.number,
                textInputAction: TextInputAction.search,
                onSubmitted: (_) =>
                    _searchManualBarcode(controller, sheetContext),
                autofocus: true,
                style: const TextStyle(color: Colors.white, fontSize: 18),
                decoration: InputDecoration(
                  hintText: '2107002621030',
                  hintStyle: const TextStyle(color: Colors.white30),
                  prefixIcon: const Icon(Icons.barcode_reader, color: Colors.white54),
                  filled: true,
                  fillColor: const Color(0xFF2A2A2A),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: BorderSide.none,
                  ),
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                ),
              ),
              const SizedBox(height: 14),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () =>
                      _searchManualBarcode(controller, sheetContext),
                  icon: const Icon(Icons.search_rounded),
                  label: const Text('Пошук'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.orangeAccent,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    minimumSize: const Size.fromHeight(52),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                ),
              ),
              TextButton(
                onPressed: () => Navigator.pop(sheetContext),
                style: TextButton.styleFrom(foregroundColor: Colors.white60),
                child: const Text('Скасувати'),
              ),
            ],
          ),
        ),
      ),
    ).whenComplete(controller.dispose);
  }

  void _searchManualBarcode(
      TextEditingController controller, BuildContext sheetContext) {
    final barcode = controller.text.trim();
    if (barcode.isEmpty) return;

    Navigator.pop(sheetContext);
    _startSingleScan();
    _processBarcode(barcode);
  }

  Widget _buildCountSummary({
    required String label,
    required String value,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
      decoration: BoxDecoration(
        color: color.withAlpha(25),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withAlpha(80)),
      ),
      child: Column(
        children: [
          Text(
            label,
            style: TextStyle(
                fontSize: 13, color: color, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 10),
          Text(
            value,
            style: TextStyle(
                fontSize: 24, color: color, fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final scanWindow = ScanWindow.forPreview(MediaQuery.of(context).size);
    final boxSize = scanWindow.width;
    final boxTop = scanWindow.top;

    return Scaffold(
      backgroundColor: Colors.black,
      resizeToAvoidBottomInset: false,
      appBar: AppBar(
        backgroundColor: const Color(0xFF121212),
        elevation: 0,
        title: const Text('Переоблік'),
        leading: IconButton(
          icon: const Icon(Icons.close, color: Colors.white),
          onPressed: () {
            final count = _sessionManager.products.length;
            if (count == 0) {
              final sid = _sessionManager.currentSessionId;
              _sessionManager.clear();
              if (sid != null) {
                context.read<SessionStorage>().deleteSession(sid);
              }
              Navigator.of(context).pop();
              return;
            }
            showDialog(
              context: context,
              builder: (dialogContext) => Dialog(
                backgroundColor: const Color(0xFF1E1E1E),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(24)),
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 48,
                        height: 48,
                        decoration: BoxDecoration(
                          color: Colors.orangeAccent.withAlpha(30),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.pause_circle_outline,
                            color: Colors.orangeAccent, size: 28),
                      ),
                      const SizedBox(height: 16),
                      const Text('Відкласти переоблік?',
                          style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w700,
                              fontSize: 20)),
                      const SizedBox(height: 8),
                      Text('$count товарів буде збережено у цій сесії.',
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                              color: Colors.white60, fontSize: 14)),
                      const SizedBox(height: 24),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: () async {
                            Navigator.pop(dialogContext);
                            final nav = Navigator.of(context);
                            await _saveSession();
                            nav.pop();
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.orangeAccent,
                            foregroundColor: Colors.white,
                          ),
                          child: const Text('Зберегти та вийти'),
                        ),
                      ),
                      const SizedBox(height: 8),
                      SizedBox(
                        width: double.infinity,
                        child: TextButton(
                          onPressed: () => Navigator.pop(dialogContext),
                          child: const Text('Продовжити',
                              style: TextStyle(color: Colors.white70)),
                        ),
                      ),
                      TextButton(
                        onPressed: () async {
                          Navigator.pop(dialogContext);
                          final sessionId = _sessionManager.currentSessionId;
                          final storage = context.read<SessionStorage>();
                          final nav = Navigator.of(context);
                          _sessionManager.clear();
                          if (sessionId != null) {
                            await storage.deleteSession(sessionId);
                          }
                          nav.pop();
                        },
                        child: const Text('Вийти без збереження',
                            style: TextStyle(color: Colors.redAccent)),
                      ),
                    ],
                  ),
                ),
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
                    sessionIds: widget.sessionIds,
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
              scanWindow: scanWindow,
              onDetect: _onBarcodeDetected,
              errorBuilder: (context, error) => Center(
                child: Container(
                  margin: const EdgeInsets.all(24),
                  padding: const EdgeInsets.fromLTRB(24, 28, 24, 20),
                  decoration: BoxDecoration(
                    color: const Color(0xFF1E1E1E),
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(color: Colors.white12),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        width: 60,
                        height: 60,
                        decoration: const BoxDecoration(
                          color: Color(0x1FCF6679),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.videocam_off_outlined,
                            size: 30, color: Color(0xFFCF6679)),
                      ),
                      const SizedBox(height: 18),
                      const Text(
                        'Камера недоступна',
                        style: TextStyle(
                            color: Colors.white,
                            fontSize: 20,
                            fontWeight: FontWeight.w700),
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'Надайте дозвіл на камеру в налаштуваннях\nабо переконайтеся, що вона не зайнята.',
                        style: TextStyle(color: Colors.white60, fontSize: 14),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 22),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          onPressed: () => _controller.start(),
                          icon: const Icon(Icons.refresh_rounded),
                          label: const Text('Спробувати знову'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.orangeAccent,
                            foregroundColor: Colors.white,
                            elevation: 0,
                            minimumSize: const Size.fromHeight(50),
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14)),
                          ),
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
                    final color =
                        _hasError ? Colors.redAccent : Colors.orangeAccent;
                    final w = _hasError ? 4.0 : _borderAnimation.value;
                    return CustomPaint(
                      size: Size(boxSize, boxSize),
                      painter: _ScanCornersPainter(
                          color: color, width: w, cornerSize: 30),
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
                    padding: const EdgeInsets.symmetric(
                        horizontal: 20, vertical: 10),
                    decoration: BoxDecoration(
                      color: Colors.black54,
                      borderRadius: BorderRadius.circular(30),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.touch_app_outlined,
                            size: 17, color: Colors.orangeAccent),
                        SizedBox(width: 8),
                        Text(
                          'Торкніться екрана, щоб сканувати',
                          style: TextStyle(
                              color: Colors.white,
                              fontSize: 14,
                              fontWeight: FontWeight.w600),
                        ),
                      ],
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
                    padding: const EdgeInsets.symmetric(
                        horizontal: 20, vertical: 10),
                    decoration: BoxDecoration(
                      color: Colors.orangeAccent.withAlpha(51),
                      borderRadius: BorderRadius.circular(30),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        SizedBox(
                            width: 14,
                            height: 14,
                            child: CircularProgressIndicator(
                                strokeWidth: 2, color: Colors.white)),
                        SizedBox(width: 10),
                        Text('Шукаємо штрихкод...',
                            style: TextStyle(
                                color: Colors.white,
                                fontSize: 14,
                                fontWeight: FontWeight.w600)),
                      ],
                    ),
                  ),
                ),
              ),
            if (!_showProductPanel)
              Positioned(
                left: 24,
                right: 24,
                bottom: 24,
                child: SafeArea(
                  top: false,
                  child: Container(
                    height: 56,
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    decoration: BoxDecoration(
                      color: const Color(0xE61E1E1E),
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(color: Colors.white24),
                    ),
                    child: Row(
                      children: [
                        IconButton(
                          onPressed: _toggleTorch,
                          tooltip: _torchOn
                              ? 'Вимкнути ліхтарик'
                              : 'Увімкнути ліхтарик',
                          icon: Icon(_torchOn
                              ? Icons.flash_on_rounded
                              : Icons.flash_off_rounded),
                          color: _torchOn ? Colors.orangeAccent : Colors.white70,
                        ),
                        const SizedBox(
                          height: 28,
                          child: VerticalDivider(color: Colors.white24),
                        ),
                        const SizedBox(width: 4),
                        Expanded(
                          child: TextButton.icon(
                            onPressed: _showManualEntry,
                            icon: const Icon(Icons.keyboard_outlined, size: 20),
                            label: const Text('Ввести вручну'),
                            style: TextButton.styleFrom(
                                foregroundColor: Colors.white70),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            if (_showProductPanel)
              AnimatedPositioned(
                duration: const Duration(milliseconds: 220),
                curve: Curves.easeOut,
                bottom: MediaQuery.viewInsetsOf(context).bottom,
                left: 0,
                right: 0,
                child: SafeArea(
                  top: false,
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
                    decoration: BoxDecoration(
                      color: const Color(0xFF1E1E1E),
                      borderRadius: const BorderRadius.only(
                        topLeft: Radius.circular(28),
                        topRight: Radius.circular(28),
                      ),
                      boxShadow: [
                        BoxShadow(
                            color: Colors.black.withAlpha(160),
                            blurRadius: 20,
                            offset: const Offset(0, -5)),
                      ],
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              width: 42,
                              height: 42,
                              decoration: BoxDecoration(
                                color: Colors.green.withAlpha(38),
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(Icons.check_circle,
                                  color: Colors.greenAccent, size: 25),
                            ),
                            const SizedBox(width: 12),
                            const Expanded(
                              child: Text(
                                'Товар відскановано',
                                style: TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.w700,
                                    color: Colors.white),
                              ),
                            ),
                            IconButton(
                              onPressed: _closeProductPanel,
                              icon: const Icon(Icons.close,
                                  color: Colors.white54),
                              tooltip: 'Закрити',
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Text(
                          _productName ?? '',
                          style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w700,
                              color: Colors.white),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            const Icon(Icons.qr_code,
                                size: 16, color: Colors.white38),
                            const SizedBox(width: 6),
                            Expanded(
                              child: Text(
                                _currentBarcode ?? '',
                                style: const TextStyle(
                                    color: Colors.white54, fontSize: 13),
                              ),
                            ),
                            Text(
                              '₴ ${_productPrice?.toStringAsFixed(2) ?? ''}',
                              style: const TextStyle(
                                  fontSize: 15,
                                  color: Colors.greenAccent,
                                  fontWeight: FontWeight.w700),
                            ),
                          ],
                        ),
                        const SizedBox(height: 18),
                        Row(
                          children: [
                            Expanded(
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 12, vertical: 8),
                                decoration: BoxDecoration(
                                  color: Colors.blue.withAlpha(30),
                                  borderRadius: BorderRadius.circular(14),
                                  border: Border.all(
                                      color: Colors.blue.withAlpha(90)),
                                ),
                                child: Column(
                                  children: [
                                    Text('Фактично',
                                        style: TextStyle(
                                            fontSize: 13,
                                            color: Colors.blue.shade100,
                                            fontWeight: FontWeight.w600)),
                                    TextField(
                                      controller: _actualCountController,
                                      keyboardType: TextInputType.number,
                                      textInputAction: TextInputAction.done,
                                      onTap: () => _actualCountController
                                          .selection = TextSelection(
                                        baseOffset: 0,
                                        extentOffset:
                                            _actualCountController.text.length,
                                      ),
                                      onChanged: (_) => _updateActualCount(),
                                      onSubmitted: (_) =>
                                          FocusScope.of(context).unfocus(),
                                      style: const TextStyle(
                                          fontSize: 30,
                                          fontWeight: FontWeight.bold,
                                          color: Colors.white),
                                      textAlign: TextAlign.center,
                                      decoration: const InputDecoration(
                                        isDense: true,
                                        border: InputBorder.none,
                                        contentPadding:
                                            EdgeInsets.symmetric(vertical: 6),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: _buildCountSummary(
                                label: 'Залишок',
                                value: _stockCount?.toString() ?? '0',
                                color: Colors.orangeAccent,
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: _buildCountSummary(
                                label: 'Різниця',
                                value:
                                    _actualCount != null && _stockCount != null
                                        ? (_actualCount! - _stockCount! >= 0
                                            ? '+${_actualCount! - _stockCount!}'
                                            : '${_actualCount! - _stockCount!}')
                                        : '0',
                                color: (_actualCount ?? 0) > (_stockCount ?? 0)
                                    ? Colors.greenAccent
                                    : (_actualCount ?? 0) < (_stockCount ?? 0)
                                        ? Colors.redAccent
                                        : Colors.white54,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            if (_hasError && !_showProductPanel)
              Positioned(
                bottom: 100,
                left: 24,
                right: 24,
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(vertical: 12, horizontal: 20),
                  decoration: BoxDecoration(
                    color: const Color(0xFF93000A),
                    borderRadius: BorderRadius.circular(25),
                    boxShadow: const [
                      BoxShadow(
                          color: Color(0xFFCF6679),
                          blurRadius: 12,
                          offset: Offset(0, 3)),
                    ],
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.error_outline,
                          color: Color(0xFFCF6679), size: 22),
                      const SizedBox(width: 10),
                      Flexible(
                        child: Text(
                          _errorMessage.isEmpty
                              ? 'Помилка сканування'
                              : _errorMessage,
                          style: const TextStyle(
                              color: Color(0xFFFFDAD6),
                              fontWeight: FontWeight.w600,
                              fontSize: 14),
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
    final fullPath = Path()
      ..addRect(Rect.fromLTWH(0, 0, size.width, size.height));
    final centerX = size.width / 2;
    final boxLeft = centerX - boxSize / 2;
    final boxPath = Path()
      ..addRect(Rect.fromLTWH(boxLeft, boxTop, boxSize, boxSize));
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

  _ScanCornersPainter(
      {required this.color, required this.width, required this.cornerSize});

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
    canvas.drawLine(
        Offset(size.width - cornerSize, 0), Offset(size.width, 0), paint);
    canvas.drawLine(
        Offset(size.width, 0), Offset(size.width, cornerSize), paint);
    // Bottom-left
    canvas.drawLine(
        Offset(0, size.height - cornerSize), Offset(0, size.height), paint);
    canvas.drawLine(
        Offset(0, size.height), Offset(cornerSize, size.height), paint);
    // Bottom-right
    canvas.drawLine(Offset(size.width - cornerSize, size.height),
        Offset(size.width, size.height), paint);
    canvas.drawLine(Offset(size.width, size.height),
        Offset(size.width, size.height - cornerSize), paint);
  }

  @override
  bool shouldRepaint(_ScanCornersPainter oldDelegate) =>
      oldDelegate.color != color || oldDelegate.width != width;
}
