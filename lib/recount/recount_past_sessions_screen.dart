import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:printing/printing.dart';
import '../services/session_storage.dart';
import '../utils/pdf_generator.dart';

class RecountPastSessionsScreen extends StatelessWidget {
  const RecountPastSessionsScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final storage = context.watch<SessionStorage>();
    final sessions = storage.pastSessions;

    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.black,
        title: const Text(
          'Минулі сесії',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.of(context).pop(),
        ),
        elevation: 0,
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [const Color(0xFF121212), Colors.blueGrey.shade900],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: sessions.isEmpty
            ? const Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.history, size: 80, color: Colors.white54),
                    SizedBox(height: 20),
                    Text(
                      'Поки що немає збережених сесій',
                      style: TextStyle(fontSize: 18, color: Colors.white70, fontWeight: FontWeight.w500),
                      textAlign: TextAlign.center,
                    ),
                    SizedBox(height: 8),
                    Text(
                      'Завершіть переоблік, щоб він з\'явився тут',
                      style: TextStyle(fontSize: 14, color: Colors.white54),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              )
            : ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: sessions.length,
                itemBuilder: (context, index) {
                  final session = sessions[index];
                  final productCount = session.products.length;
                  final totalActual = session.products.fold<int>(
                    0, (sum, p) => sum + ((p['actual_count'] as int?) ?? 0),
                  );
                  final totalStock = session.products.fold<int>(
                    0, (sum, p) => sum + ((p['stock_count'] as int?) ?? 0),
                  );

                  return Card(
                    margin: const EdgeInsets.only(bottom: 12),
                    color: const Color(0xFF1E1E1E),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: Colors.green.withAlpha(38),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: const Icon(Icons.check_circle, color: Colors.green, size: 20),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      '${session.startTime.toString().substring(0, 10)}  ${session.startTime.toString().substring(11, 16)}',
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 16,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    if (session.endTime != null)
                                      Text(
                                        'Завершено: ${session.endTime!.toString().substring(11, 16)}',
                                        style: const TextStyle(color: Colors.white54, fontSize: 12),
                                      ),
                                  ],
                                ),
                              ),
                              IconButton(
                                icon: const Icon(Icons.picture_as_pdf, color: Colors.orangeAccent, size: 20),
                                onPressed: () async {
                                  final file = await PdfGenerator.generateRecountReport(
                                    products: session.products,
                                    sessionIds: [session.id],
                                  );
                                  if (!context.mounted) return;
                                  Printing.sharePdf(bytes: await file.readAsBytes(), filename: 'recount_${session.id}.pdf');
                                },
                              ),
                              IconButton(
                                icon: const Icon(Icons.delete_outline, color: Colors.redAccent, size: 20),
                                onPressed: () async {
                                  final confirm = await showDialog<bool>(
                                    context: context,
                                    builder: (ctx) => AlertDialog(
                                      backgroundColor: const Color(0xFF424242),
                                      title: const Text('Видалити сесію?', style: TextStyle(color: Colors.white)),
                                      content: const Text('Цю дію не можна скасувати', style: TextStyle(color: Colors.white70)),
                                      actions: [
                                        TextButton(
                                          onPressed: () => Navigator.pop(ctx, false),
                                          child: const Text('Скасувати', style: TextStyle(color: Colors.white54)),
                                        ),
                                        TextButton(
                                          onPressed: () => Navigator.pop(ctx, true),
                                          child: const Text('Видалити', style: TextStyle(color: Colors.redAccent)),
                                        ),
                                      ],
                                    ),
                                  );
                                  if (confirm == true && context.mounted) {
                                    await context.read<SessionStorage>().deleteSession(session.id);
                                  }
                                },
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          Row(
                            children: [
                              _statChip(Icons.inventory, '$productCount товарів', Colors.blue),
                              const SizedBox(width: 8),
                              _statChip(Icons.checklist, 'По факту: $totalActual', Colors.orange),
                              const SizedBox(width: 8),
                              _statChip(Icons.storage, 'Залишок: $totalStock', Colors.green),
                            ],
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
      ),
    );
  }

  Widget _statChip(IconData icon, String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withAlpha(25),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withAlpha(51)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 4),
          Text(text, style: TextStyle(fontSize: 12, color: color, fontWeight: FontWeight.w500)),
        ],
      ),
    );
  }
}
