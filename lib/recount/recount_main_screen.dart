import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../services/session_storage.dart';
import 'recount_new_scan_screen.dart';
import 'recount_past_sessions_screen.dart';
import 'recount_session_manager.dart';

class RecountMainScreen extends StatelessWidget {
  const RecountMainScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final activeSession = context.watch<SessionStorage>().currentSession;

    return Scaffold(
      backgroundColor: const Color(0xFF121212),
      appBar: AppBar(
        backgroundColor: const Color(0xFF121212),
        elevation: 0,
        title: const Text('Переоблік'),
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
        child: SafeArea(
          top: false,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
            children: [
              const Text(
                'Переоблік товарів',
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Створюйте, продовжуйте та переглядайте переобліки.',
                style: TextStyle(fontSize: 15, color: Colors.white60),
              ),
              const SizedBox(height: 28),
              if (activeSession != null) ...[
                _RecountActionCard(
                  icon: Icons.play_arrow_rounded,
                  accent: Colors.orangeAccent,
                  eyebrow: 'НЕЗАВЕРШЕНИЙ ПЕРЕОБЛІК',
                  title: 'Продовжити сесію',
                  description: 'Повернутися до збережених товарів',
                  onTap: () {
                    context
                        .read<RecountSessionManager>()
                        .loadSession(activeSession.id);
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => RecountNewScanScreen(
                          sessionId: activeSession.id,
                          sessionIds: [activeSession.id],
                        ),
                      ),
                    );
                  },
                ),
                const SizedBox(height: 12),
              ],
              _RecountActionCard(
                icon: Icons.qr_code_scanner_rounded,
                accent: Colors.orangeAccent,
                eyebrow: 'НОВА СЕСІЯ',
                title: 'Розпочати переоблік',
                description: 'Скануйте товари та звіряйте кількість',
                prominent: true,
                onTap: () async {
                  final sessionId = await context
                      .read<RecountSessionManager>()
                      .startNewSession();
                  if (!context.mounted) return;
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => RecountNewScanScreen(
                        sessionId: sessionId,
                        sessionIds: [sessionId],
                      ),
                    ),
                  );
                },
              ),
              const SizedBox(height: 12),
              _RecountActionCard(
                icon: Icons.history_rounded,
                accent: Colors.blueGrey.shade200,
                eyebrow: 'АРХІВ',
                title: 'Минулі сесії',
                description: 'Переглянути історію та PDF-звіти',
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => const RecountPastSessionsScreen(),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _RecountActionCard extends StatelessWidget {
  const _RecountActionCard({
    required this.icon,
    required this.accent,
    required this.eyebrow,
    required this.title,
    required this.description,
    required this.onTap,
    this.prominent = false,
  });

  final IconData icon;
  final Color accent;
  final String eyebrow;
  final String title;
  final String description;
  final VoidCallback onTap;
  final bool prominent;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: prominent ? const Color(0xFF242A2E) : const Color(0xFF1E1E1E),
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: accent.withAlpha(prominent ? 110 : 55)),
          ),
          child: Row(
            children: [
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  color: accent.withAlpha(35),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, color: accent, size: 28),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      eyebrow,
                      style: TextStyle(
                        color: accent,
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.8,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      title,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 19,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      description,
                      style: const TextStyle(color: Colors.white60, fontSize: 14),
                    ),
                  ],
                ),
              ),
              Icon(Icons.arrow_forward_ios_rounded, color: accent, size: 18),
            ],
          ),
        ),
      ),
    );
  }
}
