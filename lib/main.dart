import 'package:flutter/material.dart';
import 'services/local_store.dart';
import 'services/sms_service_android.dart';
import 'services/share_intent_service.dart';
import 'services/momo_sms_parser.dart';
import 'theme/app_theme.dart';
import 'screens/dashboard_screen.dart';
import 'screens/transactions_screen.dart';
import 'screens/insights_screen.dart';
import 'screens/settings_screen.dart';
import 'screens/add_transaction_screen.dart';
import 'screens/onboarding_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await LocalStore.seedIfEmpty();
  runApp(const MomoTrackerApp());
}

class MomoTrackerApp extends StatelessWidget {
  const MomoTrackerApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Budgeta — MoMo Tracker',
      debugShowCheckedModeBanner: false,
      theme: buildAppTheme(),
      home: const AppEntry(),
    );
  }
}

/// Decides whether to show onboarding (first launch) or go straight to the
/// app shell — checked once at startup against the persisted flag.
class AppEntry extends StatefulWidget {
  const AppEntry({super.key});
  @override
  State<AppEntry> createState() => _AppEntryState();
}

class _AppEntryState extends State<AppEntry> {
  bool? _hasOnboarded;

  @override
  void initState() {
    super.initState();
    _check();
  }

  Future<void> _check() async {
    final settings = await LocalStore.getSettings();
    setState(() => _hasOnboarded = settings['hasOnboarded'] == true);
  }

  @override
  Widget build(BuildContext context) {
    if (_hasOnboarded == null) return const Scaffold(body: Center(child: CircularProgressIndicator()));
    if (!_hasOnboarded!) return OnboardingScreen(onDone: () => setState(() => _hasOnboarded = true));
    return const RootShell();
  }
}

class RootShell extends StatefulWidget {
  const RootShell({super.key});
  @override
  State<RootShell> createState() => _RootShellState();
}

class _RootShellState extends State<RootShell> {
  int _index = 0;

  final _screens = const [
    DashboardScreen(),
    TransactionsScreen(),
    InsightsScreen(),
    SettingsScreen(),
  ];

  @override
  void initState() {
    super.initState();
    _initCaptureServices();
  }

  Future<void> _initCaptureServices() async {
    // Android: listener for incoming MoMo SMS while the app is running.
    final settings = await LocalStore.getSettings();
    if (settings['autoReadSms'] == true) {
      await SmsService.startListening(onNewTransaction: (_) async {
        if (mounted) setState(() {}); // refresh whichever tab is showing
      });
    }

    // iOS (and Android fallback): text shared from Messages via the Share Sheet.
    ShareIntentService.start(onSharedText: (text) {
      final parsed = MomoSmsParser.parse(text);
      if (!parsed.isConfident) return;
      // Hand off to Add Transaction pre-filled so the user confirms before
      // saving, rather than silently logging something shared by mistake.
      Navigator.of(context).push(MaterialPageRoute(builder: (_) => const AddTransactionScreen()));
    });
  }

  @override
  void dispose() {
    ShareIntentService.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(child: _screens[_index]),
      floatingActionButton: _index == 0
          ? FloatingActionButton(
              onPressed: () async {
                final saved = await Navigator.push(context, MaterialPageRoute(builder: (_) => const AddTransactionScreen()));
                if (saved == true) setState(() {});
              },
              child: const Icon(Icons.add),
            )
          : null,
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _index,
        onTap: (i) => setState(() => _index = i),
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.dashboard_outlined), label: 'Overview'),
          BottomNavigationBarItem(icon: Icon(Icons.receipt_long_outlined), label: 'Transactions'),
          BottomNavigationBarItem(icon: Icon(Icons.insights_outlined), label: 'Insights'),
          BottomNavigationBarItem(icon: Icon(Icons.settings_outlined), label: 'Settings'),
        ],
      ),
    );
  }
}
