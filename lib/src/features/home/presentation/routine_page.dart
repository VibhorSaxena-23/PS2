import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/theme/app_colors.dart';
import '../../workout/data/local_plan_service.dart';
import '../../workout/data/workout_api.dart';
import '../../workout/models/workout_models.dart';
import '../../workout/presentation/active_workout_page.dart';
import '../../workout/presentation/workout_page.dart';

class RoutinePage extends StatefulWidget {
  const RoutinePage({super.key, this.workoutApi});

  final WorkoutApi? workoutApi;

  @override
  State<RoutinePage> createState() => _RoutinePageState();
}

class _RoutinePageState extends State<RoutinePage> {
  bool _loading = true;
  String? _error;
  TodayWorkout? _todayWorkout;

  @override
  void initState() {
    super.initState();
    _loadRoutine();
  }

  Future<void> _loadRoutine() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      TodayWorkout? workout;
      if (widget.workoutApi != null) {
        workout = await widget.workoutApi!.getTodayWorkout();
      } else {
        workout = await LocalPlanService.getTodayWorkout();
      }
      if (!mounted) {
        return;
      }
      setState(() {
        _todayWorkout = workout;
        _loading = false;
      });
    } catch (error) {
      try {
        final workout = await LocalPlanService.getTodayWorkout();
        if (!mounted) {
          return;
        }
        setState(() {
          _todayWorkout = workout;
          _loading = false;
        });
        return;
      } catch (_) {}
      if (!mounted) {
        return;
      }
      setState(() {
        _loading = false;
        _error = error.toString();
      });
    }
  }

  List<String> get _muscles {
    final workout = _todayWorkout;
    if (workout == null) {
      return const [];
    }

    final muscles = <String>{};
    for (final exercise in workout.exercises) {
      final muscle = exercise.primaryMuscle;
      if (muscle != null && muscle.isNotEmpty) {
        muscles.add(_titleCase(muscle));
      }
    }
    return muscles.toList();
  }

  String _titleCase(String value) {
    if (value.isEmpty) {
      return value;
    }
    return value
        .split(RegExp(r'[_\s]+'))
        .where((part) => part.isNotEmpty)
        .map((part) => '${part[0].toUpperCase()}${part.substring(1).toLowerCase()}')
        .join(' ');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.scaffoldBg,
      appBar: AppBar(
        backgroundColor: const Color(0xFF1E3A5F),
        surfaceTintColor: Colors.transparent,
        foregroundColor: Colors.white,
        title: Text(
          'Workout Routine',
          style: GoogleFonts.poppins(
            fontWeight: FontWeight.w700,
            color: Colors.white,
          ),
        ),
        elevation: 0,
      ),
      body: _buildBody(context),
    );
  }

  Widget _buildBody(BuildContext context) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_error != null) {
      return _RoutineMessageState(
        title: 'Could not load routine',
        message: _error!,
        actionLabel: 'Retry',
        onAction: _loadRoutine,
      );
    }

    if (_todayWorkout == null) {
      return _RoutineMessageState(
        title: 'No active workout plan',
        message: 'Set an active plan once and your live routine will appear here.',
        actionLabel: 'Open workout hub',
        onAction: () {
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => WorkoutPage(workoutApi: widget.workoutApi),
            ),
          );
        },
      );
    }

    final workout = _todayWorkout!;
    return RefreshIndicator(
      onRefresh: _loadRoutine,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [Color(0xFF1E3A5F), Color(0xFF2563EB)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.all(Radius.circular(24)),
            ),
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.white.withAlpha(30),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    'TODAY',
                    style: GoogleFonts.poppins(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  workout.dayLabel,
                  style: GoogleFonts.poppins(
                    fontSize: 26,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                  ),
                ),
                Text(
                  _muscles.isEmpty
                      ? (workout.planType.startsWith('custom:')
                          ? 'CUSTOM'
                          : workout.planType.toUpperCase())
                      : _muscles.join(' · '),
                  style: GoogleFonts.poppins(
                    fontSize: 13,
                    color: Colors.white.withAlpha(200),
                  ),
                ),
                const SizedBox(height: 20),
                Row(
                  children: [
                    _InfoChip(
                      icon: Icons.fitness_center_rounded,
                      label: '${workout.exercises.length} exercises',
                    ),
                    const SizedBox(width: 10),
                    _InfoChip(
                      icon: Icons.flag_rounded,
                      label: 'Day ${workout.dayNumber}/${workout.totalDays}',
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: () => Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => ActiveWorkoutPage(
                          workoutApi: widget.workoutApi,
                        ),
                      ),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.white,
                      foregroundColor: const Color(0xFF1E3A5F),
                      elevation: 0,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                      textStyle: GoogleFonts.poppins(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    icon: const Icon(Icons.play_arrow_rounded, size: 22),
                    label: const Text('Start Workout'),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withAlpha(8),
                  blurRadius: 10,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "Today's Exercises",
                  style: GoogleFonts.poppins(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 14),
                ...workout.exercises.asMap().entries.map(
                  (entry) {
                    final color = _exerciseColor(entry.key);
                    final exercise = entry.value;
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: Row(
                        children: [
                          Container(
                            width: 28,
                            height: 28,
                            decoration: BoxDecoration(
                              color: color.withAlpha(15),
                              shape: BoxShape.circle,
                            ),
                            child: Center(
                              child: Text(
                                '${entry.key + 1}',
                                style: GoogleFonts.poppins(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                  color: color,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  exercise.exerciseName,
                                  style: GoogleFonts.poppins(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                    color: AppColors.textPrimary,
                                  ),
                                ),
                                Text(
                                  exercise.primaryMuscle != null
                                      ? _titleCase(exercise.primaryMuscle!)
                                      : (exercise.equipment ?? 'Planned exercise'),
                                  style: GoogleFonts.poppins(
                                    fontSize: 11,
                                    color: AppColors.textMuted,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: color.withAlpha(15),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              'Exercise ${entry.key + 1}',
                              style: GoogleFonts.poppins(
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                                color: color,
                              ),
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withAlpha(8),
                  blurRadius: 10,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Plan Status',
                  style: GoogleFonts.poppins(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 14),
                _PlanStatusRow(
                  label: 'Plan type',
                  value: workout.planType.startsWith('custom:')
                      ? 'CUSTOM'
                      : workout.planType.toUpperCase(),
                ),
                const SizedBox(height: 10),
                _PlanStatusRow(
                  label: 'Completed sessions',
                  value: '${workout.completedSessions}',
                ),
                const SizedBox(height: 10),
                _PlanStatusRow(
                  label: 'Cycle progress',
                  value: '${workout.dayNumber} of ${workout.totalDays}',
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Color _exerciseColor(int index) {
    const palette = [
      Color(0xFF4F46E5),
      Color(0xFF7C3AED),
      Color(0xFFDC2626),
      Color(0xFF0891B2),
      Color(0xFF059669),
      Color(0xFFF59E0B),
    ];
    return palette[index % palette.length];
  }
}

class _InfoChip extends StatelessWidget {
  const _InfoChip({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white.withAlpha(25),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: Colors.white),
          const SizedBox(width: 6),
          Text(
            label,
            style: GoogleFonts.poppins(
              fontSize: 12,
              color: Colors.white,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}

class _PlanStatusRow extends StatelessWidget {
  const _PlanStatusRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Text(
            label,
            style: GoogleFonts.poppins(
              fontSize: 13,
              color: AppColors.textSecondary,
            ),
          ),
        ),
        Text(
          value,
          style: GoogleFonts.poppins(
            fontSize: 13,
            fontWeight: FontWeight.w700,
            color: AppColors.textPrimary,
          ),
        ),
      ],
    );
  }
}

class _RoutineMessageState extends StatelessWidget {
  const _RoutineMessageState({
    required this.title,
    required this.message,
    required this.actionLabel,
    required this.onAction,
  });

  final String title;
  final String message;
  final String actionLabel;
  final VoidCallback onAction;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              title,
              textAlign: TextAlign.center,
              style: GoogleFonts.poppins(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              message,
              textAlign: TextAlign.center,
              style: GoogleFonts.poppins(
                fontSize: 13,
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: onAction,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.btnDark,
                foregroundColor: Colors.white,
              ),
              child: Text(actionLabel),
            ),
          ],
        ),
      ),
    );
  }
}
