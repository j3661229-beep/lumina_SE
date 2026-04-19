import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fl_chart/fl_chart.dart';
import '../../core/theme/design_tokens.dart';
import '../../shared/widgets/shimmer_widgets.dart';
import 'context_switch_provider.dart';

class FlowGraphScreen extends ConsumerWidget {
  const FlowGraphScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final stateAsync = ref.watch(contextSwitchProvider);
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Cognitive Flow',
                style: TextStyle(fontFamily: 'Syne', fontWeight: FontWeight.w800, fontSize: 20)),
            stateAsync.when(
              loading: () => const Text('loading...', style: TextStyle(fontSize: 11, color: Colors.grey)),
              error: (_, __) => const SizedBox.shrink(),
              data: (s) => Row(mainAxisSize: MainAxisSize.min, children: [
                Container(width: 6, height: 6,
                  decoration: BoxDecoration(
                    color: s.isMonitoring ? AppColors.green : AppColors.amber,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 5),
                Text(
                  s.dndEnabled
                      ? 'Focus Mode ON'
                      : s.isMonitoring ? 'Live Monitoring' : 'Permission required',
                  style: TextStyle(
                    fontSize: 11, fontWeight: FontWeight.w600,
                    color: s.dndEnabled ? AppColors.rose : s.isMonitoring ? AppColors.green : AppColors.amber,
                  ),
                ),
              ]),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.auto_awesome, color: AppColors.amber),
            tooltip: 'Load Demo Data',
            onPressed: () {
              HapticFeedback.mediumImpact();
              ref.read(contextSwitchProvider.notifier).seedDemoData();
            },
          ),
          IconButton(
            icon: Icon(Icons.refresh_outlined, color: cs.onSurface.withOpacity(0.5)),
            onPressed: () => ref.read(contextSwitchProvider.notifier).refresh(),
          ),
        ],
      ),
      body: stateAsync.when(
        loading: () => const FlowShimmer(),
        error: (e, _) => _ErrorState(error: '$e'),
        data: (state) {
          // Show DND alert banner if a blocked app was opened
          return Stack(children: [
            RefreshIndicator(
              onRefresh: () => ref.read(contextSwitchProvider.notifier).refresh(),
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 120),
                children: [
                  if (!state.hasPermission) ...[
                    const SizedBox(height: 12),
                    _PermissionBanner(
                      onTap: () => ref.read(contextSwitchProvider.notifier).requestPermission(),
                    ),
                  ],
                  const SizedBox(height: 12),
                  // ── DND Card ──────────────────────────────────────────────
                  _DndCard(state: state),
                  const SizedBox(height: 16),
                  // ── Debt Gauge ────────────────────────────────────────────
                  _DebtGauge(score: state.score, message: state.statusMessage),
                  const SizedBox(height: 16),
                  // ── Live Timeline ──────────────────────────────────────────
                  if (state.timeline.isNotEmpty) ...[
                    _SectionHeader(title: 'Last Hour', icon: Icons.timeline_rounded),
                    const SizedBox(height: 8),
                    _LiveTimeline(sessions: state.timeline, blockedPkgs: state.blockedPackages),
                    const SizedBox(height: 16),
                  ],
                  // ── Insight ───────────────────────────────────────────────
                  _InsightCard(score: state.score),
                  const SizedBox(height: 16),
                  // ── 7-Day Chart ───────────────────────────────────────────
                  if (state.scoreHistory.length > 1) ...[
                    _SectionHeader(title: '7-Day Trend', icon: Icons.bar_chart_rounded),
                    const SizedBox(height: 8),
                    _HistoryChart(history: state.scoreHistory),
                    const SizedBox(height: 16),
                  ],
                  // ── Squads ────────────────────────────────────────────────
                  _SectionHeader(title: 'Study Squads', icon: Icons.people_rounded),
                  const SizedBox(height: 8),
                  _StudySquadsCard(
                    onShare: (gid) => ref.read(contextSwitchProvider.notifier).shareToSquad(gid),
                  ),
                  const SizedBox(height: 16),
                  // ── Tips ──────────────────────────────────────────────────
                  _TipsCard(score: state.score),
                ],
              ),
            ),
            // ── DND Alert Overlay ──────────────────────────────────────────
            if (state.dndAlert != null)
              _DndAlertOverlay(
                message: state.dndAlert!,
                onDismiss: () => ref.read(contextSwitchProvider.notifier).clearDndAlert(),
              ),
          ]);
        },
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// DND Card + App Picker
// ─────────────────────────────────────────────────────────────────────────────
class _DndCard extends ConsumerStatefulWidget {
  final CognitiveState state;
  const _DndCard({required this.state});

  @override
  ConsumerState<_DndCard> createState() => _DndCardState();
}

class _DndCardState extends ConsumerState<_DndCard> {
  bool _pickerOpen = false;
  String _search = '';
  final _searchCtrl = TextEditingController();

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final s = widget.state;
    final cs = Theme.of(context).colorScheme;
    final accent = s.dndEnabled ? AppColors.rose : AppColors.indigo;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft, end: Alignment.bottomRight,
          colors: s.dndEnabled
              ? [AppColors.rose.withOpacity(0.18), AppColors.amber.withOpacity(0.08)]
              : [AppColors.indigo.withOpacity(0.10), AppColors.cyan.withOpacity(0.06)],
        ),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: accent.withOpacity(0.35)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          // ── Toggle Row ─────────────────────────────────────────────────
          Row(children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: accent.withOpacity(0.15),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(
                s.dndEnabled ? Icons.do_not_disturb_on_rounded : Icons.do_not_disturb_off_outlined,
                color: accent, size: 22),
            ),
            const SizedBox(width: 12),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('Focus Mode (DND)',
                  style: TextStyle(fontFamily: 'Syne', fontWeight: FontWeight.w800, fontSize: 15,
                      color: cs.onSurface)),
              Text(s.dndEnabled
                  ? s.hasAccessibilityPermission
                      ? '🛡️ ${s.blockedPackages.length} app${s.blockedPackages.length == 1 ? "" : "s"} hard-blocked'
                      : '⚠️ Soft mode — enable block below'
                  : 'Block distracting apps during study',
                  style: TextStyle(fontSize: 11, color: cs.onSurface.withOpacity(0.55))),
            ])),
            Switch.adaptive(
              value: s.dndEnabled,
              activeColor: AppColors.rose,
              onChanged: (v) {
                HapticFeedback.mediumImpact();
                ref.read(contextSwitchProvider.notifier).toggleDnd(enabled: v);
              },
            ),
          ]),

          // ── Accessibility permission step (when DND ON but block not enabled) ─
          if (s.dndEnabled && !s.hasAccessibilityPermission) ...[
            const SizedBox(height: 14),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: AppColors.rose.withOpacity(0.08),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.rose.withOpacity(0.3)),
              ),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const Row(children: [
                  Icon(Icons.shield_outlined, color: AppColors.rose, size: 16),
                  SizedBox(width: 6),
                  Expanded(child: Text('Enable Hard Blocking',
                      style: TextStyle(fontWeight: FontWeight.w800, fontSize: 13,
                          color: AppColors.rose, fontFamily: 'Syne'))),
                ]),
                const SizedBox(height: 6),
                Text('Right now notifications fire but the app still opens. '
                    'Enable the Accessibility Service to INSTANTLY close blocked apps.',
                    style: TextStyle(fontSize: 11, color: AppColors.rose.withOpacity(0.8))),
                const SizedBox(height: 10),
                const _PermStep(num: '1', text: 'Tap "Enable Focus Block" below'),
                const _PermStep(num: '2', text: 'Find "Lumina Focus Block" in the list'),
                const _PermStep(num: '3', text: 'Toggle ON → come back'),
                const SizedBox(height: 10),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    style: FilledButton.styleFrom(
                      backgroundColor: AppColors.rose,
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                    onPressed: () {
                      HapticFeedback.mediumImpact();
                      ref.read(contextSwitchProvider.notifier).requestAccessibilityPermission();
                    },
                    icon: const Icon(Icons.accessibility_new_rounded, size: 16),
                    label: const Text('Enable Focus Block → Accessibility',
                        style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12)),
                  ),
                ),
              ]),
            ),
          ],

          // ── Accessibility granted badge ─────────────────────────────────
          if (s.dndEnabled && s.hasAccessibilityPermission) ...[
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: AppColors.green.withOpacity(0.1),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: AppColors.green.withOpacity(0.3)),
              ),
              child: const Row(children: [
                Icon(Icons.shield_rounded, color: AppColors.green, size: 16),
                SizedBox(width: 8),
                Expanded(child: Text('Hard blocking active — apps will be closed instantly',
                    style: TextStyle(fontSize: 12, color: AppColors.green, fontWeight: FontWeight.w600))),
              ]),
            ),
          ],

          // ── Blocked apps chips ─────────────────────────────────────────
          if (s.blockedPackages.isNotEmpty) ...[
            const SizedBox(height: 12),
            Wrap(spacing: 6, runSpacing: 6,
              children: s.blockedPackages.map((pkg) {
                final name = s.installedApps
                    .firstWhere((a) => a.packageName == pkg,
                        orElse: () => InstalledApp(packageName: pkg, appName: pkg.split('.').last))
                    .appName;
                return Chip(
                  label: Text(name, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600)),
                  backgroundColor: AppColors.rose.withOpacity(0.12),
                  side: BorderSide(color: AppColors.rose.withOpacity(0.3)),
                  deleteIcon: const Icon(Icons.close, size: 14, color: AppColors.rose),
                  onDeleted: () {
                    final updated = List<String>.from(s.blockedPackages)..remove(pkg);
                    ref.read(contextSwitchProvider.notifier).setBlockedApps(updated);
                  },
                  labelStyle: TextStyle(color: AppColors.rose.withOpacity(0.9)),
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                );
              }).toList(),
            ),
          ],

          // ── Add apps button ────────────────────────────────────────────
          const SizedBox(height: 12),
          GestureDetector(
            onTap: () async {
              await ref.read(contextSwitchProvider.notifier).loadInstalledApps();
              setState(() { _pickerOpen = true; _search = ''; _searchCtrl.clear(); });
            },
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 14),
              decoration: BoxDecoration(
                color: accent.withOpacity(0.10),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: accent.withOpacity(0.25)),
              ),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                Icon(Icons.add_circle_outline_rounded, color: accent, size: 16),
                const SizedBox(width: 8),
                Text('Add apps to block list',
                    style: TextStyle(color: accent, fontSize: 13, fontWeight: FontWeight.w700)),
              ]),
            ),
          ),

          // ── App Picker (inline collapsible) ────────────────────────────
          if (_pickerOpen) ...[
            const SizedBox(height: 14),
            _AppPicker(
              apps: widget.state.installedApps,
              selected: widget.state.blockedPackages,
              search: _search,
              searchCtrl: _searchCtrl,
              onSearchChanged: (v) => setState(() => _search = v),
              onToggle: (pkg) {
                final cur = List<String>.from(widget.state.blockedPackages);
                if (cur.contains(pkg)) cur.remove(pkg); else cur.add(pkg);
                ref.read(contextSwitchProvider.notifier).setBlockedApps(cur);
              },
              onClose: () => setState(() => _pickerOpen = false),
            ),
          ],
        ]),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// App Picker
// ─────────────────────────────────────────────────────────────────────────────
class _AppPicker extends StatelessWidget {
  final List<InstalledApp> apps;
  final List<String> selected;
  final String search;
  final TextEditingController searchCtrl;
  final ValueChanged<String> onSearchChanged;
  final ValueChanged<String> onToggle;
  final VoidCallback onClose;
  const _AppPicker({
    required this.apps, required this.selected, required this.search,
    required this.searchCtrl, required this.onSearchChanged,
    required this.onToggle, required this.onClose,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final filtered = apps
        .where((a) => a.appName.toLowerCase().contains(search.toLowerCase()))
        .toList();

    return Container(
      decoration: BoxDecoration(
        color: cs.surface.withOpacity(0.95),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: cs.outline.withOpacity(0.2)),
      ),
      child: Column(children: [
        // Header
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 12, 8, 8),
          child: Row(children: [
            const Icon(Icons.block_rounded, color: AppColors.rose, size: 16),
            const SizedBox(width: 8),
            const Expanded(child: Text('Select apps to block',
                style: TextStyle(fontFamily: 'Syne', fontWeight: FontWeight.w700, fontSize: 13))),
            IconButton(
              icon: const Icon(Icons.close, size: 18), padding: EdgeInsets.zero,
              constraints: const BoxConstraints(), onPressed: onClose,
            ),
          ]),
        ),
        // Search
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10),
          child: TextField(
            controller: searchCtrl,
            onChanged: onSearchChanged,
            style: const TextStyle(fontSize: 13),
            decoration: InputDecoration(
              hintText: 'Search apps…',
              hintStyle: TextStyle(color: cs.onSurface.withOpacity(0.4), fontSize: 13),
              prefixIcon: const Icon(Icons.search, size: 18),
              filled: true,
              fillColor: cs.onSurface.withOpacity(0.05),
              contentPadding: const EdgeInsets.symmetric(vertical: 8),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
            ),
          ),
        ),
        const SizedBox(height: 8),
        if (apps.isEmpty)
          const Padding(
            padding: EdgeInsets.all(16),
            child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
              SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)),
              SizedBox(width: 8),
              Text('Loading apps…', style: TextStyle(fontSize: 13)),
            ]),
          )
        else
          ConstrainedBox(
            constraints: const BoxConstraints(maxHeight: 260),
            child: ListView.builder(
              itemCount: filtered.length,
              shrinkWrap: true,
              itemBuilder: (_, i) {
                final app = filtered[i];
                final isSelected = selected.contains(app.packageName);
                return ListTile(
                  dense: true,
                  leading: Container(
                    width: 32, height: 32,
                    decoration: BoxDecoration(
                      color: isSelected ? AppColors.rose.withOpacity(0.15) : cs.onSurface.withOpacity(0.05),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Center(child: Text(
                      app.appName.isNotEmpty ? app.appName[0] : '?',
                      style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800,
                          color: isSelected ? AppColors.rose : cs.onSurface.withOpacity(0.6)),
                    )),
                  ),
                  title: Text(app.appName,
                      style: TextStyle(fontSize: 13, fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500)),
                  subtitle: Text(app.packageName,
                      style: TextStyle(fontSize: 10, color: cs.onSurface.withOpacity(0.4)),
                      overflow: TextOverflow.ellipsis),
                  trailing: AnimatedContainer(
                    duration: const Duration(milliseconds: 150),
                    width: 22, height: 22,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: isSelected ? AppColors.rose : Colors.transparent,
                      border: Border.all(color: isSelected ? AppColors.rose : cs.outline.withOpacity(0.4), width: 1.5),
                    ),
                    child: isSelected ? const Icon(Icons.check, size: 13, color: Colors.white) : null,
                  ),
                  onTap: () { HapticFeedback.selectionClick(); onToggle(app.packageName); },
                );
              },
            ),
          ),
        const SizedBox(height: 8),
      ]),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// DND Alert Overlay
// ─────────────────────────────────────────────────────────────────────────────
class _DndAlertOverlay extends StatelessWidget {
  final String message;
  final VoidCallback onDismiss;
  const _DndAlertOverlay({required this.message, required this.onDismiss});

  @override
  Widget build(BuildContext context) {
    return Positioned(
      top: 16, left: 16, right: 16,
      child: Material(
        color: Colors.transparent,
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppColors.rose,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [BoxShadow(color: AppColors.rose.withOpacity(0.4), blurRadius: 20, offset: const Offset(0, 8))],
          ),
          child: Row(children: [
            const Text('📵', style: TextStyle(fontSize: 24)),
            const SizedBox(width: 12),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Text('Focus Mode Alert!',
                  style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 14, fontFamily: 'Syne')),
              Text(message, style: const TextStyle(color: Colors.white70, fontSize: 12)),
            ])),
            IconButton(icon: const Icon(Icons.close, color: Colors.white, size: 18), onPressed: onDismiss),
          ]),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Permission Banner
// ─────────────────────────────────────────────────────────────────────────────
class _PermissionBanner extends StatelessWidget {
  final VoidCallback onTap;
  const _PermissionBanner({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [
          AppColors.indigo.withOpacity(0.18), AppColors.amber.withOpacity(0.10),
        ]),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.indigo.withOpacity(0.35)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(color: AppColors.indigo.withOpacity(0.15), borderRadius: BorderRadius.circular(10)),
              child: const Icon(Icons.phone_android_rounded, color: AppColors.indigo, size: 22),
            ),
            const SizedBox(width: 12),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Text('Enable App Monitoring',
                  style: TextStyle(fontFamily: 'Syne', fontWeight: FontWeight.w800, fontSize: 15)),
              Text('Required for real-time context switch tracking',
                  style: TextStyle(fontSize: 11, color: Theme.of(context).colorScheme.onSurface.withOpacity(0.55))),
            ])),
          ]),
          const SizedBox(height: 14),
          _PermStep(num: '1', text: 'Tap "Open Settings" below'),
          _PermStep(num: '2', text: 'Find Lumina in the list'),
          _PermStep(num: '3', text: 'Toggle "Allow" → come back to the app'),
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.indigo,
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              onPressed: () { HapticFeedback.mediumImpact(); onTap(); },
              icon: const Icon(Icons.settings_rounded, size: 16),
              label: const Text('Open Settings → Usage Access',
                  style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
            ),
          ),
        ]),
      ),
    );
  }
}

class _PermStep extends StatelessWidget {
  final String num;
  final String text;
  const _PermStep({required this.num, required this.text});

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 8),
    child: Row(children: [
      Container(width: 22, height: 22,
        decoration: BoxDecoration(
          color: AppColors.indigo.withOpacity(0.2), shape: BoxShape.circle,
          border: Border.all(color: AppColors.indigo.withOpacity(0.5)),
        ),
        child: Center(child: Text(num,
            style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: AppColors.indigo))),
      ),
      const SizedBox(width: 10),
      Expanded(child: Text(text,
          style: TextStyle(fontSize: 13, color: Theme.of(context).colorScheme.onSurface.withOpacity(0.8),
              fontWeight: FontWeight.w500))),
    ]),
  );
}

// ─────────────────────────────────────────────────────────────────────────────
// Debt Gauge
// ─────────────────────────────────────────────────────────────────────────────
class _DebtGauge extends StatefulWidget {
  final double score;
  final String? message;
  const _DebtGauge({required this.score, this.message});

  @override
  State<_DebtGauge> createState() => _DebtGaugeState();
}

class _DebtGaugeState extends State<_DebtGauge> with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _anim;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 800));
    _anim = Tween<double>(begin: 0, end: widget.score)
        .animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeOutCubic));
    _ctrl.forward();
  }

  @override
  void didUpdateWidget(_DebtGauge old) {
    super.didUpdateWidget(old);
    if (old.score != widget.score) {
      _anim = Tween<double>(begin: old.score, end: widget.score)
          .animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeOutCubic));
      _ctrl.forward(from: 0);
    }
  }

  @override
  void dispose() { _ctrl.dispose(); super.dispose(); }

  Color _color(double s) {
    if (s < 25) return AppColors.green;
    if (s < 50) return AppColors.amber;
    if (s < 75) return AppColors.rose;
    return AppColors.indigo;
  }

  String _label(double s) {
    if (s < 25) return 'In The Zone 🧠';
    if (s < 50) return 'Moderate ⚡';
    if (s < 75) return 'High Load ⚠️';
    return 'Critical 🔴';
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: AppStyles.glassCard(context),
      child: Column(children: [
        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          Text('Cognitive Debt', style: TextStyle(fontFamily: 'Syne', fontWeight: FontWeight.w800, fontSize: 16,
              color: Theme.of(context).colorScheme.onSurface)),
          AnimatedBuilder(animation: _anim, builder: (_, __) => Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            decoration: BoxDecoration(
              color: _color(_anim.value).withOpacity(0.15),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: _color(_anim.value).withOpacity(0.4)),
            ),
            child: Text(_label(_anim.value),
                style: TextStyle(color: _color(_anim.value), fontWeight: FontWeight.w700, fontSize: 11)),
          )),
        ]),
        const SizedBox(height: 20),
        SizedBox(height: 180,
          child: AnimatedBuilder(animation: _anim, builder: (_, __) =>
            Stack(alignment: Alignment.center, children: [
              PieChart(PieChartData(
                startDegreeOffset: -90, sectionsSpace: 0, centerSpaceRadius: 66,
                sections: [
                  PieChartSectionData(value: _anim.value, color: _color(_anim.value), radius: 20, title: ''),
                  PieChartSectionData(value: max(0, 100 - _anim.value),
                      color: Colors.grey.withOpacity(0.12), radius: 20, title: ''),
                ],
              )),
              Column(mainAxisSize: MainAxisSize.min, children: [
                Text(_anim.value.toStringAsFixed(0), style: TextStyle(
                    fontSize: 52, fontWeight: FontWeight.w900, color: _color(_anim.value), fontFamily: 'Syne')),
                Text('/100', style: TextStyle(
                    color: Theme.of(context).colorScheme.onSurface.withOpacity(0.4), fontSize: 13)),
              ]),
            ]),
          ),
        ),
        if (widget.message != null) ...[
          const SizedBox(height: 8),
          Text(widget.message!, style: TextStyle(
              fontSize: 12, color: Theme.of(context).colorScheme.onSurface.withOpacity(0.5)),
              textAlign: TextAlign.center),
        ],
      ]),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Live Timeline
// ─────────────────────────────────────────────────────────────────────────────
class _LiveTimeline extends StatelessWidget {
  final List<AppSession> sessions;
  final List<String> blockedPkgs;
  const _LiveTimeline({required this.sessions, required this.blockedPkgs});

  Color _colorFor(AppSession s) {
    if (blockedPkgs.contains(s.packageName)) return AppColors.rose;
    if (!s.isShortSwitch) return AppColors.green;
    if (s.duration.inSeconds > 60) return AppColors.amber;
    return AppColors.rose;
  }

  @override
  Widget build(BuildContext context) {
    final reversed = sessions.reversed.toList();
    return SizedBox(
      height: 126,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: reversed.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (context, i) {
          final s = reversed[i];
          final accent = _colorFor(s);
          final dur = s.duration;
          final durLabel = dur.inMinutes >= 1
              ? '${dur.inMinutes}m ${dur.inSeconds % 60}s'
              : '${dur.inSeconds}s';
          final isBlocked = blockedPkgs.contains(s.packageName);
          return Container(
            width: 100,
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: accent.withOpacity(context.isDark ? 0.12 : 0.07),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: accent.withOpacity(isBlocked ? 0.6 : 0.35), width: isBlocked ? 1.5 : 1),
            ),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                if (i == 0)
                  Container(padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(color: AppColors.green.withOpacity(0.2), borderRadius: BorderRadius.circular(6)),
                    child: const Text('NOW', style: TextStyle(fontSize: 9, color: AppColors.green, fontWeight: FontWeight.w800)),
                  ),
                if (isBlocked)
                  const Text('📵', style: TextStyle(fontSize: 12)),
                const Spacer(),
                Text(s.appName, maxLines: 2, overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700,
                        color: Theme.of(context).colorScheme.onSurface)),
                const SizedBox(height: 4),
                Text(durLabel, style: TextStyle(fontSize: 11, color: accent, fontWeight: FontWeight.w600)),
                if (s.isShortSwitch && !isBlocked)
                  Text('rapid ⚡', style: TextStyle(fontSize: 9, color: AppColors.rose.withOpacity(0.8))),
              ],
            ),
          );
        },
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Section Header / Insight / Tips / Squads / Chart / Error — same as before
// ─────────────────────────────────────────────────────────────────────────────
class _SectionHeader extends StatelessWidget {
  final String title; final IconData icon;
  const _SectionHeader({required this.title, required this.icon});
  @override
  Widget build(BuildContext context) => Row(children: [
    Icon(icon, size: 16, color: AppColors.indigo), const SizedBox(width: 6),
    Text(title, style: const TextStyle(fontFamily: 'Syne', fontWeight: FontWeight.w800, fontSize: 13, color: AppColors.indigo)),
  ]);
}

class _InsightCard extends StatelessWidget {
  final double score;
  const _InsightCard({required this.score});
  @override
  Widget build(BuildContext context) {
    final (emoji, title, desc) = score < 25
        ? ('🧠', 'Deep Focus Mode', 'You\'re crushing it. Keep distractions away.')
        : score < 50 ? ('⚡', 'Light Switching', 'Take a 5-min break to reset your focus.')
        : score < 75 ? ('⚠️', 'High Cognitive Load', 'Close social apps. Focus on one task.')
        : ('🔴', 'Critical Debt!', 'Stop switching. 20-min break immediately.');
    return Container(
      decoration: AppStyles.glassCard(context),
      child: Padding(padding: const EdgeInsets.all(16), child: Row(children: [
        Text(emoji, style: const TextStyle(fontSize: 32)), const SizedBox(width: 16),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(title, style: TextStyle(color: Theme.of(context).colorScheme.onSurface,
              fontSize: 15, fontWeight: FontWeight.w800, fontFamily: 'Syne')),
          const SizedBox(height: 4),
          Text(desc, style: TextStyle(fontSize: 13, color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6))),
        ])),
      ])),
    );
  }
}

class _TipsCard extends StatelessWidget {
  final double score;
  const _TipsCard({required this.score});
  List<String> _tips() {
    if (score < 25) return ['Keep Focus Mode ON.', 'Pomodoro: 25 min work, 5 min break.', 'Reward yourself after each block.'];
    if (score < 50) return ['Close Instagram and YouTube.', 'Use app timers for social media.', 'Write distracting thoughts down.'];
    if (score < 75) return ['Take a 10-min walk now.', 'Drink water, step away from screen.', 'Use grayscale to reduce screen appeal.'];
    return ['STOP. 20-minute break now.', 'Box breathing: 4s in, hold, out.', 'Cognitive debt resets overnight — rest!'];
  }
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: AppColors.indigo.withOpacity(context.isDark ? 0.08 : 0.04),
      borderRadius: BorderRadius.circular(16),
      border: Border.all(color: AppColors.indigo.withOpacity(0.2)),
    ),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      const Row(children: [
        Icon(Icons.lightbulb_outline, color: AppColors.indigo, size: 18), SizedBox(width: 6),
        Text('Focus Tips', style: TextStyle(fontWeight: FontWeight.w800, color: AppColors.indigo, fontFamily: 'Syne')),
      ]),
      const SizedBox(height: 10),
      ..._tips().map((t) => Padding(
        padding: const EdgeInsets.only(bottom: 6),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('• ', style: TextStyle(color: AppColors.indigo, fontWeight: FontWeight.w800)),
          Expanded(child: Text(t, style: TextStyle(
              color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6), fontSize: 12))),
        ]),
      )),
    ]),
  );
}

class _HistoryChart extends StatelessWidget {
  final List<Map<String, dynamic>> history;
  const _HistoryChart({required this.history});
  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final days = ['6d', '5d', '4d', '3d', '2d', 'Yest', 'Today'];
    final bars = history.reversed.toList();
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: AppStyles.glassCard(context),
      child: SizedBox(height: 120, child: BarChart(BarChartData(
        borderData: FlBorderData(show: false),
        gridData: FlGridData(show: true, drawVerticalLine: false, horizontalInterval: 25,
          getDrawingHorizontalLine: (_) => FlLine(color: cs.outline.withOpacity(0.1), strokeWidth: 1)),
        titlesData: FlTitlesData(
          bottomTitles: AxisTitles(sideTitles: SideTitles(showTitles: true, reservedSize: 24,
            getTitlesWidget: (v, _) => Text(v.toInt() < days.length ? days[v.toInt()] : '',
                style: TextStyle(fontSize: 10, color: cs.onSurface.withOpacity(0.4), fontWeight: FontWeight.w600)))),
          leftTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
          topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
          rightTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
        ),
        maxY: 100,
        barGroups: List.generate(bars.length, (i) {
          final score = (bars[i]['score'] as num).toDouble();
          final color = score < 25 ? AppColors.green : score < 50 ? AppColors.amber : score < 75 ? AppColors.rose : AppColors.indigo;
          return BarChartGroupData(x: history.length - 1 - i, barRods: [
            BarChartRodData(toY: score, color: color, width: 14, borderRadius: BorderRadius.circular(4)),
          ]);
        }),
      ))),
    );
  }
}

class _StudySquadsCard extends StatefulWidget {
  final Future<void> Function(String) onShare;
  const _StudySquadsCard({required this.onShare});
  @override State<_StudySquadsCard> createState() => _StudySquadsCardState();
}
class _StudySquadsCardState extends State<_StudySquadsCard> {
  bool _sharing = false; String? _shared;
  final _members = const [
    _SquadMember(alias: 'Anon#A3F2', score: 18, label: 'Zone'),
    _SquadMember(alias: 'Anon#B71C', score: 45, label: 'Moderate'),
    _SquadMember(alias: 'Anon#D99E', score: 72, label: 'High'),
  ];
  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: AppStyles.glassCard(context),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          const Text('🏆', style: TextStyle(fontSize: 20)), const SizedBox(width: 8),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text('Focus Squad', style: TextStyle(fontFamily: 'Syne', fontWeight: FontWeight.w800, fontSize: 14)),
            Text('Anonymized flow graphs', style: TextStyle(fontSize: 11, color: cs.onSurface.withOpacity(0.5))),
          ])),
          _sharing
              ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.indigo))
              : TextButton.icon(
                  style: TextButton.styleFrom(backgroundColor: AppColors.indigo.withOpacity(0.12),
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
                  icon: const Icon(Icons.upload_rounded, size: 14, color: AppColors.indigo),
                  label: const Text('Share', style: TextStyle(color: AppColors.indigo, fontSize: 12, fontWeight: FontWeight.w700)),
                  onPressed: () async {
                    setState(() => _sharing = true);
                    await widget.onShare('00000000-0000-0000-0000-000000000001');
                    setState(() { _sharing = false; _shared = 'done'; });
                  }),
        ]),
        const SizedBox(height: 12),
        ..._members.map((m) => _SquadRow(member: m)),
        if (_shared != null)
          Container(
            margin: const EdgeInsets.only(top: 8),
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(color: AppColors.green.withOpacity(0.1), borderRadius: BorderRadius.circular(8),
                border: Border.all(color: AppColors.green.withOpacity(0.3))),
            child: const Row(children: [
              Icon(Icons.check_circle_outline, color: AppColors.green, size: 14), SizedBox(width: 6),
              Text('Shared anonymously ✓', style: TextStyle(fontSize: 12, color: AppColors.green, fontWeight: FontWeight.w600)),
            ]),
          ),
      ]),
    );
  }
}

class _SquadMember { final String alias, label; final double score; final bool isYou;
  const _SquadMember({required this.alias, required this.score, required this.label, this.isYou = false});
}

class _SquadRow extends StatelessWidget {
  final _SquadMember member;
  const _SquadRow({required this.member});
  Color _bc(double s) => s < 25 ? AppColors.green : s < 50 ? AppColors.amber : s < 75 ? AppColors.rose : AppColors.indigo;
  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final color = member.isYou ? AppColors.indigo : _bc(member.score);
    return Padding(padding: const EdgeInsets.only(bottom: 8), child: Row(children: [
      SizedBox(width: 70, child: Text(member.alias, style: TextStyle(fontSize: 11,
          fontWeight: member.isYou ? FontWeight.w800 : FontWeight.w600,
          color: member.isYou ? AppColors.indigo : cs.onSurface))),
      Expanded(child: ClipRRect(borderRadius: BorderRadius.circular(4),
        child: LinearProgressIndicator(value: member.score / 100,
          backgroundColor: cs.outline.withOpacity(0.1),
          valueColor: AlwaysStoppedAnimation(color), minHeight: 6))),
      const SizedBox(width: 8),
      SizedBox(width: 36, child: Text(member.score.toStringAsFixed(0),
          style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: color), textAlign: TextAlign.right)),
    ]));
  }
}

class _ErrorState extends StatelessWidget {
  final String error;
  const _ErrorState({required this.error});
  @override
  Widget build(BuildContext context) => Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
    const Icon(Icons.error_outline, size: 48, color: AppColors.rose), const SizedBox(height: 8),
    Text(error, textAlign: TextAlign.center,
        style: TextStyle(color: Theme.of(context).colorScheme.onSurface.withOpacity(0.5))),
  ]));
}
