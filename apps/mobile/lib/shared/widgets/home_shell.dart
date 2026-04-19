import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/theme/design_tokens.dart';
import '../../features/hub/hub_provider.dart';
import 'shimmer_widgets.dart';

class HomeShell extends ConsumerWidget {
  final Widget child;
  const HomeShell({super.key, required this.child});

  static const _tabs = [
    (icon: Icons.home_outlined, activeIcon: Icons.home_rounded, label: 'Home', path: '/dashboard'),
    (icon: Icons.calendar_today_outlined, activeIcon: Icons.calendar_today_rounded, label: 'Schedule', path: '/home'),
    (icon: Icons.event_note_outlined, activeIcon: Icons.event_note_rounded, label: 'Calendar', path: '/calendar'),
    (icon: Icons.people_outline_rounded, activeIcon: Icons.people_rounded, label: 'Groups', path: '/groups'),
    (icon: Icons.account_balance_wallet_outlined, activeIcon: Icons.account_balance_wallet_rounded, label: 'Finance', path: '/expenses'),
    (icon: Icons.psychology_outlined, activeIcon: Icons.psychology_rounded, label: 'Focus', path: '/flow'),
    (icon: Icons.auto_stories_outlined, activeIcon: Icons.auto_stories_rounded, label: 'Brain', path: '/rag'),
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final location = GoRouterState.of(context).uri.path;
    int currentIndex = _tabs.indexWhere((t) => location.startsWith(t.path));
    if (currentIndex < 0) currentIndex = 0;

    final isDark = context.isDark;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: Stack(
        children: [
          // Subtle ambient glow orbs (toned down in light)
          Positioned(
            top: -120, left: -80,
            child: _GlowOrb(size: 450, color: AppColors.indigo, opacity: isDark ? 0.14 : 0.05, durationSec: 5),
          ),
          Positioned(
            bottom: 60, right: -100,
            child: _GlowOrb(size: 350, color: AppColors.cyan, opacity: isDark ? 0.09 : 0.04, durationSec: 7),
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

// ── Animated breathing glow orb ─────────────────────────────────────────────────────────
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
          width: widget.size, height: widget.size,
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

// ── Premium glassmorphism bottom navigation bar ─────────────────────────────
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
    final isDark = context.isDark;

    return Container(
      decoration: BoxDecoration(
        color: isDark
            ? const Color(0xE6080B1F)   // 90% opacity dark bg
            : const Color(0xF0FFFFFF),  // 94% opacity white
        border: Border(
          top: BorderSide(
            color: isDark
                ? const Color(0x33A78BFA)  // violet tint
                : const Color(0xFFE2E8F0),
            width: 0.5,
          ),
        ),
        boxShadow: [
          BoxShadow(
            color: isDark
                ? const Color(0x556366F1)  // indigo glow
                : Colors.black.withOpacity(0.08),
            blurRadius: 32,
            offset: const Offset(0, -8),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
          child: Row(
            children: List.generate(tabs.length, (i) {
              final sel = currentIndex == i;
              return Expanded(
                child: GestureDetector(
                  onTap: () => onTap(i),
                  behavior: HitTestBehavior.opaque,
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 250),
                    curve: Curves.easeOutCubic,
                    padding: const EdgeInsets.symmetric(vertical: 7),
                    child: Column(mainAxisSize: MainAxisSize.min, children: [
                      // Icon with animated gradient pill
                      AnimatedContainer(
                        duration: const Duration(milliseconds: 250),
                        curve: Curves.easeOutCubic,
                        padding: EdgeInsets.symmetric(
                          horizontal: sel ? 14 : 8, vertical: 6),
                        decoration: BoxDecoration(
                          gradient: sel
                              ? const LinearGradient(
                                  colors: [AppColors.indigo, AppColors.violet],
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                )
                              : null,
                          borderRadius: BorderRadius.circular(22),
                          boxShadow: sel && isDark
                              ? [const BoxShadow(
                                  color: Color(0x556366F1),
                                  blurRadius: 12,
                                  offset: Offset(0, 2))]
                              : null,
                        ),
                        child: AnimatedScale(
                          scale: sel ? 1.08 : 1.0,
                          duration: const Duration(milliseconds: 220),
                          child: Icon(
                            sel ? tabs[i].activeIcon : tabs[i].icon,
                            size: 21,
                            color: sel
                                ? Colors.white
                                : (isDark
                                    ? const Color(0xFF475569)
                                    : const Color(0xFF94A3B8)),
                          ),
                        ),
                      ),
                      const SizedBox(height: 3),
                      AnimatedDefaultTextStyle(
                        duration: const Duration(milliseconds: 200),
                        style: TextStyle(
                          fontSize: 9.0,
                          fontWeight: sel ? FontWeight.w700 : FontWeight.w500,
                          color: sel
                              ? AppColors.indigo
                              : (isDark
                                  ? const Color(0xFF334155)
                                  : const Color(0xFF94A3B8)),
                          fontFamily: 'Syne',
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

const _kGroupCategories = [
  (id: 'general',     label: 'General',     icon: Icons.people_outline,        color: Color(0xFF94A3B8)),
  (id: 'study_focus', label: 'Study',       icon: Icons.menu_book_outlined,    color: Color(0xFF6366F1)),
  (id: 'hackathon',   label: 'Hackathon',   icon: Icons.rocket_launch_outlined, color: Color(0xFFF59E0B)),
  (id: 'project',     label: 'Project',     icon: Icons.build_circle_outlined,  color: Color(0xFF10B981)),
  (id: 'lab',         label: 'Lab / Prac',  icon: Icons.science_outlined,       color: Color(0xFF22D3EE)),
  (id: 'social',      label: 'Social',      icon: Icons.celebration_outlined,   color: Color(0xFFF43F5E)),
];

class _GroupsScreenState extends ConsumerState<GroupsScreen> {
  String _categoryFilter = 'all';

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isDark = context.isDark;
    final groupsAsync = ref.watch(groupsProvider);
    final hubState = ref.watch(hubProvider);

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: NestedScrollView(
        headerSliverBuilder: (ctx, _) => [
          SliverAppBar(
            pinned: false,
            backgroundColor: isDark ? AppColors.darkBg : AppColors.lightBg,
            title: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('Study Squads', style: TextStyle(
                fontFamily: 'Syne', fontWeight: FontWeight.w800, fontSize: 22,
                color: cs.onSurface)),
              Text('Collaborate with your class', style: TextStyle(
                color: cs.onSurface.withOpacity(0.45), fontSize: 11, fontFamily: 'DM Sans')),
            ]),
            actions: [
              if (hubState.isLoading)
                Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: SizedBox(width: 18, height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.indigo)),
                ),
              _AppBarBtn(icon: Icons.checklist_rtl_outlined,
                onTap: () => context.push('/my-tasks')),
              const SizedBox(width: 8),
              _AppBarBtn(icon: Icons.refresh_rounded,
                onTap: () => ref.invalidate(groupsProvider)),
              const SizedBox(width: 12),
            ],
          ),
          // Category filters
          SliverToBoxAdapter(
            child: Container(
              color: isDark ? AppColors.darkBg : AppColors.lightBg,
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 10),
                child: Row(children: [
                  _FilterChip(
                    label: 'All', icon: Icons.grid_view_rounded,
                    color: AppColors.indigo,
                    selected: _categoryFilter == 'all',
                    onTap: () => setState(() => _categoryFilter = 'all'),
                  ),
                  const SizedBox(width: 8),
                  ..._kGroupCategories.map((cat) => Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: _FilterChip(
                      label: cat.label, icon: cat.icon, color: cat.color,
                      selected: _categoryFilter == cat.id,
                      onTap: () => setState(() =>
                        _categoryFilter = cat.id == _categoryFilter ? 'all' : cat.id),
                    ),
                  )),
                ]),
              ),
            ),
          ),
        ],
        body: groupsAsync.when(
          loading: () => const GroupsShimmer(),
          error: (e, _) => _ErrorState(
            message: e.toString(),
            onRetry: () => ref.invalidate(groupsProvider),
          ),
          data: (groups) {
            final filtered = _categoryFilter == 'all'
                ? groups
                : groups.where((g) =>
                    (g as Map<String, dynamic>)['category'] == _categoryFilter).toList();

            if (groups.isEmpty) return _EmptyState(
              onCreate: () => _showCreateSheet(context),
              onJoin: () => _showJoinSheet(context),
            );
            if (filtered.isEmpty) return Center(child: Column(
              mainAxisSize: MainAxisSize.min, children: [
                Icon(Icons.filter_list_off_outlined, size: 48,
                  color: cs.onSurface.withOpacity(0.25)),
                const SizedBox(height: 12),
                Text('No squads in this category',
                  style: TextStyle(color: cs.onSurface.withOpacity(0.5))),
              ]),
            );

            return RefreshIndicator(
              color: AppColors.indigo,
              backgroundColor: isDark ? AppColors.darkSurface : Colors.white,
              onRefresh: () async => ref.invalidate(groupsProvider),
              child: ListView.separated(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
                itemCount: filtered.length,
                separatorBuilder: (_, __) => const SizedBox(height: 10),
                itemBuilder: (_, i) =>
                  _GroupCard(group: filtered[i] as Map<String, dynamic>),
              ),
            );
          },
        ),
      ),
      floatingActionButton: Column(mainAxisSize: MainAxisSize.min, children: [
        FloatingActionButton.small(
          heroTag: 'join_fab',
          onPressed: () => _showJoinSheet(context),
          backgroundColor: isDark ? AppColors.darkSurface : Colors.white,
          foregroundColor: AppColors.indigo,
          elevation: 4,
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
            label: const Text('New Squad',
              style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
          ),
        ),
      ]),
    );
  }

  void _showCreateSheet(BuildContext ctx) {
    final nameCtrl = TextEditingController();
    final descCtrl = TextEditingController();
    String selectedCategory = 'general';

    showModalBottomSheet(
      context: ctx,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetCtx) => StatefulBuilder(builder: (sheetCtx2, setSheet) {
        final cs = Theme.of(sheetCtx2).colorScheme;
        return Container(
          decoration: BoxDecoration(
            color: cs.surface,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
            boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.3), blurRadius: 40)],
          ),
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(sheetCtx2).viewInsets.bottom + 24,
            left: 20, right: 20, top: 8,
          ),
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
            Center(child: Container(
              width: 40, height: 4, margin: const EdgeInsets.only(bottom: 20),
              decoration: BoxDecoration(
                color: cs.onSurface.withOpacity(0.15),
                borderRadius: BorderRadius.circular(2)),
            )),
            Row(children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppColors.indigo.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(12)),
                child: const Icon(Icons.group_add_outlined, color: AppColors.indigo)),
              const SizedBox(width: 12),
              Text('Create Study Squad', style: TextStyle(
                fontFamily: 'Syne', fontSize: 18, fontWeight: FontWeight.w700,
                color: cs.onSurface)),
            ]),
            const SizedBox(height: 20),
            TextField(
              controller: nameCtrl,
              style: TextStyle(color: cs.onSurface),
              decoration: InputDecoration(
                labelText: 'Squad name *',
                hintText: 'e.g. OS Study Group',
                prefixIcon: Icon(Icons.people_outline, size: 20,
                  color: cs.onSurface.withOpacity(0.4)),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: descCtrl,
              style: TextStyle(color: cs.onSurface),
              decoration: InputDecoration(
                labelText: 'Description (optional)',
                prefixIcon: Icon(Icons.notes_outlined, size: 20,
                  color: cs.onSurface.withOpacity(0.4)),
              ),
            ),
            const SizedBox(height: 16),
            Text('Category', style: TextStyle(
              color: cs.onSurface.withOpacity(0.5), fontSize: 12, fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(children: _kGroupCategories.map((cat) {
                final sel = selectedCategory == cat.id;
                return GestureDetector(
                  onTap: () => setSheet(() => selectedCategory = cat.id),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 180),
                    margin: const EdgeInsets.only(right: 8),
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                    decoration: BoxDecoration(
                      color: sel ? cat.color.withOpacity(0.15) : cs.onSurface.withOpacity(0.05),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: sel ? cat.color.withOpacity(0.5) : Colors.transparent,
                        width: sel ? 1.5 : 1,
                      ),
                    ),
                    child: Row(mainAxisSize: MainAxisSize.min, children: [
                      Icon(cat.icon, size: 12, color: sel ? cat.color : cs.onSurface.withOpacity(0.35)),
                      const SizedBox(width: 5),
                      Text(cat.label, style: TextStyle(
                        fontSize: 11, fontWeight: sel ? FontWeight.w700 : FontWeight.w500,
                        color: sel ? cat.color : cs.onSurface.withOpacity(0.5))),
                    ]),
                  ),
                );
              }).toList()),
            ),
            const SizedBox(height: 20),
            GestureDetector(
              onTap: () async {
                final name = nameCtrl.text.trim();
                if (name.isEmpty) return;
                Navigator.pop(sheetCtx2);
                await ref.read(hubProvider.notifier).createGroup(
                  name,
                  descCtrl.text.trim().isEmpty ? null : descCtrl.text.trim(),
                  category: selectedCategory,
                );
                ref.invalidate(groupsProvider);
                if (mounted && ctx.mounted) {
                  final err = ref.read(hubProvider).error;
                  ScaffoldMessenger.of(ctx).showSnackBar(SnackBar(
                    content: Text(err != null ? 'Error: $err' : 'Squad created! ✅'),
                    backgroundColor: err != null ? AppColors.rose : AppColors.green,
                  ));
                }
              },
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 16),
                decoration: DesignStyles.gradientButton(),
                child: const Center(child: Row(mainAxisSize: MainAxisSize.min, children: [
                  Icon(Icons.add_rounded, color: Colors.white, size: 18),
                  SizedBox(width: 8),
                  Text('Create Squad', style: TextStyle(
                    color: Colors.white, fontWeight: FontWeight.w700, fontSize: 15)),
                ])),
              ),
            ),
          ]),
        );
      }),
    );
  }

  void _showJoinSheet(BuildContext ctx) {
    final codeCtrl = TextEditingController();
    showModalBottomSheet(
      context: ctx,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetCtx) {
        final cs = Theme.of(sheetCtx).colorScheme;
        return Container(
          decoration: BoxDecoration(
            color: cs.surface,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
          ),
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(sheetCtx).viewInsets.bottom + 24,
            left: 20, right: 20, top: 8,
          ),
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
            Center(child: Container(
              width: 40, height: 4, margin: const EdgeInsets.only(bottom: 20),
              decoration: BoxDecoration(
                color: cs.onSurface.withOpacity(0.15),
                borderRadius: BorderRadius.circular(2)),
            )),
            Row(children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppColors.cyan.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(12)),
                child: const Icon(Icons.qr_code_scanner_outlined, color: AppColors.cyan)),
              const SizedBox(width: 12),
              Text('Join a Squad', style: TextStyle(
                fontFamily: 'Syne', fontSize: 18, fontWeight: FontWeight.w700,
                color: cs.onSurface)),
            ]),
            const SizedBox(height: 8),
            Text('Ask your squad leader for the 8-character invite code.',
              style: TextStyle(color: cs.onSurface.withOpacity(0.55), fontSize: 13)),
            const SizedBox(height: 20),
            TextField(
              controller: codeCtrl,
              maxLength: 8,
              textCapitalization: TextCapitalization.characters,
              style: TextStyle(color: cs.onSurface, letterSpacing: 2, fontWeight: FontWeight.w700),
              decoration: InputDecoration(
                labelText: 'Invite Code',
                hintText: 'e.g. ABC12345',
                prefixIcon: Icon(Icons.vpn_key_outlined, size: 20,
                  color: cs.onSurface.withOpacity(0.4)),
              ),
            ),
            const SizedBox(height: 12),
            GestureDetector(
              onTap: () async {
                final code = codeCtrl.text.trim();
                if (code.length != 8) return;
                Navigator.pop(sheetCtx);
                await ref.read(hubProvider.notifier).joinGroup(code);
                ref.invalidate(groupsProvider);
                if (mounted && ctx.mounted) {
                  final err = ref.read(hubProvider).error;
                  ScaffoldMessenger.of(ctx).showSnackBar(SnackBar(
                    content: Text(err != null ? '$err' : 'Joined squad! 🎉'),
                    backgroundColor: err != null ? AppColors.rose : AppColors.green,
                  ));
                }
              },
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 16),
                decoration: DesignStyles.gradientButton(),
                child: const Center(child: Row(mainAxisSize: MainAxisSize.min, children: [
                  Icon(Icons.login_rounded, color: Colors.white, size: 18),
                  SizedBox(width: 8),
                  Text('Join Squad', style: TextStyle(
                    color: Colors.white, fontWeight: FontWeight.w700, fontSize: 15)),
                ])),
              ),
            ),
          ]),
        );
      },
    );
  }
}

// ── App Bar icon button ───────────────────────────────────────────────────────
class _AppBarBtn extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  const _AppBarBtn({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 36, height: 36,
        decoration: BoxDecoration(
          color: cs.onSurface.withOpacity(0.07),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(icon, size: 18, color: cs.onSurface.withOpacity(0.5)),
      ),
    );
  }
}


// ── Filter chip ───────────────────────────────────────────────────────────────
class _FilterChip extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color color;
  final bool selected;
  final VoidCallback onTap;
  const _FilterChip({required this.label, required this.icon, required this.color,
    required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        decoration: BoxDecoration(
          color: selected ? color.withOpacity(0.15) : cs.onSurface.withOpacity(0.05),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: selected ? color.withOpacity(0.5) : Colors.transparent,
            width: selected ? 1.5 : 1,
          ),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(icon, size: 12, color: selected ? color : cs.onSurface.withOpacity(0.4)),
          const SizedBox(width: 5),
          Text(label, style: TextStyle(
            fontSize: 11, fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
            color: selected ? color : cs.onSurface.withOpacity(0.5))),
        ]),
      ),
    );
  }
}

// ── Group Card ────────────────────────────────────────────────────────────────
class _GroupCard extends ConsumerWidget {
  final Map<String, dynamic> group;
  const _GroupCard({required this.group});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cs = Theme.of(context).colorScheme;
    final isDark = context.isDark;
    final name = group['name'] as String? ?? 'Unnamed';
    final desc = group['description'] as String?;
    final role = group['role'] as String? ?? 'member';
    final inviteCode = group['inviteCode'] as String? ?? '';
    final categoryId = group['category'] as String? ?? 'general';
    final gId = group['id'] as String;

    final hue = name.codeUnits.fold(0, (a, b) => a + b) % 360;
    final avatarColor = HSLColor.fromAHSL(1, hue.toDouble(), 0.65, 0.55).toColor();
    final catMeta = _kGroupCategories.firstWhere((c) => c.id == categoryId,
        orElse: () => _kGroupCategories.first);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: () => context.push('/hub/$gId'),
        child: Container(
          decoration: DesignStyles.card(context),
          padding: const EdgeInsets.all(16),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              // Avatar
              Container(
                width: 48, height: 48,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(14),
                  gradient: LinearGradient(
                    colors: [avatarColor, avatarColor.withOpacity(0.7)],
                    begin: Alignment.topLeft, end: Alignment.bottomRight,
                  ),
                  boxShadow: [BoxShadow(color: avatarColor.withOpacity(0.35), blurRadius: 12, offset: const Offset(0, 4))],
                ),
                child: Center(child: Text(name[0].toUpperCase(), style: const TextStyle(
                  color: Colors.white, fontWeight: FontWeight.w800, fontSize: 20, fontFamily: 'Syne'))),
              ),
              const SizedBox(width: 12),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(children: [
                  Expanded(child: Text(name, style: TextStyle(
                    color: cs.onSurface, fontWeight: FontWeight.w700, fontSize: 15, fontFamily: 'Syne'))),
                  if (role == 'admin')
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                      decoration: BoxDecoration(
                        color: AppColors.indigo.withOpacity(0.12),
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: AppColors.indigo.withOpacity(0.3)),
                      ),
                      child: const Text('Admin', style: TextStyle(
                        fontSize: 9, color: AppColors.indigo, fontWeight: FontWeight.w700)),
                    ),
                ]),
                const SizedBox(height: 5),
                Row(children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                    decoration: BoxDecoration(
                      color: catMeta.color.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Row(mainAxisSize: MainAxisSize.min, children: [
                      Icon(catMeta.icon, size: 10, color: catMeta.color),
                      const SizedBox(width: 4),
                      Text(catMeta.label, style: TextStyle(
                        fontSize: 10, color: catMeta.color, fontWeight: FontWeight.w700)),
                    ]),
                  ),
                ]),
                if (desc != null) ...[
                  const SizedBox(height: 3),
                  Text(desc, maxLines: 1, overflow: TextOverflow.ellipsis,
                    style: TextStyle(color: cs.onSurface.withOpacity(0.5), fontSize: 12)),
                ],
              ])),
              PopupMenuButton<String>(
                icon: Icon(Icons.more_vert_rounded, color: cs.onSurface.withOpacity(0.35), size: 20),
                color: isDark ? AppColors.darkSurface : Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                  side: BorderSide(color: isDark ? AppColors.darkBorder : AppColors.lightBorder),
                ),
                onSelected: (val) {
                  if (val == 'chat') context.push('/hub/$gId');
                  if (val == 'whiteboard') context.go('/whiteboard/$gId');
                  if (val == 'my_tasks') context.push('/my-tasks');
                },
                itemBuilder: (_) => [
                  PopupMenuItem(value: 'chat', child: Row(children: [
                    Icon(Icons.chat_outlined, color: AppColors.indigo, size: 16),
                    const SizedBox(width: 10),
                    Text('Open Chat', style: TextStyle(color: cs.onSurface, fontSize: 13)),
                  ])),
                  PopupMenuItem(value: 'whiteboard', child: Row(children: [
                    Icon(Icons.draw_outlined, color: AppColors.violet, size: 16),
                    const SizedBox(width: 10),
                    Text('Whiteboard', style: TextStyle(color: cs.onSurface, fontSize: 13)),
                  ])),
                  PopupMenuItem(value: 'my_tasks', child: Row(children: [
                    Icon(Icons.checklist_rtl_outlined, color: AppColors.green, size: 16),
                    const SizedBox(width: 10),
                    Text('My Tasks', style: TextStyle(color: cs.onSurface, fontSize: 13)),
                  ])),
                ],
              ),
            ]),
            const SizedBox(height: 12),
            // Action buttons
            Row(children: [
              _ActionTile(icon: Icons.chat_bubble_outline_rounded, label: 'Chat',
                color: AppColors.indigo, onTap: () => context.push('/hub/$gId')),
              const SizedBox(width: 8),
              _ActionTile(icon: Icons.view_kanban_outlined, label: 'Kanban',
                color: AppColors.violet, onTap: () => context.go('/kanban/$gId')),
              const SizedBox(width: 8),
              _ActionTile(icon: Icons.draw_outlined, label: 'Board',
                color: AppColors.cyan, onTap: () => context.go('/whiteboard/$gId')),
            ]),
            if (inviteCode.isNotEmpty) ...[
              const SizedBox(height: 10),
              GestureDetector(
                onTap: () {
                  Clipboard.setData(ClipboardData(text: inviteCode));
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Invite code copied!'),
                      duration: Duration(seconds: 2)));
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: AppColors.indigo.withOpacity(0.07),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: AppColors.indigo.withOpacity(0.2)),
                  ),
                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                    const Icon(Icons.copy_outlined, size: 12, color: AppColors.indigo),
                    const SizedBox(width: 6),
                    Text(inviteCode, style: const TextStyle(
                      fontSize: 11, color: AppColors.indigo,
                      fontWeight: FontWeight.w700, letterSpacing: 1.5)),
                  ]),
                ),
              ),
            ],
          ]),
        ),
      ),
    );
  }
}

class _ActionTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;
  const _ActionTile({required this.icon, required this.label, required this.color, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Expanded(child: GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8),
        decoration: BoxDecoration(
          color: color.withOpacity(0.08),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: color.withOpacity(0.2)),
        ),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Icon(icon, size: 16, color: color),
          const SizedBox(height: 4),
          Text(label, style: TextStyle(
            color: color, fontSize: 10, fontWeight: FontWeight.w700)),
        ]),
      ),
    ));
  }
}

// ── Empty + Error states ──────────────────────────────────────────────────────
class _EmptyState extends StatelessWidget {
  final VoidCallback onCreate;
  final VoidCallback onJoin;
  const _EmptyState({required this.onCreate, required this.onJoin});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Center(child: Padding(
      padding: const EdgeInsets.all(40),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Container(
          padding: const EdgeInsets.all(28),
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: LinearGradient(colors: [
              AppColors.violet.withOpacity(0.2), AppColors.indigo.withOpacity(0.1)]),
          ),
          child: const Icon(Icons.people_outline_rounded, size: 54, color: AppColors.indigo)),
        const SizedBox(height: 24),
        Text('No squads yet', style: TextStyle(
          fontFamily: 'Syne', fontWeight: FontWeight.w800, fontSize: 22, color: cs.onSurface)),
        const SizedBox(height: 10),
        Text('Create a study squad or join one with an invite code.',
          textAlign: TextAlign.center,
          style: TextStyle(color: cs.onSurface.withOpacity(0.5), fontSize: 14, height: 1.5)),
        const SizedBox(height: 28),
        Row(children: [
          Expanded(child: OutlinedButton.icon(
            onPressed: onJoin,
            icon: const Icon(Icons.qr_code_scanner_outlined, size: 16),
            label: const Text('Join'),
            style: OutlinedButton.styleFrom(
              foregroundColor: AppColors.indigo,
              side: BorderSide(color: AppColors.indigo.withOpacity(0.4)),
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            ),
          )),
          const SizedBox(width: 12),
          Expanded(child: GestureDetector(
            onTap: onCreate,
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 14),
              decoration: DesignStyles.gradientButton(),
              child: const Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                Icon(Icons.group_add_outlined, color: Colors.white, size: 16),
                SizedBox(width: 8),
                Text('Create', style: TextStyle(
                  color: Colors.white, fontWeight: FontWeight.w700)),
              ]),
            ),
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
      padding: const EdgeInsets.all(40),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            shape: BoxShape.circle, color: AppColors.rose.withOpacity(0.1)),
          child: const Icon(Icons.wifi_off_outlined, size: 44, color: AppColors.rose)),
        const SizedBox(height: 20),
        Text('Could not load groups', style: TextStyle(
          fontFamily: 'Syne', fontWeight: FontWeight.w700, fontSize: 18, color: cs.onSurface)),
        const SizedBox(height: 8),
        Text('Make sure the backend is running.',
          textAlign: TextAlign.center,
          style: TextStyle(color: cs.onSurface.withOpacity(0.5), fontSize: 13)),
        const SizedBox(height: 24),
        GestureDetector(
          onTap: onRetry,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            decoration: DesignStyles.gradientButton(),
            child: const Row(mainAxisSize: MainAxisSize.min, children: [
              Icon(Icons.refresh_rounded, color: Colors.white, size: 16),
              SizedBox(width: 8),
              Text('Retry', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
            ]),
          ),
        ),
      ]),
    ));
  }
}
