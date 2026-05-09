import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:flexicurl_client_mobile/src/core/network/api_client.dart';
import 'package:flexicurl_client_mobile/src/features/workout/data/local_plan_service.dart';
import 'package:flexicurl_client_mobile/src/features/workout/data/workout_api.dart';
import 'package:flexicurl_client_mobile/src/features/workout/models/workout_models.dart';

ApiClient _buildClient(MockClient mockClient) {
  return ApiClient(
    baseUrl: 'http://localhost/mobile/api/v1',
    userId: 'test-user',
    httpClient: mockClient,
  );
}

// Reusable session JSON fixture
Map<String, dynamic> _sessionJson({
  String id = 'session-1',
  bool isCompleted = false,
}) => {
  'id': id,
  'user_id': 'test-user',
  'title': 'Push Day',
  'notes': null,
  'started_at': '2026-03-26T09:00:00Z',
  'finished_at': isCompleted ? '2026-03-26T10:00:00Z' : null,
  'duration_sec': isCompleted ? 3600 : null,
  'is_completed': isCompleted,
  'exercises': [
    {
      'id': 'ex-1',
      'exercise_id': 1,
      'exercise_name': 'Bench Press',
      'primary_muscle': 'Chest',
      'equipment': 'Barbell',
      'order_index': 0,
      'notes': null,
      'sets': [
        {
          'id': 'set-1',
          'set_number': 1,
          'set_type': 'NORMAL',
          'reps': 10,
          'weight_kg': 60.0,
          'rpe': null,
          'rir': null,
          'duration_sec': null,
          'distance_m': null,
          'note': null,
          'is_completed': true,
        },
      ],
      'volume': 600.0,
      'max_weight': 60.0,
    },
  ],
  'total_volume': 600.0,
  'created_at': '2026-03-26T09:00:00Z',
  'updated_at': '2026-03-26T09:00:00Z',
};

Map<String, dynamic> _activePlanJson() => {
  'id': 'plan-1',
  'user_id': 'test-user',
  'plan_type': 'ppl',
  'start_date': '2026-03-26T00:00:00Z',
  'created_at': '2026-03-26T00:00:00Z',
  'updated_at': '2026-03-26T00:00:00Z',
};

Map<String, dynamic> _todayWorkoutJson() => {
  'plan_type': 'ppl',
  'day_number': 1,
  'day_label': 'Push Day',
  'total_days': 6,
  'completed_sessions': 2,
  'exercises': [
    {
      'id': 1,
      'exercise_name': 'Bench Press',
      'primary_muscle': 'chest',
      'equipment': 'barbell',
    },
  ],
};

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('WorkoutApi', () {
    test('createSession posts and parses WorkoutSession', () async {
      final mock = MockClient((request) async {
        expect(request.method, 'POST');
        expect(request.url.path, '/mobile/api/v1/workouts/sessions');
        expect(request.headers['X-User-Id'], 'test-user');

        final body = jsonDecode(request.body) as Map<String, dynamic>;
        expect(body['title'], 'Leg Day');
        expect((body['exercises'] as List).length, 1);

        return http.Response(jsonEncode(_sessionJson()), 201);
      });

      final api = WorkoutApi(_buildClient(mock));
      final session = await api.createSession(
        CreateSessionRequest(
          title: 'Leg Day',
          exercises: [
            CreateExerciseRequest(
              exerciseId: 1,
              sets: [CreateSetRequest(setNumber: 1, reps: 10, weightKg: 60)],
            ),
          ],
        ),
      );

      expect(session.id, 'session-1');
      expect(session.exercises.first.exerciseName, 'Bench Press');
      expect(session.exercises.first.sets.first.weightKg, 60.0);
    });

    test('getSession fetches and parses a single session', () async {
      final mock = MockClient((request) async {
        expect(request.method, 'GET');
        expect(request.url.path, '/mobile/api/v1/workouts/sessions/session-1');
        return http.Response(jsonEncode(_sessionJson(isCompleted: true)), 200);
      });

      final api = WorkoutApi(_buildClient(mock));
      final session = await api.getSession('session-1');

      expect(session.id, 'session-1');
      expect(session.isCompleted, true);
      expect(session.durationSec, 3600);
    });

    test('updateSession patches title and parses response', () async {
      final mock = MockClient((request) async {
        expect(request.method, 'PATCH');
        expect(request.url.path, '/mobile/api/v1/workouts/sessions/session-1');

        final body = jsonDecode(request.body) as Map<String, dynamic>;
        expect(body['title'], 'Updated Title');

        return http.Response(jsonEncode(_sessionJson()), 200);
      });

      final api = WorkoutApi(_buildClient(mock));
      final session = await api.updateSession(
        'session-1',
        UpdateSessionRequest(title: 'Updated Title'),
      );

      expect(session.id, 'session-1');
    });

    test('finishSession marks session complete', () async {
      final mock = MockClient((request) async {
        expect(request.method, 'POST');
        expect(
          request.url.path,
          '/mobile/api/v1/workouts/sessions/session-1/finish',
        );
        return http.Response(jsonEncode(_sessionJson(isCompleted: true)), 200);
      });

      final api = WorkoutApi(_buildClient(mock));
      final session = await api.finishSession('session-1');

      expect(session.isCompleted, true);
      expect(session.finishedAt, isNotNull);
    });

    test('getHistory fetches paginated session list', () async {
      final mock = MockClient((request) async {
        expect(request.method, 'GET');
        expect(request.url.path, '/mobile/api/v1/workouts/sessions/history');
        expect(request.url.queryParameters['completed_only'], 'true');
        expect(request.url.queryParameters['page'], '1');

        return http.Response(
          jsonEncode({
            'items': [_sessionJson(isCompleted: true)],
            'total': 1,
            'page': 1,
            'page_size': 20,
            'total_pages': 1,
          }),
          200,
        );
      });

      final api = WorkoutApi(_buildClient(mock));
      final page = await api.getHistory(completedOnly: true);

      expect(page.items.length, 1);
      expect(page.total, 1);
      expect(page.items.first.title, 'Push Day');
    });

    test('getExerciseAnalytics fetches and parses analytics', () async {
      final mock = MockClient((request) async {
        expect(request.method, 'GET');
        expect(
          request.url.path,
          '/mobile/api/v1/workouts/sessions/exercises/1/analytics',
        );

        return http.Response(
          jsonEncode({
            'exercise_id': 1,
            'exercise_name': 'Bench Press',
            'total_sessions': 12,
            'lifetime_volume': 25000.0,
            'last_session_volume': 2400.0,
            'personal_best_weight': 82.5,
            'estimated_1rm': 95.0,
            'recent_trend': [
              {
                'session_id': 'ses-1',
                'date': '2026-03-20T10:00:00Z',
                'volume': 2400.0,
                'max_weight': 80.0,
                'total_reps': 30,
                'estimated_1rm': 92.5,
              },
              {
                'session_id': 'ses-2',
                'date': '2026-03-23T10:00:00Z',
                'volume': 2500.0,
                'max_weight': 82.5,
                'total_reps': 28,
                'estimated_1rm': 95.0,
              },
            ],
          }),
          200,
        );
      });

      final api = WorkoutApi(_buildClient(mock));
      final analytics = await api.getExerciseAnalytics(1);

      expect(analytics.exerciseId, 1);
      expect(analytics.exerciseName, 'Bench Press');
      expect(analytics.totalSessions, 12);
      expect(analytics.personalBestWeight, 82.5);
      expect(analytics.estimated1rm, 95.0);
      expect(analytics.recentTrend.length, 2);
      expect(analytics.recentTrend.last.maxWeight, 82.5);
      expect(analytics.recentTrend.last.totalReps, 28);
    });

    test('getUserAnalytics fetches user summary', () async {
      final mock = MockClient((request) async {
        expect(request.method, 'GET');
        expect(request.url.path, '/mobile/api/v1/workouts/sessions/analytics');

        return http.Response(
          jsonEncode({
            'user_id': 'test-user',
            'total_sessions': 50,
            'completed_sessions': 45,
            'total_volume': 150000.0,
            'personal_bests': [
              {
                'exercise_id': 1,
                'exercise_name': 'Bench Press',
                'total_sessions': 12,
                'lifetime_volume': 25000.0,
                'last_session_volume': null,
                'personal_best_weight': 82.5,
                'estimated_1rm': 95.0,
                'recent_trend': [],
              },
            ],
          }),
          200,
        );
      });

      final api = WorkoutApi(_buildClient(mock));
      final summary = await api.getUserAnalytics();

      expect(summary.userId, 'test-user');
      expect(summary.totalSessions, 50);
      expect(summary.completedSessions, 45);
      expect(summary.totalVolume, 150000.0);
      expect(summary.personalBests.length, 1);
      expect(summary.personalBests.first.personalBestWeight, 82.5);
    });

    test('deleteSession sends DELETE and returns void', () async {
      final mock = MockClient((request) async {
        expect(request.method, 'DELETE');
        expect(request.url.path, '/mobile/api/v1/workouts/sessions/session-1');
        return http.Response('', 204);
      });

      final api = WorkoutApi(_buildClient(mock));
      await expectLater(api.deleteSession('session-1'), completes);
    });

    test('searchExercises uses /exercises/search endpoint', () async {
      final mock = MockClient((request) async {
        expect(request.method, 'GET');
        expect(request.url.path, '/mobile/api/v1/exercises/search');
        expect(request.url.queryParameters['q'], 'bench');

        return http.Response(
          jsonEncode({
            'items': [
              {
                'id': 1,
                'exercise_name': 'Barbell Bench Press',
                'primary_muscle': 'Chest',
                'secondary_muscles': [],
                'equipment': 'Barbell',
                'difficulty': null,
                'category': null,
                'instructions': null,
                'image_url': null,
              },
            ],
            'total': 1,
            'page': 1,
            'page_size': 50,
            'total_pages': 1,
          }),
          200,
        );
      });

      final api = WorkoutApi(_buildClient(mock));
      final page = await api.searchExercises(q: 'bench');

      expect(page.items.length, 1);
      expect(page.items.first.name, 'Barbell Bench Press');
      expect(page.items.first.primaryMuscle, 'Chest');
    });

    test('getWeeklyStats fetches weekly aggregation', () async {
      final mock = MockClient((request) async {
        expect(request.method, 'GET');
        expect(
          request.url.path,
          '/mobile/api/v1/workouts/sessions/stats/weekly',
        );

        return http.Response(
          jsonEncode([
            {
              'week_start': '2026-03-16',
              'session_count': 4,
              'total_volume': 12000.0,
              'total_duration_sec': 14400,
              'avg_duration_sec': 3600,
            },
            {
              'week_start': '2026-03-23',
              'session_count': 3,
              'total_volume': 9000.0,
              'total_duration_sec': 10800,
              'avg_duration_sec': 3600,
            },
          ]),
          200,
        );
      });

      final api = WorkoutApi(_buildClient(mock));
      final stats = await api.getWeeklyStats();

      expect(stats.length, 2);
      expect(stats.first.weekStart, '2026-03-16');
      expect(stats.first.sessionCount, 4);
      expect(stats.first.totalVolume, 12000.0);
      expect(stats.last.sessionCount, 3);
    });

    test(
      'getTodayWorkout returns null and skips /today when no active plan',
      () async {
        var activePlanCalls = 0;
        var todayCalls = 0;
        final mock = MockClient((request) async {
          if (request.url.path == '/mobile/api/v1/plans/active') {
            activePlanCalls += 1;
            return http.Response(jsonEncode({'detail': 'No active plan'}), 404);
          }
          if (request.url.path == '/mobile/api/v1/plans/active/today') {
            todayCalls += 1;
            return http.Response(jsonEncode({'detail': 'Unexpected'}), 500);
          }
          return http.Response(jsonEncode({'detail': 'Unhandled path'}), 500);
        });

        final api = WorkoutApi(_buildClient(mock));

        final first = await api.getTodayWorkout();
        final second = await api.getTodayWorkout();

        expect(first, isNull);
        expect(second, isNull);
        expect(activePlanCalls, 1);
        expect(todayCalls, 0);
      },
    );

    test(
      'getTodayWorkout uses saved local plan when remote plan is unavailable',
      () async {
        await LocalPlanService.setPlanType('ppl');

        var activePlanCalls = 0;
        var todayCalls = 0;
        final mock = MockClient((request) async {
          if (request.url.path == '/mobile/api/v1/plans/active') {
            activePlanCalls += 1;
            return http.Response(jsonEncode({'detail': 'No active plan'}), 404);
          }
          if (request.url.path == '/mobile/api/v1/plans/active/today') {
            todayCalls += 1;
            return http.Response(jsonEncode({'detail': 'Unexpected'}), 500);
          }
          return http.Response(jsonEncode({'detail': 'Unhandled path'}), 500);
        });

        final api = WorkoutApi(_buildClient(mock));
        final workout = await api.getTodayWorkout();

        expect(workout, isNotNull);
        expect(workout!.planType, 'ppl');
        expect(workout.exercises, isNotEmpty);
        expect(activePlanCalls, 0);
        expect(todayCalls, 0);
      },
    );

    test('getTodayWorkout fetches /today when active plan exists', () async {
      var activePlanCalls = 0;
      var todayCalls = 0;
      final mock = MockClient((request) async {
        if (request.url.path == '/mobile/api/v1/plans/active') {
          activePlanCalls += 1;
          return http.Response(jsonEncode(_activePlanJson()), 200);
        }
        if (request.url.path == '/mobile/api/v1/plans/active/today') {
          todayCalls += 1;
          return http.Response(jsonEncode(_todayWorkoutJson()), 200);
        }
        return http.Response(jsonEncode({'detail': 'Unhandled path'}), 500);
      });

      final api = WorkoutApi(_buildClient(mock));
      final workout = await api.getTodayWorkout();

      expect(workout, isNotNull);
      expect(workout!.dayLabel, 'Push Day');
      expect(activePlanCalls, 1);
      expect(todayCalls, 1);
    });
  });
}
