class HydrationLog {
  const HydrationLog({
    required this.id,
    required this.userId,
    required this.amountMl,
    required this.recordedAt,
    this.notes,
  });

  final String id;
  final String userId;
  final double amountMl;
  final DateTime recordedAt;
  final String? notes;

  factory HydrationLog.fromJson(Map<String, dynamic> json) {
    return HydrationLog(
      id: json['id'].toString(),
      userId: json['user_id'] as String,
      amountMl: (json['amount_ml'] as num).toDouble(),
      recordedAt: DateTime.parse(json['recorded_at'] as String),
      notes: json['notes'] as String?,
    );
  }
}

class HydrationDailySummary {
  const HydrationDailySummary({
    required this.date,
    required this.totalMl,
    required this.dailyGoalMl,
    required this.remainingMl,
    required this.percentComplete,
    required this.entries,
  });

  final String date;
  final double totalMl;
  final double dailyGoalMl;
  final double remainingMl;
  final double percentComplete;
  final List<HydrationLog> entries;

  factory HydrationDailySummary.fromJson(Map<String, dynamic> json) {
    final rawEntries = json['entries'] as List<dynamic>? ?? [];
    return HydrationDailySummary(
      date: json['date'] as String,
      totalMl: (json['total_ml'] as num).toDouble(),
      dailyGoalMl: (json['daily_goal_ml'] as num).toDouble(),
      remainingMl: (json['remaining_ml'] as num).toDouble(),
      percentComplete: (json['percent_complete'] as num).toDouble(),
      entries: rawEntries
          .map((e) => HydrationLog.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }
}

class HydrationWeeklyEntry {
  const HydrationWeeklyEntry({
    required this.date,
    required this.totalMl,
    required this.goalMl,
    required this.reached,
  });

  final String date;
  final double totalMl;
  final double goalMl;
  final bool reached;

  factory HydrationWeeklyEntry.fromJson(Map<String, dynamic> json) {
    return HydrationWeeklyEntry(
      date: json['date'] as String,
      totalMl: (json['total_ml'] as num).toDouble(),
      goalMl: (json['goal_ml'] as num).toDouble(),
      reached: json['reached'] as bool,
    );
  }
}

class HydrationReminder {
  const HydrationReminder({
    required this.date,
    required this.totalMl,
    required this.dailyGoalMl,
    required this.remainingMl,
    required this.percentComplete,
    required this.reminderHour,
    required this.shouldNotify,
    required this.message,
  });

  final String date;
  final double totalMl;
  final double dailyGoalMl;
  final double remainingMl;
  final double percentComplete;
  final int reminderHour;
  final bool shouldNotify;
  final String? message;

  factory HydrationReminder.fromJson(Map<String, dynamic> json) {
    return HydrationReminder(
      date: json['date'] as String,
      totalMl: (json['total_ml'] as num).toDouble(),
      dailyGoalMl: (json['daily_goal_ml'] as num).toDouble(),
      remainingMl: (json['remaining_ml'] as num).toDouble(),
      percentComplete: (json['percent_complete'] as num).toDouble(),
      reminderHour: json['reminder_hour'] as int,
      shouldNotify: json['should_notify'] as bool,
      message: json['message'] as String?,
    );
  }
}
