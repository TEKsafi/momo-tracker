import 'package:flutter/material.dart';
import '../models/message_source.dart';
import '../services/local_store.dart';
import '../theme/app_theme.dart';

class MessageSourcesScreen extends StatefulWidget {
  const MessageSourcesScreen({super.key});
  @override
  State<MessageSourcesScreen> createState() => _MessageSourcesScreenState();
}

class _MessageSourcesScreenState extends State<MessageSourcesScreen> {
  List<MessageSource> _sources = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final sources = await LocalStore.getMessageSources();
    setState(() => _sources = sources);
  }

  Future<void> _toggle(MessageSource s, bool value) async {
    s.enabled = value;
    await LocalStore.saveMessageSources(_sources);
    setState(() {});
  }

  Future<void> _delete(MessageSource s) async {
    _sources.removeWhere((x) => x.id == s.id);
    await LocalStore.saveMessageSources(_sources);
    setState(() {});
  }

  Future<void> _addCustom() async {
    final nameController = TextEditingController();
    final senderController = TextEditingController();
    final result = await showModalBottomSheet<bool>(
      context: context,
      backgroundColor: AppColors.card,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(left: 20, right: 20, top: 20, bottom: MediaQuery.of(ctx).viewInsets.bottom + 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Add a message source', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
            const SizedBox(height: 4),
            const Text('For a bank or service not already listed.', style: TextStyle(fontSize: 12, color: AppColors.muted)),
            const SizedBox(height: 16),
            const Text('Name', style: TextStyle(fontSize: 12.5, color: AppColors.muted)),
            const SizedBox(height: 6),
            TextField(controller: nameController, autofocus: true, decoration: const InputDecoration(hintText: 'e.g. Cogebanque')),
            const SizedBox(height: 14),
            const Text('Sender ID text', style: TextStyle(fontSize: 12.5, color: AppColors.muted)),
            const SizedBox(height: 6),
            TextField(controller: senderController, decoration: const InputDecoration(hintText: 'e.g. Cogebanque or COGEBNK')),
            const SizedBox(height: 6),
            const Text(
              "Check the exact sender name shown in your Messages app for a real text from them \u2014 this has to match, even partially.",
              style: TextStyle(fontSize: 11, color: AppColors.muted),
            ),
            const SizedBox(height: 20),
            ElevatedButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Add source')),
          ],
        ),
      ),
    );

    if (result == true && nameController.text.trim().isNotEmpty && senderController.text.trim().isNotEmpty) {
      _sources.add(MessageSource(
        id: LocalStore.uuid.v4(),
        label: nameController.text.trim(),
        senderKeywords: [senderController.text.trim()],
        enabled: true,
      ));
      await LocalStore.saveMessageSources(_sources);
      setState(() {});
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Message sources')),
      floatingActionButton: FloatingActionButton(onPressed: _addCustom, child: const Icon(Icons.add)),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          const Text(
            "Only messages from a source you've turned on here are ever read as transactions \u2014 everything else (personal texts, OTP codes, promotions) is ignored automatically.",
            style: TextStyle(fontSize: 12.5, color: AppColors.muted),
          ),
          const SizedBox(height: 20),
          ..._sources.map((s) => Card(
                margin: const EdgeInsets.only(bottom: 10),
                child: ListTile(
                  title: Text(s.label, style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600)),
                  subtitle: Text(s.senderKeywords.join(', '), style: const TextStyle(fontSize: 11.5, color: AppColors.muted)),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Switch(value: s.enabled, onChanged: (v) => _toggle(s, v), activeThumbColor: AppColors.accent),
                      if (!s.isBuiltIn)
                        IconButton(icon: const Icon(Icons.delete_outline, size: 18, color: AppColors.muted), onPressed: () => _delete(s)),
                    ],
                  ),
                ),
              )),
        ],
      ),
    );
  }
}
