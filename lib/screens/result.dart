import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:vibration/vibration.dart';
import '../widgets/pulsing_opacity.dart';
import '../screens/scan.dart';
import '../screens/home.dart';
import '../services/api_config.dart';

class ResultsScreen extends StatefulWidget {
  final String barcode;
  final String selectedStore;

  const ResultsScreen({
    super.key,
    required this.barcode,
    required this.selectedStore,
  });

  @override
  State<ResultsScreen> createState() => _ResultsScreenState();
}

enum _ErrorType { none, network, server, notFound }

class _ResultsScreenState extends State<ResultsScreen> {
  Map<String, dynamic>? productData;
  bool isLoading = true;
  String? _errorMessage;
  _ErrorType _errorType = _ErrorType.none;

  @override
  void initState() {
    super.initState();
    fetchProductData();
  }

  String extractShortName(String fullName) {
    final regex = RegExp(r'Магазин\s+\"(.+?)\"');
    final match = regex.firstMatch(fullName);
    return match != null ? match.group(1)! : fullName;
  }

  Future<void> fetchProductData() async {
    try {
      final response = await http.get(Uri.parse(
        ApiConfig.productUrl(widget.barcode),
      )).timeout(const Duration(seconds: 10));
      if (!mounted) return;

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);

        if (data['success'] == true &&
            data['response'] is List &&
            data['response'].length == 2 &&
            data['response'][1] is List) {
          final productInfo = data['response'][0];
          final storesList = data['response'][1] as List;

          if (widget.selectedStore == 'Вся мережа') {
            final filteredStores = storesList.where((store) {
              final remaining = int.tryParse(store['remaining'].toString()) ?? 0;
              return remaining > 0;
            }).toList();

            if (filteredStores.isEmpty) {
              setState(() {
                productData = null;
                isLoading = false;
                _errorType = _ErrorType.notFound;
              });
              return;
            }

            final results = filteredStores.map((store) {
              return {
                'store': extractShortName(store['name']),
                'remaining': store['remaining'],
                'size': store['size'],
                'telephone': store['telephone'],
              };
            }).toList();

            final hasVibrator = await Vibration.hasVibrator();
            if (mounted && hasVibrator) {
              try { Vibration.vibrate(pattern: [0, 150, 100, 150]); } catch (_) {}
            }
            if (!mounted) return;

            setState(() {
              productData = {
                'multiple': results,
                'name': productInfo['good'],
                'price': productInfo['price'],
                'barcode': widget.barcode,
              };
              isLoading = false;
            });
          } else {
            final selectedLower = widget.selectedStore.toLowerCase();
            final filteredStores = storesList.where((store) {
              final storeName = extractShortName(store['name']).toLowerCase();
              return storeName.contains(selectedLower);
            }).toList();

            if (filteredStores.isEmpty) {
              setState(() {
                productData = null;
                isLoading = false;
                _errorType = _ErrorType.notFound;
              });
              return;
            }

            final results = filteredStores.map((store) {
              return {
                'store': extractShortName(store['name']),
                'remaining': store['remaining'],
                'size': store['size'],
                'telephone': store['telephone'],
              };
            }).toList();

            if (mounted && results.length == 1) {
              final hasVibrator = await Vibration.hasVibrator();
              if (hasVibrator) {
                try { Vibration.vibrate(pattern: [0, 150, 100, 150]); } catch (_) {}
              }
            }
            if (!mounted) return;

            setState(() {
              if (results.length == 1) {
                productData = {
                  'name': productInfo['good'],
                  'price': productInfo['price'],
                  'barcode': widget.barcode,
                  'store': results.first['store'],
                  'remaining': results.first['remaining'],
                  'size': results.first['size'],
                  'telephone': results.first['telephone'],
                };
              } else {
                productData = {
                  'multiple': results,
                  'name': productInfo['good'],
                  'price': productInfo['price'],
                  'barcode': widget.barcode,
                };
              }
              isLoading = false;
            });
          }
        } else {
          setState(() {
            productData = null;
            isLoading = false;
            _errorType = _ErrorType.notFound;
          });
        }
      } else {
        setState(() {
          productData = null;
          isLoading = false;
          _errorMessage = 'Помилка сервера: ${response.statusCode}';
          _errorType = _ErrorType.server;
        });
      }
    } on TimeoutException {
      setState(() {
        productData = null;
        isLoading = false;
        _errorMessage = 'Сервер не відповідає.\nПеревірте з\'єднання та спробуйте ще раз.';
        _errorType = _ErrorType.network;
      });
    } catch (e) {
      debugPrint('fetchProductData error: $e');
      setState(() {
        productData = null;
        isLoading = false;
        _errorMessage = 'Помилка з\'єднання.\nПеревірте інтернет та спробуйте ще раз.';
        _errorType = _ErrorType.network;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF121212),
      appBar: AppBar(
        backgroundColor: const Color(0xFF121212),
        title: const Text('Товар відскановано'),
        elevation: 0,
        automaticallyImplyLeading: false,
      ),
      body: DecoratedBox(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFF121212), Color(0xFF19232B)],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: isLoading
            ? _buildLoading()
            : _errorType != _ErrorType.none
                ? _buildErrorScreen()
                : productData == null
                    ? _buildErrorScreen()
                    : (productData?.containsKey('multiple') ?? false)
                        ? _buildMultipleResults()
                        : _buildSingleResult(),
      ),
    );
  }

  Widget _buildLoading() => const Center(
        child: PulsingOpacityWidget(
          isLoading: true,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.qr_code_scanner_rounded,
                  size: 60, color: Colors.orangeAccent),
              SizedBox(height: 16),
              Text('Шукаємо товар...',
                  style: TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.w700)),
              SizedBox(height: 6),
              Text('Перевіряємо наявність у магазині',
                  style: TextStyle(color: Colors.white60, fontSize: 14)),
            ],
          ),
        ),
      );

  Widget _buildErrorScreen() {
    final isNetwork = _errorType == _ErrorType.network;
    final icon = isNetwork ? Icons.cloud_off : Icons.search_off;
    final title = isNetwork
        ? (_errorMessage ?? 'Помилка з\'єднання')
        : 'Товар зі штрихкодом\n${widget.barcode}\nне знайдено';

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 80, color: const Color(0xFFCF6679)),
            const SizedBox(height: 20),
            Text(
              title,
              style: const TextStyle(color: Colors.white70, fontSize: 16),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 28),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (isNetwork) ...[
                  ElevatedButton.icon(
                    onPressed: () {
                      setState(() {
                        isLoading = true;
                        _errorType = _ErrorType.none;
                      });
                      fetchProductData();
                    },
                    icon: const Icon(Icons.refresh, size: 20),
                    label: const Text('Повторити'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.orangeAccent,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                    ),
                  ),
                  const SizedBox(width: 12),
                ],
                ElevatedButton.icon(
                  onPressed: () => Navigator.of(context).pushReplacement(
                    MaterialPageRoute(
                        builder: (_) =>
                            ScanScreen(selectedStore: widget.selectedStore)),
                  ),
                  icon: const Icon(Icons.qr_code_scanner, size: 20),
                  label: const Text('Сканувати ще'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.orange.shade700,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                  ),
                ),
              ],
            ),
            if (!isNetwork)
              Padding(
                padding: const EdgeInsets.only(top: 12),
                child: TextButton.icon(
                  onPressed: () => Navigator.of(context).pushReplacement(
                    MaterialPageRoute(
                        builder: (_) =>
                            ScanScreen(selectedStore: widget.selectedStore)),
                  ),
                  icon: const Icon(Icons.keyboard_outlined, size: 18, color: Colors.white54),
                  label: const Text('Ввести інший штрихкод', style: TextStyle(color: Colors.white54)),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildSingleResult() => ListView(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
        physics: const BouncingScrollPhysics(),
        children: [
          _buildProductHero(),
          const SizedBox(height: 12),
          _infoCard([
            const Text('Наявність у магазині',
                style: TextStyle(
                    color: Colors.white,
                    fontSize: 17,
                    fontWeight: FontWeight.w700)),
            const SizedBox(height: 14),
            _infoRow(Icons.storefront_outlined, 'Магазин', productData!['store']),
            _infoRow(Icons.inventory_2_outlined, 'Залишок', '${productData!['remaining']} шт'),
            if (productData!['size'] != null)
              _infoRow(Icons.straighten, 'Розмір', productData!['size']),
            if (productData!['telephone'] != null)
              _infoRow(Icons.phone, 'Телефон', productData!['telephone']),
          ]),
          const SizedBox(height: 20),
          _buildButtonsRow(),
        ],
      );

  Widget _buildMultipleResults() => Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 12),
            child: _buildProductHero(),
          ),
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
              physics: const BouncingScrollPhysics(),
              itemCount: productData!['multiple'].length,
              itemBuilder: (_, i) {
                final store = productData!['multiple'][i];
                return Padding(
                  padding: const EdgeInsets.only(bottom: 20),
                  child: _infoCard([
                    _infoRow(Icons.storefront_outlined, 'Магазин', store['store']),
                    _infoRow(Icons.inventory_2_outlined, 'Залишок', '${store['remaining']} шт'),
                    if (store['size'] != null)
                      _infoRow(Icons.straighten, 'Розмір', store['size']),
                    if (store['telephone'] != null)
                      _infoRow(Icons.phone, 'Телефон', store['telephone']),
                  ]),
                );
              },
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(20),
            child: _buildButtonsRow(),
          )
        ],
      );

  Widget _buildProductHero() => Container(
        width: double.infinity,
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: const Color(0xFF1E1E1E),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Colors.orangeAccent.withAlpha(90)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    color: Colors.greenAccent.withAlpha(30),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.check_circle_rounded,
                      color: Colors.greenAccent),
                ),
                const SizedBox(width: 12),
                const Expanded(
                  child: Text('Товар знайдено',
                      style: TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.w700)),
                ),
                Text('${productData!['price']} грн',
                    style: const TextStyle(
                        color: Colors.orangeAccent,
                        fontSize: 17,
                        fontWeight: FontWeight.w700)),
              ],
            ),
            const SizedBox(height: 16),
            Text(productData!['name'],
                style: const TextStyle(
                    color: Colors.white,
                    fontSize: 19,
                    fontWeight: FontWeight.w700)),
            const SizedBox(height: 8),
            Row(
              children: [
                const Icon(Icons.qr_code, size: 16, color: Colors.white38),
                const SizedBox(width: 6),
                Text(widget.barcode,
                    style: const TextStyle(color: Colors.white54, fontSize: 13)),
              ],
            ),
          ],
        ),
      );

  Widget _infoRow(IconData icon, String label, String value) => Padding(
        padding: const EdgeInsets.only(bottom: 14),
        child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.white12,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, size: 19, color: Colors.orangeAccent),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label,
                    style: const TextStyle(
                        fontSize: 14,
                        color: Colors.white60,
                        fontWeight: FontWeight.w500)),
                const SizedBox(height: 4),
                Text(value,
                    style: const TextStyle(
                        fontSize: 16,
                        color: Colors.white,
                        fontWeight: FontWeight.w600)),
              ],
            ),
          ),
        ],
      ));

  Widget _infoCard(List<Widget> children) => Container(
        width: double.infinity,
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: const Color(0xFF1E1E1E),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Colors.white12),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: children,
        ),
      );

  Widget _buildButtonsRow() => Row(
        children: [
          Expanded(
            child: ElevatedButton.icon(
              onPressed: () => Navigator.of(context).pushAndRemoveUntil(
                MaterialPageRoute(builder: (_) => const HomeScreen()),
                (_) => false,
              ),
              icon: const Icon(Icons.home),
              label: const Text('На головну'),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF30363B),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: ElevatedButton.icon(
              onPressed: () => Navigator.of(context).pushReplacement(
                MaterialPageRoute(
                    builder: (_) =>
                        ScanScreen(selectedStore: widget.selectedStore)),
              ),
              icon: const Icon(Icons.qr_code_scanner),
              label: const Text('Сканувати ще'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.orangeAccent,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ),
        ],
      );
}
