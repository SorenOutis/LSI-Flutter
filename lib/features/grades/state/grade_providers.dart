import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../auth/state/auth_providers.dart';
import '../data/grade_repository.dart';
import '../domain/grade_models.dart';

final Provider<GradeRepository> gradeRepositoryProvider = Provider<GradeRepository>((Ref ref) {
  return GradeRepository(ref.watch(apiClientProvider));
});

/// `/api/v1/grades`. Auto-disposed so opening the tab after a grading run
/// refetches instead of showing a stale average for the rest of the session.
final FutureProvider<GradesData> gradesProvider = FutureProvider<GradesData>((Ref ref) async {
  return ref.watch(gradeRepositoryProvider).fetch();
});
