import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jinsovik_scanner/utils/scan_window.dart';

void main() {
  test('scan window matches the visible scanning square', () {
    final window = ScanWindow.forPreview(const Size(400, 800));

    expect(window, const Rect.fromLTWH(56, 80, 288, 288));
  });
}
