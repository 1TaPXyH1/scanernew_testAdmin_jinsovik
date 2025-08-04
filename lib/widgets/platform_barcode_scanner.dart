import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import '../services/web_barcode_scanner.dart'
    if (dart.library.html) '../services/web_barcode_scanner.dart'
    if (dart.library.io) '../services/web_barcode_scanner_stub.dart';

class PlatformBarcodeScanner extends StatefulWidget {
  final Function(String) onBarcodeDetected;
  final bool torchEnabled;
  final Function(bool)? onTorchToggle;
  
  const PlatformBarcodeScanner({
    super.key,
    required this.onBarcodeDetected,
    this.torchEnabled = false,
    this.onTorchToggle,
  });

  @override
  State<PlatformBarcodeScanner> createState() => _PlatformBarcodeScannerState();
}

class _PlatformBarcodeScannerState extends State<PlatformBarcodeScanner> {
  // Mobile scanner controller
  MobileScannerController? _mobileController;
  
  // Web scanner
  WebBarcodeScanner? _webScanner;
  dynamic _videoElement;
  
  bool _isInitialized = false;
  String? _lastScannedCode;
  DateTime? _lastScanTime;
  
  @override
  void initState() {
    super.initState();
    _initializeScanner();
  }
  
  Future<void> _initializeScanner() async {
    if (kIsWeb) {
      await _initializeWebScanner();
    } else {
      _initializeMobileScanner();
    }
  }
  
  Future<void> _initializeWebScanner() async {
    try {
      _webScanner = WebBarcodeScanner();
      final stream = await _webScanner!.startScanning();
      
      if (stream != null) {
        _videoElement = _webScanner!.videoElement;
        
        stream.listen((barcode) {
          _handleBarcodeDetected(barcode);
        });
        
        setState(() {
          _isInitialized = true;
        });
      }
    } catch (e) {
      if (kDebugMode) {
        print('Web scanner initialization failed: $e');
      }
    }
  }
  
  void _initializeMobileScanner() {
    _mobileController = MobileScannerController(
      detectionSpeed: DetectionSpeed.noDuplicates,
      facing: CameraFacing.back,
      torchEnabled: widget.torchEnabled,
    );
    
    setState(() {
      _isInitialized = true;
    });
  }
  
  void _handleBarcodeDetected(String barcode) {
    final now = DateTime.now();
    
    // Prevent duplicate scans within 2 seconds
    if (_lastScannedCode == barcode && 
        _lastScanTime != null && 
        now.difference(_lastScanTime!).inSeconds < 2) {
      return;
    }
    
    _lastScannedCode = barcode;
    _lastScanTime = now;
    
    widget.onBarcodeDetected(barcode);
  }
  
  Future<void> _toggleTorch() async {
    if (kIsWeb) {
      await _webScanner?.toggleTorch(!widget.torchEnabled);
    } else {
      await _mobileController?.toggleTorch();
    }
    widget.onTorchToggle?.call(!widget.torchEnabled);
  }
  
  @override
  void dispose() {
    if (kIsWeb) {
      _webScanner?.stopScanning();
    } else {
      _mobileController?.dispose();
    }
    super.dispose();
  }
  
  @override
  Widget build(BuildContext context) {
    if (!_isInitialized) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 16),
            Text('Ініціалізація камери...'),
          ],
        ),
      );
    }
    
    return Stack(
      children: [
        // Scanner view
        if (kIsWeb) _buildWebScanner() else _buildMobileScanner(),
        
        // Overlay with scanning frame
        _buildScanningOverlay(),
        
        // Torch button
        Positioned(
          top: 50,
          right: 20,
          child: FloatingActionButton(
            mini: true,
            backgroundColor: Colors.black54,
            onPressed: _toggleTorch,
            child: Icon(
              widget.torchEnabled ? Icons.flash_on : Icons.flash_off,
              color: Colors.white,
            ),
          ),
        ),
        
        // Manual input button
        Positioned(
          bottom: 100,
          left: 20,
          right: 20,
          child: ElevatedButton.icon(
            onPressed: _showManualInputDialog,
            icon: const Icon(Icons.keyboard),
            label: const Text('Ввести вручну'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.blue,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 12),
            ),
          ),
        ),
      ],
    );
  }
  
  Widget _buildWebScanner() {
    if (_videoElement == null) {
      return const Center(child: Text('Камера недоступна'));
    }
    
    // For web, we'll use a simple container since HtmlElementView has issues
    // The actual video scanning is handled by the WebBarcodeScanner service
    return Container(
      color: Colors.black,
      child: const Center(
        child: Text(
          'Камера активна\nНаведіть на штрих-код',
          textAlign: TextAlign.center,
          style: TextStyle(
            color: Colors.white,
            fontSize: 16,
          ),
        ),
      ),
    );
  }
  
  Widget _buildMobileScanner() {
    return MobileScanner(
      controller: _mobileController,
      onDetect: (capture) {
        final List<Barcode> barcodes = capture.barcodes;
        if (barcodes.isNotEmpty && barcodes.first.rawValue != null) {
          _handleBarcodeDetected(barcodes.first.rawValue!);
        }
      },
    );
  }
  
  Widget _buildScanningOverlay() {
    return Container(
      decoration: ShapeDecoration(
        shape: const QrScannerOverlayShape(
          borderColor: Colors.blue,
          borderRadius: 10,
          borderLength: 30,
          borderWidth: 10,
          cutOutSize: 300,
        ),
      ),
      child: const Align(
        alignment: Alignment.bottomCenter,
        child: Padding(
          padding: EdgeInsets.only(bottom: 200),
          child: Text(
            'Наведіть камеру на штрих-код',
            style: TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ),
    );
  }
  
  void _showManualInputDialog() {
    final controller = TextEditingController();
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Введіть штрих-код'),
        content: TextField(
          controller: controller,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(
            hintText: '2107001234567',
            border: OutlineInputBorder(),
          ),
          autofocus: true,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Скасувати'),
          ),
          ElevatedButton(
            onPressed: () {
              final barcode = controller.text.trim();
              if (barcode.isNotEmpty) {
                Navigator.pop(context);
                _handleBarcodeDetected(barcode);
              }
            },
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }
}

// Custom overlay shape for scanning frame
class QrScannerOverlayShape extends ShapeBorder {
  final Color borderColor;
  final double borderWidth;
  final Color overlayColor;
  final double borderRadius;
  final double borderLength;
  final double cutOutSize;

  const QrScannerOverlayShape({
    this.borderColor = Colors.red,
    this.borderWidth = 3.0,
    this.overlayColor = const Color.fromRGBO(0, 0, 0, 80),
    this.borderRadius = 0,
    this.borderLength = 40,
    this.cutOutSize = 250,
  });

  @override
  EdgeInsetsGeometry get dimensions => const EdgeInsets.all(10);

  @override
  Path getInnerPath(Rect rect, {TextDirection? textDirection}) {
    return Path()
      ..fillType = PathFillType.evenOdd
      ..addPath(getOuterPath(rect), Offset.zero);
  }

  @override
  Path getOuterPath(Rect rect, {TextDirection? textDirection}) {
    Path getLeftTopPath(Rect rect) {
      return Path()
        ..moveTo(rect.left, rect.bottom)
        ..lineTo(rect.left, rect.top + borderRadius)
        ..quadraticBezierTo(rect.left, rect.top, rect.left + borderRadius, rect.top)
        ..lineTo(rect.right, rect.top);
    }

    return getLeftTopPath(rect)
      ..lineTo(rect.right, rect.bottom)
      ..lineTo(rect.left, rect.bottom)
      ..lineTo(rect.left, rect.top);
  }

  @override
  void paint(Canvas canvas, Rect rect, {TextDirection? textDirection}) {
    final width = rect.width;
    final borderWidthSize = width / 2;
    final height = rect.height;
    final borderOffset = borderWidth / 2;
    final mBorderLength = borderLength > min(cutOutSize / 2, 90) ? borderWidthSize / 2 : borderLength;
    final mCutOutSize = cutOutSize < min(width, height) ? cutOutSize : min(width, height) - 20;

    final backgroundPaint = Paint()
      ..color = overlayColor
      ..style = PaintingStyle.fill;

    final borderPaint = Paint()
      ..color = borderColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = borderWidth;

    final boxPaint = Paint()
      ..color = borderColor
      ..style = PaintingStyle.fill
      ..blendMode = BlendMode.dstOut;

    final cutOutRect = Rect.fromLTWH(
      rect.left + width / 2 - mCutOutSize / 2 + borderOffset,
      rect.top + height / 2 - mCutOutSize / 2 + borderOffset,
      mCutOutSize - borderOffset * 2,
      mCutOutSize - borderOffset * 2,
    );

    canvas
      ..saveLayer(rect, backgroundPaint)
      ..drawRect(rect, backgroundPaint)
      ..drawRRect(RRect.fromRectAndRadius(cutOutRect, Radius.circular(borderRadius)), boxPaint)
      ..restore();

    // Draw corner borders
    final path = Path()
      // Top left
      ..moveTo(cutOutRect.left - borderOffset, cutOutRect.top + mBorderLength)
      ..lineTo(cutOutRect.left - borderOffset, cutOutRect.top + borderRadius)
      ..quadraticBezierTo(cutOutRect.left - borderOffset, cutOutRect.top - borderOffset,
          cutOutRect.left + borderRadius, cutOutRect.top - borderOffset)
      ..lineTo(cutOutRect.left + mBorderLength, cutOutRect.top - borderOffset)
      // Top right
      ..moveTo(cutOutRect.right - mBorderLength, cutOutRect.top - borderOffset)
      ..lineTo(cutOutRect.right - borderRadius, cutOutRect.top - borderOffset)
      ..quadraticBezierTo(cutOutRect.right + borderOffset, cutOutRect.top - borderOffset,
          cutOutRect.right + borderOffset, cutOutRect.top + borderRadius)
      ..lineTo(cutOutRect.right + borderOffset, cutOutRect.top + mBorderLength)
      // Bottom right
      ..moveTo(cutOutRect.right + borderOffset, cutOutRect.bottom - mBorderLength)
      ..lineTo(cutOutRect.right + borderOffset, cutOutRect.bottom - borderRadius)
      ..quadraticBezierTo(cutOutRect.right + borderOffset, cutOutRect.bottom + borderOffset,
          cutOutRect.right - borderRadius, cutOutRect.bottom + borderOffset)
      ..lineTo(cutOutRect.right - mBorderLength, cutOutRect.bottom + borderOffset)
      // Bottom left
      ..moveTo(cutOutRect.left + mBorderLength, cutOutRect.bottom + borderOffset)
      ..lineTo(cutOutRect.left + borderRadius, cutOutRect.bottom + borderOffset)
      ..quadraticBezierTo(cutOutRect.left - borderOffset, cutOutRect.bottom + borderOffset,
          cutOutRect.left - borderOffset, cutOutRect.bottom - borderRadius)
      ..lineTo(cutOutRect.left - borderOffset, cutOutRect.bottom - mBorderLength);

    canvas.drawPath(path, borderPaint);
  }

  @override
  ShapeBorder scale(double t) {
    return QrScannerOverlayShape(
      borderColor: borderColor,
      borderWidth: borderWidth,
      overlayColor: overlayColor,
    );
  }

  double min(double a, double b) => a < b ? a : b;
}
