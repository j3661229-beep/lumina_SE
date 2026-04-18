import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:go_router/go_router.dart';
import 'kanban_provider.dart';

enum KanbanCol { backlog, todo, doing, done }

class KanbanScreen extends ConsumerStatefulWidget {
  final String groupId;
  const KanbanScreen({super.key, required this.groupId});
  @override
  ConsumerState<KanbanScreen> createState() => _KanbanScreenState();
}

class _KanbanScreenState extends ConsumerState<KanbanScreen> {
  final _supabase = Supabase.instance.client;
  RealtimeChannel? _channel;
  Map<KanbanCol, List<Map<String, dynamic>>> _tasks = {
    for (final c in KanbanCol.values) c: []
  };
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _ensureProfileThenLoad();
    _channel = _supabase
        .channel('kanban_${widget.groupId}')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'kanban_tasks',
          callback: (_) => _load(),
        )
        .subscribe();
  }

  // Upsert profile row first — kanban_tasks.user_id → profiles(id) FK
  Future<void> _ensureProfileThenLoad() async {
    final user = _supabase.auth.currentUser;
    if (user != null) {
      try {
        await _supabase.from('profiles').upsert({
          'id': user.id,
          'display_name': user.userMetadata?['display_name'] as String?
              ?? user.email?.split('@')[0]
              ?? 'User',
        }, onConflict: 'id');
      } catch (_) {}
    }
    await _load();
  }

  Future<void> _load() async {
    try {
      final data = await _supabase
          .from('kanban_tasks')
          .select('id, title, description, status, priority, due_date, user_id, position')
          .eq('group_id', widget.groupId)
          .order('created_at');

      final grouped = {for (final c in KanbanCol.values) c: <Map<String, dynamic>>[]};
      for (final task in List<Map<String, dynamic>>.from(data)) {
        final col = KanbanCol.values.firstWhere(
          (c) => c.name == task['status'], orElse: () => KanbanCol.todo);
        grouped[col]!.add(task);
      }
      if (mounted) setState(() { _tasks = grouped; _loading = false; });
    } catch (e) {
      debugPrint('Kanban _load error: $e');
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _moveTask(Map<String, dynamic> task, KanbanCol to) async {
    final fromName = task['status'] as String? ?? 'todo';
    final from = KanbanCol.values.firstWhere(
      (c) => c.name == fromName, orElse: () => KanbanCol.todo);
    if (from == to) return;
    HapticFeedback.lightImpact();

    // Optimistic update
    setState(() {
      _tasks[from]!.removeWhere((t) => t['id'] == task['id']);
      _tasks[to]!.add({...task, 'status': to.name});
    });

    final taskId = task['id'] as String?;
    if (taskId == null || taskId.startsWith('opt_')) {
      // Can't update an optimistic task — reload to sync
      await _load();
      return;
    }

    try {
      await _supabase.from('kanban_tasks')
          .update({'status': to.name})
          .eq('id', taskId);
      debugPrint('Moved task $taskId → ${to.name}');
    } catch (e) {
      debugPrint('Move task error: $e');
      // Rollback
      _load();
    }
  }

  Future<void> _deleteTask(Map<String, dynamic> task) async {
    final col = KanbanCol.values.firstWhere(
      (c) => c.name == task['status'], orElse: () => KanbanCol.todo);
    setState(() => _tasks[col]!.removeWhere((t) => t['id'] == task['id']));
    try {
      await _supabase.from('kanban_tasks').delete().eq('id', task['id'] as String);
    } catch (_) { _load(); }
  }

  Future<void> _addTask() async {
    final titleCtrl = TextEditingController();
    final descCtrl = TextEditingController();
    String priority = 'medium';
    KanbanCol col = KanbanCol.todo;
    String? assigneeId;
    final cs = Theme.of(context).colorScheme;
    
    List<dynamic> members = [];
    try {
      final res = await _supabase.from('group_members').select('profile_id, profiles(display_name)').eq('group_id', widget.groupId);
      members = res as List;
    } catch (_) {}

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(builder: (ctx2, setModal) => Container(
        decoration: BoxDecoration(
          color: cs.surface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        ),
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(ctx2).viewInsets.bottom + 20,
          left: 20, right: 20, top: 20,
        ),
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(color: cs.primaryContainer, borderRadius: BorderRadius.circular(12)),
              child: Icon(Icons.add_task, color: cs.onPrimaryContainer),
            ),
            const SizedBox(width: 12),
            Text('Add Task', style: Theme.of(ctx2).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700)),
          ]),
          const SizedBox(height: 20),
          TextField(
            controller: titleCtrl,
            autofocus: true,
            decoration: const InputDecoration(labelText: 'Task title *', prefixIcon: Icon(Icons.task_outlined)),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: descCtrl, maxLines: 2,
            decoration: const InputDecoration(labelText: 'Description (optional)', prefixIcon: Icon(Icons.notes_outlined)),
          ),
          const SizedBox(height: 12),
          Row(children: [
            Expanded(child: DropdownButtonFormField<String>(
              value: priority,
              decoration: const InputDecoration(labelText: 'Priority', isDense: true),
              items: [
                DropdownMenuItem(value: 'low', child: Row(children: [
                  Container(width: 8, height: 8, decoration: const BoxDecoration(color: Color(0xFF10B981), shape: BoxShape.circle)),
                  const SizedBox(width: 6), const Text('Low'),
                ])),
                DropdownMenuItem(value: 'medium', child: Row(children: [
                  Container(width: 8, height: 8, decoration: const BoxDecoration(color: Color(0xFF6366F1), shape: BoxShape.circle)),
                  const SizedBox(width: 6), const Text('Medium'),
                ])),
                DropdownMenuItem(value: 'high', child: Row(children: [
                  Container(width: 8, height: 8, decoration: const BoxDecoration(color: Color(0xFFF59E0B), shape: BoxShape.circle)),
                  const SizedBox(width: 6), const Text('High'),
                ])),
                DropdownMenuItem(value: 'critical', child: Row(children: [
                  Container(width: 8, height: 8, decoration: const BoxDecoration(color: Color(0xFFEF4444), shape: BoxShape.circle)),
                  const SizedBox(width: 6), const Text('Critical'),
                ])),
              ],
              onChanged: (v) => setModal(() => priority = v!),
            )),
            const SizedBox(width: 12),
            Expanded(child: DropdownButtonFormField<KanbanCol>(
              value: col,
              decoration: const InputDecoration(labelText: 'Column', isDense: true),
              items: KanbanCol.values.map((c) => DropdownMenuItem(
                value: c,
                child: Text(c.name[0].toUpperCase() + c.name.substring(1)),
              )).toList(),
              onChanged: (v) => setModal(() => col = v!),
            )),
          ]),
          const SizedBox(height: 12),
          DropdownButtonFormField<String?>(
            value: assigneeId,
            decoration: const InputDecoration(labelText: 'Assign To', prefixIcon: Icon(Icons.person_outline), isDense: true),
            items: [
              const DropdownMenuItem(value: null, child: Text('Unassigned')),
              ...members.map((m) => DropdownMenuItem(
                value: m['profile_id'] as String,
                child: Text(m['profiles']['display_name'] ?? 'User'),
              )),
            ],
            onChanged: (v) => setModal(() => assigneeId = v),
          ),
          const SizedBox(height: 20),
          SizedBox(width: double.infinity, child: FilledButton.icon(
            onPressed: () async {
              if (titleCtrl.text.trim().isEmpty) return;
              Navigator.pop(ctx2);
              final optimistic = {
                'id': 'opt_${DateTime.now().millisecondsSinceEpoch}',
                'title': titleCtrl.text.trim(),
                'description': descCtrl.text.trim().isEmpty ? null : descCtrl.text.trim(),
                'status': col.name,
                'priority': priority,
                'due_date': null,
              };
              setState(() => _tasks[col]!.add(optimistic));
              try {
                await _supabase.from('kanban_tasks').insert({
                  'group_id': widget.groupId,
                  'user_id': _supabase.auth.currentUser!.id,
                  'title': titleCtrl.text.trim(),
                  'description': descCtrl.text.trim().isEmpty ? null : descCtrl.text.trim(),
                  'status': col.name,
                  'priority': priority,
                  'assignee_id': assigneeId,
                });
                debugPrint('Task inserted OK');
                _load(); // replace optimistic with real DB record
              } catch (e) {
                debugPrint('Task insert error: $e');
                setState(() => _tasks[col]!.removeWhere((t) => t['id'] == optimistic['id']));
                // Show error to user
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Failed to save task: $e'), backgroundColor: Colors.red),
                  );
                }
              }
            },
            icon: const Icon(Icons.add),
            label: const Text('Add Task'),
            style: FilledButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 14)),
          )),
        ]),
      )),
    );
  }

  @override
  void dispose() {
    _channel?.unsubscribe();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final total = _tasks.values.fold(0, (s, l) => s + l.length);
    final done = _tasks[KanbanCol.done]?.length ?? 0;
    final progress = total == 0 ? 0.0 : done / total;

    return Scaffold(
      backgroundColor: cs.surface,
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.canPop() ? context.pop() : context.go('/groups'),
        ),
        title: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('Kanban Board', style: TextStyle(fontWeight: FontWeight.w700)),
          Text('$done/$total tasks done', style: TextStyle(fontSize: 12, color: cs.outline)),
        ]),
        backgroundColor: cs.surface,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.chat_outlined),
            tooltip: 'Back to Chat',
            onPressed: () => context.canPop() ? context.pop() : context.go('/groups'),
          ),
          IconButton(
            icon: const Icon(Icons.refresh_outlined),
            onPressed: _load,
          ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(6),
          child: LinearProgressIndicator(
            value: progress,
            backgroundColor: cs.surfaceContainerHighest,
            valueColor: AlwaysStoppedAnimation(cs.primary),
            minHeight: 4,
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _addTask,
        icon: const Icon(Icons.add),
        label: const Text('Add Task'),
      ),
      body: _loading
        ? const Center(child: CircularProgressIndicator())
        : ListView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.all(16),
            children: KanbanCol.values.map((col) => _KanbanColumn(
              col: col,
              tasks: _tasks[col]!,
              onDrop: (task) => _moveTask(task, col),
              onDelete: _deleteTask,
            )).toList(),
          ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Column
// ─────────────────────────────────────────────────────────────────────────────
class _KanbanColumn extends StatelessWidget {
  final KanbanCol col;
  final List<Map<String, dynamic>> tasks;
  final void Function(Map<String, dynamic>) onDrop;
  final void Function(Map<String, dynamic>) onDelete;
  const _KanbanColumn({required this.col, required this.tasks, required this.onDrop, required this.onDelete});

  static const _meta = {
    KanbanCol.backlog: (
      color: Color(0xFF94A3B8),
      icon: Icons.inbox_outlined,
      label: 'Backlog',
    ),
    KanbanCol.todo: (
      color: Color(0xFF6366F1),
      icon: Icons.radio_button_unchecked,
      label: 'To Do',
    ),
    KanbanCol.doing: (
      color: Color(0xFFF59E0B),
      icon: Icons.play_circle_outline,
      label: 'In Progress',
    ),
    KanbanCol.done: (
      color: Color(0xFF10B981),
      icon: Icons.check_circle_outline,
      label: 'Done',
    ),
  };

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final meta = _meta[col]!;

    return DragTarget<Map<String, dynamic>>(
      onAcceptWithDetails: (d) => onDrop(d.data),
      builder: (ctx, candidates, _) => AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        width: 270,
        margin: const EdgeInsets.only(right: 16),
        decoration: BoxDecoration(
          color: candidates.isNotEmpty
              ? meta.color.withOpacity(0.08)
              : cs.surfaceContainerHighest.withOpacity(0.4),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: candidates.isNotEmpty ? meta.color : Colors.transparent,
            width: 2,
          ),
        ),
        child: Column(children: [
          // Column header
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: meta.color.withOpacity(0.12),
              borderRadius: const BorderRadius.vertical(top: Radius.circular(18)),
            ),
            child: Row(children: [
              Icon(meta.icon, color: meta.color, size: 20),
              const SizedBox(width: 8),
              Expanded(child: Text(meta.label,
                style: TextStyle(fontWeight: FontWeight.w800, color: meta.color, fontSize: 14))),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: meta.color,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text('${tasks.length}',
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 13)),
              ),
            ]),
          ),

          // Task list
          Expanded(
            child: tasks.isEmpty
              ? Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
                  Icon(meta.icon, size: 36, color: meta.color.withOpacity(0.3)),
                  const SizedBox(height: 8),
                  Text('Drop here', style: TextStyle(color: meta.color.withOpacity(0.4), fontSize: 13)),
                ]))
              : ListView.builder(
                  padding: const EdgeInsets.fromLTRB(10, 8, 10, 80),
                  itemCount: tasks.length,
                  itemBuilder: (ctx, i) => Draggable<Map<String, dynamic>>(
                    data: tasks[i],
                    onDragStarted: () => HapticFeedback.mediumImpact(),
                    feedback: Material(
                      elevation: 12,
                      borderRadius: BorderRadius.circular(14),
                      child: SizedBox(
                        width: 250,
                        child: _TaskCard(task: tasks[i], dragging: true, onDelete: () {}),
                      ),
                    ),
                    childWhenDragging: Opacity(
                      opacity: 0.25,
                      child: _TaskCard(task: tasks[i], onDelete: () {}),
                    ),
                    child: _TaskCard(
                      task: tasks[i],
                      onDelete: () => onDelete(tasks[i]),
                    ),
                  ),
                ),
          ),
        ]),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Task Card
// ─────────────────────────────────────────────────────────────────────────────
class _TaskCard extends StatelessWidget {
  final Map<String, dynamic> task;
  final bool dragging;
  final VoidCallback onDelete;
  const _TaskCard({required this.task, this.dragging = false, required this.onDelete});

  static const _priorityColors = {
    'low': Color(0xFF10B981),
    'medium': Color(0xFF6366F1),
    'high': Color(0xFFF59E0B),
    'critical': Color(0xFFEF4444),
  };
  static const _priorityIcons = {
    'low': Icons.arrow_downward,
    'medium': Icons.remove,
    'high': Icons.arrow_upward,
    'critical': Icons.priority_high,
  };

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final priority = task['priority'] as String? ?? 'medium';
    final color = _priorityColors[priority] ?? cs.primary;
    final icon = _priorityIcons[priority] ?? Icons.remove;

    return Dismissible(
      key: Key('${task['id']}_card'),
      direction: dragging ? DismissDirection.none : DismissDirection.endToStart,
      onDismissed: (_) => onDelete(),
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 16),
        decoration: BoxDecoration(
          color: cs.errorContainer,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Icon(Icons.delete_outline, color: cs.error),
      ),
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        decoration: BoxDecoration(
          color: dragging ? cs.primary.withOpacity(0.95) : cs.surface,
          borderRadius: BorderRadius.circular(14),
          border: Border(left: BorderSide(color: color, width: 4)),
          boxShadow: [
            BoxShadow(
              color: dragging ? cs.primary.withOpacity(0.3) : Colors.black.withOpacity(0.06),
              blurRadius: dragging ? 20 : 4,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Expanded(child: Text(
                task['title'] as String? ?? '',
                style: TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 14,
                  color: dragging ? Colors.white : null,
                ),
                maxLines: 2, overflow: TextOverflow.ellipsis,
              )),
              const SizedBox(width: 6),
              Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Icon(icon, size: 12, color: color),
              ),
            ]),
            if ((task['description'] as String?)?.isNotEmpty == true) ...[
              const SizedBox(height: 6),
              Text(
                task['description'] as String,
                style: TextStyle(fontSize: 12, color: dragging ? Colors.white70 : cs.outline, height: 1.4),
                maxLines: 2, overflow: TextOverflow.ellipsis,
              ),
            ],
            const SizedBox(height: 8),
            Row(children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  priority[0].toUpperCase() + priority.substring(1),
                  style: TextStyle(fontSize: 10, color: color, fontWeight: FontWeight.w700),
                ),
              ),
              if (task['due_date'] != null) ...[
                const SizedBox(width: 8),
                Icon(Icons.calendar_today_outlined, size: 11,
                  color: dragging ? Colors.white54 : cs.outline),
                const SizedBox(width: 3),
                Text(
                  task['due_date'].toString().split('T')[0],
                  style: TextStyle(fontSize: 11, color: dragging ? Colors.white54 : cs.outline),
                ),
              ],
              const Spacer(),
              Text('swipe ←', style: TextStyle(fontSize: 9, color: cs.outline.withOpacity(0.4))),
            ]),
          ]),
        ),
      ),
    );
  }
}
