import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../auth/state/auth_providers.dart';
import '../data/dashboard_repository.dart';
import '../domain/dashboard_data.dart';

final Provider<DashboardRepository> dashboardRepositoryProvider = Provider<DashboardRepository>((Ref ref) {
  return DashboardRepository(ref.watch(apiClientProvider));
});

/// `/api/dashboard`, refreshed by pull-to-refresh and after any XP-claiming
/// mutation.
///
/// Kept as a plain `FutureProvider` (no auto-dispose): the dashboard is the
/// app's home screen and is watched continuously, so keeping it alive avoids
/// refetching every time the user pops back from an exam.
final FutureProvider<DashboardData> dashboardProvider = FutureProvider<DashboardData>((Ref ref) async {
  return ref.watch(dashboardRepositoryProvider).fetch();
});

final AsyncNotifierProvider<ClaimXpController, XpClaimResult?> claimXpControllerProvider =
    AsyncNotifierProvider<ClaimXpController, XpClaimResult?>(ClaimXpController.new);

/// Claims the daily streak XP and the flat bonus XP.
///
/// Both endpoints answer 200 even when nothing was granted, so the result's
/// `claimed` flag is the only reliable signal and is what drives the snackbar.
class ClaimXpController extends AsyncNotifier<XpClaimResult?> {
  @override
  FutureOr<XpClaimResult?> build() => null;

  Future<XpClaimResult> claimDaily() async {
    state = const AsyncLoading<XpClaimResult?>();
    return _run(() => ref.read(dashboardRepositoryProvider).claimXp());
  }

  Future<XpClaimResult> claimBonus() async {
    state = const AsyncLoading<XpClaimResult?>();
    return _run(() => ref.read(dashboardRepositoryProvider).claimBonusXp());
  }

  Future<XpClaimResult> _run(Future<XpClaimResult> Function() action) async {
    try {
      final XpClaimResult result = await action();
      state = AsyncData<XpClaimResult?>(result);
      ref.invalidate(dashboardProvider);
      return result;
    } catch (error, stackTrace) {
      state = AsyncError<XpClaimResult?>(error, stackTrace);
      rethrow;
    }
  }
}