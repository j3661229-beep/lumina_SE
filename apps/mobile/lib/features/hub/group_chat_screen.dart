import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../core/network/api_client.dart';
import '../../core/theme/design_tokens.dart';

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
            // Fetch sender name
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
            if (mounted) {
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

    // ── Optimistic update: show immediately ──
    final myUser = _supabase.auth.currentUser;
    final optimistic = {
      'id': 'optimistic_${DateTime.now().millisecondsSinceEpoch}',
      'content': text,
      'message_type': type,
      'metadata': metadata,
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
        if (metadata != null) 'metadata': metadata,
      }).select().single();

      // Replace optimistic with real message
      if (mounted) {
        setState(() {
          final idx = _messages.indexWhere((m) => m['id'] == optimistic['id']);
          if (idx >= 0) {
            _messages[idx] = {
              ...Map<String, dynamic>.from(result),
              'sender_name': optimistic['sender_name'],
            };
          }
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
        backgroundColor: const Color(0xFF0F1228),
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
                  leading: CircleAvatar(backgroundColor: DesignColor.indigo, child: Text(m['name'][0].toUpperCase(), style: const TextStyle(color: Colors.white))),
                  title: Text(m['name'], style: const TextStyle(color: Colors.white)),
                  subtitle: Text(isAdmin ? 'Admin' : 'Member', style: TextStyle(color: isAdmin ? DesignColor.amber : DesignColor.sub)),
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
                          child: const Text('Make Admin', style: TextStyle(color: DesignColor.indigo)))
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
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF0F0F1A) : const Color(0xFFF0F2F5),
      appBar: AppBar(
        backgroundColor: isDark ? const Color(0xFF1A1A2E) : cs.surface,
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
          ? const Center(child: CircularProgressIndicator())
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
                    ),
                  ]);
                },
              ),
        ),

        // Input bar
        _InputBar(
          controller: _controller,
          sending: _sending,
          onSend: _send,
          onCode: _showCodeSheet,
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
  const _MessageBubble({
    required this.msg,
    required this.isMe,
    required this.showSenderName,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isCode = msg['message_type'] == 'code';
    final content = msg['content'] as String? ?? '';
    final lang = (msg['metadata'] as Map?)?['language'] as String? ?? '';

    final bubbleColor = isMe
        ? const Color(0xFF6366F1)
        : isDark ? const Color(0xFF1E1E2E) : Colors.white;
    final textColor = isMe ? Colors.white : null;

    final timeStr = () {
      try {
        final t = DateTime.parse(msg['created_at'] as String).toLocal();
        return DateFormat('h:mm a').format(t);
      } catch (_) { return ''; }
    }();

    return Padding(
      padding: const EdgeInsets.only(bottom: 2),
      child: Column(
        crossAxisAlignment: isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
        children: [
          if (showSenderName && !isMe)
            Padding(
              padding: const EdgeInsets.only(left: 40, bottom: 2),
              child: Text(msg['sender_name'] as String? ?? 'User',
                style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: cs.primary)),
            ),
          Row(
            mainAxisAlignment: isMe ? MainAxisAlignment.end : MainAxisAlignment.start,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              if (!isMe) ...[
                CircleAvatar(
                  radius: 14,
                  backgroundColor: cs.primaryContainer,
                  child: Text(
                    (msg['sender_name'] as String? ?? 'U')[0].toUpperCase(),
                    style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: cs.onPrimaryContainer),
                  ),
                ),
                const SizedBox(width: 6),
              ],
              Flexible(
                child: GestureDetector(
                  onLongPress: () {
                    Clipboard.setData(ClipboardData(text: content));
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Copied!'), duration: Duration(seconds: 1)),
                    );
                  },
                  child: Container(
                    margin: EdgeInsets.only(left: isMe ? 60 : 0, right: isMe ? 0 : 60),
                    padding: const EdgeInsets.fromLTRB(14, 10, 14, 6),
                    decoration: BoxDecoration(
                      color: bubbleColor,
                      borderRadius: BorderRadius.only(
                        topLeft: const Radius.circular(18),
                        topRight: const Radius.circular(18),
                        bottomLeft: Radius.circular(isMe ? 18 : 4),
                        bottomRight: Radius.circular(isMe ? 4 : 18),
                      ),
                      boxShadow: [BoxShadow(
                        color: Colors.black.withOpacity(0.06),
                        blurRadius: 4, offset: const Offset(0, 1),
                      )],
                    ),
                    child: Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                      // Content
                      if (isCode)
                        Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Row(children: [
                            Icon(Icons.code, size: 12, color: isMe ? Colors.white70 : cs.outline),
                            const SizedBox(width: 4),
                            Text(lang, style: TextStyle(fontSize: 11, color: isMe ? Colors.white70 : cs.outline)),
                          ]),
                          const SizedBox(height: 6),
                          Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: const Color(0xFF1E1E2E),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(content,
                              style: const TextStyle(fontFamily: 'monospace', color: Color(0xFF50FA7B), fontSize: 12)),
                          ),
                        ])
                      else
                        Align(
                          alignment: Alignment.centerLeft,
                          child: Text(content, style: TextStyle(color: textColor, fontSize: 15, height: 1.35))
                        ),
                      // Time — always shown bottom-right inside bubble (WhatsApp style)
                      const SizedBox(height: 2),
                      Text(
                        timeStr,
                        style: TextStyle(
                          fontSize: 10,
                          color: isMe ? Colors.white54 : cs.outline,
                        ),
                      ),
                    ]),
                  ),
                ),
              ),
              if (isMe) const SizedBox(width: 6),
            ],
          ),
          const SizedBox(height: 2),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────

// Input Bar
// ─────────────────────────────────────────────────────────────────────────────
class _InputBar extends StatelessWidget {
  final TextEditingController controller;
  final bool sending;
  final Function({String type, Map<String, dynamic>? metadata}) onSend;
  final VoidCallback onCode;
  const _InputBar({required this.controller, required this.sending, required this.onSend, required this.onCode});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      padding: const EdgeInsets.fromLTRB(8, 8, 8, 16),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1A1A2E) : cs.surface,
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.08), blurRadius: 8, offset: const Offset(0, -2))],
      ),
      child: SafeArea(top: false, child: Row(children: [
        // Code button
        IconButton(
          icon: Icon(Icons.code, color: cs.primary),
          tooltip: 'Send code snippet',
          onPressed: onCode,
        ),
        // Text field
        Expanded(
          child: Container(
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF0F0F1A) : cs.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(24),
            ),
            child: TextField(
              controller: controller,
              minLines: 1, maxLines: 5,
              textInputAction: TextInputAction.newline,
              decoration: InputDecoration(
                hintText: 'Message...',
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                border: InputBorder.none,
                hintStyle: TextStyle(color: cs.outline),
              ),
              onSubmitted: (_) => onSend(),
            ),
          ),
        ),
        const SizedBox(width: 8),
        // Send button
        AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          child: sending
            ? const Padding(padding: EdgeInsets.all(12), child: SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)))
            : FloatingActionButton.small(
                heroTag: 'send_msg',
                onPressed: () => onSend(),
                backgroundColor: cs.primary,
                child: const Icon(Icons.send, color: Colors.white, size: 18),
              ),
        ),
      ])),
    );
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
              color: const Color(0xFF6366F1).withOpacity(0.12),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: const Color(0xFF6366F1).withOpacity(0.3)),
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
                  color: const Color(0xFF6366F1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text('Join Live', style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w700)),
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
