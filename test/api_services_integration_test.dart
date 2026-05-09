import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:flexicurl_client_mobile/src/core/network/api_client.dart';
import 'package:flexicurl_client_mobile/src/features/dashboard/data/dashboard_api.dart';
import 'package:flexicurl_client_mobile/src/features/gym/data/gym_api.dart';
import 'package:flexicurl_client_mobile/src/features/nutrition/data/nutrition_api.dart';
import 'package:flexicurl_client_mobile/src/features/profile/data/profile_api.dart';
import 'package:flexicurl_client_mobile/src/features/workout/data/workout_api.dart';
import 'package:flexicurl_client_mobile/src/features/workout/models/workout_models.dart';

ApiClient _buildClient(MockClient mockClient) {
  return ApiClient(
    baseUrl: 'http://localhost/mobile/api/v1',
    userId: 'test-user',
    httpClient: mockClient,
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('DashboardApi', () {
    test('parses progress dashboard response', () async {
      final mock = MockClient((request) async {
        expect(request.method, 'GET');
        expect(request.url.path, '/mobile/api/v1/progress/dashboard');
        expect(request.url.queryParameters['weeks'], '12');
        expect(request.headers['X-User-Id'], 'test-user');

        return http.Response(
          jsonEncode({
            'user_id': 'test-user',
            'generated_at': '2026-03-25T08:30:00Z',
            'lookback_weeks': 12,
            'weight_lookback_days': 90,
            'today': {
              'date': '2026-03-25',
              'workouts_completed': 1,
              'workout_volume': 1800.0,
              'workout_duration_sec': 3600,
              'step_count': 7800,
              'step_goal': 10000,
              'hydration_ml': 1300.0,
              'hydration_goal_ml': 2500.0,
              'calories_consumed': 1900.0,
              'calories_target': 2200.0,
              'calories_remaining': 300.0,
              'protein_g': 140.0,
              'carbs_g': 210.0,
              'fat_g': 60.0,
              'fiber_g': 28.0,
            },
            'last_7_days': {
              'active_days': 4,
              'completed_sessions': 5,
              'total_volume': 8400.0,
              'total_duration_sec': 15000,
              'avg_session_duration_sec': 3000,
            },
            'visual_insights': {
              'workout_frequency': [
                {
                  'week_start': '2026-03-02',
                  'session_count': 2,
                  'total_volume': 3000.0,
                  'total_duration_sec': 5000,
                },
              ],
              'weight_points': [
                {'date': '2026-03-20', 'weight_kg': 80.2},
              ],
              'weight_trend': {
                'start_weight_kg': 80.2,
                'latest_weight_kg': 79.7,
                'change_kg': -0.5,
                'change_percent': -0.62,
                'data_points': 2,
              },
            },
          }),
          200,
          headers: {'content-type': 'application/json'},
        );
      });

      final api = DashboardApi(_buildClient(mock));
      final dashboard = await api.getDashboard();

      expect(dashboard.userId, 'test-user');
      expect(dashboard.today.stepCount, 7800);
      expect(dashboard.visualInsights.workoutFrequency.length, 1);
    });
  });

  group('NutritionApi', () {
    test('parses daily nutrition summary', () async {
      final mock = MockClient((request) async {
        expect(request.method, 'GET');
        expect(request.url.path, '/mobile/api/v1/nutrition/summary/daily');

        return http.Response(
          jsonEncode({
            'log_date': '2026-03-25',
            'user_id': 'test-user',
            'total': {
              'calories': 1700.0,
              'protein_g': 120.0,
              'carbs_g': 200.0,
              'fat_g': 45.0,
              'fiber_g': 25.0,
            },
            'meals': [
              {
                'meal_type': 'breakfast',
                'logs': [
                  {
                    'id': 'log-1',
                    'user_id': 'test-user',
                    'food_id': 1,
                    'food_name': 'Oats',
                    'category': 'Grains',
                    'quantity_g': 80.0,
                    'meal_type': 'breakfast',
                    'log_date': '2026-03-25',
                    'calories': 300.0,
                    'protein_g': 10.0,
                    'carbs_g': 50.0,
                    'fat_g': 5.0,
                    'fiber_g': 7.0,
                    'logged_at': '2026-03-25T06:30:00Z',
                  },
                ],
                'subtotal': {
                  'calories': 300.0,
                  'protein_g': 10.0,
                  'carbs_g': 50.0,
                  'fat_g': 5.0,
                  'fiber_g': 7.0,
                },
              },
            ],
            'goal_progress': {
              'calories_target': 2200.0,
              'calories_consumed': 1700.0,
              'calories_remaining': 500.0,
              'protein_target_g': 140.0,
              'protein_consumed_g': 120.0,
              'carbs_target_g': 260.0,
              'carbs_consumed_g': 200.0,
              'fat_target_g': 70.0,
              'fat_consumed_g': 45.0,
              'percent_calories': 77.3,
            },
          }),
          200,
          headers: {'content-type': 'application/json'},
        );
      });

      final api = NutritionApi(_buildClient(mock));
      final summary = await api.getDailySummary();

      expect(summary.userId, 'test-user');
      expect(summary.meals.first.logs.first.foodName, 'Oats');
      expect(summary.goalProgress?.caloriesRemaining, 500.0);
    });
  });

  group('WorkoutApi', () {
    test('parses workout history list', () async {
      final mock = MockClient((request) async {
        expect(request.method, 'GET');
        expect(request.url.path, '/mobile/api/v1/workouts/sessions/history');

        return http.Response(
          jsonEncode({
            'items': [
              {
                'id': 'session-1',
                'user_id': 'test-user',
                'title': 'Push Day',
                'notes': null,
                'started_at': '2026-03-25T09:00:00Z',
                'finished_at': '2026-03-25T10:00:00Z',
                'duration_sec': 3600,
                'is_completed': true,
                'exercises': [
                  {
                    'id': 'exercise-1',
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
                        'rpe': 8.0,
                        'rir': 2,
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
                'created_at': '2026-03-25T09:00:00Z',
                'updated_at': '2026-03-25T10:00:00Z',
              },
            ],
            'total': 1,
            'page': 1,
            'page_size': 20,
            'total_pages': 1,
          }),
          200,
          headers: {'content-type': 'application/json'},
        );
      });

      final api = WorkoutApi(_buildClient(mock));
      final history = await api.getHistory();

      expect(history.total, 1);
      expect(history.items.first.title, 'Push Day');
      expect(history.items.first.exercises.first.exerciseName, 'Bench Press');
    });

    test('sends create session payload and parses response', () async {
      final mock = MockClient((request) async {
        expect(request.method, 'POST');
        expect(request.url.path, '/mobile/api/v1/workouts/sessions');

        final body = jsonDecode(request.body) as Map<String, dynamic>;
        expect(body['title'], 'Leg Day');
        expect((body['exercises'] as List).isNotEmpty, true);

        return http.Response(
          jsonEncode({
            'id': 'session-2',
            'user_id': 'test-user',
            'title': 'Leg Day',
            'notes': null,
            'started_at': '2026-03-25T09:00:00Z',
            'finished_at': null,
            'duration_sec': null,
            'is_completed': false,
            'exercises': [
              {
                'id': 'exercise-2',
                'exercise_id': 2,
                'exercise_name': 'Squat',
                'primary_muscle': 'Legs',
                'equipment': 'Barbell',
                'order_index': 0,
                'notes': null,
                'sets': [
                  {
                    'id': 'set-2',
                    'set_number': 1,
                    'set_type': 'NORMAL',
                    'reps': 8,
                    'weight_kg': 80.0,
                    'rpe': null,
                    'rir': null,
                    'duration_sec': null,
                    'distance_m': null,
                    'note': null,
                    'is_completed': false,
                  },
                ],
                'volume': 0.0,
                'max_weight': 0.0,
              },
            ],
            'total_volume': 0.0,
            'created_at': '2026-03-25T09:00:00Z',
            'updated_at': '2026-03-25T09:00:00Z',
          }),
          201,
          headers: {'content-type': 'application/json'},
        );
      });

      final api = WorkoutApi(_buildClient(mock));
      final request = CreateSessionRequest(
        title: 'Leg Day',
        exercises: [
          CreateExerciseRequest(
            exerciseId: 2,
            sets: [CreateSetRequest(setNumber: 1, reps: 8, weightKg: 80)],
          ),
        ],
      );

      final session = await api.createSession(request);
      expect(session.id, 'session-2');
      expect(session.exercises.first.exerciseId, 2);
    });
  });

  group('GymApi', () {
    test('discovers gyms', () async {
      final mock = MockClient((request) async {
        expect(request.method, 'GET');
        expect(request.url.path, '/mobile/api/v1/gyms/discover');

        return http.Response(
          jsonEncode([
            {
              'id': 'gym-1',
              'name': 'Flexicurl Arena',
              'description': 'Premium gym',
              'location': 'Noida',
              'latitude': 28.5,
              'longitude': 77.3,
              'distance_km': 2.3,
              'plan_count': 3,
              'min_price': 1499.0,
            },
          ]),
          200,
          headers: {'content-type': 'application/json'},
        );
      });

      final api = GymApi(_buildClient(mock));
      final gyms = await api.discoverGyms(lat: 28.6, lng: 77.2);

      expect(gyms.length, 1);
      expect(gyms.first.name, 'Flexicurl Arena');
      expect(gyms.first.planCount, 3);
    });

    test('direct gym join is disabled in favor of plan enrollment', () async {
      final mock = MockClient((request) async {
        fail('joinGym should not call the legacy memberships endpoint');
      });
      final api = GymApi(_buildClient(mock));

      expect(
        () => api.joinGym(gymId: 'gym-1'),
        throwsA(isA<UnsupportedError>()),
      );
    });
  });

  group('ProfileApi', () {
    test('updates profile', () async {
      final mock = MockClient((request) async {
        expect(request.method, 'PATCH');
        expect(request.url.path, '/mobile/api/v1/profile/');

        final body = jsonDecode(request.body) as Map<String, dynamic>;
        expect(body['firstName'], 'Alex');
        expect(body['lastName'], 'Miller');

        return http.Response(
          jsonEncode({
            'id': 'test-user',
            'email': 'alex@example.com',
            'phoneNumber': '+911234567890',
            'firstName': 'Alex',
            'lastName': 'Miller',
            'avatarUrl': null,
            'role': 'MEMBER',
            'isVerified': true,
            'isProfileComplete': true,
            'createdAt': '2026-03-25T09:00:00Z',
            'updatedAt': '2026-03-25T09:15:00Z',
          }),
          200,
          headers: {'content-type': 'application/json'},
        );
      });

      final api = ProfileApi(_buildClient(mock));
      final profile = await api.update(firstName: 'Alex', lastName: 'Miller');

      expect(profile.id, 'test-user');
      expect(profile.firstName, 'Alex');
      expect(profile.lastName, 'Miller');
      expect(profile.displayName, 'Alex Miller');
      expect(profile.isProfileComplete, isTrue);
    });
  });
}
