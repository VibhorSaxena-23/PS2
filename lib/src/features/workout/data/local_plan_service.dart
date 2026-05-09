import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../../auth/data/auth_service.dart';
import '../models/workout_models.dart';

/// Manages the user's active workout split locally (SharedPreferences).
/// The mobile server has no /plans/active endpoint, so plan selection
/// is stored on-device and the "today's workout" is computed here.
class LocalPlanService {
  LocalPlanService._();

  static const _keyPlanType = 'local_plan_type';
  static const _keyStartDate = 'local_plan_start_date';

  static Future<String> _scopeKey(String baseKey) async {
    final userId = await AuthService.instance.getUserId();
    final scope = (userId != null && userId.isNotEmpty) ? userId : 'anonymous';
    return '${baseKey}_$scope';
  }

  static String _anonymousKey(String baseKey) => '${baseKey}_anonymous';

  static Future<List<String>> _candidateKeys(String baseKey) async {
    final scoped = await _scopeKey(baseKey);
    final keys = <String>[scoped, _anonymousKey(baseKey), baseKey];
    return keys.toSet().toList();
  }

  static Future<String?> getPlanType() async {
    final prefs = await SharedPreferences.getInstance();
    for (final key in await _candidateKeys(_keyPlanType)) {
      final value = prefs.getString(key);
      if (value != null && value.isNotEmpty) return value;
    }
    return null;
  }

  static Future<DateTime?> _getStartDate() async {
    final prefs = await SharedPreferences.getInstance();
    for (final key in await _candidateKeys(_keyStartDate)) {
      final startStr = prefs.getString(key);
      if (startStr == null || startStr.isEmpty) continue;
      try {
        return DateTime.parse(startStr);
      } catch (_) {
        continue;
      }
    }
    return null;
  }

  static Future<void> setPlanType(String planType) async {
    final prefs = await SharedPreferences.getInstance();
    final startDate = _isoDate(DateTime.now());
    for (final key in await _candidateKeys(_keyPlanType)) {
      await prefs.setString(key, planType);
    }
    for (final key in await _candidateKeys(_keyStartDate)) {
      await prefs.setString(key, startDate);
    }
  }

  static Future<void> clear() async {
    final prefs = await SharedPreferences.getInstance();
    for (final key in await _candidateKeys(_keyPlanType)) {
      await prefs.remove(key);
    }
    for (final key in await _candidateKeys(_keyStartDate)) {
      await prefs.remove(key);
    }
  }

  static Future<TodayWorkout?> getTodayWorkout({
    int completedSessions = 0,
  }) async {
    final planType = await getPlanType();
    if (planType == null) return null;

    final start = await _getStartDate() ?? DateTime.now();
    final daysSince = DateTime.now().difference(start).inDays;

    return _build(planType, daysSince, completedSessions);
  }

  static Future<ActivePlan?> getActivePlan() async {
    final planType = await getPlanType();
    if (planType == null) return null;

    final start = await _getStartDate() ?? DateTime.now();
    final startDate = DateTime(start.year, start.month, start.day);
    return ActivePlan(
      id: 'local-$planType',
      userId: 'local',
      planType: planType,
      startDate: startDate,
      createdAt: startDate,
      updatedAt: startDate,
    );
  }

  static TodayWorkout? _build(String planType, int daysSince, int completed) {
    if (planType == 'ppl') return _ppl(daysSince, completed);
    if (planType == 'bro') return _bro(daysSince, completed);
    if (planType == 'full_body') return _fullBody(daysSince, completed);
    if (planType.startsWith('custom:')) {
      return _custom(planType, daysSince, completed);
    }
    return null;
  }

  static TodayWorkout? _custom(String planType, int daysSince, int completed) {
    final payload = planType.substring('custom:'.length).trim();
    if (payload.isEmpty) return null;

    try {
      final decoded = jsonDecode(payload);
      if (decoded is! List) return null;

      final days = decoded
          .whereType<Map>()
          .map(
            (day) => day.map((key, value) => MapEntry(key.toString(), value)),
          )
          .toList();
      if (days.isEmpty) return null;

      final dayIndex = daysSince % days.length;
      final current = days[dayIndex];

      final rawLabel = current['label'];
      final label = rawLabel is String && rawLabel.trim().isNotEmpty
          ? rawLabel.trim()
          : 'Day ${dayIndex + 1}';

      final rawMuscles = current['muscles'];
      final muscles = rawMuscles is List
          ? rawMuscles
                .whereType<String>()
                .map((muscle) => muscle.trim())
                .where((muscle) => muscle.isNotEmpty)
                .toList()
          : <String>[];

      final exercises = muscles.isEmpty
          ? [
              PlanExercise(
                id: -900000 - dayIndex,
                exerciseName: label,
                primaryMuscle: null,
              ),
            ]
          : muscles.asMap().entries.map((entry) {
              final muscle = entry.value;
              return PlanExercise(
                id: -900000 - (dayIndex * 100) - entry.key,
                exerciseName: muscle,
                primaryMuscle: muscle,
              );
            }).toList();

      return TodayWorkout(
        planType: planType,
        dayNumber: dayIndex + 1,
        dayLabel: label,
        totalDays: days.length,
        completedSessions: completed,
        exercises: exercises,
      );
    } catch (_) {
      return null;
    }
  }

  // ── PPL (Push / Pull / Legs — 6-day cycle) ──────────────────────────────

  static TodayWorkout _ppl(int daysSince, int completed) {
    final dayIndex = daysSince % 6;
    final days = <(String, List<PlanExercise>)>[
      (
        'Push',
        [
          const PlanExercise(
            id: -101,
            exerciseName: 'Bench Press',
            primaryMuscle: 'Chest',
          ),
          const PlanExercise(
            id: -102,
            exerciseName: 'Overhead Press',
            primaryMuscle: 'Shoulders',
          ),
          const PlanExercise(
            id: -103,
            exerciseName: 'Lateral Raise',
            primaryMuscle: 'Shoulders',
          ),
          const PlanExercise(
            id: -104,
            exerciseName: 'Tricep Pushdown',
            primaryMuscle: 'Triceps',
          ),
          const PlanExercise(
            id: -105,
            exerciseName: 'Cable Fly',
            primaryMuscle: 'Chest',
          ),
        ],
      ),
      (
        'Pull',
        [
          const PlanExercise(
            id: -201,
            exerciseName: 'Deadlift',
            primaryMuscle: 'Back',
          ),
          const PlanExercise(
            id: -202,
            exerciseName: 'Bent Over Row',
            primaryMuscle: 'Back',
          ),
          const PlanExercise(
            id: -203,
            exerciseName: 'Pull-up',
            primaryMuscle: 'Back',
          ),
          const PlanExercise(
            id: -204,
            exerciseName: 'Lat Pulldown',
            primaryMuscle: 'Back',
          ),
          const PlanExercise(
            id: -205,
            exerciseName: 'Bicep Curl',
            primaryMuscle: 'Biceps',
          ),
        ],
      ),
      (
        'Legs',
        [
          const PlanExercise(
            id: -301,
            exerciseName: 'Squat',
            primaryMuscle: 'Quadriceps',
          ),
          const PlanExercise(
            id: -302,
            exerciseName: 'Leg Press',
            primaryMuscle: 'Quadriceps',
          ),
          const PlanExercise(
            id: -303,
            exerciseName: 'Romanian Deadlift',
            primaryMuscle: 'Hamstrings',
          ),
          const PlanExercise(
            id: -304,
            exerciseName: 'Leg Curl',
            primaryMuscle: 'Hamstrings',
          ),
          const PlanExercise(
            id: -305,
            exerciseName: 'Calf Raise',
            primaryMuscle: 'Calves',
          ),
        ],
      ),
      (
        'Push',
        [
          const PlanExercise(
            id: -108,
            exerciseName: 'Incline Bench Press',
            primaryMuscle: 'Chest',
          ),
          const PlanExercise(
            id: -109,
            exerciseName: 'Dumbbell Shoulder Press',
            primaryMuscle: 'Shoulders',
          ),
          const PlanExercise(
            id: -110,
            exerciseName: 'Tricep Dips',
            primaryMuscle: 'Triceps',
          ),
          const PlanExercise(
            id: -111,
            exerciseName: 'Chest Dips',
            primaryMuscle: 'Chest',
          ),
          const PlanExercise(
            id: -112,
            exerciseName: 'Front Raise',
            primaryMuscle: 'Shoulders',
          ),
        ],
      ),
      (
        'Pull',
        [
          const PlanExercise(
            id: -211,
            exerciseName: 'Barbell Row',
            primaryMuscle: 'Back',
          ),
          const PlanExercise(
            id: -212,
            exerciseName: 'Seated Cable Row',
            primaryMuscle: 'Back',
          ),
          const PlanExercise(
            id: -213,
            exerciseName: 'Face Pull',
            primaryMuscle: 'Shoulders',
          ),
          const PlanExercise(
            id: -214,
            exerciseName: 'Hammer Curl',
            primaryMuscle: 'Biceps',
          ),
          const PlanExercise(
            id: -215,
            exerciseName: 'Preacher Curl',
            primaryMuscle: 'Biceps',
          ),
        ],
      ),
      (
        'Legs',
        [
          const PlanExercise(
            id: -311,
            exerciseName: 'Front Squat',
            primaryMuscle: 'Quadriceps',
          ),
          const PlanExercise(
            id: -312,
            exerciseName: 'Hack Squat',
            primaryMuscle: 'Quadriceps',
          ),
          const PlanExercise(
            id: -313,
            exerciseName: 'Lunge',
            primaryMuscle: 'Quadriceps',
          ),
          const PlanExercise(
            id: -314,
            exerciseName: 'Leg Extension',
            primaryMuscle: 'Quadriceps',
          ),
          const PlanExercise(
            id: -315,
            exerciseName: 'Standing Calf Raise',
            primaryMuscle: 'Calves',
          ),
        ],
      ),
    ];
    final (label, exercises) = days[dayIndex];
    return TodayWorkout(
      planType: 'ppl',
      dayNumber: dayIndex + 1,
      dayLabel: label,
      totalDays: 6,
      completedSessions: completed,
      exercises: exercises,
    );
  }

  // ── Bro Split (5-day cycle) ──────────────────────────────────────────────

  static TodayWorkout _bro(int daysSince, int completed) {
    final dayIndex = daysSince % 5;
    final days = <(String, List<PlanExercise>)>[
      (
        'Chest',
        [
          const PlanExercise(
            id: -101,
            exerciseName: 'Bench Press',
            primaryMuscle: 'Chest',
          ),
          const PlanExercise(
            id: -108,
            exerciseName: 'Incline Bench Press',
            primaryMuscle: 'Chest',
          ),
          const PlanExercise(
            id: -105,
            exerciseName: 'Cable Fly',
            primaryMuscle: 'Chest',
          ),
          const PlanExercise(
            id: -111,
            exerciseName: 'Chest Dips',
            primaryMuscle: 'Chest',
          ),
        ],
      ),
      (
        'Back',
        [
          const PlanExercise(
            id: -201,
            exerciseName: 'Deadlift',
            primaryMuscle: 'Back',
          ),
          const PlanExercise(
            id: -202,
            exerciseName: 'Bent Over Row',
            primaryMuscle: 'Back',
          ),
          const PlanExercise(
            id: -204,
            exerciseName: 'Lat Pulldown',
            primaryMuscle: 'Back',
          ),
          const PlanExercise(
            id: -212,
            exerciseName: 'Seated Cable Row',
            primaryMuscle: 'Back',
          ),
        ],
      ),
      (
        'Shoulders',
        [
          const PlanExercise(
            id: -102,
            exerciseName: 'Overhead Press',
            primaryMuscle: 'Shoulders',
          ),
          const PlanExercise(
            id: -103,
            exerciseName: 'Lateral Raise',
            primaryMuscle: 'Shoulders',
          ),
          const PlanExercise(
            id: -213,
            exerciseName: 'Face Pull',
            primaryMuscle: 'Shoulders',
          ),
          const PlanExercise(
            id: -112,
            exerciseName: 'Front Raise',
            primaryMuscle: 'Shoulders',
          ),
        ],
      ),
      (
        'Arms',
        [
          const PlanExercise(
            id: -205,
            exerciseName: 'Bicep Curl',
            primaryMuscle: 'Biceps',
          ),
          const PlanExercise(
            id: -214,
            exerciseName: 'Hammer Curl',
            primaryMuscle: 'Biceps',
          ),
          const PlanExercise(
            id: -104,
            exerciseName: 'Tricep Pushdown',
            primaryMuscle: 'Triceps',
          ),
          const PlanExercise(
            id: -401,
            exerciseName: 'Skull Crusher',
            primaryMuscle: 'Triceps',
          ),
        ],
      ),
      (
        'Legs',
        [
          const PlanExercise(
            id: -301,
            exerciseName: 'Squat',
            primaryMuscle: 'Quadriceps',
          ),
          const PlanExercise(
            id: -302,
            exerciseName: 'Leg Press',
            primaryMuscle: 'Quadriceps',
          ),
          const PlanExercise(
            id: -303,
            exerciseName: 'Romanian Deadlift',
            primaryMuscle: 'Hamstrings',
          ),
          const PlanExercise(
            id: -304,
            exerciseName: 'Leg Curl',
            primaryMuscle: 'Hamstrings',
          ),
        ],
      ),
    ];
    final (label, exercises) = days[dayIndex];
    return TodayWorkout(
      planType: 'bro',
      dayNumber: dayIndex + 1,
      dayLabel: label,
      totalDays: 5,
      completedSessions: completed,
      exercises: exercises,
    );
  }

  // ── Full Body (4-day cycle: A / Rest / B / Rest) ─────────────────────────

  static TodayWorkout _fullBody(int daysSince, int completed) {
    final dayIndex = daysSince % 4;
    final days = <(String, List<PlanExercise>)>[
      (
        'Full Body A',
        [
          const PlanExercise(
            id: -301,
            exerciseName: 'Squat',
            primaryMuscle: 'Quadriceps',
          ),
          const PlanExercise(
            id: -101,
            exerciseName: 'Bench Press',
            primaryMuscle: 'Chest',
          ),
          const PlanExercise(
            id: -201,
            exerciseName: 'Deadlift',
            primaryMuscle: 'Back',
          ),
          const PlanExercise(
            id: -102,
            exerciseName: 'Overhead Press',
            primaryMuscle: 'Shoulders',
          ),
          const PlanExercise(
            id: -203,
            exerciseName: 'Pull-up',
            primaryMuscle: 'Back',
          ),
        ],
      ),
      ('Rest Day', <PlanExercise>[]),
      (
        'Full Body B',
        [
          const PlanExercise(
            id: -303,
            exerciseName: 'Romanian Deadlift',
            primaryMuscle: 'Hamstrings',
          ),
          const PlanExercise(
            id: -108,
            exerciseName: 'Incline Bench Press',
            primaryMuscle: 'Chest',
          ),
          const PlanExercise(
            id: -202,
            exerciseName: 'Bent Over Row',
            primaryMuscle: 'Back',
          ),
          const PlanExercise(
            id: -313,
            exerciseName: 'Lunge',
            primaryMuscle: 'Quadriceps',
          ),
          const PlanExercise(
            id: -103,
            exerciseName: 'Lateral Raise',
            primaryMuscle: 'Shoulders',
          ),
        ],
      ),
      ('Rest Day', <PlanExercise>[]),
    ];
    final (label, exercises) = days[dayIndex];
    return TodayWorkout(
      planType: 'full_body',
      dayNumber: dayIndex + 1,
      dayLabel: label,
      totalDays: 4,
      completedSessions: completed,
      exercises: exercises,
    );
  }

  static String _isoDate(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-'
      '${d.month.toString().padLeft(2, '0')}-'
      '${d.day.toString().padLeft(2, '0')}';
}
