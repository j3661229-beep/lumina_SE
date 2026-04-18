import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:go_router/go_router.dart';
import '../../core/theme/design_tokens.dart';

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
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios_new_rounded, color: cs.onSurface),
          onPressed: () => context.canPop() ? context.pop() : context.go('/groups'),
        ),
        title: const Text('Whiteboard', style: TextStyle(fontFamily: 'Syne', fontWeight: FontWeight.w800)),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      floatingActionButton: Container(
        decoration: AppStyles.gradientButton(),
        child: FloatingActionButton(
          onPressed: _addItem,
          backgroundColor: Colors.transparent,
          elevation: 0,
          child: const Icon(Icons.add_rounded, color: Colors.white),
        ),
      ),
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
                      return Container(
                        decoration: AppStyles.glassCard(context),
                        padding: const EdgeInsets.all(16),
                        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          if (item['title'] != null)
                            Text(item['title'], style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16, fontFamily: 'Syne')),
                          if (item['title'] != null) const SizedBox(height: 8),
                          if (isCode)
                            Container(
                              padding: const EdgeInsets.all(12),
                              width: double.infinity,
                              decoration: BoxDecoration(
                                color: context.isDark ? Colors.black26 : const Color(0xFFF1F5F9),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: AppColors.border(context)),
                              ),
                              child: Text(item['content'],
                                style: TextStyle(
                                  fontFamily: 'monospace', 
                                  color: context.isDark ? AppColors.green : AppColors.indigo, 
                                  fontSize: 12, height: 1.5)),
                            )
                          else
                            Text(item['content'], style: const TextStyle(height: 1.5)),
                          const SizedBox(height: 12),
                          Row(children: [
                            Icon(Icons.person_outline_rounded, size: 14, color: Theme.of(context).colorScheme.onSurface.withOpacity(0.4)),
                            const SizedBox(width: 6),
                            Text('By ${item['author_id']?.toString().substring(0, 6)}', 
                              style: TextStyle(fontSize: 11, color: Theme.of(context).colorScheme.onSurface.withOpacity(0.4))),
                            if (isCode) ...[
                              const SizedBox(width: 12),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                decoration: BoxDecoration(
                                  color: AppColors.indigo.withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text((item['language'] as String).toUpperCase(), 
                                  style: const TextStyle(fontSize: 9, fontWeight: FontWeight.w800, color: AppColors.indigo)),
                              ),
                            ],
                            const Spacer(),
                            IconButton(
                              icon: Icon(Icons.copy_all_rounded, size: 18, color: AppColors.indigo),
                              onPressed: () {
                                Clipboard.setData(ClipboardData(text: item['content'] as String));
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(content: Text('Copied to clipboard!'), behavior: SnackBarBehavior.floating));
                              },
                            ),
                          ]),
                        ]),
                      );
                    },
                ),
    );
  }
}
