import 'dart:io';
import 'package:flutter/material.dart';
import '../services/local_store.dart';
import '../services/sms_service_android.dart';
import '../theme/app_theme.dart';
import 'savings_goals_screen.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});
  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  Map<String, dynamic> _settings = {};

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final s = await LocalStore.getSettings();
    setState(() => _settings = s);
  }

  Future<void> _toggleAutoSms(bool value) async {
    if (value && Platform.isAndroid) {
      final granted = await SmsService.requestPermissions();
      if (!granted) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Couldn't get SMS permission — auto-read needs it to work.")));
        }
        return;
      }
    }
    setState(() => _settings['autoReadSms'] = value);
    await LocalStore.saveSettings(_settings);
  }

  Future<void> _editProfile() async {
    final nameController = TextEditingController(text: _settings['name'] ?? '');
    final emailController = TextEditingController(text: _settings['email'] ?? '');
    final saved = await showModalBottomSheet<bool>(
      context: context,
      backgroundColor: AppColors.card,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(left: 20, right: 20, top: 20, bottom: MediaQuery.of(ctx).viewInsets.bottom + 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Edit profile', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
            const SizedBox(height: 16),
            const Text('Name', style: TextStyle(fontSize: 12.5, color: AppColors.muted)),
            const SizedBox(height: 6),
            TextField(controller: nameController, autofocus: true),
            const SizedBox(height: 14),
            const Text('Email', style: TextStyle(fontSize: 12.5, color: AppColors.muted)),
            const SizedBox(height: 6),
            TextField(controller: emailController, keyboardType: TextInputType.emailAddress),
            const SizedBox(height: 20),
            ElevatedButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Save changes')),
          ],
        ),
      ),
    );
    if (saved == true) {
      _settings['name'] = nameController.text.trim();
      _settings['email'] = emailController.text.trim();
      await LocalStore.saveSettings(_settings);
      _load();
    }
  }

  @override
  Widget build(BuildContext context) {
    final name = (_settings['name'] as String?) ?? '';
    final email = (_settings['email'] as String?) ?? '';
    final initials = name.trim().isEmpty
        ? '?'
        : name.trim().split(RegExp(r'\s+')).map((w) => w[0]).take(2).join().toUpperCase();

    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          InkWell(
            borderRadius: BorderRadius.circular(16),
            onTap: _editProfile,
            child: Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    CircleAvatar(radius: 24, backgroundColor: AppColors.accent.withValues(alpha: 0.15), child: Text(initials, style: const TextStyle(color: AppColors.accent, fontWeight: FontWeight.w700))),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(name.isEmpty ? 'Add your name' : name, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
                          if (email.isNotEmpty) Text(email, style: const TextStyle(fontSize: 12, color: AppColors.muted)),
                        ],
                      ),
                    ),
                    const Icon(Icons.chevron_right, color: AppColors.muted),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 24),
          const Text('Goals', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700)),
          const SizedBox(height: 10),
          Card(
            child: ListTile(
              leading: const Icon(Icons.savings_outlined, color: AppColors.accent),
              title: const Text('Savings goals', style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600)),
              subtitle: const Text('Set a target and track your progress', style: TextStyle(fontSize: 11.5, color: AppColors.muted)),
              trailing: const Icon(Icons.chevron_right, color: AppColors.muted),
              onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const SavingsGoalsScreen())),
            ),
          ),
          const SizedBox(height: 24),
          const Text('SMS reading', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700)),
          const SizedBox(height: 10),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Platform.isAndroid
                  ? Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('Auto-read MoMo SMS', style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600)),
                              const SizedBox(height: 3),
                              const Text('Log transactions the moment a MoMo text arrives', style: TextStyle(fontSize: 11.5, color: AppColors.muted)),
                            ],
                          ),
                        ),
                        Switch(value: _settings['autoReadSms'] == true, onChanged: _toggleAutoSms, activeThumbColor: AppColors.accent),
                      ],
                    )
                  : Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: const [
                        Row(children: [Icon(Icons.info_outline, size: 16, color: AppColors.warn), SizedBox(width: 8), Text('Not available on iOS', style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w700))]),
                        SizedBox(height: 6),
                        Text(
                          "Apple doesn't allow any app to read SMS automatically — that's an Apple restriction, not a limit of this app. Paste or share a MoMo message from Messages to log it instead.",
                          style: TextStyle(fontSize: 11.5, color: AppColors.muted),
                        ),
                      ],
                    ),
            ),
          ),
          const SizedBox(height: 24),
          const Text('How allocations work', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700)),
          const SizedBox(height: 10),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: const Text(
                "MoMo tracks one pooled balance. Budgeta can't physically split real money — allocating lets you assign incoming money to a budget, so each one keeps its own running total even though your real MoMo balance stays a single number.",
                style: TextStyle(fontSize: 12, color: AppColors.muted),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
