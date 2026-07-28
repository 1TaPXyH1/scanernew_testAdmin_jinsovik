import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import '../services/network_service.dart';
import '../screens/home.dart';
import '../screens/result.dart';

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
    _borderAnimation = Tween<double>(begin: 2, end: 5).animate(
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
    WidgetsBinding.instance.addPostFrameCallback((_) => controller.stop());
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

    final code = barcode.rawValue!;
    final networkService = NetworkService();
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
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Скасувати', style: TextStyle(color: Colors.white54))),
          ElevatedButton(
            onPressed: () {
              final code = controller.text.trim();
              if (code.isNotEmpty) {
                Navigator.pop(ctx);
                Navigator.of(context).pushReplacement(
                  MaterialPageRoute(
                    builder: (_) => ResultsScreen(barcode: code, selectedStore: widget.selectedStore),
                  ),
                );
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
    final screenSize = MediaQuery.of(context).size;
    final boxSize = screenSize.width * 0.72;
    final boxTop = screenSize.height * 0.1;

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        automaticallyImplyLeading: false,
        actions: [
          IconButton(
            icon: const Icon(Icons.close, color: Colors.white),
            onPressed: () => Navigator.of(context).pushAndRemoveUntil(
              MaterialPageRoute(builder: (_) => const HomeScreen()), (route) => false,
            ),
          ),
        ],
      ),
      body: GestureDetector(
        onTap: _readyToScan ? _startSingleScan : null,
        child: Stack(
          children: [
            MobileScanner(
              controller: controller,
              onDetect: _onBarcodeDetected,
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
                    final color = _hasError ? const Color(0xFFCF6679) : Colors.orangeAccent;
                    final w = _hasError ? 3.0 : _borderAnimation.value;
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
                    child: const Text('Натисніть на екран для сканування',
                      style: TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w600), textAlign: TextAlign.center),
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
                        Text('Сканування...', style: TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w600)),
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
              left: 24, bottom: 48,
              child: FloatingActionButton(
                onPressed: _toggleTorch,
                tooltip: _torchOn ? 'Вимкнути ліхтарик' : 'Увімкнути ліхтарик',
                backgroundColor: _torchOn ? Colors.orangeAccent : Colors.grey,
                child: Icon(_torchOn ? Icons.flash_on : Icons.flash_off),
              ),
            ),
            Positioned(
              right: 24, bottom: 48,
              child: TextButton.icon(
                onPressed: _showManualEntry,
                icon: const Icon(Icons.keyboard_outlined, color: Colors.white54, size: 20),
                label: const Text('Ввести', style: TextStyle(color: Colors.white54, fontSize: 13)),
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
    final path = Path()..addRect(Rect.fromLTWH(0, 0, size.width, size.height));
    final centerX = size.width / 2;
    final boxRect = Rect.fromLTWH(centerX - boxSize / 2, boxTop, boxSize, boxSize);
    path.addRect(boxRect);
    return Path.combine(PathOperation.reverseDifference, path, Path()..addRect(boxRect));
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
