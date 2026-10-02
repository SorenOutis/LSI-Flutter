import '../../../core/network/api_client.dart';
import '../domain/leaderboard_models.dart';

class LeaderboardRepository {
  const LeaderboardRepository(this._client);

  final ApiClient _client;

  /// Standings for a season. The server falls back to the current season when
  /// no id is given.
  Future<LeaderboardData> fetch({int? seasonId}) async {
    final Map<String, dynamic> json = await _client.getJson(
      '/leaderboard',
      query: seasonId == null ? null : <String, dynamic>{'season_id': '$seasonId'},
    );
    return LeaderboardData.fromJson(json);
  }
}
