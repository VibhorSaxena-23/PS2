import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:pedometer/pedometer.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Singleton service that wraps the device pedometer.
///
/// Call [init] once at app startup. Widgets listen via [addListener].
class StepService extends ChangeNotifier {
  StepService._();
  static final StepService instance = StepService._();

  // ── Constants ────────────────────────────────────────────────────────────────

  static const int dailyGoal = 10000;
  /// Approximate active calories per step for an average adult (~70 kg).
  static const double kcalPerStep = 0.04;
  /// Approximate stride length in metres.
  static const double strideM = 0.762;

  // ── State ────────────────────────────────────────────────────────────────────

  StreamSubscription<StepCount>? _sub;
  bool _available = false;
  bool _permissionDenied = false;
  int _todaySteps = 0;
  List<int> _weekSteps = List.filled(7, 0); // oldest → newest (today = index 6)

  bool get available => _available;
  bool get permissionDenied => _permissionDenied;
  int get todaySteps => _todaySteps;
  List<int> get weekSteps => List.unmodifiable(_weekSteps);
  double get activeCalories => _todaySteps * kcalPerStep;
  double get distanceKm => (_todaySteps * strideM) / 1000;
  double get progress => (_todaySteps / dailyGoal).clamp(0.0, 1.0);

  // ── Init ─────────────────────────────────────────────────────────────────────

  Future<void> init() async {
    // Not supported on web or desktop.
    if (kIsWeb) return;
    final platform = defaultTargetPlatform;
    if (platform != TargetPlatform.android && platform != TargetPlatform.iOS) {
      return;
    }

    // Android 10+ requires runtime ACTIVITY_RECOGNITION permission.
    if (platform == TargetPlatform.android) {
      final status = await Permission.activityRecognition.request();
      if (!status.isGranted) {
        _permissionDenied = true;
        notifyListeners();
        return;
      }
    }

    // Load persisted weekly history before subscribing.
    await _loadWeekHistory();

    try {
      _sub = Pedometer.stepCountStream.listen(
        _onStepCount,
        onError: (_) {
          _available = false;
          notifyListeners();
        },
        cancelOnError: true,
      );
      _available = true;
    } catch (_) {
      _available = false;
    }
    notifyListeners();
  }

  // ── Pedometer callback ───────────────────────────────────────────────────────

  Future<void> _onStepCount(StepCount event) async {
    final prefs = await SharedPreferences.getInstance();
    final today = _dayKey(DateTime.now());
    final savedDate = prefs.getString('steps_baseline_date');

    if (savedDate != today) {
      // New day — reset the daily baseline.
      await prefs.setString('steps_baseline_date', today);
      await prefs.setInt('steps_baseline', event.steps);
      // Persist yesterday's total before resetting.
      if (savedDate != null) {
        final old = prefs.getInt('steps_baseline') ?? event.steps;
        await prefs.setInt('steps_day_$savedDate', event.steps - old);
      }
    }

    final baseline = prefs.getInt('steps_baseline') ?? event.steps;
    _todaySteps = (event.steps - baseline).clamp(0, 999999);

    // Persist today's current total for history.
    await prefs.setInt('steps_day_$today', _todaySteps);
    await _loadWeekHistory();
    notifyListeners();
  }

  // ── History ──────────────────────────────────────────────────────────────────

  Future<void> _loadWeekHistory() async {
    final prefs = await SharedPreferences.getInstance();
    final now = DateTime.now();
    final result = <int>[];
    for (int i = 6; i >= 0; i--) {
      final day = now.subtract(Duration(days: i));
      final key = 'steps_day_${_dayKey(day)}';
      result.add(prefs.getInt(key) ?? 0);
    }
    _weekSteps = result;
  }

  // ── Helpers ──────────────────────────────────────────────────────────────────

  static String _dayKey(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }
}
