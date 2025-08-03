import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import '../services/network_service.dart';
import 'package:vibration/vibration.dart';

class RecountBarcodeScanScreen extends StatefulWidget {
  final List<String> sessionNames;
  const RecountBarcodeScanScreen({Key? key, required this.sessionNames}) : super(key: key);

  @override
  State<RecountBarcodeScanScreen> createState() => _RecountBarcodeScanScreenState();
}

class _RecountBarcodeScanScreenState extends State<RecountBarcodeScanScreen> with SingleTickerProviderStateMixin, WidgetsBindingObserver {
  final MobileScannerController _controller = MobileScannerController(
    detectionSpeed: DetectionSpeed.noDuplicates,
    facing: CameraFacing.back,
    torchEnabled: false,
  );
  bool _isScanning = false;
  bool _showSuccess = false;
  bool _hasError = false;
  bool _torchOn = false;
  String? _errorMessage;

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
    // Stop camera when widget becomes inactive (e.g., navigating to another screen)
    _controller.stop();
    super.deactivate();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _borderAnimationController.dispose();
    // Explicitly stop camera before disposing
    _controller.stop();
    _controller.dispose();
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
        _controller.stop();
        break;
      case AppLifecycleState.hidden:
        break;
    }
  }

  void _toggleTorch() {
    _controller.toggleTorch();
    setState(() {
      _torchOn = !_torchOn;
    });
  }

  void _onDetect(BarcodeCapture capture) async {
    if (_isScanning) return;
    if (capture.barcodes.isEmpty) return;
    final barcode = capture.barcodes.first.rawValue;
    if (barcode == null || barcode.isEmpty) return;

    setState(() {
      _isScanning = true;
      _errorMessage = null;
    });

    // Check internet
    final networkService = NetworkService();
    final isConnected = await networkService.isConnected();
    if (!mounted) return;
    if (!isConnected) {
      setState(() {
        _errorMessage = "Помилка інтернет з'єднання";
        _isScanning = false;
      });
      await Future.delayed(const Duration(seconds: 1));
      if (!mounted) return;
      setState(() {
        _errorMessage = null;
      });
      return;
    }

    // Validate barcode
    if (barcode.length < 7) {
      setState(() {
        _errorMessage = "Невірний штрихкод";
        _isScanning = false;
      });
      await Future.delayed(const Duration(seconds: 1));
      if (!mounted) return;
      setState(() {
        _errorMessage = null;
      });
      return;
    }

    // Validate prefix (same as ScanScreen)
    if (!barcode.startsWith('210700')) {
      setState(() {
        _hasError = true;
        _showSuccess = false;
        _errorMessage = "Невірний штрихкод";
        _isScanning = false;
      });
      await Future.delayed(const Duration(seconds: 1));
      if (!mounted) return;
      setState(() {
        _hasError = false;
        _errorMessage = null;
      });
      return;
    }

    // Fetch product data for Харківське шосе only - optimized for speed
    try {
      final response = await http.get(Uri.parse(
        'https://static.88-198-21-139.clients.your-server.de:956/REST/hs/prices/product_new/$barcode/',
      ));
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['success'] == true &&
            data['response'] is List &&
            data['response'].length == 2 &&
            data['response'][1] is List) {
          final storesList = data['response'][1] as List;
          
          // Only select Харківське шосе - constant store filter
          final kharkivskeShoseStore = storesList.firstWhere(
            (store) {
              final storeName = (store['name']?.toString().toLowerCase()) ?? '';
              return storeName.contains('харківське шосе');
            },
            orElse: () => null,
          );
          
          if (kharkivskeShoseStore == null) {
            setState(() {
              _hasError = true;
              _showSuccess = false;
              _errorMessage = "Товар не знайдено в магазині Харківське шосе";
              _isScanning = false;
            });
            await Future.delayed(const Duration(milliseconds: 800)); // Faster error display
            if (!mounted) return;
            setState(() {
              _hasError = false;
              _errorMessage = null;
            });
            return;
          }
          
          // Show success immediately for faster UX
          setState(() {
            _showSuccess = true;
            _hasError = false;
          });
          
          final hasVibrator = await Vibration.hasVibrator();
          if (mounted && hasVibrator) {
            Vibration.vibrate(pattern: [0, 150, 100, 150]);
          }
          
          // Reduced delay for faster navigation
          await Future.delayed(const Duration(milliseconds: 800));
          if (!mounted) return;
          Navigator.of(context).pop(barcode);
          return;
        } else {
          setState(() {
            _hasError = true;
            _showSuccess = false;
            _errorMessage = "Товар не знайдено";
            _isScanning = false;
          });
          await Future.delayed(const Duration(seconds: 1));
          if (!mounted) return;
          setState(() {
            _hasError = false;
            _errorMessage = null;
          });
          return;
        }
      } else {
        setState(() {
          _hasError = true;
          _showSuccess = false;
          _errorMessage = "Помилка сервера";
          _isScanning = false;
        });
        await Future.delayed(const Duration(seconds: 1));
        if (!mounted) return;
        setState(() {
          _hasError = false;
          _errorMessage = null;
        });
        return;
      }
    } catch (e) {
      setState(() {
        _hasError = true;
        _showSuccess = false;
        _errorMessage = "Помилка з'єднання";
        _isScanning = false;
      });
      await Future.delayed(const Duration(seconds: 1));
      if (!mounted) return;
      setState(() {
        _hasError = false;
        _errorMessage = null;
      });
      return;
    }
  }

  @override
  Widget build(BuildContext context) {
    final double boxSize = MediaQuery.of(context).size.width * 0.8;
    return Semantics(
      label: 'Екран сканування (переоблік)',
      child: Scaffold(
        backgroundColor: Colors.black,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          automaticallyImplyLeading: false,
          title: const Text('Сканування'),
          centerTitle: true,
          actions: [
            IconButton(
              icon: Icon(_torchOn ? Icons.flash_on : Icons.flash_off, color: Colors.yellowAccent),
              tooltip: _torchOn ? 'Вимкнути ліхтарик' : 'Увімкнути ліхтарик',
              onPressed: _toggleTorch,
            ),
            IconButton(
              icon: const Icon(Icons.close),
              tooltip: 'Закрити',
              onPressed: () => Navigator.of(context).pop(),
            ),
          ],
        ),
        body: Stack(
          children: [
            MobileScanner(
              controller: _controller,
              onDetect: _onDetect,
            ),
            Positioned.fill(
              child: IgnorePointer(
                child: Container(
                  color: Colors.black54,
                  child: Center(
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(16),
                      child: Container(
                        width: boxSize,
                        height: boxSize,
                        color: Colors.transparent,
                      ),
                    ),
                  ),
                ),
              ),
            ),
            // Animated scan border
            AnimatedBuilder(
              animation: _borderAnimationController,
              builder: (context, child) {
                return Center(
                  child: Container(
                    width: boxSize,
                    height: boxSize,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: _hasError ? Colors.redAccent : Colors.lightBlueAccent,
                        width: _borderAnimation.value,
                      ),
                    ),
                  ),
                );
              },
            ),
            // Error overlay
            if (_errorMessage != null)
              AnimatedOpacity(
                duration: const Duration(milliseconds: 300),
                opacity: 1.0,
                child: Container(
                  color: Colors.black54,
                  child: Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.error_outline,
                          color: Colors.redAccent,
                          size: 80,
                        ),
                        const SizedBox(height: 20),
                        Text(
                          _errorMessage ?? 'Помилка',
                          style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            // Success overlay
            if (_errorMessage == null)
              AnimatedOpacity(
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
                        SizedBox(height: 20),
                        Text(
                          'Успішно',
                          style: TextStyle(color: Colors.greenAccent, fontSize: 24, fontWeight: FontWeight.bold),
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
