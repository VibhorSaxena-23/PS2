import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/utils/formatters.dart';
import '../data/local_plan_service.dart';
import '../data/workout_api.dart';
import '../models/workout_models.dart';
import 'active_workout_page.dart';
import 'exercise_progress_page.dart';
import 'session_detail_page.dart';

class WorkoutPage extends StatefulWidget {
  const WorkoutPage({super.key, this.workoutApi});

  final WorkoutApi? workoutApi;

  @override
  State<WorkoutPage> createState() => _WorkoutPageState();
}

class _WorkoutPageState extends State<WorkoutPage> {
  DateTime _selectedDate = DateTime.now();
  bool _loading = true;
  bool _loadingProgress = false;
  String? _error;
  int _loadGeneration = 0;

  UserAnalyticsSummary? _analytics;
  TodayWorkout? _todayWorkout;
  WorkoutSession? _selectedDaySession;
  Map<int, ExerciseAnalytics?> _exerciseAnalyticsById = const {};

  bool get _isTodaySelected => _isSameDay(_selectedDate, DateTime.now());

  @override
  void initState() {
    super.initState();
    _loadPageData();
  }

  Future<void> _loadPageData() async {
    final loadId = ++_loadGeneration;
    final api = widget.workoutApi;
    if (api == null) {
      if (!mounted || loadId != _loadGeneration) {
        return;
      }
      setState(() {
        _loading = false;
        _error = null;
        _analytics = null;
        _todayWorkout = null;
        _selectedDaySession = null;
        _exerciseAnalyticsById = const {};
        _loadingProgress = false;
      });
      return;
    }

    setState(() {
      _loading = true;
      _error = null;
      _loadingProgress = false;
    });

    final dateIso = _isoDate(_selectedDate);
    String? loadWarning;
    UserAnalyticsSummary? analytics;
    SessionHistoryPage? history;
    TodayWorkout? todayWorkout;

    String appendWarning(String? existing, String message) {
      return existing == null ? message : '$existing\n$message';
    }

    try {
      analytics = await api.getUserAnalytics();
    } catch (_) {
      loadWarning = appendWarning(
        loadWarning,
        'Summary is temporarily unavailable.',
      );
    }

    try {
      history = await api.getHistory(
        startDate: dateIso,
        endDate: dateIso,
        page: 1,
        pageSize: 10,
        completedOnly: false,
      );
    } catch (_) {
      loadWarning = appendWarning(
        loadWarning,
        'Logbook is temporarily unavailable.',
      );
    }

    if (_isTodaySelected) {
      try {
        todayWorkout = await api.getTodayWorkout();
      } catch (_) {
        try {
          todayWorkout = await LocalPlanService.getTodayWorkout(
            completedSessions:
                history?.items.where((s) => s.isCompleted).length ?? 0,
          );
        } catch (_) {
          loadWarning = appendWarning(
            loadWarning,
            'Today\'s plan is temporarily unavailable.',
          );
        }
      }
    }

    final latestSession = history?.items.isNotEmpty == true
        ? history!.items.first
        : null;

    if (!mounted || loadId != _loadGeneration) {
      return;
    }

    setState(() {
      _analytics = analytics;
      _selectedDaySession = latestSession;
      _todayWorkout = todayWorkout;
      _exerciseAnalyticsById = const {};
      _loading = false;
      _loadingProgress =
          todayWorkout != null && todayWorkout.exercises.isNotEmpty;
      _error = loadWarning;
    });

    if (todayWorkout != null && todayWorkout.exercises.isNotEmpty) {
      final analyticsMap = await _loadExerciseAnalytics(todayWorkout.exercises);
      if (!mounted || loadId != _loadGeneration) {
        return;
      }
      setState(() {
        _exerciseAnalyticsById = analyticsMap;
        _loadingProgress = false;
      });
    }
  }

  Future<Map<int, ExerciseAnalytics?>> _loadExerciseAnalytics(
    List<PlanExercise> exercises,
  ) async {
    final api = widget.workoutApi!;
    final tasks = exercises.map((exercise) async {
      if (exercise.id <= 0) {
        return MapEntry<int, ExerciseAnalytics?>(exercise.id, null);
      }
      try {
        final data = await api.getExerciseAnalytics(exercise.id);
        return MapEntry<int, ExerciseAnalytics?>(exercise.id, data);
      } catch (_) {
        return MapEntry<int, ExerciseAnalytics?>(exercise.id, null);
      }
    });
    return Map<int, ExerciseAnalytics?>.fromEntries(await Future.wait(tasks));
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime.now().subtract(const Duration(days: 365)),
      lastDate: DateTime.now().add(const Duration(days: 7)),
    );
    if (picked == null || _isSameDay(picked, _selectedDate)) {
      return;
    }
    setState(() => _selectedDate = picked);
    _loadPageData();
  }

  Future<void> _choosePlanType() async {
    final selected = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: Colors.white,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
      ),
      builder: (ctx) => _PlanPickerSheet(
        currentPlanType: _todayWorkout?.planType,
        onCustomPlan: (planTypeString) {
          Navigator.of(ctx).pop(planTypeString);
        },
      ),
    );

    if (selected == null) return;

    TodayWorkout? optimisticWorkout;
    try {
      await LocalPlanService.setPlanType(selected);
      optimisticWorkout = await LocalPlanService.getTodayWorkout();
      if (widget.workoutApi != null) {
        await widget.workoutApi!.setActivePlan(selected);
      }
    } catch (_) {}
    if (!mounted) return;

    if (optimisticWorkout != null) {
      setState(() {
        _todayWorkout = optimisticWorkout;
        _error = null;
        _loadingProgress = optimisticWorkout!.exercises.isNotEmpty;
      });
    }

    final label = selected.startsWith('custom:')
        ? 'Custom'
        : selected.toUpperCase();
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text('Active plan set to $label')));
    _loadPageData();
  }

  Future<void> _openWorkoutLogger() async {
    // If there's an existing in-progress session for today, resume it
    // instead of creating a brand new empty session.
    final session = _selectedDaySession;
    final existingToResume = (session != null && !session.isCompleted)
        ? session
        : null;

    final completed = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => ActiveWorkoutPage(
          workoutApi: widget.workoutApi,
          existingSession: existingToResume,
        ),
      ),
    );
    if (completed == true && mounted) {
      _loadPageData();
    }
  }

  Future<void> _openSessionDetail() async {
    final session = _selectedDaySession;
    if (session == null) {
      return;
    }
    final deleted = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) =>
            SessionDetailPage(session: session, workoutApi: widget.workoutApi),
      ),
    );
    if (deleted == true && mounted) {
      _loadPageData();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.scaffoldBg,
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFFF6FAF9), AppColors.scaffoldBg],
          ),
        ),
        child: SafeArea(
          child: _loading
              ? const Center(child: CircularProgressIndicator())
              : RefreshIndicator(
                  onRefresh: _loadPageData,
                  child: ListView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
                    children: [
                      if (_error != null) ...[
                        _LoadWarning(message: _error!),
                        const SizedBox(height: 14),
                      ],
                      _buildHeader(),
                      const SizedBox(height: 14),
                      _buildStatusAndPlan(),
                      const SizedBox(height: 14),
                      _buildExerciseProgress(),
                      const SizedBox(height: 14),
                      _buildWorkoutStatusLogbook(),
                    ],
                  ),
                ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    final totalSessions = _analytics?.totalSessions ?? 0;
    final completedSessions = _analytics?.completedSessions ?? 0;
    final volume = _analytics?.totalVolume ?? 0;

    return _FrameCard(
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Summary',
                  style: GoogleFonts.poppins(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  Formatters.date(_selectedDate),
                  style: GoogleFonts.poppins(
                    fontSize: 13,
                    color: AppColors.textSecondary,
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  '$completedSessions / $totalSessions sessions completed',
                  style: GoogleFonts.poppins(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '${volume.toStringAsFixed(0)} kg total volume tracked',
                  style: GoogleFonts.poppins(
                    fontSize: 12,
                    color: AppColors.textMuted,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            onPressed: _pickDate,
            icon: Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.divider),
                color: Colors.white,
              ),
              child: const Icon(
                Icons.calendar_month_rounded,
                color: AppColors.textPrimary,
              ),
            ),
            tooltip: 'Pick date',
          ),
        ],
      ),
    );
  }

  Widget _buildStatusAndPlan() {
    final session = _selectedDaySession;
    final hasSession = session != null;
    final isFinished = hasSession && session.isCompleted;

    final statusTitle = isFinished
        ? 'Finished'
        : hasSession
        ? 'Record In Progress'
        : 'Record Today\'s Workout';
    final statusText = isFinished
        ? 'You completed a workout for this date.'
        : hasSession
        ? 'Session exists for this date. Keep tracking your sets.'
        : 'No session logged yet. Start recording now.';

    return _FrameCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              color: isFinished
                  ? AppColors.accentGreenSoft
                  : const Color(0xFFF3F4F6),
              border: Border.all(
                color: isFinished ? AppColors.accentGreen : AppColors.divider,
              ),
            ),
            child: Row(
              children: [
                Icon(
                  isFinished
                      ? Icons.check_circle_rounded
                      : Icons.edit_note_rounded,
                  color: isFinished
                      ? AppColors.accentGreen
                      : AppColors.textSecondary,
                  size: 18,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        statusTitle,
                        style: GoogleFonts.poppins(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      Text(
                        statusText,
                        style: GoogleFonts.poppins(
                          fontSize: 11,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
                if (_isTodaySelected)
                  TextButton(
                    onPressed: widget.workoutApi == null
                        ? null
                        : _openWorkoutLogger,
                    child: Text(
                      hasSession ? 'Update' : 'Record',
                      style: GoogleFonts.poppins(
                        fontWeight: FontWeight.w700,
                        color: AppColors.btnDark,
                      ),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          _buildTodayPlanCard(),
        ],
      ),
    );
  }

  Widget _buildTodayPlanCard() {
    final workout = _todayWorkout;

    if (!_isTodaySelected) {
      return const _SimpleEmpty(
        title: 'Today\'s Plan',
        body: 'Plan view is available when today\'s date is selected.',
      );
    }

    if (workout == null) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.divider),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Today\'s Plan',
              style: GoogleFonts.poppins(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'No active plan yet. Choose a preset or create your own.',
              style: GoogleFonts.poppins(
                fontSize: 12,
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Once selected, the plan stays active until you change it.',
              style: GoogleFonts.poppins(
                fontSize: 12,
                color: AppColors.textMuted,
              ),
            ),
            const SizedBox(height: 10),
            OutlinedButton(
              onPressed: _choosePlanType,
              style: OutlinedButton.styleFrom(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              child: const Text('Set Active Plan'),
            ),
          ],
        ),
      );
    }

    final planLabel = workout.planType.startsWith('custom:')
        ? 'Custom'
        : workout.planType.toUpperCase();

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.divider),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Today\'s Plan: ${workout.dayLabel.toUpperCase()}',
                      style: GoogleFonts.poppins(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    Text(
                      'Day ${workout.dayNumber}/${workout.totalDays}  •  $planLabel',
                      style: GoogleFonts.poppins(
                        fontSize: 11,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              if (widget.workoutApi != null)
                _ChangePlanButton(onTap: _choosePlanType),
            ],
          ),
          const SizedBox(height: 8),
          SizedBox(
            height: 84,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: workout.exercises.length,
              separatorBuilder: (_, _) => const SizedBox(width: 10),
              itemBuilder: (context, index) {
                final exercise = workout.exercises[index];
                return Container(
                  width: 112,
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppColors.divider),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        exercise.exerciseName,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.poppins(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textPrimary,
                          height: 1.3,
                        ),
                      ),
                      const Spacer(),
                      Text(
                        exercise.primaryMuscle ?? 'Exercise',
                        style: GoogleFonts.poppins(
                          fontSize: 10,
                          color: AppColors.textMuted,
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildExerciseProgress() {
    final exercises = _todayWorkout?.exercises ?? const <PlanExercise>[];
    return _FrameCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Exercise Progress',
            style: GoogleFonts.poppins(
              fontSize: 15,
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Tap an exercise to see past performance and graph.',
            style: GoogleFonts.poppins(
              fontSize: 12,
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: 10),
          if (_loadingProgress) const LinearProgressIndicator(minHeight: 2),
          if (!_loadingProgress && exercises.isEmpty)
            const _SimpleEmpty(
              title: 'No exercises available',
              body: 'Set an active plan to load exercise progress chips.',
            ),
          if (!_loadingProgress && exercises.isNotEmpty)
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: exercises.map((exercise) {
                final analytics = _exerciseAnalyticsById[exercise.id];
                final pb = analytics != null && analytics.totalSessions > 0
                    ? '${analytics.personalBestWeight.toStringAsFixed(1)} kg PB'
                    : 'No PB yet';
                return InkWell(
                  borderRadius: BorderRadius.circular(999),
                  onTap: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => ExerciseProgressPage(
                          exerciseId: exercise.id,
                          exerciseName: exercise.exerciseName,
                          muscle: exercise.primaryMuscle,
                          workoutApi: widget.workoutApi,
                        ),
                      ),
                    );
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 9,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFFEEF2FF),
                      borderRadius: BorderRadius.circular(999),
                      border: Border.all(color: const Color(0xFFC7D2FE)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          exercise.exerciseName,
                          style: GoogleFonts.poppins(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          pb,
                          style: GoogleFonts.poppins(
                            fontSize: 10,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }).toList(),
            ),
        ],
      ),
    );
  }

  Widget _buildWorkoutStatusLogbook() {
    final session = _selectedDaySession;
    return _FrameCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  _isTodaySelected
                      ? 'Today\'s Workout Status'
                      : 'Workout Status',
                  style: GoogleFonts.poppins(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                ),
              ),
              if (session != null)
                TextButton(
                  onPressed: _openSessionDetail,
                  child: const Text('View'),
                ),
            ],
          ),
          const SizedBox(height: 8),
          if (session == null)
            const _SimpleEmpty(
              title: 'No logbook entries',
              body: 'Once a session is recorded, sets and reps show here.',
            ),
          if (session != null)
            ...session.exercises.map((exercise) {
              return Container(
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 10,
                ),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.divider),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        exercise.exerciseName,
                        style: GoogleFonts.poppins(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textPrimary,
                        ),
                      ),
                    ),
                    Text(
                      _setsRepSummary(exercise),
                      style: GoogleFonts.poppins(
                        fontSize: 12,
                        color: AppColors.textSecondary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              );
            }),
        ],
      ),
    );
  }

  String _setsRepSummary(SessionExercise exercise) {
    final sourceSets = exercise.sets.where((set) => set.isCompleted).toList();
    final effectiveSets = sourceSets.isNotEmpty ? sourceSets : exercise.sets;
    final setCount = effectiveSets.length;
    if (setCount == 0) {
      return 'No sets';
    }
    final reps = effectiveSets.fold<int>(
      0,
      (maxReps, set) => math.max(maxReps, set.reps ?? 0),
    );
    if (reps <= 0) {
      return '$setCount sets';
    }
    return '$setCount sets $reps reps';
  }

  static bool _isSameDay(DateTime first, DateTime second) {
    return first.year == second.year &&
        first.month == second.month &&
        first.day == second.day;
  }

  static String _isoDate(DateTime date) {
    final y = date.year.toString().padLeft(4, '0');
    final m = date.month.toString().padLeft(2, '0');
    final d = date.day.toString().padLeft(2, '0');
    return '$y-$m-$d';
  }
}

class _FrameCard extends StatelessWidget {
  const _FrameCard({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFFCFCFC),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: AppColors.textSecondary.withAlpha(80),
          width: 1.3,
        ),
      ),
      child: child,
    );
  }
}

class _SimpleEmpty extends StatelessWidget {
  const _SimpleEmpty({required this.title, required this.body});

  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        color: const Color(0xFFF8FAFC),
        border: Border.all(color: AppColors.divider),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: GoogleFonts.poppins(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            body,
            style: GoogleFonts.poppins(
              fontSize: 12,
              color: AppColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}

// ── Change plan button ────────────────────────────────────────────────────────

class _LoadWarning extends StatelessWidget {
  const _LoadWarning({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFFFFBEB),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFFDE68A)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(
            Icons.info_outline_rounded,
            size: 18,
            color: Color(0xFFD97706),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              message,
              style: GoogleFonts.poppins(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: const Color(0xFF92400E),
                height: 1.35,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ChangePlanButton extends StatelessWidget {
  const _ChangePlanButton({required this.onTap});
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: const Color(0xFFEEF2FF),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: const Color(0xFFC7D2FE)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.swap_horiz_rounded,
              size: 16,
              color: AppColors.accent,
            ),
            const SizedBox(width: 4),
            Text(
              'Change',
              style: GoogleFonts.poppins(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: AppColors.accent,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Plan picker bottom sheet ─────────────────────────────────────────────────

class _PlanPickerSheet extends StatefulWidget {
  const _PlanPickerSheet({this.currentPlanType, required this.onCustomPlan});
  final String? currentPlanType;
  final ValueChanged<String> onCustomPlan;

  @override
  State<_PlanPickerSheet> createState() => _PlanPickerSheetState();
}

class _PlanPickerSheetState extends State<_PlanPickerSheet> {
  bool _showCustomBuilder = false;

  // Custom plan builder state
  final List<_CustomDay> _days = [_CustomDay(label: 'Day 1', muscles: [])];

  static const _allMuscles = [
    'Chest',
    'Back',
    'Shoulders',
    'Biceps',
    'Triceps',
    'Legs',
    'Hamstrings',
    'Glutes',
    'Calves',
    'Core',
  ];

  void _addDay() {
    setState(() {
      _days.add(_CustomDay(label: 'Day ${_days.length + 1}', muscles: []));
    });
  }

  void _removeDay(int index) {
    if (_days.length <= 1) return;
    setState(() => _days.removeAt(index));
  }

  void _toggleMuscle(int dayIndex, String muscle) {
    setState(() {
      final day = _days[dayIndex];
      if (day.muscles.contains(muscle)) {
        day.muscles.remove(muscle);
      } else {
        day.muscles.add(muscle);
      }
    });
  }

  bool get _isCustomValid => _days.every((d) => d.muscles.isNotEmpty);

  void _submitCustom() {
    if (!_isCustomValid) return;
    final payload = _days
        .map((day) => {'label': day.label, 'muscles': day.muscles})
        .toList();
    widget.onCustomPlan('custom:${jsonEncode(payload)}');
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(
        16,
        16,
        16,
        MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      child: _showCustomBuilder ? _buildCustomBuilder() : _buildPresetList(),
    );
  }

  Widget _buildPresetList() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Center(
          child: Container(
            width: 36,
            height: 4,
            decoration: BoxDecoration(
              color: AppColors.divider,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
        ),
        const SizedBox(height: 14),
        Text(
          'Choose Workout Plan',
          style: GoogleFonts.poppins(
            fontSize: 17,
            fontWeight: FontWeight.w700,
            color: AppColors.textPrimary,
          ),
        ),
        const SizedBox(height: 12),
        _PresetPlanTile(
          title: 'PPL',
          subtitle: 'Push / Pull / Legs  •  6 days',
          isActive: widget.currentPlanType == 'ppl',
          onTap: () => Navigator.of(context).pop('ppl'),
        ),
        const SizedBox(height: 8),
        _PresetPlanTile(
          title: 'Bro Split',
          subtitle: 'One muscle group per day  •  5 days',
          isActive: widget.currentPlanType == 'bro',
          onTap: () => Navigator.of(context).pop('bro'),
        ),
        const SizedBox(height: 8),
        _PresetPlanTile(
          title: 'Full Body',
          subtitle: 'All major muscles each session  •  3 days',
          isActive: widget.currentPlanType == 'full_body',
          onTap: () => Navigator.of(context).pop('full_body'),
        ),
        const SizedBox(height: 12),
        SizedBox(
          width: double.infinity,
          child: OutlinedButton.icon(
            onPressed: () => setState(() => _showCustomBuilder = true),
            icon: const Icon(Icons.tune_rounded, size: 18),
            label: Text(
              'Build Custom Plan',
              style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
            ),
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              side: const BorderSide(color: AppColors.accent),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildCustomBuilder() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            GestureDetector(
              onTap: () => setState(() => _showCustomBuilder = false),
              child: const Icon(Icons.arrow_back_rounded, size: 22),
            ),
            const SizedBox(width: 10),
            Text(
              'Custom Plan',
              style: GoogleFonts.poppins(
                fontSize: 17,
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary,
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          'Pick muscle groups for each training day.',
          style: GoogleFonts.poppins(
            fontSize: 12,
            color: AppColors.textSecondary,
          ),
        ),
        const SizedBox(height: 12),
        ConstrainedBox(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(context).size.height * 0.45,
          ),
          child: ListView.separated(
            shrinkWrap: true,
            itemCount: _days.length,
            separatorBuilder: (_, _) => const SizedBox(height: 10),
            itemBuilder: (context, i) {
              final day = _days[i];
              return Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: day.muscles.isEmpty
                        ? AppColors.error.withAlpha(120)
                        : AppColors.divider,
                  ),
                  color: const Color(0xFFF8FAFC),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            day.label,
                            style: GoogleFonts.poppins(
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              color: AppColors.textPrimary,
                            ),
                          ),
                        ),
                        if (_days.length > 1)
                          GestureDetector(
                            onTap: () => _removeDay(i),
                            child: const Icon(
                              Icons.close_rounded,
                              size: 18,
                              color: AppColors.textMuted,
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: _allMuscles.map((muscle) {
                        final selected = day.muscles.contains(muscle);
                        return GestureDetector(
                          onTap: () => _toggleMuscle(i, muscle),
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 5,
                            ),
                            decoration: BoxDecoration(
                              color: selected ? AppColors.accent : Colors.white,
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(
                                color: selected
                                    ? AppColors.accent
                                    : AppColors.inputBorder,
                              ),
                            ),
                            child: Text(
                              muscle,
                              style: GoogleFonts.poppins(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: selected
                                    ? Colors.white
                                    : AppColors.textSecondary,
                              ),
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: _addDay,
                icon: const Icon(Icons.add_rounded, size: 18),
                label: Text(
                  'Add Day',
                  style: GoogleFonts.poppins(
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                  ),
                ),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: ElevatedButton(
                onPressed: _isCustomValid ? _submitCustom : null,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.accent,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                child: Text(
                  'Save Plan',
                  style: GoogleFonts.poppins(
                    fontWeight: FontWeight.w700,
                    fontSize: 13,
                  ),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _CustomDay {
  _CustomDay({required this.label, required this.muscles});
  final String label;
  final List<String> muscles;
}

// ── Preset plan tile ─────────────────────────────────────────────────────────

class _PresetPlanTile extends StatelessWidget {
  const _PresetPlanTile({
    required this.title,
    required this.subtitle,
    required this.isActive,
    required this.onTap,
  });

  final String title;
  final String subtitle;
  final bool isActive;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isActive ? AppColors.accent : AppColors.divider,
            width: isActive ? 1.5 : 1,
          ),
          color: isActive ? const Color(0xFFEEF2FF) : Colors.white,
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: GoogleFonts.poppins(
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  Text(
                    subtitle,
                    style: GoogleFonts.poppins(
                      fontSize: 12,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
            if (isActive)
              const Icon(
                Icons.check_circle_rounded,
                color: AppColors.accent,
                size: 22,
              )
            else
              const Icon(
                Icons.chevron_right_rounded,
                color: AppColors.textMuted,
              ),
          ],
        ),
      ),
    );
  }
}
