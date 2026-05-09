import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:flexicurl_client_mobile/src/core/network/api_client.dart';
import 'package:flexicurl_client_mobile/src/core/network/api_exception.dart';
import 'package:flexicurl_client_mobile/src/features/workout/data/workout_api.dart';
import 'package:flexicurl_client_mobile/src/features/workout/models/workout_models.dart';
import 'package:flexicurl_client_mobile/src/features/workout/presentation/workout_page.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  testWidgets(
    'shows friendly behavior when active plan endpoint is unavailable',
    (tester) async {
      final api = _ActivePlanUnavailableWorkoutApi();

      await tester.pumpWidget(MaterialApp(home: WorkoutPage(workoutApi: api)));
      await tester.pump();

      for (var i = 0;
          i < 20 && find.text('Set Active Plan').evaluate().isEmpty;
          i++) {
        await tester.pump(const Duration(milliseconds: 200));
      }

      expect(find.text('Set Active Plan'), findsOneWidget);

      await tester.tap(find.text('Set Active Plan'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('PPL').first);
      await tester.pumpAndSettle();

      expect(find.text('Set Active Plan'), findsOneWidget);
      expect(find.text('Could not set active plan:'), findsNothing);
    },
  );
}

class _ActivePlanUnavailableWorkoutApi extends WorkoutApi {
  _ActivePlanUnavailableWorkoutApi()
      : super(
          ApiClient(
            baseUrl: 'http://localhost/mobile/api/v1',
            userId: 'test-user',
            httpClient: MockClient((_) async => throw UnimplementedError()),
          ),
        );

  @override
  Future<UserAnalyticsSummary> getUserAnalytics() async {
    return const UserAnalyticsSummary(
      userId: 'test-user',
      totalSessions: 0,
      completedSessions: 0,
      totalVolume: 0,
      personalBests: [],
    );
  }

  @override
  Future<SessionHistoryPage> getHistory({
    String? startDate,
    String? endDate,
    int? exerciseId,
    String? muscle,
    String? equipment,
    bool completedOnly = false,
    int page = 1,
    int pageSize = 20,
  }) async {
    return SessionHistoryPage(
      items: const [],
      total: 0,
      page: 1,
      pageSize: 20,
      totalPages: 0,
    );
  }

  @override
  Future<TodayWorkout?> getTodayWorkout() async => null;

  @override
  Future<ActivePlan> setActivePlan(String planType) async {
    throw ApiException(message: 'Not Found', statusCode: 404);
  }
}
