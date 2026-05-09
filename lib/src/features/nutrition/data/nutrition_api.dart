import '../../../core/network/api_client.dart';
import 'local_nutrition_store.dart';
import '../models/nutrition_models.dart';

class NutritionApi {
  NutritionApi(this._client);

  final ApiClient _client;

  // ── Foods ──────────────────────────────────────────────────────────────────

  /// Search foods by query, or list all (optionally filtered by category).
  Future<List<FoodSearchItem>> searchFoods({
    String? query,
    String? category,
    int limit = 20,
  }) async {
    final params = <String, dynamic>{'limit': limit};
    if (query != null) params['query'] = query;
    if (category != null) params['category'] = category;

    final response = await _client.get(
      '/nutrition/foods',
      queryParameters: params,
    );
    return (response as List<dynamic>)
        .cast<Map<String, dynamic>>()
        .map(FoodSearchItem.fromJson)
        .toList();
  }

  /// Get all food categories.
  Future<List<String>> getFoodCategories() async {
    final response = await _client.get('/nutrition/foods/categories');
    return (response as List<dynamic>).cast<String>();
  }

  /// Preview macros for a food at a given quantity (no log created).
  Future<MacroPreview> previewMacros({
    required int foodId,
    required double quantityG,
  }) async {
    final response = await _client.get(
      '/nutrition/foods/$foodId/preview',
      queryParameters: {'quantity_g': quantityG},
    );
    return MacroPreview.fromJson(Map<String, dynamic>.from(response as Map));
  }

  // ── Logging ────────────────────────────────────────────────────────────────

  /// Log a meal entry.
  Future<FoodLog> logMeal({
    required int foodId,
    required double quantityG,
    required String mealType,
    String? logDate,
  }) async {
    final body = <String, dynamic>{
      'food_id': foodId,
      'quantity_g': quantityG,
      'meal_type': mealType,
    };
    if (logDate != null) body['log_date'] = logDate;

    final response = await _client.post('/nutrition/logs', body: body);
    return FoodLog.fromJson(Map<String, dynamic>.from(response as Map));
  }

  /// Update an existing meal log (quantity and/or meal type).
  Future<FoodLog> updateLog({
    required String logId,
    double? quantityG,
    String? mealType,
  }) async {
    final body = <String, dynamic>{};
    if (quantityG != null) body['quantity_g'] = quantityG;
    if (mealType != null) body['meal_type'] = mealType;

    final response = await _client.patch('/nutrition/logs/$logId', body: body);
    return FoodLog.fromJson(Map<String, dynamic>.from(response as Map));
  }

  /// Delete a meal log entry.
  Future<void> deleteLog(String logId) async {
    await _client.delete('/nutrition/logs/$logId');
  }

  // ── Summaries ──────────────────────────────────────────────────────────────

  /// Fetch daily nutrition summary. [logDate] format: `yyyy-MM-dd`.
  Future<DailyNutritionSummary> getDailySummary({String? logDate}) async {
    final params = <String, dynamic>{};
    if (logDate != null) params['log_date'] = logDate;

    try {
      final response = await _client.get(
        '/nutrition/summary/daily',
        queryParameters: params.isEmpty ? null : params,
      );
      final summary = DailyNutritionSummary.fromJson(
        Map<String, dynamic>.from(response as Map),
      );
      await LocalNutritionStore.saveDailySummary(summary);
      return summary;
    } catch (_) {
      final fallback = await LocalNutritionStore.getDailySummary(
        logDate ?? _todayKey(),
      );
      if (fallback != null) return fallback;
      rethrow;
    }
  }

  /// Fetch weekly summary (per-day macro totals).
  Future<List<WeeklySummaryDay>> getWeeklySummary({
    required String startDate,
    required String endDate,
  }) async {
    try {
      final response = await _client.get(
        '/nutrition/summary/weekly',
        queryParameters: {'start_date': startDate, 'end_date': endDate},
      );
      final days = (response as List<dynamic>)
          .cast<Map<String, dynamic>>()
          .map(WeeklySummaryDay.fromJson)
          .toList();
      await LocalNutritionStore.saveWeeklySummary(
        startDate: startDate,
        endDate: endDate,
        days: days,
      );
      return days;
    } catch (_) {
      final fallback = await LocalNutritionStore.getWeeklySummary(
        startDate: startDate,
        endDate: endDate,
      );
      if (fallback != null) return fallback;
      rethrow;
    }
  }

  // ── Goals ──────────────────────────────────────────────────────────────────

  /// Set or update daily macro goals.
  Future<MacroGoal> setGoal({
    required double dailyCalories,
    required double proteinG,
    required double carbsG,
    required double fatG,
  }) async {
    final response = await _client.post(
      '/nutrition/goals',
      body: {
        'daily_calories': dailyCalories,
        'protein_g': proteinG,
        'carbs_g': carbsG,
        'fat_g': fatG,
      },
    );
    final goal = MacroGoal.fromJson(Map<String, dynamic>.from(response as Map));
    await LocalNutritionStore.saveGoal(goal);
    return goal;
  }

  /// Get current macro goals.
  Future<MacroGoal> getGoal() async {
    try {
      final response = await _client.get('/nutrition/goals');
      final goal = MacroGoal.fromJson(
        Map<String, dynamic>.from(response as Map),
      );
      await LocalNutritionStore.saveGoal(goal);
      return goal;
    } catch (_) {
      final fallback = await LocalNutritionStore.getGoal();
      if (fallback != null) return fallback;
      rethrow;
    }
  }

  /// Delete macro goals.
  Future<void> deleteGoal() async {
    await _client.delete('/nutrition/goals');
    await LocalNutritionStore.deleteGoal();
  }

  String _todayKey() {
    final now = DateTime.now();
    return '${now.year.toString().padLeft(4, '0')}-'
        '${now.month.toString().padLeft(2, '0')}-'
        '${now.day.toString().padLeft(2, '0')}';
  }
}
