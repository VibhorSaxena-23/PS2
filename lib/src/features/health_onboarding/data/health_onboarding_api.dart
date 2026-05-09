import 'dart:developer' as dev;

import '../../../core/network/api_client.dart';
import '../../nutrition/data/local_nutrition_store.dart';
import '../../nutrition/models/nutrition_models.dart';
import '../models/health_draft.dart';
import '../models/nutrition_plan.dart';

/// Thin wrapper around the backend metrics endpoints used during health setup.
///
/// Endpoints used:
///   POST /metrics/targets       → calculate (no save)
///   POST /metrics/targets/save  → calculate + persist
///   POST /metrics               → record body measurement
///   POST /metrics               → onboarding profile snapshot sync (best effort)
class HealthOnboardingApi {
  HealthOnboardingApi(this._client);

  final ApiClient _client;

  // ── Calculate targets (preview – does not persist) ─────────────────────────

  Future<NutritionPlan> calculateTargets(HealthDraft draft) async {
    final body = _buildTargetBody(draft);
    final response = await _client.post('/metrics/targets', body: body);
    return NutritionPlan.fromJson(Map<String, dynamic>.from(response as Map));
  }

  // ── Mifflin–St Jeor client-side fallback ──────────────────────────────────
  /// Used when the backend call fails during the preview step.
  /// Clearly flagged in logs so it is easy to detect.
  NutritionPlan calculateLocalFallback(HealthDraft draft) {
    dev.log(
      '[HealthOnboardingApi] Using local Mifflin-St Jeor fallback '
      '(backend unreachable)',
      name: 'health_onboarding',
    );

    final w = draft.weightKg!;
    final h = draft.heightCm!;
    final a = draft.age!.toDouble();
    final isMale = draft.sex == BiologicalSex.male;

    final bmr = isMale
        ? (10 * w) + (6.25 * h) - (5 * a) + 5
        : (10 * w) + (6.25 * h) - (5 * a) - 161;

    const multipliers = {
      ActivityLevel.sedentary: 1.2,
      ActivityLevel.light: 1.375,
      ActivityLevel.moderate: 1.55,
      ActivityLevel.veryActive: 1.725,
      ActivityLevel.athlete: 1.9,
    };
    final maintenance = bmr * multipliers[draft.activityLevel!]!;

    CalorieGoalOption buildOption(double rate) {
      final adjustment = (rate * 7700.0) / 7.0;
      final minCal = isMale ? 1400.0 : 1200.0;
      final target = (maintenance - adjustment).clamp(minCal, double.infinity);
      final proteinG = (w * 1.8).roundToDouble();
      final fatG = ((target * 0.25) / 9).roundToDouble();
      final carbsG = ((target - proteinG * 4 - fatG * 9) / 4)
          .clamp(0, double.infinity)
          .roundToDouble();
      return CalorieGoalOption(
        rateKgPerWeek: rate,
        dailyDeficitKcal: maintenance - target,
        targetCaloriesKcal: target,
        macros: MacroTargets(proteinG: proteinG, carbsG: carbsG, fatG: fatG),
      );
    }

    final allRates = [-1.0, -0.5, -0.25, 0.0, 0.25, 0.5, 1.0];
    final options = allRates.map(buildOption).toList();
    final selected = draft.weeklyRateKg != null
        ? buildOption(draft.weeklyRateKg!)
        : null;

    return NutritionPlan(
      bmi: w / ((h / 100) * (h / 100)),
      bmiCategory: _bmiCategory(w / ((h / 100) * (h / 100))),
      bmrKcal: bmr,
      maintenanceCaloriesKcal: maintenance,
      selectedGoal: selected,
      goalOptions: options,
    );
  }

  // ── Save targets + profile in parallel ────────────────────────────────────

  /// Saves calorie target to metrics AND syncs it to the nutrition goals
  /// endpoint so the meal logger shows the same calorie target.
  Future<SavedNutritionPlan> saveTargets(HealthDraft draft) async {
    final body = _buildTargetBody(draft);
    final response = await _client.post('/metrics/targets/save', body: body);
    final plan = SavedNutritionPlan.fromJson(
      Map<String, dynamic>.from(response as Map),
    );
    await LocalNutritionStore.saveGoal(
      MacroGoal(
        userId: plan.userId,
        dailyCalories: plan.targetCaloriesKcal,
        proteinG: plan.macros.proteinG,
        carbsG: plan.macros.carbsG,
        fatG: plan.macros.fatG,
        updatedAt: DateTime.now(),
      ),
    );

    // ── Sync to nutrition/goals so the meal logger reads the same target ──
    // This is non-fatal: metrics target is already persisted.
    try {
      await _client.post(
        '/nutrition/goals',
        body: {
          'daily_calories': plan.targetCaloriesKcal,
          'protein_g': plan.macros.proteinG,
          'carbs_g': plan.macros.carbsG,
          'fat_g': plan.macros.fatG,
        },
      );
    } catch (e) {
      dev.log(
        '[HealthOnboardingApi] nutrition/goals sync failed (non-fatal): $e',
        name: 'health_onboarding',
      );
    }

    return plan;
  }

  /// Saves profile fields (age / sex / height / weight / activity / goal).
  Future<void> saveProfile(HealthDraft draft) async {
    final goalStr = _goalToProfileString(draft.goalType!);
    final activityStr = draft.activityLevel!.apiValue;
    final sexStr = draft.sex!.apiValue;
    final age = draft.age;

    // Mobile /profile/setup may not exist in all deployments.
    // Persist a profile snapshot via /metrics (live endpoint) so onboarding
    // body stats are saved server-side.
    await _client.post(
      '/metrics',
      body: {
        'height_m': draft.heightM,
        'weight_kg': draft.weightKg,
        'notes':
            'onboarding_profile age=$age sex=$sexStr goal=$goalStr activity=$activityStr',
      },
    );
  }

  // ── Helpers ────────────────────────────────────────────────────────────────

  Map<String, dynamic> _buildTargetBody(HealthDraft draft) {
    return {
      'weight_kg': draft.weightKg,
      'height_m': draft.heightM,
      'age_years': draft.age,
      'sex': draft.sex!.apiValue,
      'activity_level': draft.activityLevel!.apiValue,
      if (draft.weeklyRateKg != null)
        'goal_rate_kg_per_week': draft.weeklyRateKg,
    };
  }

  String _goalToProfileString(GoalType goal) {
    switch (goal) {
      case GoalType.loseWeight:
        return 'weight_loss';
      case GoalType.gainWeight:
        return 'muscle_gain';
      case GoalType.maintain:
        return 'maintenance';
    }
  }

  String _bmiCategory(double bmi) {
    if (bmi < 18.5) return 'Underweight';
    if (bmi < 25.0) return 'Normal';
    if (bmi < 30.0) return 'Overweight';
    return 'Obese';
  }
}
