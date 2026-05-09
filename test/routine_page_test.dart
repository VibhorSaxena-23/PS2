import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/testing.dart';

import 'package:flexicurl_client_mobile/src/core/network/api_client.dart';
import 'package:flexicurl_client_mobile/src/features/home/presentation/routine_page.dart';
import 'package:flexicurl_client_mobile/src/features/workout/data/workout_api.dart';
import 'package:flexicurl_client_mobile/src/features/workout/models/workout_models.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('no active plan shows empty routine state, not blocking error', (
    tester,
  ) async {
    final api = _NullTodayWorkoutApi();

    await tester.pumpWidget(MaterialApp(home: RoutinePage(workoutApi: api)));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.text('No active workout plan'), findsOneWidget);
    expect(find.text('Could not load routine'), findsNothing);
    expect(api.getTodayWorkoutCalls, 1);
  });
}

class _NullTodayWorkoutApi extends WorkoutApi {
  _NullTodayWorkoutApi()
    : super(
        ApiClient(
          baseUrl: 'http://localhost/mobile/api/v1',
          userId: 'test-user',
          httpClient: MockClient((_) async => throw UnimplementedError()),
        ),
      );

  int getTodayWorkoutCalls = 0;

  @override
  Future<TodayWorkout?> getTodayWorkout() async {
    getTodayWorkoutCalls += 1;
    return null;
  }
}
