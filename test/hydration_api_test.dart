import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:flexicurl_client_mobile/src/core/network/api_client.dart';
import 'package:flexicurl_client_mobile/src/features/hydration/data/hydration_api.dart';

ApiClient _buildClient(MockClient mockClient) {
  return ApiClient(
    baseUrl: 'http://localhost/mobile/api/v1',
    userId: 'test-user',
    httpClient: mockClient,
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('HydrationApi', () {
    test('createLog posts and parses HydrationLog', () async {
      final mock = MockClient((request) async {
        expect(request.method, 'POST');
        expect(request.url.path, '/mobile/api/v1/hydration/logs');
        expect(request.headers['X-User-Id'], 'test-user');

        final body = jsonDecode(request.body) as Map<String, dynamic>;
        expect(body['amount_ml'], 500);

        return http.Response(
          jsonEncode({
            'id': '1',
            'user_id': 'test-user',
            'amount_ml': 500.0,
            'recorded_at': '2026-03-26T08:00:00Z',
            'notes': null,
          }),
          201,
        );
      });

      final api = HydrationApi(_buildClient(mock));
      final log = await api.createLog(amountMl: 500);

      expect(log.id, '1');
      expect(log.amountMl, 500.0);
      expect(log.userId, 'test-user');
    });

    test('updateLog patches and parses HydrationLog', () async {
      final mock = MockClient((request) async {
        expect(request.method, 'PATCH');
        expect(request.url.path, '/mobile/api/v1/hydration/logs/7');

        final body = jsonDecode(request.body) as Map<String, dynamic>;
        expect(body['amount_ml'], 750);

        return http.Response(
          jsonEncode({
            'id': '7',
            'user_id': 'test-user',
            'amount_ml': 750.0,
            'recorded_at': '2026-03-26T09:00:00Z',
            'notes': 'updated',
          }),
          200,
        );
      });

      final api = HydrationApi(_buildClient(mock));
      final log = await api.updateLog(logId: '7', amountMl: 750, notes: 'updated');

      expect(log.id, '7');
      expect(log.amountMl, 750.0);
      expect(log.notes, 'updated');
    });

    test('deleteLog sends DELETE request', () async {
      final mock = MockClient((request) async {
        expect(request.method, 'DELETE');
        expect(request.url.path, '/mobile/api/v1/hydration/logs/3');
        return http.Response('', 204);
      });

      final api = HydrationApi(_buildClient(mock));
      await api.deleteLog('3'); // should not throw
    });

    test('getDailySummary fetches and parses HydrationDailySummary', () async {
      final mock = MockClient((request) async {
        expect(request.method, 'GET');
        expect(request.url.path, '/mobile/api/v1/hydration/daily-summary');

        return http.Response(
          jsonEncode({
            'date': '2026-03-26',
            'total_ml': 1500.0,
            'daily_goal_ml': 2500.0,
            'remaining_ml': 1000.0,
            'percent_complete': 60.0,
            'entries': [
              {
                'id': '1',
                'user_id': 'test-user',
                'amount_ml': 500.0,
                'recorded_at': '2026-03-26T07:00:00Z',
                'notes': null,
              },
              {
                'id': '2',
                'user_id': 'test-user',
                'amount_ml': 1000.0,
                'recorded_at': '2026-03-26T10:00:00Z',
                'notes': null,
              },
            ],
          }),
          200,
        );
      });

      final api = HydrationApi(_buildClient(mock));
      final summary = await api.getDailySummary();

      expect(summary.date, '2026-03-26');
      expect(summary.totalMl, 1500.0);
      expect(summary.dailyGoalMl, 2500.0);
      expect(summary.remainingMl, 1000.0);
      expect(summary.percentComplete, 60.0);
      expect(summary.entries.length, 2);
      expect(summary.entries.first.amountMl, 500.0);
    });

    test('getWeeklySummary fetches and parses list', () async {
      final mock = MockClient((request) async {
        expect(request.method, 'GET');
        expect(request.url.path, '/mobile/api/v1/hydration/weekly-summary');
        expect(request.url.queryParameters['days'], '7');

        return http.Response(
          jsonEncode([
            {'date': '2026-03-20', 'total_ml': 2600.0, 'goal_ml': 2500.0, 'reached': true},
            {'date': '2026-03-21', 'total_ml': 1800.0, 'goal_ml': 2500.0, 'reached': false},
            {'date': '2026-03-22', 'total_ml': 2500.0, 'goal_ml': 2500.0, 'reached': true},
            {'date': '2026-03-23', 'total_ml': 3000.0, 'goal_ml': 2500.0, 'reached': true},
            {'date': '2026-03-24', 'total_ml': 2200.0, 'goal_ml': 2500.0, 'reached': false},
            {'date': '2026-03-25', 'total_ml': 2700.0, 'goal_ml': 2500.0, 'reached': true},
            {'date': '2026-03-26', 'total_ml': 1500.0, 'goal_ml': 2500.0, 'reached': false},
          ]),
          200,
        );
      });

      final api = HydrationApi(_buildClient(mock));
      final weekly = await api.getWeeklySummary();

      expect(weekly.length, 7);
      expect(weekly.first.date, '2026-03-20');
      expect(weekly.first.reached, true);
      expect(weekly.last.totalMl, 1500.0);
      expect(weekly.last.reached, false);
    });

    test('getReminder fetches and parses HydrationReminder', () async {
      final mock = MockClient((request) async {
        expect(request.method, 'GET');
        expect(request.url.path, '/mobile/api/v1/hydration/reminder');

        return http.Response(
          jsonEncode({
            'date': '2026-03-26',
            'total_ml': 1500.0,
            'daily_goal_ml': 2500.0,
            'remaining_ml': 1000.0,
            'percent_complete': 60.0,
            'reminder_hour': 20,
            'should_notify': true,
            'message': 'You still need 1000 ml to hit your daily goal!',
          }),
          200,
        );
      });

      final api = HydrationApi(_buildClient(mock));
      final reminder = await api.getReminder();

      expect(reminder.shouldNotify, true);
      expect(reminder.remainingMl, 1000.0);
      expect(reminder.reminderHour, 20);
      expect(reminder.message, contains('1000 ml'));
    });
  });
}
