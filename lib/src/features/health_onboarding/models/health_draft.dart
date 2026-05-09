/// In-memory draft state for the health onboarding wizard.
/// All fields are nullable — the wizard validates each step before Next.
library;

// ── Enums ─────────────────────────────────────────────────────────────────────

enum BiologicalSex { male, female }

extension BiologicalSexLabel on BiologicalSex {
  String get label => this == BiologicalSex.male ? 'Male' : 'Female';
  String get apiValue => name; // 'male' | 'female'
}

enum ActivityLevel {
  sedentary,
  light,
  moderate,
  veryActive,
  athlete,
}

extension ActivityLevelLabel on ActivityLevel {
  String get label {
    switch (this) {
      case ActivityLevel.sedentary:
        return 'Sedentary';
      case ActivityLevel.light:
        return 'Lightly Active';
      case ActivityLevel.moderate:
        return 'Moderately Active';
      case ActivityLevel.veryActive:
        return 'Very Active';
      case ActivityLevel.athlete:
        return 'Athlete';
    }
  }

  String get description {
    switch (this) {
      case ActivityLevel.sedentary:
        return 'Little or no exercise, desk job';
      case ActivityLevel.light:
        return '1–3 days/week light exercise';
      case ActivityLevel.moderate:
        return '3–5 days/week moderate exercise';
      case ActivityLevel.veryActive:
        return '6–7 days/week hard exercise';
      case ActivityLevel.athlete:
        return 'Twice daily / physical job';
    }
  }

  String get apiValue {
    switch (this) {
      case ActivityLevel.sedentary:
        return 'sedentary';
      case ActivityLevel.light:
        return 'light';
      case ActivityLevel.moderate:
        return 'moderate';
      case ActivityLevel.veryActive:
        return 'very_active';
      case ActivityLevel.athlete:
        return 'athlete';
    }
  }
}

enum GoalType {
  loseWeight,
  gainWeight,
  maintain,
}

extension GoalTypeLabel on GoalType {
  String get label {
    switch (this) {
      case GoalType.loseWeight:
        return 'Lose Weight';
      case GoalType.gainWeight:
        return 'Gain Weight';
      case GoalType.maintain:
        return 'Maintain Weight';
    }
  }

  String get description {
    switch (this) {
      case GoalType.loseWeight:
        return 'Burn fat, create a calorie deficit';
      case GoalType.gainWeight:
        return 'Build muscle, create a calorie surplus';
      case GoalType.maintain:
        return 'Stay at current weight, balanced intake';
    }
  }
}

enum FoodPreference { nonVeg, vegetarian, eggetarian, vegan }

extension FoodPreferenceLabel on FoodPreference {
  String get label {
    switch (this) {
      case FoodPreference.nonVeg:
        return 'Non-Veg';
      case FoodPreference.vegetarian:
        return 'Vegetarian';
      case FoodPreference.eggetarian:
        return 'Eggetarian';
      case FoodPreference.vegan:
        return 'Vegan';
    }
  }
}

// ── Preset health conditions ──────────────────────────────────────────────────

const kPresetConditions = [
  'Diabetes',
  'Thyroid',
  'Hypertension',
  'PCOS / PCOD',
  'High Cholesterol',
  'Knee Injury',
  'Back Pain',
  'Heart Condition',
  'Asthma',
];

// ── Allowed weekly rate values (mirrors backend ALLOWED_GOAL_RATES) ───────────
// Negative = gain, 0 = maintain, positive = lose
const kWeeklyRatesLose  = [0.25, 0.5, 1.0];
const kWeeklyRatesGain  = [-0.25, -0.5, -1.0]; // stored as positive in UI label
const kWeeklyRateMaintain = 0.0;

// ── Draft model ───────────────────────────────────────────────────────────────

class HealthDraft {
  const HealthDraft({
    this.heightCm,
    this.weightKg,
    this.age,
    this.sex,
    this.activityLevel,
    this.goalType,
    this.weeklyRateKg,          // API value: positive=lose, negative=gain, 0=maintain
    this.healthConditions = const [],
    this.healthNotes,
    this.foodPreference,
    this.wakeTime,
    this.sleepTime,
    this.workoutTime,
  });

  final double? heightCm;
  final double? weightKg;
  final int? age;
  final BiologicalSex? sex;
  final ActivityLevel? activityLevel;
  final GoalType? goalType;
  final double? weeklyRateKg;
  final List<String> healthConditions;
  final String? healthNotes;
  final FoodPreference? foodPreference;
  final String? wakeTime;    // e.g. "06:30"
  final String? sleepTime;   // e.g. "22:00"
  final String? workoutTime; // e.g. "07:00"

  // ── Step validations ───────────────────────────────────────────────────────

  bool get isBodyValid {
    if (heightCm == null || weightKg == null || age == null || sex == null) return false;
    if (heightCm! < 100 || heightCm! > 250) return false;
    if (weightKg! < 25  || weightKg! > 300) return false;
    if (age! < 13 || age! > 100) return false;
    return true;
  }

  bool get isActivityGoalValid =>
      activityLevel != null && goalType != null;

  bool get isRateValid {
    if (goalType == GoalType.maintain) return weeklyRateKg == kWeeklyRateMaintain;
    return weeklyRateKg != null && weeklyRateKg != kWeeklyRateMaintain;
  }

  // ── API mapping helpers ────────────────────────────────────────────────────

  double? get heightM => heightCm != null ? heightCm! / 100.0 : null;

  // ── copyWith ───────────────────────────────────────────────────────────────

  HealthDraft copyWith({
    double? heightCm,
    double? weightKg,
    int? age,
    BiologicalSex? sex,
    ActivityLevel? activityLevel,
    GoalType? goalType,
    double? weeklyRateKg,
    List<String>? healthConditions,
    String? healthNotes,
    bool clearHealthNotes = false,
    FoodPreference? foodPreference,
    bool clearFoodPreference = false,
    String? wakeTime,
    bool clearWakeTime = false,
    String? sleepTime,
    bool clearSleepTime = false,
    String? workoutTime,
    bool clearWorkoutTime = false,
  }) {
    return HealthDraft(
      heightCm: heightCm ?? this.heightCm,
      weightKg: weightKg ?? this.weightKg,
      age: age ?? this.age,
      sex: sex ?? this.sex,
      activityLevel: activityLevel ?? this.activityLevel,
      goalType: goalType ?? this.goalType,
      weeklyRateKg: weeklyRateKg ?? this.weeklyRateKg,
      healthConditions: healthConditions ?? this.healthConditions,
      healthNotes: clearHealthNotes ? null : (healthNotes ?? this.healthNotes),
      foodPreference: clearFoodPreference ? null : (foodPreference ?? this.foodPreference),
      wakeTime: clearWakeTime ? null : (wakeTime ?? this.wakeTime),
      sleepTime: clearSleepTime ? null : (sleepTime ?? this.sleepTime),
      workoutTime: clearWorkoutTime ? null : (workoutTime ?? this.workoutTime),
    );
  }
}
