import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jinsovik_scanner/main.dart';
import 'package:jinsovik_scanner/recount/recount_session_manager.dart';
import 'package:jinsovik_scanner/screens/home.dart';
import 'package:jinsovik_scanner/services/session_storage.dart';
import 'package:provider/provider.dart';

void main() {
  testWidgets('elevated buttons do not inherit a colored shadow',
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
    final style = Theme.of(context).elevatedButtonTheme.style!;
    expect(style.elevation?.resolve(<WidgetState>{}), 0);
    expect(style.shadowColor?.resolve(<WidgetState>{}), Colors.transparent);
  });
}
