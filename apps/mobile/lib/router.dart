import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'features/auth/auth_screen.dart';
import 'features/home/home_screen.dart';
import 'features/timetable/timetable_screen.dart';
import 'features/timetable/ocr_parser_screen.dart';
import 'features/timetable/attendance_screen.dart';
import 'features/timetable/bunk_analytics_screen.dart';
import 'features/hub/groups_screen.dart';
import 'features/hub/group_chat_screen.dart';
import 'features/hub/whiteboard_screen.dart';
import 'features/hub/pasteboard_screen.dart';
import 'features/kanban/kanban_screen.dart'; 
import 'features/calendar/heatmap_screen.dart';
import 'features/profile/profile_screen.dart';
import 'features/expenses/expense_screen.dart';
import 'features/expenses/weekly_wrap_screen.dart';
import 'features/rag/rag_screen.dart';
import 'features/context_switch/flow_graph_screen.dart';
import 'shared/widgets/home_shell.dart';

final router = GoRouter(
  initialLocation: '/home',
  // ── Catch OAuth deep links before GoRouter tries to route them ────────────
  // Supabase implicit flow returns tokens in the URL fragment which GoRouter
  // cannot route. Redirect login-callback to /home (session is set by Supabase SDK).
  redirect: (ctx, state) {
    // OAuth callback — let Supabase SDK handle the token; just send user home/auth
    final uri = state.uri;
    if (uri.host == 'login-callback' || uri.path.contains('login-callback')) {
      final loggedIn = Supabase.instance.client.auth.currentSession != null;
      return loggedIn ? '/home' : '/auth';
    }
    final loggedIn = Supabase.instance.client.auth.currentSession != null;
    final onAuth = uri.path == '/auth';
    if (!loggedIn && !onAuth) return '/auth';
    if (loggedIn && onAuth) return '/home';
    return null;
  },
  // Fallback for any unmatched deep-link route (e.g. io.supabase.lumina://*)
  errorBuilder: (ctx, state) {
    final loggedIn = Supabase.instance.client.auth.currentSession != null;
    return loggedIn ? const TimetableScreen() : const AuthScreen();
  },
  refreshListenable: GoRouterRefreshStream(
    Supabase.instance.client.auth.onAuthStateChange,
  ),
  routes: [
    GoRoute(path: '/auth', builder: (_, __) => const AuthScreen()),
    ShellRoute(
      builder: (ctx, state, child) => HomeShell(child: child),
      routes: [
        GoRoute(path: '/home', builder: (_, __) => const HomeScreen()),
        GoRoute(path: '/groups', builder: (_, __) => const GroupsScreen()),
        GoRoute(path: '/calendar', builder: (_, __) => const HeatmapScreen()),
        GoRoute(path: '/expenses', builder: (_, __) => const ExpenseScreen()),
        GoRoute(path: '/flow', builder: (_, __) => const FlowGraphScreen()),
        GoRoute(path: '/rag', builder: (_, __) => const RagScreen()),
        GoRoute(path: '/my-tasks', builder: (_, __) => const MyTasksKanbanScreen()),
        GoRoute(path: '/profile', builder: (_, __) => const ProfileScreen()),
      ],
    ),
    // Full-screen routes (outside shell)
    GoRoute(path: '/ocr', builder: (_, __) => const OcrParserScreen()),
    GoRoute(path: '/bunk', builder: (_, __) => const BunkAnalyticsScreen()),
    GoRoute(path: '/weekly-wrap', builder: (_, __) => const WeeklyWrapScreen()),
    GoRoute(
      path: '/attendance/:slotId',
      builder: (ctx, state) => AttendanceScreen(slotId: state.pathParameters['slotId']!),
    ),
    GoRoute(
      path: '/hub/:groupId',
      builder: (ctx, state) => GroupChatScreen(groupId: state.pathParameters['groupId']!),
    ),
    GoRoute(
      path: '/whiteboard/:groupId',
      builder: (ctx, state) => WhiteboardScreen(groupId: state.pathParameters['groupId']!),
    ),
    GoRoute(
      path: '/pasteboard/:groupId',
      builder: (ctx, state) => PasteboardScreen(groupId: state.pathParameters['groupId']!),
    ),
    GoRoute(
      path: '/kanban/:groupId',
      builder: (ctx, state) => KanbanScreen(groupId: state.pathParameters['groupId']!),
    ),
  ],
);

/// Listens to Supabase auth stream — fires on signIn, signOut, AND setSession
class GoRouterRefreshStream extends ChangeNotifier {
  GoRouterRefreshStream(Stream<dynamic> stream) {
    notifyListeners();
    _sub = stream.listen((_) => notifyListeners());
  }
  late final dynamic _sub;
  @override
  void dispose() { _sub.cancel(); super.dispose(); }
}
