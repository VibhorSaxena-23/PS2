import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/utils/formatters.dart';
import '../data/workout_api.dart';
import '../models/workout_models.dart';

/// Displays all exercises and sets for a completed (or in-progress) session.
/// When [workoutApi] is provided, the delete action is enabled.
class SessionDetailPage extends StatefulWidget {
  const SessionDetailPage({
    super.key,
    required this.session,
    this.workoutApi,
  });

  final WorkoutSession session;
  final WorkoutApi? workoutApi;

  @override
  State<SessionDetailPage> createState() => _SessionDetailPageState();
}

class _SessionDetailPageState extends State<SessionDetailPage> {
  bool _deleting = false;

  String _fmtDuration(int seconds) {
    final m = seconds ~/ 60;
    if (m < 60) return '${m}m';
    return '${m ~/ 60}h ${m % 60}m';
  }

  Future<void> _confirmDelete() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(
          'Delete Session?',
          style: GoogleFonts.poppins(
              fontWeight: FontWeight.w700, color: AppColors.textPrimary),
        ),
        content: Text(
          'This will permanently delete the workout and all its sets. This cannot be undone.',
          style: GoogleFonts.poppins(
              fontSize: 14, color: AppColors.textSecondary, height: 1.5),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text('Cancel',
                style: GoogleFonts.poppins(color: AppColors.textSecondary)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.error,
              foregroundColor: Colors.white,
              elevation: 0,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
            ),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text('Delete',
                style:
                    GoogleFonts.poppins(fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    setState(() => _deleting = true);
    try {
      await widget.workoutApi!.deleteSession(widget.session.id);
      if (mounted) Navigator.of(context).pop(true); // true = deleted
    } catch (e) {
      if (mounted) {
        setState(() => _deleting = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to delete: $e',
                style: GoogleFonts.poppins(fontSize: 13)),
            behavior: SnackBarBehavior.floating,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final title = widget.session.title?.trim().isNotEmpty == true
        ? widget.session.title!
        : 'Workout Session';

    return Scaffold(
      backgroundColor: AppColors.scaffoldBg,
      appBar: AppBar(
        backgroundColor: AppColors.btnDark,
        surfaceTintColor: Colors.transparent,
        foregroundColor: Colors.white,
        title: Text(title,
            style: GoogleFonts.poppins(
                fontWeight: FontWeight.w700, color: Colors.white)),
        elevation: 0,
        actions: [
          if (widget.workoutApi != null)
            _deleting
                ? const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 16),
                    child: SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white),
                    ),
                  )
                : IconButton(
                    icon: const Icon(Icons.delete_outline_rounded,
                        color: Colors.white),
                    tooltip: 'Delete session',
                    onPressed: _confirmDelete,
                  ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // ── Summary header ──────────────────────────────────────────
          Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [Color(0xFF1A1A2E), Color(0xFF16213E)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.all(Radius.circular(20)),
            ),
            padding: const EdgeInsets.all(20),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    _SummaryItem(
                      label: 'Date',
                      value: Formatters.date(widget.session.startedAt),
                    ),
                    if (widget.session.durationSec != null)
                      _SummaryItem(
                        label: 'Duration',
                        value: _fmtDuration(widget.session.durationSec!),
                      ),
                    _SummaryItem(
                      label: 'Volume',
                      value:
                          '${widget.session.totalVolume.toStringAsFixed(0)} kg',
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    _SummaryItem(
                      label: 'Exercises',
                      value: '${widget.session.exercises.length}',
                    ),
                    _SummaryItem(
                      label: 'Sets',
                      value:
                          '${widget.session.exercises.fold<int>(0, (s, e) => s + e.sets.length)}',
                    ),
                    _SummaryItem(
                      label: 'Status',
                      value: widget.session.isCompleted ? 'Done' : 'In progress',
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // ── Exercise blocks ─────────────────────────────────────────
          ...widget.session.exercises.map(
            (ex) => _ExerciseBlock(exercise: ex),
          ),
        ],
      ),
    );
  }
}

class _SummaryItem extends StatelessWidget {
  const _SummaryItem({required this.label, required this.value});
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(value,
            style: GoogleFonts.poppins(
                fontSize: 16,
                fontWeight: FontWeight.w800,
                color: Colors.white)),
        Text(label,
            style: GoogleFonts.poppins(
                fontSize: 11, color: Colors.white.withAlpha(180))),
      ],
    );
  }
}

class _ExerciseBlock extends StatelessWidget {
  const _ExerciseBlock({required this.exercise});
  final SessionExercise exercise;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(8),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Exercise name
          Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: AppColors.accent.withAlpha(20),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.fitness_center_rounded,
                    size: 18, color: AppColors.accent),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(exercise.exerciseName,
                        style: GoogleFonts.poppins(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: AppColors.textPrimary)),
                    if (exercise.primaryMuscle != null)
                      Text(exercise.primaryMuscle!,
                          style: GoogleFonts.poppins(
                              fontSize: 11, color: AppColors.textMuted)),
                  ],
                ),
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: AppColors.accentGreenSoft,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  '${exercise.maxWeight.toStringAsFixed(1)} kg max',
                  style: GoogleFonts.poppins(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: AppColors.accentGreen),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),

          // Column headers
          Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: Row(
              children: [
                SizedBox(
                    width: 36,
                    child: Text('SET',
                        style: GoogleFonts.poppins(
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                            color: AppColors.textMuted))),
                Expanded(
                    child: Text('KG',
                        style: GoogleFonts.poppins(
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                            color: AppColors.textMuted))),
                SizedBox(
                    width: 60,
                    child: Text('REPS',
                        style: GoogleFonts.poppins(
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                            color: AppColors.textMuted))),
                const SizedBox(width: 24),
              ],
            ),
          ),

          // Set rows
          ...exercise.sets.map(
            (s) => Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Row(
                children: [
                  SizedBox(
                    width: 36,
                    child: Container(
                      width: 22,
                      height: 22,
                      decoration: BoxDecoration(
                        color: s.isCompleted
                            ? AppColors.accentGreen
                            : AppColors.divider,
                        shape: BoxShape.circle,
                      ),
                      child: Center(
                        child: Text('${s.setNumber}',
                            style: GoogleFonts.poppins(
                                fontSize: 10,
                                fontWeight: FontWeight.w700,
                                color: s.isCompleted
                                    ? Colors.white
                                    : AppColors.textMuted)),
                      ),
                    ),
                  ),
                  Expanded(
                    child: Text(
                      s.weightKg != null
                          ? s.weightKg!.toStringAsFixed(1)
                          : '—',
                      style: GoogleFonts.poppins(
                          fontSize: 13, color: AppColors.textPrimary),
                    ),
                  ),
                  SizedBox(
                    width: 60,
                    child: Text(
                      s.reps != null ? s.reps.toString() : '—',
                      style: GoogleFonts.poppins(
                          fontSize: 13, color: AppColors.textPrimary),
                    ),
                  ),
                  SizedBox(
                    width: 24,
                    child: s.isCompleted
                        ? const Icon(Icons.check_circle_rounded,
                            size: 16, color: AppColors.accentGreen)
                        : const Icon(Icons.circle_outlined,
                            size: 16, color: AppColors.divider),
                  ),
                ],
              ),
            ),
          ),

          if (exercise.notes != null && exercise.notes!.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text('Note: ${exercise.notes!}',
                style: GoogleFonts.poppins(
                    fontSize: 11,
                    fontStyle: FontStyle.italic,
                    color: AppColors.textMuted)),
          ],
        ],
      ),
    );
  }
}
