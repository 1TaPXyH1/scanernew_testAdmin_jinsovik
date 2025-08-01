import 'package:flutter/material.dart';
import 'recount_barcode_scan_screen.dart';
import 'recount_product_screen.dart';
import 'package:provider/provider.dart';
import 'recount_product_list_screen.dart';
import 'recount_session_manager.dart';

class RecountScanScreen extends StatelessWidget {
  final List<String> sessionNames;
  final String? sessionId;

  const RecountScanScreen({
    Key? key,
    required this.sessionNames,
    this.sessionId,
  }) : super(key: key);

  Future<void> _startScan(BuildContext context) async {
    while (true) {
      if (!context.mounted) return;
      final barcode = await Navigator.of(context).push<String>(
        MaterialPageRoute(
          builder: (context) => RecountBarcodeScanScreen(sessionNames: sessionNames),
        ),
      );
      if (barcode == null || barcode.isEmpty) break;

      if (!context.mounted) return;
      final result = await Navigator.of(context).push<String>(
        MaterialPageRoute(
          builder: (context) => RecountProductScreen(
            barcode: barcode,
            sessionNames: sessionNames,
          ),
        ),
      );

      if (result == 'show_list') {
        if (!context.mounted) return;
        final listResult = await Navigator.of(context).push<String>(
          MaterialPageRoute(
            builder: (_) => RecountProductListScreen(
              products: Provider.of<RecountSessionManager>(context, listen: false).products,
              sessionNames: sessionNames,
            ),
          ),
        );
        if (listResult == 'scan_more') {
          continue;
        } else if (listResult == 'finish') {
          return;
        } else {
          break;
        }
      } else if (result == 'scan_more') {
        continue;
      } else {
        break;
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Сканування (Переоблік)'),
      ),
      body: Center(
        child: ElevatedButton.icon(
          icon: const Icon(Icons.qr_code_scanner),
          label: const Text('Почати сканування'),
          onPressed: () => _startScan(context),
          style: ElevatedButton.styleFrom(
            padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 18),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            backgroundColor: Colors.blueAccent,
          ),
        ),
      ),
    );
  }
}
