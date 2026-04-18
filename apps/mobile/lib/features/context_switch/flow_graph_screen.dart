import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fl_chart/fl_chart.dart';
import 'context_switch_provider.dart';

class FlowGraphScreen extends ConsumerWidget {
  const FlowGraphScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final stateAsync = ref.watch(contextSwitchProvider);
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Cognitive Flow'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_outlined),
            onPressed: () => ref.invalidate(contextSwitchProvider),
          ),
        ],
      ),
      body: stateAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
          const Icon(Icons.error_outline, size: 48, color: Colors.red),
          const SizedBox(height: 8),
          Text('$e', textAlign: TextAlign.center),
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
    if (score < 25) return const Color(0xFF10B981);
    if (score < 50) return const Color(0xFFF59E0B);
    if (score < 75) return const Color(0xFFEF4444);
    return const Color(0xFF7C3AED);
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
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [_color.withOpacity(0.12), _color.withOpacity(0.04)],
          begin: Alignment.topLeft, end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: _color.withOpacity(0.25), width: 1.5),
      ),
      child: Column(children: [
        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          Text('Cognitive Debt', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(color: _color.withOpacity(0.15), borderRadius: BorderRadius.circular(20)),
            child: Text(_label, style: TextStyle(color: _color, fontWeight: FontWeight.w700, fontSize: 12)),
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
                style: TextStyle(fontSize: 52, fontWeight: FontWeight.w900, color: _color)),
              Text('/100', style: TextStyle(color: Theme.of(context).colorScheme.outline, fontSize: 14)),
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
      decoration: BoxDecoration(
        color: cs.surfaceContainerHighest.withOpacity(0.5),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('7-Day Trend', style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700)),
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
                  style: TextStyle(fontSize: 10, color: cs.outline),
                ),
              )),
              leftTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
              topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
              rightTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
            ),
            maxY: 100,
            barGroups: List.generate(bars.length, (i) {
              final score = (bars[i]['score'] as num).toDouble();
              Color barColor = score < 25 ? const Color(0xFF10B981)
                : score < 50 ? const Color(0xFFF59E0B)
                : score < 75 ? const Color(0xFFEF4444)
                : const Color(0xFF7C3AED);
              return BarChartGroupData(x: history.length - 1 - i, barRods: [
                BarChartRodData(toY: score, color: barColor, width: 16, borderRadius: BorderRadius.circular(4)),
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
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(children: [
          Text(emoji, style: const TextStyle(fontSize: 36)),
          const SizedBox(width: 16),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(title, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
            const SizedBox(height: 4),
            Text(desc, style: TextStyle(fontSize: 13, color: cs.outline)),
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
        color: cs.primaryContainer.withOpacity(0.3),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: cs.primary.withOpacity(0.2)),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Icon(Icons.lightbulb_outline, color: cs.primary, size: 18),
          const SizedBox(width: 6),
          Text('Focus Tips', style: TextStyle(fontWeight: FontWeight.w700, color: cs.primary)),
        ]),
        const SizedBox(height: 10),
        ...tips.map((t) => Padding(
          padding: const EdgeInsets.only(bottom: 6),
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('• ', style: TextStyle(color: cs.primary, fontWeight: FontWeight.w700)),
            Expanded(child: Text(t, style: const TextStyle(fontSize: 13))),
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
