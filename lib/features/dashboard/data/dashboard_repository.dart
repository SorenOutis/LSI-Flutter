import '../../../core/network/api_client.dart';
import '../domain/dashboard_data.dart';

class DashboardRepository {
  const DashboardRepository(this._client);

  final ApiClient _client;

  Future<DashboardData> fetch() async {
    final Map<String, dynamic> json = await _client.getJson('/dashboard');
    return DashboardData.fromJson(json);
  }

  /// Always answers 200 with `claimed: false` when already claimed today, so the
  /// result — not the status code — is what callers must branch on.
  Future<XpClaimResult> claimXp() async {
    return XpClaimResult.fromJson(await _client.postJson('/claim-xp'));
  }

  Future<XpClaimResult> claimBonusXp() async {
    return XpClaimResult.fromJson(await _client.postJson('/claim-bonus-xp'));
  }
}