import '../../../core/network/api_client.dart';
import '../models/hydration_models.dart';

class HydrationApi {
  const HydrationApi(this._client);

  final ApiClient _client;

  Future<HydrationLog> createLog({
    required int amountMl,
    String? notes,
  }) async {
    final body = <String, dynamic>{'amount_ml': amountMl};
    if (notes != null && notes.isNotEmpty) {
      body['notes'] = notes;
    }
    final json = await _client.post('/hydration/logs', body: body);
    return HydrationLog.fromJson(json as Map<String, dynamic>);
  }

  Future<HydrationLog> updateLog({
    required String logId,
    required int amountMl,
    String? notes,
  }) async {
    final body = <String, dynamic>{'amount_ml': amountMl};
    if (notes != null) {
      body['notes'] = notes;
    }
    final json = await _client.patch('/hydration/logs/$logId', body: body);
    return HydrationLog.fromJson(json as Map<String, dynamic>);
  }

  Future<void> deleteLog(String logId) {
    return _client.delete('/hydration/logs/$logId');
  }

  Future<HydrationDailySummary> getDailySummary({String? date}) async {
    final params = date != null ? <String, dynamic>{'log_date': date} : null;
    final json = await _client.get('/hydration/daily-summary',
        queryParameters: params);
    return HydrationDailySummary.fromJson(json as Map<String, dynamic>);
  }

  Future<List<HydrationWeeklyEntry>> getWeeklySummary({int days = 7}) async {
    final json = await _client.get(
      '/hydration/weekly-summary',
      queryParameters: <String, dynamic>{'days': days},
    );
    final list = json as List<dynamic>;
    return list
        .map((e) => HydrationWeeklyEntry.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<HydrationReminder> getReminder() async {
    final json = await _client.get('/hydration/reminder');
    return HydrationReminder.fromJson(json as Map<String, dynamic>);
  }
}
