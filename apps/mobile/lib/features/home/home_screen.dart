import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../core/theme/app_theme.dart';
import '../../shared/widgets/app_card.dart';
import '../../shared/widgets/app_button.dart';
import '../../shared/widgets/stat_tile.dart';
import '../../shared/widgets/section_header.dart';
import '../timetable/timetable_provider.dart';
import '../../shared/widgets/shimmer_widgets.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});
  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final profile = await ref.read(timetableProvider.notifier).checkProfile();
      if (profile != null && profile['division'] == null && mounted) {
        // Will implement onboarding flow via separate file if needed or keep inline
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final now = DateTime.now();
    final todayKey = DateFormat('EEEE').format(now).toLowerCase();
    
    final slotsAsync = ref.watch(timetableProvider);

    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: RefreshIndicator(
          onRefresh: () async => ref.invalidate(timetableProvider),
          color: theme.colorScheme.primary,
          child: CustomScrollView(
            slivers: [
              // ── Header ──────────────────────────────────────────
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 20, 20, 12),
                  child: Row(
                    children: [
                      CircleAvatar(
                        radius: 24,
                        backgroundColor: theme.colorScheme.primary.withOpacity(0.2),
                        child: Text(
                          'J', // TODO: user initial
                          style: TextStyle(
                            color: theme.colorScheme.primary,
                            fontWeight: FontWeight.w800,
                            fontSize: 18,
                          ),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Good Morning, Jayesh',
                              style: theme.textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            Text(
                              DateFormat('EEEE, MMMM d').format(now),
                              style: theme.textTheme.bodyMedium?.copyWith(
                                color: theme.colorScheme.onSurface.withOpacity(0.6),
                              ),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        onPressed: () => context.push('/profile'),
                        icon: const Icon(Icons.settings_outlined),
                        color: theme.colorScheme.onSurface.withOpacity(0.6),
                      )
                    ],
                  ),
                ),
              ),

              // ── Quick Actions ───────────────────────────────────
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                  child: Row(
                    children: [
                      Expanded(
                        child: AppButton(
                          text: 'AI Search',
                          icon: Icons.auto_awesome,
                          variant: AppButtonVariant.secondary,
                          onPressed: () => context.push('/rag'),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: AppButton(
                          text: 'Scan PDF',
                          icon: Icons.document_scanner_outlined,
                          variant: AppButtonVariant.secondary,
                          onPressed: () => context.push('/ocr'),
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              // ── Stats Row ───────────────────────────────────────
              SliverToBoxAdapter(
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                  child: Row(
                    children: [
                      SizedBox(
                        width: 150,
                        child: StatTile(
                          title: 'Attendance',
                          value: '82%',
                          icon: Icons.check_circle_outline,
                          color: Colors.green,
                          progress: 0.82,
                          onTap: () => context.push('/bunk'),
                        ),
                      ),
                      const SizedBox(width: 12),
                      SizedBox(
                        width: 150,
                        child: StatTile(
                          title: 'Open Tasks',
                          value: '5',
                          icon: Icons.task_alt_outlined,
                          color: theme.colorScheme.primary,
                          onTap: () => context.push('/my-tasks'),
                        ),
                      ),
                      const SizedBox(width: 12),
                      SizedBox(
                        width: 150,
                        child: StatTile(
                          title: 'Study Groups',
                          value: '3 Active',
                          icon: Icons.group_outlined,
                          color: Colors.orange,
                          onTap: () => context.go('/groups'),
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              // ── Smart Insight ───────────────────────────────────
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                  child: AppCard(
                    glass: true,
                    color: theme.colorScheme.primary.withOpacity(0.05),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(Icons.lightbulb_outline, color: theme.colorScheme.primary),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Lumina Insight',
                                style: theme.textTheme.titleSmall?.copyWith(
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'You have a high concentration of lab classes tomorrow. Consider reviewing the notes generated from your OCR scans today.',
                                style: theme.textTheme.bodyMedium?.copyWith(
                                  height: 1.4,
                                  color: theme.colorScheme.onSurface.withOpacity(0.8),
                                ),
                              ),
                            ],
                          ),
                        )
                      ],
                    ),
                  ),
                ),
              ),

              // ── Today's Schedule ────────────────────────────────
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
                  child: const SectionHeader(
                    title: 'Today\'s Schedule',
                    subtitle: 'Up next in your timetable',
                  ),
                ),
              ),

              slotsAsync.when(
                loading: () => const SliverToBoxAdapter(child: TimetableShimmer()),
                error: (e, _) => SliverToBoxAdapter(
                  child: AppCard(
                    margin: const EdgeInsets.symmetric(horizontal: 20),
                    child: Text('Error loading schedule: $e'),
                  ),
                ),
                data: (slots) {
                  final todaySlots = slots.where((s) => s['day_of_week'] == todayKey).toList();
                  
                  if (todaySlots.isEmpty) {
                    return SliverToBoxAdapter(
                      child: AppCard(
                        margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                        child: const Center(
                          child: Padding(
                            padding: EdgeInsets.all(16.0),
                            child: Text('No classes scheduled for today. Take a break!'),
                          ),
                        ),
                      ),
                    );
                  }

                  return SliverList(
                    delegate: SliverChildBuilderDelegate(
                      (context, index) {
                        final slot = todaySlots[index] as Map<String, dynamic>;
                        final subjectName = slot['subject']?['name'] as String? ?? 'Unknown Subject';
                        final professorInfo = slot['subject']?['professor'] != null 
                            ? (slot['subject']['professor']['name'] as String?) 
                            : null;
                        
                        return Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
                          child: AppCard(
                            child: Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(12),
                                  decoration: BoxDecoration(
                                    color: theme.colorScheme.primary.withOpacity(0.1),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Icon(Icons.class_outlined, color: theme.colorScheme.primary),
                                ),
                                const SizedBox(width: 16),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        subjectName,
                                        style: theme.textTheme.titleMedium?.copyWith(
                                          fontWeight: FontWeight.w700,
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        '${slot['start_time']} - ${slot['end_time']}',
                                        style: theme.textTheme.bodySmall?.copyWith(
                                          color: theme.colorScheme.onSurface.withOpacity(0.6),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                      childCount: todaySlots.length,
                    ),
                  );
                },
              ),
              
              const SliverToBoxAdapter(child: SizedBox(height: 100)), // Bottom padding
            ],
          ),
        ),
      ),
    );
  }
}
