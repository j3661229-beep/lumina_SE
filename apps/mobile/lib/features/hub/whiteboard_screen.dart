import 'package:flutter/material.dart';
import 'package:flutter_drawing_board/flutter_drawing_board.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:go_router/go_router.dart';

class WhiteboardScreen extends StatefulWidget {
  final String groupId;
  const WhiteboardScreen({super.key, required this.groupId});
  @override
  State<WhiteboardScreen> createState() => _WhiteboardScreenState();
}

class _WhiteboardScreenState extends State<WhiteboardScreen> {
  final _drawingController = DrawingController();
  final _supabase = Supabase.instance.client;
  final _sessionId = DateTime.now().millisecondsSinceEpoch.toString();

  @override
  void initState() {
    super.initState();
    _sendPresenceMessage();
  }

  Future<void> _sendPresenceMessage() async {
    final user = _supabase.auth.currentUser;
    if (user == null) return;
    final name = user.userMetadata?['display_name'] as String?
        ?? user.email?.split('@')[0]
        ?? 'Someone';
    try {
      await _supabase.from('messages').insert({
        'group_id': widget.groupId,
        'sender_id': user.id,
        'content': '$name opened the Whiteboard 🎨',
        'message_type': 'whiteboard',
        'metadata': {
          'action': 'whiteboard_open',
          'user_name': name,
          'group_id': widget.groupId,
        },
      });
    } catch (_) {}
  }

  Future<void> _saveStroke(dynamic strokeData) async {
    await _supabase.from('whiteboard_strokes').insert({
      'group_id': widget.groupId,
      'session_id': _sessionId,
      'author_id': _supabase.auth.currentUser!.id,
      'stroke_data': strokeData,
    });
  }

  @override
  void dispose() {
    _drawingController.dispose();
    super.dispose();
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
        title: const Text('Whiteboard'),
        backgroundColor: Theme.of(context).colorScheme.surface,
        actions: [
          IconButton(
            icon: const Icon(Icons.undo),
            onPressed: () => _drawingController.undo(),
          ),
          IconButton(
            icon: const Icon(Icons.redo),
            onPressed: () => _drawingController.redo(),
          ),
          IconButton(
            icon: const Icon(Icons.delete_outline),
            onPressed: () => showDialog(
              context: context,
              builder: (ctx) => AlertDialog(
                title: const Text('Clear whiteboard?'),
                actions: [
                  TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
                  TextButton(
                    onPressed: () { _drawingController.clear(); Navigator.pop(ctx); },
                    child: const Text('Clear'),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
      body: DrawingBoard(
        controller: _drawingController,
        background: Container(
          color: Theme.of(context).brightness == Brightness.dark
              ? const Color(0xFF1A1A2E)
              : Colors.white,
        ),
        showDefaultActions: true,
        showDefaultTools: true,
      ),
    );
  }
}
