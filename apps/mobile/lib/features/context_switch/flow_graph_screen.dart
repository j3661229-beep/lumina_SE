import 'package:flutter/material.dart';
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
        title: const Text('Cognitive Flow',
          style: TextStyle(fontFamily: 'Syne', fontWeight: FontWeight.w800)),
        actions: [
          IconButton(
            icon: const Icon(Icons.auto_awesome, color: AppColors.amber),
            tooltip: 'Generate Demo Data',
            onPressed: () async {
              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Seeding demo data...')));
              await ref.read(contextSwitchProvider.notifier).seedDemoData();
              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                content: Text('✨ Demo Data Generated!'), 
                backgroundColor: AppColors.green
              ));
            },
          ),
          IconButton(
            icon: Icon(Icons.refresh_outlined, color: Theme.of(context).colorScheme.onSurface.withOpacity(0.4)),
            onPressed: () => ref.invalidate(contextSwitchProvider),
          ),
        ],
      ),
      body: stateAsync.when(
        loading: () => const FlowShimmer(),
        error: (e, _) => Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
          const Icon(Icons.error_outline, size: 48, color: AppColors.rose),
          const SizedBox(height: 8),
          Text('$e', textAlign: TextAlign.center, style: TextStyle(color: Theme.of(context).colorScheme.onSurface.withOpacity(0.5))),
        ])),
        data: (state) => RefreshIndicator(
          onRefresh: () async => ref.invalidate(contextSwitchProvider),
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.all(20),
            child: Column(children: [
              // ── Debt Dial ──
              _DebtDial(score: state.score),
              const SizedBox(height: 20),
              // ── Insight Card ──
              _InsightCard(score: state.score),
              const SizedBox(height: 20),
              // ── 7-Day History Chart ──
              if (state.history.length > 1) ...[
                _HistoryChart(history: state.history, cs: cs),
                const SizedBox(height: 20),
              ],
              // ── Tips ──
              _TipsCard(score: state.score),
            ]),
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// Debt Dial
// ─────────────────────────────────────────────────────────────
class _DebtDial extends StatelessWidget {
  final double score;
  const _DebtDial({required this.score});

  Color get _color {
    if (score < 25) return AppColors.green;
    if (score < 50) return AppColors.amber;
    if (score < 75) return AppColors.rose;
    return AppColors.indigo;
  }

  String get _label {
    if (score < 25) return 'In The Zone';
    if (score < 50) return 'Moderate';
    if (score < 75) return 'High Load';
    return 'Critical';
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: AppStyles.glassCard(context),
      child: Column(children: [
        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          Text('Cognitive Debt', style: TextStyle(color: Theme.of(context).colorScheme.onSurface, fontWeight: FontWeight.w800, fontSize: 16, fontFamily: 'Syne')),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: _color.withOpacity(0.15),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: _color.withOpacity(0.4)),
            ),
            child: Text(_label, style: TextStyle(color: _color, fontWeight: FontWeight.w700, fontSize: 10)),
          ),
        ]),
        const SizedBox(height: 20),
        SizedBox(
          height: 200,
          child: Stack(alignment: Alignment.center, children: [
            PieChart(PieChartData(
              startDegreeOffset: -90,
              sectionsSpace: 0,
              centerSpaceRadius: 70,
              sections: [
                PieChartSectionData(value: score, color: _color, radius: 22, title: ''),
                PieChartSectionData(value: 100 - score, color: Colors.grey.withOpacity(0.15), radius: 22, title: ''),
              ],
            )),
            Column(mainAxisSize: MainAxisSize.min, children: [
              Text('${score.toStringAsFixed(0)}',
                style: TextStyle(fontSize: 52, fontWeight: FontWeight.w900, color: _color, fontFamily: 'Syne')),
              Text('/100', style: TextStyle(color: Theme.of(context).colorScheme.onSurface.withOpacity(0.4), fontSize: 14, fontWeight: FontWeight.w600)),
            ]),
          ]),
        ),
      ]),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// 7-Day History Bar Chart
// ─────────────────────────────────────────────────────────────
class _HistoryChart extends StatelessWidget {
  final List<Map<String, dynamic>> history;
  final ColorScheme cs;
  const _HistoryChart({required this.history, required this.cs});

  @override
  Widget build(BuildContext context) {
    final days = ['6d', '5d', '4d', '3d', '2d', 'Yest', 'Today'];
    final bars = history.reversed.toList();

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: AppStyles.glassCard(context),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('7-Day Trend', style: TextStyle(color: Theme.of(context).colorScheme.onSurface, fontWeight: FontWeight.w800, fontSize: 14, fontFamily: 'Syne')),
        const SizedBox(height: 16),
        SizedBox(
          height: 120,
          child: BarChart(BarChartData(
            borderData: FlBorderData(show: false),
            gridData: FlGridData(
              show: true,
              drawVerticalLine: false,
              horizontalInterval: 25,
              getDrawingHorizontalLine: (_) => FlLine(color: cs.outline.withOpacity(0.1), strokeWidth: 1),
            ),
            titlesData: FlTitlesData(
              bottomTitles: AxisTitles(sideTitles: SideTitles(
                showTitles: true, reservedSize: 24,
                getTitlesWidget: (v, _) => Text(
                  v.toInt() < days.length ? days[v.toInt()] : '',
                  style: TextStyle(fontSize: 10, color: Theme.of(context).colorScheme.onSurface.withOpacity(0.4), fontWeight: FontWeight.w600),
                ),
              )),
              leftTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
              topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
              rightTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
            ),
            maxY: 100,
            barGroups: List.generate(bars.length, (i) {
              final score = (bars[i]['score'] as num).toDouble();
              Color barColor = score < 25 ? AppColors.green
                : score < 50 ? AppColors.amber
                : score < 75 ? AppColors.rose
                : AppColors.indigo;
              return BarChartGroupData(x: history.length - 1 - i, barRods: [
                BarChartRodData(toY: score, color: barColor, width: 14, borderRadius: BorderRadius.circular(4)),
              ]);
            }),
          )),
        ),
      ]),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// Insight Card
// ─────────────────────────────────────────────────────────────
class _InsightCard extends StatelessWidget {
  final double score;
  const _InsightCard({required this.score});

  @override
  Widget build(BuildContext context) {
    final (emoji, title, desc) = _content(score);
    final cs = Theme.of(context).colorScheme;
    return Container(
      decoration: AppStyles.glassCard(context),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(children: [
          Text(emoji, style: const TextStyle(fontSize: 32)),
          const SizedBox(width: 16),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(title, style: TextStyle(color: Theme.of(context).colorScheme.onSurface, fontSize: 15, fontWeight: FontWeight.w800, fontFamily: 'Syne')),
            const SizedBox(height: 4),
            Text(desc, style: TextStyle(fontSize: 13, color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6))),
          ])),
        ]),
      ),
    );
  }

  (String, String, String) _content(double s) {
    if (s < 25) return ('🧠', 'Deep Focus Mode', 'You\'re crushing it. Keep distractions away.');
    if (s < 50) return ('⚡', 'Light Switching', 'Take a 5-min break to reset your focus.');
    if (s < 75) return ('⚠️', 'High Cognitive Load', 'Close social apps. Focus on one task at a time.');
    return ('🔴', 'Critical Debt!', 'Stop switching. Take a 20-min break immediately.');
  }
}

// ─────────────────────────────────────────────────────────────
// Tips Card
// ─────────────────────────────────────────────────────────────
class _TipsCard extends StatelessWidget {
  final double score;
  const _TipsCard({required this.score});

  @override
  Widget build(BuildContext context) {
    final tips = _tips(score);
    final cs = Theme.of(context).colorScheme;
    return Container(
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
        ...tips.map((t) => Padding(
          padding: const EdgeInsets.only(bottom: 6),
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text('• ', style: TextStyle(color: AppColors.indigo, fontWeight: FontWeight.w800)),
            Expanded(child: Text(t, style: TextStyle(color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6), fontSize: 12))),
          ]),
        )),
      ]),
    );
  }

  List<String> _tips(double s) {
    if (s < 25) return [
      'Keep Lumina\'s Do Not Disturb active.',
      'Use Pomodoro: 25 min work, 5 min break.',
      'Reward yourself after completing a block.',
    ];
    if (s < 50) return [
      'Close Instagram and YouTube tabs.',
      'Use app timers for social media.',
      'Write down distracting thoughts to revisit later.',
    ];
    if (s < 75) return [
      'Take a 10-min walk immediately.',
      'Drink water and step away from your screen.',
      'Use grayscale mode to reduce screen appeal.',
    ];
    return [
      'STOP. Take a 20-minute break now.',
      'Do box breathing: 4s in, 4s hold, 4s out.',
      'Your cognitive debt resets overnight — rest!',
    ];
  }
}
