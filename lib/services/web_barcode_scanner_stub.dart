// Stub implementation for non-web platforms
import 'dart:async';

class WebBarcodeScanner {
  Future<Stream<String>?> startScanning() async {
    throw UnsupportedError('Web barcode scanner is only supported on web platforms');
  }
  
  void stopScanning() {
    // No-op for non-web platforms
  }
  
  dynamic get videoElement => null;
  
  Future<void> toggleTorch(bool enabled) async {
    // No-op for non-web platforms
  }
  
  Future<bool> isTorchSupported() async {
    return false;
  }
}
