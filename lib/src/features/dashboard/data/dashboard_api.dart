import '../../../core/network/api_client.dart';
import '../models/dashboard_models.dart';

class DashboardApi {
  DashboardApi(this._client);

  final ApiClient _client;

  Future<ProgressDashboard> getDashboard({
    int weeks = 12,
    int weightDays = 90,
  }) async {
    final response = await _client.get(
      '/progress/dashboard',
      queryParameters: {
        'weeks': weeks,
        'weight_days': weightDays,
      },
    );
    return ProgressDashboard.fromJson(Map<String, dynamic>.from(response));
  }
}
