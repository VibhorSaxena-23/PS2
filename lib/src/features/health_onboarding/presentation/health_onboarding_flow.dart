import 'package:flutter/material.dart';

import '../../profile/data/profile_api.dart';
import '../data/health_onboarding_api.dart';
import '../models/health_draft.dart';
import '../models/nutrition_plan.dart';
import 'steps/step_body_basics.dart';
import 'steps/step_activity_goal.dart';
import 'steps/step_weekly_rate.dart';
import 'steps/step_health_conditions.dart';
import 'steps/step_food_routine.dart';
import 'steps/step_nutrition_summary.dart';

enum _HealthStep {
  bodyBasics,
  activityGoal,
  weeklyRate,
  healthConditions,
  foodRoutine,
  nutritionSummary,
}

const _kTotalSteps = 6;

/// Top-level coordinator for the health setup wizard.
/// Holds draft state; individual step pages are stateless (receive draft + callback).
class HealthOnboardingFlow extends StatefulWidget {
  const HealthOnboardingFlow({
    super.key,
    required this.api,
    required this.profileApi,
    required this.onCompleted,
  });

  final HealthOnboardingApi api;
  final ProfileApi profileApi;
  final VoidCallback onCompleted;

  @override
  State<HealthOnboardingFlow> createState() => _HealthOnboardingFlowState();
}

class _HealthOnboardingFlowState extends State<HealthOnboardingFlow> {
  _HealthStep _step = _HealthStep.bodyBasics;
  HealthDraft _draft = const HealthDraft();
  NutritionPlan? _plan;

  // step index (0-based) used for progress bar
  int get _stepIndex => _HealthStep.values.indexOf(_step);

  void _next() => setState(() {
        if (_step != _HealthStep.nutritionSummary) {
          _step = _HealthStep.values[_stepIndex + 1];
        }
      });

  void _back() {
    if (_stepIndex == 0) return;
    setState(() => _step = _HealthStep.values[_stepIndex - 1]);
  }

  void _updateDraft(HealthDraft d) => setState(() => _draft = d);

  @override
  Widget build(BuildContext context) {
    final progress = (_stepIndex + 1) / _kTotalSteps;

    switch (_step) {
      case _HealthStep.bodyBasics:
        return StepBodyBasics(
          draft: _draft,
          progress: progress,
          onBack: null,
          onNext: (d) { _updateDraft(d); _next(); },
        );

      case _HealthStep.activityGoal:
        return StepActivityGoal(
          draft: _draft,
          progress: progress,
          onBack: _back,
          onNext: (d) { _updateDraft(d); _next(); },
        );

      case _HealthStep.weeklyRate:
        return StepWeeklyRate(
          draft: _draft,
          progress: progress,
          onBack: _back,
          onNext: (d) { _updateDraft(d); _next(); },
        );

      case _HealthStep.healthConditions:
        return StepHealthConditions(
          draft: _draft,
          progress: progress,
          onBack: _back,
          onNext: (d) { _updateDraft(d); _next(); },
        );

      case _HealthStep.foodRoutine:
        return StepFoodRoutine(
          draft: _draft,
          progress: progress,
          onBack: _back,
          onNext: (HealthDraft d) async {
            _updateDraft(d);
            // Calculate targets before showing summary
            NutritionPlan plan;
            try {
              plan = await widget.api.calculateTargets(d);
            } catch (e) {
              plan = widget.api.calculateLocalFallback(d);
            }
            if (!mounted) return;
            setState(() { _plan = plan; _step = _HealthStep.nutritionSummary; });
          },
        );

      case _HealthStep.nutritionSummary:
        return StepNutritionSummary(
          draft: _draft,
          plan: _plan!,
          api: widget.api,
          progress: progress,
          onBack: _back,
          onCompleted: widget.onCompleted,
        );
    }
  }
}
