import 'package:flutter/material.dart';
import 'package:shimmer/shimmer.dart';
import '../../core/theme/design_tokens.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Shared shimmer palette — matches the dark DesignColor theme
// ─────────────────────────────────────────────────────────────────────────────
const _kBase    = Color(0xFF1A1D2E);
const _kHighlight = Color(0xFF2D3152);

// Base shimmer wrapper — apply over a dark background
class AppShimmer extends StatelessWidget {
  final Widget child;
  const AppShimmer({super.key, required this.child});

  @override
  Widget build(BuildContext context) => Shimmer.fromColors(
    baseColor: _kBase,
    highlightColor: _kHighlight,
    period: const Duration(milliseconds: 1200),
    child: child,
  );
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
// 1. Groups List Shimmer — replaces CircularProgressIndicator on Groups screen
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
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(
      color: _kBase,
      borderRadius: BorderRadius.circular(18),
    ),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [
        // Avatar
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

// ─────────────────────────────────────────────────────────────────────────────
// 2. Timetable / Schedule Shimmer
// ─────────────────────────────────────────────────────────────────────────────
class TimetableShimmer extends StatelessWidget {
  const TimetableShimmer({super.key});

  @override
  Widget build(BuildContext context) => AppShimmer(
    child: ListView(padding: const EdgeInsets.all(16), children: [
      // Day tab row
      Row(children: List.generate(7, (_) => Expanded(child: Padding(
        padding: const EdgeInsets.only(right: 6),
        child: _box(h: 48, r: 12),
      )))),
      const SizedBox(height: 16),
      // Class cards
      ...List.generate(5, (i) => Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(color: _kBase, borderRadius: BorderRadius.circular(16)),
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

// ─────────────────────────────────────────────────────────────────────────────
// 3. Expenses Shimmer
// ─────────────────────────────────────────────────────────────────────────────
class ExpensesShimmer extends StatelessWidget {
  const ExpensesShimmer({super.key});

  @override
  Widget build(BuildContext context) => AppShimmer(
    child: ListView(padding: const EdgeInsets.all(16), children: [
      // Summary card
      Container(
        height: 130,
        decoration: BoxDecoration(color: _kBase, borderRadius: BorderRadius.circular(20)),
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
      // Transaction rows
      ...List.generate(6, (i) => Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(color: _kBase, borderRadius: BorderRadius.circular(14)),
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

// ─────────────────────────────────────────────────────────────────────────────
// 4. Kanban Board Shimmer
// ─────────────────────────────────────────────────────────────────────────────
class KanbanShimmer extends StatelessWidget {
  const KanbanShimmer({super.key});

  @override
  Widget build(BuildContext context) => AppShimmer(
    child: ListView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.all(16),
      children: List.generate(4, (_) => Container(
        width: 270,
        margin: const EdgeInsets.only(right: 16),
        decoration: BoxDecoration(color: _kBase, borderRadius: BorderRadius.circular(20)),
        child: Column(children: [
          // Column header
          Container(
            margin: const EdgeInsets.all(12),
            child: Row(children: [
              _box(w: 24, h: 24, r: 6),
              const SizedBox(width: 8),
              Expanded(child: _box(h: 14, r: 6)),
              const SizedBox(width: 8),
              _box(w: 28, h: 28, r: 14),
            ]),
          ),
          const Divider(height: 1, color: DesignColor.border),
          // Task cards
          Expanded(child: ListView.builder(
            padding: const EdgeInsets.all(10),
            itemCount: 3,
            itemBuilder: (_, __) => Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: _kHighlight,
                borderRadius: BorderRadius.circular(14),
                border: const Border(left: BorderSide(color: Colors.white24, width: 4)),
              ),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                _box(h: 14, r: 6),
                const SizedBox(height: 8),
                _box(w: 180, h: 10, r: 6),
                const SizedBox(height: 10),
                Row(children: [
                  _box(w: 50, h: 18, r: 6),
                  const SizedBox(width: 8),
                  _box(w: 70, h: 10, r: 6),
                ]),
              ]),
            ),
          )),
        ]),
      )),
    ),
  );
}

// ─────────────────────────────────────────────────────────────────────────────
// 5. Group Chat Shimmer
// ─────────────────────────────────────────────────────────────────────────────
class ChatShimmer extends StatelessWidget {
  const ChatShimmer({super.key});

  @override
  Widget build(BuildContext context) => AppShimmer(
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
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              if (!isMe) ...[
                _box(w: 28, h: 28, r: 14),
                const SizedBox(width: 8),
              ],
              Column(
                crossAxisAlignment: isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
                children: [
                  if (!isMe) ...[_box(w: 60, h: 10, r: 6), const SizedBox(height: 4)],
                  Container(
                    width: 180 + (i % 3) * 30.0,
                    height: 40 + (i % 2) * 16.0,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    ),
  );
}

// ─────────────────────────────────────────────────────────────────────────────
// 6. Profile Shimmer
// ─────────────────────────────────────────────────────────────────────────────
class ProfileShimmer extends StatelessWidget {
  const ProfileShimmer({super.key});

  @override
  Widget build(BuildContext context) => AppShimmer(
    child: ListView(padding: const EdgeInsets.all(20), children: [
      // Avatar + name header
      Center(child: Column(children: [
        _box(w: 96, h: 96, r: 48),
        const SizedBox(height: 14),
        _box(w: 140, h: 18, r: 8),
        const SizedBox(height: 8),
        _box(w: 200, h: 12, r: 6),
      ])),
      const SizedBox(height: 24),
      // Stats row
      Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(color: _kBase, borderRadius: BorderRadius.circular(20)),
        child: Row(children: List.generate(3, (i) => Expanded(child: Column(children: [
          _box(w: 40, h: 20, r: 8),
          const SizedBox(height: 6),
          _box(w: 60, h: 10, r: 6),
        ])))),
      ),
      const SizedBox(height: 16),
      // Setting rows
      ...List.generate(5, (_) => Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(color: _kBase, borderRadius: BorderRadius.circular(14)),
          child: Row(children: [
            _box(w: 36, h: 36, r: 10),
            const SizedBox(width: 14),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              _box(w: 100, h: 13, r: 6),
              const SizedBox(height: 6),
              _box(w: 160, h: 10, r: 6),
            ])),
            _box(w: 24, h: 24, r: 6),
          ]),
        ),
      )),
    ]),
  );
}

// ─────────────────────────────────────────────────────────────────────────────
// 7. Flow / Context-Switch Graph Shimmer
// ─────────────────────────────────────────────────────────────────────────────
class FlowShimmer extends StatelessWidget {
  const FlowShimmer({super.key});

  @override
  Widget build(BuildContext context) => AppShimmer(
    child: ListView(padding: const EdgeInsets.all(16), children: [
      // Graph area
      Container(
        height: 220,
        decoration: BoxDecoration(color: _kBase, borderRadius: BorderRadius.circular(20)),
        padding: const EdgeInsets.all(16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          _box(w: 120, h: 14, r: 6),
          const SizedBox(height: 8),
          _box(w: 80, h: 10, r: 6),
        ]),
      ),
      const SizedBox(height: 16),
      ...List.generate(4, (_) => Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(color: _kBase, borderRadius: BorderRadius.circular(14)),
          child: Row(children: [
            _box(w: 40, h: 40, r: 20),
            const SizedBox(width: 12),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              _box(w: 100, h: 13, r: 6),
              const SizedBox(height: 6),
              _box(h: 10, r: 6),
            ])),
          ]),
        ),
      )),
    ]),
  );
}

// ─────────────────────────────────────────────────────────────────────────────
// 8. Generic card list shimmer — reusable for any screen
// ─────────────────────────────────────────────────────────────────────────────
class CardListShimmer extends StatelessWidget {
  final int count;
  final double cardHeight;
  const CardListShimmer({super.key, this.count = 6, this.cardHeight = 70});

  @override
  Widget build(BuildContext context) => AppShimmer(
    child: ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: count,
      separatorBuilder: (_, __) => const SizedBox(height: 10),
      itemBuilder: (_, __) => Container(
        height: cardHeight,
        decoration: BoxDecoration(color: _kBase, borderRadius: BorderRadius.circular(14)),
        padding: const EdgeInsets.all(14),
        child: Row(children: [
          _box(w: 42, h: 42, r: 10),
          const SizedBox(width: 12),
          Expanded(child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _box(w: 150, h: 13, r: 6),
              const SizedBox(height: 7),
              _box(w: 100, h: 10, r: 6),
          ])),
        ]),
      ),
    ),
  );
}

// ─────────────────────────────────────────────────────────────────────────────
// 9. RAG / Notes shimmer
// ─────────────────────────────────────────────────────────────────────────────
class NotesShimmer extends StatelessWidget {
  const NotesShimmer({super.key});

  @override
  Widget build(BuildContext context) => AppShimmer(
    child: ListView(padding: const EdgeInsets.all(16), children: [
      // Search bar
      _box(h: 52, r: 14),
      const SizedBox(height: 16),
      // Note cards
      ...List.generate(5, (i) => Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(color: _kBase, borderRadius: BorderRadius.circular(16)),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            _box(w: 160, h: 14, r: 6),
            const SizedBox(height: 8),
            _box(h: 10, r: 6),
            const SizedBox(height: 5),
            _box(w: 240, h: 10, r: 6),
            const SizedBox(height: 12),
            Row(children: [
              _box(w: 50, h: 18, r: 9),
              const SizedBox(width: 8),
              _box(w: 70, h: 18, r: 9),
            ]),
          ]),
        ),
      )),
    ]),
  );
}
