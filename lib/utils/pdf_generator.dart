import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:intl/intl.dart';
import 'package:flutter/services.dart' show rootBundle;

class PdfGenerator {
  static bool _isWomenProduct(Map<String, dynamic> product) {
    final name = (product['name']?.toString() ?? '').toLowerCase();
    return name.startsWith('ж ');
  }

  static Map<String, List<Map<String, dynamic>>> _groupProductsByGender(List<Map<String, dynamic>> products) {
    final women = <Map<String, dynamic>>[];
    final men = <Map<String, dynamic>>[];

    for (final product in products) {
      if (_isWomenProduct(product)) {
        women.add(product);
      } else {
        men.add(product);
      }
    }

    return {
      'Жіночий товар': women,
      'Чоловічий товар': men,
    };
  }

  static Future<File> generateRecountReport({
    required List<Map<String, dynamic>> products,
    required List<String> sessionNames,
  }) async {
    final pdf = pw.Document();

    late final pw.Font otoiwoFont;
    late final pw.Font otoiwoBoldFont;
    try {
      final fontData = await rootBundle.load('assets/fonts/calibri.ttf');
      otoiwoFont = pw.Font.ttf(fontData.buffer.asByteData());
      otoiwoBoldFont = otoiwoFont;
    } catch (e) {
      rethrow;
    }

    final totalStock = products.fold<int>(0, (sum, p) => sum + _toInt(p['stock_count']));
    final totalActual = products.fold<int>(0, (sum, p) => sum + _toInt(p['actual_count']));
    final totalDiff = totalActual - totalStock;
    final totalStockPrice = products.fold<double>(0.0, (sum, p) => sum + (_toDouble(p['price']) * _toInt(p['stock_count'])));
    final totalActualPrice = products.fold<double>(0.0, (sum, p) => sum + (_toDouble(p['price']) * _toInt(p['actual_count'])));
    final totalPriceDiff = totalActualPrice - totalStockPrice;

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(20),
        build: (pw.Context context) {
          return [
            pw.Container(
              padding: const pw.EdgeInsets.all(20),
              decoration: const pw.BoxDecoration(
                color: PdfColors.blue900,
                borderRadius: pw.BorderRadius.all(pw.Radius.circular(12)),
              ),
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text(
                    'ЗВІТ ПЕРЕОБЛІКУ',
                    style: pw.TextStyle(
                      font: otoiwoBoldFont,
                      fontSize: 28,
                      fontWeight: pw.FontWeight.bold,
                      color: PdfColors.white,
                    ),
                  ),
                  pw.SizedBox(height: 8),
                  pw.Text(
                    'ID сесії: ${sessionNames.join(', ')}',
                    style: pw.TextStyle(
                      font: otoiwoFont,
                      fontSize: 14,
                      color: PdfColors.white,
                    ),
                  ),
                  pw.Text(
                    'Дата: ${DateFormat('dd.MM.yyyy HH:mm').format(DateTime.now())}',
                    style: pw.TextStyle(
                      font: otoiwoFont,
                      fontSize: 14,
                      color: PdfColors.white,
                    ),
                  ),
                  pw.SizedBox(height: 8),
                  pw.Container(
                    padding: const pw.EdgeInsets.all(12),
                    decoration: pw.BoxDecoration(
                      color: PdfColors.grey200,
                      borderRadius: const pw.BorderRadius.all(pw.Radius.circular(8)),
                      border: pw.Border.all(color: PdfColors.grey400),
                    ),
                    child: pw.Row(
                      children: [
                        pw.Text(
                          'Відповідальний за переоблік: ',
                          style: pw.TextStyle(
                            font: otoiwoFont,
                            fontSize: 12,
                            color: PdfColors.white,
                          ),
                        ),
                        pw.Expanded(
                          child: pw.Container(
                            height: 20,
                            decoration: const pw.BoxDecoration(
                              border: pw.Border(
                                bottom: pw.BorderSide(
                                  color: PdfColors.grey400,
                                  width: 1,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            pw.SizedBox(height: 16),
            pw.Container(
              padding: const pw.EdgeInsets.all(12),
              decoration: pw.BoxDecoration(
                color: PdfColors.grey100,
                borderRadius: const pw.BorderRadius.all(pw.Radius.circular(8)),
                border: pw.Border.all(color: PdfColors.grey300),
              ),
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text(
                    'ПІДСУМОК',
                    style: pw.TextStyle(
                      font: otoiwoBoldFont,
                      fontSize: 18,
                      fontWeight: pw.FontWeight.bold,
                    ),
                  ),
                  pw.SizedBox(height: 12),
                  _buildSummaryRow('Всього товарів:', '${products.length}', otoiwoFont, otoiwoBoldFont),
                  _buildSummaryRow('Загальний залишок:', '$totalStock', otoiwoFont, otoiwoBoldFont, color: PdfColors.green),
                  _buildSummaryRow('Загальна кількість по факту:', '$totalActual', otoiwoFont, otoiwoBoldFont, color: PdfColors.blue),
                  _buildSummaryRow('Різниця:', '$totalDiff', otoiwoFont, otoiwoBoldFont, color: totalDiff >= 0 ? PdfColors.green : PdfColors.red),
                  pw.Divider(),
                  _buildSummaryRow('Вартість за залишком:', '${totalStockPrice.toStringAsFixed(2)} грн', otoiwoFont, otoiwoBoldFont),
                  _buildSummaryRow('Вартість по факту:', '${totalActualPrice.toStringAsFixed(2)} грн', otoiwoFont, otoiwoBoldFont),
                  _buildSummaryRow('Різниця у вартості:', '${totalPriceDiff.toStringAsFixed(2)} грн', otoiwoFont, otoiwoBoldFont,
                      color: totalPriceDiff >= 0 ? PdfColors.green : PdfColors.red),
                ],
              ),
            ),
            pw.SizedBox(height: 16),
            ..._buildGroupedProductTables(products, otoiwoFont, otoiwoBoldFont),
          ];
        },
      ),
    );

    final output = await getTemporaryDirectory();
    final file = File('${output.path}/recount_${DateTime.now().millisecondsSinceEpoch}.pdf');
    return await file.writeAsBytes(await pdf.save());
  }

  static pw.Widget _buildSummaryRow(
    String label,
    String value,
    pw.Font font,
    pw.Font boldFont, {
    PdfColor? color,
  }) {
    return pw.Row(
      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
      children: [
        pw.Text(label, style: pw.TextStyle(font: font, fontSize: 12)),
        pw.Text(
          value,
          style: pw.TextStyle(
            font: boldFont,
            fontSize: 12,
            fontWeight: pw.FontWeight.bold,
            color: color,
          ),
        ),
      ],
    );
  }

  static List<pw.Widget> _buildGroupedProductTables(List<Map<String, dynamic>> products, pw.Font font, pw.Font boldFont) {
    final groupedProducts = _groupProductsByGender(products);
    final tableRows = <pw.TableRow>[];

    // Add table header
    tableRows.add(
      pw.TableRow(
        decoration: const pw.BoxDecoration(color: PdfColors.blue900),
        children: [
          _buildTableCell('Назва товару', font: boldFont, color: PdfColors.white, isHeader: true),
          _buildTableCell('Ціна', font: boldFont, color: PdfColors.white, isHeader: true),
          _buildTableCell('Залишок', font: boldFont, color: PdfColors.white, isHeader: true),
          _buildTableCell('По факту', font: boldFont, color: PdfColors.white, isHeader: true),
          _buildTableCell('Різниця', font: boldFont, color: PdfColors.white, isHeader: true),
        ],
      ),
    );

    int overallIndex = 0;
    
    for (final entry in groupedProducts.entries) {
      if (entry.value.isEmpty) continue;

      // Add category separator row
      tableRows.add(
        pw.TableRow(
          decoration: const pw.BoxDecoration(color: PdfColors.grey300),
          children: [
            pw.Container(
              padding: const pw.EdgeInsets.symmetric(vertical: 8, horizontal: 8),
              child: pw.Text(
                '${entry.key.toUpperCase()} (${entry.value.length} позицій)',
                style: pw.TextStyle(
                  font: boldFont,
                  fontSize: 11,
                  fontWeight: pw.FontWeight.bold,
                  color: PdfColors.black,
                ),
              ),
            ),
            pw.Container(), // Empty cells
            pw.Container(),
            pw.Container(),
            pw.Container(),
          ],
        ),
      );

      // Add products for this category
      for (int i = 0; i < entry.value.length; i++) {
        final p = entry.value[i];
        final diff = _toInt(p['actual_count']) - _toInt(p['stock_count']);
        final isEven = overallIndex % 2 == 0;

        tableRows.add(
          pw.TableRow(
            decoration: pw.BoxDecoration(
              color: isEven ? PdfColors.grey50 : PdfColors.white,
            ),
            children: [
              _buildTableCell(p['name']?.toString() ?? '', font: font),
              _buildTableCell('${_toDouble(p['price']).toStringAsFixed(2)} грн', font: font),
              _buildTableCell(_toInt(p['stock_count']).toString(), font: font),
              _buildTableCell(_toInt(p['actual_count']).toString(), font: font),
              _buildTableCell(
                diff == 0 ? '' : diff.toString(),
                font: boldFont,
                color: diff > 0 ? PdfColors.green : (diff < 0 ? PdfColors.red : PdfColors.black),
              ),
            ],
          ),
        );
        overallIndex++;
      }
    }

    return [
      pw.Table(
        border: pw.TableBorder.all(color: PdfColors.grey400),
        columnWidths: const {
          0: pw.FlexColumnWidth(3),
          1: pw.FlexColumnWidth(1),
          2: pw.FlexColumnWidth(1),
          3: pw.FlexColumnWidth(1),
          4: pw.FlexColumnWidth(1),
        },
        children: tableRows,
      ),
    ];
  }

  static pw.Widget _buildTableCell(String text, {required pw.Font font, PdfColor? color, bool isHeader = false}) {
    return pw.Container(
      padding: const pw.EdgeInsets.all(8),
      child: pw.Text(
        text,
        style: pw.TextStyle(
          font: font,
          fontSize: isHeader ? 12 : 10,
          fontWeight: isHeader ? pw.FontWeight.bold : pw.FontWeight.normal,
          color: color ?? PdfColors.black,
        ),
        textAlign: isHeader ? pw.TextAlign.center : pw.TextAlign.left,
      ),
    );
  }

  static int _toInt(dynamic v) => v is int ? v : int.tryParse(v.toString()) ?? 0;
  static double _toDouble(dynamic v) => v is double ? v : double.tryParse(v.toString()) ?? 0.0;
}
