import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jinsovik_scanner/main.dart';
import 'package:jinsovik_scanner/recount/recount_session_manager.dart';
import 'package:jinsovik_scanner/services/session_storage.dart';
import 'package:jinsovik_scanner/screens/home.dart';
import 'package:provider/provider.dart';

void main() {
  testWidgets('snack bar text stays readable on the dark app theme',
      (tester) async {
    final storage = SessionStorage();
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider.value(value: storage),
          ChangeNotifierProvider(
              create: (_) => RecountSessionManager(storage)),
        ],
        child: const BarcodeScannerApp(),
      ),
    );

    final context = tester.element(find.byType(HomeScreen));
    expect(Theme.of(context).snackBarTheme.contentTextStyle?.color, Colors.white);
  });
}
