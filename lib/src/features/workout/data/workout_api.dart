import '../../../core/network/api_client.dart';
import '../../../core/network/api_exception.dart';
import 'local_plan_service.dart';
import '../models/workout_models.dart';

class WorkoutApi {
  WorkoutApi(this._client);

  final ApiClient _client;
  bool? _hasActivePlan;
  bool _usesLocalActivePlan = false;

  // ── Session CRUD ────────────────────────────────────────────────────────────

  Future<WorkoutSession> createSession(CreateSessionRequest request) async {
    final response = await _client.post(
      '/workouts/sessions',
      body: request.toJson(),
    );
    return WorkoutSession.fromJson(Map<String, dynamic>.from(response));
  }

  Future<WorkoutSession> getSession(String sessionId) async {
    final response = await _client.get('/workouts/sessions/$sessionId');
    return WorkoutSession.fromJson(Map<String, dynamic>.from(response));
  }

  Future<WorkoutSession> updateSession(
    String sessionId,
    UpdateSessionRequest request,
  ) async {
    final response = await _client.patch(
      '/workouts/sessions/$sessionId',
      body: request.toJson(),
    );
    return WorkoutSession.fromJson(Map<String, dynamic>.from(response));
  }

  Future<WorkoutSession> finishSession(String sessionId) async {
    final response = await _client.post(
      '/workouts/sessions/$sessionId/finish',
      body: {},
    );
    return WorkoutSession.fromJson(Map<String, dynamic>.from(response));
  }

  Future<void> deleteSession(String sessionId) async {
    await _client.delete('/workouts/sessions/$sessionId');
  }

  // ── History ─────────────────────────────────────────────────────────────────

  Future<SessionHistoryPage> getHistory({
    String? startDate,
    String? endDate,
    int? exerciseId,
    String? muscle,
    String? equipment,
    bool completedOnly = false,
    int page = 1,
    int pageSize = 20,
  }) async {
    final params = <String, dynamic>{'page': page, 'page_size': pageSize};
    if (startDate != null) params['start_date'] = startDate;
    if (endDate != null) params['end_date'] = endDate;
    if (exerciseId != null) params['exercise_id'] = exerciseId;
    if (muscle != null) params['muscle'] = muscle;
    if (equipment != null) params['equipment'] = equipment;
    if (completedOnly) params['completed_only'] = true;

    final response = await _client.get(
      '/workouts/sessions/history',
      queryParameters: params,
    );
    return SessionHistoryPage.fromJson(Map<String, dynamic>.from(response));
  }

  // ── Exercise catalog ────────────────────────────────────────────────────────

  Future<ExercisePage> getExercises({
    String? q,
    String? muscle,
    String? equipment,
    String? difficulty,
    int page = 1,
    int pageSize = 30,
  }) async {
    final params = <String, dynamic>{'page': page, 'page_size': pageSize};
    if (q != null && q.isNotEmpty) params['q'] = q;
    if (muscle != null) params['muscle'] = muscle;
    if (equipment != null) params['equipment'] = equipment;
    if (difficulty != null) params['difficulty'] = difficulty;
    final response = await _client.get('/exercises', queryParameters: params);
    return ExercisePage.fromJson(Map<String, dynamic>.from(response));
  }

  Future<MuscleGroups> getMuscleGroups() async {
    final response = await _client.get('/exercises/muscles');
    return MuscleGroups.fromJson(Map<String, dynamic>.from(response));
  }

  /// Dedicated full-text search endpoint — use when a non-empty query is present.
  Future<ExercisePage> searchExercises({
    required String q,
    int page = 1,
    int pageSize = 50,
  }) async {
    final params = <String, dynamic>{
      'q': q,
      'page': page,
      'page_size': pageSize,
    };
    final response = await _client.get(
      '/exercises/search',
      queryParameters: params,
    );
    return ExercisePage.fromJson(Map<String, dynamic>.from(response));
  }

  // ── Analytics ───────────────────────────────────────────────────────────────

  Future<ExerciseAnalytics> getExerciseAnalytics(
    int exerciseId, {
    int trendLimit = 10,
  }) async {
    final response = await _client.get(
      '/workouts/sessions/exercises/$exerciseId/analytics',
      queryParameters: <String, dynamic>{'trend_limit': trendLimit},
    );
    return ExerciseAnalytics.fromJson(Map<String, dynamic>.from(response));
  }

  Future<UserAnalyticsSummary> getUserAnalytics() async {
    final response = await _client.get('/workouts/sessions/analytics');
    return UserAnalyticsSummary.fromJson(Map<String, dynamic>.from(response));
  }

  Future<List<WeeklyWorkoutStats>> getWeeklyStats({
    String? startDate,
    String? endDate,
  }) async {
    final params = <String, dynamic>{};
    if (startDate != null) params['start_date'] = startDate;
    if (endDate != null) params['end_date'] = endDate;
    final response = await _client.get(
      '/workouts/sessions/stats/weekly',
      queryParameters: params.isNotEmpty ? params : null,
    );
    return (response as List<dynamic>)
        .cast<Map<String, dynamic>>()
        .map(WeeklyWorkoutStats.fromJson)
        .toList();
  }

  // ── Active Plan ───────────────────────────────────────────────────────────

  Future<ActivePlan> setActivePlan(String planType) async {
    await LocalPlanService.setPlanType(planType);
    try {
      final response = await _client.post(
        '/plans/active',
        body: {'plan_type': planType},
      );
      _hasActivePlan = true;
      _usesLocalActivePlan = false;
      return ActivePlan.fromJson(Map<String, dynamic>.from(response));
    } catch (_) {
      final localPlan = await LocalPlanService.getActivePlan();
      if (localPlan != null) {
        _hasActivePlan = true;
        _usesLocalActivePlan = true;
        return localPlan;
      }
      rethrow;
    }
  }

  Future<ActivePlan?> getActivePlan() async {
    try {
      final response = await _client.get('/plans/active');
      _hasActivePlan = true;
      _usesLocalActivePlan = false;
      return ActivePlan.fromJson(Map<String, dynamic>.from(response));
    } on ApiException catch (error) {
      if (error.statusCode == 404) {
        final localPlan = await LocalPlanService.getActivePlan();
        if (localPlan != null) {
          _hasActivePlan = true;
          _usesLocalActivePlan = true;
          return localPlan;
        }
        _hasActivePlan = false;
        _usesLocalActivePlan = false;
        return null;
      }
      rethrow;
    }
  }

  Future<TodayWorkout?> getTodayWorkout() async {
    final localWorkout = await LocalPlanService.getTodayWorkout();
    if (localWorkout != null) {
      _hasActivePlan = true;
      _usesLocalActivePlan = true;
      return localWorkout;
    }

    if (_hasActivePlan == false) {
      return null;
    }

    // Avoid noisy /plans/active/today 404s: only query "today" when an active
    // plan exists (or has not been checked yet).
    if (_hasActivePlan == null) {
      final activePlan = await getActivePlan();
      if (activePlan == null) {
        return null;
      }
    }

    if (_usesLocalActivePlan) {
      return LocalPlanService.getTodayWorkout();
    }

    try {
      final response = await _client.get('/plans/active/today');
      _hasActivePlan = true;
      return TodayWorkout.fromJson(Map<String, dynamic>.from(response));
    } on ApiException catch (error) {
      if (error.statusCode == 404) {
        final fallback = await LocalPlanService.getTodayWorkout();
        if (fallback != null) {
          _hasActivePlan = true;
          _usesLocalActivePlan = true;
          return fallback;
        }
        _hasActivePlan = false;
        _usesLocalActivePlan = false;
        return null;
      }
      rethrow;
    }
  }

  Future<void> deleteActivePlan() async {
    await _client.delete('/plans/active');
    _hasActivePlan = false;
    _usesLocalActivePlan = false;
    await LocalPlanService.clear();
  }

  // ── Templates ─────────────────────────────────────────────────────────────

  Future<WorkoutTemplate> createTemplate({
    required String title,
    String? notes,
    required List<Map<String, dynamic>> exercises,
  }) async {
    final response = await _client.post(
      '/templates',
      body: {'title': title, 'notes': notes, 'exercises': exercises},
    );
    return WorkoutTemplate.fromJson(Map<String, dynamic>.from(response));
  }

  Future<TemplatePage> getTemplates({int page = 1, int pageSize = 20}) async {
    final response = await _client.get(
      '/templates',
      queryParameters: {'page': page, 'page_size': pageSize},
    );
    return TemplatePage.fromJson(Map<String, dynamic>.from(response));
  }

  Future<WorkoutTemplate> getTemplate(String templateId) async {
    final response = await _client.get('/templates/$templateId');
    return WorkoutTemplate.fromJson(Map<String, dynamic>.from(response));
  }

  Future<void> deleteTemplate(String templateId) async {
    await _client.delete('/templates/$templateId');
  }

  // ── Plan catalog ──────────────────────────────────────────────────────────

  Future<List<String>> getAvailablePlans() async {
    final response = await _client.get('/plans');
    return (response as List<dynamic>).cast<String>();
  }
}
