import 'dart:async';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/theme/app_colors.dart';
import '../data/workout_api.dart';
import '../models/workout_models.dart';

/// Returned when a user selects an exercise from the picker.
class PickedExercise {
  const PickedExercise({
    required this.id,
    required this.name,
    required this.muscle,
    this.equipment,
  });
  final int id;
  final String name;
  final String muscle;
  final String? equipment;
}

// ── Page ─────────────────────────────────────────────────────────────────────

/// Hevy-style exercise browser — search + muscle group filter.
/// When [workoutApi] is provided, fetches exercises from backend.
/// Falls back to a built-in catalog when the API is unavailable.
class ExercisePickerPage extends StatefulWidget {
  const ExercisePickerPage({super.key, this.workoutApi});

  final WorkoutApi? workoutApi;

  @override
  State<ExercisePickerPage> createState() => _ExercisePickerPageState();
}

class _ExercisePickerPageState extends State<ExercisePickerPage> {
  final _searchCtrl = TextEditingController();
  String _query = '';
  String _muscleFilter = 'All';

  // API-loaded state
  List<ExerciseItem>? _apiExercises;
  List<String> _muscles = const [
    'All', 'Chest', 'Back', 'Shoulders', 'Legs', 'Biceps', 'Triceps',
    'Core', 'Hamstrings', 'Glutes', 'Calves', 'Full Body',
  ];
  bool _loadingExercises = false;
  Timer? _debounce;

  @override
  void initState() {
    super.initState();
    if (widget.workoutApi != null) {
      _loadMuscles();
      _loadExercises();
    }
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    _debounce?.cancel();
    super.dispose();
  }

  Future<void> _loadMuscles() async {
    try {
      final groups = await widget.workoutApi!.getMuscleGroups();
      if (mounted) {
        setState(() {
          _muscles = ['All', ...groups.primaryMuscles];
        });
      }
    } catch (_) {
      // Keep default muscles on failure
    }
  }

  Future<void> _loadExercises() async {
    setState(() => _loadingExercises = true);
    try {
      final ExercisePage page;
      if (_query.isNotEmpty) {
        // Use dedicated full-text search when user is typing
        page = await widget.workoutApi!.searchExercises(q: _query, pageSize: 50);
      } else {
        // Browse mode — filter by muscle group if selected
        page = await widget.workoutApi!.getExercises(
          muscle: _muscleFilter != 'All' ? _muscleFilter : null,
          pageSize: 50,
        );
      }
      if (mounted) {
        setState(() {
          _apiExercises = page.items;
          _loadingExercises = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _apiExercises = null; // Fall back to catalog
          _loadingExercises = false;
        });
      }
    }
  }

  void _onSearchChanged(String value) {
    setState(() => _query = value);
    if (widget.workoutApi != null) {
      _debounce?.cancel();
      _debounce = Timer(const Duration(milliseconds: 400), _loadExercises);
    }
  }

  void _onMuscleSelected(String muscle) {
    setState(() => _muscleFilter = muscle);
    if (widget.workoutApi != null) {
      _loadExercises();
    }
  }

  // ── Fallback catalog ────────────────────────────────────────────────────────

  // Mirror of the production DB (IDs 1–20). Used only when the API is unreachable.
  static const _catalog = [
    ExerciseItem(id: 1,  name: 'Barbell Bench Press',  primaryMuscle: 'Chest',      equipment: 'Barbell'),
    ExerciseItem(id: 2,  name: 'Dumbbell Bench Press', primaryMuscle: 'Chest',      equipment: 'Dumbbell'),
    ExerciseItem(id: 3,  name: 'Push Ups',             primaryMuscle: 'Chest',      equipment: 'Bodyweight'),
    ExerciseItem(id: 4,  name: 'Pull Ups',             primaryMuscle: 'Back',       equipment: 'Pull-up Bar'),
    ExerciseItem(id: 5,  name: 'Lat Pulldown',         primaryMuscle: 'Back',       equipment: 'Machine'),
    ExerciseItem(id: 6,  name: 'Barbell Squat',        primaryMuscle: 'Legs',       equipment: 'Barbell'),
    ExerciseItem(id: 7,  name: 'Leg Press',            primaryMuscle: 'Legs',       equipment: 'Machine'),
    ExerciseItem(id: 8,  name: 'Romanian Deadlift',    primaryMuscle: 'Hamstrings', equipment: 'Barbell'),
    ExerciseItem(id: 9,  name: 'Shoulder Press',       primaryMuscle: 'Shoulders',  equipment: 'Dumbbell'),
    ExerciseItem(id: 10, name: 'Lateral Raise',        primaryMuscle: 'Shoulders',  equipment: 'Dumbbell'),
    ExerciseItem(id: 11, name: 'Bicep Curl',           primaryMuscle: 'Biceps',     equipment: 'Dumbbell'),
    ExerciseItem(id: 12, name: 'Hammer Curl',          primaryMuscle: 'Biceps',     equipment: 'Dumbbell'),
    ExerciseItem(id: 13, name: 'Tricep Pushdown',      primaryMuscle: 'Triceps',    equipment: 'Cable'),
    ExerciseItem(id: 14, name: 'Plank',                primaryMuscle: 'Core',       equipment: 'Bodyweight'),
    ExerciseItem(id: 15, name: 'Mountain Climbers',    primaryMuscle: 'Core',       equipment: 'Bodyweight'),
    ExerciseItem(id: 16, name: 'Walking Lunges',       primaryMuscle: 'Legs',       equipment: 'Dumbbell'),
    ExerciseItem(id: 17, name: 'Glute Bridge',         primaryMuscle: 'Glutes',     equipment: 'Bodyweight'),
    ExerciseItem(id: 18, name: 'Calf Raises',          primaryMuscle: 'Calves',     equipment: 'Bodyweight'),
    ExerciseItem(id: 19, name: 'Russian Twist',        primaryMuscle: 'Core',       equipment: 'Bodyweight'),
    ExerciseItem(id: 20, name: 'Burpees',              primaryMuscle: 'Full Body',  equipment: 'Bodyweight'),
  ];

  List<ExerciseItem> get _displayList {
    // If API returned results, use those (already filtered server-side)
    if (_apiExercises != null) return _apiExercises!;

    // Otherwise filter the local catalog
    return _catalog.where((e) {
      final matchMuscle = _muscleFilter == 'All' ||
          e.primaryMuscle == _muscleFilter;
      final matchQuery = _query.isEmpty ||
          e.name.toLowerCase().contains(_query.toLowerCase()) ||
          (e.primaryMuscle?.toLowerCase().contains(_query.toLowerCase()) ?? false);
      return matchMuscle && matchQuery;
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final filtered = _displayList;
    return Scaffold(
      backgroundColor: AppColors.scaffoldBg,
      appBar: AppBar(
        backgroundColor: AppColors.white,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        title: Text(
          'Select Exercise',
          style: GoogleFonts.poppins(
            fontSize: 17,
            fontWeight: FontWeight.w700,
            color: AppColors.textPrimary,
          ),
        ),
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.close_rounded, color: AppColors.textPrimary),
          onPressed: () => Navigator.of(context).pop(),
        ),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(106),
          child: Column(
            children: [
              // ── Search bar ──────────────────────────────────────────
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 10),
                child: Container(
                  height: 44,
                  decoration: BoxDecoration(
                    color: AppColors.scaffoldBg,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: TextField(
                    controller: _searchCtrl,
                    onChanged: _onSearchChanged,
                    style: GoogleFonts.poppins(
                        fontSize: 14, color: AppColors.textPrimary),
                    decoration: InputDecoration(
                      hintText: 'Search exercises...',
                      hintStyle: GoogleFonts.poppins(
                          fontSize: 14, color: AppColors.textMuted),
                      prefixIcon: const Icon(Icons.search_rounded,
                          color: AppColors.textMuted, size: 20),
                      suffixIcon: _query.isNotEmpty
                          ? IconButton(
                              icon: const Icon(Icons.clear_rounded,
                                  color: AppColors.textMuted, size: 18),
                              onPressed: () {
                                _searchCtrl.clear();
                                _onSearchChanged('');
                              },
                            )
                          : null,
                      border: InputBorder.none,
                      contentPadding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                  ),
                ),
              ),
              // ── Muscle filter chips ─────────────────────────────────
              SizedBox(
                height: 38,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemCount: _muscles.length,
                  separatorBuilder: (_, _) => const SizedBox(width: 8),
                  itemBuilder: (context, i) {
                    final muscle = _muscles[i];
                    final selected = _muscleFilter == muscle;
                    return ChoiceChip(
                      label: Text(muscle),
                      selected: selected,
                      onSelected: (_) => _onMuscleSelected(muscle),
                      labelStyle: GoogleFonts.poppins(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color:
                            selected ? Colors.white : AppColors.textSecondary,
                      ),
                      backgroundColor: AppColors.scaffoldBg,
                      selectedColor: AppColors.btnDark,
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      side: const BorderSide(color: Colors.transparent),
                      showCheckmark: false,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(20)),
                    );
                  },
                ),
              ),
              const SizedBox(height: 8),
              const Divider(height: 1, color: AppColors.divider),
            ],
          ),
        ),
      ),
      body: _loadingExercises
          ? const Center(child: CircularProgressIndicator())
          : filtered.isEmpty
              ? Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.search_off_rounded,
                          size: 44, color: AppColors.textMuted),
                      const SizedBox(height: 8),
                      Text('No exercises found',
                          style: GoogleFonts.poppins(
                              fontSize: 14, color: AppColors.textMuted)),
                    ],
                  ),
                )
              : ListView.separated(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  itemCount: filtered.length,
                  separatorBuilder: (_, _) => const Divider(
                    height: 1,
                    indent: 72,
                    color: AppColors.divider,
                  ),
                  itemBuilder: (context, i) {
                    final entry = filtered[i];
                    final muscle = entry.primaryMuscle ?? '';
                    final equipment = entry.equipment ?? '';
                    return ListTile(
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 4),
                      leading: Container(
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                          color: _muscleColor(muscle).withAlpha(30),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Icon(_muscleIcon(muscle),
                            color: _muscleColor(muscle), size: 22),
                      ),
                      title: Text(
                        entry.name,
                        style: GoogleFonts.poppins(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      subtitle: Text(
                        [muscle, equipment]
                            .where((s) => s.isNotEmpty)
                            .join(' · '),
                        style: GoogleFonts.poppins(
                            fontSize: 12, color: AppColors.textMuted),
                      ),
                      trailing: const Icon(Icons.add_circle_rounded,
                          color: AppColors.accent, size: 26),
                      onTap: () => Navigator.of(context).pop(
                        PickedExercise(
                          id: entry.id,
                          name: entry.name,
                          muscle: muscle,
                          equipment: equipment.isNotEmpty ? equipment : null,
                        ),
                      ),
                    );
                  },
                ),
    );
  }

  Color _muscleColor(String muscle) => switch (muscle) {
        'Chest'      => const Color(0xFF4F46E5),
        'Back'       => const Color(0xFF0891B2),
        'Shoulders'  => const Color(0xFF7C3AED),
        'Legs'       => const Color(0xFF059669),
        'Biceps'     => const Color(0xFFD97706),
        'Triceps'    => const Color(0xFFDC2626),
        'Core'       => const Color(0xFF0EA5E9),
        'Hamstrings' => const Color(0xFF16A34A),
        'Glutes'     => const Color(0xFFDB2777),
        'Calves'     => const Color(0xFF2563EB),
        'Full Body'  => const Color(0xFF9333EA),
        _ => AppColors.textSecondary,
      };

  IconData _muscleIcon(String muscle) => switch (muscle) {
        'Back'       => Icons.accessibility_new_rounded,
        'Legs'       => Icons.directions_run_rounded,
        'Hamstrings' => Icons.directions_run_rounded,
        'Glutes'     => Icons.directions_run_rounded,
        'Full Body'  => Icons.sports_gymnastics_rounded,
        _ => Icons.fitness_center_rounded,
      };
}
