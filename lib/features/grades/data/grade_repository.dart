import '../../../core/network/api_client.dart';
import '../domain/grade_models.dart';

class GradeRepository {
  const GradeRepository(this._client);

  final ApiClient _client;

  Future<GradesData> fetch() async {
    final Map<String, dynamic> json = await _client.getJson('/grades');
    return GradesData.fromJson(json);
  }
}
