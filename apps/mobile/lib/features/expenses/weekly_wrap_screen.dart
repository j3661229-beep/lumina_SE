import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';
import 'expense_provider.dart';
import 'expense_cats.dart';

class WeeklyWrapScreen extends ConsumerWidget {
  const WeeklyWrapScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final wrapAsync = ref.watch(weeklyWrapProvider);
    final allAsync  = ref.watch(expenseProvider);
    final cs        = Theme.of(context).colorScheme;
    final isDark    = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF0F1117) : const Color(0xFFF7F8FD),
      body: wrapAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('$e')),
        data: (data) {
          if (data.isEmpty) {
            return Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
              const Text('📊', style: TextStyle(fontSize: 64)),
              const SizedBox(height: 12),
              const Text('Not enough data yet',
                style: TextStyle(fontWeight: FontWeight.w700, fontSize: 18)),
              const SizedBox(height: 4),
              Text('Log some expenses first', style: TextStyle(color: cs.outline)),
            ]));
          }

          // Build week map: weekStart → {category → total}
          final Map<String, Map<String, double>> byWeek = {};
          for (final row in data) {
            final week = row['week_start'].toString().split('T')[0];
            byWeek.putIfAbsent(week, () => {});
            byWeek[week]![row['category'] as String] =
                double.tryParse(row['total'].toString()) ?? 0;
          }
          final weeks = byWeek.keys.toList()..sort((a, b) => b.compareTo(a));
          final latestWeek = weeks.first;
          final latestData = byWeek[latestWeek]!;
          final weekTotal  = latestData.values.fold(0.0, (a, b) => a + b);

          // Detect top category
          String topCat = '';
          double topAmt = 0;
          latestData.forEach((k, v) { if (v > topAmt) { topAmt = v; topCat = k; } });
          final topCatMeta = catFor(topCat);

          // Budget status (₹5000 week budget — common student)
          const weekBudget = 5000.0;
          final budgetPct  = (weekTotal / weekBudget).clamp(0.0, 1.0);
          final budgetColor = budgetPct > 0.9 ? const Color(0xFFEF4444)
              : budgetPct > 0.7 ? const Color(0xFFF59E0B)
              : const Color(0xFF10B981);

          // Weekly trend (bar chart data)
          final trendWeeks = weeks.take(5).toList().reversed.toList();

          return CustomScrollView(
            slivers: [
              // ── Header ────────────────────────────────────────────────
              SliverAppBar(
                pinned: true,
                expandedHeight: 180,
                backgroundColor: cs.primary,
                leading: IconButton(
                  icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white),
                  onPressed: () => Navigator.pop(context),
                ),
                flexibleSpace: FlexibleSpaceBar(
                  background: Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topLeft, end: Alignment.bottomRight,
                        colors: [cs.primary, cs.secondary],
                      ),
                    ),
                    child: SafeArea(
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(20, 48, 20, 16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Weekly Wrap',
                              style: const TextStyle(
                                color: Colors.white, fontSize: 28,
                                fontWeight: FontWeight.w900)),
                            const SizedBox(height: 4),
                            Text(
                              'Week of ${DateFormat.MMMd().format(DateTime.tryParse(latestWeek) ?? DateTime.now())}',
                              style: const TextStyle(color: Colors.white70, fontSize: 13)),
                            const SizedBox(height: 12),
                            Row(children: [
                              Text('₹${weekTotal.toStringAsFixed(0)}',
                                style: const TextStyle(
                                  color: Colors.white, fontSize: 36,
                                  fontWeight: FontWeight.w900)),
                              const SizedBox(width: 12),
                              Chip(
                                backgroundColor: budgetColor.withOpacity(0.25),
                                label: Text(
                                  budgetPct > 0.9 ? '🔴 Over budget!' :
                                  budgetPct > 0.7 ? '🟡 Watch it' : '🟢 On track',
                                  style: TextStyle(color: budgetColor, fontWeight: FontWeight.w700, fontSize: 12),
                                ),
                              ),
                            ]),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),

              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(children: [

                    // ── Budget ring ──────────────────────────────────────
                    _Section(
                      title: 'Budget Used',
                      child: Row(children: [
                        SizedBox(
                          width: 100, height: 100,
                          child: Stack(alignment: Alignment.center, children: [
                            CircularProgressIndicator(
                              value: budgetPct,
                              strokeWidth: 10,
                              backgroundColor: budgetColor.withOpacity(0.1),
                              valueColor: AlwaysStoppedAnimation(budgetColor),
                            ),
                            Text('${(budgetPct * 100).toInt()}%',
                              style: TextStyle(fontWeight: FontWeight.w900,
                                fontSize: 22, color: budgetColor)),
                          ]),
                        ),
                        const SizedBox(width: 24),
                        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Text('₹${weekTotal.toStringAsFixed(0)} spent',
                            style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 18)),
                          const SizedBox(height: 4),
                          Text('of ₹${weekBudget.toStringAsFixed(0)} budget',
                            style: TextStyle(color: cs.outline)),
                          const SizedBox(height: 8),
                          Text(
                            budgetPct > 0.9 ? '⚠️ You\'re over budget. Try to reduce ${topCatMeta.label} spends.'
                            : budgetPct > 0.7 ? '⚡ Getting close. ${topCatMeta.emoji} ${topCatMeta.label} is your biggest spend.'
                            : '✅ Great job! You\'re well within budget this week.',
                            style: TextStyle(fontSize: 13, color: cs.onSurface, height: 1.4),
                          ),
                        ])),
                      ]),
                    ),

                    const SizedBox(height: 16),

                    // ── Pie chart ────────────────────────────────────────
                    _Section(
                      title: 'Spending Breakdown',
                      child: Row(children: [
                        Expanded(
                          flex: 5,
                          child: SizedBox(
                            height: 180,
                            child: PieChart(PieChartData(
                              sections: latestData.entries.map((e) {
                                final cat = catFor(e.key);
                                final pct = e.value / weekTotal * 100;
                                return PieChartSectionData(
                                  value: e.value,
                                  color: cat.color,
                                  title: pct >= 10 ? '${pct.toStringAsFixed(0)}%' : '',
                                  titleStyle: const TextStyle(
                                    fontSize: 11, fontWeight: FontWeight.w800, color: Colors.white),
                                  radius: 60,
                                  badgeWidget: pct < 10 ? null : Text(cat.emoji),
                                  badgePositionPercentageOffset: 1.3,
                                );
                              }).toList(),
                              sectionsSpace: 3,
                              centerSpaceRadius: 32,
                            )),
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          flex: 4,
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: (latestData.entries.toList()
                                ..sort((a, b) => b.value.compareTo(a.value)))
                                .take(5)
                                .map((e) {
                                  final cat = catFor(e.key);
                                  return Padding(
                                    padding: const EdgeInsets.symmetric(vertical: 4),
                                    child: Row(children: [
                                      Text(cat.emoji, style: const TextStyle(fontSize: 14)),
                                      const SizedBox(width: 6),
                                      Expanded(child: Text(cat.label,
                                        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
                                        overflow: TextOverflow.ellipsis)),
                                      Text('₹${e.value.toStringAsFixed(0)}',
                                        style: TextStyle(fontSize: 12,
                                          fontWeight: FontWeight.w700, color: cat.color)),
                                    ]),
                                  );
                                }).toList(),
                          ),
                        ),
                      ]),
                    ),

                    const SizedBox(height: 16),

                    // ── 5-week bar chart ─────────────────────────────────
                    if (trendWeeks.length > 1)
                      _Section(
                        title: 'Last ${trendWeeks.length} Weeks',
                        child: SizedBox(
                          height: 160,
                          child: BarChart(BarChartData(
                            alignment: BarChartAlignment.spaceAround,
                            maxY: trendWeeks.map((w) =>
                              byWeek[w]!.values.fold(0.0, (a, b) => a + b)).reduce((a, b) => a > b ? a : b) * 1.3,
                            barGroups: trendWeeks.asMap().entries.map((en) {
                              final week = en.value;
                              final tot  = byWeek[week]!.values.fold(0.0, (a, b) => a + b);
                              final isLatest = week == latestWeek;
                              return BarChartGroupData(x: en.key, barRods: [
                                BarChartRodData(
                                  toY: tot,
                                  color: isLatest ? cs.primary : cs.primaryContainer,
                                  width: 28, borderRadius: BorderRadius.circular(8),
                                  rodStackItems: byWeek[week]!.entries.map((e) {
                                    final cat   = catFor(e.key);
                                    return BarChartRodStackItem(0, e.value, cat.color);
                                  }).toList(),
                                ),
                              ]);
                            }).toList(),
                            gridData: const FlGridData(show: false),
                            borderData: FlBorderData(show: false),
                            titlesData: FlTitlesData(
                              leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                              topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                              rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                              bottomTitles: AxisTitles(sideTitles: SideTitles(
                                showTitles: true,
                                getTitlesWidget: (v, m) {
                                  final w = trendWeeks[v.toInt()];
                                  final d = DateTime.tryParse(w);
                                  return Text(d != null ? DateFormat.MMMd().format(d) : w,
                                    style: const TextStyle(fontSize: 9));
                                },
                              )),
                            ),
                          )),
                        ),
                      ),

                    const SizedBox(height: 16),

                    // ── Smart insights ───────────────────────────────────
                    _Section(
                      title: '💡 Smart Insights',
                      child: Column(children: _buildInsights(latestData, weekTotal, weeks, byWeek)
                          .map((t) => Padding(
                            padding: const EdgeInsets.symmetric(vertical: 6),
                            child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                              const Icon(Icons.arrow_right_rounded, size: 20),
                              const SizedBox(width: 4),
                              Expanded(child: Text(t, style: const TextStyle(fontSize: 13, height: 1.4))),
                            ]),
                          )).toList(),
                      ),
                    ),

                    const SizedBox(height: 96),
                  ]),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  List<String> _buildInsights(Map<String, double> week, double total,
      List<String> weeks, Map<String, Map<String, double>> byWeek) {
    final insights = <String>[];
    if (total == 0) return ['No data yet.'];

    // Top category
    String topK = ''; double topV = 0;
    week.forEach((k, v) { if (v > topV) { topV = v; topK = k; } });
    final topMeta = catFor(topK);
    insights.add('${topMeta.emoji} ${topMeta.label} is your biggest spend at ₹${topV.toStringAsFixed(0)} (${(topV/total*100).toStringAsFixed(0)}% of total).');

    // Compare to last week
    if (weeks.length >= 2) {
      final lastWeek = byWeek[weeks[1]]!;
      final lastTotal = lastWeek.values.fold(0.0, (a, b) => a + b);
      if (lastTotal > 0) {
        final diff = total - lastTotal;
        if (diff > 0) {
          insights.add('📈 You spent ₹${diff.toStringAsFixed(0)} MORE than last week. Consider cutting down on ${topMeta.label}.');
        } else {
          insights.add('📉 Great! You spent ₹${(-diff).toStringAsFixed(0)} LESS than last week. Keep it up!');
        }
      }
    }

    // Food warning
    final food = week['food'] ?? 0;
    if (food > total * 0.5) {
      insights.add('🍔 Food takes up more than 50% of your budget. Cook more, spend less!');
    }

    // Budget tip
    if (total > 4500) {
      insights.add('💳 You\'re close to your ₹5000 weekly limit. Plan your remaining expenses carefully.');
    } else if (total < 1000) {
      insights.add('🥳 Excellent frugality! You\'ve spent only ₹${total.toStringAsFixed(0)} this week.');
    }

    return insights;
  }
}

// ── Shared section card ───────────────────────────────────────────────────────
class _Section extends StatelessWidget {
  const _Section({required this.title, required this.child});
  final String title;
  final Widget child;
  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [BoxShadow(
          color: Colors.black.withOpacity(0.05),
          blurRadius: 12, offset: const Offset(0, 4))],
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(title, style: Theme.of(context).textTheme.labelLarge?.copyWith(
          fontWeight: FontWeight.w800, color: cs.primary)),
        const SizedBox(height: 12),
        child,
      ]),
    );
  }
}
