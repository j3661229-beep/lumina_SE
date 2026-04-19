import 'package:flutter/material.dart';
import 'package:flutter/material.dart'; // flutter-force-rebuild
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:go_router/go_router.dart';
import '../../core/theme/design_tokens.dart';
import 'expense_provider.dart';
import 'expense_cats.dart';

double _asDouble(dynamic v) {
  if (v == null) return 0;
  if (v is num) return v.toDouble();
  return double.tryParse(v.toString()) ?? 0;
}

// Backend returns 'expenseDate' (Prisma camelCase), fallback to 'date'
String? _expDate(dynamic e) =>
    (e['expenseDate'] as String?) ?? (e['date'] as String?);

// ── Screen ────────────────────────────────────────────────────────────────────
class ExpenseScreen extends ConsumerStatefulWidget {
  const ExpenseScreen({super.key});
  @override
  ConsumerState<ExpenseScreen> createState() => _ExpenseScreenState();
}

class _ExpenseScreenState extends ConsumerState<ExpenseScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabCtrl;

  @override
  void initState() {
    super.initState();
    _tabCtrl = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabCtrl.dispose();
    super.dispose();
  }

  Future<void> _addExpense([dynamic existing]) async {
    HapticFeedback.mediumImpact();
    final amountCtrl = TextEditingController(
        text: existing != null ? _asDouble(existing['amount']).toStringAsFixed(2) : '');
    final noteCtrl = TextEditingController(text: existing?['description'] ?? '');
    String selCat = existing?['category'] ?? 'food';

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(builder: (ctx2, setS) {
        final cat = catFor(selCat);
        final cs = Theme.of(ctx2).colorScheme;
        return Container(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(ctx2).viewInsets.bottom + 24,
            left: 20, right: 20, top: 8,
          ),
          decoration: BoxDecoration(
            color: Theme.of(ctx2).colorScheme.surface,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
            boxShadow: context.isDark ? [] : [
              BoxShadow(color: Colors.black.withOpacity(0.12), blurRadius: 40, offset: const Offset(0, -4))
            ],
          ),
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
            // Pull handle
            Center(child: Container(
              width: 40, height: 4, margin: const EdgeInsets.only(bottom: 20),
              decoration: BoxDecoration(
                color: cs.onSurface.withOpacity(0.15),
                borderRadius: BorderRadius.circular(2)),
            )),
            Text(existing == null ? 'Add Expense' : 'Edit Expense',
              style: TextStyle(fontFamily: 'Syne', fontWeight: FontWeight.w700, fontSize: 20, color: cs.onSurface)),
            const SizedBox(height: 20),
            // Amount Field
            TextField(
              controller: amountCtrl,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              style: TextStyle(fontSize: 32, fontWeight: FontWeight.w800, fontFamily: 'Syne', color: cs.onSurface),
              decoration: InputDecoration(
                hintText: '0.00',
                hintStyle: TextStyle(color: cs.onSurface.withOpacity(0.25), fontSize: 32, fontFamily: 'Syne'),
                prefixIcon: Padding(
                  padding: const EdgeInsets.only(left: 16, right: 8, top: 4),
                  child: Text('₹', style: TextStyle(fontSize: 28, fontWeight: FontWeight.w700, color: AppColors.indigo)),
                ),
                prefixIconConstraints: const BoxConstraints(minWidth: 0, minHeight: 0),
                border: InputBorder.none, enabledBorder: InputBorder.none, focusedBorder: InputBorder.none,
                filled: false,
              ),
            ),
            const SizedBox(height: 4),
            // Category pills
            Text('Category', style: TextStyle(color: cs.onSurface.withOpacity(0.5), fontSize: 12, fontWeight: FontWeight.w600)),
            const SizedBox(height: 10),
            Wrap(spacing: 8, runSpacing: 8,
              children: kExpInsightCats.map((c) {
                final sel = selCat == c.key;
                return GestureDetector(
                  onTap: () => setS(() => selCat = c.key),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 160),
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: sel ? c.color.withOpacity(0.15) : AppColors.surfaceContainer(ctx2),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: sel ? c.color.withOpacity(0.5) : AppColors.border(ctx2)),
                    ),
                    child: Row(mainAxisSize: MainAxisSize.min, children: [
                      Icon(c.icon, size: 14, color: sel ? c.color : cs.onSurface.withOpacity(0.4)),
                      const SizedBox(width: 6),
                      Text(c.label, style: TextStyle(
                        color: sel ? c.color : cs.onSurface.withOpacity(0.5),
                        fontSize: 12, fontWeight: FontWeight.w600)),
                    ]),
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 16),
            // Note field
            TextField(
              controller: noteCtrl,
              style: TextStyle(fontSize: 14, color: cs.onSurface),
              decoration: InputDecoration(
                hintText: 'Add a note (optional)',
                prefixIcon: Icon(Icons.notes_rounded, size: 18, color: cs.onSurface.withOpacity(0.35)),
                filled: true,
                fillColor: AppColors.surfaceContainer(ctx2),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
              ),
            ),
            const SizedBox(height: 20),
            SizedBox(width: double.infinity,
              child: GestureDetector(
                onTap: () async {
                  final amt = double.tryParse(amountCtrl.text) ?? 0;
                  if (amt <= 0) return;
                  Navigator.pop(ctx2);
                  final data = {
                    'amount': amt, 'category': selCat,
                    'description': noteCtrl.text.isEmpty ? catFor(selCat).label : noteCtrl.text,
                    'date': DateTime.now().toIso8601String(),
                  };
                  if (existing == null) {
                    await ref.read(expensesProvider.notifier).add(data);
                  } else {
                    await ref.read(expensesProvider.notifier).updateRecord(existing['id'], data);
                  }
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  decoration: DesignStyles.gradientButton(),
                  child: const Center(child: Text('Save Expense',
                    style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 15))),
                ),
              ),
            ),
          ]),
        );
      }),
    );
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isDark = context.isDark;
    final expAsync = ref.watch(expensesProvider);

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: NestedScrollView(
        headerSliverBuilder: (ctx, _) => [
          SliverAppBar(
            expandedHeight: 200,
            pinned: true,
            stretch: true,
            elevation: 0,
            backgroundColor: isDark ? AppColors.darkBg : const Color(0xFF059669),
            systemOverlayStyle: SystemUiOverlayStyle.light,
            flexibleSpace: FlexibleSpaceBar(
              collapseMode: CollapseMode.parallax,
              background: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: isDark
                        ? [const Color(0xFF064E3B), const Color(0xFF080B1F)]
                        : [const Color(0xFF059669), const Color(0xFF10B981)],
                    begin: Alignment.topLeft, end: Alignment.bottomRight,
                  ),
                ),
                child: Stack(children: [
                  // Decorative circle
                  Positioned(top: -30, right: -40,
                    child: Container(
                      width: 200, height: 200,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: RadialGradient(colors: [
                          Colors.white.withOpacity(0.07), Colors.transparent])),
                    ),
                  ),
                  SafeArea(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
                      child: expAsync.when(
                        loading: () => const SizedBox(),
                        error: (_, __) => const SizedBox(),
                        data: (expenses) {
                          final now = DateTime.now();
                          double monthTotal = 0; int monthCount = 0;
                          double weekTotal = 0;
                          for (final e in expenses) {
                            final d = DateTime.tryParse(_expDate(e) ?? '');
                            if (d != null && d.month == now.month && d.year == now.year) {
                              monthTotal += _asDouble(e['amount']); monthCount++;
                            }
                            if (d != null && now.difference(d).inDays < 7) {
                              weekTotal += _asDouble(e['amount']);
                            }
                          }
                          return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                            Row(children: [
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                decoration: BoxDecoration(
                                  color: Colors.white.withOpacity(0.15),
                                  borderRadius: BorderRadius.circular(20),
                                  border: Border.all(color: Colors.white.withOpacity(0.2)),
                                ),
                                child: Row(mainAxisSize: MainAxisSize.min, children: [
                                  const Icon(Icons.calendar_month_rounded,
                                      color: Colors.white70, size: 11),
                                  const SizedBox(width: 4),
                                  Text(DateFormat('MMMM yyyy').format(now),
                                    style: const TextStyle(color: Colors.white70, fontSize: 10,
                                      fontWeight: FontWeight.w600)),
                                ]),
                              ),
                              const Spacer(),
                              GestureDetector(
                                onTap: () => context.push('/weekly-wrap'),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                                  decoration: BoxDecoration(
                                    color: Colors.white.withOpacity(0.15),
                                    borderRadius: BorderRadius.circular(20),
                                    border: Border.all(color: Colors.white.withOpacity(0.25)),
                                  ),
                                  child: const Row(mainAxisSize: MainAxisSize.min, children: [
                                    Icon(Icons.bar_chart_rounded, color: Colors.white, size: 13),
                                    SizedBox(width: 5),
                                    Text('Weekly Wrap', style: TextStyle(
                                      color: Colors.white, fontSize: 11, fontWeight: FontWeight.w700)),
                                  ]),
                                ),
                              ),
                            ]),
                            const SizedBox(height: 10),
                            Text('This Month', style: TextStyle(
                              color: Colors.white.withOpacity(0.7), fontSize: 12)),
                            Text('₹${monthTotal.toStringAsFixed(0)}',
                              style: const TextStyle(
                                fontFamily: 'Syne', fontWeight: FontWeight.w800,
                                fontSize: 38, color: Colors.white, height: 1.1)),
                            const SizedBox(height: 6),
                            Row(children: [
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                decoration: BoxDecoration(
                                  color: Colors.white.withOpacity(0.15),
                                  borderRadius: BorderRadius.circular(20)),
                                child: Text('$monthCount transactions',
                                  style: const TextStyle(color: Colors.white70, fontSize: 10,
                                    fontWeight: FontWeight.w600)),
                              ),
                              const SizedBox(width: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                decoration: BoxDecoration(
                                  color: Colors.white.withOpacity(0.15),
                                  borderRadius: BorderRadius.circular(20)),
                                child: Text('₹${weekTotal.toStringAsFixed(0)} this week',
                                  style: const TextStyle(color: Colors.white70, fontSize: 10,
                                    fontWeight: FontWeight.w600)),
                              ),
                            ]),
                          ]);
                        },
                      ),
                    ),
                  ),
                ]),
              ),
            ),
            title: const Text('Finance',
              style: TextStyle(fontFamily: 'Syne', fontWeight: FontWeight.w800,
                color: Colors.white, fontSize: 18)),
          ),
          // Category filter tabs
          SliverToBoxAdapter(
            child: Container(
              color: Theme.of(context).scaffoldBackgroundColor,
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(children: [
                  _CatChip(label: 'All', icon: Icons.grid_view_rounded, color: AppColors.indigo,
                    selected: true, onTap: () {}),
                  const SizedBox(width: 8),
                  ...kExpInsightCats.take(5).map((c) => Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: _CatChip(label: c.label, icon: c.icon, color: c.color,
                      selected: false, onTap: () {}),
                  )),
                ]),
              ),
            ),
          ),
        ],
        body: expAsync.when(
          loading: () => const Center(child: CircularProgressIndicator(color: AppColors.indigo)),
          error: (e, _) => Center(child: Text('$e', style: TextStyle(color: AppColors.rose))),
          data: (expenses) {
            if (expenses.isEmpty) return _buildEmpty();
            final sorted = [...expenses]..sort((a, b) {
              final da = DateTime.tryParse(_expDate(a) ?? '') ?? DateTime(0);
              final db = DateTime.tryParse(_expDate(b) ?? '') ?? DateTime(0);
              return db.compareTo(da);
            });
            return ListView.builder(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
              itemCount: sorted.length,
              itemBuilder: (ctx, i) => _ExpenseTile(
                expense: sorted[i],
                onEdit: () => _addExpense(sorted[i]),
                onDelete: () => ref.read(expensesProvider.notifier).delete(sorted[i]['id']),
              ),
            );
          },
        ),
      ),
      floatingActionButton: Container(
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [AppColors.green, Color(0xFF059669)],
            begin: Alignment.topLeft, end: Alignment.bottomRight),
          borderRadius: BorderRadius.circular(18),
          boxShadow: const [
            BoxShadow(color: Color(0x5510B981), blurRadius: 20, offset: Offset(0, 6))],
        ),
        child: FloatingActionButton.extended(
          onPressed: () => _addExpense(),
          backgroundColor: Colors.transparent,
          foregroundColor: Colors.white,
          elevation: 0,
          icon: const Icon(Icons.add_rounded),
          label: const Text('Log Expense',
            style: TextStyle(fontWeight: FontWeight.w700, fontFamily: 'Syne')),
        ),
      ),
    );
  }

  Widget _buildEmpty() {
    final cs = Theme.of(context).colorScheme;
    return Center(child: Padding(
      padding: const EdgeInsets.all(40),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Container(padding: const EdgeInsets.all(28),
          decoration: BoxDecoration(
            shape: BoxShape.circle, 
            color: AppColors.green.withOpacity(context.isDark ? 0.15 : 0.08)
          ),
          child: const Icon(Icons.account_balance_wallet_outlined, color: AppColors.green, size: 48)),
        const SizedBox(height: 20),
        Text('No Expenses Yet', style: TextStyle(
          fontFamily: 'Syne', fontWeight: FontWeight.w700, fontSize: 20, color: cs.onSurface)),
        const SizedBox(height: 8),
        Text('Track where your money goes. Add your first expense!',
          textAlign: TextAlign.center,
          style: TextStyle(color: cs.onSurface.withOpacity(0.5), fontSize: 13, height: 1.5)),
      ]),
    ));
  }
}

class _ExpenseTile extends StatelessWidget {
  final Map expense;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  const _ExpenseTile({required this.expense, required this.onEdit, required this.onDelete});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final cat = catFor(expense['category'] as String? ?? 'other');
    final amount = _asDouble(expense['amount']);
    final date = DateTime.tryParse(_expDate(expense) ?? '');
    final dateStr = date != null ? DateFormat('d MMM, EEE').format(date) : '';
    final desc = expense['description'] as String? ?? cat.label;

    return Dismissible(
      key: Key(expense['id']?.toString() ?? desc),
      direction: DismissDirection.endToStart,
      onDismissed: (_) => onDelete(),
      background: Container(
        margin: const EdgeInsets.only(bottom: 8),
        decoration: BoxDecoration(
          color: AppColors.rose.withOpacity(0.1),
          borderRadius: BorderRadius.circular(16),
        ),
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        child: const Icon(Icons.delete_outline_rounded, color: AppColors.rose),
      ),
      child: GestureDetector(
        onTap: onEdit,
        child: Container(
          margin: const EdgeInsets.only(bottom: 8),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: DesignStyles.card(context, radius: 16),
          child: Row(children: [
            Container(
              width: 46, height: 46,
              decoration: BoxDecoration(
                color: cat.color.withOpacity(0.12),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(cat.icon, color: cat.color, size: 22),
            ),
            const SizedBox(width: 14),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(desc, style: TextStyle(
                fontWeight: FontWeight.w600, fontSize: 14, color: cs.onSurface),
                maxLines: 1, overflow: TextOverflow.ellipsis),
              const SizedBox(height: 3),
              Row(children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: cat.color.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(cat.label, style: TextStyle(
                    color: cat.color, fontSize: 10, fontWeight: FontWeight.w600)),
                ),
                const SizedBox(width: 6),
                Text(dateStr, style: TextStyle(
                  color: cs.onSurface.withOpacity(0.4), fontSize: 11)),
              ]),
            ])),
            Text('₹${amount.toStringAsFixed(0)}',
              style: const TextStyle(fontFamily: 'Syne', fontWeight: FontWeight.w800,
                fontSize: 16, color: AppColors.rose)),
          ]),
        ),
      ),
    );
  }
}

class _ActionBtn extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;
  const _ActionBtn({required this.icon, required this.label, required this.color, required this.onTap});

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(icon, color: color, size: 16),
        const SizedBox(width: 6),
        Text(label, style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.w600)),
      ]),
    ),
  );
}

class _CatChip extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color color;
  final bool selected;
  final VoidCallback onTap;
  const _CatChip({required this.label, required this.icon, required this.color, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: selected ? color.withOpacity(0.15) : cs.onSurface.withOpacity(0.05),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: selected ? color.withOpacity(0.4) : Colors.transparent),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(icon, size: 14, color: selected ? color : cs.onSurface.withOpacity(0.4)),
          const SizedBox(width: 6),
          Text(label, style: TextStyle(
            color: selected ? color : cs.onSurface.withOpacity(0.5),
            fontSize: 12, fontWeight: FontWeight.w600)),
        ]),
      ),
    );
  }
}

class _TabHeaderDelegate extends SliverPersistentHeaderDelegate {
  final Widget child;
  const _TabHeaderDelegate({required this.child});

  @override
  Widget build(BuildContext ctx, double shrinkOffset, bool overlapsContent) => child;
  @override double get maxExtent => 56;
  @override double get minExtent => 56;
  @override bool shouldRebuild(_) => false;
}
