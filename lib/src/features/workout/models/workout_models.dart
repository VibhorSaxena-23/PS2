class WorkoutSession {
  WorkoutSession({
    required this.id,
    required this.userId,
    this.title,
    this.notes,
    required this.startedAt,
    this.finishedAt,
    this.durationSec,
    required this.isCompleted,
    required this.exercises,
    required this.totalVolume,
    required this.createdAt,
    required this.updatedAt,
  });

  final String id;
  final String userId;
  final String? title;
  final String? notes;
  final DateTime startedAt;
  final DateTime? finishedAt;
  final int? durationSec;
  final bool isCompleted;
  final List<SessionExercise> exercises;
  final double totalVolume;
  final DateTime createdAt;
  final DateTime updatedAt;

  factory WorkoutSession.fromJson(Map<String, dynamic> json) {
    final exJson = (json['exercises'] as List<dynamic>? ?? [])
        .cast<Map<String, dynamic>>();
    return WorkoutSession(
      id: json['id'] as String,
      userId: json['user_id'] as String,
      title: json['title'] as String?,
      notes: json['notes'] as String?,
      startedAt: DateTime.parse(json['started_at'] as String).toLocal(),
      finishedAt: json['finished_at'] != null
          ? DateTime.parse(json['finished_at'] as String).toLocal()
          : null,
      durationSec: json['duration_sec'] as int?,
      isCompleted: json['is_completed'] as bool,
      exercises: exJson.map(SessionExercise.fromJson).toList(),
      totalVolume: _d(json['total_volume']),
      createdAt: DateTime.parse(json['created_at'] as String).toLocal(),
      updatedAt: DateTime.parse(json['updated_at'] as String).toLocal(),
    );
  }
}

class SessionExercise {
  SessionExercise({
    required this.id,
    required this.exerciseId,
    required this.exerciseName,
    this.primaryMuscle,
    this.equipment,
    required this.orderIndex,
    this.notes,
    required this.sets,
    required this.volume,
    required this.maxWeight,
  });

  final String id;
  final int exerciseId;
  final String exerciseName;
  final String? primaryMuscle;
  final String? equipment;
  final int orderIndex;
  final String? notes;
  final List<ExerciseSet> sets;
  final double volume;
  final double maxWeight;

  factory SessionExercise.fromJson(Map<String, dynamic> json) {
    final setJson = (json['sets'] as List<dynamic>? ?? [])
        .cast<Map<String, dynamic>>();
    return SessionExercise(
      id: json['id'] as String,
      exerciseId: json['exercise_id'] as int,
      exerciseName: json['exercise_name'] as String,
      primaryMuscle: json['primary_muscle'] as String?,
      equipment: json['equipment'] as String?,
      orderIndex: json['order_index'] as int,
      notes: json['notes'] as String?,
      sets: setJson.map(ExerciseSet.fromJson).toList(),
      volume: _d(json['volume']),
      maxWeight: _d(json['max_weight']),
    );
  }
}

class ExerciseSet {
  ExerciseSet({
    required this.id,
    required this.setNumber,
    required this.setType,
    this.reps,
    this.weightKg,
    this.rpe,
    this.rir,
    this.durationSec,
    this.distanceM,
    this.note,
    required this.isCompleted,
  });

  final String id;
  final int setNumber;
  final String setType;
  final int? reps;
  final double? weightKg;
  final double? rpe;
  final int? rir;
  final int? durationSec;
  final double? distanceM;
  final String? note;
  final bool isCompleted;

  factory ExerciseSet.fromJson(Map<String, dynamic> json) {
    return ExerciseSet(
      id: json['id'] as String,
      setNumber: json['set_number'] as int,
      setType: json['set_type'] as String,
      reps: json['reps'] as int?,
      weightKg: _nd(json['weight_kg']),
      rpe: _nd(json['rpe']),
      rir: json['rir'] as int?,
      durationSec: json['duration_sec'] as int?,
      distanceM: _nd(json['distance_m']),
      note: json['note'] as String?,
      isCompleted: json['is_completed'] as bool,
    );
  }
}

class SessionHistoryPage {
  SessionHistoryPage({
    required this.items,
    required this.total,
    required this.page,
    required this.pageSize,
    required this.totalPages,
  });

  final List<WorkoutSession> items;
  final int total;
  final int page;
  final int pageSize;
  final int totalPages;

  factory SessionHistoryPage.fromJson(Map<String, dynamic> json) {
    final itemsJson = (json['items'] as List<dynamic>? ?? [])
        .cast<Map<String, dynamic>>();
    return SessionHistoryPage(
      items: itemsJson.map(WorkoutSession.fromJson).toList(),
      total: json['total'] as int? ?? 0,
      page: json['page'] as int? ?? 1,
      pageSize: json['page_size'] as int? ?? 20,
      totalPages: json['total_pages'] as int? ?? 0,
    );
  }
}

/// Request payload for creating a new workout session.
class CreateSessionRequest {
  CreateSessionRequest({
    this.title,
    this.notes,
    this.startedAt,
    required this.exercises,
  });

  final String? title;
  final String? notes;
  final DateTime? startedAt;
  final List<CreateExerciseRequest> exercises;

  Map<String, dynamic> toJson() {
    final json = <String, dynamic>{};
    if (title != null) json['title'] = title;
    if (notes != null) json['notes'] = notes;
    if (startedAt != null) json['started_at'] = startedAt!.toUtc().toIso8601String();
    json['exercises'] = exercises.map((e) => e.toJson()).toList();
    return json;
  }
}

/// Request payload for updating an existing session.
class UpdateSessionRequest {
  UpdateSessionRequest({
    this.title,
    this.notes,
    this.exercises,
  });

  final String? title;
  final String? notes;
  final List<CreateExerciseRequest>? exercises;

  Map<String, dynamic> toJson() {
    final json = <String, dynamic>{};
    if (title != null) json['title'] = title;
    if (notes != null) json['notes'] = notes;
    if (exercises != null) {
      json['exercises'] = exercises!.map((e) => e.toJson()).toList();
    }
    return json;
  }
}

class CreateExerciseRequest {
  CreateExerciseRequest({
    required this.exerciseId,
    this.orderIndex = 0,
    this.notes,
    required this.sets,
  });

  final int exerciseId;
  final int orderIndex;
  final String? notes;
  final List<CreateSetRequest> sets;

  Map<String, dynamic> toJson() {
    final json = <String, dynamic>{
      'exercise_id': exerciseId,
      'order_index': orderIndex,
      'sets': sets.map((s) => s.toJson()).toList(),
    };
    if (notes != null) json['notes'] = notes;
    return json;
  }
}

class CreateSetRequest {
  CreateSetRequest({
    required this.setNumber,
    this.setType = 'NORMAL',
    this.reps,
    this.weightKg,
    this.rpe,
    this.rir,
    this.durationSec,
    this.distanceM,
    this.note,
    this.isCompleted = false,
  });

  final int setNumber;
  final String setType;
  final int? reps;
  final double? weightKg;
  final double? rpe;
  final int? rir;
  final int? durationSec;
  final double? distanceM;
  final String? note;
  final bool isCompleted;

  Map<String, dynamic> toJson() {
    final json = <String, dynamic>{
      'set_number': setNumber,
      'set_type': setType,
      'is_completed': isCompleted,
    };
    if (reps != null) json['reps'] = reps;
    if (weightKg != null) json['weight_kg'] = weightKg;
    if (rpe != null) json['rpe'] = rpe;
    if (rir != null) json['rir'] = rir;
    if (durationSec != null) json['duration_sec'] = durationSec;
    if (distanceM != null) json['distance_m'] = distanceM;
    if (note != null) json['note'] = note;
    return json;
  }
}

double _d(dynamic v) => (v as num).toDouble();
double? _nd(dynamic v) => v == null ? null : (v as num).toDouble();

// ── Exercise catalog models ───────────────────────────────────────────────────

class ExerciseItem {
  const ExerciseItem({
    required this.id,
    required this.name,
    this.primaryMuscle,
    this.secondaryMuscles,
    this.equipment,
    this.difficulty,
    this.category,
    this.instructions,
    this.imageUrl,
  });

  final int id;
  final String name;
  final String? primaryMuscle;
  final List<String>? secondaryMuscles;
  final String? equipment;
  final String? difficulty;
  final String? category;
  final String? instructions;
  final String? imageUrl;

  factory ExerciseItem.fromJson(Map<String, dynamic> json) {
    return ExerciseItem(
      id: json['id'] as int,
      // Backend returns 'exercise_name'; support 'name' as fallback
      name: (json['exercise_name'] ?? json['name']) as String,
      primaryMuscle: json['primary_muscle'] as String?,
      secondaryMuscles: json['secondary_muscles'] != null
          ? (json['secondary_muscles'] as List<dynamic>).cast<String>()
          : null,
      equipment: json['equipment'] as String?,
      difficulty: json['difficulty'] as String?,
      category: json['category'] as String?,
      instructions: json['instructions'] as String?,
      imageUrl: json['image_url'] as String?,
    );
  }
}

class ExercisePage {
  const ExercisePage({
    required this.items,
    required this.total,
    required this.page,
    required this.pageSize,
    required this.totalPages,
  });

  final List<ExerciseItem> items;
  final int total;
  final int page;
  final int pageSize;
  final int totalPages;

  factory ExercisePage.fromJson(Map<String, dynamic> json) {
    return ExercisePage(
      items: (json['items'] as List<dynamic>? ?? [])
          .cast<Map<String, dynamic>>()
          .map(ExerciseItem.fromJson)
          .toList(),
      total: json['total'] as int? ?? 0,
      page: json['page'] as int? ?? 1,
      pageSize: json['page_size'] as int? ?? 20,
      totalPages: json['total_pages'] as int? ?? 0,
    );
  }
}

class MuscleGroups {
  const MuscleGroups({
    required this.primaryMuscles,
    required this.secondaryMuscles,
  });

  final List<String> primaryMuscles;
  final List<String> secondaryMuscles;

  factory MuscleGroups.fromJson(Map<String, dynamic> json) {
    return MuscleGroups(
      primaryMuscles:
          (json['primary_muscles'] as List<dynamic>? ?? []).cast<String>(),
      secondaryMuscles:
          (json['secondary_muscles'] as List<dynamic>? ?? []).cast<String>(),
    );
  }
}

// ── Analytics models ──────────────────────────────────────────────────────────

/// Single data point from the per-exercise analytics trend (PerformancePoint).
class PerformancePoint {
  const PerformancePoint({
    required this.sessionId,
    required this.date,
    required this.volume,
    required this.maxWeight,
    required this.totalReps,
    required this.estimated1rm,
  });

  final String sessionId;
  final DateTime date;
  final double volume;
  final double maxWeight;
  final int totalReps;
  final double estimated1rm;

  factory PerformancePoint.fromJson(Map<String, dynamic> json) {
    return PerformancePoint(
      sessionId: json['session_id'] as String,
      date: DateTime.parse(json['date'] as String).toLocal(),
      volume: _d(json['volume']),
      maxWeight: _d(json['max_weight']),
      totalReps: json['total_reps'] as int,
      estimated1rm: _d(json['estimated_1rm']),
    );
  }
}

/// Response from GET /workouts/sessions/exercises/{id}/analytics
class ExerciseAnalytics {
  const ExerciseAnalytics({
    required this.exerciseId,
    required this.exerciseName,
    required this.totalSessions,
    required this.lifetimeVolume,
    this.lastSessionVolume,
    required this.personalBestWeight,
    required this.estimated1rm,
    required this.recentTrend,
  });

  final int exerciseId;
  final String exerciseName;
  final int totalSessions;
  final double lifetimeVolume;
  final double? lastSessionVolume;
  final double personalBestWeight;
  final double estimated1rm;
  final List<PerformancePoint> recentTrend;

  factory ExerciseAnalytics.fromJson(Map<String, dynamic> json) {
    return ExerciseAnalytics(
      exerciseId: json['exercise_id'] as int,
      exerciseName: json['exercise_name'] as String,
      totalSessions: json['total_sessions'] as int,
      lifetimeVolume: _d(json['lifetime_volume']),
      lastSessionVolume: _nd(json['last_session_volume']),
      personalBestWeight: _d(json['personal_best_weight']),
      estimated1rm: _d(json['estimated_1rm']),
      recentTrend: (json['recent_trend'] as List<dynamic>? ?? [])
          .cast<Map<String, dynamic>>()
          .map(PerformancePoint.fromJson)
          .toList(),
    );
  }
}

/// Response from GET /workouts/sessions/analytics
class UserAnalyticsSummary {
  const UserAnalyticsSummary({
    required this.userId,
    required this.totalSessions,
    required this.completedSessions,
    required this.totalVolume,
    required this.personalBests,
  });

  final String userId;
  final int totalSessions;
  final int completedSessions;
  final double totalVolume;
  final List<ExerciseAnalytics> personalBests;

  factory UserAnalyticsSummary.fromJson(Map<String, dynamic> json) {
    return UserAnalyticsSummary(
      userId: json['user_id'] as String,
      totalSessions: json['total_sessions'] as int,
      completedSessions: json['completed_sessions'] as int,
      totalVolume: _d(json['total_volume']),
      personalBests: (json['personal_bests'] as List<dynamic>? ?? [])
          .cast<Map<String, dynamic>>()
          .map(ExerciseAnalytics.fromJson)
          .toList(),
    );
  }
}

// ── Active plan models ──────────────────────────────────────────────────────

class ActivePlan {
  const ActivePlan({
    required this.id,
    required this.userId,
    required this.planType,
    required this.startDate,
    required this.createdAt,
    required this.updatedAt,
  });

  final String id;
  final String userId;
  final String planType;
  final DateTime startDate;
  final DateTime createdAt;
  final DateTime updatedAt;

  factory ActivePlan.fromJson(Map<String, dynamic> json) {
    return ActivePlan(
      id: json['id'] as String,
      userId: json['user_id'] as String,
      planType: json['plan_type'] as String,
      startDate: DateTime.parse(json['start_date'] as String).toLocal(),
      createdAt: DateTime.parse(json['created_at'] as String).toLocal(),
      updatedAt: DateTime.parse(json['updated_at'] as String).toLocal(),
    );
  }
}

class PlanExercise {
  const PlanExercise({
    required this.id,
    required this.exerciseName,
    this.primaryMuscle,
    this.equipment,
  });

  final int id;
  final String exerciseName;
  final String? primaryMuscle;
  final String? equipment;

  factory PlanExercise.fromJson(Map<String, dynamic> json) {
    return PlanExercise(
      id: json['id'] as int,
      exerciseName: json['exercise_name'] as String,
      primaryMuscle: json['primary_muscle'] as String?,
      equipment: json['equipment'] as String?,
    );
  }
}

class TodayWorkout {
  const TodayWorkout({
    required this.planType,
    required this.dayNumber,
    required this.dayLabel,
    required this.totalDays,
    required this.completedSessions,
    required this.exercises,
  });

  final String planType;
  final int dayNumber;
  final String dayLabel;
  final int totalDays;
  final int completedSessions;
  final List<PlanExercise> exercises;

  factory TodayWorkout.fromJson(Map<String, dynamic> json) {
    return TodayWorkout(
      planType: json['plan_type'] as String,
      dayNumber: json['day_number'] as int,
      dayLabel: json['day_label'] as String,
      totalDays: json['total_days'] as int,
      completedSessions: json['completed_sessions'] as int,
      exercises: (json['exercises'] as List<dynamic>)
          .cast<Map<String, dynamic>>()
          .map(PlanExercise.fromJson)
          .toList(),
    );
  }
}

// ── Template models ─────────────────────────────────────────────────────────

class WorkoutTemplateSet {
  const WorkoutTemplateSet({
    required this.id,
    required this.setNumber,
    this.setType = 'NORMAL',
    this.reps,
    this.weightKg,
    this.rpe,
    this.rir,
  });

  final String id;
  final int setNumber;
  final String setType;
  final int? reps;
  final double? weightKg;
  final double? rpe;
  final int? rir;

  factory WorkoutTemplateSet.fromJson(Map<String, dynamic> json) {
    return WorkoutTemplateSet(
      id: json['id'] as String,
      setNumber: json['set_number'] as int,
      setType: json['set_type'] as String? ?? 'NORMAL',
      reps: json['reps'] as int?,
      weightKg: _nd(json['weight_kg']),
      rpe: _nd(json['rpe']),
      rir: json['rir'] as int?,
    );
  }
}

class WorkoutTemplateExercise {
  const WorkoutTemplateExercise({
    required this.id,
    required this.exerciseId,
    required this.exerciseName,
    this.primaryMuscle,
    this.equipment,
    required this.orderIndex,
    this.notes,
    required this.sets,
  });

  final String id;
  final int exerciseId;
  final String exerciseName;
  final String? primaryMuscle;
  final String? equipment;
  final int orderIndex;
  final String? notes;
  final List<WorkoutTemplateSet> sets;

  factory WorkoutTemplateExercise.fromJson(Map<String, dynamic> json) {
    return WorkoutTemplateExercise(
      id: json['id'] as String,
      exerciseId: json['exercise_id'] as int,
      exerciseName: json['exercise_name'] as String,
      primaryMuscle: json['primary_muscle'] as String?,
      equipment: json['equipment'] as String?,
      orderIndex: json['order_index'] as int,
      notes: json['notes'] as String?,
      sets: (json['sets'] as List<dynamic>? ?? [])
          .cast<Map<String, dynamic>>()
          .map(WorkoutTemplateSet.fromJson)
          .toList(),
    );
  }
}

class WorkoutTemplate {
  const WorkoutTemplate({
    required this.id,
    required this.userId,
    required this.title,
    this.notes,
    required this.exercises,
    required this.createdAt,
    required this.updatedAt,
  });

  final String id;
  final String userId;
  final String title;
  final String? notes;
  final List<WorkoutTemplateExercise> exercises;
  final DateTime createdAt;
  final DateTime updatedAt;

  factory WorkoutTemplate.fromJson(Map<String, dynamic> json) {
    return WorkoutTemplate(
      id: json['id'] as String,
      userId: json['user_id'] as String,
      title: json['title'] as String,
      notes: json['notes'] as String?,
      exercises: (json['exercises'] as List<dynamic>? ?? [])
          .cast<Map<String, dynamic>>()
          .map(WorkoutTemplateExercise.fromJson)
          .toList(),
      createdAt: DateTime.parse(json['created_at'] as String).toLocal(),
      updatedAt: DateTime.parse(json['updated_at'] as String).toLocal(),
    );
  }
}

class TemplatePage {
  const TemplatePage({
    required this.items,
    required this.total,
    required this.page,
    required this.pageSize,
    required this.totalPages,
  });

  final List<WorkoutTemplate> items;
  final int total;
  final int page;
  final int pageSize;
  final int totalPages;

  factory TemplatePage.fromJson(Map<String, dynamic> json) {
    return TemplatePage(
      items: (json['items'] as List<dynamic>? ?? [])
          .cast<Map<String, dynamic>>()
          .map(WorkoutTemplate.fromJson)
          .toList(),
      total: json['total'] as int? ?? 0,
      page: json['page'] as int? ?? 1,
      pageSize: json['page_size'] as int? ?? 20,
      totalPages: json['total_pages'] as int? ?? 0,
    );
  }
}

/// Response from GET /workouts/sessions/stats/weekly
class WeeklyWorkoutStats {
  const WeeklyWorkoutStats({
    required this.weekStart,
    required this.sessionCount,
    required this.totalVolume,
    this.totalDurationSec,
    this.avgDurationSec,
  });

  final String weekStart;
  final int sessionCount;
  final double totalVolume;
  final int? totalDurationSec;
  final int? avgDurationSec;

  factory WeeklyWorkoutStats.fromJson(Map<String, dynamic> json) {
    return WeeklyWorkoutStats(
      weekStart: json['week_start'] as String,
      sessionCount: json['session_count'] as int,
      totalVolume: _d(json['total_volume']),
      totalDurationSec: json['total_duration_sec'] as int?,
      avgDurationSec: json['avg_duration_sec'] as int?,
    );
  }
}
