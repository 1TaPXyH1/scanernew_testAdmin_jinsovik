import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import '../services/network_service.dart';
import '../screens/home.dart';
import '../screens/result.dart';
import '../utils/scan_window.dart';

class ScanScreen extends StatefulWidget {
  final String selectedStore;
  const ScanScreen({super.key, required this.selectedStore});

  @override
  State<ScanScreen> createState() => _ScanScreenState();
}

class _ScanScreenState extends State<ScanScreen>
    with SingleTickerProviderStateMixin, WidgetsBindingObserver {
  final MobileScannerController controller = MobileScannerController(
    detectionSpeed: DetectionSpeed.noDuplicates,
    facing: CameraFacing.back,
    torchEnabled: false,
  );
  bool _isScanning = false;
  bool _torchOn = false;
  bool _readyToScan = true;

  bool _hasError = false;
  String _errorMessage = '';

  late final AnimationController _borderAnimationController;
  late final Animation<double> _borderAnimation;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    controller.start();
    _borderAnimationController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);
    _borderAnimation = Tween<double>(begin: 3, end: 6).animate(
      CurvedAnimation(parent: _borderAnimationController, curve: Curves.easeInOut),
    );
  }

  @override
  void activate() {
    super.activate();
    controller.start();
  }

  @override
  void deactivate() {
    controller.stop();
    super.deactivate();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _borderAnimationController.dispose();
    controller.stop();
    controller.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    switch (state) {
      case AppLifecycleState.resumed:
        controller.start();
        break;
      case AppLifecycleState.inactive:
      case AppLifecycleState.paused:
      case AppLifecycleState.detached:
        controller.stop();
        break;
      case AppLifecycleState.hidden:
        break;
    }
  }

  void _toggleTorch() {
    controller.toggleTorch();
    setState(() => _torchOn = !_torchOn);
  }

  void _startSingleScan() {
    if (_isScanning) return;
    setState(() {
      _readyToScan = false;
      _isScanning = true;
    });
  }

  Future<void> _onBarcodeDetected(BarcodeCapture capture) async {
    if (!_isScanning) return;

    final barcode = capture.barcodes.first;
    if (barcode.rawValue == null || barcode.rawValue!.isEmpty) return;

    setState(() => _isScanning = false);

    final code = barcode.rawValue!;
    final networkService = NetworkService.instance;
    final isConnected = await networkService.isConnected();

    if (!mounted) return;

    if (!isConnected) {
      _showError("Помилка інтернет з'єднання");
      return;
    }

    if (!code.startsWith('210700')) {
      _showError("Невірний штрихкод");
      return;
    }

    if (!mounted) return;
    await Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: (_) => ResultsScreen(
          barcode: code,
          selectedStore: widget.selectedStore,
        ),
      ),
    );
  }

  void _showError(String message) {
    setState(() {
      _errorMessage = message;
      _hasError = true;
      _readyToScan = true;
    });
    Future.delayed(const Duration(milliseconds: 1500), () {
      if (mounted) setState(() { _hasError = false; _errorMessage = ''; });
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
                onSubmitted: (_) => _searchManualCode(controller, sheetContext),
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
                  onPressed: () => _searchManualCode(controller, sheetContext),
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

  void _searchManualCode(
      TextEditingController controller, BuildContext sheetContext) {
    final code = controller.text.trim();
    if (code.isEmpty) return;

    Navigator.pop(sheetContext);
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: (_) =>
            ResultsScreen(barcode: code, selectedStore: widget.selectedStore),
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
        title: const Text('Сканування'),
        leading: IconButton(
          icon: const Icon(Icons.close, color: Colors.white),
          onPressed: () => Navigator.of(context).pushAndRemoveUntil(
            MaterialPageRoute(builder: (_) => const HomeScreen()), (route) => false,
          ),
        ),
      ),
      body: GestureDetector(
        onTap: () {
          FocusScope.of(context).unfocus();
          if (_readyToScan) _startSingleScan();
        },
        child: Stack(
          children: [
            MobileScanner(
              controller: controller,
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
                        style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w700),
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
                          onPressed: () => controller.start(),
                          icon: const Icon(Icons.refresh_rounded),
                          label: const Text('Спробувати знову'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.orangeAccent,
                            foregroundColor: Colors.white,
                            elevation: 0,
                            minimumSize: const Size.fromHeight(50),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
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
              left: 0, right: 0,
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
            if (_readyToScan && !_hasError)
              Positioned(
                top: boxTop + boxSize + 16,
                left: 0, right: 0,
                child: Center(
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                    decoration: BoxDecoration(color: Colors.black54, borderRadius: BorderRadius.circular(30)),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.touch_app_outlined, size: 17, color: Colors.orangeAccent),
                        SizedBox(width: 8),
                        Text('Торкніться екрана, щоб сканувати',
                          style: TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w600)),
                      ],
                    ),
                  ),
                ),
              ),
            if (_isScanning)
              Positioned(
                top: boxTop + boxSize + 16,
                left: 0, right: 0,
                child: Center(
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                    decoration: BoxDecoration(color: Colors.orangeAccent.withAlpha(51), borderRadius: BorderRadius.circular(30)),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)),
                        SizedBox(width: 10),
                        Text('Шукаємо штрихкод...', style: TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w600)),
                      ],
                    ),
                  ),
                ),
              ),
            if (_hasError)
              Positioned(
                bottom: 100, left: 24, right: 24,
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 20),
                  decoration: BoxDecoration(
                    color: const Color(0xFF93000A),
                    borderRadius: BorderRadius.circular(25),
                    boxShadow: const [BoxShadow(color: Color(0xFFCF6679), blurRadius: 12, offset: Offset(0, 3))],
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.error_outline, color: Color(0xFFCF6679), size: 22),
                      const SizedBox(width: 10),
                      Flexible(
                        child: Text(_errorMessage.isEmpty ? 'Помилка сканування' : _errorMessage,
                          style: const TextStyle(color: Color(0xFFFFDAD6), fontWeight: FontWeight.w600, fontSize: 14)),
                      ),
                    ],
                  ),
                ),
              ),
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
                        tooltip: _torchOn ? 'Вимкнути ліхтарик' : 'Увімкнути ліхтарик',
                        icon: Icon(_torchOn ? Icons.flash_on_rounded : Icons.flash_off_rounded),
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
                          style: TextButton.styleFrom(foregroundColor: Colors.white70),
                        ),
                      ),
                    ],
                  ),
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
    final boxPath = Path()..addRect(Rect.fromLTWH(centerX - boxSize / 2, boxTop, boxSize, boxSize));
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
    canvas.drawLine(Offset(0, cornerSize), Offset.zero, paint);
    canvas.drawLine(Offset.zero, Offset(cornerSize, 0), paint);
    canvas.drawLine(Offset(size.width - cornerSize, 0), Offset(size.width, 0), paint);
    canvas.drawLine(Offset(size.width, 0), Offset(size.width, cornerSize), paint);
    canvas.drawLine(Offset(0, size.height - cornerSize), Offset(0, size.height), paint);
    canvas.drawLine(Offset(0, size.height), Offset(cornerSize, size.height), paint);
    canvas.drawLine(Offset(size.width - cornerSize, size.height), Offset(size.width, size.height), paint);
    canvas.drawLine(Offset(size.width, size.height), Offset(size.width, size.height - cornerSize), paint);
  }

  @override
  bool shouldRepaint(_ScanCornersPainter oldDelegate) =>
      oldDelegate.color != color || oldDelegate.width != width;
}
