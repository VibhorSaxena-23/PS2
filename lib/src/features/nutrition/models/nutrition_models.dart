// ── Helpers ───────────────────────────────────────────────────────────────────

double _d(dynamic v) => (v as num).toDouble();
double? _nd(dynamic v) => v == null ? null : (v as num).toDouble();

// ── Daily Summary ─────────────────────────────────────────────────────────────

class DailyNutritionSummary {
  DailyNutritionSummary({
    required this.logDate,
    required this.userId,
    required this.total,
    required this.meals,
    this.goalProgress,
  });

  final String logDate;
  final String userId;
  final MacroTotals total;
  final List<MealGroup> meals;
  final GoalProgress? goalProgress;

  factory DailyNutritionSummary.fromJson(Map<String, dynamic> json) {
    final mealsJson = (json['meals'] as List<dynamic>? ?? [])
        .cast<Map<String, dynamic>>();
    return DailyNutritionSummary(
      logDate: json['log_date'] as String,
      userId: json['user_id'] as String,
      total: MacroTotals.fromJson(
        Map<String, dynamic>.from(json['total'] as Map),
      ),
      meals: mealsJson.map(MealGroup.fromJson).toList(),
      goalProgress: json['goal_progress'] != null
          ? GoalProgress.fromJson(
              Map<String, dynamic>.from(json['goal_progress'] as Map),
            )
          : null,
    );
  }

  Map<String, dynamic> toJson() => {
    'log_date': logDate,
    'user_id': userId,
    'total': total.toJson(),
    'meals': meals.map((meal) => meal.toJson()).toList(),
    if (goalProgress != null) 'goal_progress': goalProgress!.toJson(),
  };
}

// ── Macros ────────────────────────────────────────────────────────────────────

class MacroTotals {
  MacroTotals({
    required this.calories,
    required this.proteinG,
    required this.carbsG,
    required this.fatG,
    required this.fiberG,
  });

  final double calories;
  final double proteinG;
  final double carbsG;
  final double fatG;
  final double fiberG;

  factory MacroTotals.fromJson(Map<String, dynamic> json) {
    return MacroTotals(
      calories: _d(json['calories']),
      proteinG: _d(json['protein_g']),
      carbsG: _d(json['carbs_g']),
      fatG: _d(json['fat_g']),
      fiberG: _d(json['fiber_g']),
    );
  }

  Map<String, dynamic> toJson() => {
    'calories': calories,
    'protein_g': proteinG,
    'carbs_g': carbsG,
    'fat_g': fatG,
    'fiber_g': fiberG,
  };
}

// ── Meal Group ────────────────────────────────────────────────────────────────

class MealGroup {
  MealGroup({
    required this.mealType,
    required this.logs,
    required this.subtotal,
  });

  final String mealType;
  final List<FoodLog> logs;
  final MacroTotals subtotal;

  String get displayMealType {
    switch (mealType) {
      case 'breakfast':
        return 'Breakfast';
      case 'lunch':
        return 'Lunch';
      case 'dinner':
        return 'Dinner';
      case 'snack':
        return 'Snack';
      case 'pre_workout':
        return 'Pre-Workout';
      case 'post_workout':
        return 'Post-Workout';
      default:
        return mealType;
    }
  }

  factory MealGroup.fromJson(Map<String, dynamic> json) {
    final logsJson = (json['logs'] as List<dynamic>? ?? [])
        .cast<Map<String, dynamic>>();
    return MealGroup(
      mealType: json['meal_type'] as String,
      logs: logsJson.map(FoodLog.fromJson).toList(),
      subtotal: MacroTotals.fromJson(
        Map<String, dynamic>.from(json['subtotal'] as Map),
      ),
    );
  }

  Map<String, dynamic> toJson() => {
    'meal_type': mealType,
    'logs': logs.map((log) => log.toJson()).toList(),
    'subtotal': subtotal.toJson(),
  };
}

// ── Food Log ──────────────────────────────────────────────────────────────────

class FoodLog {
  FoodLog({
    required this.id,
    required this.userId,
    required this.foodId,
    required this.foodName,
    required this.category,
    required this.quantityG,
    required this.mealType,
    required this.logDate,
    required this.calories,
    required this.proteinG,
    required this.carbsG,
    required this.fatG,
    required this.fiberG,
    required this.loggedAt,
  });

  final String id;
  final String userId;
  final int foodId;
  final String foodName;
  final String category;
  final double quantityG;
  final String mealType;
  final String logDate;
  final double calories;
  final double proteinG;
  final double carbsG;
  final double fatG;
  final double fiberG;
  final DateTime loggedAt;

  factory FoodLog.fromJson(Map<String, dynamic> json) {
    return FoodLog(
      id: json['id'] as String,
      userId: json['user_id'] as String,
      foodId: json['food_id'] as int,
      foodName: json['food_name'] as String,
      category: json['category'] as String,
      quantityG: _d(json['quantity_g']),
      mealType: json['meal_type'] as String,
      logDate: json['log_date'] as String,
      calories: _d(json['calories']),
      proteinG: _d(json['protein_g']),
      carbsG: _d(json['carbs_g']),
      fatG: _d(json['fat_g']),
      fiberG: _d(json['fiber_g']),
      loggedAt: DateTime.parse(json['logged_at'] as String).toLocal(),
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'user_id': userId,
    'food_id': foodId,
    'food_name': foodName,
    'category': category,
    'quantity_g': quantityG,
    'meal_type': mealType,
    'log_date': logDate,
    'calories': calories,
    'protein_g': proteinG,
    'carbs_g': carbsG,
    'fat_g': fatG,
    'fiber_g': fiberG,
    'logged_at': loggedAt.toUtc().toIso8601String(),
  };
}

// ── Goal Progress ─────────────────────────────────────────────────────────────

class GoalProgress {
  GoalProgress({
    this.caloriesTarget,
    required this.caloriesConsumed,
    this.caloriesRemaining,
    this.proteinTargetG,
    required this.proteinConsumedG,
    this.carbsTargetG,
    required this.carbsConsumedG,
    this.fatTargetG,
    required this.fatConsumedG,
    this.percentCalories,
  });

  final double? caloriesTarget;
  final double caloriesConsumed;
  final double? caloriesRemaining;
  final double? proteinTargetG;
  final double proteinConsumedG;
  final double? carbsTargetG;
  final double carbsConsumedG;
  final double? fatTargetG;
  final double fatConsumedG;
  final double? percentCalories;

  factory GoalProgress.fromJson(Map<String, dynamic> json) {
    return GoalProgress(
      caloriesTarget: _nd(json['calories_target']),
      caloriesConsumed: _d(json['calories_consumed']),
      caloriesRemaining: _nd(json['calories_remaining']),
      proteinTargetG: _nd(json['protein_target_g']),
      proteinConsumedG: _d(json['protein_consumed_g']),
      carbsTargetG: _nd(json['carbs_target_g']),
      carbsConsumedG: _d(json['carbs_consumed_g']),
      fatTargetG: _nd(json['fat_target_g']),
      fatConsumedG: _d(json['fat_consumed_g']),
      percentCalories: _nd(json['percent_calories']),
    );
  }

  Map<String, dynamic> toJson() => {
    'calories_target': caloriesTarget,
    'calories_consumed': caloriesConsumed,
    'calories_remaining': caloriesRemaining,
    'protein_target_g': proteinTargetG,
    'protein_consumed_g': proteinConsumedG,
    'carbs_target_g': carbsTargetG,
    'carbs_consumed_g': carbsConsumedG,
    'fat_target_g': fatTargetG,
    'fat_consumed_g': fatConsumedG,
    'percent_calories': percentCalories,
  };
}

// ── Food Search ───────────────────────────────────────────────────────────────

class FoodSearchItem {
  FoodSearchItem({
    required this.id,
    required this.name,
    required this.category,
    required this.caloriesPer100g,
    required this.proteinPer100g,
    required this.carbsPer100g,
    required this.fatPer100g,
    required this.fiberPer100g,
  });

  final int id;
  final String name;
  final String category;
  final double caloriesPer100g;
  final double proteinPer100g;
  final double carbsPer100g;
  final double fatPer100g;
  final double fiberPer100g;

  factory FoodSearchItem.fromJson(Map<String, dynamic> json) {
    return FoodSearchItem(
      id: json['id'] as int,
      name: json['name'] as String,
      category: json['category'] as String,
      caloriesPer100g: _d(json['calories_per_100g']),
      proteinPer100g: _d(json['protein_per_100g']),
      carbsPer100g: _d(json['carbs_per_100g']),
      fatPer100g: _d(json['fat_per_100g']),
      fiberPer100g: _d(json['fiber_per_100g']),
    );
  }
}

// ── Macro Preview ─────────────────────────────────────────────────────────────

class MacroPreview {
  MacroPreview({
    required this.calories,
    required this.proteinG,
    required this.carbsG,
    required this.fatG,
    required this.fiberG,
  });

  final double calories;
  final double proteinG;
  final double carbsG;
  final double fatG;
  final double fiberG;

  factory MacroPreview.fromJson(Map<String, dynamic> json) {
    return MacroPreview(
      calories: _d(json['calories']),
      proteinG: _d(json['protein_g']),
      carbsG: _d(json['carbs_g']),
      fatG: _d(json['fat_g']),
      fiberG: _d(json['fiber_g']),
    );
  }
}

// ── Macro Goal ───────────────────────────────────────────────────────────────

class MacroGoal {
  MacroGoal({
    required this.userId,
    required this.dailyCalories,
    required this.proteinG,
    required this.carbsG,
    required this.fatG,
    required this.updatedAt,
  });

  final String userId;
  final double dailyCalories;
  final double proteinG;
  final double carbsG;
  final double fatG;
  final DateTime updatedAt;

  factory MacroGoal.fromJson(Map<String, dynamic> json) {
    return MacroGoal(
      userId: json['user_id'] as String,
      dailyCalories: _d(json['daily_calories']),
      proteinG: _d(json['protein_g']),
      carbsG: _d(json['carbs_g']),
      fatG: _d(json['fat_g']),
      updatedAt: DateTime.parse(json['updated_at'] as String).toLocal(),
    );
  }

  Map<String, dynamic> toJson() => {
    'user_id': userId,
    'daily_calories': dailyCalories,
    'protein_g': proteinG,
    'carbs_g': carbsG,
    'fat_g': fatG,
    'updated_at': updatedAt.toUtc().toIso8601String(),
  };
}

// ── Weekly Summary Day ────────────────────────────────────────────────────────

class WeeklySummaryDay {
  WeeklySummaryDay({
    required this.date,
    required this.calories,
    required this.proteinG,
    required this.carbsG,
    required this.fatG,
    required this.logCount,
  });

  final String date;
  final double calories;
  final double proteinG;
  final double carbsG;
  final double fatG;
  final int logCount;

  factory WeeklySummaryDay.fromJson(Map<String, dynamic> json) {
    return WeeklySummaryDay(
      date: json['date'] as String,
      calories: _d(json['calories']),
      proteinG: _d(json['protein_g']),
      carbsG: _d(json['carbs_g']),
      fatG: _d(json['fat_g']),
      logCount: json['log_count'] as int,
    );
  }

  Map<String, dynamic> toJson() => {
    'date': date,
    'calories': calories,
    'protein_g': proteinG,
    'carbs_g': carbsG,
    'fat_g': fatG,
    'log_count': logCount,
  };
}
