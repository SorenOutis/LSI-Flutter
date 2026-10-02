import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../auth/state/auth_providers.dart';
import '../data/profile_repository.dart';
import '../domain/xp_history.dart';

final Provider<ProfileRepository> profileRepositoryProvider = Provider<ProfileRepository>((Ref ref) {
  return ProfileRepository(ref.watch(apiClientProvider));
});

/// XP ledger for the signed-in student.
///
/// Reads the id off the session rather than taking it as a parameter: the only
/// profile the app can currently open is your own (the public-profile routes
/// are a later feature), and a null session should render an empty ledger
/// rather than fire a request with a bogus id.
final FutureProvider<XpHistory> xpHistoryProvider = FutureProvider<XpHistory>((Ref ref) async {
  final String? publicId = ref.watch(sessionProvider).value?.publicId;
  if (publicId == null || publicId.isEmpty) return XpHistory.empty;

  return ref.watch(profileRepositoryProvider).fetchXpHistory(publicId);
});
