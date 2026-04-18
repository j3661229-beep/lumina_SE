import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import '../../core/theme/app_theme.dart';
import '../../shared/widgets/app_card.dart';
import '../../shared/widgets/app_button.dart';
import 'rag_provider.dart';

class RagScreen extends ConsumerStatefulWidget {
  const RagScreen({super.key});
  @override
  ConsumerState<RagScreen> createState() => _RagScreenState();
}

class _RagScreenState extends ConsumerState<RagScreen>
    with SingleTickerProviderStateMixin {
  final _queryCtrl = TextEditingController();
  final _scrollCtrl = ScrollController();
  late final AnimationController _pulseCtrl;
  late final Animation<double> _pulse;

  String? _answer;
  bool _isQuerying = false;
  bool _showDocs = false;

  @override
  void initState() {
    super.initState();
    _pulseCtrl = AnimationController(vsync: this, duration: const Duration(seconds: 2))
      ..repeat(reverse: true);
    _pulse = Tween<double>(begin: 0.8, end: 1.0).animate(
      CurvedAnimation(parent: _pulseCtrl, curve: Curves.easeInOut));
  }

  @override
  void dispose() {
    _queryCtrl.dispose();
    _scrollCtrl.dispose();
    _pulseCtrl.dispose();
    super.dispose();
  }

  Future<void> _askQuestion() async {
    final q = _queryCtrl.text.trim();
    if (q.isEmpty) return;
    HapticFeedback.mediumImpact();
    setState(() { _isQuerying = true; _answer = null; });
    try {
      final answer = await ref.read(ragProvider.notifier).query(q);
      setState(() { _answer = answer; _isQuerying = false; });
      // Scroll to answer
      await Future.delayed(const Duration(milliseconds: 100));
      if (_scrollCtrl.hasClients) {
        _scrollCtrl.animateTo(
          _scrollCtrl.position.maxScrollExtent,
          duration: const Duration(milliseconds: 400),
          curve: Curves.easeOut,
        );
      }
    } catch (e) {
      setState(() { _answer = '⚠️ Error: $e'; _isQuerying = false; });
    }
  }

  @override
  Widget build(BuildContext context) {
    final ragAsync = ref.watch(ragProvider);

    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    return Scaffold(
      backgroundColor: cs.surface,
      body: Stack(children: [
        // Ambient glows
        Positioned(top: -100, right: -80,
          child: _GlowOrb(color: cs.primary, size: 300, opacity: 0.15)),
        Positioned(bottom: 100, left: -60,
          child: _GlowOrb(color: cs.tertiary, size: 220, opacity: 0.1)),

        SafeArea(child: Column(children: [
          // ── Header ──────────────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(18, 14, 18, 0),
            child: Row(children: [
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('Second Brain', style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800)),
                ragAsync.when(
                  loading: () => Text('Initialising…', style: TextStyle(color: cs.onSurface.withOpacity(0.6), fontSize: 11)),
                  error: (_, __) => const SizedBox(),
                  data: (s) => Text('${s.docs.length} docs · ${s.totalChunks} chunks indexed',
                    style: TextStyle(color: cs.onSurface.withOpacity(0.6), fontSize: 11)),
                ),
              ])),
              // Docs toggle
              GestureDetector(
                onTap: () => setState(() => _showDocs = !_showDocs),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                  decoration: BoxDecoration(
                    color: _showDocs ? cs.primary.withOpacity(0.1) : cs.surfaceContainerHighest.withOpacity(0.5),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: _showDocs ? cs.primary.withOpacity(0.3) : cs.onSurface.withOpacity(0.1)),
                  ),
                  child: Icon(Icons.auto_stories_outlined,
                    size: 18, color: _showDocs ? cs.primary : cs.onSurface.withOpacity(0.6)),
                ),
              ),
            ]),
          ),

          const SizedBox(height: 14),

          // ── Online indicator + RAG description ──────────────────────────
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 18),
            child: AppCard(
              glass: true,
              padding: const EdgeInsets.all(14),
              color: cs.primaryContainer.withOpacity(0.2),
              child: Row(children: [
                ScaleTransition(
                  scale: _pulse,
                  child: Container(
                    width: 8, height: 8,
                    decoration: const BoxDecoration(
                      color: Colors.green,
                      shape: BoxShape.circle,
                      boxShadow: [BoxShadow(color: Colors.green, blurRadius: 6)],
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(child: Text(
                  'Local-first RAG — Index once, query forever offline. Embeddings stay on your device.',
                  style: theme.textTheme.bodySmall?.copyWith(color: cs.onSurface.withOpacity(0.7), height: 1.4),
                )),
              ]),
            ),
          ),

          const SizedBox(height: 14),

          // ── Indexing progress bar ────────────────────────────────────────
          ragAsync.when(
            loading: () => LinearProgressIndicator(color: cs.primary, backgroundColor: cs.surfaceContainerHighest),
            error: (e, _) => Padding(
              padding: const EdgeInsets.symmetric(horizontal: 18),
              child: Text('Error: $e', style: TextStyle(color: cs.error, fontSize: 12)),
            ),
            data: (s) => s.isIndexing
                ? Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 18),
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(s.indexingStatus ?? '', style: TextStyle(color: cs.onSurface.withOpacity(0.6), fontSize: 11)),
                      const SizedBox(height: 6),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(4),
                        child: LinearProgressIndicator(
                          value: s.indexProgress,
                          color: cs.primary,
                          backgroundColor: cs.surfaceContainerHighest,
                          minHeight: 4,
                        ),
                      ),
                    ]),
                  )
                : s.indexingStatus != null
                    ? Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 18),
                        child: Text(s.indexingStatus!, style: TextStyle(color: cs.onSurface.withOpacity(0.6), fontSize: 11)),
                      )
                    : const SizedBox(),
          ),

          // ── Documents list (collapsible) ─────────────────────────────────
          if (_showDocs)
            ragAsync.maybeWhen(
              data: (s) => s.docs.isEmpty
                  ? Padding(
                      padding: const EdgeInsets.all(18),
                      child: _EmptyState(onUpload: () => ref.read(ragProvider.notifier).pickAndIndex()),
                    )
                  : SizedBox(
                      height: 160,
                      child: ListView.builder(
                        scrollDirection: Axis.horizontal,
                        padding: const EdgeInsets.symmetric(horizontal: 18),
                        itemCount: s.docs.length + 1,
                        itemBuilder: (ctx, i) {
                          if (i == s.docs.length) {
                            return _AddDocCard(onTap: () => ref.read(ragProvider.notifier).pickAndIndex());
                          }
                          final doc = s.docs[i];
                          return _DocCard(
                            doc: doc,
                            onDelete: () => ref.read(ragProvider.notifier).deleteDoc(doc.docId),
                          );
                        },
                      ),
                    ),
              orElse: () => const SizedBox(),
            ),

          // ── Main chat area ───────────────────────────────────────────────
          Expanded(
            child: ragAsync.maybeWhen(
              data: (s) => s.docs.isEmpty && !_showDocs
                  ? _EmptyState(onUpload: () => ref.read(ragProvider.notifier).pickAndIndex())
                  : _AnswerArea(
                      answer: _answer,
                      isQuerying: _isQuerying,
                      scrollCtrl: _scrollCtrl,
                      query: _queryCtrl.text,
                    ),
              orElse: () => Center(child: CircularProgressIndicator(color: cs.primary)),
            ),
          ),

          // ── Query input ──────────────────────────────────────────────────
          _QueryBar(
            ctrl: _queryCtrl,
            isQuerying: _isQuerying,
            onSend: _askQuestion,
            onUpload: () => ref.read(ragProvider.notifier).pickAndIndex(),
          ),
        ])),
      ]),
    );
  }
}

// ── Answer display area ───────────────────────────────────────────────────────
class _AnswerArea extends StatelessWidget {
  final String? answer;
  final bool isQuerying;
  final ScrollController scrollCtrl;
  final String query;
  const _AnswerArea({required this.answer, required this.isQuerying, required this.scrollCtrl, required this.query});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
  
    if (answer == null && !isQuerying) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Icon(Icons.psychology_outlined, size: 56, color: cs.primary),
            const SizedBox(height: 14),
            Text('Ask anything about your notes', textAlign: TextAlign.center,
              style: TextStyle(color: cs.onSurface.withOpacity(0.7), fontSize: 14, height: 1.5)),
            const SizedBox(height: 8),
            Text('"Explain Dijkstra\'s algorithm"\n"What is the formula for…"\n"Summarise chapter 3"',
              textAlign: TextAlign.center,
              style: TextStyle(color: cs.onSurface.withOpacity(0.5), fontSize: 12, height: 1.6, fontStyle: FontStyle.italic)),
          ]),
        ),
      );
    }

    return ListView(
      controller: scrollCtrl,
      padding: const EdgeInsets.fromLTRB(18, 8, 18, 8),
      children: [
        if (query.isNotEmpty) ...[
          // User question bubble
          Align(
            alignment: Alignment.centerRight,
            child: Container(
              constraints: const BoxConstraints(maxWidth: 280),
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF6366F1), Color(0xFF8B5CF6)],
                  begin: Alignment.topLeft, end: Alignment.bottomRight,
                ),
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(18), topRight: Radius.circular(18),
                  bottomLeft: Radius.circular(18), bottomRight: Radius.circular(4),
                ),
              ),
              child: Text(query,
                style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w500)),
            ),
          ),
        ],
        if (isQuerying)
          AppCard(
            margin: const EdgeInsets.only(bottom: 12),
            padding: const EdgeInsets.all(16),
            glass: true,
            child: Row(children: [
              SizedBox(width: 16, height: 16,
                child: CircularProgressIndicator(strokeWidth: 2, color: cs.primary)),
              const SizedBox(width: 12),
              Text('Searching your notes…', style: TextStyle(color: cs.onSurface.withOpacity(0.7), fontSize: 13)),
            ]),
          )
        else if (answer != null)
          AppCard(
            margin: const EdgeInsets.only(bottom: 12),
            padding: const EdgeInsets.all(16),
            color: cs.surfaceContainerHighest.withOpacity(0.3),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Container(
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: cs.primary.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Icon(Icons.auto_awesome, size: 12, color: cs.primary),
                ),
                const SizedBox(width: 8),
                Text('Lumina AI', style: TextStyle(
                  color: cs.primary, fontSize: 11, fontWeight: FontWeight.w700, letterSpacing: 0.4)),
              ]),
              const SizedBox(height: 10),
              MarkdownBody(
                data: answer!,
                selectable: true,
                styleSheet: MarkdownStyleSheet(
                  p: theme.textTheme.bodyMedium?.copyWith(height: 1.6),
                  code: TextStyle(fontFamily: 'monospace', backgroundColor: cs.onSurface.withOpacity(0.1), color: cs.onSurface),
                  codeblockDecoration: BoxDecoration(
                    color: cs.onSurface.withOpacity(0.05),
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              ),
            ]),
          ),
      ],
    );
  }
}

// ── Query bar ─────────────────────────────────────────────────────────────────
class _QueryBar extends StatelessWidget {
  final TextEditingController ctrl;
  final bool isQuerying;
  final VoidCallback onSend;
  final VoidCallback onUpload;
  const _QueryBar({required this.ctrl, required this.isQuerying, required this.onSend, required this.onUpload});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      padding: EdgeInsets.fromLTRB(14, 10, 14, MediaQuery.of(context).padding.bottom + 12),
      decoration: BoxDecoration(
        border: Border(top: BorderSide(color: cs.onSurface.withOpacity(0.1))),
        color: cs.surface,
      ),
      child: Row(children: [
        // Upload button
        GestureDetector(
          onTap: onUpload,
          child: Container(
            width: 44, height: 44,
            decoration: BoxDecoration(
              color: cs.surfaceContainerHighest.withOpacity(0.5),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: cs.onSurface.withOpacity(0.1)),
            ),
            child: Icon(Icons.upload_file_outlined, size: 20, color: cs.onSurface.withOpacity(0.7)),
          ),
        ),
        const SizedBox(width: 10),
        // Text field
        Expanded(
          child: Container(
            decoration: BoxDecoration(
              color: cs.surfaceContainerHighest.withOpacity(0.5),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: cs.onSurface.withOpacity(0.1)),
            ),
            child: TextField(
              controller: ctrl,
              style: TextStyle(color: cs.onSurface, fontSize: 14),
              decoration: InputDecoration(
                hintText: 'Ask about your notes or PDFs…',
                hintStyle: TextStyle(color: cs.onSurface.withOpacity(0.5), fontSize: 13),
                border: InputBorder.none,
                contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              ),
              onSubmitted: (_) => onSend(),
              textInputAction: TextInputAction.send,
            ),
          ),
        ),
        const SizedBox(width: 10),
        // Send button
        GestureDetector(
          onTap: isQuerying ? null : onSend,
          child: Container(
            width: 44, height: 44,
            decoration: BoxDecoration(
              gradient: isQuerying ? null : LinearGradient(
                colors: [cs.primary, cs.tertiary],
                begin: Alignment.topLeft, end: Alignment.bottomRight,
              ),
              color: isQuerying ? cs.surfaceContainerHighest : null,
              borderRadius: BorderRadius.circular(12),
            ),
            child: isQuerying
                ? Center(child: SizedBox(width: 18, height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2, color: cs.primary)))
                : const Icon(Icons.send_rounded, size: 18, color: Colors.white),
          ),
        ),
      ]),
    );
  }
}

// ── Document card ─────────────────────────────────────────────────────────────
class _DocCard extends StatelessWidget {
  final ({String docId, String docTitle, String docType, int chunks, DateTime addedAt}) doc;
  final VoidCallback onDelete;
  const _DocCard({required this.doc, required this.onDelete});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isPdf = doc.docType.toLowerCase() == 'pdf';
    return AppCard(
      width: 150,
      margin: const EdgeInsets.only(right: 10, bottom: 4, top: 4),
      padding: const EdgeInsets.all(14),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          Icon(isPdf ? Icons.picture_as_pdf_outlined : Icons.description_outlined,
            size: 22, color: isPdf ? Colors.red : Colors.cyan),
          GestureDetector(
            onTap: onDelete,
            child: Icon(Icons.delete_outline, size: 16, color: cs.onSurface.withOpacity(0.5)),
          ),
        ]),
        const SizedBox(height: 8),
        Text(doc.docTitle,
          style: TextStyle(color: cs.onSurface, fontSize: 12, fontWeight: FontWeight.w600),
          maxLines: 2, overflow: TextOverflow.ellipsis),
        const Spacer(),
        Text('${doc.chunks} chunks',
          style: TextStyle(color: cs.onSurface.withOpacity(0.5), fontSize: 10)),
      ]),
    );
  }
}

class _AddDocCard extends StatelessWidget {
  final VoidCallback onTap;
  const _AddDocCard({required this.onTap});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 110,
        margin: const EdgeInsets.only(right: 10, bottom: 4, top: 4),
        decoration: BoxDecoration(
          border: Border.all(color: cs.primary.withOpacity(0.3), style: BorderStyle.solid),
          borderRadius: BorderRadius.circular(14),
          color: cs.primary.withOpacity(0.1),
        ),
        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          Icon(Icons.add_rounded, color: cs.primary, size: 28),
          const SizedBox(height: 6),
          Text('Add PDF\nor Note', textAlign: TextAlign.center,
            style: TextStyle(color: cs.primary, fontSize: 11, fontWeight: FontWeight.w600)),
        ]),
      ),
    );
  }
}

// ── Empty state ───────────────────────────────────────────────────────────────
class _EmptyState extends StatelessWidget {
  final VoidCallback onUpload;
  const _EmptyState({required this.onUpload});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              shape: BoxShape.circle, color: cs.primary.withOpacity(0.1)),
            child: Icon(Icons.auto_stories_outlined, size: 44, color: cs.primary),
          ),
          const SizedBox(height: 20),
          Text('No Documents Yet', style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800)),
          const SizedBox(height: 8),
          Text(
            'Upload your textbook PDFs and notes. '
            'Lumina will index them locally so you can ask questions '
            'even without internet.',
            textAlign: TextAlign.center,
            style: TextStyle(color: cs.onSurface.withOpacity(0.7), fontSize: 13, height: 1.5)),
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            child: AppButton(
              text: 'Upload PDF or Notes',
              icon: Icons.upload_file_outlined,
              onPressed: onUpload,
            ),
          ),
        ]),
      ),
    );
  }
}

// ── Ambient glow orb ──────────────────────────────────────────────────────────
class _GlowOrb extends StatelessWidget {
  final Color color;
  final double size, opacity;
  const _GlowOrb({required this.color, required this.size, required this.opacity});

  @override
  Widget build(BuildContext context) => Container(
    width: size, height: size,
    decoration: BoxDecoration(
      shape: BoxShape.circle,
      gradient: RadialGradient(colors: [color.withOpacity(opacity), Colors.transparent]),
    ),
  );
}
