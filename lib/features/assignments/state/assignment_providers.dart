import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../auth/state/auth_providers.dart';
import '../data/assignment_repository.dart';
import '../domain/assignment_models.dart';

final Provider<AssignmentRepository> assignmentRepositoryProvider = Provider<AssignmentRepository>((Ref ref) {
  return AssignmentRepository(ref.watch(apiClientProvider));
});

/// `/api/v1/assignments`. Auto-disposed so a grade posted while the student is
/// elsewhere shows up the next time the page is opened.
final FutureProvider<AssignmentsData> assignmentsProvider = FutureProvider<AssignmentsData>((Ref ref) async {
  return ref.watch(assignmentRepositoryProvider).fetch();
});
