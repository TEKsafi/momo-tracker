import 'package:flutter/material.dart';
import '../services/local_store.dart';
import '../theme/app_theme.dart';

class _Slide {
  final IconData icon;
  final String title;
  final String body;
  const _Slide(this.icon, this.title, this.body);
}

const _slides = [
  _Slide(
    Icons.sms_outlined,
    'Every MoMo message, understood',
    "Budgeta reads your MoMo texts and logs each transaction the moment it lands — no typing amounts, no forgetting to note it down.",
  ),
  _Slide(
    Icons.pie_chart_outline,
    'One balance, multiple purposes',
    "MoMo only tracks one number. Budgeta lets you split incoming money into budgets, so rent, savings, and daily spend never get mixed up again.",
  ),
  _Slide(
    Icons.insights_outlined,
    'Insights that actually help',
    'See where your money really goes each month, spot bills that repeat, and set savings goals — not just a list of numbers.',
  ),
];

class OnboardingScreen extends StatefulWidget {
  final VoidCallback onDone;
  const OnboardingScreen({super.key, required this.onDone});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final _controller = PageController();
  int _page = 0;

  Future<void> _finish() async {
    final settings = await LocalStore.getSettings();
    settings['hasOnboarded'] = true;
    await LocalStore.saveSettings(settings);
    widget.onDone();
  }

  @override
  Widget build(BuildContext context) {
    final isLast = _page == _slides.length - 1;
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            Align(
              alignment: Alignment.topRight,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: TextButton(onPressed: _finish, child: const Text('Skip', style: TextStyle(color: AppColors.muted))),
              ),
            ),
            Expanded(
              child: PageView.builder(
                controller: _controller,
                itemCount: _slides.length,
                onPageChanged: (i) => setState(() => _page = i),
                itemBuilder: (_, i) {
                  final s = _slides[i];
                  return Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 32),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          width: 84,
                          height: 84,
                          decoration: BoxDecoration(color: AppColors.accent.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(24)),
                          child: Icon(s.icon, size: 38, color: AppColors.accent),
                        ),
                        const SizedBox(height: 32),
                        Text(s.title, textAlign: TextAlign.center, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800)),
                        const SizedBox(height: 12),
                        Text(s.body, textAlign: TextAlign.center, style: const TextStyle(fontSize: 14, color: AppColors.muted, height: 1.5)),
                      ],
                    ),
                  );
                },
              ),
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(_slides.length, (i) => AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                margin: const EdgeInsets.symmetric(horizontal: 4),
                width: i == _page ? 20 : 6,
                height: 6,
                decoration: BoxDecoration(color: i == _page ? AppColors.accent : AppColors.border, borderRadius: BorderRadius.circular(3)),
              )),
            ),
            Padding(
              padding: const EdgeInsets.all(24),
              child: ElevatedButton(
                onPressed: isLast
                    ? _finish
                    : () => _controller.nextPage(duration: const Duration(milliseconds: 250), curve: Curves.easeOut),
                child: Text(isLast ? 'Get started' : 'Continue'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
