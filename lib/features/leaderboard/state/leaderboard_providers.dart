import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../auth/state/auth_providers.dart';
import '../data/leaderboard_repository.dart';
import '../domain/leaderboard_models.dart';

final Provider<LeaderboardRepository> leaderboardRepositoryProvider = Provider<LeaderboardRepository>((Ref ref) {
  return LeaderboardRepository(ref.watch(apiClientProvider));
});

/// `/api/v1/leaderboard` for the current season.
final FutureProvider<LeaderboardData> leaderboardProvider = FutureProvider<LeaderboardData>((Ref ref) async {
  return ref.watch(leaderboardRepositoryProvider).fetch();
});
