/// Response models that mirror the backend CalorieTargetOut /
/// SavedCalorieTargetOut schemas.
library;

class MacroTargets {
  const MacroTargets({
    required this.proteinG,
    required this.carbsG,
    required this.fatG,
  });

  final double proteinG;
  final double carbsG;
  final double fatG;

  factory MacroTargets.fromJson(Map<String, dynamic> j) => MacroTargets(
        proteinG: (j['protein_g'] as num).toDouble(),
        carbsG:   (j['carbs_g']   as num).toDouble(),
        fatG:     (j['fat_g']     as num).toDouble(),
      );
}

class CalorieGoalOption {
  const CalorieGoalOption({
    required this.rateKgPerWeek,
    required this.dailyDeficitKcal,
    required this.targetCaloriesKcal,
    required this.macros,
  });

  final double rateKgPerWeek;
  final double dailyDeficitKcal;  // positive = deficit, negative = surplus
  final double targetCaloriesKcal;
  final MacroTargets macros;

  factory CalorieGoalOption.fromJson(Map<String, dynamic> j) => CalorieGoalOption(
        rateKgPerWeek:      (j['rate_kg_per_week']      as num).toDouble(),
        dailyDeficitKcal:   (j['daily_deficit_kcal']    as num).toDouble(),
        targetCaloriesKcal: (j['target_calories_kcal']  as num).toDouble(),
        macros: MacroTargets.fromJson(
            Map<String, dynamic>.from(j['macros'] as Map)),
      );
}

class NutritionPlan {
  const NutritionPlan({
    required this.bmi,
    required this.bmiCategory,
    required this.bmrKcal,
    required this.maintenanceCaloriesKcal,
    this.selectedGoal,
    required this.goalOptions,
  });

  final double bmi;
  final String bmiCategory;
  final double bmrKcal;
  final double maintenanceCaloriesKcal;
  final CalorieGoalOption? selectedGoal;
  final List<CalorieGoalOption> goalOptions;

  factory NutritionPlan.fromJson(Map<String, dynamic> j) => NutritionPlan(
        bmi:                      (j['bmi']                        as num).toDouble(),
        bmiCategory:               j['bmi_category']               as String,
        bmrKcal:                  (j['bmr_kcal']                   as num).toDouble(),
        maintenanceCaloriesKcal:  (j['maintenance_calories_kcal']  as num).toDouble(),
        selectedGoal: j['selected_goal'] == null
            ? null
            : CalorieGoalOption.fromJson(
                Map<String, dynamic>.from(j['selected_goal'] as Map)),
        goalOptions: (j['goal_options'] as List<dynamic>)
            .cast<Map<String, dynamic>>()
            .map(CalorieGoalOption.fromJson)
            .toList(),
      );
}

class SavedNutritionPlan {
  const SavedNutritionPlan({
    required this.id,
    required this.userId,
    required this.goalRateKgPerWeek,
    required this.bmi,
    required this.bmiCategory,
    required this.bmrKcal,
    required this.maintenanceCaloriesKcal,
    required this.dailyDeficitKcal,
    required this.targetCaloriesKcal,
    required this.macros,
  });

  final String id;
  final String userId;
  final double goalRateKgPerWeek;
  final double bmi;
  final String bmiCategory;
  final double bmrKcal;
  final double maintenanceCaloriesKcal;
  final double dailyDeficitKcal;
  final double targetCaloriesKcal;
  final MacroTargets macros;

  factory SavedNutritionPlan.fromJson(Map<String, dynamic> j) => SavedNutritionPlan(
        id:                       j['id']                         as String,
        userId:                   j['user_id']                    as String,
        goalRateKgPerWeek:        (j['goal_rate_kg_per_week']     as num).toDouble(),
        bmi:                      (j['bmi']                       as num).toDouble(),
        bmiCategory:               j['bmi_category']              as String,
        bmrKcal:                  (j['bmr_kcal']                  as num).toDouble(),
        maintenanceCaloriesKcal:  (j['maintenance_calories_kcal'] as num).toDouble(),
        dailyDeficitKcal:         (j['daily_deficit_kcal']        as num).toDouble(),
        targetCaloriesKcal:       (j['target_calories_kcal']      as num).toDouble(),
        macros: MacroTargets.fromJson(
            Map<String, dynamic>.from(j['macros'] as Map)),
      );
}
