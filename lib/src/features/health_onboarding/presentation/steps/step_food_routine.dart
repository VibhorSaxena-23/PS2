import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../core/theme/app_colors.dart';
import '../../models/health_draft.dart';
import '../_health_onboarding_scaffold.dart';

class StepFoodRoutine extends StatefulWidget {
  const StepFoodRoutine({
    super.key,
    required this.draft,
    required this.progress,
    required this.onBack,
    required this.onNext,
  });

  final HealthDraft draft;
  final double progress;
  final VoidCallback onBack;
  final Future<void> Function(HealthDraft) onNext;

  @override
  State<StepFoodRoutine> createState() => _StepFoodRoutineState();
}

class _StepFoodRoutineState extends State<StepFoodRoutine> {
  FoodPreference? _food;
  String? _wakeTime;
  String? _sleepTime;
  String? _workoutTime;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _food = widget.draft.foodPreference;
    _wakeTime = widget.draft.wakeTime;
    _sleepTime = widget.draft.sleepTime;
    _workoutTime = widget.draft.workoutTime;
  }

  HealthDraft get _current => widget.draft.copyWith(
        foodPreference: _food,
        wakeTime: _wakeTime,
        sleepTime: _sleepTime,
        workoutTime: _workoutTime,
      );

  Future<void> _handleNext() async {
    setState(() => _isLoading = true);
    await widget.onNext(_current);
    if (mounted) setState(() => _isLoading = false);
  }

  Future<void> _pickTime(String label,
      {required ValueChanged<String?> onPicked}) async {
    final initial = TimeOfDay.now();
    final picked = await showTimePicker(
      context: context,
      initialTime: initial,
      helpText: 'Select $label',
    );
    if (picked != null) {
      final formatted =
          '${picked.hour.toString().padLeft(2, '0')}:${picked.minute.toString().padLeft(2, '0')}';
      onPicked(formatted);
    }
  }

  @override
  Widget build(BuildContext context) {
    return HealthOnboardingScaffold(
      title: 'Food & Routine',
      subtitle: 'Step 5 of 6 — Optional details for smarter recommendations.',
      progress: widget.progress,
      stepLabel: '5 / 6',
      onBack: widget.onBack,
      onNext: _handleNext, // always valid — entirely optional step
      isLoading: _isLoading,
      nextLabel: _isLoading ? 'Calculating…' : 'See My Plan',
      nextIcon: Icons.auto_graph_rounded,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Food preference
          _SectionLabel('Food Preference'),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: FoodPreference.values.map((f) {
              final sel = _food == f;
              return ChoiceChip(
                label: Text(
                  f.label,
                  style: GoogleFonts.poppins(
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    color: sel ? Colors.white : AppColors.textPrimary,
                  ),
                ),
                selected: sel,
                onSelected: (_) => setState(() => _food = sel ? null : f),
                selectedColor: AppColors.btnDark,
                backgroundColor: AppColors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                  side: BorderSide(
                    color:
                        sel ? AppColors.btnDark : AppColors.inputBorder,
                    width: sel ? 2 : 1.5,
                  ),
                ),
                padding: const EdgeInsets.symmetric(
                    horizontal: 12, vertical: 6),
              );
            }).toList(),
          ),
          const SizedBox(height: 26),

          // Daily routine times
          _SectionLabel('Daily Routine  (optional)'),
          const SizedBox(height: 10),
          _TimeRow(
            icon: Icons.wb_sunny_outlined,
            label: 'Wake up',
            value: _wakeTime,
            onTap: () => _pickTime('wake-up time',
                onPicked: (t) => setState(() => _wakeTime = t)),
          ),
          const SizedBox(height: 10),
          _TimeRow(
            icon: Icons.bedtime_outlined,
            label: 'Sleep',
            value: _sleepTime,
            onTap: () => _pickTime('sleep time',
                onPicked: (t) => setState(() => _sleepTime = t)),
          ),
          const SizedBox(height: 10),
          _TimeRow(
            icon: Icons.fitness_center_rounded,
            label: 'Workout',
            value: _workoutTime,
            onTap: () => _pickTime('workout time',
                onPicked: (t) => setState(() => _workoutTime = t)),
          ),
          const SizedBox(height: 20),

          Text(
            'Tap "See My Plan" to calculate your personalised calorie targets.',
            style: GoogleFonts.poppins(
              fontSize: 12,
              color: AppColors.textMuted,
              fontStyle: FontStyle.italic,
            ),
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.text);
  final String text;

  @override
  Widget build(BuildContext context) => Text(
        text,
        style: GoogleFonts.poppins(
          fontSize: 13,
          fontWeight: FontWeight.w600,
          color: AppColors.textSecondary,
        ),
      );
}

class _TimeRow extends StatelessWidget {
  const _TimeRow({
    required this.icon,
    required this.label,
    required this.value,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final String? value;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: AppColors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
              color: AppColors.inputBorder, width: 1.5),
        ),
        child: Row(
          children: [
            Icon(icon, size: 20, color: AppColors.textSecondary),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                label,
                style: GoogleFonts.poppins(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: AppColors.textPrimary,
                ),
              ),
            ),
            Text(
              value ?? 'Tap to set',
              style: GoogleFonts.poppins(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: value != null
                    ? AppColors.textPrimary
                    : AppColors.textMuted,
              ),
            ),
            const SizedBox(width: 6),
            const Icon(Icons.chevron_right_rounded,
                size: 18, color: AppColors.textMuted),
          ],
        ),
      ),
    );
  }
}
