import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../core/theme/app_colors.dart';
import '../../models/health_draft.dart';
import '../_health_onboarding_scaffold.dart';

class StepActivityGoal extends StatefulWidget {
  const StepActivityGoal({
    super.key,
    required this.draft,
    required this.progress,
    required this.onNext,
    required this.onBack,
  });

  final HealthDraft draft;
  final double progress;
  final ValueChanged<HealthDraft> onNext;
  final VoidCallback onBack;

  @override
  State<StepActivityGoal> createState() => _StepActivityGoalState();
}

class _StepActivityGoalState extends State<StepActivityGoal> {
  ActivityLevel? _activity;
  GoalType? _goal;

  @override
  void initState() {
    super.initState();
    _activity = widget.draft.activityLevel;
    _goal = widget.draft.goalType;
  }

  bool get _valid => _activity != null && _goal != null;

  HealthDraft get _current => widget.draft.copyWith(
        activityLevel: _activity,
        goalType: _goal,
        // reset weekly rate when goal changes
        weeklyRateKg:
            _goal == GoalType.maintain ? kWeeklyRateMaintain : widget.draft.weeklyRateKg,
      );

  @override
  Widget build(BuildContext context) {
    return HealthOnboardingScaffold(
      title: 'Activity & Goal',
      subtitle: 'Step 2 of 6 — How active are you and what\'s your target?',
      progress: widget.progress,
      stepLabel: '2 / 6',
      onBack: widget.onBack,
      onNext: _valid ? () => widget.onNext(_current) : null,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _SectionHeader('Activity Level'),
          const SizedBox(height: 10),
          ...ActivityLevel.values.map(
            (a) => HealthOptionCard(
              label: a.label,
              description: a.description,
              icon: _activityIcon(a),
              selected: _activity == a,
              onTap: () => setState(() => _activity = a),
            ),
          ),
          const SizedBox(height: 20),
          _SectionHeader('Your Goal'),
          const SizedBox(height: 10),
          ...GoalType.values.map(
            (g) => HealthOptionCard(
              label: g.label,
              description: g.description,
              icon: _goalIcon(g),
              selected: _goal == g,
              onTap: () => setState(() => _goal = g),
              accent: _goalColor(g),
            ),
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }

  IconData _activityIcon(ActivityLevel a) {
    switch (a) {
      case ActivityLevel.sedentary:
        return Icons.weekend_rounded;
      case ActivityLevel.light:
        return Icons.directions_walk_rounded;
      case ActivityLevel.moderate:
        return Icons.directions_run_rounded;
      case ActivityLevel.veryActive:
        return Icons.fitness_center_rounded;
      case ActivityLevel.athlete:
        return Icons.emoji_events_rounded;
    }
  }

  IconData _goalIcon(GoalType g) {
    switch (g) {
      case GoalType.loseWeight:
        return Icons.trending_down_rounded;
      case GoalType.gainWeight:
        return Icons.trending_up_rounded;
      case GoalType.maintain:
        return Icons.balance_rounded;
    }
  }

  Color _goalColor(GoalType g) {
    switch (g) {
      case GoalType.loseWeight:
        return const Color(0xFF0EA5E9);
      case GoalType.gainWeight:
        return const Color(0xFF16A34A);
      case GoalType.maintain:
        return AppColors.btnDark;
    }
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader(this.text);
  final String text;

  @override
  Widget build(BuildContext context) => Text(
        text,
        style: GoogleFonts.poppins(
          fontSize: 15,
          fontWeight: FontWeight.w700,
          color: AppColors.textPrimary,
        ),
      );
}
