import '../../../core/network/api_client.dart';
import '../domain/assignment_models.dart';

class AssignmentRepository {
  const AssignmentRepository(this._client);

  final ApiClient _client;

  Future<AssignmentsData> fetch() async {
    final Map<String, dynamic> json = await _client.getJson('/assignments');
    return AssignmentsData.fromJson(json);
  }
}
