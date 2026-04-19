import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../core/network/api_client.dart';
import '../../core/theme/design_tokens.dart';
import '../../shared/widgets/shimmer_widgets.dart';
import 'presence_provider.dart';

class GroupChatScreen extends ConsumerStatefulWidget {
  final String groupId;
  const GroupChatScreen({super.key, required this.groupId});
  @override
  ConsumerState<GroupChatScreen> createState() => _GroupChatScreenState();
}

class _GroupChatScreenState extends ConsumerState<GroupChatScreen> {
  final _controller = TextEditingController();
  final _scroll = ScrollController();
  final _supabase = Supabase.instance.client;
  final List<Map<String, dynamic>> _messages = [];
  RealtimeChannel? _channel;
  bool _loading = true;
  String? _groupName;
  bool _sending = false;
  Map<String, dynamic>? _replyTo;

  String get _myId => _supabase.auth.currentUser?.id ?? '';

  @override
  void initState() {
    super.initState();
    _loadGroupInfo();
    _loadHistory();
    _subscribeRealtime();
    _ensureProfile();
  }

  // Ensure profile exists so joins don't fail
  Future<void> _ensureProfile() async {
    final user = _supabase.auth.currentUser;
    if (user == null) return;
    try {
      await _supabase.from('profiles').upsert({
        'id': user.id,
        'display_name': user.userMetadata?['display_name'] ?? user.email?.split('@')[0] ?? 'User',
      }, onConflict: 'id');
    } catch (_) {}
  }

  Future<void> _loadGroupInfo() async {
    try {
      final g = await _supabase.from('groups').select('name').eq('id', widget.groupId).single();
      setState(() => _groupName = g['name'] as String?);
    } catch (_) {}
  }

  Future<void> _loadHistory() async {
    try {
      final data = await _supabase
          .from('messages')
          .select('id, content, message_type, metadata, is_pinned, created_at, sender_id')
          .eq('group_id', widget.groupId)
          .order('created_at')
          .limit(100);

      // Fetch sender display names separately to avoid FK panic
      final senderIds = (data as List).map((m) => m['sender_id'] as String).toSet().toList();
      final Map<String, String> nameMap = {};
      if (senderIds.isNotEmpty) {
        try {
          final profiles = await _supabase
              .from('profiles')
              .select('id, display_name')
              .inFilter('id', senderIds);
          for (final p in profiles as List) {
            nameMap[p['id'] as String] = p['display_name'] as String? ?? 'User';
          }
        } catch (_) {}
      }

      final msgs = (data).map<Map<String, dynamic>>((m) => {
        ...Map<String, dynamic>.from(m),
        'sender_name': nameMap[m['sender_id']] ?? 'User',
      }).toList();

      setState(() {
        _messages.clear();
        _messages.addAll(msgs);
        _loading = false;
      });
      _scrollToBottom();
    } catch (e) {
      setState(() => _loading = false);
    }
  }

  void _subscribeRealtime() {
    _channel = _supabase
        .channel('chat_${widget.groupId}')
        .onBroadcast(
          event: 'new_message',
          callback: (payload) async {
            final msg = Map<String, dynamic>.from(payload);
            // Ignore if it's from us (we add optimistic locally)
            if (msg['sender_id'] == _myId) return;
            
            // Add or replace
            if (mounted) {
              setState(() {
                final idx = _messages.indexWhere((m) => m['id'] == msg['id']);
                if (idx >= 0) {
                  _messages[idx] = msg;
                } else {
                  _messages.add(msg);
                }
              });
              _scrollToBottom();
            }
          },
        )
        // Also keep POSTGRES changes enabled as a fallback
        .onPostgresChanges(
          event: PostgresChangeEvent.insert,
          schema: 'public',
          table: 'messages',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'group_id',
            value: widget.groupId,
          ),
          callback: (payload) async {
            final msg = Map<String, dynamic>.from(payload.newRecord);
            // Prevent duplication from postgres if already added
            if (_messages.any((m) => m['id'] == msg['id'])) return;

            // Fetch sender name safely
            try {
              final profile = await _supabase
                  .from('profiles')
                  .select('display_name')
                  .eq('id', msg['sender_id'])
                  .maybeSingle();
              msg['sender_name'] = profile?['display_name'] ?? 'User';
            } catch (_) {
              msg['sender_name'] = 'User';
            }
            if (mounted && !_messages.any((m) => m['id'] == msg['id'])) {
              setState(() => _messages.add(msg));
              _scrollToBottom();
            }
          },
        )
        .subscribe();
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scroll.hasClients) {
        _scroll.animateTo(
          _scroll.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  Future<void> _send({String type = 'text', Map<String, dynamic>? metadata}) async {
    final text = _controller.text.trim();
    if (text.isEmpty || _sending) return;
    setState(() => _sending = true);
    _controller.clear();

    final replyTo = _replyTo;
    setState(() => _replyTo = null); // clear immediately

    // ── Optimistic update: show immediately ──
    final myUser = _supabase.auth.currentUser;
    final optimistic = {
      'id': 'optimistic_${DateTime.now().millisecondsSinceEpoch}',
      'content': text,
      'message_type': type,
      'metadata': {
        if (metadata != null) ...metadata,
        if (replyTo != null) 'reply_to': {
          'id': replyTo['id'],
          'content': replyTo['content'],
          'sender_name': replyTo['sender_name'],
        },
      },
      'is_pinned': false,
      'sender_id': _myId,
      'sender_name': myUser?.userMetadata?['display_name'] ?? myUser?.email?.split('@')[0] ?? 'Me',
      'created_at': DateTime.now().toIso8601String(),
      'optimistic': true,
    };
    setState(() => _messages.add(optimistic));
    _scrollToBottom();

    try {
      final result = await _supabase.from('messages').insert({
        'group_id': widget.groupId,
        'sender_id': _myId,
        'content': text,
        'message_type': type,
        'metadata': optimistic['metadata'],
        if (replyTo != null) 'reply_to_id': replyTo['id'],
      }).select().single();

      // Replace optimistic with real message
      if (mounted) {
        setState(() {
          final idx = _messages.indexWhere((m) => m['id'] == optimistic['id']);
          final realMsg = {
            ...Map<String, dynamic>.from(result),
            'sender_name': optimistic['sender_name'],
          };
          if (idx >= 0) {
            _messages[idx] = realMsg;
          } else {
            _messages.add(realMsg);
          }
          // Broadcast to others in real-time
          _channel?.send(
            type: RealtimeListenTypes.broadcast,
            event: 'new_message',
            payload: realMsg,
          );
        });
      }
    } catch (e) {
      // Remove optimistic on failure
      if (mounted) {
        setState(() => _messages.removeWhere((m) => m['id'] == optimistic['id']));
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to send: $e'), backgroundColor: Colors.red),
        );
      }
    }
    if (mounted) setState(() => _sending = false);
  }

  Future<void> _showCodeSheet() async {
    final codeCtrl = TextEditingController();
    final langCtrl = TextEditingController(text: 'dart');
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        decoration: BoxDecoration(
          color: Theme.of(ctx).colorScheme.surface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        ),
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(ctx).viewInsets.bottom + 16,
          left: 16, right: 16, top: 16,
        ),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          TextField(controller: langCtrl, decoration: const InputDecoration(labelText: 'Language')),
          const SizedBox(height: 8),
          TextField(
            controller: codeCtrl, maxLines: 8,
            decoration: const InputDecoration(labelText: 'Paste code here', border: OutlineInputBorder()),
            style: const TextStyle(fontFamily: 'monospace', fontSize: 13),
          ),
          const SizedBox(height: 12),
          SizedBox(width: double.infinity, child: FilledButton.icon(
            onPressed: () {
              Navigator.pop(ctx);
              _controller.text = codeCtrl.text;
              _send(type: 'code', metadata: {'language': langCtrl.text});
            },
            icon: const Icon(Icons.send),
            label: const Text('Send Code'),
          )),
        ]),
      ),
    );
  }

  Future<void> _showMembersSheet() async {
    try {
      final res = await ApiClient.instance.get<Map<String, dynamic>>('/groups/${widget.groupId}/members');
      final currentMember = (res['members'] as List).firstWhere((m) => m['id'] == _myId, orElse: () => null);
      final bool iAmAdmin = currentMember != null && (currentMember['isCreator'] == true || currentMember['role'] == 'admin');

      if (!mounted) return;
      showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        backgroundColor: AppColors.surface(context),
        builder: (ctx) => StatefulBuilder(builder: (ctx, setInnerState) {
          final members = res['members'] as List;
          return Container(
            padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom + 16, left: 16, right: 16, top: 24),
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              const Text('Group Members', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 16),
              ...members.map((m) {
                final isAdmin = m['isCreator'] == true || m['role'] == 'admin';
                return ListTile(
                  leading: CircleAvatar(backgroundColor: AppColors.indigo, child: Text(m['name'][0].toUpperCase(), style: const TextStyle(color: Colors.white))),
                  title: Text(m['name'], style: TextStyle(color: AppColors.textPrimary(context))),
                  subtitle: Text(isAdmin ? 'Admin' : 'Member', style: TextStyle(color: isAdmin ? AppColors.amber : AppColors.textSecondary(context))),
                  trailing: (iAmAdmin && !isAdmin && m['id'] != _myId)
                      ? TextButton(
                          onPressed: () async {
                            try {
                              await ApiClient.instance.post('/groups/${widget.groupId}/promote', data: {'memberId': m['id']});
                              setInnerState(() => m['role'] = 'admin');
                              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('User promoted to Admin!')));
                            } catch (e) {
                              ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
                            }
                          },
                          child: const Text('Make Admin', style: TextStyle(color: AppColors.indigo)))
                      : null,
                );
              }),
            ]),
          );
        }),
      );
    } catch (_) {}
  }

  @override
  void dispose() {
    _channel?.unsubscribe();
    _controller.dispose();
    _scroll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isDark = context.isDark;
    final presence = ref.watch(presenceProvider(widget.groupId));
    final typingIds = presence.typingUserIds;

    return Scaffold(
      backgroundColor: AppColors.cardBg(context),
      appBar: AppBar(
        surfaceTintColor: Colors.transparent,
        backgroundColor: AppColors.surface(context),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.canPop() ? context.pop() : context.go('/groups'),
        ),
        titleSpacing: 0,
        title: Row(children: [
          CircleAvatar(
            radius: 18,
            backgroundColor: cs.primaryContainer,
            child: Text(
              (_groupName ?? 'G')[0].toUpperCase(),
              style: TextStyle(fontWeight: FontWeight.w800, color: cs.onPrimaryContainer),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(_groupName ?? 'Squad Chat',
              style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
            Row(children: [
              Container(width: 6, height: 6, decoration: const BoxDecoration(color: Color(0xFF10B981), shape: BoxShape.circle)),
              const SizedBox(width: 4),
              Text('Live', style: TextStyle(fontSize: 11, color: cs.outline)),
            ]),
          ])),
        ]),
        actions: [
          IconButton(
            icon: const Icon(Icons.group_outlined),
            tooltip: 'Members',
            onPressed: _showMembersSheet,
          ),
          IconButton(
            icon: const Icon(Icons.view_kanban_outlined),
            tooltip: 'Kanban',
            onPressed: () => context.push('/kanban/${widget.groupId}'),
          ),
          IconButton(
            icon: const Icon(Icons.draw_outlined),
            tooltip: 'Whiteboard',
            onPressed: () => context.push('/whiteboard/${widget.groupId}'),
          ),
        ],
        elevation: 0,
      ),
      body: Column(children: [
        // Messages list
        Expanded(child: _loading
          ? const ChatShimmer()
          : _messages.isEmpty
            ? Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
                Text('👋', style: const TextStyle(fontSize: 48)),
                const SizedBox(height: 12),
                Text('Say hi to your squad!', style: TextStyle(color: cs.outline, fontSize: 16)),
              ]))
            : ListView.builder(
                controller: _scroll,
                reverse: true,
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                itemCount: _messages.length,
                itemBuilder: (ctx, i) {
                  // reverse: true means i=0 is the NEWEST (bottom)
                  final msg = _messages[_messages.length - 1 - i];
                  final prevMsg = i < _messages.length - 1
                      ? _messages[_messages.length - 2 - i] : null;

                  // ── Whiteboard activity pill ──
                  if (msg['message_type'] == 'whiteboard') {
                    return _ActivityPill(
                      msg: msg,
                      onTap: () => context.push('/whiteboard/${widget.groupId}'),
                    );
                  }

                  final isMe = msg['sender_id'] == _myId;
                  final showName = !isMe && (prevMsg == null ||
                      prevMsg['message_type'] == 'whiteboard' ||
                      prevMsg['sender_id'] != msg['sender_id']);

                  // Date separator: show when day changes
                  Widget? separator;
                  if (prevMsg != null) {
                    try {
                      final curr = DateTime.parse(msg['created_at'] as String).toLocal();
                      final prev = DateTime.parse(prevMsg['created_at'] as String).toLocal();
                      if (curr.day != prev.day || curr.month != prev.month) {
                        separator = _DateSeparator(date: curr);
                      }
                    } catch (_) {}
                  }

                  return Column(mainAxisSize: MainAxisSize.min, children: [
                    if (separator != null) separator,
                    _MessageBubble(
                      msg: msg,
                      isMe: isMe,
                      showSenderName: showName,
                      onReply: () => setState(() => _replyTo = msg),
                    ),
                  ]);
                },
              ),
        ),

        // Typing indicators
        if (typingIds.isNotEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(children: [
              Text(
                '${typingIds.map((id) => presence.idToName[id] ?? 'Someone').join(', ')} ${typingIds.length > 1 ? 'are' : 'is'} typing...',
                style: TextStyle(fontSize: 10, color: AppColors.indigo, fontStyle: FontStyle.italic),
              ),
            ]),
          ),

        // Input bar
        _InputBar(
          controller: _controller,
          sending: _sending,
          onSend: _send,
          onCode: _showCodeSheet,
          onTyping: () => ref.read(presenceProvider(widget.groupId).notifier).setTyping(true),
          replyTo: _replyTo,
          onCancelReply: () => setState(() => _replyTo = null),
        ),
      ]),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Message Bubble — WhatsApp/ChatGPT style
// ─────────────────────────────────────────────────────────────────────────────
class _MessageBubble extends StatelessWidget {
  final Map<String, dynamic> msg;
  final bool isMe;
  final bool showSenderName;
  final VoidCallback onReply;

  const _MessageBubble({
    required this.msg,
    required this.isMe,
    required this.showSenderName,
    required this.onReply,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isDark = context.isDark;
    final isCode = msg['message_type'] == 'code';
    final content = msg['content'] as String? ?? '';
    final lang = (msg['metadata'] as Map?)?['language'] as String? ?? '';
    final replyTo = (msg['metadata'] as Map?)?['reply_to'] as Map?;

    final bubbleColor = isMe
        ? AppColors.indigo.withOpacity(0.9)
        : isDark ? AppColors.darkSurface.withOpacity(0.8) : Colors.white.withOpacity(0.9);
    
    final textColor = isMe ? Colors.white : AppColors.textPrimary(context);

    final timeStr = () {
      try {
        final t = DateTime.parse(msg['created_at'] as String).toLocal();
        return DateFormat('h:mm a').format(t);
      } catch (_) { return ''; }
    }();

    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Column(
        crossAxisAlignment: isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
        children: [
          if (showSenderName && !isMe)
            Padding(
              padding: const EdgeInsets.only(left: 42, bottom: 4),
              child: Text(msg['sender_name'] as String? ?? 'User',
                style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: AppColors.indigo, letterSpacing: 0.5)),
            ),
          Row(
            mainAxisAlignment: isMe ? MainAxisAlignment.end : MainAxisAlignment.start,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              if (!isMe) ...[
                CircleAvatar(
                  radius: 15,
                  backgroundColor: AppColors.indigo.withOpacity(0.1),
                  child: Text(
                    (msg['sender_name'] as String? ?? 'U')[0].toUpperCase(),
                    style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: AppColors.indigo),
                  ),
                ),
                const SizedBox(width: 8),
              ],
              Flexible(
                child: GestureDetector(
                  onHorizontalDragEnd: (details) {
                    if (details.primaryVelocity! < -100) onReply();
                  },
                  onLongPress: () {
                    HapticFeedback.mediumImpact();
                    _showMessageMenu(context, content, onReply);
                  },
                  child: Container(
                    margin: EdgeInsets.only(left: isMe ? 60 : 0, right: isMe ? 0 : 60),
                    padding: const EdgeInsets.fromLTRB(14, 10, 14, 8),
                    decoration: BoxDecoration(
                      color: bubbleColor,
                      borderRadius: BorderRadius.only(
                        topLeft: const Radius.circular(20),
                        topRight: const Radius.circular(20),
                        bottomLeft: Radius.circular(isMe ? 20 : 4),
                        bottomRight: Radius.circular(isMe ? 4 : 20),
                      ),
                      border: Border.all(
                        color: isMe ? Colors.white.withOpacity(0.1) : AppColors.border(context),
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(isDark ? 0.2 : 0.05),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        )
                      ],
                    ),
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      // Reply Preview
                      if (replyTo != null)
                        Container(
                          margin: const EdgeInsets.only(bottom: 8),
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                          decoration: BoxDecoration(
                            color: (isMe ? Colors.black : AppColors.indigo).withOpacity(0.1),
                            borderRadius: BorderRadius.circular(8),
                            border: Border(left: BorderSide(color: isMe ? Colors.white54 : AppColors.indigo, width: 3)),
                          ),
                          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                            Text(replyTo['sender_name'] ?? 'User', 
                              style: TextStyle(fontSize: 10, fontWeight: FontWeight.w900, color: isMe ? Colors.white70 : AppColors.indigo)),
                            Text(replyTo['content'] ?? '', 
                              maxLines: 1, overflow: TextOverflow.ellipsis,
                              style: TextStyle(fontSize: 12, color: isMe ? Colors.white60 : AppColors.textSecondary(context))),
                          ]),
                        ),

                      // Content
                      if (isCode)
                        _CodeBlock(content: content, lang: lang, isMe: isMe)
                      else
                        Text(content, style: TextStyle(color: textColor, fontSize: 15, height: 1.4, letterSpacing: 0.2)),

                      // Footer
                      const SizedBox(height: 4),
                      Row(mainAxisSize: MainAxisSize.min, children: [
                        const Spacer(),
                        Text(
                          timeStr,
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                            color: isMe ? Colors.white60 : AppColors.textMuted(context),
                          ),
                        ),
                        if (isMe) ...[
                          const SizedBox(width: 4),
                          Icon(Icons.done_all, size: 12, color: Colors.white60),
                        ],
                      ]),
                    ]),
                  ),
                ),
              ),
              if (isMe) const SizedBox(width: 8),
            ],
          ),
        ],
      ),
    );
  }

  void _showMessageMenu(BuildContext context, String content, VoidCallback onReply) {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.surface(context),
      builder: (ctx) => SafeArea(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          ListTile(
            leading: const Icon(Icons.reply_outlined),
            title: const Text('Reply'),
            onTap: () { Navigator.pop(ctx); onReply(); },
          ),
          ListTile(
            leading: const Icon(Icons.copy_outlined),
            title: const Text('Copy Text'),
            onTap: () {
              Clipboard.setData(ClipboardData(text: content));
              Navigator.pop(ctx);
            },
          ),
        ]),
      ),
    );
  }
}

class _CodeBlock extends StatelessWidget {
  final String content, lang;
  final bool isMe;
  const _CodeBlock({required this.content, required this.lang, required this.isMe});

  @override
  Widget build(BuildContext context) {
    final isDark = context.isDark;
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [
        Icon(Icons.code, size: 12, color: isMe ? Colors.white70 : AppColors.indigo),
        const SizedBox(width: 4),
        Text(lang.toUpperCase(), style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: isMe ? Colors.white70 : AppColors.indigo)),
      ]),
      const SizedBox(height: 8),
      Container(
        width: double.infinity,
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: isDark ? Colors.black.withOpacity(0.3) : Colors.black.withOpacity(0.05),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: Colors.white.withOpacity(0.05)),
        ),
        child: Text(content,
          style: TextStyle(fontFamily: 'monospace', color: isDark ? const Color(0xFF50FA7B) : const Color(0xFF1B5E20), fontSize: 12)),
      ),
    ]);
  }
}

// ── Input Bar ─────────────────────────────────────────────────────────────────
class _InputBar extends StatelessWidget {
  final TextEditingController controller;
  final bool sending;
  final Function({String type, Map<String, dynamic>? metadata}) onSend;
  final VoidCallback onCode;
  final VoidCallback onTyping;
  final Map<String, dynamic>? replyTo;
  final VoidCallback onCancelReply;

  const _InputBar({
    required this.controller,
    required this.sending,
    required this.onSend,
    required this.onCode,
    required this.onTyping,
    this.replyTo,
    required this.onCancelReply,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = context.isDark;

    return Container(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 16),
      decoration: BoxDecoration(
        color: AppColors.surface(context).withOpacity(0.9),
        border: Border(top: BorderSide(color: AppColors.border(context))),
      ),
      child: SafeArea(top: false, child: Column(mainAxisSize: MainAxisSize.min, children: [
        if (replyTo != null)
          Container(
            margin: const EdgeInsets.only(bottom: 8),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: AppColors.indigo.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(children: [
              const Icon(Icons.reply, size: 16, color: AppColors.indigo),
              const SizedBox(width: 8),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('Replying to ${replyTo!['sender_name']}', 
                  style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w900, color: AppColors.indigo)),
                Text(replyTo!['content'], maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 12, color: AppColors.textSecondary(context))),
              ])),
              IconButton(icon: const Icon(Icons.close, size: 18), onPressed: onCancelReply),
            ]),
          ),
        Row(children: [
          IconButton(
            icon: const Icon(Icons.add_circle_outline, color: AppColors.indigo, size: 28),
            onPressed: () => _showAttachmentMenu(context),
          ),
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                color: isDark ? Colors.black.withOpacity(0.2) : Colors.black.withOpacity(0.04),
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: AppColors.border(context)),
              ),
              child: TextField(
                controller: controller,
                minLines: 1, maxLines: 5,
                onChanged: (_) => onTyping(),
                style: TextStyle(color: AppColors.textPrimary(context)),
                decoration: InputDecoration(
                  hintText: 'Type a message...',
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  border: InputBorder.none,
                  hintStyle: TextStyle(color: AppColors.textMuted(context), fontSize: 14),
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          sending
            ? const SizedBox(width: 44, height: 44, child: Center(child: CircularProgressIndicator(strokeWidth: 2)))
            : FloatingActionButton.small(
                onPressed: () => onSend(),
                backgroundColor: AppColors.indigo,
                elevation: 4,
                child: const Icon(Icons.send, color: Colors.white, size: 18),
              ),
        ]),
      ])),
    );
  }

  void _showAttachmentMenu(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.surface(context),
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Row(mainAxisAlignment: MainAxisAlignment.spaceAround, children: [
              _AttachmentItem(icon: Icons.code, label: 'Code', color: AppColors.amber, onTap: () { Navigator.pop(ctx); onCode(); }),
              _AttachmentItem(icon: Icons.draw_outlined, label: 'Board', color: AppColors.rose, onTap: () { Navigator.pop(ctx); }),
              _AttachmentItem(icon: Icons.insert_drive_file_outlined, label: 'File', color: AppColors.indigo, onTap: () {}),
            ]),
          ]),
        ),
      ),
    );
  }
}

class _AttachmentItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;
  const _AttachmentItem({required this.icon, required this.label, required this.color, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Column(mainAxisSize: MainAxisSize.min, children: [
      InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          width: 56, height: 56,
          decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(16), border: Border.all(color: color.withOpacity(0.3))),
          child: Icon(icon, color: color, size: 28),
        ),
      ),
      const SizedBox(height: 8),
      Text(label, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: AppColors.textSecondary(context))),
    ]);
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Whiteboard Activity Pill
// ─────────────────────────────────────────────────────────────────────────────
class _ActivityPill extends StatelessWidget {
  final Map<String, dynamic> msg;
  final VoidCallback onTap;
  const _ActivityPill({required this.msg, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final content = msg['content'] as String? ?? 'Whiteboard activity';
    final timeStr = () {
      try {
        final t = DateTime.parse(msg['created_at'] as String).toLocal();
        return DateFormat('h:mm a').format(t);
      } catch (_) { return ''; }
    }();

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Center(
        child: GestureDetector(
          onTap: onTap,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: AppColors.indigo.withOpacity(0.12),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: AppColors.indigo.withOpacity(0.3)),
            ),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              const Text('🎨', style: TextStyle(fontSize: 16)),
              const SizedBox(width: 8),
              Flexible(child: Text(
                content,
                style: TextStyle(fontSize: 13, color: cs.onSurface, fontWeight: FontWeight.w500),
              )),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: AppColors.indigo,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Text('Join Live', style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w700)),
              ),
            ]),
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Date Separator
// ─────────────────────────────────────────────────────────────────────────────
class _DateSeparator extends StatelessWidget {
  final DateTime date;
  const _DateSeparator({required this.date});

  String get _label {
    final now = DateTime.now();
    if (date.year == now.year && date.month == now.month && date.day == now.day) return 'Today';
    final yesterday = now.subtract(const Duration(days: 1));
    if (date.year == yesterday.year && date.month == yesterday.month && date.day == yesterday.day) return 'Yesterday';
    return DateFormat('MMM d, yyyy').format(date);
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Row(children: [
        Expanded(child: Divider(color: cs.outline.withOpacity(0.2))),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Text(_label,
            style: TextStyle(fontSize: 11, color: cs.outline, fontWeight: FontWeight.w600)),
        ),
        Expanded(child: Divider(color: cs.outline.withOpacity(0.2))),
      ]),
    );
  }
}
