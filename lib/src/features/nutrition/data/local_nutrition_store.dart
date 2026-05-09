import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../../auth/data/auth_service.dart';
import '../models/nutrition_models.dart';

class LocalNutritionStore {
  LocalNutritionStore._();

  static const _keyGoal = 'nutrition_goal';
  static const _keyDailySummary = 'nutrition_daily_summary';
  static const _keyWeeklySummary = 'nutrition_weekly_summary';

  static String _anonymousKey(String baseKey) => '${baseKey}_anonymous';

  static Future<String> _scopeKey(String baseKey) async {
    final userId = await AuthService.instance.getUserId();
    final scope = userId != null && userId.isNotEmpty ? userId : 'anonymous';
    return '${baseKey}_$scope';
  }

  static Future<List<String>> _candidateKeys(String baseKey) async {
    final scoped = await _scopeKey(baseKey);
    final keys = <String>[scoped, _anonymousKey(baseKey), baseKey];
    return keys.toSet().toList();
  }

  static Future<SharedPreferences?> _prefs() async {
    try {
      return await SharedPreferences.getInstance();
    } catch (_) {
      return null;
    }
  }

  static Future<void> saveGoal(MacroGoal goal) async {
    final prefs = await _prefs();
    if (prefs == null) return;
    final encoded = jsonEncode(goal.toJson());
    for (final key in await _candidateKeys(_keyGoal)) {
      await prefs.setString(key, encoded);
    }
  }

  static Future<MacroGoal?> getGoal() async {
    final prefs = await _prefs();
    if (prefs == null) return null;
    for (final key in await _candidateKeys(_keyGoal)) {
      final raw = prefs.getString(key);
      if (raw == null || raw.isEmpty) continue;
      try {
        return MacroGoal.fromJson(
          Map<String, dynamic>.from(jsonDecode(raw) as Map),
        );
      } catch (_) {
        continue;
      }
    }
    return null;
  }

  static Future<void> deleteGoal() async {
    final prefs = await _prefs();
    if (prefs == null) return;
    for (final key in await _candidateKeys(_keyGoal)) {
      await prefs.remove(key);
    }
  }

  static Future<void> saveDailySummary(DailyNutritionSummary summary) async {
    final prefs = await _prefs();
    if (prefs == null) return;
    final encoded = jsonEncode(summary.toJson());
    for (final key in await _candidateKeys(_dailyKey(summary.logDate))) {
      await prefs.setString(key, encoded);
    }
  }

  static Future<DailyNutritionSummary?> getDailySummary(String logDate) async {
    final prefs = await _prefs();
    if (prefs == null) return null;
    for (final key in await _candidateKeys(_dailyKey(logDate))) {
      final raw = prefs.getString(key);
      if (raw == null || raw.isEmpty) continue;
      try {
        return DailyNutritionSummary.fromJson(
          Map<String, dynamic>.from(jsonDecode(raw) as Map),
        );
      } catch (_) {
        continue;
      }
    }
    return null;
  }

  static Future<void> saveWeeklySummary({
    required String startDate,
    required String endDate,
    required List<WeeklySummaryDay> days,
  }) async {
    final prefs = await _prefs();
    if (prefs == null) return;
    final encoded = jsonEncode(days.map((day) => day.toJson()).toList());
    for (final key in await _candidateKeys(_weeklyKey(startDate, endDate))) {
      await prefs.setString(key, encoded);
    }
  }

  static Future<List<WeeklySummaryDay>?> getWeeklySummary({
    required String startDate,
    required String endDate,
  }) async {
    final prefs = await _prefs();
    if (prefs == null) return null;
    for (final key in await _candidateKeys(_weeklyKey(startDate, endDate))) {
      final raw = prefs.getString(key);
      if (raw == null || raw.isEmpty) continue;
      try {
        return (jsonDecode(raw) as List<dynamic>)
            .cast<Map<String, dynamic>>()
            .map(WeeklySummaryDay.fromJson)
            .toList();
      } catch (_) {
        continue;
      }
    }
    return null;
  }

  static String _dailyKey(String logDate) => '${_keyDailySummary}_$logDate';

  static String _weeklyKey(String startDate, String endDate) =>
      '${_keyWeeklySummary}_${startDate}_$endDate';
}
