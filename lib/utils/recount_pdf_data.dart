import 'dart:convert';
import 'dart:typed_data';

class RecountPdfData {
  const RecountPdfData({
    required this.reportId,
    required this.products,
    required this.startTime,
    required this.endTime,
  });

  static const _markerStart = '%%JINSOVIK_RECOUNT_V1';
  static const _markerEnd = '%%JINSOVIK_RECOUNT_END';

  final String reportId;
  final List<Map<String, dynamic>> products;
  final DateTime startTime;
  final DateTime endTime;

  Uint8List embedIn(Uint8List pdfBytes) {
    final payload = base64Url.encode(
      utf8.encode(
        jsonEncode({
          'reportId': reportId,
          'products': products,
          'startTime': startTime.toIso8601String(),
          'endTime': endTime.toIso8601String(),
        }),
      ),
    );
    final marker = '\n$_markerStart\n%$payload\n$_markerEnd\n';
    return Uint8List.fromList([...pdfBytes, ...latin1.encode(marker)]);
  }

  static RecountPdfData? tryExtract(Uint8List pdfBytes) {
    try {
      final content = latin1.decode(pdfBytes);
      final start = content.lastIndexOf(_markerStart);
      if (start < 0) return null;

      final payloadStart = content.indexOf('\n%', start);
      final end = content.indexOf(_markerEnd, payloadStart);
      if (payloadStart < 0 || end < 0) return null;

      final payload = content.substring(payloadStart + 2, end).trim();
      final decoded = jsonDecode(utf8.decode(base64Url.decode(payload)));
      if (decoded is! Map<String, dynamic> || decoded['products'] is! List) {
        return null;
      }

      final products = (decoded['products'] as List)
          .whereType<Map>()
          .map((product) => Map<String, dynamic>.from(product))
          .toList();
      return RecountPdfData(
        reportId: decoded['reportId'] as String,
        products: products,
        startTime: DateTime.parse(decoded['startTime'] as String),
        endTime: DateTime.parse(decoded['endTime'] as String),
      );
    } catch (_) {
      return null;
    }
  }

  static RecountPdfMergeResult merge(List<RecountPdfData> reports) {
    final productsByBarcode = <String, Map<String, dynamic>>{};
    final conflictingBarcodes = <String>{};
    final duplicateReportIds = <String>{};
    final seenReportIds = <String>{};
    var startTime = reports.first.startTime;
    var endTime = reports.first.endTime;

    for (final report in reports) {
      if (!seenReportIds.add(report.reportId)) {
        duplicateReportIds.add(report.reportId);
        continue;
      }
      if (report.startTime.isBefore(startTime)) startTime = report.startTime;
      if (report.endTime.isAfter(endTime)) endTime = report.endTime;

      for (final sourceProduct in report.products) {
        final barcode = sourceProduct['barcode']?.toString() ?? '';
        if (barcode.isEmpty) continue;

        final existing = productsByBarcode[barcode];
        if (existing == null) {
          productsByBarcode[barcode] = Map<String, dynamic>.from(sourceProduct);
          continue;
        }

        if (_toDouble(existing['stock_count']) !=
                _toDouble(sourceProduct['stock_count']) ||
            _toDouble(existing['price']) != _toDouble(sourceProduct['price'])) {
          conflictingBarcodes.add(barcode);
        }
        existing['actual_count'] =
            _toInt(existing['actual_count']) + _toInt(sourceProduct['actual_count']);
      }
    }

    return RecountPdfMergeResult(
      products: productsByBarcode.values.toList(),
      startTime: startTime,
      endTime: endTime,
      conflictingBarcodes: conflictingBarcodes.toList(),
      duplicateReportIds: duplicateReportIds.toList(),
    );
  }

  static int _toInt(dynamic value) =>
      value is int ? value : int.tryParse(value?.toString() ?? '') ?? 0;

  static double _toDouble(dynamic value) =>
      value is double ? value : double.tryParse(value?.toString() ?? '') ?? 0;
}

class RecountPdfMergeResult {
  const RecountPdfMergeResult({
    required this.products,
    required this.startTime,
    required this.endTime,
    required this.conflictingBarcodes,
    required this.duplicateReportIds,
  });

  final List<Map<String, dynamic>> products;
  final DateTime startTime;
  final DateTime endTime;
  final List<String> conflictingBarcodes;
  final List<String> duplicateReportIds;
}
