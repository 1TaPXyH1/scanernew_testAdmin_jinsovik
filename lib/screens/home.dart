import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';
import '../screens/scan.dart';
import '../recount/recount_main_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  String _appVersion = '';
  String selectedStore = 'Харківське шосе';

  final List<String> stores = ['Харківське шосе', 'Вся мережа'];

  @override
  void initState() {
    super.initState();
    _loadVersion();
  }

  Future<void> _loadVersion() async {
    try {
      final packageInfo = await PackageInfo.fromPlatform();
      if (mounted) {
        setState(() {
          _appVersion = 'Версія ${packageInfo.version}';
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() => _appVersion = 'Версія 1.0');
      }
    }
  }

  void _showStorePicker() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.black87,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) {
        return ListView.builder(
          shrinkWrap: true,
          itemCount: stores.length,
          itemBuilder: (context, index) {
            final store = stores[index];
            final isSelected = store == selectedStore;
            return ListTile(
              leading: Icon(
                isSelected ? Icons.check_circle : Icons.storefront,
                color: isSelected ? Colors.orangeAccent : Colors.white54,
              ),
              title: Text(
                store,
                style: TextStyle(
                  color: isSelected ? Colors.orangeAccent : Colors.white70,
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                  fontSize: 18,
                ),
              ),
              onTap: () {
                setState(() {
                  selectedStore = store;
                });
                Navigator.pop(context);
              },
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: true,
      child: Scaffold(
        body: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [Colors.black, Colors.blueGrey.shade900],
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
            ),
          ),
          child: SafeArea(
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                  child: Row(
                    children: [
                      const Icon(Icons.qr_code_scanner, color: Colors.white70, size: 22),
                      const SizedBox(width: 8),
                      const Text(
                        'Jinsovik Сканер',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const Spacer(),
                    ],
                  ),
                ),
                const Spacer(flex: 2),
                Container(
                  decoration: BoxDecoration(
                    color: Colors.orangeAccent.withAlpha(25),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: Colors.orangeAccent.withAlpha(63)),
                  ),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(16),
                    onTap: _showStorePicker,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.storefront, color: Colors.orangeAccent.shade200, size: 20),
                          const SizedBox(width: 10),
                          Text(
                            selectedStore,
                            style: TextStyle(color: Colors.orangeAccent.shade200, fontSize: 17, fontWeight: FontWeight.w600),
                          ),
                          const SizedBox(width: 6),
                          Icon(Icons.expand_more, color: Colors.orangeAccent.shade200.withAlpha(179), size: 22),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 48),
                SizedBox(
                  width: 200,
                  height: 200,
                  child: ElevatedButton(
                    onPressed: () {
                      Navigator.of(context).push(
                        PageRouteBuilder(
                          pageBuilder: (context, animation, secondaryAnimation) =>
                              ScanScreen(selectedStore: selectedStore),
                          transitionsBuilder:
                              (context, animation, secondaryAnimation, child) {
                            return SlideTransition(
                              position: Tween<Offset>(
                                begin: const Offset(0.0, 1.0),
                                end: Offset.zero,
                              ).animate(animation),
                              child: FadeTransition(
                                opacity: animation,
                                child: child,
                              ),
                            );
                          },
                          transitionDuration: const Duration(milliseconds: 300),
                        ),
                      );
                    },
                    style: ElevatedButton.styleFrom(
                      shape: const CircleBorder(),
                      backgroundColor: Colors.orangeAccent,
                      shadowColor: Colors.orangeAccent.withAlpha(128),
                      elevation: 12,
                    ),
                    child: const Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.camera_alt_outlined, size: 48, color: Colors.white),
                        SizedBox(height: 8),
                        Text(
                          'СКАНУВАТИ',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 48),
                SizedBox(
                  width: 220,
                  child: OutlinedButton.icon(
                    onPressed: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (context) => const RecountMainScreen(),
                        ),
                      );
                    },
                    icon: const Icon(Icons.bar_chart_rounded, size: 20, color: Colors.white70),
                    label: const Text(
                      'Переоблік товарів',
                      style: TextStyle(
                        color: Colors.white70,
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: Colors.white24),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(24),
                      ),
                      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 24),
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                const SizedBox(height: 48),
                Text(
                  _appVersion,
                  style: const TextStyle(
                    fontSize: 13,
                    color: Colors.white54,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 16),
                const Spacer(flex: 1),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
