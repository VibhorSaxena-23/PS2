import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:flexicurl_client_mobile/src/core/network/api_client.dart';
import 'package:flexicurl_client_mobile/src/core/network/api_exception.dart';
import 'package:flexicurl_client_mobile/src/features/health_onboarding/data/health_onboarding_api.dart';
import 'package:flexicurl_client_mobile/src/features/health_onboarding/models/health_draft.dart';
import 'package:flexicurl_client_mobile/src/features/health_onboarding/models/nutrition_plan.dart';
import 'package:flexicurl_client_mobile/src/features/health_onboarding/presentation/steps/step_nutrition_summary.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('StepNutritionSummary', () {
    testWidgets(
      'saveTargets success + saveProfile failure still completes onboarding',
      (tester) async {
        final api = _FakeHealthOnboardingApi(
          saveProfileError: ApiException(message: 'Not Found', statusCode: 404),
        );
        var completed = false;

        await tester.pumpWidget(
          MaterialApp(
            home: StepNutritionSummary(
              draft: _draft(),
              plan: _plan(),
              api: api,
              progress: 1,
              onBack: () {},
              onCompleted: () => completed = true,
            ),
          ),
        );

        await tester.tap(find.text('Save & Start'));
        await tester.pump();

        for (var i = 0; i < 20 && !completed; i += 1) {
          await tester.pump(const Duration(milliseconds: 100));
        }

        expect(completed, isTrue);
        expect(api.saveTargetsCalls, 1);
        expect(api.saveProfileCalls, 1);
        expect(
          find.text('Could not save your plan. Please try again.'),
          findsNothing,
        );
        expect(
          find.text(
            'Saved your nutrition plan. Profile snapshot sync will retry later.',
          ),
          findsOneWidget,
        );
      },
    );

    testWidgets(
      'saveTargets failure shows blocking error and does not complete',
      (tester) async {
        final api = _FakeHealthOnboardingApi(
          saveTargetsError: ApiException(
            message: 'Server error',
            statusCode: 500,
          ),
        );
        var completed = false;

        await tester.pumpWidget(
          MaterialApp(
            home: StepNutritionSummary(
              draft: _draft(),
              plan: _plan(),
              api: api,
              progress: 1,
              onBack: () {},
              onCompleted: () => completed = true,
            ),
          ),
        );

        await tester.tap(find.text('Save & Start'));
        await tester.pumpAndSettle();

        expect(completed, isFalse);
        expect(api.saveTargetsCalls, 1);
        expect(api.saveProfileCalls, 0);
        expect(
          find.text('Could not save your plan. Please try again.'),
          findsOneWidget,
        );
      },
    );
  });
}

class _FakeHealthOnboardingApi extends HealthOnboardingApi {
  _FakeHealthOnboardingApi({this.saveTargetsError, this.saveProfileError})
    : super(
        ApiClient(
          baseUrl: 'http://localhost/mobile/api/v1',
          userId: 'test-user',
          httpClient: MockClient(
            (_) async => http.Response(jsonEncode(<String, dynamic>{}), 200),
          ),
        ),
      );

  final Object? saveTargetsError;
  final Object? saveProfileError;
  int saveTargetsCalls = 0;
  int saveProfileCalls = 0;

  @override
  Future<SavedNutritionPlan> saveTargets(HealthDraft draft) async {
    saveTargetsCalls += 1;
    if (saveTargetsError != null) {
      throw saveTargetsError!;
    }

    return const SavedNutritionPlan(
      id: 'saved-1',
      userId: 'test-user',
      goalRateKgPerWeek: 0.5,
      bmi: 22.1,
      bmiCategory: 'Normal',
      bmrKcal: 1700,
      maintenanceCaloriesKcal: 2400,
      dailyDeficitKcal: 500,
      targetCaloriesKcal: 1900,
      macros: MacroTargets(proteinG: 140, carbsG: 190, fatG: 60),
    );
  }

  @override
  Future<void> saveProfile(HealthDraft draft) async {
    saveProfileCalls += 1;
    if (saveProfileError != null) {
      throw saveProfileError!;
    }
  }
}

HealthDraft _draft() {
  return const HealthDraft(
    heightCm: 175,
    weightKg: 72,
    age: 28,
    sex: BiologicalSex.male,
    activityLevel: ActivityLevel.moderate,
    goalType: GoalType.loseWeight,
    weeklyRateKg: 0.5,
  );
}

NutritionPlan _plan() {
  const selectedGoal = CalorieGoalOption(
    rateKgPerWeek: 0.5,
    dailyDeficitKcal: 500,
    targetCaloriesKcal: 1900,
    macros: MacroTargets(proteinG: 140, carbsG: 190, fatG: 60),
  );

  return const NutritionPlan(
    bmi: 22.1,
    bmiCategory: 'Normal',
    bmrKcal: 1700,
    maintenanceCaloriesKcal: 2400,
    selectedGoal: selectedGoal,
    goalOptions: [selectedGoal],
  );
}
