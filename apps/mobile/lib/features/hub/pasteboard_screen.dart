import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:go_router/go_router.dart';

class PasteboardScreen extends StatefulWidget {
  final String groupId;
  const PasteboardScreen({super.key, required this.groupId});
  @override
  State<PasteboardScreen> createState() => _PasteboardScreenState();
}

class _PasteboardScreenState extends State<PasteboardScreen> {
  final _supabase = Supabase.instance.client;
  List<Map<String, dynamic>> _items = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final data = await _supabase
        .from('pasteboard_items')
        .select('id, title, content, language, author_id, created_at, is_pinned')
        .eq('group_id', widget.groupId)
        .order('created_at', ascending: false);
    setState(() { _items = List<Map<String, dynamic>>.from(data); _loading = false; });
  }

  Future<void> _addItem() async {
    final contentCtrl = TextEditingController();
    final titleCtrl = TextEditingController();
    final langCtrl = TextEditingController();
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom, left: 16, right: 16, top: 16),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          TextField(controller: titleCtrl, decoration: const InputDecoration(labelText: 'Title (optional)')),
          const SizedBox(height: 8),
          TextField(controller: langCtrl, decoration: const InputDecoration(labelText: 'Language (for code, optional)')),
          const SizedBox(height: 8),
          TextField(controller: contentCtrl, maxLines: 6, decoration: const InputDecoration(labelText: 'Content *')),
          const SizedBox(height: 12),
          ElevatedButton.icon(
            onPressed: () async {
              if (contentCtrl.text.trim().isEmpty) return;
              Navigator.pop(ctx);
              await _supabase.from('pasteboard_items').insert({
                'group_id': widget.groupId,
                'author_id': _supabase.auth.currentUser!.id,
                'title': titleCtrl.text.trim().isEmpty ? null : titleCtrl.text.trim(),
                'content': contentCtrl.text.trim(),
                'language': langCtrl.text.trim().isEmpty ? null : langCtrl.text.trim(),
              });
              _load();
            },
            icon: const Icon(Icons.push_pin),
            label: const Text('Pin It'),
          ),
          const SizedBox(height: 16),
        ]),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.canPop() ? context.pop() : context.go('/groups'),
        ),
        title: const Text('Pasteboard'),
        backgroundColor: Theme.of(context).colorScheme.surface,
      ),
      floatingActionButton: FloatingActionButton(onPressed: _addItem, child: const Icon(Icons.add)),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _items.isEmpty
              ? Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
                  Icon(Icons.push_pin_outlined, size: 64, color: cs.outline),
                  const SizedBox(height: 12),
                  Text('No pinned items yet', style: Theme.of(context).textTheme.titleMedium),
                ]))
              : ListView.separated(
                  padding: const EdgeInsets.all(16),
                  itemCount: _items.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 10),
                  itemBuilder: (ctx, i) {
                    final item = _items[i];
                    final isCode = item['language'] != null;
                    return Card(
                      child: Padding(
                        padding: const EdgeInsets.all(14),
                        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          if (item['title'] != null)
                            Text(item['title'], style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
                          if (item['title'] != null) const SizedBox(height: 6),
                          if (isCode)
                            Container(
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(color: const Color(0xFF1E1E2E), borderRadius: BorderRadius.circular(8)),
                              child: Text(item['content'],
                                style: const TextStyle(fontFamily: 'monospace', color: Color(0xFF50FA7B), fontSize: 12)),
                            )
                          else
                            Text(item['content']),
                          const SizedBox(height: 8),
                          Row(children: [
                            Icon(Icons.person_outline, size: 13, color: cs.outline),
                            const SizedBox(width: 4),
                            Text(item['author_id']?.toString().substring(0, 6) ?? '', style: TextStyle(fontSize: 12, color: cs.outline)),
                            if (isCode) ...[
                              const SizedBox(width: 10),
                              Chip(label: Text(item['language'], style: const TextStyle(fontSize: 11)), visualDensity: VisualDensity.compact),
                            ],
                            const Spacer(),
                            IconButton(
                              icon: Icon(Icons.copy_outlined, size: 16, color: cs.primary),
                              onPressed: () {
                                Clipboard.setData(ClipboardData(text: item['content'] as String));
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(content: Text('Copied!'), duration: Duration(seconds: 1)));
                              },
                            ),
                          ]),
                        ]),
                      ),
                    );
                  },
                ),
    );
  }
}
