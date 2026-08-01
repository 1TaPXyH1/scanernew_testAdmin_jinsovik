import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:jinsovik_scanner/utils/recount_pdf_data.dart';

void main() {
  final firstReport = RecountPdfData(
    reportId: 'report-1',
    startTime: DateTime(2026, 8, 1, 10),
    endTime: DateTime(2026, 8, 1, 10, 30),
    products: [
      {
        'barcode': '111',
        'name': 'Товар 1',
        'price': 100.0,
        'stock_count': 10,
        'actual_count': 1,
      },
    ],
  );

  test('embeds and extracts recount data without changing the visible PDF', () {
    final bytes = firstReport.embedIn(Uint8List.fromList('%PDF-1.7\n%%EOF'.codeUnits));

    final restored = RecountPdfData.tryExtract(bytes);

    expect(restored, isNotNull);
    expect(restored!.reportId, 'report-1');
    expect(restored.products.single['barcode'], '111');
    expect(restored.products.single['actual_count'], 1);
    expect(restored.startTime, firstReport.startTime);
  });

  test('merges products by barcode and sums only the actual count', () {
    final secondReport = RecountPdfData(
      reportId: 'report-2',
      startTime: DateTime(2026, 8, 1, 10, 5),
      endTime: DateTime(2026, 8, 1, 11),
      products: [
        {
          'barcode': '111',
          'name': 'Товар 1',
          'price': 100.0,
          'stock_count': 10,
          'actual_count': 3,
        },
        {
          'barcode': '222',
          'name': 'Товар 2',
          'price': 200.0,
          'stock_count': 4,
          'actual_count': 4,
        },
      ],
    );

    final result = RecountPdfData.merge([firstReport, secondReport]);

    expect(result.products, hasLength(2));
    expect(result.products.firstWhere((p) => p['barcode'] == '111')['actual_count'], 4);
    expect(result.products.firstWhere((p) => p['barcode'] == '111')['stock_count'], 10);
    expect(result.startTime, firstReport.startTime);
    expect(result.endTime, secondReport.endTime);
  });

  test('reports a duplicate report without double-counting its products', () {
    final result = RecountPdfData.merge([firstReport, firstReport]);

    expect(result.duplicateReportIds, ['report-1']);
    expect(result.products.single['actual_count'], 1);
  });

  test('keeps the first stock and price while reporting conflicting values', () {
    final conflictingReport = RecountPdfData(
      reportId: 'report-conflict',
      startTime: DateTime(2026, 8, 1, 10, 10),
      endTime: DateTime(2026, 8, 1, 10, 40),
      products: [
        {
          'barcode': '111',
          'name': 'Товар 1',
          'price': 120.0,
          'stock_count': 12,
          'actual_count': 3,
        },
      ],
    );

    final result = RecountPdfData.merge([firstReport, conflictingReport]);

    expect(result.conflictingBarcodes, ['111']);
    expect(result.products.single['price'], 100.0);
    expect(result.products.single['stock_count'], 10);
    expect(result.products.single['actual_count'], 4);
  });
}
