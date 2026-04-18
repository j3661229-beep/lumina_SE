import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/theme/design_tokens.dart';
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
    (icon: Icons.auto_stories_outlined, activeIcon: Icons.auto_stories, label: 'Notes', path: '/rag'),
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final location = GoRouterState.of(context).uri.path;
    int currentIndex = _tabs.indexWhere((t) => location.startsWith(t.path));
    if (currentIndex < 0) currentIndex = 0;

    return Scaffold(
      backgroundColor: DesignColor.bg,
      body: Stack(
        children: [
          // Ambient glow orbs — from lumina_ui.jsx
          Positioned(
            top: -120, left: -80,
            child: _GlowOrb(size: 450, color: DesignColor.indigo, opacity: 0.18, durationSec: 5),
          ),
          Positioned(
            bottom: 60, right: -100,
            child: _GlowOrb(size: 350, color: DesignColor.cyan, opacity: 0.12, durationSec: 7),
          ),
          Positioned(
            left: -300, right: -300,
            top: 0, bottom: 0,
            child: Center(
              child: _GlowOrb(size: 600, color: DesignColor.violet, opacity: 0.06, durationSec: 9),
            ),
          ),
          child,
        ],
      ),
      bottomNavigationBar: _LuminaBottomNav(
        currentIndex: currentIndex,
        onTap: (i) {
          HapticFeedback.selectionClick();
          context.go(_tabs[i].path);
        },
        tabs: _tabs,
      ),
    );
  }
}

// ── Animated breathing glow orb ──────────────────────────────────────────────
class _GlowOrb extends StatefulWidget {
  final double size, opacity;
  final Color color;
  final int durationSec;
  const _GlowOrb({required this.size, required this.color, required this.opacity, required this.durationSec});
  @override
  State<_GlowOrb> createState() => _GlowOrbState();
}

class _GlowOrbState extends State<_GlowOrb> with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _anim;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: Duration(seconds: widget.durationSec))
      ..repeat(reverse: true);
    _anim = Tween<double>(begin: 0.85, end: 1.1)
        .animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut));
  }

  @override
  void dispose() { _ctrl.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) =>
    AnimatedBuilder(
      animation: _anim,
      builder: (_, __) => Transform.scale(
        scale: _anim.value,
        child: Container(
          width: widget.size,
          height: widget.size,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: RadialGradient(colors: [
              widget.color.withOpacity(widget.opacity),
              Colors.transparent,
            ]),
          ),
        ),
      ),
    );
}

// ── Lumina custom bottom nav bar ─────────────────────────────────────────────
class _LuminaBottomNav extends StatelessWidget {
  final int currentIndex;
  final ValueChanged<int> onTap;
  final List<({IconData icon, IconData activeIcon, String label, String path})> tabs;

  const _LuminaBottomNav({
    required this.currentIndex,
    required this.onTap,
    required this.tabs,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: DesignColor.overlay,
        border: const Border(top: BorderSide(color: DesignColor.border)),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
          child: Row(
            children: List.generate(tabs.length, (i) {
              final sel = currentIndex == i;
              return Expanded(
                child: GestureDetector(
                  onTap: () => onTap(i),
                  behavior: HitTestBehavior.opaque,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 6),
                    child: Column(mainAxisSize: MainAxisSize.min, children: [
                      Stack(alignment: Alignment.center, children: [
                        // Glow halo
                        AnimatedContainer(
                          duration: const Duration(milliseconds: 250),
                          curve: Curves.easeOut,
                          width: sel ? 38 : 0,
                          height: sel ? 38 : 0,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: sel ? DesignColor.indigoGlow : Colors.transparent,
                          ),
                        ),
                        // Icon
                        AnimatedScale(
                          scale: sel ? 1.15 : 1.0,
                          duration: const Duration(milliseconds: 200),
                          child: Icon(
                            sel ? tabs[i].activeIcon : tabs[i].icon,
                            size: 21,
                            color: sel ? DesignColor.indigo : DesignColor.muted,
                          ),
                        ),
                      ]),
                      const SizedBox(height: 4),
                      AnimatedDefaultTextStyle(
                        duration: const Duration(milliseconds: 200),
                        style: TextStyle(
                          fontSize: 9.5,
                          fontWeight: sel ? FontWeight.w700 : FontWeight.w500,
                          color: sel ? DesignColor.indigo : DesignColor.muted,
                        ),
                        child: Text(tabs[i].label),
                      ),
                    ]),
                  ),
                ),
              );
            }),
          ),
        ),
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

    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        title: const Text('Study Squads'),
        actions: [
          if (hubState.isLoading)
            const Padding(
              padding: EdgeInsets.only(right: 16),
              child: SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: DesignColor.indigo)),
            ),
          IconButton(
            icon: const Icon(Icons.refresh_outlined, color: DesignColor.sub),
            onPressed: () => ref.invalidate(groupsProvider),
          ),
        ],
      ),
      body: groupsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator(color: DesignColor.indigo)),
        error: (e, _) => _ErrorState(message: e.toString(), onRetry: () => ref.invalidate(groupsProvider)),
        data: (groups) {
          if (groups.isEmpty) return _EmptyState(
            onCreate: () => _showCreateSheet(context),
            onJoin: () => _showJoinSheet(context),
          );
          return RefreshIndicator(
            color: DesignColor.indigo,
            backgroundColor: DesignColor.s1,
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
          backgroundColor: DesignColor.s2,
          foregroundColor: DesignColor.sub,
          child: const Icon(Icons.qr_code_scanner_outlined),
        ),
        const SizedBox(height: 10),
        Container(
          decoration: DesignStyles.gradientButton(),
          child: FloatingActionButton.extended(
            heroTag: 'create_fab',
            onPressed: () => _showCreateSheet(context),
            backgroundColor: Colors.transparent,
            elevation: 0,
            icon: const Icon(Icons.group_add_outlined, color: Colors.white),
            label: const Text('New Squad', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
          ),
        ),
      ]),
    );
  }

  void _showCreateSheet(BuildContext ctx) {
    final nameCtrl = TextEditingController();
    final descCtrl = TextEditingController();

    showModalBottomSheet(
      context: ctx,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetCtx) => Container(
        decoration: const BoxDecoration(
          color: Color(0xFF0F1228),
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
          border: Border(top: BorderSide(color: DesignColor.borderH)),
        ),
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(sheetCtx).viewInsets.bottom + 20,
          left: 20, right: 20, top: 20,
        ),
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(color: DesignColor.indigoGlow, borderRadius: BorderRadius.circular(12)),
              child: const Icon(Icons.group_add_outlined, color: DesignColor.indigo),
            ),
            const SizedBox(width: 12),
            Text('Create Study Squad', style: Theme.of(ctx).textTheme.titleLarge),
          ]),
          const SizedBox(height: 20),
          _DarkTextField(controller: nameCtrl, label: 'Squad name *', hint: 'e.g. OS Study Group', icon: Icons.people_outline),
          const SizedBox(height: 12),
          _DarkTextField(controller: descCtrl, label: 'Description (optional)', icon: Icons.notes_outlined),
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            child: Container(
              decoration: DesignStyles.gradientButton(),
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
                      ScaffoldMessenger.of(ctx).showSnackBar(SnackBar(content: Text('Error: $err'), backgroundColor: DesignColor.rose));
                    } else if (ctx.mounted) {
                      ScaffoldMessenger.of(ctx).showSnackBar(const SnackBar(content: Text('Squad created! ✅')));
                    }
                  }
                },
                style: FilledButton.styleFrom(
                  backgroundColor: Colors.transparent,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  foregroundColor: Colors.white,
                  elevation: 0,
                ),
                icon: const Icon(Icons.add),
                label: const Text('Create Squad'),
              ),
            ),
          ),
        ]),
      ),
    );
  }

  void _showJoinSheet(BuildContext ctx) {
    final codeCtrl = TextEditingController();

    showModalBottomSheet(
      context: ctx,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetCtx) => Container(
        decoration: const BoxDecoration(
          color: Color(0xFF0F1228),
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
          border: Border(top: BorderSide(color: DesignColor.borderH)),
        ),
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(sheetCtx).viewInsets.bottom + 20,
          left: 20, right: 20, top: 20,
        ),
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(color: DesignColor.indigoGlow, borderRadius: BorderRadius.circular(12)),
              child: const Icon(Icons.qr_code_scanner_outlined, color: DesignColor.indigo),
            ),
            const SizedBox(width: 12),
            Text('Join a Squad', style: Theme.of(ctx).textTheme.titleLarge),
          ]),
          const SizedBox(height: 8),
          const Text('Ask your squad leader for the 8-character invite code.',
            style: TextStyle(color: DesignColor.sub, fontSize: 13)),
          const SizedBox(height: 20),
          _DarkTextField(
            controller: codeCtrl,
            label: 'Invite Code',
            hint: 'e.g. ABC12345',
            icon: Icons.vpn_key_outlined,
            maxLength: 8,
            textCaps: TextCapitalization.characters,
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: Container(
              decoration: DesignStyles.gradientButton(),
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
                      ScaffoldMessenger.of(ctx).showSnackBar(SnackBar(content: Text('$err'), backgroundColor: DesignColor.rose));
                    } else {
                      ScaffoldMessenger.of(ctx).showSnackBar(const SnackBar(content: Text('Joined squad! 🎉')));
                    }
                  }
                },
                style: FilledButton.styleFrom(
                  backgroundColor: Colors.transparent,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  foregroundColor: Colors.white,
                  elevation: 0,
                ),
                icon: const Icon(Icons.login),
                label: const Text('Join Squad'),
              ),
            ),
          ),
        ]),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Dark-styled text field
// ─────────────────────────────────────────────────────────────────────────────
class _DarkTextField extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  final String? hint;
  final IconData icon;
  final int? maxLength;
  final TextCapitalization textCaps;

  const _DarkTextField({
    required this.controller,
    required this.label,
    required this.icon,
    this.hint,
    this.maxLength,
    this.textCaps = TextCapitalization.none,
  });

  @override
  Widget build(BuildContext context) => TextField(
    controller: controller,
    maxLength: maxLength,
    textCapitalization: textCaps,
    style: const TextStyle(color: DesignColor.text, fontSize: 14),
    decoration: InputDecoration(
      labelText: label,
      hintText: hint,
      labelStyle: const TextStyle(color: DesignColor.sub),
      hintStyle: const TextStyle(color: DesignColor.muted),
      prefixIcon: Icon(icon, color: DesignColor.muted, size: 20),
      filled: true,
      fillColor: DesignColor.s1,
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: DesignColor.border),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: DesignColor.indigo),
      ),
      counterStyle: const TextStyle(color: DesignColor.muted),
    ),
  );
}

// ─────────────────────────────────────────────────────────────────────────────
// Group Card
// ─────────────────────────────────────────────────────────────────────────────
class _GroupCard extends ConsumerWidget {
  final Map<String, dynamic> group;
  const _GroupCard({required this.group});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final name = group['name'] as String? ?? 'Unnamed';
    final desc = group['description'] as String?;
    final role = group['role'] as String? ?? 'member';
    final inviteCode = group['inviteCode'] as String? ?? '';
    final gId = group['id'] as String;

    final hue = name.codeUnits.fold(0, (a, b) => a + b) % 360;
    final avatarColor = HSLColor.fromAHSL(1, hue.toDouble(), 0.65, 0.55).toColor();

    return Container(
      decoration: DesignStyles.glassCard(),
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: () => context.push('/hub/$gId'),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              // Avatar
              Container(
                width: 46, height: 46,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(14),
                  gradient: LinearGradient(
                    colors: [avatarColor, avatarColor.withOpacity(0.6)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  boxShadow: [BoxShadow(color: avatarColor.withOpacity(0.4), blurRadius: 12, offset: const Offset(0, 4))],
                ),
                child: Center(
                  child: Text(name[0].toUpperCase(),
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 19, fontFamily: 'Syne')),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(children: [
                  Expanded(child: Text(name,
                    style: const TextStyle(color: DesignColor.text, fontWeight: FontWeight.w700, fontSize: 15, fontFamily: 'Syne'))),
                  if (role == 'admin')
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: DesignColor.indigoGlow,
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: DesignColor.borderH),
                      ),
                      child: const Text('Admin', style: TextStyle(fontSize: 9, color: DesignColor.indigo, fontWeight: FontWeight.w700)),
                    ),
                ]),
                if (desc != null) ...[
                  const SizedBox(height: 3),
                  Text(desc, maxLines: 1, overflow: TextOverflow.ellipsis,
                    style: const TextStyle(color: DesignColor.sub, fontSize: 12)),
                ],
              ])),
              PopupMenuButton<String>(
                icon: const Icon(Icons.more_vert, color: DesignColor.muted),
                color: const Color(0xFF0F1228),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                  side: const BorderSide(color: DesignColor.border),
                ),
                onSelected: (val) {
                  if (val == 'chat') context.push('/hub/$gId');
                  if (val == 'whiteboard') context.go('/whiteboard/$gId');
                },
                itemBuilder: (_) => const [
                  PopupMenuItem(value: 'chat',
                    child: ListTile(leading: Icon(Icons.chat_outlined, color: DesignColor.sub), title: Text('Open Chat', style: TextStyle(color: DesignColor.text)), dense: true)),
                  PopupMenuItem(value: 'whiteboard',
                    child: ListTile(leading: Icon(Icons.draw_outlined, color: DesignColor.sub), title: Text('Whiteboard', style: TextStyle(color: DesignColor.text)), dense: true)),
                ],
              ),
            ]),
            // Action buttons row
            Padding(
              padding: const EdgeInsets.only(top: 12),
              child: Row(children: [
                Expanded(child: _ActionBtn(icon: Icons.chat_outlined, label: 'Chat', onTap: () => context.push('/hub/$gId'))),
                const SizedBox(width: 7),
                Expanded(child: _ActionBtn(icon: Icons.view_kanban_outlined, label: 'Kanban', onTap: () => context.go('/kanban/$gId'))),
                const SizedBox(width: 7),
                Expanded(child: _ActionBtn(icon: Icons.draw_outlined, label: 'Whiteboard', onTap: () => context.go('/whiteboard/$gId'))),
              ]),
            ),
            if (inviteCode.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 10),
                child: GestureDetector(
                  onTap: () {
                    Clipboard.setData(ClipboardData(text: inviteCode));
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Invite code copied!'), duration: Duration(seconds: 2)));
                  },
                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                    const Icon(Icons.copy_outlined, size: 11, color: DesignColor.indigo),
                    const SizedBox(width: 4),
                    Text(inviteCode, style: const TextStyle(fontSize: 11, color: DesignColor.indigo, fontWeight: FontWeight.w600, letterSpacing: 1.2)),
                  ]),
                ),
              ),
          ]),
        ),
      ),
    );
  }
}

class _ActionBtn extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  const _ActionBtn({required this.icon, required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: Container(
      padding: const EdgeInsets.symmetric(vertical: 7),
      decoration: BoxDecoration(
        color: DesignColor.s1,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: DesignColor.border),
      ),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Icon(icon, size: 14, color: DesignColor.sub),
        const SizedBox(height: 3),
        Text(label, style: const TextStyle(color: DesignColor.sub, fontSize: 9.5, fontWeight: FontWeight.w600)),
      ]),
    ),
  );
}

// ─────────────────────────────────────────────────────────────────────────────
// Empty + Error states
// ─────────────────────────────────────────────────────────────────────────────
class _EmptyState extends StatelessWidget {
  final VoidCallback onCreate;
  final VoidCallback onJoin;
  const _EmptyState({required this.onCreate, required this.onJoin});

  @override
  Widget build(BuildContext context) => Center(child: Padding(
    padding: const EdgeInsets.all(32),
    child: Column(mainAxisSize: MainAxisSize.min, children: [
      Container(
        padding: const EdgeInsets.all(24),
        decoration: const BoxDecoration(color: DesignColor.indigoGlow, shape: BoxShape.circle),
        child: const Icon(Icons.people_outline, size: 54, color: DesignColor.indigo),
      ),
      const SizedBox(height: 20),
      Text('No squads yet', style: Theme.of(context).textTheme.headlineSmall),
      const SizedBox(height: 8),
      const Text('Create a study squad or join one with an invite code.',
        textAlign: TextAlign.center, style: TextStyle(color: DesignColor.sub, fontSize: 14)),
      const SizedBox(height: 28),
      Row(children: [
        Expanded(child: OutlinedButton.icon(
          onPressed: onJoin,
          icon: const Icon(Icons.qr_code_scanner_outlined),
          label: const Text('Join'),
          style: OutlinedButton.styleFrom(
            foregroundColor: DesignColor.indigo,
            side: const BorderSide(color: DesignColor.borderH),
            padding: const EdgeInsets.symmetric(vertical: 14),
          ),
        )),
        const SizedBox(width: 12),
        Expanded(child: Container(
          decoration: DesignStyles.gradientButton(),
          child: FilledButton.icon(
            onPressed: onCreate,
            style: FilledButton.styleFrom(
              backgroundColor: Colors.transparent,
              foregroundColor: Colors.white,
              elevation: 0,
              padding: const EdgeInsets.symmetric(vertical: 14),
            ),
            icon: const Icon(Icons.group_add_outlined),
            label: const Text('Create'),
          ),
        )),
      ]),
    ]),
  ));
}

class _ErrorState extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;
  const _ErrorState({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) => Center(child: Padding(
    padding: const EdgeInsets.all(32),
    child: Column(mainAxisSize: MainAxisSize.min, children: [
      const Icon(Icons.wifi_off_outlined, size: 56, color: DesignColor.rose),
      const SizedBox(height: 16),
      Text('Could not load groups', style: Theme.of(context).textTheme.titleMedium),
      const SizedBox(height: 8),
      const Text('Make sure you\'re signed in and the backend is running.',
        textAlign: TextAlign.center, style: TextStyle(color: DesignColor.sub)),
      const SizedBox(height: 20),
      Container(
        decoration: DesignStyles.gradientButton(),
        child: FilledButton.icon(
          onPressed: onRetry,
          style: FilledButton.styleFrom(
            backgroundColor: Colors.transparent,
            foregroundColor: Colors.white,
            elevation: 0,
          ),
          icon: const Icon(Icons.refresh),
          label: const Text('Retry'),
        ),
      ),
    ]),
  ));
}
