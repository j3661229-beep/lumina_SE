import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../core/theme/design_tokens.dart';
import 'rag_provider.dart';

// ── Persistent chat message model ────────────────────────────────────────────
class _ChatMessage {
  final String text;
  final bool isUser;
  final bool isError;
  final DateTime timestamp;

  const _ChatMessage({
    required this.text,
    required this.isUser,
    this.isError = false,
    required this.timestamp,
  });

  Map<String, dynamic> toJson() => {
    'text': text,
    'isUser': isUser,
    'isError': isError,
    'ts': timestamp.millisecondsSinceEpoch,
  };

  factory _ChatMessage.fromJson(Map<String, dynamic> j) => _ChatMessage(
    text: j['text'] as String,
    isUser: j['isUser'] as bool,
    isError: (j['isError'] as bool?) ?? false,
    timestamp: DateTime.fromMillisecondsSinceEpoch(j['ts'] as int),
  );
}

const _kChatKey = 'rag_chat_v3'; // bumped: clears old *(Offline Mode)* cached messages
const _kMaxSaved = 100;

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

  final List<_ChatMessage> _messages = [];
  bool _isQuerying = false;
  bool _showDocs = false;
  bool _chatLoaded = false;

  @override
  void initState() {
    super.initState();
    _pulseCtrl = AnimationController(vsync: this, duration: const Duration(seconds: 2))
      ..repeat(reverse: true);
    _pulse = Tween<double>(begin: 0.6, end: 1.0)
        .animate(CurvedAnimation(parent: _pulseCtrl, curve: Curves.easeInOut));
    _loadChatHistory();
  }

  @override
  void dispose() {
    _queryCtrl.dispose();
    _scrollCtrl.dispose();
    _pulseCtrl.dispose();
    super.dispose();
  }

  // ── Local persistence ─────────────────────────────────────────────────────
  Future<void> _loadChatHistory() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_kChatKey);
    if (raw != null) {
      try {
        final list = (jsonDecode(raw) as List)
            .map((e) => _ChatMessage.fromJson(e as Map<String, dynamic>))
            .toList();
        if (mounted) {
          setState(() {
            _messages.addAll(list);
            _chatLoaded = true;
          });
          WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToBottom());
        }
      } catch (_) {
        // Corrupt or incompatible cache — wipe it
        await prefs.remove(_kChatKey);
        if (mounted) setState(() => _chatLoaded = true);
      }
    } else {
      if (mounted) setState(() => _chatLoaded = true);
    }
  }

  Future<void> _saveChatHistory() async {
    final prefs = await SharedPreferences.getInstance();
    // Only keep last _kMaxSaved messages
    final toSave = _messages.length > _kMaxSaved
        ? _messages.sublist(_messages.length - _kMaxSaved)
        : _messages;
    await prefs.setString(_kChatKey, jsonEncode(toSave.map((m) => m.toJson()).toList()));
  }

  Future<void> _clearChat() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_kChatKey);
    setState(() => _messages.clear());
  }

  Future<void> _ask() async {
    final q = _queryCtrl.text.trim();
    if (q.isEmpty || _isQuerying) return;
    HapticFeedback.mediumImpact();
    _queryCtrl.clear();
    setState(() {
      _messages.add(_ChatMessage(text: q, isUser: true, timestamp: DateTime.now()));
      _isQuerying = true;
    });
    _scrollToBottom();
    try {
      final answer = await ref.read(ragProvider.notifier).query(q);
      debugPrint('[RAG Screen] Answer: $answer');
      setState(() {
        _messages.add(_ChatMessage(text: answer, isUser: false, timestamp: DateTime.now()));
        _isQuerying = false;
      });
    } catch (e) {
      debugPrint('[RAG Screen] Query error: $e');
      setState(() {
        _messages.add(_ChatMessage(
          text: '⚠️ Error: $e', isUser: false, isError: true, timestamp: DateTime.now()));
        _isQuerying = false;
      });
    }
    _scrollToBottom();
    _saveChatHistory();
  }

  void _scrollToBottom() {
    Future.delayed(const Duration(milliseconds: 150), () {
      if (_scrollCtrl.hasClients) {
        _scrollCtrl.animateTo(_scrollCtrl.position.maxScrollExtent,
            duration: const Duration(milliseconds: 400), curve: Curves.easeOut);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isDark = context.isDark;
    final ragAsync = ref.watch(ragProvider);

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: Column(children: [
        // ── Premium header ─────────────────────────────────────────────────
        Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: isDark
                  ? [const Color(0xFF1E1B4B), AppColors.darkBg]
                  : [const Color(0xFF4F46E5), const Color(0xFF6D28D9)],
              begin: Alignment.topLeft, end: Alignment.bottomRight,
            ),
          ),
          child: SafeArea(
            bottom: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
              child: Row(children: [
                // AI avatar orb
                Container(
                  width: 44, height: 44,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [AppColors.indigo, AppColors.violet],
                      begin: Alignment.topLeft, end: Alignment.bottomRight),
                    borderRadius: BorderRadius.circular(14),
                    boxShadow: const [BoxShadow(
                      color: Color(0x556366F1), blurRadius: 16, offset: Offset(0, 4))],
                  ),
                  child: const Icon(Icons.auto_awesome_rounded, color: Colors.white, size: 20),
                ),
                const SizedBox(width: 12),
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  const Text('Second Brain', style: TextStyle(
                    fontFamily: 'Syne', fontSize: 18, fontWeight: FontWeight.w800,
                    color: Colors.white)),
                  ragAsync.when(
                    loading: () => Text('Loading…', style: TextStyle(
                      color: Colors.white.withOpacity(0.5), fontSize: 11)),
                    error: (_, __) => const SizedBox(),
                    data: (s) => Row(children: [
                      ScaleTransition(
                        scale: _pulse,
                        child: Container(
                          width: 6, height: 6,
                          decoration: BoxDecoration(
                            color: s.isIndexing ? AppColors.amber : AppColors.green,
                            shape: BoxShape.circle,
                            boxShadow: [BoxShadow(
                              color: (s.isIndexing ? AppColors.amber : AppColors.green).withOpacity(0.6),
                              blurRadius: 6)]),
                        ),
                      ),
                      const SizedBox(width: 6),
                      Flexible(child: Text(
                        s.isIndexing
                            ? s.indexingStatus ?? 'Indexing…'
                            : 'Offline AI · ${s.docs.length} docs · ${s.totalChunks} chunks',
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.65),
                          fontSize: 11,
                          fontWeight: s.isIndexing ? FontWeight.w700 : FontWeight.w500,
                        ),
                      )),
                    ]),
                  ),
                ])),
                // Docs toggle
                _NavBtn(
                  icon: _showDocs ? Icons.auto_stories_rounded : Icons.auto_stories_outlined,
                  active: _showDocs,
                  onTap: () => setState(() => _showDocs = !_showDocs),
                ),
                const SizedBox(width: 8),
                if (_messages.isNotEmpty)
                  _NavBtn(
                    icon: Icons.cleaning_services_outlined,
                    active: false,
                    onTap: () => showDialog(
                      context: context,
                      builder: (ctx) => AlertDialog(
                        backgroundColor: cs.surface,
                        title: const Text('Clear chat history?', style: TextStyle(fontFamily: 'Syne', fontWeight: FontWeight.w700, fontSize: 16)),
                        content: const Text('This will delete all saved messages permanently.'),
                        actions: [
                          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
                          TextButton(
                            onPressed: () { Navigator.pop(ctx); _clearChat(); },
                            child: const Text('Clear', style: TextStyle(color: AppColors.rose)),
                          ),
                        ],
                      ),
                    ),
                  ),
              ]),
            ),
          ),
        ),

        // ── Indexing overlay (shown even when docs list is empty) ───────────
        ragAsync.maybeWhen(
          data: (s) => s.isIndexing
              ? _IndexingProgressBar(
                  status: s.indexingStatus ?? 'Indexing…',
                  progress: s.indexProgress,
                )
              : const SizedBox(),
          orElse: () => const SizedBox(),
        ),

        // ── Documents shelf ─────────────────────────────────────────────────
        if (_showDocs)
          ragAsync.maybeWhen(
            data: (s) => s.docs.isEmpty && !s.isIndexing
                ? _EmptyDocsBar(onUpload: () => ref.read(ragProvider.notifier).pickAndIndex())
                : s.docs.isEmpty
                    ? const SizedBox() // indexing in progress, progress bar already shown above
                    : _DocsShelf(
                        docs: s.docs,
                        onDelete: (id) => ref.read(ragProvider.notifier).deleteDoc(id),
                        onAdd: () => ref.read(ragProvider.notifier).pickAndIndex(),
                      ),
            orElse: () => const SizedBox(),
          ),

        // ── Divider ─────────────────────────────────────────────────────────
        Container(height: 0.5, color: AppColors.border(context)),

        // ── Chat area ──────────────────────────────────────────────────────
        Expanded(
          child: !_chatLoaded
              ? const Center(child: CircularProgressIndicator(color: AppColors.indigo))
              : ragAsync.maybeWhen(
                  data: (s) => s.docs.isEmpty && _messages.isEmpty
                      ? _EmptyState(onUpload: () => ref.read(ragProvider.notifier).pickAndIndex())
                      : _ChatArea(
                          messages: _messages,
                          isQuerying: _isQuerying,
                          scrollCtrl: _scrollCtrl,
                        ),
                  orElse: () => const Center(child: CircularProgressIndicator(color: AppColors.indigo)),
                ),
        ),

        // ── Suggestions ─────────────────────────────────────────────────────
        if (_messages.isEmpty && _chatLoaded)
          _Suggestions(onTap: (s) {
            _queryCtrl.text = s;
            _ask();
          }),

        // ── Input bar ──────────────────────────────────────────────────────
        _InputBar(
          ctrl: _queryCtrl,
          isQuerying: _isQuerying,
          onSend: _ask,
          onUpload: () => ref.read(ragProvider.notifier).pickAndIndex(),
        ),
      ]),
    );
  }
}

// ── Indexing progress bar (always visible during upload) ──────────────────────
class _IndexingProgressBar extends StatelessWidget {
  final String status;
  final double progress;
  const _IndexingProgressBar({required this.status, required this.progress});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 8, 16, 4),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.indigo.withOpacity(0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.indigo.withOpacity(0.2)),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          SizedBox(
            width: 14, height: 14,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              color: AppColors.indigo,
              value: progress > 0 ? progress : null,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              status,
              style: const TextStyle(
                color: AppColors.indigo, fontSize: 12, fontWeight: FontWeight.w600),
            ),
          ),
          if (progress > 0)
            Text('${(progress * 100).round()}%',
              style: const TextStyle(color: AppColors.indigo, fontSize: 12, fontWeight: FontWeight.w800)),
        ]),
        if (progress > 0) ...[
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: progress,
              color: AppColors.indigo,
              backgroundColor: AppColors.indigo.withOpacity(0.1),
              minHeight: 4,
            ),
          ),
        ],
      ]),
    );
  }
}

// ── Chat message model ────────────────────────────────────────────────────────
// (defined at top of file)

// ── Chat area ─────────────────────────────────────────────────────────────────
class _ChatArea extends StatelessWidget {
  final List<_ChatMessage> messages;
  final bool isQuerying;
  final ScrollController scrollCtrl;
  const _ChatArea({required this.messages, required this.isQuerying, required this.scrollCtrl});

  @override
  Widget build(BuildContext context) {
    final isDark = context.isDark;
    return ListView.builder(
      controller: scrollCtrl,
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
      itemCount: messages.length + (isQuerying ? 1 : 0),
      itemBuilder: (ctx, i) {
        if (i == messages.length && isQuerying) {
          return _ThinkingBubble();
        }
        final msg = messages[i];
        if (msg.isUser) {
          return Align(
            alignment: Alignment.centerRight,
            child: Container(
              constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.75),
              margin: const EdgeInsets.only(bottom: 12, left: 40),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [AppColors.indigo, AppColors.violet],
                  begin: Alignment.topLeft, end: Alignment.bottomRight,
                ),
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(18), topRight: Radius.circular(18),
                  bottomLeft: Radius.circular(18), bottomRight: Radius.circular(4),
                ),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.indigo.withOpacity(isDark ? 0.3 : 0.15),
                    blurRadius: 12, offset: const Offset(0, 4)
                  )
                ],
              ),
              child: Text(msg.text, style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w500)),
            ),
          );
        }
        return Align(
          alignment: Alignment.centerLeft,
          child: Container(
            constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.85),
            margin: const EdgeInsets.only(bottom: 12, right: 40),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: msg.isError
                  ? AppColors.rose.withOpacity(0.1)
                  : AppColors.surfaceContainer(context),
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(18), topRight: Radius.circular(18),
                bottomLeft: Radius.circular(4), bottomRight: Radius.circular(18),
              ),
              border: Border.all(
                color: msg.isError ? AppColors.rose.withOpacity(0.5) : AppColors.border(context),
              ),
            ),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              if (!msg.isError)
                Row(children: [
                  Container(
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(colors: [AppColors.indigo, AppColors.violet]),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: const Icon(Icons.auto_awesome, size: 11, color: Colors.white),
                  ),
                  const SizedBox(width: 7),
                  Text('Lumina AI', style: const TextStyle(
                    color: AppColors.indigo, fontSize: 10, fontWeight: FontWeight.w700, letterSpacing: 0.5)),
                  const Spacer(),
                  Text(
                    _fmtTime(msg.timestamp),
                    style: TextStyle(fontSize: 9, color: Theme.of(context).colorScheme.onSurface.withOpacity(0.35)),
                  ),
                ]),
              if (!msg.isError) const SizedBox(height: 10),
              SelectableText(msg.text, style: TextStyle(
                color: Theme.of(context).colorScheme.onSurface, fontSize: 14, height: 1.65)),
            ]),
          ),
        );
      },
    );
  }

  static String _fmtTime(DateTime dt) {
    final h = dt.hour.toString().padLeft(2, '0');
    final m = dt.minute.toString().padLeft(2, '0');
    return '$h:$m';
  }
}

// ── Typing indicator ──────────────────────────────────────────────────────────
class _ThinkingBubble extends StatefulWidget {
  @override
  State<_ThinkingBubble> createState() => _ThinkingBubbleState();
}

class _ThinkingBubbleState extends State<_ThinkingBubble> with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _anim;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 900))..repeat(reverse: true);
    _anim = Tween<double>(begin: 0.3, end: 1.0).animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut));
  }

  @override
  void dispose() { _ctrl.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
        decoration: BoxDecoration(
          color: AppColors.cardBg(context),
          borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(4), topRight: Radius.circular(18),
            bottomLeft: Radius.circular(18), bottomRight: Radius.circular(18),
          ),
          border: Border.all(color: AppColors.border(context)),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: List.generate(3, (i) =>
          AnimatedBuilder(
            animation: _anim,
            builder: (_, __) => Container(
              margin: const EdgeInsets.only(right: 4),
              width: 7, height: 7,
              decoration: BoxDecoration(
                color: AppColors.indigo.withOpacity(
                  ((_anim.value + (i * 0.33)) % 1.0).clamp(0.2, 1.0)),
                shape: BoxShape.circle,
              ),
            ),
          ),
        )),
      ),
    );
  }
}

// ── Suggestion chips ──────────────────────────────────────────────────────────
class _Suggestions extends StatelessWidget {
  final ValueChanged<String> onTap;
  const _Suggestions({required this.onTap});

  static const _items = [
    (icon: '🎯', text: 'Explain Dijkstra\'s algorithm'),
    (icon: '📖', text: 'Summarise chapter 3'),
    (icon: '📐', text: 'Key formulas for exam'),
    (icon: '🧠', text: 'What is this topic about?'),
  ];

  @override
  Widget build(BuildContext context) {
    final isDark = context.isDark;
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 6),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 8),
          child: Text('Try asking…',
            style: TextStyle(
              color: Theme.of(context).colorScheme.onSurface.withOpacity(0.45),
              fontSize: 11, fontWeight: FontWeight.w600)),
        ),
        Wrap(spacing: 8, runSpacing: 8, children: _items.map((item) =>
          GestureDetector(
            onTap: () => onTap(item.text),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 150),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: isDark
                    ? AppColors.indigo.withOpacity(0.1)
                    : AppColors.indigo.withOpacity(0.06),
                borderRadius: BorderRadius.circular(22),
                border: Border.all(
                  color: AppColors.indigo.withOpacity(isDark ? 0.3 : 0.2)),
              ),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                Text(item.icon, style: const TextStyle(fontSize: 13)),
                const SizedBox(width: 6),
                Text(item.text,
                  style: const TextStyle(
                    color: AppColors.indigo, fontSize: 12, fontWeight: FontWeight.w600)),
              ]),
            ),
          ),
        ).toList()),
      ]),
    );
  }
}

// ── Input bar ─────────────────────────────────────────────────────────────────
class _InputBar extends StatelessWidget {
  final TextEditingController ctrl;
  final bool isQuerying;
  final VoidCallback onSend, onUpload;
  const _InputBar({required this.ctrl, required this.isQuerying, required this.onSend, required this.onUpload});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isDark = context.isDark;
    return Container(
      padding: EdgeInsets.fromLTRB(12, 10, 12, MediaQuery.of(context).padding.bottom + 12),
      decoration: BoxDecoration(
        color: AppColors.surface(context),
        border: Border(top: BorderSide(color: cs.onSurface.withOpacity(0.08))),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(isDark ? 0.2 : 0.04), blurRadius: 20, offset: const Offset(0, -4))],
      ),
      child: Row(children: [
        // Upload
        _BarBtn(icon: Icons.upload_file_outlined, onTap: onUpload,
          color: cs.onSurface.withOpacity(0.5)),
        const SizedBox(width: 10),
        // Input
        Expanded(child: Container(
          decoration: BoxDecoration(
            color: cs.onSurface.withOpacity(0.05),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: cs.onSurface.withOpacity(0.1)),
          ),
          child: TextField(
            controller: ctrl,
            style: TextStyle(color: cs.onSurface, fontSize: 14),
            decoration: InputDecoration(
              hintText: 'Ask anything about your notes…',
              hintStyle: TextStyle(color: cs.onSurface.withOpacity(0.35), fontSize: 13),
              border: InputBorder.none, enabledBorder: InputBorder.none,
              focusedBorder: InputBorder.none, filled: false,
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            ),
            onSubmitted: (_) => onSend(),
            textInputAction: TextInputAction.send,
            maxLines: null,
          ),
        )),
        const SizedBox(width: 10),
        // Send
        GestureDetector(
          onTap: isQuerying ? null : onSend,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            width: 44, height: 44,
            decoration: BoxDecoration(
              gradient: isQuerying
                  ? null
                  : const LinearGradient(colors: [AppColors.indigo, AppColors.violet]),
              color: isQuerying ? cs.onSurface.withOpacity(0.1) : null,
              borderRadius: BorderRadius.circular(22),
            ),
            child: Icon(
              isQuerying ? Icons.hourglass_empty_rounded : Icons.send_rounded,
              color: isQuerying ? cs.onSurface.withOpacity(0.3) : Colors.white,
              size: 18,
            ),
          ),
        ),
      ]),
    );
  }
}

class _BarBtn extends StatelessWidget {
  final IconData icon;
  final Color color;
  final VoidCallback onTap;
  const _BarBtn({required this.icon, required this.color, required this.onTap});

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: Container(
      width: 44, height: 44,
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.onSurface.withOpacity(0.06),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: Theme.of(context).colorScheme.onSurface.withOpacity(0.1)),
      ),
      child: Icon(icon, color: color, size: 20),
    ),
  );
}

class _NavBtn extends StatelessWidget {
  final IconData icon;
  final bool active;
  final VoidCallback onTap;
  const _NavBtn({required this.icon, required this.active, required this.onTap});

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: Container(
      width: 38, height: 38,
      decoration: BoxDecoration(
        color: active ? AppColors.indigo.withOpacity(0.15) : Theme.of(context).colorScheme.onSurface.withOpacity(0.07),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: active ? AppColors.indigo.withOpacity(0.4) : Colors.transparent),
      ),
      child: Icon(icon, size: 18, color: active ? AppColors.indigo : Theme.of(context).colorScheme.onSurface.withOpacity(0.5)),
    ),
  );
}

// ── Docs shelf ────────────────────────────────────────────────────────────────
class _DocsShelf extends StatelessWidget {
  final List docs;
  final ValueChanged<String> onDelete;
  final VoidCallback onAdd;
  const _DocsShelf({required this.docs, required this.onDelete, required this.onAdd});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 130,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        children: [
          ...docs.map((doc) => _DocCard(doc: doc, onDelete: () => onDelete(doc.docId))),
          _AddCard(onTap: onAdd),
        ],
      ),
    );
  }
}

class _DocCard extends StatelessWidget {
  final dynamic doc;
  final VoidCallback onDelete;
  const _DocCard({required this.doc, required this.onDelete});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isDark = context.isDark;
    final isPdf = (doc.docType as String).toLowerCase() == 'pdf';
    final color = isPdf ? AppColors.rose : AppColors.cyan;
    return Container(
      width: 140,
      margin: const EdgeInsets.only(right: 10, top: 8, bottom: 8),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.cardBg(context),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border(context)),
        boxShadow: isDark ? [] : [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 8)],
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          Container(padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(color: color.withOpacity(0.12), borderRadius: BorderRadius.circular(8)),
            child: Icon(isPdf ? Icons.picture_as_pdf_rounded : Icons.description_rounded, size: 16, color: color)),
          GestureDetector(
            onTap: onDelete,
            child: Icon(Icons.close_rounded, size: 14, color: cs.onSurface.withOpacity(0.35))),
        ]),
        const SizedBox(height: 8),
        Text(doc.docTitle as String, style: TextStyle(
          color: cs.onSurface, fontSize: 12, fontWeight: FontWeight.w600),
          maxLines: 2, overflow: TextOverflow.ellipsis),
        const Spacer(),
        Text('${doc.chunks} chunks', style: TextStyle(
          color: cs.onSurface.withOpacity(0.5), fontSize: 10, fontWeight: FontWeight.w600)),
      ]),
    );
  }
}

class _AddCard extends StatelessWidget {
  final VoidCallback onTap;
  const _AddCard({required this.onTap});

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: Container(
      width: 110, margin: const EdgeInsets.only(right: 10, top: 8, bottom: 8),
      decoration: BoxDecoration(
        color: AppColors.indigo.withOpacity(0.08),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.indigo.withOpacity(0.25), style: BorderStyle.solid),
      ),
      child: const Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        Icon(Icons.add_circle_outline_rounded, color: AppColors.indigo, size: 28),
        SizedBox(height: 6),
        Text('Add PDF\nor Note', textAlign: TextAlign.center,
          style: TextStyle(color: AppColors.indigo, fontSize: 11, fontWeight: FontWeight.w600)),
      ]),
    ),
  );
}

class _EmptyDocsBar extends StatelessWidget {
  final VoidCallback onUpload;
  const _EmptyDocsBar({required this.onUpload});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 60,
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: GestureDetector(
        onTap: onUpload,
        child: Container(
          decoration: BoxDecoration(
            color: AppColors.indigo.withOpacity(0.08),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: AppColors.indigo.withOpacity(0.25)),
          ),
          child: const Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            Icon(Icons.upload_file_outlined, color: AppColors.indigo, size: 20),
            SizedBox(width: 10),
            Text('Upload your first PDF or note', style: TextStyle(
              color: AppColors.indigo, fontWeight: FontWeight.w600, fontSize: 13)),
          ]),
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  final VoidCallback onUpload;
  const _EmptyState({required this.onUpload});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isDark = context.isDark;
    return Center(child: Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        // Glowing AI brain icon
        Container(
          width: 110, height: 110,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: const LinearGradient(
              colors: [AppColors.indigo, AppColors.violet],
              begin: Alignment.topLeft, end: Alignment.bottomRight),
            boxShadow: [
              BoxShadow(
                color: AppColors.indigo.withOpacity(isDark ? 0.5 : 0.3),
                blurRadius: 40, offset: const Offset(0, 8)),
            ],
          ),
          child: const Icon(Icons.psychology_rounded, size: 52, color: Colors.white),
        ),
        const SizedBox(height: 28),
        Text('Your Second Brain', style: TextStyle(
          fontFamily: 'Syne', fontWeight: FontWeight.w800, fontSize: 24,
          color: cs.onSurface)),
        const SizedBox(height: 10),
        Text(
          'Upload textbook PDFs and notes. Lumina indexes them locally — then you can ask anything, even offline.',
          textAlign: TextAlign.center,
          style: TextStyle(color: cs.onSurface.withOpacity(0.5), fontSize: 13, height: 1.65)),
        const SizedBox(height: 24),
        // Feature pills
        Wrap(spacing: 8, runSpacing: 8, alignment: WrapAlignment.center, children: [
          _FeaturePill('🔒 100% Offline', AppColors.green),
          _FeaturePill('📄 PDF & Notes', AppColors.indigo),
          _FeaturePill('⚡ Instant Search', AppColors.amber),
        ]),
        const SizedBox(height: 28),
        GestureDetector(
          onTap: onUpload,
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 16),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [AppColors.indigo, AppColors.violet],
                begin: Alignment.topLeft, end: Alignment.bottomRight),
              borderRadius: BorderRadius.circular(16),
              boxShadow: const [
                BoxShadow(color: Color(0x556366F1), blurRadius: 20, offset: Offset(0, 6))],
            ),
            child: const Row(mainAxisAlignment: MainAxisAlignment.center, children: [
              Icon(Icons.upload_file_rounded, color: Colors.white, size: 20),
              SizedBox(width: 10),
              Text('Upload PDF or Notes', style: TextStyle(
                color: Colors.white, fontWeight: FontWeight.w700, fontSize: 15,
                fontFamily: 'Syne')),
            ]),
          ),
        ),
      ]),
    ));
  }
}

class _FeaturePill extends StatelessWidget {
  final String label;
  final Color color;
  const _FeaturePill(this.label, this.color);

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
    decoration: BoxDecoration(
      color: color.withOpacity(0.1),
      borderRadius: BorderRadius.circular(20),
      border: Border.all(color: color.withOpacity(0.25)),
    ),
    child: Text(label, style: TextStyle(
      color: color, fontSize: 11, fontWeight: FontWeight.w700)),
  );
}
