import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:go_router/go_router.dart';
import '../../core/theme/design_tokens.dart';
import '../../shared/widgets/shimmer_widgets.dart';

enum KanbanCol { backlog, todo, doing, done }

// ─────────────────────────────────────────────────────────────────────────────
// Group Kanban Board
// ─────────────────────────────────────────────────────────────────────────────
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
  List<dynamic> _members = [];
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
    await Future.wait([_load(), _loadMembers()]);
  }

  Future<void> _loadMembers() async {
    try {
      final res = await _supabase
          .from('group_members')
          .select('profile_id, profiles(display_name)')
          .eq('group_id', widget.groupId);
      if (mounted) setState(() => _members = res as List);
    } catch (_) {}
  }

  Future<void> _load() async {
    try {
      final data = await _supabase
          .from('kanban_tasks')
          .select('id, title, description, status, priority, due_date, user_id, assignee_id, position')
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

    setState(() {
      _tasks[from]!.removeWhere((t) => t['id'] == task['id']);
      _tasks[to]!.add({...task, 'status': to.name});
    });

    final taskId = task['id'] as String?;
    if (taskId == null || taskId.startsWith('opt_')) {
      await _load();
      return;
    }

    try {
      await _supabase.from('kanban_tasks')
          .update({'status': to.name})
          .eq('id', taskId);
    } catch (e) {
      debugPrint('Move task error: $e');
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

  Future<void> _editTask(Map<String, dynamic> task, Map<String, dynamic> updates) async {
    final taskId = task['id'] as String?;
    if (taskId == null || taskId.startsWith('opt_')) return;

    // Optimistic update in the map
    final oldStatus = task['status'] as String? ?? 'todo';
    final newStatus = updates['status'] as String? ?? oldStatus;
    final oldCol = KanbanCol.values.firstWhere((c) => c.name == oldStatus, orElse: () => KanbanCol.todo);
    final newCol = KanbanCol.values.firstWhere((c) => c.name == newStatus, orElse: () => KanbanCol.todo);

    setState(() {
      _tasks[oldCol]!.removeWhere((t) => t['id'] == taskId);
      _tasks[newCol]!.add({...task, ...updates});
    });

    try {
      await _supabase.from('kanban_tasks').update(updates).eq('id', taskId);
      await _load(); // sync truth from DB
    } catch (e) {
      debugPrint('Edit task error: $e');
      _load();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to save: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  void _openTaskDetail(Map<String, dynamic> task) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _TaskDetailSheet(
        task: task,
        members: _members,
        onSave: (updates) => _editTask(task, updates),
        onDelete: () => _deleteTask(task),
      ),
    );
  }

  Future<void> _addTask() async {
    final titleCtrl = TextEditingController();
    final descCtrl = TextEditingController();
    String priority = 'medium';
    KanbanCol col = KanbanCol.todo;
    String? assigneeId;
    final cs = Theme.of(context).colorScheme;

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(builder: (ctx2, setModal) => Container(
        decoration: BoxDecoration(
          color: Theme.of(context).scaffoldBackgroundColor,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
          border: Border.all(color: AppColors.border(context)),
        ),
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(ctx2).viewInsets.bottom + 32,
          left: 24, right: 24, top: 24,
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
              items: _priorityItems(),
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
              ..._members.map((m) => DropdownMenuItem(
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
                'assignee_id': assigneeId,
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
                _load();
              } catch (e) {
                debugPrint('Task insert error: $e');
                setState(() => _tasks[col]!.removeWhere((t) => t['id'] == optimistic['id']));
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
        ? const KanbanShimmer()
        : ListView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.all(16),
            children: KanbanCol.values.map((col) => _KanbanColumn(
              col: col,
              tasks: _tasks[col]!,
              onDrop: (task) => _moveTask(task, col),
              onDelete: _deleteTask,
              onTap: _openTaskDetail,
            )).toList(),
          ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// My Tasks Screen — tasks assigned to me across all groups
// ─────────────────────────────────────────────────────────────────────────────
class MyTasksKanbanScreen extends ConsumerStatefulWidget {
  const MyTasksKanbanScreen({super.key});
  @override
  ConsumerState<MyTasksKanbanScreen> createState() => _MyTasksKanbanScreenState();
}

class _MyTasksKanbanScreenState extends ConsumerState<MyTasksKanbanScreen> {
  final _supabase = Supabase.instance.client;
  Map<KanbanCol, List<Map<String, dynamic>>> _tasks = {
    for (final c in KanbanCol.values) c: []
  };
  // groupId → groupName cache
  Map<String, String> _groupNames = {};
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final userId = _supabase.auth.currentUser?.id;
      if (userId == null) { setState(() => _loading = false); return; }

      // Tasks assigned to me OR created by me as personal
      final data = await _supabase
          .from('kanban_tasks')
          .select('id, title, description, status, priority, due_date, user_id, assignee_id, group_id, position, is_personal')
          .or('assignee_id.eq.$userId,and(user_id.eq.$userId,is_personal.eq.true)')
          .order('created_at');

      // Load group names for all group_ids found
      final groupIds = (data as List)
          .map((t) => t['group_id'] as String?)
          .whereType<String>()
          .toSet()
          .toList();

      if (groupIds.isNotEmpty) {
        try {
          final groups = await _supabase
              .from('groups')
              .select('id, name')
              .inFilter('id', groupIds);
          final names = <String, String>{};
          for (final g in groups as List) {
            names[g['id'] as String] = g['name'] as String? ?? 'Group';
          }
          _groupNames = names;
        } catch (_) {}
      }

      final grouped = {for (final c in KanbanCol.values) c: <Map<String, dynamic>>[]};
      for (final task in List<Map<String, dynamic>>.from(data)) {
        final col = KanbanCol.values.firstWhere(
          (c) => c.name == task['status'], orElse: () => KanbanCol.todo);
        grouped[col]!.add({
          ...task,
          '_group_name': _groupNames[task['group_id']] ?? (task['is_personal'] == true ? 'Personal' : 'Group'),
        });
      }
      if (mounted) setState(() { _tasks = grouped; _loading = false; });
    } catch (e) {
      debugPrint('MyTasks _load error: $e');
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _editTask(Map<String, dynamic> task, Map<String, dynamic> updates) async {
    final taskId = task['id'] as String?;
    if (taskId == null) return;

    final oldStatus = task['status'] as String? ?? 'todo';
    final newStatus = updates['status'] as String? ?? oldStatus;
    final oldCol = KanbanCol.values.firstWhere((c) => c.name == oldStatus, orElse: () => KanbanCol.todo);
    final newCol = KanbanCol.values.firstWhere((c) => c.name == newStatus, orElse: () => KanbanCol.todo);

    setState(() {
      _tasks[oldCol]!.removeWhere((t) => t['id'] == taskId);
      _tasks[newCol]!.add({...task, ...updates});
    });

    try {
      await _supabase.from('kanban_tasks').update(updates).eq('id', taskId);
      await _load();
    } catch (e) {
      _load();
    }
  }

  void _openTaskDetail(Map<String, dynamic> task) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _TaskDetailSheet(
        task: task,
        members: const [],
        onSave: (updates) => _editTask(task, updates),
        onDelete: null, // read-only delete in my tasks view
      ),
    );
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
          const Text('My Tasks', style: TextStyle(fontWeight: FontWeight.w700)),
          Text('$done/$total completed', style: TextStyle(fontSize: 12, color: cs.outline)),
        ]),
        backgroundColor: cs.surface,
        elevation: 0,
        actions: [
          IconButton(icon: const Icon(Icons.refresh_outlined), onPressed: _load),
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
      body: _loading
        ? const KanbanShimmer()
        : total == 0
          ? Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
              Icon(Icons.checklist_rtl_outlined, size: 56, color: cs.primary.withOpacity(0.3)),
              const SizedBox(height: 16),
              Text('No tasks assigned to you', style: TextStyle(color: cs.outline, fontSize: 15)),
              const SizedBox(height: 6),
              Text('Tasks assigned to you across groups will appear here.',
                style: TextStyle(color: cs.outline.withOpacity(0.6), fontSize: 12),
                textAlign: TextAlign.center),
            ]))
          : ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.all(16),
              children: KanbanCol.values.map<Widget>((col) => _KanbanColumn(
                col: col,
                tasks: _tasks[col]!,
                onDrop: (task) => _editTask(task, {'status': col.name}),
                onTap: _openTaskDetail,
              )).toList(),
            ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Task Detail / Edit Sheet
// ─────────────────────────────────────────────────────────────────────────────
class _TaskDetailSheet extends StatefulWidget {
  final Map<String, dynamic> task;
  final List<dynamic> members;
  final Future<void> Function(Map<String, dynamic> updates) onSave;
  final VoidCallback? onDelete;

  const _TaskDetailSheet({
    required this.task,
    required this.members,
    required this.onSave,
    this.onDelete,
  });

  @override
  State<_TaskDetailSheet> createState() => _TaskDetailSheetState();
}

class _TaskDetailSheetState extends State<_TaskDetailSheet> {
  bool _editing = false;
  bool _saving = false;
  late TextEditingController _titleCtrl;
  late TextEditingController _descCtrl;
  late String _priority;
  late String _status;
  late String? _assigneeId;
  DateTime? _dueDate;

  static const _priorityColors = {
    'low': Color(0xFF10B981),
    'medium': Color(0xFF6366F1),
    'high': Color(0xFFF59E0B),
    'critical': Color(0xFFEF4444),
  };

  @override
  void initState() {
    super.initState();
    final t = widget.task;
    _titleCtrl = TextEditingController(text: t['title'] as String? ?? '');
    _descCtrl = TextEditingController(text: t['description'] as String? ?? '');
    _priority = t['priority'] as String? ?? 'medium';
    _status = t['status'] as String? ?? 'todo';
    _assigneeId = t['assignee_id'] as String?;
    final due = t['due_date'];
    if (due != null) {
      try { _dueDate = DateTime.parse(due.toString()); } catch (_) {}
    }
  }

  @override
  void dispose() {
    _titleCtrl.dispose();
    _descCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_titleCtrl.text.trim().isEmpty) return;
    setState(() => _saving = true);
    final updates = <String, dynamic>{
      'title': _titleCtrl.text.trim(),
      'description': _descCtrl.text.trim().isEmpty ? null : _descCtrl.text.trim(),
      'priority': _priority,
      'status': _status,
      'assignee_id': _assigneeId,
      'due_date': _dueDate?.toIso8601String().split('T')[0],
    };
    await widget.onSave(updates);
    if (mounted) Navigator.pop(context);
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _dueDate ?? DateTime.now(),
      firstDate: DateTime.now().subtract(const Duration(days: 30)),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (picked != null) setState(() => _dueDate = picked);
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final priority = _priority;
    final priorityColor = _priorityColors[priority] ?? cs.primary;
    final groupName = widget.task['_group_name'] as String?;

    return Container(
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
      ),
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
        left: 20, right: 20, top: 8,
      ),
      child: SingleChildScrollView(
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          // Handle bar
          Center(
            child: Container(
              width: 36, height: 4,
              margin: const EdgeInsets.only(bottom: 20),
              decoration: BoxDecoration(
                color: cs.outline.withOpacity(0.3),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),

          // Header row — title + edit/close toggle
          Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Expanded(
              child: _editing
                ? TextField(
                    controller: _titleCtrl,
                    autofocus: true,
                    style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 18),
                    decoration: const InputDecoration(
                      hintText: 'Task title',
                      border: InputBorder.none,
                      contentPadding: EdgeInsets.zero,
                    ),
                  )
                : Text(
                    widget.task['title'] as String? ?? '',
                    style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 18),
                  ),
            ),
            // Edit / Done toggle
            IconButton(
              icon: Icon(_editing ? Icons.edit_off_outlined : Icons.edit_outlined, color: cs.primary),
              tooltip: _editing ? 'Stop editing' : 'Edit task',
              onPressed: () => setState(() => _editing = !_editing),
            ),
            if (widget.onDelete != null)
              IconButton(
                icon: Icon(Icons.delete_outline, color: cs.error),
                tooltip: 'Delete task',
                onPressed: () {
                  Navigator.pop(context);
                  widget.onDelete!();
                },
              ),
          ]),

          // Group badge (My Tasks view)
          if (groupName != null) ...[
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              margin: const EdgeInsets.only(bottom: 12),
              decoration: BoxDecoration(
                color: cs.primaryContainer,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                Icon(Icons.people_outline, size: 11, color: cs.onPrimaryContainer),
                const SizedBox(width: 4),
                Text(groupName, style: TextStyle(fontSize: 11, color: cs.onPrimaryContainer, fontWeight: FontWeight.w700)),
              ]),
            ),
          ],

          // Priority badge (view mode)
          if (!_editing) ...[
            const SizedBox(height: 6),
            Row(children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: priorityColor.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  Container(width: 7, height: 7,
                    margin: const EdgeInsets.only(right: 5),
                    decoration: BoxDecoration(color: priorityColor, shape: BoxShape.circle)),
                  Text(
                    priority[0].toUpperCase() + priority.substring(1),
                    style: TextStyle(fontSize: 11, color: priorityColor, fontWeight: FontWeight.w700),
                  ),
                ]),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: cs.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(_status[0].toUpperCase() + _status.substring(1),
                  style: TextStyle(fontSize: 11, color: cs.onSurface, fontWeight: FontWeight.w600)),
              ),
              if (_dueDate != null) ...[
                const SizedBox(width: 8),
                Icon(Icons.calendar_today_outlined, size: 12, color: cs.outline),
                const SizedBox(width: 3),
                Text(_dueDate!.toIso8601String().split('T')[0],
                  style: TextStyle(fontSize: 11, color: cs.outline)),
              ],
            ]),
          ],

          const SizedBox(height: 16),

          // Description
          if (!_editing && (widget.task['description'] as String?)?.isNotEmpty == true) ...[
            Text('Description', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12, color: cs.outline)),
            const SizedBox(height: 6),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: cs.surfaceContainerHighest.withOpacity(0.5),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(widget.task['description'] as String,
                style: TextStyle(fontSize: 14, color: cs.onSurface, height: 1.5)),
            ),
            const SizedBox(height: 16),
          ],

          // ── EDIT MODE FIELDS ──────────────────────────────────────────────
          if (_editing) ...[
            TextField(
              controller: _descCtrl, maxLines: 3,
              decoration: const InputDecoration(
                labelText: 'Description',
                prefixIcon: Icon(Icons.notes_outlined),
                alignLabelWithHint: true,
              ),
            ),
            const SizedBox(height: 12),

            Row(children: [
              Expanded(child: DropdownButtonFormField<String>(
                value: _priority,
                decoration: const InputDecoration(labelText: 'Priority', isDense: true),
                items: _priorityItems(),
                onChanged: (v) => setState(() => _priority = v!),
              )),
              const SizedBox(width: 12),
              Expanded(child: DropdownButtonFormField<String>(
                value: _status,
                decoration: const InputDecoration(labelText: 'Status', isDense: true),
                items: KanbanCol.values.map((c) => DropdownMenuItem(
                  value: c.name,
                  child: Text(c.name[0].toUpperCase() + c.name.substring(1)),
                )).toList(),
                onChanged: (v) => setState(() => _status = v!),
              )),
            ]),
            const SizedBox(height: 12),

            // Assignee — only shown when we have members
            if (widget.members.isNotEmpty)
              DropdownButtonFormField<String?>(
                value: _assigneeId,
                decoration: const InputDecoration(labelText: 'Assignee', prefixIcon: Icon(Icons.person_outline), isDense: true),
                items: [
                  const DropdownMenuItem(value: null, child: Text('Unassigned')),
                  ...widget.members.map((m) => DropdownMenuItem(
                    value: m['profile_id'] as String,
                    child: Text(m['profiles']['display_name'] ?? 'User'),
                  )),
                ],
                onChanged: (v) => setState(() => _assigneeId = v),
              )
            else
              // Assignee display-only when no members loaded
              InkWell(
                onTap: () {},
                borderRadius: BorderRadius.circular(8),
                child: InputDecorator(
                  decoration: const InputDecoration(labelText: 'Assignee', prefixIcon: Icon(Icons.person_outline), isDense: true),
                  child: Text(_assigneeId != null ? 'Assigned' : 'Unassigned',
                    style: TextStyle(color: cs.outline)),
                ),
              ),
            const SizedBox(height: 12),

            // Due date picker
            InkWell(
              onTap: _pickDate,
              borderRadius: BorderRadius.circular(12),
              child: InputDecorator(
                decoration: const InputDecoration(
                  labelText: 'Due Date',
                  prefixIcon: Icon(Icons.calendar_today_outlined),
                  isDense: true,
                  suffixIcon: Icon(Icons.edit_calendar_outlined),
                ),
                child: Text(
                  _dueDate != null
                    ? _dueDate!.toIso8601String().split('T')[0]
                    : 'No due date',
                  style: TextStyle(color: _dueDate != null ? cs.onSurface : cs.outline),
                ),
              ),
            ),
            const SizedBox(height: 20),

            Row(children: [
              if (_dueDate != null)
                TextButton.icon(
                  onPressed: () => setState(() => _dueDate = null),
                  icon: const Icon(Icons.clear, size: 16),
                  label: const Text('Clear date'),
                ),
              const Spacer(),
              FilledButton.icon(
                onPressed: _saving ? null : _save,
                icon: _saving
                  ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : const Icon(Icons.save_outlined),
                label: Text(_saving ? 'Saving…' : 'Save Changes'),
                style: FilledButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12)),
              ),
            ]),
          ],

          // Assignee info — view mode
          if (!_editing) ...[
            if (widget.task['assignee_id'] != null) ...[
              Row(children: [
                Icon(Icons.person_pin_outlined, size: 14, color: cs.outline),
                const SizedBox(width: 6),
                Text('Assigned', style: TextStyle(fontSize: 12, color: cs.outline)),
              ]),
              const SizedBox(height: 8),
            ],
            Center(
              child: TextButton.icon(
                onPressed: () => setState(() => _editing = true),
                icon: const Icon(Icons.edit_outlined, size: 16),
                label: const Text('Edit Task'),
              ),
            ),
          ],
        ]),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Shared priority dropdown items helper
// ─────────────────────────────────────────────────────────────────────────────
List<DropdownMenuItem<String>> _priorityItems() => [
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
];

// ─────────────────────────────────────────────────────────────────────────────
// Column
// ─────────────────────────────────────────────────────────────────────────────
class _KanbanColumn extends StatelessWidget {
  final KanbanCol col;
  final List<Map<String, dynamic>> tasks;
  final void Function(Map<String, dynamic>) onDrop;
  final void Function(Map<String, dynamic>)? onDelete;
  final void Function(Map<String, dynamic>) onTap;
  final bool showGroupBadge;

  const _KanbanColumn({
    required this.col,
    required this.tasks,
    required this.onDrop,
    required this.onTap,
    this.onDelete,
    this.showGroupBadge = false,
  });

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
                        child: _TaskCard(
                          task: tasks[i],
                          dragging: true,
                          onDelete: null,
                          onTap: () {},
                          showGroupBadge: showGroupBadge,
                        ),
                      ),
                    ),
                    childWhenDragging: Opacity(
                      opacity: 0.25,
                      child: _TaskCard(
                        task: tasks[i],
                        onDelete: null,
                        onTap: () {},
                        showGroupBadge: showGroupBadge,
                      ),
                    ),
                    child: _TaskCard(
                      task: tasks[i],
                      onDelete: onDelete != null ? () => onDelete!(tasks[i]) : null,
                      onTap: () => onTap(tasks[i]),
                      showGroupBadge: showGroupBadge,
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
  final VoidCallback? onDelete;
  final VoidCallback onTap;
  final bool showGroupBadge;

  const _TaskCard({
    required this.task,
    this.dragging = false,
    required this.onDelete,
    required this.onTap,
    this.showGroupBadge = false,
  });

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

  Widget _buildCard(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final priority = task['priority'] as String? ?? 'medium';
    final color = _priorityColors[priority] ?? cs.primary;
    final icon = _priorityIcons[priority] ?? Icons.remove;
    final groupName = task['_group_name'] as String?;

    return InkWell(
      onTap: dragging ? null : onTap,
      borderRadius: BorderRadius.circular(14),
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
            // Group badge (My Tasks view)
            if (showGroupBadge && groupName != null) ...[
              const SizedBox(height: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: cs.primaryContainer.withOpacity(0.6),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  Icon(Icons.people_outline, size: 9, color: cs.onPrimaryContainer),
                  const SizedBox(width: 3),
                  Text(groupName,
                    style: TextStyle(fontSize: 9, color: cs.onPrimaryContainer, fontWeight: FontWeight.w700)),
                ]),
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
              if (!dragging)
                Icon(Icons.touch_app_outlined, size: 12, color: cs.outline.withOpacity(0.35)),
            ]),
          ]),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (onDelete == null || dragging) return _buildCard(context);

    return Dismissible(
      key: Key('${task['id']}_card'),
      direction: DismissDirection.endToStart,
      onDismissed: (_) => onDelete!(),
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 16),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.errorContainer,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Icon(Icons.delete_outline, color: Theme.of(context).colorScheme.error),
      ),
      child: _buildCard(context),
    );
  }
}
