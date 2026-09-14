import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import 'add_transaction_screen.dart';

class DailyCheckinScreen extends StatelessWidget {
  const DailyCheckinScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Daily check-in')),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(color: AppColors.accent.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(20)),
              child: const Icon(Icons.wallet_outlined, size: 32, color: AppColors.accent),
            ),
            const SizedBox(height: 24),
            const Text('Did you spend or receive cash today?', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800), textAlign: TextAlign.center),
            const SizedBox(height: 10),
            const Text(
              "Cash handed to someone, or cash you received, never sends a MoMo text \u2014 add it here so today's numbers stay accurate.",
              style: TextStyle(fontSize: 13, color: AppColors.muted, height: 1.5),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 28),
            ElevatedButton(
              onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const AddTransactionScreen())),
              child: const Text('Add a transaction'),
            ),
            const SizedBox(height: 10),
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Nothing to add', style: TextStyle(color: AppColors.muted)),
            ),
          ],
        ),
      ),
    );
  }
}
