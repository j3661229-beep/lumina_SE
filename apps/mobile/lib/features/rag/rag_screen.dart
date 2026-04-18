import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'rag_provider.dart';

class RagScreen extends ConsumerStatefulWidget {
  const RagScreen({super.key});
  @override
  ConsumerState<RagScreen> createState() => _RagScreenState();
}

class _RagScreenState extends ConsumerState<RagScreen> {
  final _queryCtrl = TextEditingController();
  List<Map<String, dynamic>> _results = [];
  bool _searching = false;

  Future<void> _search() async {
    final q = _queryCtrl.text.trim();
    if (q.isEmpty) return;
    setState(() => _searching = true);
    final results = await ref.read(ragProvider.notifier).search(q);
    setState(() { _results = results; _searching = false; });
  }

  @override
  Widget build(BuildContext context) {
    final ragState = ref.watch(ragProvider);
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(title: const Text('Study Buddy (RAG)')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            // Info card
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                gradient: LinearGradient(colors: [cs.primaryContainer, cs.secondaryContainer]),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Row(children: [
                const Icon(Icons.offline_bolt_outlined),
                const SizedBox(width: 10),
                Expanded(child: Text('Offline semantic search over your notes & PDFs', style: TextStyle(color: cs.onPrimaryContainer))),
              ]),
            ),
            const SizedBox(height: 16),
            Row(children: [
              Expanded(
                child: TextField(
                  controller: _queryCtrl,
                  decoration: const InputDecoration(
                    hintText: 'Ask anything about your notes...',
                    prefixIcon: Icon(Icons.search),
                  ),
                  onSubmitted: (_) => _search(),
                ),
              ),
              const SizedBox(width: 8),
              FilledButton(onPressed: _searching ? null : _search, child: const Icon(Icons.search)),
            ]),
            const SizedBox(height: 12),

            ragState.when(
              loading: () => const LinearProgressIndicator(),
              error: (e, _) => Text('$e', style: TextStyle(color: cs.error)),
              data: (_) => const SizedBox(),
            ),

            if (_searching) const LinearProgressIndicator(),

            Expanded(
              child: _results.isEmpty
                  ? Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
                      Icon(Icons.auto_stories_outlined, size: 64, color: cs.outline),
                      const SizedBox(height: 12),
                      Text('Upload notes or PDFs to enable semantic search',
                        textAlign: TextAlign.center, style: TextStyle(color: cs.outline)),
                    ]))
                  : ListView.builder(
                      itemCount: _results.length,
                      itemBuilder: (ctx, i) {
                        final r = _results[i];
                        return Card(
                          child: Padding(
                            padding: const EdgeInsets.all(14),
                            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                              Row(children: [
                                Icon(Icons.article_outlined, size: 16, color: cs.primary),
                                const SizedBox(width: 6),
                                Text(r['docTitle'] ?? '', style: TextStyle(fontWeight: FontWeight.w700, color: cs.primary, fontSize: 13)),
                              ]),
                              const SizedBox(height: 6),
                              Text(r['chunkText'] ?? '', style: const TextStyle(fontSize: 14), maxLines: 4, overflow: TextOverflow.ellipsis),
                            ]),
                          ),
                        );
                      },
                    ),
            ),

            // Upload button
            ElevatedButton.icon(
              onPressed: () => ref.read(ragProvider.notifier).pickAndIndex(),
              icon: const Icon(Icons.upload_file_outlined),
              label: const Text('Upload Notes / PDF'),
            ),
          ],
        ),
      ),
    );
  }
}
