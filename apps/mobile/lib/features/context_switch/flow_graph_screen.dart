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
    final isDark = context.isDark;

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
              data: (s) => Text(
                s.isMonitoring ? '● Live Monitoring' : s.hasPermission ? 'Waiting...' : 'Permission required',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: s.isMonitoring ? AppColors.green : AppColors.amber,
                ),
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.auto_awesome, color: AppColors.amber),
            tooltip: 'Load Demo Data',
            onPressed: () async {
              HapticFeedback.mediumImpact();
              await ref.read(contextSwitchProvider.notifier).seedDemoData();
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
        data: (state) => RefreshIndicator(
          onRefresh: () => ref.read(contextSwitchProvider.notifier).refresh(),
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 32),
            children: [
              // ── 1. Permission Banner ──────────────────────────────────
              if (!state.hasPermission)
                _PermissionBanner(
                  onTap: () => ref.read(contextSwitchProvider.notifier).requestPermission(),
                ),
              // ── 2. Debt Gauge ──────────────────────────────────────────
              const SizedBox(height: 12),
              _DebtGauge(score: state.score, message: state.statusMessage),
              const SizedBox(height: 16),
              // ── 3. Live Timeline ──────────────────────────────────────
              if (state.timeline.isNotEmpty) ...[
                _SectionHeader(title: 'Last Hour', icon: Icons.timeline_rounded),
                const SizedBox(height: 8),
                _LiveTimeline(sessions: state.timeline),
                const SizedBox(height: 16),
              ],
              // ── 4. Insight Card ───────────────────────────────────────
              _InsightCard(score: state.score),
              const SizedBox(height: 16),
              // ── 5. 7-Day Trend ────────────────────────────────────────
              if (state.scoreHistory.length > 1) ...[
                _SectionHeader(title: '7-Day Trend', icon: Icons.bar_chart_rounded),
                const SizedBox(height: 8),
                _HistoryChart(history: state.scoreHistory),
                const SizedBox(height: 16),
              ],
              // ── 6. Study Squads ───────────────────────────────────────
              _SectionHeader(title: 'Study Squads', icon: Icons.people_rounded),
              const SizedBox(height: 8),
              _StudySquadsCard(
                onShare: (groupId) =>
                    ref.read(contextSwitchProvider.notifier).shareToSquad(groupId),
              ),
              const SizedBox(height: 16),
              // ── 7. Tips ───────────────────────────────────────────────
              _TipsCard(score: state.score),
            ],
          ),
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
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(top: 8),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          gradient: LinearGradient(colors: [
            AppColors.amber.withOpacity(0.15),
            AppColors.rose.withOpacity(0.1),
          ]),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.amber.withOpacity(0.4)),
        ),
        child: Row(children: [
          const Text('🔓', style: TextStyle(fontSize: 24)),
          const SizedBox(width: 12),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Text('Enable App Monitoring',
                  style: TextStyle(fontWeight: FontWeight.w800, fontSize: 14, fontFamily: 'Syne')),
              const SizedBox(height: 2),
              Text('Tap to grant Usage Access in Settings → allow Lumina to track context switches',
                  style: TextStyle(fontSize: 12, color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6))),
            ]),
          ),
          Icon(Icons.arrow_forward_ios_rounded, size: 14, color: AppColors.amber),
        ]),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Debt Gauge — animated arc + score
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
          Text('Cognitive Debt', style: TextStyle(
              fontFamily: 'Syne', fontWeight: FontWeight.w800, fontSize: 16,
              color: Theme.of(context).colorScheme.onSurface)),
          AnimatedBuilder(
            animation: _anim,
            builder: (_, __) => Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              decoration: BoxDecoration(
                color: _color(_anim.value).withOpacity(0.15),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: _color(_anim.value).withOpacity(0.4)),
              ),
              child: Text(_label(_anim.value),
                  style: TextStyle(color: _color(_anim.value), fontWeight: FontWeight.w700, fontSize: 11)),
            ),
          ),
        ]),
        const SizedBox(height: 20),
        SizedBox(
          height: 180,
          child: AnimatedBuilder(
            animation: _anim,
            builder: (_, __) => Stack(alignment: Alignment.center, children: [
              PieChart(PieChartData(
                startDegreeOffset: -90,
                sectionsSpace: 0,
                centerSpaceRadius: 66,
                sections: [
                  PieChartSectionData(value: _anim.value, color: _color(_anim.value), radius: 20, title: ''),
                  PieChartSectionData(value: max(0, 100 - _anim.value),
                      color: Colors.grey.withOpacity(0.12), radius: 20, title: ''),
                ],
              )),
              Column(mainAxisSize: MainAxisSize.min, children: [
                Text(_anim.value.toStringAsFixed(0),
                    style: TextStyle(fontSize: 52, fontWeight: FontWeight.w900,
                        color: _color(_anim.value), fontFamily: 'Syne')),
                Text('/100', style: TextStyle(
                    color: Theme.of(context).colorScheme.onSurface.withOpacity(0.4), fontSize: 13)),
              ]),
            ]),
          ),
        ),
        if (widget.message != null) ...[
          const SizedBox(height: 8),
          Text(widget.message!,
              style: TextStyle(fontSize: 12, color: Theme.of(context).colorScheme.onSurface.withOpacity(0.5)),
              textAlign: TextAlign.center),
        ],
      ]),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Live Timeline — horizontal scrollable app switch cards
// ─────────────────────────────────────────────────────────────────────────────
class _LiveTimeline extends StatelessWidget {
  final List<AppSession> sessions;
  const _LiveTimeline({required this.sessions});

  Color _colorFor(AppSession s) {
    if (!s.isShortSwitch) return AppColors.green;
    if (s.duration.inSeconds > 60) return AppColors.amber;
    return AppColors.rose;
  }

  @override
  Widget build(BuildContext context) {
    final reversed = sessions.reversed.toList();
    return SizedBox(
      height: 120,
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
          return Container(
            width: 100,
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: accent.withOpacity(context.isDark ? 0.12 : 0.07),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: accent.withOpacity(0.35)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                if (i == 0)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: AppColors.green.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: const Text('NOW', style: TextStyle(fontSize: 9, color: AppColors.green, fontWeight: FontWeight.w800)),
                  ),
                const Spacer(),
                Text(s.appName,
                    maxLines: 2, overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700,
                        color: Theme.of(context).colorScheme.onSurface)),
                const SizedBox(height: 4),
                Text(durLabel, style: TextStyle(fontSize: 11, color: accent, fontWeight: FontWeight.w600)),
                if (s.isShortSwitch)
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
// Study Squads Card
// ─────────────────────────────────────────────────────────────────────────────
class _StudySquadsCard extends StatefulWidget {
  final Future<void> Function(String groupId) onShare;
  const _StudySquadsCard({required this.onShare});

  @override
  State<_StudySquadsCard> createState() => _StudySquadsCardState();
}

class _StudySquadsCardState extends State<_StudySquadsCard> {
  bool _sharing = false;
  String? _sharedGroupId;

  // Mock squad members (in production: fetched from API)
  final _mockMembers = const [
    _SquadMember(alias: 'Anon#A3F2', score: 18, label: 'Zone'),
    _SquadMember(alias: 'Anon#B71C', score: 45, label: 'Moderate'),
    _SquadMember(alias: 'Anon#D99E', score: 72, label: 'High'),
    _SquadMember(alias: 'You', score: 0, label: 'You', isYou: true),
  ];

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: AppStyles.glassCard(context),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          const Text('🏆', style: TextStyle(fontSize: 20)),
          const SizedBox(width: 8),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Text('Focus Squad', style: TextStyle(fontFamily: 'Syne', fontWeight: FontWeight.w800, fontSize: 14)),
              Text('Anonymized flow graphs — social accountability',
                  style: TextStyle(fontSize: 11, color: cs.onSurface.withOpacity(0.5))),
            ]),
          ),
          _sharing
              ? const SizedBox(width: 20, height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.indigo))
              : TextButton.icon(
                  style: TextButton.styleFrom(
                    backgroundColor: AppColors.indigo.withOpacity(0.12),
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  icon: const Icon(Icons.upload_rounded, size: 14, color: AppColors.indigo),
                  label: const Text('Share', style: TextStyle(color: AppColors.indigo, fontSize: 12, fontWeight: FontWeight.w700)),
                  onPressed: () async {
                    // For demo, use a fixed group ID — in production use actual group picker
                    const demoGroupId = '00000000-0000-0000-0000-000000000001';
                    setState(() => _sharing = true);
                    await widget.onShare(demoGroupId);
                    setState(() { _sharing = false; _sharedGroupId = demoGroupId; });
                  },
                ),
        ]),
        const SizedBox(height: 14),
        // Squad leaderboard
        ..._mockMembers.map((m) => _SquadRow(member: m)),
        if (_sharedGroupId != null) ...[
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: AppColors.green.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: AppColors.green.withOpacity(0.3)),
            ),
            child: const Row(children: [
              Icon(Icons.check_circle_outline, color: AppColors.green, size: 14),
              SizedBox(width: 6),
              Text('Flow graph shared anonymously ✓',
                  style: TextStyle(fontSize: 12, color: AppColors.green, fontWeight: FontWeight.w600)),
            ]),
          ),
        ],
      ]),
    );
  }
}

class _SquadMember {
  final String alias;
  final double score;
  final String label;
  final bool isYou;
  const _SquadMember({required this.alias, required this.score, required this.label, this.isYou = false});
}

class _SquadRow extends StatelessWidget {
  final _SquadMember member;
  const _SquadRow({required this.member});

  Color _barColor(double s) {
    if (s < 25) return AppColors.green;
    if (s < 50) return AppColors.amber;
    if (s < 75) return AppColors.rose;
    return AppColors.indigo;
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final color = member.isYou ? AppColors.indigo : _barColor(member.score);
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(children: [
        SizedBox(width: 70,
          child: Text(member.alias,
              style: TextStyle(fontSize: 11, fontWeight: member.isYou ? FontWeight.w800 : FontWeight.w600,
                  color: member.isYou ? AppColors.indigo : cs.onSurface))),
        Expanded(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: member.score / 100,
              backgroundColor: cs.outline.withOpacity(0.1),
              valueColor: AlwaysStoppedAnimation(color),
              minHeight: 6,
            ),
          ),
        ),
        const SizedBox(width: 8),
        SizedBox(width: 50,
          child: Text('${member.isYou ? "Live" : member.score.toStringAsFixed(0)}',
              style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: color),
              textAlign: TextAlign.right)),
      ]),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// 7-Day History Chart
// ─────────────────────────────────────────────────────────────────────────────
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
      child: SizedBox(
        height: 120,
        child: BarChart(BarChartData(
          borderData: FlBorderData(show: false),
          gridData: FlGridData(
            show: true, drawVerticalLine: false, horizontalInterval: 25,
            getDrawingHorizontalLine: (_) => FlLine(color: cs.outline.withOpacity(0.1), strokeWidth: 1),
          ),
          titlesData: FlTitlesData(
            bottomTitles: AxisTitles(sideTitles: SideTitles(
              showTitles: true, reservedSize: 24,
              getTitlesWidget: (v, _) => Text(
                v.toInt() < days.length ? days[v.toInt()] : '',
                style: TextStyle(fontSize: 10, color: cs.onSurface.withOpacity(0.4), fontWeight: FontWeight.w600),
              ),
            )),
            leftTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
            topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
            rightTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
          ),
          maxY: 100,
          barGroups: List.generate(bars.length, (i) {
            final score = (bars[i]['score'] as num).toDouble();
            final color = score < 25 ? AppColors.green : score < 50 ? AppColors.amber
                : score < 75 ? AppColors.rose : AppColors.indigo;
            return BarChartGroupData(x: history.length - 1 - i, barRods: [
              BarChartRodData(toY: score, color: color, width: 14, borderRadius: BorderRadius.circular(4)),
            ]);
          }),
        )),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Insight Card
// ─────────────────────────────────────────────────────────────────────────────
class _InsightCard extends StatelessWidget {
  final double score;
  const _InsightCard({required this.score});

  @override
  Widget build(BuildContext context) {
    final (emoji, title, desc) = score < 25
        ? ('🧠', 'Deep Focus Mode', 'You\'re crushing it. Keep distractions away.')
        : score < 50
            ? ('⚡', 'Light Switching', 'Take a 5-min break to reset your focus.')
            : score < 75
                ? ('⚠️', 'High Cognitive Load', 'Close social apps. Focus on one task.')
                : ('🔴', 'Critical Debt!', 'Stop switching. 20-min break immediately.');
    return Container(
      decoration: AppStyles.glassCard(context),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(children: [
          Text(emoji, style: const TextStyle(fontSize: 32)),
          const SizedBox(width: 16),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(title, style: TextStyle(
                color: Theme.of(context).colorScheme.onSurface,
                fontSize: 15, fontWeight: FontWeight.w800, fontFamily: 'Syne')),
            const SizedBox(height: 4),
            Text(desc, style: TextStyle(fontSize: 13,
                color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6))),
          ])),
        ]),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Tips Card
// ─────────────────────────────────────────────────────────────────────────────
class _TipsCard extends StatelessWidget {
  final double score;
  const _TipsCard({required this.score});

  List<String> _tips() {
    if (score < 25) return [
      'Keep Lumina\'s focus mode active.',
      'Use Pomodoro: 25 min work, 5 min break.',
      'Reward yourself after each focus block.',
    ];
    if (score < 50) return [
      'Close Instagram and YouTube now.',
      'Use app timers for social media.',
      'Write distracting thoughts to revisit later.',
    ];
    if (score < 75) return [
      'Take a 10-min walk immediately.',
      'Drink water, step away from the screen.',
      'Use grayscale mode to reduce screen appeal.',
    ];
    return [
      'STOP. Take a 20-minute break now.',
      'Box breathing: 4s in, 4s hold, 4s out.',
      'Your cognitive debt resets overnight — rest!',
    ];
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
        Icon(Icons.lightbulb_outline, color: AppColors.indigo, size: 18),
        SizedBox(width: 6),
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

// ─────────────────────────────────────────────────────────────────────────────
// Section Header
// ─────────────────────────────────────────────────────────────────────────────
class _SectionHeader extends StatelessWidget {
  final String title;
  final IconData icon;
  const _SectionHeader({required this.title, required this.icon});

  @override
  Widget build(BuildContext context) => Row(children: [
    Icon(icon, size: 16, color: AppColors.indigo),
    const SizedBox(width: 6),
    Text(title, style: const TextStyle(fontFamily: 'Syne', fontWeight: FontWeight.w800, fontSize: 13, color: AppColors.indigo)),
  ]);
}

// ─────────────────────────────────────────────────────────────────────────────
// Error State
// ─────────────────────────────────────────────────────────────────────────────
class _ErrorState extends StatelessWidget {
  final String error;
  const _ErrorState({required this.error});

  @override
  Widget build(BuildContext context) => Center(
    child: Column(mainAxisSize: MainAxisSize.min, children: [
      const Icon(Icons.error_outline, size: 48, color: AppColors.rose),
      const SizedBox(height: 8),
      Text(error, textAlign: TextAlign.center,
          style: TextStyle(color: Theme.of(context).colorScheme.onSurface.withOpacity(0.5))),
    ]),
  );
}
