import 'dart:convert';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';

import '../models/transaction.dart';
import '../services/backup_service.dart';
import '../services/local_store.dart';
import '../services/sms_service_android.dart';
import '../services/notification_service.dart';
import '../theme/app_theme.dart';
import 'savings_goals_screen.dart';
import 'message_sources_screen.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});
  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  Map<String, dynamic> _settings = {};
  List<MoneyAccount> _accounts = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final s = await LocalStore.getSettings();
      final accounts = await LocalStore.getMoneyAccounts();
      setState(() {
        _settings = s;
        _accounts = accounts;
      });
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

  Future<void> _toggleNotifyOnTransaction(bool value) async {
    setState(() => _settings['notifyOnTransaction'] = value);
    await LocalStore.saveSettings(_settings);
  }

  Future<void> _toggleDailyCheckin(bool value) async {
    setState(() => _settings['dailyCheckinEnabled'] = value);
    await LocalStore.saveSettings(_settings);
    if (value) {
      await NotificationService.scheduleDailyCheckin(
        hour: _settings['dailyCheckinHour'] ?? 20,
        minute: _settings['dailyCheckinMinute'] ?? 0,
      );
    } else {
      await NotificationService.cancelDailyCheckin();
    }
  }

  Future<void> _setThemeMode(ThemeMode mode) async {
    appThemeController.value = mode;
    _settings['themeMode'] = switch (mode) {
      ThemeMode.light => 'light',
      ThemeMode.dark => 'dark',
      ThemeMode.system => 'dark',
    };
    await LocalStore.saveSettings(_settings);
    if (mounted) setState(() {});
  }

  Future<void> _pickCheckinTime() async {
    final current = TimeOfDay(hour: _settings['dailyCheckinHour'] ?? 20, minute: _settings['dailyCheckinMinute'] ?? 0);
    final picked = await showTimePicker(context: context, initialTime: current);
    if (picked == null) return;
    setState(() {
      _settings['dailyCheckinHour'] = picked.hour;
      _settings['dailyCheckinMinute'] = picked.minute;
    });
    await LocalStore.saveSettings(_settings);
    if (_settings['dailyCheckinEnabled'] == true) {
      await NotificationService.scheduleDailyCheckin(hour: picked.hour, minute: picked.minute);
    }
  }

  Future<void> _addAccount() async {
    final nameController = TextEditingController();
    var type = 'mobile money';
    final saved = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.card,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheetState) => Padding(
          padding: EdgeInsets.only(left: 20, right: 20, top: 20, bottom: MediaQuery.of(ctx).viewInsets.bottom + 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Add money source', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
              const SizedBox(height: 14),
              TextField(controller: nameController, autofocus: true, decoration: const InputDecoration(labelText: 'Name', hintText: 'Airtel Money or Bank account')),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                initialValue: type,
                items: const [
                  DropdownMenuItem(value: 'mobile money', child: Text('Mobile money')),
                  DropdownMenuItem(value: 'bank', child: Text('Bank')),
                  DropdownMenuItem(value: 'cash', child: Text('Cash on hand')),
                ],
                onChanged: (value) => setSheetState(() => type = value ?? type),
                decoration: const InputDecoration(labelText: 'Type'),
              ),
              const SizedBox(height: 18),
              ElevatedButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Add source')),
            ],
          ),
        ),
      ),
    );
    if (saved == true && nameController.text.trim().isNotEmpty) {
      final accounts = [..._accounts, MoneyAccount(id: LocalStore.uuid.v4(), name: nameController.text.trim(), type: type)];
      await LocalStore.saveMoneyAccounts(accounts);
      setState(() => _accounts = accounts);
    }
  }

  Future<void> _setCashReminder(bool enabled) async {
    setState(() => _settings['cashReminderEnabled'] = enabled);
    await LocalStore.saveSettings(_settings);
    if (enabled) {
      await NotificationService.scheduleCashReminder(intervalMinutes: _settings['cashReminderIntervalMinutes'] ?? 60);
    } else {
      await NotificationService.cancelCashReminder();
    }
  }

  Future<void> _setCashReminderInterval(int minutes) async {
    setState(() => _settings['cashReminderIntervalMinutes'] = minutes);
    await LocalStore.saveSettings(_settings);
    if (_settings['cashReminderEnabled'] == true) {
      await NotificationService.scheduleCashReminder(intervalMinutes: minutes);
    }
  }

  Future<void> _exportBackup() async {
    try {
      final json = await BackupService.exportJson();
      await Clipboard.setData(ClipboardData(text: json));
      await SharePlus.instance.share(
        ShareParams(
          text: json,
          subject: 'Budgeta backup',
        ),
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Backup exported and ready to share. Keep it before reinstalling.')),
        );
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not export backup. Please try again.')),
        );
      }
    }
  }

  Future<void> _importBackup() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['json'],
        withData: true,
      );

      if (result == null || result.files.isEmpty || result.files.single.path == null) {
        return;
      }

      final file = File(result.files.single.path!);
      final jsonText = await file.readAsString();
      final decoded = jsonDecode(jsonText);
      if (decoded is! Map<String, dynamic>) {
        throw const FormatException('Invalid backup format');
      }

      await BackupService.importAll(decoded);
      await _load();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Backup restored successfully.')),
        );
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Import failed. Please choose a valid Budgeta backup JSON file.')),
        );
      }
    }
  }

  Future<void> _editProfile() async {
    final nameController = TextEditingController(text: _settings['name'] ?? '');
    final emailController = TextEditingController(text: _settings['email'] ?? '');
    final phoneController = TextEditingController(text: _settings['phone'] ?? '');
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
              const SizedBox(height: 14),
              const Text('Phone number', style: TextStyle(fontSize: 12.5, color: AppColors.muted)),
              const SizedBox(height: 6),
              TextField(controller: phoneController, keyboardType: TextInputType.phone),
            const SizedBox(height: 20),
            ElevatedButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Save changes')),
          ],
        ),
      ),
    );
    if (saved == true) {
      _settings['name'] = nameController.text.trim();
      _settings['email'] = emailController.text.trim();
      _settings['phone'] = phoneController.text.trim();
      await LocalStore.saveSettings(_settings);
      _load();
    }
  }

  @override
  Widget build(BuildContext context) {
    final name = (_settings['name'] as String?) ?? '';
    final email = (_settings['email'] as String?) ?? '';
    final emailUsername = email.contains('@') ? email.split('@').first.trim() : '';
    final displayName = name.trim().isNotEmpty ? name.trim() : emailUsername;
    final initials = displayName.isEmpty
        ? '?'
      : displayName.split(RegExp(r'\s+')).map((w) => w[0]).take(2).join().toUpperCase();
    final checkinHour = _settings['dailyCheckinHour'] ?? 20;
    final checkinMinute = _settings['dailyCheckinMinute'] ?? 0;
    final checkinTimeLabel = TimeOfDay(hour: checkinHour, minute: checkinMinute).format(context);

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
                            Text(displayName.isEmpty ? 'Add your profile details' : displayName, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
                          if (email.isNotEmpty) Text(email, style: const TextStyle(fontSize: 12, color: AppColors.muted)),
                            if ((_settings['phone'] as String?)?.isNotEmpty == true) Text(_settings['phone'], style: const TextStyle(fontSize: 12, color: AppColors.muted)),
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
            const Text('Money sources', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700)),
            const SizedBox(height: 10),
            Card(
              child: Column(
                children: [
                  ..._accounts.map((account) => ListTile(
                        leading: Icon(account.type == 'cash' ? Icons.payments_outlined : account.type == 'bank' ? Icons.account_balance_outlined : Icons.account_balance_wallet_outlined, color: AppColors.accent),
                        title: Text(account.name, style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600)),
                        subtitle: Text(account.type, style: const TextStyle(fontSize: 11.5, color: AppColors.muted)),
                      )),
                  ListTile(leading: const Icon(Icons.add, color: AppColors.accent), title: const Text('Add MTN, Airtel, bank, or cash', style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600)), onTap: _addAccount),
                ],
              ),
            ),
            const SizedBox(height: 24),
          const Text('Appearance', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700)),
          const SizedBox(height: 10),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Theme', style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 10),
                  SegmentedButton<ThemeMode>(
                    segments: const [
                      ButtonSegment(value: ThemeMode.light, icon: Icon(Icons.light_mode_rounded), label: Text('Light')),
                      ButtonSegment(value: ThemeMode.dark, icon: Icon(Icons.dark_mode_rounded), label: Text('Dark')),
                    ],
                    selected: {appThemeController.value},
                    onSelectionChanged: (value) => _setThemeMode(value.first),
                    showSelectedIcon: false,
                  ),
                ],
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
                              const Text('Auto-read messages', style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600)),
                              const SizedBox(height: 3),
                              const Text('Log transactions the moment a text arrives from an enabled source', style: TextStyle(fontSize: 11.5, color: AppColors.muted)),
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
                          "Apple doesn't allow any app to read SMS automatically — that's an Apple restriction, not a limit of this app. Paste or share a message from Messages to log it instead.",
                          style: TextStyle(fontSize: 11.5, color: AppColors.muted),
                        ),
                      ],
                    ),
            ),
          ),
          const SizedBox(height: 12),
          Card(
            child: ListTile(
              leading: const Icon(Icons.tune, color: AppColors.accent),
              title: const Text('Message sources', style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600)),
              subtitle: const Text('Choose which senders count — MoMo, your bank, or a custom one', style: TextStyle(fontSize: 11.5, color: AppColors.muted)),
              trailing: const Icon(Icons.chevron_right, color: AppColors.muted),
              onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const MessageSourcesScreen())),
            ),
          ),
          const SizedBox(height: 24),
          const Text('Backup & restore', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700)),
          const SizedBox(height: 10),
          Card(
            child: Column(
              children: [
                ListTile(
                  leading: const Icon(Icons.upload_file_outlined, color: AppColors.accent),
                  title: const Text('Export data', style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600)),
                  subtitle: const Text('Save your budgets, transactions, and settings before reinstalling', style: TextStyle(fontSize: 11.5, color: AppColors.muted)),
                  onTap: _exportBackup,
                ),
                const Divider(height: 1, color: AppColors.border),
                ListTile(
                  leading: const Icon(Icons.download_outlined, color: AppColors.accent),
                  title: const Text('Import data', style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600)),
                  subtitle: const Text('Restore a previously exported Budgeta backup after reinstalling', style: TextStyle(fontSize: 11.5, color: AppColors.muted)),
                  onTap: _importBackup,
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          const Text('Notifications', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700)),
          const SizedBox(height: 10),
          Card(
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('Notify when a transaction is logged', style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600)),
                            const SizedBox(height: 3),
                            const Text('A quick alert every time a message is auto-parsed', style: TextStyle(fontSize: 11.5, color: AppColors.muted)),
                          ],
                        ),
                      ),
                      Switch(value: _settings['notifyOnTransaction'] == true, onChanged: _toggleNotifyOnTransaction, activeThumbColor: AppColors.accent),
                    ],
                  ),
                ),
                const Divider(height: 1, color: AppColors.border),
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('Daily cash check-in', style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600)),
                            const SizedBox(height: 3),
                            const Text('A reminder to log anything by hand — cash given or received', style: TextStyle(fontSize: 11.5, color: AppColors.muted)),
                          ],
                        ),
                      ),
                      Switch(value: _settings['dailyCheckinEnabled'] == true, onChanged: _toggleDailyCheckin, activeThumbColor: AppColors.accent),
                    ],
                  ),
                ),
                if (_settings['dailyCheckinEnabled'] == true) ...[
                  const Divider(height: 1, color: AppColors.border),
                  ListTile(
                    title: const Text('Reminder time', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                    trailing: Text(checkinTimeLabel, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.accent)),
                    onTap: _pickCheckinTime,
                  ),
                ],
                  const Divider(height: 1, color: AppColors.border),
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: Row(
                      children: [
                        const Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text('Cash recording reminders', style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600)), SizedBox(height: 3), Text('Vibrates and asks you to record cash on hand', style: TextStyle(fontSize: 11.5, color: AppColors.muted))])),
                        Switch(value: _settings['cashReminderEnabled'] == true, onChanged: _setCashReminder, activeThumbColor: AppColors.accent),
                      ],
                    ),
                  ),
                  if (_settings['cashReminderEnabled'] == true) ...[
                    const Divider(height: 1, color: AppColors.border),
                    ListTile(
                      title: const Text('Reminder interval', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                      subtitle: const Text('Short reminders use a foreground Android loop so they can fire on time', style: TextStyle(fontSize: 11, color: AppColors.muted)),
                      trailing: DropdownButton<int>(
                        value: [1, 5, 10, 30, 60].contains(_settings['cashReminderIntervalMinutes'])
                            ? _settings['cashReminderIntervalMinutes']
                            : 30,
                        items: const [
                          DropdownMenuItem(value: 1, child: Text('1 min')),
                          DropdownMenuItem(value: 5, child: Text('5 min')),
                          DropdownMenuItem(value: 10, child: Text('10 min')),
                          DropdownMenuItem(value: 30, child: Text('30 min')),
                          DropdownMenuItem(value: 60, child: Text('1 hour')),
                        ],
                        onChanged: (value) {
                          if (value != null) _setCashReminderInterval(value);
                        },
                      ),
                    ),
                  ],
              ],
            ),
          ),
          const SizedBox(height: 24),
          const Text('How allocations work', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700)),
          const SizedBox(height: 10),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Text(
                "MoMo tracks one pooled balance. Budgeta can't physically split real money — allocating lets you assign incoming money to a budget, so each one keeps its own running total even though your real MoMo balance stays a single number.",
                style: TextStyle(fontSize: 12, color: AppColors.mutedFor(context)),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
