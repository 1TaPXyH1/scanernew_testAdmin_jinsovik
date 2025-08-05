import 'dart:async';
import 'package:flutter/foundation.dart';

// Conditional imports for web-only libraries
import 'dart:html' as html if (dart.library.html) 'dart:html';
import 'dart:js' as js if (dart.library.js) 'dart:js';
import 'dart:js_util' as js_util if (dart.library.js_util) 'dart:js_util';
// Для реєстрації platformView
import 'dart:ui_web' if (dart.library.io) 'dart:ui' show platformViewRegistry;

class WebBarcodeScanner {
  static const String _jsLibraryUrl = 'https://unpkg.com/@zxing/library@latest/umd/index.min.js';
  static bool _isLibraryLoaded = false;
  static Completer<bool>? _loadingCompleter;
  
  html.VideoElement? _videoElement;
  html.CanvasElement? _canvasElement;
  html.CanvasRenderingContext2D? _canvasContext;
  StreamController<String>? _barcodeController;
  Timer? _scanTimer;
  bool _isScanning = false;
  
  // Load ZXing library
  static Future<bool> loadZXingLibrary() async {
    if (_isLibraryLoaded) return true;
    
    if (_loadingCompleter != null) {
      return _loadingCompleter!.future;
    }
    
    _loadingCompleter = Completer<bool>();
    
    try {
      final script = html.ScriptElement()
        ..src = _jsLibraryUrl
        ..type = 'text/javascript';
      
      script.onLoad.listen((_) {
        _isLibraryLoaded = true;
        _loadingCompleter!.complete(true);
      });
      
      script.onError.listen((_) {
        _loadingCompleter!.complete(false);
      });
      
      html.document.head!.append(script);
      
      return _loadingCompleter!.future;
    } catch (e) {
      _loadingCompleter!.complete(false);
      return false;
    }
  }
  
  // Initialize camera and start scanning
  Future<Stream<String>?> startScanning() async {
    if (_isScanning) return _barcodeController?.stream;
    
    try {
      // Load ZXing library first
      final libraryLoaded = await loadZXingLibrary();
      if (!libraryLoaded) {
        throw Exception('Failed to load ZXing library');
      }
      
      // Request camera access
      final mediaStream = await html.window.navigator.mediaDevices!.getUserMedia({
        'video': {
          'facingMode': 'environment', // Back camera
          'width': {'ideal': 1280},
          'height': {'ideal': 720},
          'frameRate': {'ideal': 30}
        }
      });
      
      // Create video element
      _videoElement = html.VideoElement()
        ..srcObject = mediaStream
        ..autoplay = true
        ..muted = true
        ..style.width = '100%'
        ..style.height = '100%'
        ..style.objectFit = 'cover'
        ..style.border = 'none'
        ..style.background = 'black';
      
      // Set playsInline attribute for iOS compatibility
      _videoElement!.setAttribute('playsinline', 'true');
      
      // Register platform view for Flutter web
      if (kIsWeb) {
        try {
          platformViewRegistry.registerViewFactory(
            'barcode-scanner-video',
            (int viewId) => _videoElement!,
          );
        } catch (e) {
          // Platform view might already be registered, ignore error
          if (kDebugMode) {
            print('Platform view registration warning: $e');
          }
        }
      }
      
      // Create canvas for image processing
      _canvasElement = html.CanvasElement()
        ..width = 640
        ..height = 480;
      _canvasContext = _canvasElement!.getContext('2d') as html.CanvasRenderingContext2D;
      
      // Wait for video to be ready
      await _videoElement!.onLoadedMetadata.first;
      
      _barcodeController = StreamController<String>.broadcast();
      _isScanning = true;
      
      // Start scanning loop
      _startScanningLoop();
      
      return _barcodeController!.stream;
    } catch (e) {
      if (kDebugMode) {
        print('Error starting camera: $e');
      }
      return null;
    }
  }
  
  void _startScanningLoop() {
    _scanTimer = Timer.periodic(const Duration(milliseconds: 500), (_) {
      if (!_isScanning || _videoElement == null || _canvasElement == null) return;
      
      try {
        // Draw video frame to canvas
        _canvasContext!.drawImageScaled(
          _videoElement!,
          0, 0,
          _canvasElement!.width!,
          _canvasElement!.height!
        );
        
        // Get image data
        final imageData = _canvasContext!.getImageData(
          0, 0,
          _canvasElement!.width!,
          _canvasElement!.height!
        );
        
        // Try to decode barcode using ZXing
        _decodeBarcode(imageData);
      } catch (e) {
        if (kDebugMode) {
          print('Error in scanning loop: $e');
        }
      }
    });
  }
  
  void _decodeBarcode(html.ImageData imageData) {
    try {
      // Use ZXing library to decode
      final codeReader = js_util.callConstructor(
        js.context['ZXing']['BrowserMultiFormatReader'], []
      );
      
      // Create a promise-based decode
      final decodePromise = js_util.callMethod(
        codeReader, 'decodeFromImageData', [imageData]
      );
      
      // Convert promise to future
      js_util.promiseToFuture(decodePromise).then((result) {
        if (result != null) {
          final text = js_util.getProperty(result, 'text');
          if (text != null && text.toString().isNotEmpty) {
            _barcodeController?.add(text.toString());
          }
        }
      }).catchError((error) {
        // Silently ignore decode errors (no barcode found)
      });
    } catch (e) {
      // Silently ignore errors
    }
  }
  
  // Stop scanning and cleanup
  void stopScanning() {
    _isScanning = false;
    _scanTimer?.cancel();
    _scanTimer = null;
    
    // Stop video stream
    if (_videoElement?.srcObject != null) {
      final mediaStream = _videoElement!.srcObject as html.MediaStream;
      for (final track in mediaStream.getTracks()) {
        track.stop();
      }
    }
    
    _videoElement?.remove();
    _videoElement = null;
    _canvasElement = null;
    _canvasContext = null;
    
    _barcodeController?.close();
    _barcodeController = null;
  }
  
  // Get video element for display
  html.VideoElement? get videoElement => _videoElement;
  
  // Toggle torch (if supported)
  Future<void> toggleTorch(bool enabled) async {
    try {
      if (_videoElement?.srcObject != null) {
        final mediaStream = _videoElement!.srcObject as html.MediaStream;
        final videoTracks = mediaStream.getVideoTracks();
        
        if (videoTracks.isNotEmpty) {
          final track = videoTracks.first;
          final capabilities = js_util.callMethod(track, 'getCapabilities', []);
          
          if (js_util.hasProperty(capabilities, 'torch')) {
            await js_util.promiseToFuture(
              js_util.callMethod(track, 'applyConstraints', [{
                'advanced': [{'torch': enabled}]
              }])
            );
          }
        }
      }
    } catch (e) {
      if (kDebugMode) {
        print('Torch not supported: $e');
      }
    }
  }
  
  // Check if torch is supported
  Future<bool> isTorchSupported() async {
    try {
      if (_videoElement?.srcObject != null) {
        final mediaStream = _videoElement!.srcObject as html.MediaStream;
        final videoTracks = mediaStream.getVideoTracks();
        
        if (videoTracks.isNotEmpty) {
          final track = videoTracks.first;
          final capabilities = js_util.callMethod(track, 'getCapabilities', []);
          return js_util.hasProperty(capabilities, 'torch');
        }
      }
    } catch (e) {
      // Torch not supported
    }
    return false;
  }
}
