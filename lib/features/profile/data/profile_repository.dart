import '../../../core/network/api_client.dart';
import '../domain/xp_history.dart';

class ProfileRepository {
  const ProfileRepository(this._client);

  final ApiClient _client;

  /// XP ledger for a user, keyed by `public_id`.
  ///
  /// The `/users/{public_id}/xp-history` route, not `/xp-history/{user}`: that
  /// one carries `->whereNumber('user')` and is bound to the numeric primary key,
  /// so passing a public id like `LSI-2026-0001` matches no route and 404s. Both
  /// point at the same controller and return the same payload.
  Future<XpHistory> fetchXpHistory(String publicId) async {
    final Map<String, dynamic> json = await _client.getJson('/users/$publicId/xp-history');
    return XpHistory.fromJson(json);
  }
}
