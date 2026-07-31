import 'package:flutter/widgets.dart';

class ScanWindow {
  const ScanWindow._();

  static Rect forPreview(Size previewSize) {
    final side = previewSize.width * 0.72;
    return Rect.fromLTWH(
      (previewSize.width - side) / 2,
      previewSize.height * 0.1,
      side,
      side,
    );
  }
}
