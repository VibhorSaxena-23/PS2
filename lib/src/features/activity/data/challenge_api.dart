import '../../../core/network/api_client.dart';
import '../models/challenge_models.dart';

class ChallengeApi {
  ChallengeApi(this._client);

  final ApiClient _client;

  void dispose() => _client.dispose();

  Future<List<ChallengeTemplateSummary>> listChallenges({
    String? category,
    String? difficulty,
    String? gymId,
    bool? featured,
    bool activeOnly = true,
  }) async {
    final query = <String, dynamic>{'activeOnly': activeOnly};
    if (category != null && category.isNotEmpty) query['category'] = category;
    if (difficulty != null && difficulty.isNotEmpty) {
      query['difficulty'] = difficulty;
    }
    if (gymId != null && gymId.isNotEmpty) query['gymId'] = gymId;
    if (featured != null) query['featured'] = featured;
    final response = await _client.get('/challenges', queryParameters: query);
    final items = response is Map<String, dynamic>
        ? response['items'] as List<dynamic>? ?? const <dynamic>[]
        : response as List<dynamic>;
    return items
        .whereType<Map>()
        .map(
          (item) => ChallengeTemplateSummary.fromJson(
            Map<String, dynamic>.from(item),
          ),
        )
        .toList();
  }

  Future<ChallengeTemplateDetail> getChallenge(String challengeId) async {
    final response = await _client.get('/challenges/$challengeId');
    return ChallengeTemplateDetail.fromJson(
      Map<String, dynamic>.from(response),
    );
  }

  Future<ChallengeAttempt> startAttempt(
    String challengeId, {
    String? gymId,
    String source = 'mobile_activity',
    DateTime? startedAt,
  }) async {
    final body = <String, dynamic>{'source': source};
    if (gymId != null && gymId.isNotEmpty) {
      body['gym_id'] = gymId;
    }
    if (startedAt != null) {
      body['started_at'] = startedAt.toUtc().toIso8601String();
    }
    final response = await _client.post(
      '/challenges/$challengeId/start',
      body: body,
    );
    return ChallengeAttempt.fromJson(Map<String, dynamic>.from(response));
  }

  Future<ChallengeAttempt?> getActiveAttempt({String? challengeId}) async {
    final query = <String, dynamic>{};
    if (challengeId != null && challengeId.isNotEmpty) {
      query['challengeId'] = challengeId;
    }
    final response = await _client.get(
      '/challenges/attempts/active',
      queryParameters: query.isEmpty ? null : query,
    );
    if (response == null) return null;
    if (response is! Map) return null;
    return ChallengeAttempt.fromJson(Map<String, dynamic>.from(response));
  }

  Future<ChallengeAttempt> getAttempt(String attemptId) async {
    final response = await _client.get('/challenges/attempts/$attemptId');
    return ChallengeAttempt.fromJson(Map<String, dynamic>.from(response));
  }

  Future<ChallengeAttempt> pauseAttempt(String attemptId) async {
    final response = await _client.post(
      '/challenges/attempts/$attemptId/pause',
      body: {},
    );
    return ChallengeAttempt.fromJson(Map<String, dynamic>.from(response));
  }

  Future<ChallengeAttempt> resumeAttempt(String attemptId) async {
    final response = await _client.post(
      '/challenges/attempts/$attemptId/resume',
      body: {},
    );
    return ChallengeAttempt.fromJson(Map<String, dynamic>.from(response));
  }

  Future<ChallengeAttempt> abandonAttempt(String attemptId) async {
    final response = await _client.post(
      '/challenges/attempts/$attemptId/abandon',
      body: {},
    );
    return ChallengeAttempt.fromJson(Map<String, dynamic>.from(response));
  }

  Future<ChallengeAttempt> completeExercise({
    required String attemptId,
    required int circuitNumber,
    required int orderIndex,
    int? completedReps,
    int? completedDurationSec,
    double? completedDistanceM,
  }) async {
    final body = <String, dynamic>{
      'circuit_number': circuitNumber,
      'order_index': orderIndex,
      'completed_reps': ?completedReps,
      'completed_duration_sec': ?completedDurationSec,
      'completed_distance_m': ?completedDistanceM,
      'completed_at': DateTime.now().toUtc().toIso8601String(),
    };
    final response = await _client.post(
      '/challenges/attempts/$attemptId/complete-exercise',
      body: body,
    );
    return ChallengeAttempt.fromJson(Map<String, dynamic>.from(response));
  }

  Future<ChallengeAttempt> completeCircuit({
    required String attemptId,
    required int circuitNumber,
  }) async {
    final response = await _client.post(
      '/challenges/attempts/$attemptId/complete-circuit',
      body: {
        'circuit_number': circuitNumber,
        'completed_at': DateTime.now().toUtc().toIso8601String(),
      },
    );
    return ChallengeAttempt.fromJson(Map<String, dynamic>.from(response));
  }

  Future<ChallengeAttempt> finishAttempt(
    String attemptId, {
    bool submitForReview = false,
  }) async {
    final response = await _client.post(
      '/challenges/attempts/$attemptId/finish',
      body: {
        'submitForReview': submitForReview,
        'completed_at': DateTime.now().toUtc().toIso8601String(),
      },
    );
    return ChallengeAttempt.fromJson(Map<String, dynamic>.from(response));
  }

  Future<ChallengePersonalLeaderboard> personalLeaderboard(
    String challengeId,
  ) async {
    final response = await _client.get(
      '/challenges/$challengeId/leaderboard/me',
    );
    return ChallengePersonalLeaderboard.fromJson(
      Map<String, dynamic>.from(response),
    );
  }

  Future<ChallengeRankedLeaderboard> gymLeaderboard(
    String challengeId, {
    String? gymId,
    int limit = 20,
  }) async {
    final query = <String, dynamic>{'limit': limit};
    if (gymId != null && gymId.isNotEmpty) query['gymId'] = gymId;
    final response = await _client.get(
      '/challenges/$challengeId/leaderboard/gym',
      queryParameters: query,
    );
    return ChallengeRankedLeaderboard.fromJson(
      Map<String, dynamic>.from(response),
    );
  }

  Future<ChallengeRankedLeaderboard> globalLeaderboard(
    String challengeId, {
    int limit = 20,
  }) async {
    final response = await _client.get(
      '/challenges/$challengeId/leaderboard/global',
      queryParameters: {'limit': limit},
    );
    return ChallengeRankedLeaderboard.fromJson(
      Map<String, dynamic>.from(response),
    );
  }
}
