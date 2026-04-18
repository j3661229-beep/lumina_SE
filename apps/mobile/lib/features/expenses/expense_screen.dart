import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:go_router/go_router.dart';
import '../../core/theme/design_tokens.dart';
import '../../shared/widgets/shimmer_widgets.dart';
import 'expense_provider.dart';
import 'expense_cats.dart';

// Prisma Decimal fields arrive as String over JSON — handle both
double _toDouble(dynamic v) {
  if (v == null) return 0;
  if (v is num) return v.toDouble();
  return double.tryParse(v.toString()) ?? 0;
}

// ── Screen ───────────────────────────────────────────────────────────────────
class ExpenseScreen extends ConsumerStatefulWidget {
  const ExpenseScreen({super.key});
  @override
  ConsumerState<ExpenseScreen> createState() => _ExpenseScreenState();
}

class _ExpenseScreenState extends ConsumerState<ExpenseScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _fab;

  @override
  void initState() {
    super.initState();
    _fab = AnimationController(vsync: this, duration: const Duration(milliseconds: 260));
  }

  @override
  void dispose() { _fab.dispose(); super.dispose(); }

  // ── Quick-add bottom sheet ────────────────────────────────────────────────
  Future<void> _addExpense([dynamic existing]) async {
    HapticFeedback.mediumImpact();
    final amountCtrl = TextEditingController(text: existing != null ? _toDouble(existing['amount']).toStringAsFixed(2) : '');
    final noteCtrl   = TextEditingController(text: existing?['description'] as String? ?? '');
    String selCat    = existing?['category'] as String? ?? 'food';

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx2, setS) {
          final cat = catFor(selCat);
          return AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            padding: EdgeInsets.only(
              bottom: MediaQuery.of(ctx2).viewInsets.bottom + 24,
              left: 20, right: 20, top: 20,
            ),
            decoration: const BoxDecoration(
              color: Color(0xFF0F1228),
              borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
              border: Border(top: BorderSide(color: DesignColor.borderH)),
            ),
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              // Pill handle
              Container(width: 40, height: 4,
                decoration: BoxDecoration(color: DesignColor.muted, borderRadius: BorderRadius.circular(2))),
              const SizedBox(height: 16),

              // Selected category badge
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 200),
                child: Container(
                  key: ValueKey(selCat),
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(
                    color: cat.color.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: cat.color.withOpacity(0.4)),
                  ),
                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                    Text(cat.emoji, style: const TextStyle(fontSize: 20)),
                    const SizedBox(width: 8),
                    Text(cat.label, style: TextStyle(color: cat.color, fontWeight: FontWeight.w700)),
                  ]),
                ),
              ),
              const SizedBox(height: 16),

              // Category chip row
              SizedBox(
                height: 56,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  separatorBuilder: (_, __) => const SizedBox(width: 8),
                  itemCount: cats.length,
                  itemBuilder: (_, i) {
                    final c = cats[i];
                    final sel = c.key == selCat;
                    return GestureDetector(
                      onTap: () { HapticFeedback.selectionClick(); setS(() => selCat = c.key); },
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 140),
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        decoration: BoxDecoration(
                          color: sel ? c.color : c.color.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: sel ? c.color : Colors.transparent),
                        ),
                        child: Text(c.emoji, style: const TextStyle(fontSize: 22)),
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(height: 20),

              // Amount field — big and prominent
              TextFormField(
                controller: amountCtrl,
                autofocus: true,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d{0,2}'))],
                style: TextStyle(
                  fontSize: 36, fontWeight: FontWeight.w900,
                  color: cat.color,
                ),
                textAlign: TextAlign.center,
                decoration: InputDecoration(
                  filled: false,
                  border: InputBorder.none,
                  hintText: '₹ 0',
                  hintStyle: TextStyle(fontSize: 36, color: cat.color.withOpacity(0.3)),
                ),
              ),

              const SizedBox(height: 12),
              TextField(
                controller: noteCtrl,
                decoration: InputDecoration(
                  labelText: 'Note (optional)',
                  prefixIcon: const Icon(Icons.edit_note_outlined),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
              const SizedBox(height: 20),

              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  style: FilledButton.styleFrom(
                    backgroundColor: cat.color,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  ),
                  onPressed: () async {
                    final a = double.tryParse(amountCtrl.text);
                    if (a == null || a <= 0) return;
                    HapticFeedback.heavyImpact();
                    Navigator.pop(ctx);
                    final note = noteCtrl.text.trim().isEmpty ? null : noteCtrl.text.trim();
                    if (existing != null) {
                      await ref.read(expenseProvider.notifier)
                          .updateExpense(existing['id'], a, selCat, note);
                    } else {
                      await ref.read(expenseProvider.notifier)
                          .addExpense(a, selCat, note);
                    }
                  },
                  icon: const Icon(Icons.check_rounded),
                  label: Text(existing != null ? 'Update Expense' : 'Log Expense', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
                ),
              ),
            ]),
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final cs      = Theme.of(context).colorScheme;
    final isDark  = Theme.of(context).brightness == Brightness.dark;
    final expenses = ref.watch(expenseProvider);

    return Scaffold(
      backgroundColor: DesignColor.bg,
      floatingActionButton: Container(
        decoration: DesignStyles.gradientButton(),
        child: FloatingActionButton.extended(
          onPressed: _addExpense,
          backgroundColor: Colors.transparent,
          foregroundColor: Colors.white,
          elevation: 0,
          icon: const Icon(Icons.add_rounded),
          label: const Text('Log', style: TextStyle(fontWeight: FontWeight.w700)),
        ),
      ),
      body: expenses.when(
        loading: () => const ExpensesShimmer(),
        error: (e, _) => Center(
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            const Icon(Icons.wifi_off_outlined, size: 48, color: DesignColor.rose),
            const SizedBox(height: 12),
            Text('$e', textAlign: TextAlign.center, style: const TextStyle(color: DesignColor.sub)),
            const SizedBox(height: 12),
            Container(
              decoration: DesignStyles.gradientButton(),
              child: FilledButton(
                onPressed: () => ref.invalidate(expenseProvider),
                style: FilledButton.styleFrom(
                  backgroundColor: Colors.transparent,
                  foregroundColor: Colors.white,
                  elevation: 0,
                ),
                child: const Text('Retry'),
              ),
            ),
          ]),
        ),
        data: (list) => _ExpenseBody(
          expenses: list,
          onDelete: (id) => ref.read(expenseProvider.notifier).deleteExpense(id),
          onAdd: _addExpense,
          onRefresh: () => ref.refresh(expenseProvider.future),
          onWrap: () => context.push('/weekly-wrap'),
        ),
      ),
    );
  }
}

// ── Body ─────────────────────────────────────────────────────────────────────
class _ExpenseBody extends StatelessWidget {
  const _ExpenseBody({
    required this.expenses,
    required this.onDelete,
    required this.onAdd,
    required this.onRefresh,
    required this.onWrap,
  });

  final List<dynamic> expenses;
  final Future<void> Function(String) onDelete;
  final void Function([dynamic]) onAdd;
  final VoidCallback onWrap;
  final Future<void> Function() onRefresh;

  @override
  Widget build(BuildContext context) {
    final cs     = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final size   = MediaQuery.sizeOf(context);
    final now    = DateTime.now();
    final fmt    = DateFormat('yyyy-MM-dd');

    // Compute totals
    double todayTotal = 0, weekTotal = 0, monthTotal = 0;
    final weekStart = now.subtract(Duration(days: now.weekday - 1));
    for (final e in expenses) {
      final raw = e['expenseDate'] as String? ?? e['expense_date'] as String? ?? '';
      final d   = DateTime.tryParse(raw.split('T')[0]);
      final amt = _toDouble(e['amount']);
      if (d == null) continue;
      if (fmt.format(d) == fmt.format(now))   todayTotal  += amt;
      if (!d.isBefore(weekStart.subtract(const Duration(days: 1)))) weekTotal  += amt;
      if (d.month == now.month && d.year == now.year)               monthTotal += amt;
    }

    // Group by date
    final Map<String, List<dynamic>> grouped = {};
    for (final e in expenses) {
      final key = (e['expenseDate'] as String? ?? e['expense_date'] as String? ?? '').split('T')[0];
      grouped.putIfAbsent(key, () => []).add(e);
    }
    final days = grouped.keys.toList()..sort((a, b) => b.compareTo(a));

    return RefreshIndicator(
      onRefresh: onRefresh,
      child: CustomScrollView(
        slivers: [
          // ── SliverAppBar ────────────────────────────────────────────────
          SliverAppBar(
            pinned: true,
            expandedHeight: size.height > 800 ? 240 : 200,
            backgroundColor: DesignColor.indigo,
            flexibleSpace: FlexibleSpaceBar(
              background: Container(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft, end: Alignment.bottomRight,
                    colors: [DesignColor.indigo, Color(0xFF8B5CF6), DesignColor.cyan],
                  ),
                ),
                child: SafeArea(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 48, 20, 16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text('Expenses',
                              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                                color: Colors.white, fontWeight: FontWeight.w900)),
                            IconButton(
                              onPressed: onWrap,
                              icon: const Icon(Icons.bar_chart_rounded, color: Colors.white),
                              tooltip: 'Weekly Wrap',
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Row(children: [
                          _SummaryPill('Today', todayTotal, Colors.white),
                          const SizedBox(width: 12),
                          _SummaryPill('This Week', weekTotal, Colors.white70),
                          const SizedBox(width: 12),
                          _SummaryPill('Month', monthTotal, Colors.white54),
                        ]),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),

          if (expenses.isEmpty) ...[
            SliverFillRemaining(
              child: Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
                Text('💸', style: const TextStyle(fontSize: 56)),
                const SizedBox(height: 12),
                Text('No expenses yet',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
                const SizedBox(height: 4),
                Text('Tap Log to add your first one',
                  style: TextStyle(color: cs.outline)),
              ])),
            ),
          ] else ...[
            // ── Category breakdown mini bar ────────────────────────────────
            SliverToBoxAdapter(child: _CategoryBar(expenses: expenses)),

            // ── Day groups ────────────────────────────────────────────────
            for (final day in days) ...[
              SliverToBoxAdapter(child: _DayHeader(day: day, items: grouped[day]!)),
              SliverList(
                delegate: SliverChildBuilderDelegate(
                  (ctx, i) {
                    final e   = grouped[day]![i];
                    final cat = catFor(e['category'] as String? ?? 'other');
                    return _ExpenseTile(e: e, cat: cat, onDelete: onDelete, onTap: () => onAdd(e));
                  },
                  childCount: grouped[day]!.length,
                ),
              ),
            ],

            SliverToBoxAdapter(child: SizedBox(height: size.height * 0.15)),
          ],
        ],
      ),
    );
  }
}

// ── Widgets ──────────────────────────────────────────────────────────────────
class _SummaryPill extends StatelessWidget {
  const _SummaryPill(this.label, this.value, this.color);
  final String label; final double value; final Color color;
  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(label, style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.w500)),
      const SizedBox(height: 2),
      Text('₹${value.toStringAsFixed(0)}',
        style: TextStyle(color: color, fontWeight: FontWeight.w800, fontSize: 18, fontFamily: 'Syne')),
    ]);
}

class _CategoryBar extends StatelessWidget {
  const _CategoryBar({required this.expenses});
  final List<dynamic> expenses;
  @override
  Widget build(BuildContext context) {
    final totals = <String, double>{};
    for (final e in expenses) {
      final cat = e['category'] as String? ?? 'other';
      totals[cat] = (totals[cat] ?? 0) + _toDouble(e['amount']);
    }
    final total = totals.values.fold(0.0, (a, b) => a + b);
    if (total == 0) return const SizedBox.shrink();

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 16, 16, 4),
      decoration: DesignStyles.glassCard(),
      padding: const EdgeInsets.all(16),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Text('This Month by Category',
          style: TextStyle(color: DesignColor.text, fontWeight: FontWeight.w700, fontSize: 13, fontFamily: 'Syne')),
        const SizedBox(height: 12),
        // Stacked bar
        ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: SizedBox(
            height: 10,
            child: Row(
              children: totals.entries.map((entry) {
                final cat = catFor(entry.key);
                return Flexible(
                  flex: (entry.value / total * 1000).round(),
                  child: Container(color: cat.color),
                );
              }).toList(),
            ),
          ),
        ),
        const SizedBox(height: 12),
        Wrap(spacing: 12, runSpacing: 6,
          children: totals.entries.map((e) {
            final cat = catFor(e.key);
            return Row(mainAxisSize: MainAxisSize.min, children: [
              Container(width: 8, height: 8, decoration: BoxDecoration(
                color: cat.color, shape: BoxShape.circle)),
              const SizedBox(width: 6),
              Text('${cat.emoji} ₹${e.value.toStringAsFixed(0)}',
                style: const TextStyle(color: DesignColor.sub, fontSize: 11, fontWeight: FontWeight.w600)),
            ]);
          }).toList(),
        ),
      ]),
    );
  }
}

class _DayHeader extends StatelessWidget {
  const _DayHeader({required this.day, required this.items});
  final String day; final List<dynamic> items;
  @override
  Widget build(BuildContext context) {
    final d = DateTime.tryParse(day);
    final label = d == null ? day
        : DateFormat.yMMMd().format(d);
    final subtotal = items.fold<double>(
        0, (s, e) => s + _toDouble(e['amount']));
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
      child: Row(children: [
        Text(label, style: const TextStyle(
          color: DesignColor.indigo, fontWeight: FontWeight.w800, fontSize: 13, fontFamily: 'Syne')),
        const Spacer(),
        Text('₹${subtotal.toStringAsFixed(2)}',
          style: const TextStyle(color: DesignColor.muted, fontSize: 11, fontWeight: FontWeight.w600)),
      ]),
    );
  }
}

class _ExpenseTile extends StatelessWidget {
  const _ExpenseTile({required this.e, required this.cat, required this.onDelete, required this.onTap});
  final dynamic e;
  final ExpenseCat cat;
  final Future<void> Function(String) onDelete;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 3),
      child: Dismissible(
        key: Key(e['id'] as String),
        direction: DismissDirection.endToStart,
        onDismissed: (_) { HapticFeedback.mediumImpact(); onDelete(e['id'] as String); },
        background: Container(
          alignment: Alignment.centerRight,
          padding: const EdgeInsets.only(right: 20),
          decoration: BoxDecoration(
            color: DesignColor.rose.withOpacity(0.12), borderRadius: BorderRadius.circular(16)),
          child: const Icon(Icons.delete_outline_rounded, color: DesignColor.rose),
        ),
        child: Container(
          decoration: DesignStyles.glassCard(),
            child: ListTile(
              onTap: onTap,
              leading: Container(
                width: 44, height: 44,
                decoration: BoxDecoration(
                  color: cat.color.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Center(child: Text(cat.emoji, style: const TextStyle(fontSize: 22))),
              ),
              title: Text(
                e['description'] as String? ?? cat.label,
                style: const TextStyle(color: DesignColor.text, fontWeight: FontWeight.w600, fontSize: 14),
              ),
              subtitle: Text(cat.label,
                style: TextStyle(color: cat.color, fontSize: 12, fontWeight: FontWeight.w500)),
              trailing: Text(
                '₹${_toDouble(e['amount']).toStringAsFixed(2)}',
                style: TextStyle(
                  fontWeight: FontWeight.w800, color: cat.color, fontSize: 16, fontFamily: 'Syne'),
              ),
            ),
          ),
        ),
    );
  }
}
