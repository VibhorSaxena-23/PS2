import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/config/app_config.dart';
import '../../../core/network/api_client.dart';
import '../data/challenge_api.dart';
import '../models/challenge_models.dart';
import '../../gym/data/gym_api.dart';
import '../../gym/models/gym_models.dart';
import '../../hydration/data/hydration_api.dart';
import '../../steps/step_service.dart';
import '../../workout/data/local_plan_service.dart';
import '../../workout/data/workout_api.dart';
import '../../workout/models/workout_models.dart';
import '../../workout/presentation/workout_page.dart';

// ══════════════════════════════════════════════════════════════════════════════
//  ActivityPage
// ══════════════════════════════════════════════════════════════════════════════

class ActivityPage extends StatefulWidget {
  const ActivityPage({
    super.key,
    required this.gymApi,
    required this.workoutApi,
    required this.hydrationApi,
  });

  final GymApi gymApi;
  final WorkoutApi workoutApi;
  final HydrationApi hydrationApi;

  @override
  State<ActivityPage> createState() => _ActivityPageState();
}

class _ActivityPageState extends State<ActivityPage> {
  static const bool _enableChallengePreview = bool.fromEnvironment(
    'ENABLE_ACTIVITY_CHALLENGE_PREVIEW',
    defaultValue: false,
  );
  static const _challengeAttemptsKey = 'activity_challenge_attempts_v1';
  static const _challenges = [
    _Challenge(
      id: 'burpees_50',
      title: '50 Burpees',
      targetReps: 50,
      unit: 'burpees',
      accent: Color(0xFFEF4444),
      softAccent: Color(0xFFFFE4E6),
      icon: Icons.local_fire_department_rounded,
      description: 'A full-body conditioning test. Finish 50 clean reps.',
      expiryDays: 7,
    ),
    _Challenge(
      id: 'squats_100',
      title: '100 Air Squats',
      targetReps: 100,
      unit: 'squats',
      accent: Color(0xFF2563EB),
      softAccent: Color(0xFFDBEAFE),
      icon: Icons.keyboard_double_arrow_down_rounded,
      description: 'Leg endurance under control. Hit depth and keep rhythm.',
      expiryDays: 7,
    ),
  ];

  GymAttendancePage? _attendancePage;
  TodayWorkout? _todayWorkout;
  GymAttendance? _activeSession;
  late final ChallengeApi _challengeApi;
  Map<String, List<_ChallengeAttempt>> _challengeAttempts = {};
  List<ChallengeTemplateSummary> _liveChallenges = const [];
  final Map<String, ChallengeTemplateDetail> _liveChallengeDetails = {};
  ChallengeAttempt? _liveActiveAttempt;
  bool _challengesLoading = false;
  bool _challengeActionLoading = false;
  String? _challengeLoadError;
  bool _loading = true;

  Timer? _timer;
  Timer? _challengeTimer;
  Duration _elapsed = Duration.zero;
  Duration _challengeElapsed = Duration.zero;
  String? _activeChallengeId;

  @override
  void initState() {
    super.initState();
    _challengeApi = ChallengeApi(
      ApiClient(baseUrl: AppConfig.apiBaseUrl, userId: AppConfig.userId),
    );
    _load();
    if (_enableChallengePreview) {
      unawaited(_loadChallengeAttempts());
    }
    if (!_enableChallengePreview) {
      unawaited(_loadLiveChallenges());
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    _challengeTimer?.cancel();
    _challengeApi.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    GymAttendancePage? attendancePage;
    TodayWorkout? todayWorkout;

    try {
      final items = await widget.gymApi.getAttendance(limit: 20, offset: 0);
      attendancePage = GymAttendancePage(items: items);
    } catch (_) {}

    try {
      todayWorkout = await widget.workoutApi.getTodayWorkout();
    } catch (_) {
      try {
        todayWorkout = await LocalPlanService.getTodayWorkout();
      } catch (_) {}
    }

    if (!mounted) return;

    final active = attendancePage?.items.where((a) => a.isActive).firstOrNull;

    _timer?.cancel();
    _timer = null;

    if (active != null) {
      _elapsed = DateTime.now().difference(active.checkedIn);
      _timer = Timer.periodic(const Duration(seconds: 1), (_) {
        if (!mounted) return;
        setState(() => _elapsed += const Duration(seconds: 1));
      });
    }

    setState(() {
      _attendancePage = attendancePage;
      _todayWorkout = todayWorkout;
      _activeSession = active;
      _loading = false;
    });
    if (!_enableChallengePreview) {
      unawaited(_loadLiveChallenges(silent: true));
    }
  }

  Future<void> _endSession() async {
    final s = _activeSession;
    if (s == null) return;
    try {
      await widget.gymApi.checkOut(s.gymId);
      _timer?.cancel();
      await _load();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Could not end session: $e')));
    }
  }

  Future<void> _loadChallengeAttempts() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_challengeAttemptsKey);
      if (raw == null || raw.isEmpty) return;
      final decoded = jsonDecode(raw);
      if (decoded is! Map) return;
      final loaded = <String, List<_ChallengeAttempt>>{};
      for (final entry in decoded.entries) {
        final attempts = entry.value;
        if (attempts is! List) continue;
        loaded[entry.key.toString()] =
            attempts
                .whereType<Map>()
                .map(
                  (json) => _ChallengeAttempt.fromJson(
                    Map<String, dynamic>.from(json),
                  ),
                )
                .toList()
              ..sort((a, b) => b.recordedAt.compareTo(a.recordedAt));
      }
      if (!mounted) return;
      setState(() => _challengeAttempts = loaded);
    } catch (_) {
      // Local challenge history is non-critical.
    }
  }

  Future<void> _saveChallengeAttempts() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final encoded = jsonEncode(
        _challengeAttempts.map(
          (key, attempts) => MapEntry(
            key,
            attempts.map((attempt) => attempt.toJson()).toList(),
          ),
        ),
      );
      await prefs.setString(_challengeAttemptsKey, encoded);
    } catch (_) {
      // Fail soft; the active UI state still stays usable.
    }
  }

  List<_ChallengeAttempt> _attemptsFor(String challengeId) =>
      _challengeAttempts[challengeId] ?? const [];

  _ChallengeAttempt? _bestCompletedAttempt(String challengeId) {
    final completed =
        _attemptsFor(
            challengeId,
          ).where((attempt) => attempt.isCompleted).toList()
          ..sort((a, b) => a.elapsed.compareTo(b.elapsed));
    return completed.isEmpty ? null : completed.first;
  }

  void _startChallenge(_Challenge challenge) {
    _challengeTimer?.cancel();
    setState(() {
      _activeChallengeId = challenge.id;
      _challengeElapsed = Duration.zero;
    });
    _challengeTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      setState(() => _challengeElapsed += const Duration(seconds: 1));
    });
  }

  Future<void> _pauseChallenge(_Challenge challenge) async {
    if (_activeChallengeId != challenge.id) return;
    final reps = await _askCompletedReps(challenge);
    if (reps == null) return;
    await _recordChallengeAttempt(
      challenge: challenge,
      repsCompleted: reps,
      submittedForApproval: false,
    );
  }

  void _cancelChallenge() {
    _challengeTimer?.cancel();
    setState(() {
      _activeChallengeId = null;
      _challengeElapsed = Duration.zero;
    });
  }

  Future<void> _finishChallenge(_Challenge challenge) async {
    if (_activeChallengeId != challenge.id) return;
    await _recordChallengeAttempt(
      challenge: challenge,
      repsCompleted: challenge.targetReps,
      submittedForApproval: true,
    );
  }

  Future<void> _recordChallengeAttempt({
    required _Challenge challenge,
    required int repsCompleted,
    required bool submittedForApproval,
  }) async {
    final attempt = _ChallengeAttempt(
      id: DateTime.now().microsecondsSinceEpoch.toString(),
      challengeId: challenge.id,
      repsCompleted: repsCompleted.clamp(0, challenge.targetReps),
      targetReps: challenge.targetReps,
      elapsed: _challengeElapsed,
      recordedAt: DateTime.now(),
      approvalStatus: submittedForApproval ? 'pending' : 'partial',
    );

    _challengeTimer?.cancel();
    setState(() {
      final next = [..._attemptsFor(challenge.id), attempt]
        ..sort((a, b) => b.recordedAt.compareTo(a.recordedAt));
      _challengeAttempts = {..._challengeAttempts, challenge.id: next};
      _activeChallengeId = null;
      _challengeElapsed = Duration.zero;
    });
    await _saveChallengeAttempts();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          submittedForApproval
              ? '${challenge.title} sent to gym admin for approval.'
              : '${attempt.repsCompleted}/${challenge.targetReps} ${challenge.unit} saved as a partial attempt.',
        ),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  Future<int?> _askCompletedReps(_Challenge challenge) async {
    final controller = TextEditingController();
    final result = await showDialog<int>(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          title: Text(
            'Save partial attempt?',
            style: GoogleFonts.poppins(fontWeight: FontWeight.w800),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Pause will stop this challenge and save your current progress. If this was a mis-tap, hit Cancel to keep the timer running.',
                style: GoogleFonts.poppins(
                  fontSize: 13,
                  height: 1.45,
                  color: const Color(0xFF6B7280),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: controller,
                keyboardType: TextInputType.number,
                autofocus: true,
                decoration: InputDecoration(
                  hintText: 'Reps completed',
                  suffixText: '/ ${challenge.targetReps}',
                  filled: true,
                  fillColor: const Color(0xFFF9FAFB),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () {
                final reps = int.tryParse(controller.text.trim());
                Navigator.of(ctx).pop(reps);
              },
              child: const Text('Save'),
            ),
          ],
        );
      },
    );
    controller.dispose();
    return result;
  }

  void _showLeaderboard(_Challenge challenge) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _ChallengeLeaderboardSheet(
        challenge: challenge,
        attempts: _attemptsFor(challenge.id),
        personalBest: _bestCompletedAttempt(challenge.id),
      ),
    );
  }

  // ── Computed stats ─────────────────────────────────────────────────────────

  Future<void> _loadLiveChallenges({bool silent = false}) async {
    if (!silent) {
      setState(() {
        _challengesLoading = true;
        _challengeLoadError = null;
      });
    }
    try {
      final challenges = await _challengeApi.listChallenges(activeOnly: true);
      final activeAttempt = await _challengeApi.getActiveAttempt();
      if (!mounted) return;
      challenges.sort((a, b) {
        if (a.isFeatured != b.isFeatured) return a.isFeatured ? -1 : 1;
        return a.title.toLowerCase().compareTo(b.title.toLowerCase());
      });
      _challengeTimer?.cancel();
      setState(() {
        _liveChallenges = challenges;
        _liveActiveAttempt = activeAttempt;
        _activeChallengeId = activeAttempt?.challengeTemplateId;
        _challengeLoadError = null;
        _challengesLoading = false;
      });
      _syncLiveChallengeTimer();
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _challengesLoading = false;
        _challengeLoadError = 'Could not load challenges right now.';
      });
    }
  }

  void _syncLiveChallengeTimer() {
    _challengeTimer?.cancel();
    final attempt = _liveActiveAttempt;
    if (attempt == null) {
      if (mounted) {
        setState(() {
          _activeChallengeId = null;
          _challengeElapsed = Duration.zero;
        });
      }
      return;
    }
    setState(() {
      _activeChallengeId = attempt.challengeTemplateId;
      _challengeElapsed = _elapsedForLiveAttempt(
        attempt,
        DateTime.now().toUtc(),
      );
    });
    if (!attempt.isInProgress) return;
    _challengeTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted || _liveActiveAttempt == null) return;
      setState(() {
        _challengeElapsed = _elapsedForLiveAttempt(
          _liveActiveAttempt!,
          DateTime.now().toUtc(),
        );
      });
    });
  }

  Duration _elapsedForLiveAttempt(ChallengeAttempt attempt, DateTime nowUtc) {
    if (attempt.totalTimeSec != null) {
      return Duration(seconds: attempt.totalTimeSec!);
    }
    final pausedExtra = attempt.isPaused && attempt.pausedAt != null
        ? nowUtc.difference(attempt.pausedAt!).inSeconds
        : 0;
    final elapsedSeconds =
        nowUtc.difference(attempt.startedAt).inSeconds -
        attempt.totalPausedSec -
        pausedExtra;
    return Duration(seconds: elapsedSeconds < 0 ? 0 : elapsedSeconds);
  }

  Future<ChallengeTemplateDetail> _getLiveChallengeDetail(
    String challengeId,
  ) async {
    final cached = _liveChallengeDetails[challengeId];
    if (cached != null) return cached;
    final detail = await _challengeApi.getChallenge(challengeId);
    _liveChallengeDetails[challengeId] = detail;
    return detail;
  }

  Future<bool> _confirmSwitchFromActiveChallenge() async {
    final active = _liveActiveAttempt;
    if (active == null || !active.isInProgress) return true;
    return await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: Text(
              'Switch challenge?',
              style: GoogleFonts.poppins(fontWeight: FontWeight.w700),
            ),
            content: Text(
              'Starting another challenge will abandon your active attempt.',
              style: GoogleFonts.poppins(fontSize: 13),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(false),
                child: const Text('Cancel'),
              ),
              FilledButton(
                onPressed: () => Navigator.of(ctx).pop(true),
                child: const Text('Abandon & Start'),
              ),
            ],
          ),
        ) ??
        false;
  }

  Future<void> _startLiveChallenge(ChallengeTemplateSummary challenge) async {
    if (_challengeActionLoading) return;
    setState(() => _challengeActionLoading = true);
    try {
      final active = _liveActiveAttempt;
      if (active != null && active.challengeTemplateId != challenge.id) {
        final confirmed = await _confirmSwitchFromActiveChallenge();
        if (!confirmed) {
          if (mounted) setState(() => _challengeActionLoading = false);
          return;
        }
        await _challengeApi.abandonAttempt(active.id);
      }

      ChallengeAttempt attempt;
      final current = _liveActiveAttempt;
      if (current != null && current.challengeTemplateId == challenge.id) {
        if (current.isPaused) {
          attempt = await _challengeApi.resumeAttempt(current.id);
        } else if (current.isInProgress) {
          attempt = current;
        } else {
          attempt = await _challengeApi.startAttempt(challenge.id);
        }
      } else {
        attempt = await _challengeApi.startAttempt(challenge.id);
      }
      if (!mounted) return;
      setState(() {
        _liveActiveAttempt = attempt;
      });
      _syncLiveChallengeTimer();
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Unable to start challenge right now.')),
      );
    } finally {
      if (mounted) setState(() => _challengeActionLoading = false);
    }
  }

  Future<void> _pauseLiveChallenge() async {
    final active = _liveActiveAttempt;
    if (active == null || !active.isInProgress || _challengeActionLoading) {
      return;
    }
    setState(() => _challengeActionLoading = true);
    try {
      final paused = await _challengeApi.pauseAttempt(active.id);
      if (!mounted) return;
      setState(() {
        _liveActiveAttempt = paused;
      });
      _syncLiveChallengeTimer();
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Unable to pause challenge.')),
      );
    } finally {
      if (mounted) setState(() => _challengeActionLoading = false);
    }
  }

  Future<void> _resumeLiveChallenge() async {
    final active = _liveActiveAttempt;
    if (active == null || !active.isPaused || _challengeActionLoading) return;
    setState(() => _challengeActionLoading = true);
    try {
      final resumed = await _challengeApi.resumeAttempt(active.id);
      if (!mounted) return;
      setState(() {
        _liveActiveAttempt = resumed;
      });
      _syncLiveChallengeTimer();
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Unable to resume challenge.')),
      );
    } finally {
      if (mounted) setState(() => _challengeActionLoading = false);
    }
  }

  Future<void> _abandonLiveChallenge() async {
    final active = _liveActiveAttempt;
    if (active == null || _challengeActionLoading) return;
    setState(() => _challengeActionLoading = true);
    try {
      await _challengeApi.abandonAttempt(active.id);
      if (!mounted) return;
      setState(() {
        _liveActiveAttempt = null;
      });
      _syncLiveChallengeTimer();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Active challenge abandoned.')),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Unable to abandon challenge.')),
      );
    } finally {
      if (mounted) setState(() => _challengeActionLoading = false);
    }
  }

  Future<void> _finishLiveChallenge(ChallengeTemplateSummary challenge) async {
    final active = _liveActiveAttempt;
    if (active == null || _challengeActionLoading) return;
    setState(() => _challengeActionLoading = true);
    try {
      final detail = await _getLiveChallengeDetail(challenge.id);
      var attempt = await _challengeApi.getAttempt(active.id);
      final completedExercises = <String>{
        for (final result in attempt.exerciseResults)
          '${result.circuitNumber}:${result.orderIndex}',
      };
      final completedCircuits = <int>{
        for (final split in attempt.circuitSplits) split.circuitNumber,
      };

      final circuits = [...detail.circuits]
        ..sort((a, b) {
          final byOrder = a.orderIndex.compareTo(b.orderIndex);
          if (byOrder != 0) return byOrder;
          return a.circuitNumber.compareTo(b.circuitNumber);
        });

      for (final circuit in circuits) {
        final exercises = [...circuit.exercises]
          ..sort((a, b) => a.orderIndex.compareTo(b.orderIndex));
        for (final exercise in exercises.where((e) => e.isMandatory)) {
          final key = '${circuit.circuitNumber}:${exercise.orderIndex}';
          if (completedExercises.contains(key)) continue;
          attempt = await _challengeApi.completeExercise(
            attemptId: attempt.id,
            circuitNumber: circuit.circuitNumber,
            orderIndex: exercise.orderIndex,
            completedReps: exercise.targetReps,
            completedDurationSec:
                exercise.targetDurationSec ??
                (exercise.targetReps == null && exercise.targetDistanceM == null
                    ? (exercise.minValidSec ?? 1)
                    : null),
            completedDistanceM: exercise.targetDistanceM,
          );
          completedExercises.add(key);
        }
        if (!completedCircuits.contains(circuit.circuitNumber)) {
          attempt = await _challengeApi.completeCircuit(
            attemptId: attempt.id,
            circuitNumber: circuit.circuitNumber,
          );
          completedCircuits.add(circuit.circuitNumber);
        }
      }

      final finished = await _challengeApi.finishAttempt(attempt.id);
      if (!mounted) return;
      setState(() {
        _liveActiveAttempt = null;
      });
      _syncLiveChallengeTimer();
      await _loadLiveChallenges(silent: true);
      if (!mounted) return;
      final total = _formatChallengeTime(
        Duration(seconds: finished.totalTimeSec ?? 0),
      );
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Challenge finished in $total.')));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Finish failed: $e')));
    } finally {
      if (mounted) setState(() => _challengeActionLoading = false);
    }
  }

  Future<void> _showLiveLeaderboard(ChallengeTemplateSummary challenge) async {
    try {
      final results = await Future.wait([
        _challengeApi.personalLeaderboard(challenge.id),
        _challengeApi.gymLeaderboard(challenge.id, limit: 20),
        _challengeApi.globalLeaderboard(challenge.id, limit: 20),
      ]);
      if (!mounted) return;
      await showModalBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder: (_) => _LiveChallengeLeaderboardSheet(
          title: challenge.title,
          personal: results[0] as ChallengePersonalLeaderboard,
          gym: results[1] as ChallengeRankedLeaderboard,
          global: results[2] as ChallengeRankedLeaderboard,
        ),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Unable to load leaderboard right now.')),
      );
    }
  }

  List<GymAttendance> get _thisWeek {
    final now = DateTime.now();
    final weekStart = DateTime(
      now.year,
      now.month,
      now.day - (now.weekday - 1),
    );
    return (_attendancePage?.items ?? [])
        .where((a) => a.checkedIn.isAfter(weekStart))
        .toList();
  }

  int get _weekSessions => _thisWeek.length;

  int get _weekMinutes => _thisWeek.fold<int>(0, (s, a) {
    final out = a.checkOut;
    return s + (out != null ? out.difference(a.checkedIn).inMinutes : 0);
  });

  int get _gymsVisited => _thisWeek.map((a) => a.gymId).toSet().length;

  int get _dayStreak {
    final items = _attendancePage?.items ?? [];
    if (items.isEmpty) return 0;
    int streak = 0;
    final today = DateTime.now();
    for (int i = 0; i < 30; i++) {
      final d = today.subtract(Duration(days: i));
      final has = items.any(
        (a) =>
            a.checkedIn.year == d.year &&
            a.checkedIn.month == d.month &&
            a.checkedIn.day == d.day,
      );
      if (has) {
        streak++;
      } else if (i > 0) {
        break;
      }
    }
    return streak;
  }

  String _formatTimer(Duration d) {
    final h = d.inHours.toString().padLeft(2, '0');
    final m = (d.inMinutes % 60).toString().padLeft(2, '0');
    final s = (d.inSeconds % 60).toString().padLeft(2, '0');
    return '$h:$m:$s';
  }

  String _formatChallengeTime(Duration d) {
    final minutes = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final seconds = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    if (d.inHours > 0) {
      return '${d.inHours}:$minutes:$seconds';
    }
    return '$minutes:$seconds';
  }

  // ── Build ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F7),
      body: RefreshIndicator(
        onRefresh: _load,
        child: CustomScrollView(
          physics: const BouncingScrollPhysics(
            parent: AlwaysScrollableScrollPhysics(),
          ),
          slivers: [
            SliverToBoxAdapter(child: _buildHeader()),
            if (_loading)
              const SliverFillRemaining(
                child: Center(child: CircularProgressIndicator()),
              )
            else ...[
              // Session state
              if (_activeSession != null)
                _sliver(_buildActiveSessionCard(), top: 0)
              else
                _sliver(_buildNoSessionCard()),
              // Steps & Active Calories (Apple Fitness style)
              _sliver(_buildStepsCard()),
              // Workout
              _sliver(_buildWorkoutCard()),
              if (_enableChallengePreview)
                _sliver(_buildChallengesSection())
              else
                _sliver(_buildLiveChallengesSection()),
              // This Week
              _sliver(_buildThisWeekSection()),
              // Recent Activity + History
              _sliver(_buildActivityHistory(), bottom: 40),
            ],
          ],
        ),
      ),
    );
  }

  SliverPadding _sliver(Widget child, {double top = 12, double bottom = 0}) {
    return SliverPadding(
      padding: EdgeInsets.fromLTRB(16, top, 16, bottom),
      sliver: SliverToBoxAdapter(child: child),
    );
  }

  // ── Header ─────────────────────────────────────────────────────────────────

  Widget _buildHeader() {
    return Container(
      decoration: const BoxDecoration(color: Color(0xFFEDF7EE)),
      padding: EdgeInsets.only(
        top: MediaQuery.of(context).padding.top + 20,
        left: 20,
        right: 20,
        bottom: 20,
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Activity',
                style: GoogleFonts.poppins(
                  fontSize: 28,
                  fontWeight: FontWeight.w800,
                  color: const Color(0xFF111827),
                  height: 1.1,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                'Track your fitness journey',
                style: GoogleFonts.poppins(
                  fontSize: 13,
                  color: const Color(0xFF6B7280),
                ),
              ),
            ],
          ),
          // Quick stats pill
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.06),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Row(
              children: [
                const Icon(
                  Icons.local_fire_department_rounded,
                  size: 16,
                  color: Color(0xFFF59E0B),
                ),
                const SizedBox(width: 5),
                Text(
                  '$_dayStreak day streak',
                  style: GoogleFonts.poppins(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: const Color(0xFF374151),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── No-session empty state ─────────────────────────────────────────────────

  Widget _buildNoSessionCard() {
    return _Card(
      child: Column(
        children: [
          const SizedBox(height: 8),
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              color: const Color(0xFFF3F4F6),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.ssid_chart_rounded,
              size: 30,
              color: Color(0xFF9CA3AF),
            ),
          ),
          const SizedBox(height: 14),
          Text(
            'You\'re not in a session',
            style: GoogleFonts.poppins(
              fontSize: 15,
              fontWeight: FontWeight.w700,
              color: const Color(0xFF111827),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Start a workout session\nto track your activity',
            textAlign: TextAlign.center,
            style: GoogleFonts.poppins(
              fontSize: 12,
              color: const Color(0xFF9CA3AF),
              height: 1.5,
            ),
          ),
          const SizedBox(height: 18),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => WorkoutPage(workoutApi: widget.workoutApi),
                ),
              ),
              icon: const Icon(Icons.play_arrow_rounded, size: 18),
              label: Text(
                'Start Session',
                style: GoogleFonts.poppins(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                ),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF111827),
                foregroundColor: Colors.white,
                elevation: 0,
                padding: const EdgeInsets.symmetric(vertical: 13),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
            ),
          ),
          const SizedBox(height: 4),
        ],
      ),
    );
  }

  // ── Active session card ────────────────────────────────────────────────────

  Widget _buildActiveSessionCard() {
    final s = _activeSession!;
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF111827),
        borderRadius: BorderRadius.circular(22),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF111827).withValues(alpha: 0.25),
            blurRadius: 24,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Gym name + Active badge
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  s.gymName ?? 'Gym',
                  style: GoogleFonts.poppins(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: Colors.white.withValues(alpha: 0.7),
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: const Color(0xFF22C55E),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 6,
                      height: 6,
                      decoration: const BoxDecoration(
                        color: Colors.white,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 5),
                    Text(
                      'Active',
                      style: GoogleFonts.poppins(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 2),
          Text(
            'Gym Session',
            style: GoogleFonts.poppins(
              fontSize: 20,
              fontWeight: FontWeight.w800,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 20),
          // Timer block
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 24),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.07),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              children: [
                const Icon(
                  Icons.timer_outlined,
                  size: 22,
                  color: Colors.white54,
                ),
                const SizedBox(height: 10),
                Text(
                  _formatTimer(_elapsed),
                  style: GoogleFonts.robotoMono(
                    fontSize: 40,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                    letterSpacing: 3,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Session Duration',
                  style: GoogleFonts.poppins(
                    fontSize: 12,
                    color: Colors.white54,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          // Buttons
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _endSession,
                  icon: const Icon(Icons.stop_rounded, size: 16),
                  label: Text(
                    'End Session',
                    style: GoogleFonts.poppins(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.white,
                    side: const BorderSide(color: Colors.white38, width: 1.5),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: OutlinedButton(
                  onPressed: () => Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) =>
                          WorkoutPage(workoutApi: widget.workoutApi),
                    ),
                  ),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.white,
                    side: const BorderSide(color: Colors.white38, width: 1.5),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: Text(
                    'Add Exercise',
                    style: GoogleFonts.poppins(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ── Steps & Active Calories (Apple Fitness style) ─────────────────────────

  Widget _buildStepsCard() {
    return ListenableBuilder(
      listenable: StepService.instance,
      builder: (context, child) {
        final svc = StepService.instance;
        final steps = svc.todaySteps;
        final goal = StepService.dailyGoal;
        final progress = svc.progress;
        final calories = svc.activeCalories;
        final distanceKm = svc.distanceKm;

        if (svc.permissionDenied) {
          return _Card(
            child: Row(
              children: [
                const Icon(
                  Icons.directions_walk_rounded,
                  size: 28,
                  color: Color(0xFFEA580C),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Text(
                    'Enable Activity Recognition to track steps',
                    style: GoogleFonts.poppins(
                      fontSize: 13,
                      color: const Color(0xFF6B7280),
                    ),
                  ),
                ),
              ],
            ),
          );
        }

        return _Card(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header row
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 34,
                        height: 34,
                        decoration: BoxDecoration(
                          color: const Color(0xFFFFEDD5),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.directions_walk_rounded,
                          size: 18,
                          color: Color(0xFFEA580C),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Text(
                        'Move',
                        style: GoogleFonts.poppins(
                          fontSize: 17,
                          fontWeight: FontWeight.w700,
                          color: const Color(0xFF111827),
                        ),
                      ),
                    ],
                  ),
                  Text(
                    'Today',
                    style: GoogleFonts.poppins(
                      fontSize: 12,
                      color: const Color(0xFF9CA3AF),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              // Ring + stats side by side
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  // Activity ring
                  SizedBox(
                    width: 110,
                    height: 110,
                    child: CustomPaint(
                      painter: _ActivityRingPainter(progress: progress),
                      child: Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              steps >= 1000
                                  ? '${(steps / 1000).toStringAsFixed(1)}k'
                                  : '$steps',
                              style: GoogleFonts.poppins(
                                fontSize: 20,
                                fontWeight: FontWeight.w800,
                                color: const Color(0xFF111827),
                              ),
                            ),
                            Text(
                              'steps',
                              style: GoogleFonts.poppins(
                                fontSize: 10,
                                color: const Color(0xFF9CA3AF),
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 20),
                  // Stats column
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _StepStat(
                          label: 'Goal',
                          value: '${(goal / 1000).toStringAsFixed(0)}k steps',
                          color: const Color(0xFFEA580C),
                        ),
                        const SizedBox(height: 12),
                        _StepStat(
                          label: 'Active Cal',
                          value: '${calories.round()} kcal',
                          color: const Color(0xFFDC2626),
                        ),
                        const SizedBox(height: 12),
                        _StepStat(
                          label: 'Distance',
                          value: '${distanceKm.toStringAsFixed(2)} km',
                          color: const Color(0xFF7C3AED),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              // Progress bar
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: progress,
                  minHeight: 6,
                  backgroundColor: const Color(0xFFF3F4F6),
                  valueColor: const AlwaysStoppedAnimation(Color(0xFFEA580C)),
                ),
              ),
              const SizedBox(height: 6),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    '${(progress * 100).round()}% of daily goal',
                    style: GoogleFonts.poppins(
                      fontSize: 11,
                      color: const Color(0xFF9CA3AF),
                    ),
                  ),
                  Text(
                    '${(goal - steps).clamp(0, goal).toStringAsFixed(0)} steps left',
                    style: GoogleFonts.poppins(
                      fontSize: 11,
                      color: const Color(0xFF9CA3AF),
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  // ── Workout card ───────────────────────────────────────────────────────────

  Widget _buildWorkoutCard() {
    final label = _todayWorkout?.dayLabel;
    return _Card(
      child: Row(
        children: [
          _IconBox(
            icon: Icons.fitness_center_rounded,
            bg: const Color(0xFFEDE9FE),
            color: const Color(0xFF7C3AED),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Workout',
                  style: GoogleFonts.poppins(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: const Color(0xFF111827),
                  ),
                ),
                Text(
                  label != null ? 'Today: $label' : 'Start your gym workout',
                  style: GoogleFonts.poppins(
                    fontSize: 12,
                    color: const Color(0xFF9CA3AF),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          ElevatedButton.icon(
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => WorkoutPage(workoutApi: widget.workoutApi),
              ),
            ),
            icon: const Icon(Icons.play_arrow_rounded, size: 15),
            label: Text(
              'Start',
              style: GoogleFonts.poppins(
                fontSize: 12,
                fontWeight: FontWeight.w700,
              ),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF111827),
              foregroundColor: Colors.white,
              elevation: 0,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── This Week section ──────────────────────────────────────────────────────

  Widget _buildLiveChallengesSection() {
    final activeTemplateId = _liveActiveAttempt?.challengeTemplateId;
    return _Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF0F172A), Color(0xFF1D4ED8)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: const Icon(
                  Icons.workspace_premium_rounded,
                  color: Colors.white,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Challenges',
                      style: GoogleFonts.poppins(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        color: const Color(0xFF111827),
                      ),
                    ),
                    Text(
                      'Synced from backend',
                      style: GoogleFonts.poppins(
                        fontSize: 12,
                        color: const Color(0xFF6B7280),
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                onPressed: _challengesLoading ? null : _loadLiveChallenges,
                icon: _challengesLoading
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.refresh_rounded),
                tooltip: 'Refresh',
              ),
            ],
          ),
          const SizedBox(height: 14),
          if (_challengeLoadError != null)
            Text(
              _challengeLoadError!,
              style: GoogleFonts.poppins(
                fontSize: 12,
                color: const Color(0xFFB91C1C),
              ),
            )
          else if (_liveChallenges.isEmpty && _challengesLoading)
            const Center(child: CircularProgressIndicator())
          else if (_liveChallenges.isEmpty)
            Text(
              'No active challenges available right now.',
              style: GoogleFonts.poppins(
                fontSize: 12,
                color: const Color(0xFF6B7280),
              ),
            )
          else
            ..._liveChallenges.take(4).map((challenge) {
              final isActive = challenge.id == activeTemplateId;
              final tone = _challengeTone(challenge.category);
              return Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF9FAFB),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: isActive ? tone : const Color(0xFFE5E7EB),
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(
                            _challengeIcon(challenge.category),
                            color: tone,
                            size: 18,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              challenge.title,
                              style: GoogleFonts.poppins(
                                fontSize: 14,
                                fontWeight: FontWeight.w700,
                                color: const Color(0xFF111827),
                              ),
                            ),
                          ),
                          if (isActive)
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: tone.withValues(alpha: 0.12),
                                borderRadius: BorderRadius.circular(999),
                              ),
                              child: Text(
                                _liveActiveAttempt?.isPaused == true
                                    ? 'Paused'
                                    : 'Live',
                                style: GoogleFonts.poppins(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w700,
                                  color: tone,
                                ),
                              ),
                            ),
                        ],
                      ),
                      if ((challenge.description ?? '').trim().isNotEmpty) ...[
                        const SizedBox(height: 6),
                        Text(
                          challenge.description!,
                          style: GoogleFonts.poppins(
                            fontSize: 12,
                            color: const Color(0xFF6B7280),
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          Text(
                            '${challenge.pointsReward} pts',
                            style: GoogleFonts.poppins(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: const Color(0xFF111827),
                            ),
                          ),
                          const SizedBox(width: 10),
                          if (challenge.estimatedDurationSec != null)
                            Text(
                              '${(challenge.estimatedDurationSec! / 60).round()} min',
                              style: GoogleFonts.poppins(
                                fontSize: 12,
                                color: const Color(0xFF6B7280),
                              ),
                            ),
                          const Spacer(),
                          if (isActive)
                            Text(
                              _formatChallengeTime(_challengeElapsed),
                              style: GoogleFonts.robotoMono(
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                                color: tone,
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          if (!isActive)
                            FilledButton.icon(
                              onPressed: _challengeActionLoading
                                  ? null
                                  : () => _startLiveChallenge(challenge),
                              icon: const Icon(
                                Icons.play_arrow_rounded,
                                size: 16,
                              ),
                              label: const Text('Start'),
                              style: FilledButton.styleFrom(
                                backgroundColor: const Color(0xFF111827),
                                foregroundColor: Colors.white,
                                textStyle: GoogleFonts.poppins(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                          if (isActive &&
                              _liveActiveAttempt?.isInProgress == true)
                            OutlinedButton.icon(
                              onPressed: _challengeActionLoading
                                  ? null
                                  : _pauseLiveChallenge,
                              icon: const Icon(Icons.pause_rounded, size: 16),
                              label: const Text('Pause'),
                            ),
                          if (isActive && _liveActiveAttempt?.isPaused == true)
                            OutlinedButton.icon(
                              onPressed: _challengeActionLoading
                                  ? null
                                  : _resumeLiveChallenge,
                              icon: const Icon(
                                Icons.play_arrow_rounded,
                                size: 16,
                              ),
                              label: const Text('Resume'),
                            ),
                          if (isActive)
                            FilledButton.icon(
                              onPressed: _challengeActionLoading
                                  ? null
                                  : () => _finishLiveChallenge(challenge),
                              icon: const Icon(Icons.flag_rounded, size: 16),
                              label: const Text('Finish'),
                              style: FilledButton.styleFrom(
                                backgroundColor: tone,
                                foregroundColor: Colors.white,
                              ),
                            ),
                          if (isActive)
                            TextButton(
                              onPressed: _challengeActionLoading
                                  ? null
                                  : _abandonLiveChallenge,
                              child: const Text('Abandon'),
                            ),
                          OutlinedButton.icon(
                            onPressed: () => _showLiveLeaderboard(challenge),
                            icon: const Icon(
                              Icons.leaderboard_rounded,
                              size: 16,
                            ),
                            label: const Text('Leaderboard'),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              );
            }),
        ],
      ),
    );
  }

  IconData _challengeIcon(String category) {
    switch (category) {
      case 'STRENGTH':
        return Icons.fitness_center_rounded;
      case 'ENDURANCE':
        return Icons.directions_run_rounded;
      case 'HIIT':
        return Icons.bolt_rounded;
      case 'MOBILITY':
        return Icons.self_improvement_rounded;
      case 'SKILL':
        return Icons.emoji_events_rounded;
      case 'FAT_LOSS':
      default:
        return Icons.local_fire_department_rounded;
    }
  }

  Color _challengeTone(String category) {
    switch (category) {
      case 'STRENGTH':
        return const Color(0xFF7C3AED);
      case 'ENDURANCE':
        return const Color(0xFF0284C7);
      case 'HIIT':
        return const Color(0xFFDC2626);
      case 'MOBILITY':
        return const Color(0xFF059669);
      case 'SKILL':
        return const Color(0xFFD97706);
      case 'FAT_LOSS':
      default:
        return const Color(0xFF2563EB);
    }
  }

  Widget _buildChallengesSection() {
    return _Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF111827), Color(0xFF334155)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: const Icon(
                  Icons.workspace_premium_rounded,
                  color: Colors.white,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Challenges',
                      style: GoogleFonts.poppins(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        color: const Color(0xFF111827),
                      ),
                    ),
                    Text(
                      'Timed gym tests with personal bests',
                      style: GoogleFonts.poppins(
                        fontSize: 12,
                        color: const Color(0xFF6B7280),
                      ),
                    ),
                  ],
                ),
              ),
              TextButton.icon(
                onPressed: () => _showLeaderboard(_challenges.first),
                icon: const Icon(Icons.leaderboard_rounded, size: 16),
                label: const Text('Leaderboard'),
                style: TextButton.styleFrom(
                  foregroundColor: const Color(0xFF111827),
                  textStyle: GoogleFonts.poppins(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          ..._challenges.map((challenge) {
            final isActive = _activeChallengeId == challenge.id;
            final attempts = _attemptsFor(challenge.id);
            final best = _bestCompletedAttempt(challenge.id);
            return Padding(
              padding: EdgeInsets.only(
                bottom: challenge == _challenges.last ? 0 : 12,
              ),
              child: _ChallengeCard(
                challenge: challenge,
                attempts: attempts,
                personalBest: best,
                isActive: isActive,
                timeLabel: isActive
                    ? _formatChallengeTime(_challengeElapsed)
                    : best == null
                    ? '--:--'
                    : _formatChallengeTime(best.elapsed),
                onStart: () => _startChallenge(challenge),
                onPause: () => _pauseChallenge(challenge),
                onFinish: () => _finishChallenge(challenge),
                onCancel: _cancelChallenge,
                onLeaderboard: () => _showLeaderboard(challenge),
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget _buildThisWeekSection() {
    final weekMin = _weekMinutes;
    return _Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'This Week',
            style: GoogleFonts.poppins(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: const Color(0xFF111827),
            ),
          ),
          const SizedBox(height: 4),
          _WeekRow(
            icon: Icons.ssid_chart_rounded,
            iconBg: const Color(0xFFEEF2FF),
            iconColor: const Color(0xFF6366F1),
            label: 'Sessions',
            value: '$_weekSessions',
          ),
          const _Divider(),
          _WeekRow(
            icon: Icons.timer_outlined,
            iconBg: const Color(0xFFECFDF5),
            iconColor: const Color(0xFF059669),
            label: 'Duration',
            value: weekMin > 0 ? '$weekMin min' : '0 min',
          ),
          const _Divider(),
          _WeekRow(
            icon: Icons.place_outlined,
            iconBg: const Color(0xFFFFF7ED),
            iconColor: const Color(0xFFF59E0B),
            label: 'Gyms Visited',
            value: '$_gymsVisited',
          ),
        ],
      ),
    );
  }

  // ── Activity history ───────────────────────────────────────────────────────

  Widget _buildActivityHistory() {
    final items = _attendancePage?.items ?? [];
    if (items.isEmpty) {
      return _Card(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 20),
          child: Column(
            children: [
              const Icon(
                Icons.history_rounded,
                size: 40,
                color: Color(0xFFD1D5DB),
              ),
              const SizedBox(height: 10),
              Text(
                'No gym sessions yet',
                style: GoogleFonts.poppins(
                  fontSize: 14,
                  color: const Color(0xFF9CA3AF),
                ),
              ),
            ],
          ),
        ),
      );
    }

    // Group by date
    final Map<String, List<GymAttendance>> grouped = {};
    for (final a in items) {
      final key = _dateKey(a.checkedIn);
      grouped.putIfAbsent(key, () => []).add(a);
    }

    final recent = items.take(3).toList();
    final historyKeys = grouped.keys.toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Recent Activity
        _SectionLabel(label: 'Recent Activity'),
        const SizedBox(height: 8),
        _Card(
          child: Column(
            children: recent
                .map((a) => _ActivityRow(attendance: a, showTime: false))
                .toList(),
          ),
        ),
        const SizedBox(height: 20),
        // History grouped
        _SectionLabel(label: 'History'),
        const SizedBox(height: 8),
        ...historyKeys.map((key) {
          final dayItems = grouped[key]!;
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Text(
                  key,
                  style: GoogleFonts.poppins(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: const Color(0xFF6B7280),
                  ),
                ),
              ),
              _Card(
                child: Column(
                  children: dayItems
                      .map((a) => _ActivityRow(attendance: a, showTime: true))
                      .toList(),
                ),
              ),
              const SizedBox(height: 10),
            ],
          );
        }),
      ],
    );
  }

  String _dateKey(DateTime dt) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(const Duration(days: 1));
    final day = DateTime(dt.year, dt.month, dt.day);
    if (day == today) return 'Today';
    if (day == yesterday) return 'Yesterday';
    return DateFormat('MMMM d').format(dt);
  }
}

// ══════════════════════════════════════════════════════════════════════════════
//  Step sub-widgets
// ══════════════════════════════════════════════════════════════════════════════

/// Apple Fitness-style circular activity ring.
class _ActivityRingPainter extends CustomPainter {
  const _ActivityRingPainter({required this.progress});
  final double progress;

  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width / 2;
    final cy = size.height / 2;
    final radius = (size.width - 16) / 2;
    const strokeW = 10.0;
    final rect = Rect.fromCircle(center: Offset(cx, cy), radius: radius);

    // Track
    final trackPaint = Paint()
      ..color = const Color(0xFFFFEDD5)
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeW
      ..strokeCap = StrokeCap.round;
    canvas.drawCircle(Offset(cx, cy), radius, trackPaint);

    // Progress arc
    final arcPaint = Paint()
      ..color = const Color(0xFFEA580C)
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeW
      ..strokeCap = StrokeCap.round;
    canvas.drawArc(
      rect,
      -3.14159 / 2, // start at top
      2 * 3.14159 * progress.clamp(0.0, 1.0),
      false,
      arcPaint,
    );
  }

  @override
  bool shouldRepaint(_ActivityRingPainter old) => old.progress != progress;
}

/// Small stat row: label + value with a color accent dot.
class _StepStat extends StatelessWidget {
  const _StepStat({
    required this.label,
    required this.value,
    required this.color,
  });
  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 8),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: GoogleFonts.poppins(
                fontSize: 10,
                color: const Color(0xFF9CA3AF),
                fontWeight: FontWeight.w500,
              ),
            ),
            Text(
              value,
              style: GoogleFonts.poppins(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: const Color(0xFF111827),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
//  Sub-widgets
// ══════════════════════════════════════════════════════════════════════════════

class _Card extends StatelessWidget {
  const _Card({required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: child,
    );
  }
}

class _IconBox extends StatelessWidget {
  const _IconBox({required this.icon, required this.bg, required this.color});
  final IconData icon;
  final Color bg;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 44,
      height: 44,
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Icon(icon, color: color, size: 22),
    );
  }
}

class _Challenge {
  const _Challenge({
    required this.id,
    required this.title,
    required this.targetReps,
    required this.unit,
    required this.accent,
    required this.softAccent,
    required this.icon,
    required this.description,
    required this.expiryDays,
  });

  final String id;
  final String title;
  final int targetReps;
  final String unit;
  final Color accent;
  final Color softAccent;
  final IconData icon;
  final String description;
  final int expiryDays;
}

class _ChallengeAttempt {
  const _ChallengeAttempt({
    required this.id,
    required this.challengeId,
    required this.repsCompleted,
    required this.targetReps,
    required this.elapsed,
    required this.recordedAt,
    required this.approvalStatus,
  });

  final String id;
  final String challengeId;
  final int repsCompleted;
  final int targetReps;
  final Duration elapsed;
  final DateTime recordedAt;
  final String approvalStatus;

  bool get isCompleted => repsCompleted >= targetReps;

  Map<String, dynamic> toJson() => {
    'id': id,
    'challenge_id': challengeId,
    'reps_completed': repsCompleted,
    'target_reps': targetReps,
    'elapsed_ms': elapsed.inMilliseconds,
    'recorded_at': recordedAt.toIso8601String(),
    'approval_status': approvalStatus,
  };

  factory _ChallengeAttempt.fromJson(Map<String, dynamic> json) {
    return _ChallengeAttempt(
      id: json['id']?.toString() ?? '',
      challengeId: json['challenge_id']?.toString() ?? '',
      repsCompleted: (json['reps_completed'] as num?)?.toInt() ?? 0,
      targetReps: (json['target_reps'] as num?)?.toInt() ?? 0,
      elapsed: Duration(
        milliseconds: (json['elapsed_ms'] as num?)?.toInt() ?? 0,
      ),
      recordedAt:
          DateTime.tryParse(json['recorded_at']?.toString() ?? '') ??
          DateTime.now(),
      approvalStatus:
          json['approval_status']?.toString() ??
          (((json['reps_completed'] as num?)?.toInt() ?? 0) >=
                  ((json['target_reps'] as num?)?.toInt() ?? 0)
              ? 'pending'
              : 'partial'),
    );
  }
}

class _ChallengeCard extends StatelessWidget {
  const _ChallengeCard({
    required this.challenge,
    required this.attempts,
    required this.personalBest,
    required this.isActive,
    required this.timeLabel,
    required this.onStart,
    required this.onPause,
    required this.onFinish,
    required this.onCancel,
    required this.onLeaderboard,
  });

  final _Challenge challenge;
  final List<_ChallengeAttempt> attempts;
  final _ChallengeAttempt? personalBest;
  final bool isActive;
  final String timeLabel;
  final VoidCallback onStart;
  final VoidCallback onPause;
  final VoidCallback onFinish;
  final VoidCallback onCancel;
  final VoidCallback onLeaderboard;

  @override
  Widget build(BuildContext context) {
    final lastAttempt = attempts.isEmpty ? null : attempts.first;
    return AnimatedContainer(
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOutCubic,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isActive ? const Color(0xFF111827) : const Color(0xFFF9FAFB),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isActive ? const Color(0xFF111827) : const Color(0xFFE5E7EB),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  color: isActive
                      ? Colors.white.withValues(alpha: 0.12)
                      : challenge.softAccent,
                  borderRadius: BorderRadius.circular(15),
                ),
                child: Icon(
                  challenge.icon,
                  color: isActive ? Colors.white : challenge.accent,
                  size: 24,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      challenge.title,
                      style: GoogleFonts.poppins(
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                        color: isActive
                            ? Colors.white
                            : const Color(0xFF111827),
                      ),
                    ),
                    Text(
                      challenge.description,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.poppins(
                        fontSize: 11,
                        height: 1.35,
                        color: isActive
                            ? Colors.white.withValues(alpha: 0.64)
                            : const Color(0xFF6B7280),
                      ),
                    ),
                    const SizedBox(height: 8),
                    _ExpiryChip(
                      label: 'Expires in ${challenge.expiryDays} days',
                      isActive: isActive,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              _ChallengeTimePill(
                label: personalBest == null && !isActive ? 'Best' : 'Time',
                time: timeLabel,
                isActive: isActive,
                color: challenge.accent,
              ),
            ],
          ),
          const SizedBox(height: 14),
          if (isActive)
            _ActiveChallengeControls(
              onPause: onPause,
              onFinish: onFinish,
              onCancel: onCancel,
            )
          else ...[
            Row(
              children: [
                _ChallengeMetric(
                  label: 'Attempts',
                  value: attempts.length.toString(),
                  dark: false,
                ),
                const SizedBox(width: 10),
                _ChallengeMetric(
                  label: 'Completed',
                  value: attempts.where((a) => a.isCompleted).length.toString(),
                  dark: false,
                ),
                const SizedBox(width: 10),
                _ChallengeMetric(
                  label: 'Last',
                  value: lastAttempt == null
                      ? '-'
                      : '${lastAttempt.repsCompleted}/${challenge.targetReps}',
                  dark: false,
                ),
              ],
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(
                  child: FilledButton.icon(
                    onPressed: onStart,
                    icon: Icon(
                      attempts.isEmpty
                          ? Icons.play_arrow_rounded
                          : Icons.replay_rounded,
                      size: 18,
                    ),
                    label: Text(attempts.isEmpty ? 'Start' : 'Reattempt'),
                    style: FilledButton.styleFrom(
                      backgroundColor: const Color(0xFF111827),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                      textStyle: GoogleFonts.poppins(
                        fontSize: 13,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                OutlinedButton.icon(
                  onPressed: onLeaderboard,
                  icon: const Icon(Icons.leaderboard_rounded, size: 17),
                  label: const Text('Board'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: const Color(0xFF111827),
                    side: const BorderSide(color: Color(0xFFD1D5DB)),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 12,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _ChallengeTimePill extends StatelessWidget {
  const _ChallengeTimePill({
    required this.label,
    required this.time,
    required this.isActive,
    required this.color,
  });

  final String label;
  final String time;
  final bool isActive;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: isActive ? Colors.white.withValues(alpha: 0.12) : Colors.white,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        children: [
          Text(
            label,
            style: GoogleFonts.poppins(
              fontSize: 9,
              fontWeight: FontWeight.w700,
              color: isActive
                  ? Colors.white.withValues(alpha: 0.65)
                  : const Color(0xFF9CA3AF),
            ),
          ),
          Text(
            time,
            style: GoogleFonts.robotoMono(
              fontSize: 15,
              fontWeight: FontWeight.w800,
              color: isActive ? Colors.white : color,
            ),
          ),
        ],
      ),
    );
  }
}

class _ExpiryChip extends StatelessWidget {
  const _ExpiryChip({required this.label, required this.isActive});

  final String label;
  final bool isActive;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: isActive
            ? Colors.white.withValues(alpha: 0.14)
            : const Color(0xFFFFF7ED),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(
          color: isActive
              ? Colors.white.withValues(alpha: 0.18)
              : const Color(0xFFFED7AA),
        ),
      ),
      child: Text(
        label,
        style: GoogleFonts.poppins(
          fontSize: 10,
          fontWeight: FontWeight.w800,
          letterSpacing: 0.1,
          color: isActive ? Colors.white : const Color(0xFFC2410C),
        ),
      ),
    );
  }
}

class _ChallengeMetric extends StatelessWidget {
  const _ChallengeMetric({
    required this.label,
    required this.value,
    required this.dark,
  });

  final String label;
  final String value;
  final bool dark;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
        decoration: BoxDecoration(
          color: dark
              ? Colors.white.withValues(alpha: 0.1)
              : const Color(0xFFFFFFFF),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: GoogleFonts.poppins(
                fontSize: 10,
                color: dark
                    ? Colors.white.withValues(alpha: 0.62)
                    : const Color(0xFF9CA3AF),
              ),
            ),
            Text(
              value,
              style: GoogleFonts.poppins(
                fontSize: 14,
                fontWeight: FontWeight.w800,
                color: dark ? Colors.white : const Color(0xFF111827),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ActiveChallengeControls extends StatelessWidget {
  const _ActiveChallengeControls({
    required this.onPause,
    required this.onFinish,
    required this.onCancel,
  });

  final VoidCallback onPause;
  final VoidCallback onFinish;
  final VoidCallback onCancel;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Row(
            children: [
              const Icon(Icons.timer_rounded, color: Colors.white),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Finish submits this attempt to the gym admin for validation. Pause saves a partial attempt.',
                  style: GoogleFonts.poppins(
                    fontSize: 12.5,
                    height: 1.35,
                    fontWeight: FontWeight.w600,
                    color: Colors.white.withValues(alpha: 0.9),
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: onPause,
                icon: const Icon(Icons.pause_rounded, size: 17),
                label: const Text('Pause & save'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.white,
                  backgroundColor: Colors.white.withValues(alpha: 0.08),
                  side: BorderSide(color: Colors.white.withValues(alpha: 0.55)),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: FilledButton.icon(
                onPressed: onFinish,
                icon: const Icon(Icons.flag_rounded, size: 17),
                label: const Text('Finish'),
                style: FilledButton.styleFrom(
                  backgroundColor: Colors.white,
                  foregroundColor: const Color(0xFF111827),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 10),
            IconButton(
              onPressed: onCancel,
              icon: const Icon(Icons.close_rounded),
              color: Colors.white70,
              tooltip: 'Cancel attempt',
            ),
          ],
        ),
      ],
    );
  }
}

class _ChallengeLeaderboardSheet extends StatelessWidget {
  const _ChallengeLeaderboardSheet({
    required this.challenge,
    required this.attempts,
    required this.personalBest,
  });

  final _Challenge challenge;
  final List<_ChallengeAttempt> attempts;
  final _ChallengeAttempt? personalBest;

  @override
  Widget build(BuildContext context) {
    final completedAttempts = attempts.where((a) => a.isCompleted).toList()
      ..sort((a, b) => a.elapsed.compareTo(b.elapsed));
    final gymRows = _gymRows(challenge, personalBest);

    return DraggableScrollableSheet(
      initialChildSize: 0.82,
      minChildSize: 0.5,
      maxChildSize: 0.94,
      builder: (context, controller) {
        return Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
          ),
          child: ListView(
            controller: controller,
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
            children: [
              Center(
                child: Container(
                  width: 44,
                  height: 5,
                  decoration: BoxDecoration(
                    color: const Color(0xFFE5E7EB),
                    borderRadius: BorderRadius.circular(999),
                  ),
                ),
              ),
              const SizedBox(height: 18),
              Text(
                '${challenge.title} Leaderboard',
                style: GoogleFonts.poppins(
                  fontSize: 22,
                  fontWeight: FontWeight.w900,
                  color: const Color(0xFF111827),
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Frontend preview. Gym-wide scores will sync from backend later.',
                style: GoogleFonts.poppins(
                  fontSize: 12,
                  color: const Color(0xFF6B7280),
                ),
              ),
              const SizedBox(height: 18),
              _PersonalBestPanel(
                challenge: challenge,
                personalBest: personalBest,
                completedAttempts: completedAttempts.length,
                totalAttempts: attempts.length,
              ),
              const SizedBox(height: 20),
              _LeaderboardSectionTitle(
                title: 'Gym Best Times',
                subtitle: 'Best completed attempts only',
              ),
              const SizedBox(height: 10),
              ...gymRows.asMap().entries.map((entry) {
                return _LeaderboardRow(
                  rank: entry.key + 1,
                  name: entry.value.name,
                  time: _formatDuration(entry.value.elapsed),
                  meta: entry.value.meta,
                  highlight: entry.value.isUser,
                );
              }),
              const SizedBox(height: 20),
              _LeaderboardSectionTitle(
                title: 'Your Attempts',
                subtitle: 'Completed and partial attempts are both saved',
              ),
              const SizedBox(height: 10),
              if (attempts.isEmpty)
                _EmptyAttemptPanel(challenge: challenge)
              else
                ...attempts.take(8).map((attempt) {
                  return _AttemptRow(challenge: challenge, attempt: attempt);
                }),
            ],
          ),
        );
      },
    );
  }

  static String _formatDuration(Duration d) {
    final minutes = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final seconds = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    if (d.inHours > 0) return '${d.inHours}:$minutes:$seconds';
    return '$minutes:$seconds';
  }

  List<_GymLeaderboardRowData> _gymRows(
    _Challenge challenge,
    _ChallengeAttempt? best,
  ) {
    final rows = <_GymLeaderboardRowData>[
      _GymLeaderboardRowData(
        name: 'Aarav',
        elapsed: challenge.id == 'burpees_50'
            ? const Duration(minutes: 3, seconds: 54)
            : const Duration(minutes: 4, seconds: 40),
        meta: 'FlexiCurl Gym',
      ),
      _GymLeaderboardRowData(
        name: 'Meera',
        elapsed: challenge.id == 'burpees_50'
            ? const Duration(minutes: 4, seconds: 12)
            : const Duration(minutes: 5, seconds: 2),
        meta: 'FlexiCurl Gym',
      ),
      _GymLeaderboardRowData(
        name: 'Kabir',
        elapsed: challenge.id == 'burpees_50'
            ? const Duration(minutes: 4, seconds: 35)
            : const Duration(minutes: 5, seconds: 21),
        meta: 'FlexiCurl Gym',
      ),
    ];
    if (best != null) {
      rows.add(
        _GymLeaderboardRowData(
          name: 'You',
          elapsed: best.elapsed,
          meta: 'Personal best',
          isUser: true,
        ),
      );
    }
    rows.sort((a, b) => a.elapsed.compareTo(b.elapsed));
    return rows;
  }
}

class _LiveChallengeLeaderboardSheet extends StatelessWidget {
  const _LiveChallengeLeaderboardSheet({
    required this.title,
    required this.personal,
    required this.gym,
    required this.global,
  });

  final String title;
  final ChallengePersonalLeaderboard personal;
  final ChallengeRankedLeaderboard gym;
  final ChallengeRankedLeaderboard global;

  static String _formatDurationSec(int sec) {
    final d = Duration(seconds: sec);
    final minutes = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final seconds = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    if (d.inHours > 0) return '${d.inHours}:$minutes:$seconds';
    return '$minutes:$seconds';
  }

  static String _displayName(ChallengeLeaderboardEntry entry) {
    if (entry.isCurrentUser) return 'You';
    final raw = entry.userId.trim();
    if (raw.isEmpty) return 'Member';
    if (raw.length <= 8) return raw;
    return '${raw.substring(0, 8)}…';
  }

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.9,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      builder: (context, controller) {
        return Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
          ),
          child: ListView(
            controller: controller,
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
            children: [
              Center(
                child: Container(
                  width: 44,
                  height: 5,
                  decoration: BoxDecoration(
                    color: const Color(0xFFE5E7EB),
                    borderRadius: BorderRadius.circular(999),
                  ),
                ),
              ),
              const SizedBox(height: 18),
              Text(
                '$title Leaderboard',
                style: GoogleFonts.poppins(
                  fontSize: 22,
                  fontWeight: FontWeight.w900,
                  color: const Color(0xFF111827),
                ),
              ),
              const SizedBox(height: 14),
              _LeaderboardSectionTitle(
                title: 'Personal',
                subtitle: '${personal.totalAttempts} attempts',
              ),
              const SizedBox(height: 10),
              if (personal.entries.isEmpty)
                Text(
                  'No completed attempts yet.',
                  style: GoogleFonts.poppins(
                    fontSize: 12,
                    color: const Color(0xFF6B7280),
                  ),
                )
              else
                ...personal.entries
                    .take(20)
                    .map(
                      (entry) => _LeaderboardRow(
                        rank: entry.rank,
                        name: _displayName(entry),
                        time: _formatDurationSec(entry.totalTimeSec),
                        meta: '${entry.totalPoints} pts',
                        highlight: entry.isCurrentUser || entry.isLatestAttempt,
                      ),
                    ),
              const SizedBox(height: 16),
              _LeaderboardSectionTitle(
                title: 'Gym',
                subtitle: 'Best valid attempt per member',
              ),
              const SizedBox(height: 10),
              if (gym.entries.isEmpty)
                Text(
                  'No gym results available yet.',
                  style: GoogleFonts.poppins(
                    fontSize: 12,
                    color: const Color(0xFF6B7280),
                  ),
                )
              else
                ...gym.entries
                    .take(20)
                    .map(
                      (entry) => _LeaderboardRow(
                        rank: entry.rank,
                        name: _displayName(entry),
                        time: _formatDurationSec(entry.totalTimeSec),
                        meta: '${entry.totalPoints} pts',
                        highlight: entry.isCurrentUser,
                      ),
                    ),
              const SizedBox(height: 16),
              _LeaderboardSectionTitle(
                title: 'Global',
                subtitle: 'Best valid attempt per member',
              ),
              const SizedBox(height: 10),
              if (global.entries.isEmpty)
                Text(
                  'No global results available yet.',
                  style: GoogleFonts.poppins(
                    fontSize: 12,
                    color: const Color(0xFF6B7280),
                  ),
                )
              else
                ...global.entries
                    .take(20)
                    .map(
                      (entry) => _LeaderboardRow(
                        rank: entry.rank,
                        name: _displayName(entry),
                        time: _formatDurationSec(entry.totalTimeSec),
                        meta: '${entry.totalPoints} pts',
                        highlight: entry.isCurrentUser,
                      ),
                    ),
            ],
          ),
        );
      },
    );
  }
}

class _GymLeaderboardRowData {
  const _GymLeaderboardRowData({
    required this.name,
    required this.elapsed,
    required this.meta,
    this.isUser = false,
  });

  final String name;
  final Duration elapsed;
  final String meta;
  final bool isUser;
}

class _PersonalBestPanel extends StatelessWidget {
  const _PersonalBestPanel({
    required this.challenge,
    required this.personalBest,
    required this.completedAttempts,
    required this.totalAttempts,
  });

  final _Challenge challenge;
  final _ChallengeAttempt? personalBest;
  final int completedAttempts;
  final int totalAttempts;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [challenge.accent, const Color(0xFF111827)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(22),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Personal Best',
                  style: GoogleFonts.poppins(
                    fontSize: 12,
                    color: Colors.white.withValues(alpha: 0.72),
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  personalBest == null
                      ? 'No completed attempt'
                      : _ChallengeLeaderboardSheet._formatDuration(
                          personalBest!.elapsed,
                        ),
                  style: GoogleFonts.robotoMono(
                    fontSize: 26,
                    fontWeight: FontWeight.w900,
                    color: Colors.white,
                  ),
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '$completedAttempts completed',
                style: GoogleFonts.poppins(
                  fontSize: 12,
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                ),
              ),
              Text(
                '$totalAttempts total attempts',
                style: GoogleFonts.poppins(
                  fontSize: 11,
                  color: Colors.white.withValues(alpha: 0.72),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _LeaderboardSectionTitle extends StatelessWidget {
  const _LeaderboardSectionTitle({required this.title, required this.subtitle});

  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: GoogleFonts.poppins(
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                  color: const Color(0xFF111827),
                ),
              ),
              Text(
                subtitle,
                style: GoogleFonts.poppins(
                  fontSize: 11,
                  color: const Color(0xFF9CA3AF),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _LeaderboardRow extends StatelessWidget {
  const _LeaderboardRow({
    required this.rank,
    required this.name,
    required this.time,
    required this.meta,
    required this.highlight,
  });

  final int rank;
  final String name;
  final String time;
  final String meta;
  final bool highlight;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: highlight ? const Color(0xFFECFDF5) : const Color(0xFFF9FAFB),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: highlight ? const Color(0xFF86EFAC) : const Color(0xFFE5E7EB),
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 30,
            height: 30,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: highlight ? const Color(0xFF16A34A) : Colors.white,
              shape: BoxShape.circle,
            ),
            child: Text(
              '$rank',
              style: GoogleFonts.poppins(
                fontSize: 12,
                fontWeight: FontWeight.w900,
                color: highlight ? Colors.white : const Color(0xFF111827),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  style: GoogleFonts.poppins(
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                    color: const Color(0xFF111827),
                  ),
                ),
                Text(
                  meta,
                  style: GoogleFonts.poppins(
                    fontSize: 11,
                    color: const Color(0xFF6B7280),
                  ),
                ),
              ],
            ),
          ),
          Text(
            time,
            style: GoogleFonts.robotoMono(
              fontSize: 14,
              fontWeight: FontWeight.w900,
              color: const Color(0xFF111827),
            ),
          ),
        ],
      ),
    );
  }
}

class _AttemptRow extends StatelessWidget {
  const _AttemptRow({required this.challenge, required this.attempt});

  final _Challenge challenge;
  final _ChallengeAttempt attempt;

  @override
  Widget build(BuildContext context) {
    final completed = attempt.isCompleted;
    final status = attempt.approvalStatus.toLowerCase();
    final statusLabel = completed
        ? status == 'approved'
              ? 'Approved'
              : 'Pending approval'
        : 'Partial';
    final statusBg = completed
        ? status == 'approved'
              ? const Color(0xFFDCFCE7)
              : const Color(0xFFFEF3C7)
        : const Color(0xFFFFEDD5);
    final statusFg = completed
        ? status == 'approved'
              ? const Color(0xFF15803D)
              : const Color(0xFF92400E)
        : const Color(0xFFC2410C);
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFF9FAFB),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: Row(
        children: [
          Icon(
            completed ? Icons.check_circle_rounded : Icons.flag_outlined,
            color: completed
                ? const Color(0xFF16A34A)
                : const Color(0xFFF59E0B),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  completed
                      ? 'Completed'
                      : '${attempt.repsCompleted}/${challenge.targetReps} ${challenge.unit}',
                  style: GoogleFonts.poppins(
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                    color: const Color(0xFF111827),
                  ),
                ),
                Text(
                  DateFormat('MMM d, h:mm a').format(attempt.recordedAt),
                  style: GoogleFonts.poppins(
                    fontSize: 11,
                    color: const Color(0xFF9CA3AF),
                  ),
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                _ChallengeLeaderboardSheet._formatDuration(attempt.elapsed),
                style: GoogleFonts.robotoMono(
                  fontSize: 13,
                  fontWeight: FontWeight.w900,
                  color: const Color(0xFF111827),
                ),
              ),
              const SizedBox(height: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: statusBg,
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  statusLabel,
                  style: GoogleFonts.poppins(
                    fontSize: 9,
                    fontWeight: FontWeight.w800,
                    color: statusFg,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _EmptyAttemptPanel extends StatelessWidget {
  const _EmptyAttemptPanel({required this.challenge});

  final _Challenge challenge;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: const Color(0xFFF9FAFB),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Text(
        'Start ${challenge.title} to record your first attempt.',
        style: GoogleFonts.poppins(
          fontSize: 12,
          color: const Color(0xFF6B7280),
        ),
      ),
    );
  }
}

class _WeekRow extends StatelessWidget {
  const _WeekRow({
    required this.icon,
    required this.iconBg,
    required this.iconColor,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final Color iconBg;
  final Color iconColor;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Row(
        children: [
          _IconBox(icon: icon, bg: iconBg, color: iconColor),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              label,
              style: GoogleFonts.poppins(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: const Color(0xFF374151),
              ),
            ),
          ),
          Text(
            value,
            style: GoogleFonts.poppins(
              fontSize: 14,
              fontWeight: FontWeight.w800,
              color: const Color(0xFF111827),
            ),
          ),
        ],
      ),
    );
  }
}

class _Divider extends StatelessWidget {
  const _Divider();

  @override
  Widget build(BuildContext context) {
    return const Divider(height: 1, color: Color(0xFFE5E7EB));
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Text(
      label,
      style: GoogleFonts.poppins(
        fontSize: 13,
        fontWeight: FontWeight.w700,
        color: const Color(0xFF6B7280),
      ),
    );
  }
}

class _ActivityRow extends StatelessWidget {
  const _ActivityRow({required this.attendance, required this.showTime});
  final GymAttendance attendance;
  final bool showTime;

  String get _duration {
    final out = attendance.checkedOut;
    if (out == null) return 'Active';
    final mins = out.difference(attendance.checkedIn).inMinutes;
    if (mins < 60) return '$mins min';
    final h = mins ~/ 60;
    final m = mins % 60;
    return m > 0 ? '${h}h ${m}m' : '${h}h';
  }

  /// Estimated calories: ~7 kcal/min (≈5 MET × 70 kg) for a gym session.
  /// Returns empty string while session is still active.
  String get _calories {
    final out = attendance.checkedOut;
    if (out == null) return '';
    final mins = out.difference(attendance.checkedIn).inMinutes;
    if (mins <= 0) return '';
    return '~${(mins * 7)} cal';
  }

  String get _timeLabel {
    if (showTime) return DateFormat('h:mm a').format(attendance.checkedIn);
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final d = attendance.checkedIn;
    final day = DateTime(d.year, d.month, d.day);
    if (day == today) return 'Today';
    return DateFormat('MMM d').format(d);
  }

  @override
  Widget build(BuildContext context) {
    final isActive = attendance.isActive;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 9),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: isActive
                  ? const Color(0xFFDCFCE7)
                  : const Color(0xFFF3F4F6),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              Icons.fitness_center_outlined,
              size: 18,
              color: isActive
                  ? const Color(0xFF16A34A)
                  : const Color(0xFF9CA3AF),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  attendance.gymName ?? 'Gym Session',
                  style: GoogleFonts.poppins(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: const Color(0xFF111827),
                  ),
                ),
                Text(
                  _timeLabel,
                  style: GoogleFonts.poppins(
                    fontSize: 11,
                    color: const Color(0xFF9CA3AF),
                  ),
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                _duration,
                style: GoogleFonts.poppins(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: isActive
                      ? const Color(0xFF16A34A)
                      : const Color(0xFF111827),
                ),
              ),
              if (_calories.isNotEmpty)
                Text(
                  _calories,
                  style: GoogleFonts.poppins(
                    fontSize: 11,
                    color: const Color(0xFF9CA3AF),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
