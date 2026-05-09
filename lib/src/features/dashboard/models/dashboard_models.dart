class ProgressDashboard {
  ProgressDashboard({
    required this.userId,
    required this.generatedAt,
    required this.lookbackWeeks,
    required this.weightLookbackDays,
    required this.today,
    required this.last7Days,
    required this.visualInsights,
  });

  final String userId;
  final DateTime generatedAt;
  final int lookbackWeeks;
  final int weightLookbackDays;
  final TodaySummary today;
  final Last7DaysSummary last7Days;
  final VisualInsights visualInsights;

  factory ProgressDashboard.fromJson(Map<String, dynamic> json) {
    return ProgressDashboard(
      userId: json['user_id'] as String,
      generatedAt: DateTime.parse(json['generated_at'] as String),
      lookbackWeeks: json['lookback_weeks'] as int,
      weightLookbackDays: json['weight_lookback_days'] as int,
      today: TodaySummary.fromJson(
        Map<String, dynamic>.from(json['today'] as Map),
      ),
      last7Days: Last7DaysSummary.fromJson(
        Map<String, dynamic>.from(json['last_7_days'] as Map),
      ),
      visualInsights: VisualInsights.fromJson(
        Map<String, dynamic>.from(json['visual_insights'] as Map),
      ),
    );
  }
}

class TodaySummary {
  TodaySummary({
    required this.date,
    required this.workoutsCompleted,
    required this.workoutVolume,
    required this.workoutDurationSec,
    required this.stepCount,
    required this.stepGoal,
    required this.hydrationMl,
    required this.hydrationGoalMl,
    required this.caloriesConsumed,
    this.caloriesTarget,
    this.caloriesRemaining,
    required this.proteinG,
    required this.carbsG,
    required this.fatG,
    required this.fiberG,
  });

  final String date;
  final int workoutsCompleted;
  final double workoutVolume;
  final int workoutDurationSec;
  final int stepCount;
  final int stepGoal;
  final double hydrationMl;
  final double hydrationGoalMl;
  final double caloriesConsumed;
  final double? caloriesTarget;
  final double? caloriesRemaining;
  final double proteinG;
  final double carbsG;
  final double fatG;
  final double fiberG;

  factory TodaySummary.fromJson(Map<String, dynamic> json) {
    return TodaySummary(
      date: json['date'] as String,
      workoutsCompleted: json['workouts_completed'] as int,
      workoutVolume: _d(json['workout_volume']),
      workoutDurationSec: json['workout_duration_sec'] as int,
      stepCount: json['step_count'] as int,
      stepGoal: json['step_goal'] as int,
      hydrationMl: _d(json['hydration_ml']),
      hydrationGoalMl: _d(json['hydration_goal_ml']),
      caloriesConsumed: _d(json['calories_consumed']),
      caloriesTarget: _nd(json['calories_target']),
      caloriesRemaining: _nd(json['calories_remaining']),
      proteinG: _d(json['protein_g']),
      carbsG: _d(json['carbs_g']),
      fatG: _d(json['fat_g']),
      fiberG: _d(json['fiber_g']),
    );
  }
}

class Last7DaysSummary {
  Last7DaysSummary({
    required this.activeDays,
    required this.completedSessions,
    required this.totalVolume,
    required this.totalDurationSec,
    this.avgSessionDurationSec,
  });

  final int activeDays;
  final int completedSessions;
  final double totalVolume;
  final int totalDurationSec;
  final int? avgSessionDurationSec;

  factory Last7DaysSummary.fromJson(Map<String, dynamic> json) {
    return Last7DaysSummary(
      activeDays: json['active_days'] as int,
      completedSessions: json['completed_sessions'] as int,
      totalVolume: _d(json['total_volume']),
      totalDurationSec: json['total_duration_sec'] as int,
      avgSessionDurationSec: json['avg_session_duration_sec'] as int?,
    );
  }
}

class VisualInsights {
  VisualInsights({
    required this.workoutFrequency,
    required this.weightPoints,
    required this.weightTrend,
  });

  final List<WorkoutFrequencyPoint> workoutFrequency;
  final List<WeightPoint> weightPoints;
  final WeightTrend weightTrend;

  factory VisualInsights.fromJson(Map<String, dynamic> json) {
    final freqList = (json['workout_frequency'] as List<dynamic>)
        .cast<Map<String, dynamic>>()
        .map(WorkoutFrequencyPoint.fromJson)
        .toList();
    final weightList = (json['weight_points'] as List<dynamic>)
        .cast<Map<String, dynamic>>()
        .map(WeightPoint.fromJson)
        .toList();
    return VisualInsights(
      workoutFrequency: freqList,
      weightPoints: weightList,
      weightTrend: WeightTrend.fromJson(
        Map<String, dynamic>.from(json['weight_trend'] as Map),
      ),
    );
  }
}

class WorkoutFrequencyPoint {
  WorkoutFrequencyPoint({
    required this.weekStart,
    required this.sessionCount,
    required this.totalVolume,
    required this.totalDurationSec,
  });

  final String weekStart;
  final int sessionCount;
  final double totalVolume;
  final int totalDurationSec;

  factory WorkoutFrequencyPoint.fromJson(Map<String, dynamic> json) {
    return WorkoutFrequencyPoint(
      weekStart: json['week_start'] as String,
      sessionCount: json['session_count'] as int,
      totalVolume: _d(json['total_volume']),
      totalDurationSec: json['total_duration_sec'] as int,
    );
  }
}

class WeightPoint {
  WeightPoint({required this.date, required this.weightKg});

  final String date;
  final double weightKg;

  factory WeightPoint.fromJson(Map<String, dynamic> json) {
    return WeightPoint(
      date: json['date'] as String,
      weightKg: _d(json['weight_kg']),
    );
  }
}

class WeightTrend {
  WeightTrend({
    this.startWeightKg,
    this.latestWeightKg,
    this.changeKg,
    this.changePercent,
    required this.dataPoints,
  });

  final double? startWeightKg;
  final double? latestWeightKg;
  final double? changeKg;
  final double? changePercent;
  final int dataPoints;

  factory WeightTrend.fromJson(Map<String, dynamic> json) {
    return WeightTrend(
      startWeightKg: _nd(json['start_weight_kg']),
      latestWeightKg: _nd(json['latest_weight_kg']),
      changeKg: _nd(json['change_kg']),
      changePercent: _nd(json['change_percent']),
      dataPoints: json['data_points'] as int,
    );
  }
}

double _d(dynamic v) => (v as num).toDouble();
double? _nd(dynamic v) => v == null ? null : (v as num).toDouble();
