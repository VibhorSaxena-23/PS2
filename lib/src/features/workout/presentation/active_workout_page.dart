import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/theme/app_colors.dart';
import '../data/workout_api.dart';
import '../models/workout_models.dart';
import 'exercise_picker_page.dart';

// ── Local data models ─────────────────────────────────────────────────────────

class _LoggedSet {
  _LoggedSet() {
    weightCtrl = TextEditingController();
    repsCtrl = TextEditingController();
  }

  late final TextEditingController weightCtrl;
  late final TextEditingController repsCtrl;
  bool isDone = false;

  void dispose() {
    weightCtrl.dispose();
    repsCtrl.dispose();
  }
}

class _LoggedExercise {
  _LoggedExercise({required this.id, required this.name, required this.muscle})
    : sets = [_LoggedSet()];

  final int id;
  final String name;
  final String muscle;
  final List<_LoggedSet> sets;
}

// ── Page ─────────────────────────────────────────────────────────────────────

/// Hevy-style live workout logger.
/// When [workoutApi] is provided, creates and finishes session via API on completion.
/// Pass [existingSession] to resume an in-progress session instead of creating a new one.
class ActiveWorkoutPage extends StatefulWidget {
  const ActiveWorkoutPage({super.key, this.workoutApi, this.existingSession});

  final WorkoutApi? workoutApi;

  /// An existing in-progress session to resume. When non-null the page
  /// restores its exercises from this session and skips creating a new one.
  final WorkoutSession? existingSession;

  @override
  State<ActiveWorkoutPage> createState() => _ActiveWorkoutPageState();
}

class _ActiveWorkoutPageState extends State<ActiveWorkoutPage> {
  late final TextEditingController _titleCtrl;
  final _stopwatch = Stopwatch()..start();
  late final Timer _timerTick;
  final _exercises = <_LoggedExercise>[];
  final Map<int, SessionExercise?> _previousExerciseMap = {};
  bool _saving = false;
  bool _syncing = false;
  // Stores session ID if createSession succeeded but finishSession failed,
  // so a retry finishes the existing session rather than creating a new one.
  String? _pendingSessionId;
  Timer? _syncDebounce;

  @override
  void initState() {
    super.initState();
    final existing = widget.existingSession;
    if (existing != null) {
      // Resume: restore session ID, title and all previously logged exercises
      _pendingSessionId = existing.id;
      _titleCtrl = TextEditingController(text: existing.title ?? 'New Workout');
      _restoreFromSession(existing);
    } else {
      _titleCtrl = TextEditingController(text: 'New Workout');
    }
    _titleCtrl.addListener(_queuePersist);
    _timerTick = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  /// Restores in-memory exercise list from a persisted [WorkoutSession].
  void _restoreFromSession(WorkoutSession session) {
    for (final ex in session.exercises) {
      final logged = _LoggedExercise(
        id: ex.exerciseId,
        name: ex.exerciseName,
        muscle: ex.primaryMuscle ?? '',
      );
      // Replace the default single empty set with the persisted ones
      logged.sets.clear();
      for (final s in ex.sets) {
        final loggedSet = _LoggedSet();
        if (s.weightKg != null) {
          loggedSet.weightCtrl.text = s.weightKg! % 1 == 0
              ? s.weightKg!.toInt().toString()
              : s.weightKg!.toString();
        }
        if (s.reps != null) loggedSet.repsCtrl.text = s.reps.toString();
        loggedSet.isDone = s.isCompleted;
        logged.sets.add(loggedSet);
      }
      // Ensure at least one set row
      if (logged.sets.isEmpty) logged.sets.add(_LoggedSet());
      _exercises.add(logged);
      // Pre-cache previous performance lookup
      _previousExerciseMap[ex.exerciseId] = ex;
    }
  }

  @override
  void dispose() {
    _syncDebounce?.cancel();
    _timerTick.cancel();
    _stopwatch.stop();
    _titleCtrl.dispose();
    for (final ex in _exercises) {
      for (final s in ex.sets) {
        s.dispose();
      }
    }
    super.dispose();
  }

  String get _elapsedDisplay {
    final e = _stopwatch.elapsed;
    final h = e.inHours;
    final m = e.inMinutes.remainder(60);
    final s = e.inSeconds.remainder(60);
    if (h > 0) {
      return '${h.toString().padLeft(2, '0')}:'
          '${m.toString().padLeft(2, '0')}:'
          '${s.toString().padLeft(2, '0')}';
    }
    return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }

  Future<void> _ensureSessionCreated() async {
    if (widget.workoutApi == null || _pendingSessionId != null) {
      return;
    }

    try {
      final session = await widget.workoutApi!.createSession(
        _buildCreateRequest(),
      );
      _pendingSessionId = session.id;
    } catch (error) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not create workout draft: $error')),
      );
    }
  }

  void _queuePersist() {
    if (widget.workoutApi == null || _saving) {
      return;
    }
    if (_exercises.isEmpty && _pendingSessionId == null) {
      return;
    }

    _syncDebounce?.cancel();
    _syncDebounce = Timer(const Duration(milliseconds: 500), _persistDraft);
  }

  Future<void> _persistDraft() async {
    if (widget.workoutApi == null || _saving || _syncing) {
      return;
    }
    if (_exercises.isEmpty && _pendingSessionId == null) {
      return;
    }

    await _ensureSessionCreated();
    final sessionId = _pendingSessionId;
    if (sessionId == null) {
      return;
    }

    if (mounted) {
      setState(() => _syncing = true);
    }

    try {
      await widget.workoutApi!.updateSession(
        sessionId,
        UpdateSessionRequest(
          title: _titleCtrl.text.trim().isNotEmpty
              ? _titleCtrl.text.trim()
              : null,
          exercises: _buildExerciseRequests(),
        ),
      );
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not sync workout changes: $error')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _syncing = false);
      }
    }
  }

  Future<void> _loadPreviousPerformance(int exerciseId) async {
    if (widget.workoutApi == null ||
        _previousExerciseMap.containsKey(exerciseId)) {
      return;
    }

    try {
      final history = await widget.workoutApi!.getHistory(
        exerciseId: exerciseId,
        completedOnly: true,
        page: 1,
        pageSize: 1,
      );

      SessionExercise? previousExercise;
      if (history.items.isNotEmpty) {
        final session = history.items.first;
        for (final exercise in session.exercises) {
          if (exercise.exerciseId == exerciseId) {
            previousExercise = exercise;
            break;
          }
        }
      }

      if (mounted) {
        setState(() {
          _previousExerciseMap[exerciseId] = previousExercise;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _previousExerciseMap[exerciseId] = null;
        });
      }
    }
  }

  Future<void> _deletePendingDraft() async {
    final sessionId = _pendingSessionId;
    if (sessionId == null || widget.workoutApi == null) {
      return;
    }

    _syncDebounce?.cancel();
    _pendingSessionId = null;
    try {
      await widget.workoutApi!.deleteSession(sessionId);
    } catch (_) {}
  }

  Future<void> _addExercise() async {
    final picked = await Navigator.of(context).push<PickedExercise>(
      MaterialPageRoute(
        builder: (_) => ExercisePickerPage(workoutApi: widget.workoutApi),
      ),
    );
    if (picked == null) return;
    setState(() {
      _exercises.add(
        _LoggedExercise(
          id: picked.id,
          name: picked.name,
          muscle: picked.muscle,
        ),
      );
    });
    unawaited(_loadPreviousPerformance(picked.id));
    _queuePersist();
  }

  void _finishWorkout() {
    if (_exercises.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Add at least one exercise to finish.',
            style: GoogleFonts.poppins(fontSize: 13),
          ),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      );
      return;
    }
    _showFinishDialog();
  }

  void _showFinishDialog() {
    final completedSets = _exercises.fold<int>(
      0,
      (sum, ex) => sum + ex.sets.where((s) => s.isDone).length,
    );
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(
          'Finish Workout?',
          style: GoogleFonts.poppins(
            fontWeight: FontWeight.w700,
            color: AppColors.textPrimary,
          ),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.emoji_events_rounded,
              size: 52,
              color: Color(0xFFF59E0B),
            ),
            const SizedBox(height: 12),
            Text(
              '${_exercises.length} exercises\n'
              '$completedSets sets completed\n'
              '$_elapsedDisplay',
              textAlign: TextAlign.center,
              style: GoogleFonts.poppins(
                fontSize: 15,
                color: AppColors.textSecondary,
                height: 1.7,
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: Text(
              'Cancel',
              style: GoogleFonts.poppins(color: AppColors.textSecondary),
            ),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.accentGreen,
              foregroundColor: AppColors.btnDark,
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            onPressed: () {
              Navigator.of(ctx).pop();
              _saveAndFinish();
            },
            child: Text(
              'Finish',
              style: GoogleFonts.poppins(fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _saveAndFinish() async {
    if (widget.workoutApi == null) {
      Navigator.of(context).pop(true);
      return;
    }

    try {
      _syncDebounce?.cancel();
      await _persistDraft();
      await _ensureSessionCreated();
      setState(() => _saving = true);
      await widget.workoutApi!.finishSession(_pendingSessionId!);
      if (mounted) Navigator.of(context).pop(true);
    } catch (e) {
      if (!mounted) return;
      setState(() => _saving = false);
      // Use a dialog so the error isn't missed like a disappearing snackbar.
      await showDialog<void>(
        context: context,
        builder: (ctx) => AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          title: Text(
            'Save failed',
            style: GoogleFonts.poppins(
              fontWeight: FontWeight.w700,
              color: AppColors.error,
            ),
          ),
          content: Text(
            e.toString(),
            style: GoogleFonts.poppins(
              fontSize: 13,
              color: AppColors.textSecondary,
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: Text(
                'Dismiss',
                style: GoogleFonts.poppins(color: AppColors.textSecondary),
              ),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.accentGreen,
                foregroundColor: AppColors.btnDark,
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              onPressed: () {
                Navigator.of(ctx).pop();
                _saveAndFinish();
              },
              child: Text(
                'Retry',
                style: GoogleFonts.poppins(fontWeight: FontWeight.w700),
              ),
            ),
          ],
        ),
      );
    }
  }

  List<CreateExerciseRequest> _buildExerciseRequests() {
    return _exercises.asMap().entries.map((entry) {
      final ex = entry.value;
      return CreateExerciseRequest(
        exerciseId: ex.id,
        orderIndex: entry.key,
        sets: ex.sets.asMap().entries.map((setEntry) {
          final s = setEntry.value;
          final weight = double.tryParse(s.weightCtrl.text);
          final reps = int.tryParse(s.repsCtrl.text);
          return CreateSetRequest(
            setNumber: setEntry.key + 1,
            weightKg: weight,
            reps: reps,
            isCompleted: s.isDone,
          );
        }).toList(),
      );
    }).toList();
  }

  CreateSessionRequest _buildCreateRequest() {
    final startTime = DateTime.now().subtract(_stopwatch.elapsed);
    return CreateSessionRequest(
      title: _titleCtrl.text.trim().isNotEmpty ? _titleCtrl.text.trim() : null,
      startedAt: startTime,
      exercises: _buildExerciseRequests(),
    );
  }

  void _confirmDiscard() {
    if (_exercises.isEmpty) {
      unawaited(_deletePendingDraft());
      Navigator.of(context).pop(false);
      return;
    }
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(
          'Discard Workout?',
          style: GoogleFonts.poppins(fontWeight: FontWeight.w700),
        ),
        content: Text(
          'Your current workout progress will be lost.',
          style: GoogleFonts.poppins(color: AppColors.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: Text(
              'Keep',
              style: GoogleFonts.poppins(color: AppColors.textSecondary),
            ),
          ),
          TextButton(
            onPressed: () async {
              Navigator.of(ctx).pop();
              await _deletePendingDraft();
              if (mounted) {
                Navigator.of(context).pop(false);
              }
            },
            child: Text(
              'Discard',
              style: GoogleFonts.poppins(
                color: AppColors.error,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.scaffoldBg,
      body: Column(
        children: [
          // ── Top bar (dark) ────────────────────────────────────────────
          _WorkoutTopBar(
            elapsedDisplay: _elapsedDisplay,
            titleCtrl: _titleCtrl,
            onCancel: _confirmDiscard,
            onFinish: _saving ? null : _finishWorkout,
            saving: _saving,
            syncing: _syncing,
          ),

          // ── Exercise list ─────────────────────────────────────────────
          Expanded(
            child: _exercises.isEmpty
                ? _EmptyState(onAdd: _addExercise)
                : ListView.builder(
                    padding: const EdgeInsets.fromLTRB(16, 14, 16, 120),
                    itemCount: _exercises.length,
                    itemBuilder: (context, i) {
                      final ex = _exercises[i];
                      return _ExerciseCard(
                        exercise: ex,
                        previousExercise: _previousExerciseMap[ex.id],
                        onRemove: () {
                          setState(() {
                            for (final s in ex.sets) {
                              s.dispose();
                            }
                            _exercises.remove(ex);
                          });
                          if (_exercises.isEmpty) {
                            unawaited(_deletePendingDraft());
                          } else {
                            _queuePersist();
                          }
                        },
                        onAddSet: () => setState(() {
                          ex.sets.add(_LoggedSet());
                          _queuePersist();
                        }),
                        onSetChanged: () {
                          setState(() {});
                          _queuePersist();
                        },
                      );
                    },
                  ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _saving ? null : _addExercise,
        backgroundColor: AppColors.accent,
        elevation: 4,
        icon: const Icon(Icons.add_rounded, color: Colors.white),
        label: Text(
          'Add Exercise',
          style: GoogleFonts.poppins(
            color: Colors.white,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }
}

// ── Top bar ───────────────────────────────────────────────────────────────────

class _WorkoutTopBar extends StatelessWidget {
  const _WorkoutTopBar({
    required this.elapsedDisplay,
    required this.titleCtrl,
    required this.onCancel,
    required this.onFinish,
    required this.saving,
    required this.syncing,
  });

  final String elapsedDisplay;
  final TextEditingController titleCtrl;
  final VoidCallback onCancel;
  final VoidCallback? onFinish;
  final bool saving;
  final bool syncing;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: AppColors.btnDark,
      padding: EdgeInsets.only(
        top: MediaQuery.of(context).padding.top + 8,
        bottom: 14,
        left: 16,
        right: 16,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // Cancel
          GestureDetector(
            onTap: onCancel,
            child: Text(
              'Cancel',
              style: GoogleFonts.poppins(
                fontSize: 14,
                color: Colors.white.withAlpha(160),
              ),
            ),
          ),
          // Title + timer
          Expanded(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                SizedBox(
                  height: 28,
                  child: TextField(
                    controller: titleCtrl,
                    textAlign: TextAlign.center,
                    style: GoogleFonts.poppins(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                    ),
                    decoration: const InputDecoration(
                      border: InputBorder.none,
                      isDense: true,
                      contentPadding: EdgeInsets.zero,
                    ),
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  elapsedDisplay,
                  style: GoogleFonts.poppins(
                    fontSize: 12,
                    color: AppColors.accentGreen,
                  ),
                ),
                if (syncing)
                  Text(
                    'Syncing...',
                    style: GoogleFonts.poppins(
                      fontSize: 10,
                      color: Colors.white70,
                    ),
                  ),
              ],
            ),
          ),
          // Finish
          GestureDetector(
            onTap: onFinish,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
              decoration: BoxDecoration(
                color: AppColors.accentGreen,
                borderRadius: BorderRadius.circular(10),
              ),
              child: saving
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: AppColors.btnDark,
                      ),
                    )
                  : Text(
                      'Finish',
                      style: GoogleFonts.poppins(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: AppColors.btnDark,
                      ),
                    ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Empty state ───────────────────────────────────────────────────────────────

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.onAdd});
  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(
              color: AppColors.accent.withAlpha(20),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.fitness_center_rounded,
              size: 34,
              color: AppColors.accent,
            ),
          ),
          const SizedBox(height: 18),
          Text(
            'Get Started',
            style: GoogleFonts.poppins(
              fontSize: 20,
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Tap below to add your first exercise',
            style: GoogleFonts.poppins(
              fontSize: 13,
              color: AppColors.textMuted,
            ),
          ),
          const SizedBox(height: 28),
          ElevatedButton.icon(
            onPressed: onAdd,
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.accent,
              foregroundColor: Colors.white,
              elevation: 0,
              padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 14),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
              textStyle: GoogleFonts.poppins(
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
            ),
            icon: const Icon(Icons.add_rounded, size: 20),
            label: const Text('Add Exercise'),
          ),
        ],
      ),
    );
  }
}

// ── Exercise card ─────────────────────────────────────────────────────────────

class _ExerciseCard extends StatelessWidget {
  const _ExerciseCard({
    required this.exercise,
    required this.previousExercise,
    required this.onRemove,
    required this.onAddSet,
    required this.onSetChanged,
  });

  final _LoggedExercise exercise;
  final SessionExercise? previousExercise;
  final VoidCallback onRemove;
  final VoidCallback onAddSet;
  final VoidCallback onSetChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
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
          // Exercise header
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 6, 8),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        exercise.name,
                        style: GoogleFonts.poppins(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: AppColors.accent,
                        ),
                      ),
                      Text(
                        exercise.muscle,
                        style: GoogleFonts.poppins(
                          fontSize: 12,
                          color: AppColors.textMuted,
                        ),
                      ),
                    ],
                  ),
                ),
                PopupMenuButton<String>(
                  icon: const Icon(
                    Icons.more_horiz_rounded,
                    color: AppColors.textMuted,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                  onSelected: (val) {
                    if (val == 'remove') onRemove();
                  },
                  itemBuilder: (_) => [
                    PopupMenuItem(
                      value: 'remove',
                      child: Row(
                        children: [
                          const Icon(
                            Icons.delete_outline_rounded,
                            size: 18,
                            color: AppColors.error,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            'Remove Exercise',
                            style: GoogleFonts.poppins(
                              color: AppColors.error,
                              fontSize: 14,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          // Column headers
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                SizedBox(
                  width: 36,
                  child: Text(
                    'SET',
                    style: GoogleFonts.poppins(
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textMuted,
                    ),
                  ),
                ),
                Expanded(
                  child: Text(
                    'PREVIOUS',
                    style: GoogleFonts.poppins(
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textMuted,
                    ),
                  ),
                ),
                SizedBox(
                  width: 64,
                  child: Text(
                    'KG',
                    textAlign: TextAlign.center,
                    style: GoogleFonts.poppins(
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textMuted,
                    ),
                  ),
                ),
                SizedBox(
                  width: 64,
                  child: Text(
                    'REPS',
                    textAlign: TextAlign.center,
                    style: GoogleFonts.poppins(
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textMuted,
                    ),
                  ),
                ),
                const SizedBox(width: 36),
              ],
            ),
          ),
          const SizedBox(height: 6),

          // Set rows
          ...exercise.sets.asMap().entries.map(
            (entry) => _SetRow(
              setNumber: entry.key + 1,
              loggedSet: entry.value,
              previousText: _previousSetText(entry.key),
              onChanged: onSetChanged,
              onRemove: exercise.sets.length > 1
                  ? () {
                      entry.value.dispose();
                      exercise.sets.removeAt(entry.key);
                      onSetChanged();
                    }
                  : null,
            ),
          ),

          // Add Set button
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 14),
            child: GestureDetector(
              onTap: onAddSet,
              child: Container(
                height: 38,
                decoration: BoxDecoration(
                  color: AppColors.scaffoldBg,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Center(
                  child: Text(
                    '+ Add Set',
                    style: GoogleFonts.poppins(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _previousSetText(int setIndex) {
    if (previousExercise == null || setIndex >= previousExercise!.sets.length) {
      return '-';
    }

    final previousSet = previousExercise!.sets[setIndex];
    final weight = previousSet.weightKg;
    final reps = previousSet.reps;

    if (weight == null && reps == null) {
      return '-';
    }
    if (weight == null) {
      return '${reps ?? 0} reps';
    }
    if (reps == null) {
      return '${weight.toStringAsFixed(1)} kg';
    }
    return '${weight.toStringAsFixed(1)} x $reps';
  }
}

// ── Set row ───────────────────────────────────────────────────────────────────

class _SetRow extends StatelessWidget {
  const _SetRow({
    required this.setNumber,
    required this.loggedSet,
    required this.previousText,
    required this.onChanged,
    this.onRemove,
  });

  final int setNumber;
  final _LoggedSet loggedSet;
  final String previousText;
  final VoidCallback onChanged;
  final VoidCallback? onRemove;

  @override
  Widget build(BuildContext context) {
    final done = loggedSet.isDone;
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      color: done ? AppColors.accentGreenSoft : Colors.transparent,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 5),
      child: Row(
        children: [
          // Set number circle (long-press to remove)
          GestureDetector(
            onLongPress: onRemove,
            child: SizedBox(
              width: 36,
              child: Container(
                width: 26,
                height: 26,
                decoration: BoxDecoration(
                  color: done ? AppColors.accentGreen : AppColors.divider,
                  shape: BoxShape.circle,
                ),
                child: Center(
                  child: Text(
                    '$setNumber',
                    style: GoogleFonts.poppins(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: done ? Colors.white : AppColors.textSecondary,
                    ),
                  ),
                ),
              ),
            ),
          ),
          Expanded(
            child: Text(
              previousText,
              style: GoogleFonts.poppins(
                fontSize: 13,
                color: AppColors.textMuted,
              ),
            ),
          ),
          // Weight input
          SizedBox(
            width: 64,
            child: _NumberInput(
              controller: loggedSet.weightCtrl,
              hint: '0',
              decimal: true,
              onChanged: (_) => onChanged(),
            ),
          ),
          // Reps input
          SizedBox(
            width: 64,
            child: _NumberInput(
              controller: loggedSet.repsCtrl,
              hint: '0',
              decimal: false,
              onChanged: (_) => onChanged(),
            ),
          ),
          // Done checkmark
          SizedBox(
            width: 36,
            child: GestureDetector(
              onTap: () {
                loggedSet.isDone = !loggedSet.isDone;
                onChanged();
              },
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 150),
                width: 28,
                height: 28,
                decoration: BoxDecoration(
                  color: done ? AppColors.accentGreen : Colors.transparent,
                  border: Border.all(
                    color: done ? AppColors.accentGreen : AppColors.inputBorder,
                    width: 1.5,
                  ),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: done
                    ? const Icon(
                        Icons.check_rounded,
                        size: 16,
                        color: Colors.white,
                      )
                    : null,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Number input ──────────────────────────────────────────────────────────────

class _NumberInput extends StatelessWidget {
  const _NumberInput({
    required this.controller,
    required this.hint,
    required this.decimal,
    required this.onChanged,
  });

  final TextEditingController controller;
  final String hint;
  final bool decimal;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 36,
      margin: const EdgeInsets.symmetric(horizontal: 4),
      decoration: BoxDecoration(
        color: AppColors.scaffoldBg,
        borderRadius: BorderRadius.circular(8),
      ),
      child: TextField(
        controller: controller,
        onChanged: onChanged,
        keyboardType: TextInputType.numberWithOptions(decimal: decimal),
        inputFormatters: [
          if (decimal)
            FilteringTextInputFormatter.allow(RegExp(r'[0-9.]'))
          else
            FilteringTextInputFormatter.digitsOnly,
        ],
        textAlign: TextAlign.center,
        style: GoogleFonts.poppins(
          fontSize: 14,
          fontWeight: FontWeight.w600,
          color: AppColors.textPrimary,
        ),
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: GoogleFonts.poppins(
            fontSize: 14,
            color: AppColors.textMuted,
          ),
          border: InputBorder.none,
          isDense: true,
          contentPadding: const EdgeInsets.symmetric(vertical: 8),
        ),
      ),
    );
  }
}
