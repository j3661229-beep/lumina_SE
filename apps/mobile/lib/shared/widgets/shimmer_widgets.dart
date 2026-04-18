import 'package:flutter/material.dart';
import 'package:shimmer/shimmer.dart';
import '../../core/theme/design_tokens.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Shared shimmer palette
// ─────────────────────────────────────────────────────────────────────────────

// Base shimmer wrapper — apply over a standard background
class AppShimmer extends StatelessWidget {
  final Widget child;
  const AppShimmer({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    final isDark = context.isDark;
    final base = isDark ? const Color(0xFF1A1D2E) : const Color(0xFFE2E8F0);
    final highlight = isDark ? const Color(0xFF2D3152) : const Color(0xFFF1F5F9);

    return Shimmer.fromColors(
      baseColor: base,
      highlightColor: highlight,
      period: const Duration(milliseconds: 1200),
      child: child,
    );
  }
}

// Utility: rounded filled box
Widget _box({double? w, double? h = 14, double r = 8}) => Container(
  width: w,
  height: h,
  decoration: BoxDecoration(
    color: Colors.white,
    borderRadius: BorderRadius.circular(r),
  ),
);

// ─────────────────────────────────────────────────────────────────────────────
// 1. Groups List Shimmer
// ─────────────────────────────────────────────────────────────────────────────
class GroupsShimmer extends StatelessWidget {
  const GroupsShimmer({super.key});

  @override
  Widget build(BuildContext context) => AppShimmer(
    child: ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: 5,
      separatorBuilder: (_, __) => const SizedBox(height: 10),
      itemBuilder: (_, __) => _GroupCardSkeleton(),
    ),
  );
}

class _GroupCardSkeleton extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final isDark = context.isDark;
    final bg = isDark ? const Color(0xFF1A1D2E) : const Color(0xFFE2E8F0);

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Container(width: 46, height: 46,
            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(14))),
          const SizedBox(width: 12),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            _box(w: 120, h: 14, r: 6),
            const SizedBox(height: 6),
            _box(w: 80, h: 10, r: 6),
          ])),
          _box(w: 40, h: 10, r: 10),
        ]),
        const SizedBox(height: 12),
        Row(children: [
          Expanded(child: _box(h: 30, r: 8)),
          const SizedBox(width: 7),
          Expanded(child: _box(h: 30, r: 8)),
          const SizedBox(width: 7),
          Expanded(child: _box(h: 30, r: 8)),
        ]),
      ]),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// 2. Timetable / Schedule Shimmer
// ─────────────────────────────────────────────────────────────────────────────
class TimetableShimmer extends StatelessWidget {
  const TimetableShimmer({super.key});

  @override
  Widget build(BuildContext context) {
    final isDark = context.isDark;
    final bg = isDark ? const Color(0xFF1A1D2E) : const Color(0xFFE2E8F0);

    return AppShimmer(
      child: ListView(padding: const EdgeInsets.all(16), children: [
        Row(children: List.generate(7, (_) => Expanded(child: Padding(
          padding: const EdgeInsets.only(right: 6),
          child: _box(h: 48, r: 12),
        )))),
        const SizedBox(height: 16),
        ...List.generate(5, (i) => Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(16)),
            child: Row(children: [
              _box(w: 4, h: 52, r: 2),
              const SizedBox(width: 12),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                _box(w: 160, h: 14, r: 6),
                const SizedBox(height: 8),
                _box(w: 100, h: 10, r: 6),
                const SizedBox(height: 6),
                _box(w: 80, h: 10, r: 6),
              ])),
              _box(w: 48, h: 48, r: 12),
            ]),
          ),
        )),
      ]),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// 3. Expenses Shimmer
// ─────────────────────────────────────────────────────────────────────────────
class ExpensesShimmer extends StatelessWidget {
  const ExpensesShimmer({super.key});

  @override
  Widget build(BuildContext context) {
    final isDark = context.isDark;
    final bg = isDark ? const Color(0xFF1A1D2E) : const Color(0xFFE2E8F0);

    return AppShimmer(
      child: ListView(padding: const EdgeInsets.all(16), children: [
        Container(
          height: 130,
          decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(20)),
          padding: const EdgeInsets.all(18),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            _box(w: 90, h: 12, r: 6),
            const SizedBox(height: 10),
            _box(w: 160, h: 28, r: 8),
            const Spacer(),
            Row(children: [
              Expanded(child: _box(h: 12, r: 6)),
              const SizedBox(width: 16),
              Expanded(child: _box(h: 12, r: 6)),
            ]),
          ]),
        ),
        const SizedBox(height: 16),
        ...List.generate(6, (i) => Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(14)),
            child: Row(children: [
              _box(w: 40, h: 40, r: 10),
              const SizedBox(width: 12),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                _box(w: 130, h: 13, r: 6),
                const SizedBox(height: 6),
                _box(w: 80, h: 10, r: 6),
              ])),
              _box(w: 60, h: 14, r: 6),
            ]),
          ),
        )),
      ]),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// 4. Kanban Board Shimmer
// ─────────────────────────────────────────────────────────────────────────────
class KanbanShimmer extends StatelessWidget {
  const KanbanShimmer({super.key});

  @override
  Widget build(BuildContext context) {
    final isDark = context.isDark;
    final bg = isDark ? const Color(0xFF1A1D2E) : const Color(0xFFE2E8F0);
    final highlight = isDark ? const Color(0xFF2D3152) : const Color(0xFFF1F5F9);

    return AppShimmer(
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.all(16),
        children: List.generate(4, (_) => Container(
          width: 270,
          margin: const EdgeInsets.only(right: 16),
          decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(20)),
          child: Column(children: [
            Container(
              padding: const EdgeInsets.all(16),
              child: Row(children: [
                _box(w: 24, h: 24, r: 6),
                const SizedBox(width: 8),
                Expanded(child: _box(h: 14, r: 6)),
              ]),
            ),
            Divider(height: 1, color: AppColors.border(context)),
            Expanded(child: ListView.builder(
              padding: const EdgeInsets.all(10),
              itemCount: 3,
              itemBuilder: (_, __) => Container(
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: highlight,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  _box(h: 14, r: 6),
                  const SizedBox(height: 8),
                  _box(w: 180, h: 10, r: 6),
                ]),
              ),
            )),
          ]),
        )),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// 5. Group Chat Shimmer
// ─────────────────────────────────────────────────────────────────────────────
class ChatShimmer extends StatelessWidget {
  const ChatShimmer({super.key});

  @override
  Widget build(BuildContext context) {
    final isDark = context.isDark;
    final bg = isDark ? const Color(0xFF1A1D2E) : const Color(0xFFE2E8F0);

    return AppShimmer(
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        reverse: true,
        itemCount: 10,
        itemBuilder: (_, i) {
          final isMe = i % 3 == 0;
          return Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Row(
              mainAxisAlignment: isMe ? MainAxisAlignment.end : MainAxisAlignment.start,
              children: [
                if (!isMe) ...[_box(w: 28, h: 28, r: 14), const SizedBox(width: 8)],
                Container(
                  width: 140 + (i % 3) * 40.0,
                  height: 48,
                  decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(16)),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// 6. Profile Shimmer
// ─────────────────────────────────────────────────────────────────────────────
class ProfileShimmer extends StatelessWidget {
  const ProfileShimmer({super.key});

  @override
  Widget build(BuildContext context) {
    final isDark = context.isDark;
    final bg = isDark ? const Color(0xFF1A1D2E) : const Color(0xFFE2E8F0);

    return AppShimmer(
      child: ListView(padding: const EdgeInsets.all(20), children: [
        Center(child: Column(children: [
          _box(w: 96, h: 96, r: 48),
          const SizedBox(height: 14),
          _box(w: 140, h: 18, r: 8),
        ])),
        const SizedBox(height: 24),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(20)),
          child: Row(children: List.generate(3, (_) => Expanded(child: _box(h: 20, r: 8)))),
        ),
        const SizedBox(height: 16),
        ...List.generate(4, (_) => Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: Row(children: [
            _box(w: 40, h: 40, r: 10),
            const SizedBox(width: 12),
            Expanded(child: _box(h: 16, r: 8)),
          ]),
        )),
      ]),
    );
  }
}

// (Remaining shimmers follow same pattern...)
class CardListShimmer extends StatelessWidget {
  final int count;
  final double cardHeight;
  const CardListShimmer({super.key, this.count = 6, this.cardHeight = 70});

  @override
  Widget build(BuildContext context) {
    final isDark = context.isDark;
    final bg = isDark ? const Color(0xFF1A1D2E) : const Color(0xFFE2E8F0);

    return AppShimmer(
      child: ListView.separated(
        padding: const EdgeInsets.all(16),
        itemCount: count,
        separatorBuilder: (_, __) => const SizedBox(height: 10),
        itemBuilder: (_, __) => Container(
          height: cardHeight,
          decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(14)),
        ),
      ),
    );
  }
}

class FlowShimmer extends StatelessWidget {
  const FlowShimmer({super.key});

  @override
  Widget build(BuildContext context) {
    final isDark = context.isDark;
    final bg = isDark ? const Color(0xFF1A1D2E) : const Color(0xFFE2E8F0);

    return AppShimmer(
      child: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Container(
            height: 240,
            decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(24)),
          ),
          const SizedBox(height: 20),
          Container(
            height: 80,
            decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(20)),
          ),
          const SizedBox(height: 20),
          Container(
            height: 160,
            decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(20)),
          ),
          const SizedBox(height: 20),
          Container(
            height: 120,
            decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(20)),
          ),
        ],
      ),
    );
  }
}
