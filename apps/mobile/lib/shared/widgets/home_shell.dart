import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../features/hub/hub_provider.dart';

class HomeShell extends ConsumerWidget {
  final Widget child;
  const HomeShell({super.key, required this.child});

  static const _tabs = [
    (icon: Icons.calendar_view_week_outlined, activeIcon: Icons.calendar_view_week, label: 'Timetable', path: '/home'),
    (icon: Icons.people_outline, activeIcon: Icons.people, label: 'Groups', path: '/groups'),
    (icon: Icons.calendar_month_outlined, activeIcon: Icons.calendar_month, label: 'Calendar', path: '/calendar'),
    (icon: Icons.wallet_outlined, activeIcon: Icons.wallet, label: 'Expenses', path: '/expenses'),
    (icon: Icons.psychology_outlined, activeIcon: Icons.psychology, label: 'Flow', path: '/flow'),
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final location = GoRouterState.of(context).uri.path;
    int currentIndex = _tabs.indexWhere((t) => location.startsWith(t.path));
    if (currentIndex < 0) currentIndex = 0;
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      body: child,
      bottomNavigationBar: NavigationBar(
        selectedIndex: currentIndex,
        onDestinationSelected: (i) {
          HapticFeedback.selectionClick();
          context.go(_tabs[i].path);
        },
        animationDuration: const Duration(milliseconds: 300),
        backgroundColor: cs.surface,
        indicatorColor: cs.primaryContainer,
        elevation: 0,
        destinations: _tabs.map((t) => NavigationDestination(
          icon: Icon(t.icon),
          selectedIcon: Icon(t.activeIcon, color: cs.onPrimaryContainer),
          label: t.label,
        )).toList(),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Groups Screen
// ─────────────────────────────────────────────────────────────────────────────
class GroupsScreen extends ConsumerStatefulWidget {
  const GroupsScreen({super.key});
  @override
  ConsumerState<GroupsScreen> createState() => _GroupsScreenState();
}

class _GroupsScreenState extends ConsumerState<GroupsScreen> {
  @override
  Widget build(BuildContext context) {
    final groupsAsync = ref.watch(groupsProvider);
    final hubState = ref.watch(hubProvider);
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      backgroundColor: cs.surface,
      appBar: AppBar(
        title: const Text('Study Squads'),
        actions: [
          if (hubState.isLoading)
            const Padding(
              padding: EdgeInsets.only(right: 16),
              child: SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)),
            ),
          IconButton(
            icon: const Icon(Icons.refresh_outlined),
            onPressed: () => ref.invalidate(groupsProvider),
          ),
        ],
      ),
      body: groupsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => _ErrorState(
          message: e.toString(),
          onRetry: () => ref.invalidate(groupsProvider),
        ),
        data: (groups) {
          if (groups.isEmpty) return _EmptyState(
            onCreate: () => _showCreateSheet(context),
            onJoin: () => _showJoinSheet(context),
          );
          return RefreshIndicator(
            onRefresh: () async => ref.invalidate(groupsProvider),
            child: ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: groups.length,
              separatorBuilder: (_, __) => const SizedBox(height: 10),
              itemBuilder: (ctx, i) {
                final g = groups[i] as Map<String, dynamic>;
                return _GroupCard(group: g);
              },
            ),
          );
        },
      ),
      floatingActionButton: Column(mainAxisSize: MainAxisSize.min, children: [
        FloatingActionButton.small(
          heroTag: 'join_fab',
          onPressed: () => _showJoinSheet(context),
          tooltip: 'Join via code',
          backgroundColor: cs.secondaryContainer,
          foregroundColor: cs.onSecondaryContainer,
          child: const Icon(Icons.qr_code_scanner_outlined),
        ),
        const SizedBox(height: 10),
        FloatingActionButton.extended(
          heroTag: 'create_fab',
          onPressed: () => _showCreateSheet(context),
          icon: const Icon(Icons.group_add_outlined),
          label: const Text('New Squad'),
        ),
      ]),
    );
  }

  void _showCreateSheet(BuildContext ctx) {
    final nameCtrl = TextEditingController();
    final descCtrl = TextEditingController();
    final cs = Theme.of(ctx).colorScheme;

    showModalBottomSheet(
      context: ctx,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetCtx) => Container(
        decoration: BoxDecoration(
          color: cs.surface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        ),
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(sheetCtx).viewInsets.bottom + 20,
          left: 20, right: 20, top: 20,
        ),
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(color: cs.primaryContainer, borderRadius: BorderRadius.circular(12)),
              child: Icon(Icons.group_add_outlined, color: cs.onPrimaryContainer),
            ),
            const SizedBox(width: 12),
            Text('Create Study Squad', style: Theme.of(ctx).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700)),
          ]),
          const SizedBox(height: 20),
          TextField(
            controller: nameCtrl,
            autofocus: true,
            decoration: const InputDecoration(
              labelText: 'Squad name *',
              prefixIcon: Icon(Icons.people_outline),
              hintText: 'e.g. OS Study Group, DBMS Warriors',
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: descCtrl,
            decoration: const InputDecoration(
              labelText: 'Description (optional)',
              prefixIcon: Icon(Icons.notes_outlined),
            ),
          ),
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: () async {
                final name = nameCtrl.text.trim();
                if (name.isEmpty) return;
                Navigator.pop(sheetCtx);
                await ref.read(hubProvider.notifier).createGroup(name, descCtrl.text.trim().isEmpty ? null : descCtrl.text.trim());
                ref.invalidate(groupsProvider);
                if (mounted) {
                  final err = ref.read(hubProvider).error;
                  if (err != null && ctx.mounted) {
                    ScaffoldMessenger.of(ctx).showSnackBar(
                      SnackBar(content: Text('Error: $err'), backgroundColor: cs.error),
                    );
                  } else if (ctx.mounted) {
                    ScaffoldMessenger.of(ctx).showSnackBar(
                      const SnackBar(content: Text('Squad created! ✅')),
                    );
                  }
                }
              },
              icon: const Icon(Icons.add),
              label: const Text('Create Squad'),
              style: FilledButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 14)),
            ),
          ),
        ]),
      ),
    );
  }

  void _showJoinSheet(BuildContext ctx) {
    final codeCtrl = TextEditingController();
    final cs = Theme.of(ctx).colorScheme;

    showModalBottomSheet(
      context: ctx,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetCtx) => Container(
        decoration: BoxDecoration(
          color: cs.surface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        ),
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(sheetCtx).viewInsets.bottom + 20,
          left: 20, right: 20, top: 20,
        ),
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(color: cs.secondaryContainer, borderRadius: BorderRadius.circular(12)),
              child: Icon(Icons.qr_code_scanner_outlined, color: cs.onSecondaryContainer),
            ),
            const SizedBox(width: 12),
            Text('Join a Squad', style: Theme.of(ctx).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700)),
          ]),
          const SizedBox(height: 8),
          Text('Ask your squad leader for the 8-character invite code.',
            style: TextStyle(color: cs.outline, fontSize: 13)),
          const SizedBox(height: 20),
          TextField(
            controller: codeCtrl,
            autofocus: true,
            maxLength: 8,
            textCapitalization: TextCapitalization.characters,
            decoration: const InputDecoration(
              labelText: 'Invite Code',
              prefixIcon: Icon(Icons.vpn_key_outlined),
              hintText: 'e.g. ABC12345',
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: () async {
                final code = codeCtrl.text.trim();
                if (code.length != 8) return;
                Navigator.pop(sheetCtx);
                await ref.read(hubProvider.notifier).joinGroup(code);
                ref.invalidate(groupsProvider);
                if (mounted && ctx.mounted) {
                  final err = ref.read(hubProvider).error;
                  if (err != null) {
                    ScaffoldMessenger.of(ctx).showSnackBar(
                      SnackBar(content: Text('$err'), backgroundColor: cs.error),
                    );
                  } else {
                    ScaffoldMessenger.of(ctx).showSnackBar(
                      const SnackBar(content: Text('Joined squad! 🎉')),
                    );
                  }
                }
              },
              icon: const Icon(Icons.login),
              label: const Text('Join Squad'),
              style: FilledButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 14)),
            ),
          ),
        ]),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Group Card
// ─────────────────────────────────────────────────────────────────────────────
class _GroupCard extends ConsumerWidget {
  final Map<String, dynamic> group;
  const _GroupCard({required this.group});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cs = Theme.of(context).colorScheme;
    final name = group['name'] as String? ?? 'Unnamed';
    final desc = group['description'] as String?;
    final role = group['role'] as String? ?? 'member';
    final inviteCode = group['inviteCode'] as String? ?? '';
    final gId = group['id'] as String;

    final hue = name.codeUnits.fold(0, (a, b) => a + b) % 360;
    final avatarColor = HSLColor.fromAHSL(1, hue.toDouble(), 0.6, 0.45).toColor();

    return Card(
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      elevation: 0,
      child: InkWell(
        onTap: () => context.push('/hub/$gId'),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(children: [
            // Avatar
            Container(
              width: 50, height: 50,
              decoration: BoxDecoration(
                color: avatarColor,
                borderRadius: BorderRadius.circular(14),
              ),
              child: Center(
                child: Text(name[0].toUpperCase(),
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 22)),
              ),
            ),
            const SizedBox(width: 14),
            // Info
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Expanded(child: Text(name, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16))),
                if (role == 'admin')
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: cs.primaryContainer, borderRadius: BorderRadius.circular(6)),
                    child: Text('Admin', style: TextStyle(fontSize: 10, color: cs.onPrimaryContainer, fontWeight: FontWeight.w700)),
                  ),
              ]),
              if (desc != null) ...[
                const SizedBox(height: 2),
                Text(desc, maxLines: 1, overflow: TextOverflow.ellipsis,
                  style: TextStyle(color: cs.outline, fontSize: 13)),
              ],
              if (inviteCode.isNotEmpty) ...[
                const SizedBox(height: 6),
                GestureDetector(
                  onTap: () {
                    Clipboard.setData(ClipboardData(text: inviteCode));
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Invite code copied!'), duration: Duration(seconds: 2)),
                    );
                  },
                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                    Icon(Icons.copy_outlined, size: 12, color: cs.primary),
                    const SizedBox(width: 4),
                    Text(inviteCode, style: TextStyle(fontSize: 12, color: cs.primary, fontWeight: FontWeight.w600, letterSpacing: 1)),
                  ]),
                ),
              ],
            ])),
            // Actions
            PopupMenuButton<String>(
              icon: Icon(Icons.more_vert, color: cs.outline),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              onSelected: (val) {
                if (val == 'chat') context.push('/hub/$gId');
                if (val == 'whiteboard') context.go('/whiteboard/$gId');
              },
              itemBuilder: (_) => const [
                PopupMenuItem(value: 'chat',
                  child: ListTile(leading: Icon(Icons.chat_outlined), title: Text('Open Chat'), dense: true)),
                PopupMenuItem(value: 'whiteboard',
                  child: ListTile(leading: Icon(Icons.draw_outlined), title: Text('Whiteboard'), dense: true)),
              ],
            ),
          ]),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Empty + Error states
// ─────────────────────────────────────────────────────────────────────────────
class _EmptyState extends StatelessWidget {
  final VoidCallback onCreate;
  final VoidCallback onJoin;
  const _EmptyState({required this.onCreate, required this.onJoin});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Center(child: Padding(
      padding: const EdgeInsets.all(32),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: cs.primaryContainer.withOpacity(0.3),
            shape: BoxShape.circle,
          ),
          child: Icon(Icons.people_outline, size: 56, color: cs.primary),
        ),
        const SizedBox(height: 20),
        Text('No squads yet', style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w700)),
        const SizedBox(height: 8),
        Text('Create a study squad or join one with an invite code.',
          textAlign: TextAlign.center, style: TextStyle(color: cs.outline, fontSize: 15)),
        const SizedBox(height: 28),
        Row(children: [
          Expanded(child: OutlinedButton.icon(
            onPressed: onJoin,
            icon: const Icon(Icons.qr_code_scanner_outlined),
            label: const Text('Join Squad'),
            style: OutlinedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 14)),
          )),
          const SizedBox(width: 12),
          Expanded(child: FilledButton.icon(
            onPressed: onCreate,
            icon: const Icon(Icons.group_add_outlined),
            label: const Text('Create'),
            style: FilledButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 14)),
          )),
        ]),
      ]),
    ));
  }
}

class _ErrorState extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;
  const _ErrorState({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Center(child: Padding(
      padding: const EdgeInsets.all(32),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Icon(Icons.wifi_off_outlined, size: 56, color: cs.error),
        const SizedBox(height: 16),
        Text('Could not load groups', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
        const SizedBox(height: 8),
        Text('Make sure you\'re signed in and the backend is running.',
          textAlign: TextAlign.center, style: TextStyle(color: cs.outline)),
        const SizedBox(height: 20),
        FilledButton.icon(onPressed: onRetry, icon: const Icon(Icons.refresh), label: const Text('Retry')),
      ]),
    ));
  }
}
