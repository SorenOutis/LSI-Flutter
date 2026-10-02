import 'dart:async';

import 'package:flutter/cupertino.dart' show CupertinoIcons, CupertinoTabBar;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../features/activity/presentation/activity_screen.dart';
import '../features/assignments/presentation/assignment_detail_screen.dart';
import '../features/assignments/presentation/assignments_screen.dart';
import '../features/auth/domain/app_user.dart';
import '../features/auth/presentation/login_screen.dart';
import '../features/auth/presentation/register_screen.dart';
import '../features/auth/state/auth_providers.dart';
import '../features/calendar/presentation/calendar_screen.dart';
import '../features/chats/presentation/chat_thread_screen.dart';
import '../features/chats/presentation/chats_screen.dart';
import '../features/chats/presentation/new_chat_screen.dart';
import '../features/dashboard/presentation/dashboard_screen.dart';
import '../features/grades/presentation/grades_screen.dart';
import '../features/leaderboard/presentation/leaderboard_screen.dart';
import '../features/more/presentation/more_screen.dart';
import '../features/profile/presentation/profile_screen.dart';
import '../features/settings/presentation/settings_screen.dart';
import '../features/exams/presentation/exam_detail_screen.dart';
import '../features/exams/presentation/exam_list_screen.dart';
import '../features/exams/presentation/exam_review_screen.dart';
import '../features/exams/presentation/exam_status_screen.dart';
import '../features/exams/presentation/exam_taking_screen.dart';
import '../shared/widgets/app_motion.dart';

final GlobalKey<NavigatorState> _rootNavigatorKey = GlobalKey<NavigatorState>(debugLabel: 'root');

/// The route table.
///
/// Built once from a [Provider] so it can read the session for its initial
/// location, then kept in sync by `refreshListenable` — any 401 from the Dio
/// interceptor or an explicit sign-out re-runs `redirect` and navigates, without
/// any screen having to call the router itself.
/// Bridges Riverpod's provider notifications to go_router's `refreshListenable`.
///
/// go_router needs a plain Flutter [Listenable]; Riverpod's `Refreshable` is a
/// different interface, so the session is observed here and re-signalled.
class _RouterRefresh extends ChangeNotifier {
  void signal() => notifyListeners();
}

final Provider<GoRouter> routerProvider = Provider<GoRouter>((Ref ref) {
  final AsyncValue<AppUser?> session = ref.read(sessionProvider);
  final _RouterRefresh refresh = _RouterRefresh();

  ref.onDispose(refresh.dispose);
  ref.listen<AsyncValue<AppUser?>>(sessionProvider, (AsyncValue<AppUser?>? _, AsyncValue<AppUser?> _) {
    refresh.signal();
  });

  return GoRouter(
    navigatorKey: _rootNavigatorKey,
    initialLocation: switch (session) {
      AsyncData(value: final AppUser? user) => user == null ? '/login' : '/dashboard',
      _ => '/splash',
    },
    refreshListenable: refresh,
    redirect: (BuildContext context, GoRouterState state) {
      final AsyncValue<AppUser?> current = ref.read(sessionProvider);
      final String location = state.matchedLocation;

      // While the stored token is being verified, hold on the splash. Without
      // this a returning user would be pushed to /login mid-verification and
      // then bounced back, showing a login flash on every cold start.
      if (current.isLoading) return location == '/splash' ? null : '/splash';

      final bool signedIn = current.value != null;

      if (!signedIn) {
        // /splash is only ever a "still checking" screen — once the check has
        // come back signed-out it must move on, or the app sits on the spinner
        // forever.
        if (location == '/splash') return '/login';
        return (location == '/login' || location == '/register') ? null : '/login';
      }

      if (location == '/splash' || location == '/login' || location == '/register') return '/dashboard';

      return null;
    },
    routes: [
      GoRoute(path: '/splash', builder: (BuildContext context, GoRouterState state) => const _SplashScreen()),
      GoRoute(path: '/login', builder: (BuildContext context, GoRouterState state) => const LoginScreen()),
      GoRoute(path: '/register', builder: (BuildContext context, GoRouterState state) => const RegisterScreen()),

      // Tabs keep their own navigation stack and scroll position via the
      // indexedStack shell.
      StatefulShellRoute.indexedStack(
        builder: (BuildContext context, GoRouterState state, StatefulNavigationShell shell) =>
            HomeShell(navigationShell: shell),
        branches: [
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/dashboard',
                builder: (BuildContext context, GoRouterState state) => const DashboardScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/exams',
                builder: (BuildContext context, GoRouterState state) => const ExamListScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/calendar',
                builder: (BuildContext context, GoRouterState state) => const CalendarScreen(),
              ),
            ],
          ),
          // The catch-all tab. Its sub-routes are nested rather than declared on
          // the root navigator so the tab bar stays put: these are still "inside"
          // the app, unlike the exam-taking flow.
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/more',
                builder: (BuildContext context, GoRouterState state) => const MoreScreen(),
                routes: [
                  GoRoute(
                    path: 'grades',
                    builder: (BuildContext context, GoRouterState state) => const GradesScreen(),
                  ),
                  GoRoute(
                    path: 'assignments',
                    builder: (BuildContext context, GoRouterState state) => const AssignmentsScreen(),
                    routes: [
                      GoRoute(
                        path: ':assignmentId',
                        builder: (BuildContext context, GoRouterState state) => AssignmentDetailScreen(
                          assignmentId: int.parse(state.pathParameters['assignmentId']!),
                        ),
                      ),
                    ],
                  ),
                  GoRoute(
                    path: 'activity',
                    builder: (BuildContext context, GoRouterState state) => const ActivityScreen(),
                  ),
                  GoRoute(
                    path: 'leaderboard',
                    builder: (BuildContext context, GoRouterState state) => const LeaderboardScreen(),
                  ),
                  GoRoute(
                    path: 'profile',
                    builder: (BuildContext context, GoRouterState state) => const ProfileScreen(),
                  ),
                  GoRoute(
                    path: 'chats',
                    builder: (BuildContext context, GoRouterState state) => const ChatsScreen(),
                    routes: [
                      GoRoute(
                        parentNavigatorKey: _rootNavigatorKey,
                        path: 'new',
                        pageBuilder: (BuildContext context, GoRouterState state) => CustomTransitionPage(
                          key: state.pageKey,
                          child: const NewChatScreen(),
                          transitionsBuilder: (BuildContext context, Animation<double> animation,
                              Animation<double> secondaryAnimation, Widget child) {
                            return AppPageTransition(animation: animation, child: child);
                          },
                        ),
                      ),
                      // Full-screen, like the exam flow: a thread with a composer
                      // is a place you go into and come back from, and a composer
                      // sitting above a persistent tab bar reads as a half-open
                      // screen.
                      GoRoute(
                        parentNavigatorKey: _rootNavigatorKey,
                        path: ':sessionId',
                        pageBuilder: (BuildContext context, GoRouterState state) => CustomTransitionPage(
                          key: state.pageKey,
                          child: ChatThreadScreen(
                            sessionId: _sessionIdOf(state),
                          ),
                          transitionsBuilder: (BuildContext context, Animation<double> animation,
                              Animation<double> secondaryAnimation, Widget child) {
                            return AppPageTransition(animation: animation, child: child);
                          },
                        ),
                      ),
                    ],
                  ),
                  GoRoute(
                    path: 'settings',
                    builder: (BuildContext context, GoRouterState state) => const SettingsScreen(),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),

      // The exam flows sit on the root navigator, outside the tab shell: taking
      // an exam should not leave a bottom-nav tap away from abandoning it.
      // Each gets a fade+rises transition (AppPageTransition) so entering a
      // place you "go into and come back from" feels like a push, while tab
      // switches stay instant.
      GoRoute(
        parentNavigatorKey: _rootNavigatorKey,
        path: '/exams/:examId',
        pageBuilder: (BuildContext context, GoRouterState state) => CustomTransitionPage(
          key: state.pageKey,
          child: ExamDetailScreen(examId: _examIdOf(state)),
          transitionsBuilder: (BuildContext context, Animation<double> animation,
              Animation<double> secondaryAnimation, Widget child) {
            return AppPageTransition(animation: animation, child: child);
          },
        ),
      ),
      GoRoute(
        parentNavigatorKey: _rootNavigatorKey,
        path: '/exams/:examId/review',
        pageBuilder: (BuildContext context, GoRouterState state) => CustomTransitionPage(
          key: state.pageKey,
          child: ExamReviewScreen(examId: _examIdOf(state)),
          transitionsBuilder: (BuildContext context, Animation<double> animation,
              Animation<double> secondaryAnimation, Widget child) {
            return AppPageTransition(animation: animation, child: child);
          },
        ),
      ),
      GoRoute(
        parentNavigatorKey: _rootNavigatorKey,
        path: '/exams/:examId/parts/:partId',
        pageBuilder: (BuildContext context, GoRouterState state) => CustomTransitionPage(
          key: state.pageKey,
          child: ExamTakingScreen(
            examId: _examIdOf(state),
            partId: _partIdOf(state),
          ),
          transitionsBuilder: (BuildContext context, Animation<double> animation,
              Animation<double> secondaryAnimation, Widget child) {
            return AppPageTransition(animation: animation, child: child);
          },
        ),
      ),
      GoRoute(
        parentNavigatorKey: _rootNavigatorKey,
        path: '/exams/:examId/parts/:partId/status',
        pageBuilder: (BuildContext context, GoRouterState state) => CustomTransitionPage(
          key: state.pageKey,
          child: ExamPartStatusScreen(
            examId: _examIdOf(state),
            partId: _partIdOf(state),
          ),
          transitionsBuilder: (BuildContext context, Animation<double> animation,
              Animation<double> secondaryAnimation, Widget child) {
            return AppPageTransition(animation: animation, child: child);
          },
        ),
      ),
    ],
  );
});

int _examIdOf(GoRouterState state) => int.parse(state.pathParameters['examId']!);

int _partIdOf(GoRouterState state) => int.parse(state.pathParameters['partId']!);

int _sessionIdOf(GoRouterState state) => int.parse(state.pathParameters['sessionId']!);

/// Bottom-nav shell over the dashboard, exam list and calendar.
///
/// A [NavigationBar] here would render Material's 80px bar with a pill
/// indicator. [CupertinoTabBar] gives the iOS metrics instead — 49pt tall, a
/// hairline top edge, no pill — and works standalone as a `bottomNavigationBar`,
/// so the routed `navigationShell` stays the body. (`CupertinoTabScaffold` is
/// deliberately not used: it builds its own `TabView` from a `tabBuilder` and
/// would ignore the body, blanking every tab.)
class HomeShell extends StatelessWidget {
  const HomeShell({super.key, required this.navigationShell});

  final StatefulNavigationShell navigationShell;

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;

    return Scaffold(
      body: navigationShell,
      extendBody: true,
      bottomNavigationBar: CupertinoTabBar(
        currentIndex: navigationShell.currentIndex,
        // `initialLocation: true` makes a tap on the already-active tab pop that
        // branch back to its root instead of doing nothing.
        onTap: (int index) => navigationShell.goBranch(
          index,
          initialLocation: index == navigationShell.currentIndex,
        ),
        activeColor: scheme.primary,
        inactiveColor: scheme.onSurface.withValues(alpha: 0.45),
        backgroundColor: scheme.surface.withValues(alpha: 0.92),
        border: Border(
          top: BorderSide(color: scheme.outlineVariant.withValues(alpha: 0.6), width: 0.5),
        ),
        items: const [
          BottomNavigationBarItem(
            icon: Icon(CupertinoIcons.house),
            activeIcon: Icon(CupertinoIcons.house_fill),
            label: 'Home',
          ),
          BottomNavigationBarItem(
            icon: Icon(CupertinoIcons.doc_text),
            activeIcon: Icon(CupertinoIcons.doc_text_fill),
            label: 'Exams',
          ),
          BottomNavigationBarItem(
            icon: Icon(CupertinoIcons.calendar),
            activeIcon: Icon(CupertinoIcons.calendar),
            label: 'Calendar',
          ),
          BottomNavigationBarItem(
            icon: Icon(CupertinoIcons.ellipsis_circle),
            activeIcon: Icon(CupertinoIcons.ellipsis_circle_fill),
            label: 'More',
          ),
        ],
      ),
    );
  }
}

/// The account menu shown in the app bar of both tab screens.
class ProfileMenu extends ConsumerWidget {
  const ProfileMenu({super.key});

  Future<void> _confirmSignOut(BuildContext context, WidgetRef ref) async {
    final bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (BuildContext dialogContext) => AlertDialog(
        title: const Text('Sign out?'),
        content: const Text('You will need your email and password to sign back in.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Sign out'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    await ref.read(sessionProvider.notifier).signOut();
    // The redirect reacts to the session change; this go() just makes the
    // transition immediate rather than waiting for the listener tick.
    if (context.mounted) context.go('/login');
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AppUser? user = ref.watch(sessionProvider).value;
    final ColorScheme scheme = Theme.of(context).colorScheme;

    return PopupMenuButton<String>(
      tooltip: 'Account',
      onSelected: (String value) {
        if (value == 'signOut') unawaited(_confirmSignOut(context, ref));
      },
      itemBuilder: (BuildContext context) => [
        PopupMenuItem<String>(
          enabled: false,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(user?.name ?? '', style: const TextStyle(fontWeight: FontWeight.w600)),
              if (user?.email != null)
                Text(user?.email ?? '', style: Theme.of(context).textTheme.bodySmall),
            ],
          ),
        ),
        const PopupMenuDivider(),
        const PopupMenuItem<String>(
          value: 'signOut',
          child: Row(
            children: [
              Icon(Icons.logout_rounded),
              SizedBox(width: 12),
              Text('Sign out'),
            ],
          ),
        ),
      ],
      child: Padding(
        padding: const EdgeInsets.only(right: 8),
        child: CircleAvatar(
          backgroundColor: scheme.primaryContainer,
          child: Text(
            user?.initials ?? '?',
            style: TextStyle(color: scheme.onPrimaryContainer, fontWeight: FontWeight.w700),
          ),
        ),
      ),
    );
  }
}

class _SplashScreen extends StatelessWidget {
  const _SplashScreen();

  @override
  Widget build(BuildContext context) {
    return const Scaffold(body: Center(child: CircularProgressIndicator()));
  }
}