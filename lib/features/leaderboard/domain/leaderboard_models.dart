import '../../../core/utils/json_parsing.dart';
import '../../dashboard/domain/dashboard_data.dart';

export '../../dashboard/domain/dashboard_data.dart' show SectionLeaderboard, LeaderboardUser;

/// `/api/v1/leaderboard`.
///
/// Reuses [SectionLeaderboard] from the dashboard payload — the endpoint returns
/// the same board shape, and a second near-identical model would be the kind of
/// duplication that drifts.
class LeaderboardData {
  const LeaderboardData({required this.boards, this.seasonName});

  final List<SectionLeaderboard> boards;

  /// The season these standings belong to, or null when the student has none.
  final String? seasonName;

  bool get isEmpty => boards.isEmpty;

  factory LeaderboardData.fromJson(Map<String, dynamic> json) {
    return LeaderboardData(
      boards: json.asMapList('leaderboards').map(SectionLeaderboard.fromJson).toList(growable: false),
      seasonName: json.asMap('selectedSeason')['name'] as String?,
    );
  }

  static const LeaderboardData empty = LeaderboardData(boards: <SectionLeaderboard>[]);
}
