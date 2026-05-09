class ChallengeTemplateSummary {
  const ChallengeTemplateSummary({
    required this.id,
    required this.title,
    required this.slug,
    required this.category,
    required this.difficulty,
    required this.pointsReward,
    this.description,
    this.estimatedDurationSec,
    this.isActive = true,
    this.isFeatured = false,
    this.gymId,
  });

  final String id;
  final String title;
  final String slug;
  final String? description;
  final String category;
  final String difficulty;
  final int pointsReward;
  final int? estimatedDurationSec;
  final bool isActive;
  final bool isFeatured;
  final String? gymId;

  factory ChallengeTemplateSummary.fromJson(Map<String, dynamic> json) {
    return ChallengeTemplateSummary(
      id: (json['id'] ?? '').toString(),
      title: (json['title'] ?? '').toString(),
      slug: (json['slug'] ?? '').toString(),
      description: json['description']?.toString(),
      category: (json['category'] ?? '').toString(),
      difficulty: (json['difficulty'] ?? '').toString(),
      pointsReward: _toInt(json['points_reward'] ?? json['pointsReward']) ?? 0,
      estimatedDurationSec: _toInt(
        json['estimated_duration_sec'] ?? json['estimatedDurationSec'],
      ),
      isActive: (json['is_active'] ?? json['isActive']) as bool? ?? true,
      isFeatured: (json['is_featured'] ?? json['isFeatured']) as bool? ?? false,
      gymId: json['gym_id']?.toString() ?? json['gymId']?.toString(),
    );
  }
}

class ChallengeCircuitExercise {
  const ChallengeCircuitExercise({
    required this.id,
    required this.orderIndex,
    required this.exerciseName,
    this.targetReps,
    this.targetDurationSec,
    this.targetDistanceM,
    this.pointsPerComplete = 0,
    this.minValidSec,
    this.isMandatory = true,
  });

  final String id;
  final int orderIndex;
  final String exerciseName;
  final int? targetReps;
  final int? targetDurationSec;
  final double? targetDistanceM;
  final int pointsPerComplete;
  final int? minValidSec;
  final bool isMandatory;

  factory ChallengeCircuitExercise.fromJson(Map<String, dynamic> json) {
    return ChallengeCircuitExercise(
      id: (json['id'] ?? '').toString(),
      orderIndex: _toInt(json['order_index'] ?? json['orderIndex']) ?? 0,
      exerciseName: (json['exercise_name'] ?? json['exerciseName'] ?? '')
          .toString(),
      targetReps: _toInt(json['target_reps'] ?? json['targetReps']),
      targetDurationSec: _toInt(
        json['target_duration_sec'] ?? json['targetDurationSec'],
      ),
      targetDistanceM: _toDouble(
        json['target_distance_m'] ?? json['targetDistanceM'],
      ),
      pointsPerComplete:
          _toInt(json['points_per_complete'] ?? json['pointsPerComplete']) ?? 0,
      minValidSec: _toInt(json['min_valid_sec'] ?? json['minValidSec']),
      isMandatory:
          (json['is_mandatory'] ?? json['isMandatory']) as bool? ?? true,
    );
  }
}

class ChallengeCircuit {
  const ChallengeCircuit({
    required this.id,
    required this.circuitNumber,
    required this.orderIndex,
    required this.exercises,
    this.title,
    this.restAfterSec,
  });

  final String id;
  final String? title;
  final int circuitNumber;
  final int orderIndex;
  final int? restAfterSec;
  final List<ChallengeCircuitExercise> exercises;

  factory ChallengeCircuit.fromJson(Map<String, dynamic> json) {
    final rawExercises = (json['exercises'] as List<dynamic>? ?? const []);
    return ChallengeCircuit(
      id: (json['id'] ?? '').toString(),
      title: json['title']?.toString(),
      circuitNumber:
          _toInt(json['circuit_number'] ?? json['circuitNumber']) ?? 0,
      orderIndex: _toInt(json['order_index'] ?? json['orderIndex']) ?? 0,
      restAfterSec: _toInt(json['rest_after_sec'] ?? json['restAfterSec']),
      exercises: rawExercises
          .whereType<Map>()
          .map(
            (e) =>
                ChallengeCircuitExercise.fromJson(Map<String, dynamic>.from(e)),
          )
          .toList(),
    );
  }
}

class ChallengeTemplateDetail extends ChallengeTemplateSummary {
  const ChallengeTemplateDetail({
    required super.id,
    required super.title,
    required super.slug,
    required super.category,
    required super.difficulty,
    required super.pointsReward,
    required this.circuits,
    super.description,
    super.estimatedDurationSec,
    super.isActive,
    super.isFeatured,
    super.gymId,
  });

  final List<ChallengeCircuit> circuits;

  factory ChallengeTemplateDetail.fromJson(Map<String, dynamic> json) {
    final rawCircuits = (json['circuits'] as List<dynamic>? ?? const []);
    return ChallengeTemplateDetail(
      id: (json['id'] ?? '').toString(),
      title: (json['title'] ?? '').toString(),
      slug: (json['slug'] ?? '').toString(),
      description: json['description']?.toString(),
      category: (json['category'] ?? '').toString(),
      difficulty: (json['difficulty'] ?? '').toString(),
      pointsReward: _toInt(json['points_reward'] ?? json['pointsReward']) ?? 0,
      estimatedDurationSec: _toInt(
        json['estimated_duration_sec'] ?? json['estimatedDurationSec'],
      ),
      isActive: (json['is_active'] ?? json['isActive']) as bool? ?? true,
      isFeatured: (json['is_featured'] ?? json['isFeatured']) as bool? ?? false,
      gymId: json['gym_id']?.toString() ?? json['gymId']?.toString(),
      circuits: rawCircuits
          .whereType<Map>()
          .map((c) => ChallengeCircuit.fromJson(Map<String, dynamic>.from(c)))
          .toList(),
    );
  }
}

class ChallengeAttempt {
  const ChallengeAttempt({
    required this.id,
    required this.challengeTemplateId,
    required this.status,
    required this.startedAt,
    required this.totalPausedSec,
    required this.totalPoints,
    required this.validationStatus,
    required this.circuitSplits,
    required this.exerciseResults,
    this.gymId,
    this.pausedAt,
    this.resumedAt,
    this.completedAt,
    this.totalTimeSec,
  });

  final String id;
  final String challengeTemplateId;
  final String status;
  final DateTime startedAt;
  final DateTime? pausedAt;
  final DateTime? resumedAt;
  final DateTime? completedAt;
  final int totalPausedSec;
  final int? totalTimeSec;
  final int totalPoints;
  final String validationStatus;
  final String? gymId;
  final List<ChallengeAttemptCircuitSplit> circuitSplits;
  final List<ChallengeAttemptExerciseResult> exerciseResults;

  bool get isInProgress => status == 'IN_PROGRESS';
  bool get isPaused => status == 'PAUSED';
  bool get isCompleted => status == 'COMPLETED';

  factory ChallengeAttempt.fromJson(Map<String, dynamic> json) {
    final rawSplits =
        (json['circuit_splits'] ?? json['circuitSplits']) as List<dynamic>? ??
        const [];
    final rawResults =
        (json['exercise_results'] ?? json['exerciseResults'])
            as List<dynamic>? ??
        const [];
    return ChallengeAttempt(
      id: (json['id'] ?? '').toString(),
      challengeTemplateId:
          (json['challenge_template_id'] ?? json['challengeTemplateId'] ?? '')
              .toString(),
      status: (json['status'] ?? '').toString(),
      startedAt:
          _toDateTime(json['started_at'] ?? json['startedAt']) ??
          DateTime.now().toUtc(),
      pausedAt: _toDateTime(json['paused_at'] ?? json['pausedAt']),
      resumedAt: _toDateTime(json['resumed_at'] ?? json['resumedAt']),
      completedAt: _toDateTime(json['completed_at'] ?? json['completedAt']),
      totalPausedSec:
          _toInt(json['total_paused_sec'] ?? json['totalPausedSec']) ?? 0,
      totalTimeSec: _toInt(json['total_time_sec'] ?? json['totalTimeSec']),
      totalPoints: _toInt(json['total_points'] ?? json['totalPoints']) ?? 0,
      validationStatus:
          (json['validation_status'] ?? json['validationStatus'] ?? '')
              .toString(),
      gymId: json['gym_id']?.toString() ?? json['gymId']?.toString(),
      circuitSplits: rawSplits
          .whereType<Map>()
          .map(
            (e) => ChallengeAttemptCircuitSplit.fromJson(
              Map<String, dynamic>.from(e),
            ),
          )
          .toList(),
      exerciseResults: rawResults
          .whereType<Map>()
          .map(
            (e) => ChallengeAttemptExerciseResult.fromJson(
              Map<String, dynamic>.from(e),
            ),
          )
          .toList(),
    );
  }
}

class ChallengeAttemptCircuitSplit {
  const ChallengeAttemptCircuitSplit({
    required this.circuitNumber,
    this.splitTimeSec,
  });

  final int circuitNumber;
  final int? splitTimeSec;

  factory ChallengeAttemptCircuitSplit.fromJson(Map<String, dynamic> json) {
    return ChallengeAttemptCircuitSplit(
      circuitNumber:
          _toInt(json['circuit_number'] ?? json['circuitNumber']) ?? 0,
      splitTimeSec: _toInt(json['split_time_sec'] ?? json['splitTimeSec']),
    );
  }
}

class ChallengeAttemptExerciseResult {
  const ChallengeAttemptExerciseResult({
    required this.circuitNumber,
    required this.orderIndex,
    this.validationStatus,
  });

  final int circuitNumber;
  final int orderIndex;
  final String? validationStatus;

  factory ChallengeAttemptExerciseResult.fromJson(Map<String, dynamic> json) {
    return ChallengeAttemptExerciseResult(
      circuitNumber:
          _toInt(json['circuit_number'] ?? json['circuitNumber']) ?? 0,
      orderIndex: _toInt(json['order_index'] ?? json['orderIndex']) ?? 0,
      validationStatus: (json['validation_status'] ?? json['validationStatus'])
          ?.toString(),
    );
  }
}

class ChallengeLeaderboardEntry {
  const ChallengeLeaderboardEntry({
    required this.rank,
    required this.userId,
    required this.attemptId,
    required this.totalTimeSec,
    required this.totalPoints,
    required this.completedAt,
    this.gymId,
    this.isCurrentUser = false,
    this.isLatestAttempt = false,
    this.isPersonalTop3 = false,
  });

  final int rank;
  final String userId;
  final String attemptId;
  final String? gymId;
  final int totalTimeSec;
  final int totalPoints;
  final DateTime completedAt;
  final bool isCurrentUser;
  final bool isLatestAttempt;
  final bool isPersonalTop3;

  factory ChallengeLeaderboardEntry.fromJson(Map<String, dynamic> json) {
    return ChallengeLeaderboardEntry(
      rank: _toInt(json['rank']) ?? 0,
      userId: (json['user_id'] ?? json['userId'] ?? '').toString(),
      attemptId: (json['attempt_id'] ?? json['attemptId'] ?? '').toString(),
      gymId: json['gym_id']?.toString() ?? json['gymId']?.toString(),
      totalTimeSec: _toInt(json['total_time_sec'] ?? json['totalTimeSec']) ?? 0,
      totalPoints: _toInt(json['total_points'] ?? json['totalPoints']) ?? 0,
      completedAt:
          _toDateTime(json['completed_at'] ?? json['completedAt']) ??
          DateTime.now().toUtc(),
      isCurrentUser:
          (json['is_current_user'] ?? json['isCurrentUser']) as bool? ?? false,
      isLatestAttempt:
          (json['is_latest_attempt'] ?? json['isLatestAttempt']) as bool? ??
          false,
      isPersonalTop3:
          (json['is_personal_top3'] ?? json['isPersonalTop3']) as bool? ??
          false,
    );
  }
}

class ChallengePersonalLeaderboard {
  const ChallengePersonalLeaderboard({
    required this.challengeTemplateId,
    required this.entries,
    required this.totalAttempts,
    this.personalBest,
    this.latestAttempt,
  });

  final String challengeTemplateId;
  final List<ChallengeLeaderboardEntry> entries;
  final int totalAttempts;
  final ChallengeLeaderboardEntry? personalBest;
  final ChallengeLeaderboardEntry? latestAttempt;

  factory ChallengePersonalLeaderboard.fromJson(Map<String, dynamic> json) {
    final rawEntries = (json['entries'] as List<dynamic>? ?? const []);
    return ChallengePersonalLeaderboard(
      challengeTemplateId:
          (json['challenge_template_id'] ?? json['challengeTemplateId'] ?? '')
              .toString(),
      entries: rawEntries
          .whereType<Map>()
          .map(
            (e) => ChallengeLeaderboardEntry.fromJson(
              Map<String, dynamic>.from(e),
            ),
          )
          .toList(),
      totalAttempts:
          _toInt(json['total_attempts'] ?? json['totalAttempts']) ?? 0,
      personalBest:
          _asMap(json['personal_best'] ?? json['personalBest']) == null
          ? null
          : ChallengeLeaderboardEntry.fromJson(
              _asMap(json['personal_best'] ?? json['personalBest'])!,
            ),
      latestAttempt:
          _asMap(json['latest_attempt'] ?? json['latestAttempt']) == null
          ? null
          : ChallengeLeaderboardEntry.fromJson(
              _asMap(json['latest_attempt'] ?? json['latestAttempt'])!,
            ),
    );
  }
}

class ChallengeRankedLeaderboard {
  const ChallengeRankedLeaderboard({
    required this.challengeTemplateId,
    required this.entries,
    this.currentUserRank,
    this.currentUserEntry,
  });

  final String challengeTemplateId;
  final List<ChallengeLeaderboardEntry> entries;
  final int? currentUserRank;
  final ChallengeLeaderboardEntry? currentUserEntry;

  factory ChallengeRankedLeaderboard.fromJson(Map<String, dynamic> json) {
    final rawEntries = (json['entries'] as List<dynamic>? ?? const []);
    return ChallengeRankedLeaderboard(
      challengeTemplateId:
          (json['challenge_template_id'] ?? json['challengeTemplateId'] ?? '')
              .toString(),
      entries: rawEntries
          .whereType<Map>()
          .map(
            (e) => ChallengeLeaderboardEntry.fromJson(
              Map<String, dynamic>.from(e),
            ),
          )
          .toList(),
      currentUserRank: _toInt(
        json['current_user_rank'] ?? json['currentUserRank'],
      ),
      currentUserEntry:
          _asMap(json['current_user_entry'] ?? json['currentUserEntry']) == null
          ? null
          : ChallengeLeaderboardEntry.fromJson(
              _asMap(json['current_user_entry'] ?? json['currentUserEntry'])!,
            ),
    );
  }
}

int? _toInt(dynamic value) {
  if (value == null) return null;
  if (value is int) return value;
  if (value is num) return value.toInt();
  if (value is String) {
    return int.tryParse(value) ?? double.tryParse(value)?.toInt();
  }
  return null;
}

double? _toDouble(dynamic value) {
  if (value == null) return null;
  if (value is double) return value;
  if (value is num) return value.toDouble();
  if (value is String) return double.tryParse(value);
  return null;
}

DateTime? _toDateTime(dynamic value) {
  if (value == null) return null;
  final raw = value.toString();
  final parsed = DateTime.tryParse(raw);
  return parsed?.toUtc();
}

Map<String, dynamic>? _asMap(dynamic value) {
  if (value is Map<String, dynamic>) return value;
  if (value is Map) return Map<String, dynamic>.from(value);
  return null;
}
