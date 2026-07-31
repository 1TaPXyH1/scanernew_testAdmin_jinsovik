import 'package:flutter/material.dart';
import 'package:printing/printing.dart';
import 'package:provider/provider.dart';

import '../services/session_storage.dart';
import '../utils/pdf_generator.dart';

class RecountPastSessionsScreen extends StatelessWidget {
  const RecountPastSessionsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final sessions = context.watch<SessionStorage>().pastSessions;

    return Scaffold(
      backgroundColor: const Color(0xFF121212),
      appBar: AppBar(
        backgroundColor: const Color(0xFF121212),
        elevation: 0,
        title: const Text('Минулі сесії'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: DecoratedBox(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFF121212), Color(0xFF19232B)],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: sessions.isEmpty
            ? const _EmptySessions()
            : ListView.builder(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
                itemCount: sessions.length + 1,
                itemBuilder: (context, index) {
                  if (index == 0) {
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 20),
                      child: Text(
                        '${sessions.length} завершених переобліків',
                        style: const TextStyle(
                            color: Colors.white60, fontSize: 15),
                      ),
                    );
                  }
                  return _SessionCard(session: sessions[index - 1]);
                },
              ),
      ),
    );
  }
}

class _EmptySessions extends StatelessWidget {
  const _EmptySessions();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Padding(
        padding: EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.history_toggle_off_rounded,
                size: 72, color: Colors.white38),
            SizedBox(height: 20),
            Text(
              'Поки що немає завершених сесій',
              style: TextStyle(
                  fontSize: 19,
                  color: Colors.white,
                  fontWeight: FontWeight.w700),
              textAlign: TextAlign.center,
            ),
            SizedBox(height: 8),
            Text(
              'Завершіть переоблік, щоб переглянути його тут.',
              style: TextStyle(fontSize: 14, color: Colors.white60),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

class _SessionCard extends StatelessWidget {
  const _SessionCard({required this.session});

  final SavedSession session;

  @override
  Widget build(BuildContext context) {
    final productCount = session.products.length;
    final totalActual = session.products.fold<int>(
      0,
      (sum, product) => sum + ((product['actual_count'] as int?) ?? 0),
    );
    final totalStock = session.products.fold<int>(
      0,
      (sum, product) => sum + ((product['stock_count'] as int?) ?? 0),
    );
    final date = session.startTime.toString().substring(0, 10);
    final startTime = session.startTime.toString().substring(11, 16);
    final endTime = session.endTime?.toString().substring(11, 16);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: const Color(0xFF1E1E1E),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: Colors.greenAccent.withAlpha(30),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.check_circle_rounded,
                    color: Colors.greenAccent),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(date,
                        style: const TextStyle(
                            color: Colors.white,
                            fontSize: 17,
                            fontWeight: FontWeight.w700)),
                    Text(
                      endTime == null
                          ? 'Розпочато о $startTime'
                          : '$startTime — $endTime',
                      style: const TextStyle(color: Colors.white54, fontSize: 13),
                    ),
                  ],
                ),
              ),
              _RoundAction(
                tooltip: 'Створити PDF',
                icon: Icons.picture_as_pdf_outlined,
                color: Colors.orangeAccent,
                onPressed: () async {
                  final file = await PdfGenerator.generateRecountReport(
                    products: session.products,
                    sessionIds: [session.id],
                  );
                  if (!context.mounted) return;
                  await Printing.sharePdf(
                    bytes: await file.readAsBytes(),
                    filename: 'recount_${session.id}.pdf',
                  );
                },
              ),
              const SizedBox(width: 6),
              _RoundAction(
                tooltip: 'Видалити сесію',
                icon: Icons.delete_outline_rounded,
                color: Colors.redAccent,
                onPressed: () async {
                  final confirmed = await showDialog<bool>(
                    context: context,
                    builder: (dialogContext) => AlertDialog(
                      backgroundColor: const Color(0xFF272727),
                      title: const Text('Видалити сесію?'),
                      content: const Text('Цю дію не можна скасувати.'),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.pop(dialogContext, false),
                          child: const Text('Скасувати'),
                        ),
                        TextButton(
                          onPressed: () => Navigator.pop(dialogContext, true),
                          child: const Text('Видалити',
                              style: TextStyle(color: Colors.redAccent)),
                        ),
                      ],
                    ),
                  );
                  if (confirmed == true && context.mounted) {
                    await context.read<SessionStorage>().deleteSession(session.id);
                    if (!context.mounted) return;
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Сесію видалено'),
                        backgroundColor: Color(0xFF30363B),
                        behavior: SnackBarBehavior.floating,
                      ),
                    );
                  }
                },
              ),
            ],
          ),
          const SizedBox(height: 18),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _SessionStat(
                  icon: Icons.inventory_2_outlined,
                  text: '$productCount товарів',
                  color: Colors.blueAccent),
              _SessionStat(
                  icon: Icons.fact_check_outlined,
                  text: 'По факту: $totalActual',
                  color: Colors.orangeAccent),
              _SessionStat(
                  icon: Icons.warehouse_outlined,
                  text: 'Залишок: $totalStock',
                  color: Colors.greenAccent),
            ],
          ),
        ],
      ),
    );
  }
}

class _RoundAction extends StatelessWidget {
  const _RoundAction({
    required this.tooltip,
    required this.icon,
    required this.color,
    required this.onPressed,
  });

  final String tooltip;
  final IconData icon;
  final Color color;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) => Material(
        color: color.withAlpha(24),
        shape: const CircleBorder(),
        child: IconButton(
          tooltip: tooltip,
          onPressed: onPressed,
          icon: Icon(icon, color: color),
        ),
      );
}

class _SessionStat extends StatelessWidget {
  const _SessionStat({
    required this.icon,
    required this.text,
    required this.color,
  });

  final IconData icon;
  final String text;
  final Color color;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
        decoration: BoxDecoration(
          color: color.withAlpha(20),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: color.withAlpha(60)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 16, color: color),
            const SizedBox(width: 6),
            Text(text,
                style: TextStyle(
                    fontSize: 13, color: color, fontWeight: FontWeight.w600)),
          ],
        ),
      );
}
