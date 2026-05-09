import 'dart:math' show min, max;

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/theme/app_colors.dart';
import '../data/workout_api.dart';
import '../models/workout_models.dart';

/// Hevy-style per-exercise progress screen.
/// When [workoutApi] is provided, loads real analytics from the backend.
class ExerciseProgressPage extends StatefulWidget {
  const ExerciseProgressPage({
    super.key,
    required this.exerciseId,
    required this.exerciseName,
    this.muscle,
    this.workoutApi,
  });

  final int exerciseId;
  final String exerciseName;
  final String? muscle;
  final WorkoutApi? workoutApi;

  @override
  State<ExerciseProgressPage> createState() => _ExerciseProgressPageState();
}

class _ExerciseProgressPageState extends State<ExerciseProgressPage> {
  ExerciseAnalytics? _analytics;
  bool _loading = false;
  String? _error;
  bool _isTemplateExercise = false;

  @override
  void initState() {
    super.initState();
    if (widget.exerciseId <= 0) {
      _isTemplateExercise = true;
      _loading = false;
    } else if (widget.workoutApi != null) {
      _loadAnalytics();
    } else {
      _error = 'Workout API is not configured.';
    }
  }

  Future<void> _loadAnalytics() async {
    if (widget.exerciseId <= 0) {
      setState(() {
        _isTemplateExercise = true;
        _loading = false;
        _error = null;
      });
      return;
    }

    if (widget.workoutApi == null) {
      setState(() {
        _loading = false;
        _error = 'Workout API is not configured.';
      });
      return;
    }

    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final data = await widget.workoutApi!.getExerciseAnalytics(
        widget.exerciseId,
      );
      if (mounted) {
        setState(() {
          _analytics = data;
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString();
          _loading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    // Build display data from real analytics only
    final List<double> weights;
    final List<String> labels;
    final double bestWeight;
    final int sessionCount;

    if (_analytics != null) {
      weights = _analytics!.recentTrend.map((p) => p.maxWeight).toList();
      labels = _analytics!.recentTrend.map((p) {
        final d = p.date;
        return '${_monthAbbr(d.month)} ${d.day}';
      }).toList();
      bestWeight = _analytics!.personalBestWeight;
      sessionCount = _analytics!.totalSessions;
    } else {
      weights = const [];
      labels = const [];
      bestWeight = 0.0;
      sessionCount = 0;
    }

    return Scaffold(
      backgroundColor: AppColors.scaffoldBg,
      appBar: AppBar(
        backgroundColor: AppColors.white,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(
            Icons.arrow_back_ios_new_rounded,
            color: AppColors.textPrimary,
            size: 20,
          ),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              widget.exerciseName,
              style: GoogleFonts.poppins(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary,
              ),
            ),
            if (widget.muscle != null)
              Text(
                widget.muscle!,
                style: GoogleFonts.poppins(
                  fontSize: 12,
                  color: AppColors.textMuted,
                ),
              ),
          ],
        ),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _isTemplateExercise
          ? _TemplateExerciseBody(
              exerciseName: widget.exerciseName,
              muscle: widget.muscle,
            )
          : _error != null && _analytics == null
          ? _ErrorBody(message: _error!, onRetry: _loadAnalytics)
          : widget.workoutApi != null && _analytics == null
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.fitness_center_rounded,
                      size: 48,
                      color: AppColors.textMuted.withAlpha(120),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'No data yet',
                      style: GoogleFonts.poppins(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Start logging ${widget.exerciseName} to track your progress here.',
                      textAlign: TextAlign.center,
                      style: GoogleFonts.poppins(
                        fontSize: 13,
                        color: AppColors.textMuted,
                        height: 1.5,
                      ),
                    ),
                  ],
                ),
              ),
            )
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                // ── Stats row ──────────────────────────────────────────
                Row(
                  children: [
                    _StatCard(
                      label: 'Best Weight',
                      value: '${bestWeight.toStringAsFixed(1)} kg',
                      icon: Icons.emoji_events_rounded,
                      iconColor: const Color(0xFFF59E0B),
                    ),
                    const SizedBox(width: 12),
                    _StatCard(
                      label: 'Sessions',
                      value: '$sessionCount',
                      icon: Icons.bar_chart_rounded,
                      iconColor: AppColors.accent,
                    ),
                  ],
                ),
                if (_analytics != null) ...[
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      _StatCard(
                        label: 'Est. 1RM',
                        value:
                            '${_analytics!.estimated1rm.toStringAsFixed(1)} kg',
                        icon: Icons.trending_up_rounded,
                        iconColor: AppColors.accentGreen,
                      ),
                      const SizedBox(width: 12),
                      _StatCard(
                        label: 'Lifetime Vol.',
                        value: _fmtVolume(_analytics!.lifetimeVolume),
                        icon: Icons.monitor_weight_outlined,
                        iconColor: const Color(0xFF7C3AED),
                      ),
                    ],
                  ),
                ],
                const SizedBox(height: 16),

                // ── Progress chart ─────────────────────────────────────
                Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withAlpha(8),
                        blurRadius: 10,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Max Weight',
                        style: GoogleFonts.poppins(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      Text(
                        'kg per session',
                        style: GoogleFonts.poppins(
                          fontSize: 11,
                          color: AppColors.textMuted,
                        ),
                      ),
                      const SizedBox(height: 12),
                      SizedBox(
                        height: 200,
                        child: weights.isEmpty
                            ? Center(
                                child: Text(
                                  'No data yet',
                                  style: GoogleFonts.poppins(
                                    color: AppColors.textMuted,
                                  ),
                                ),
                              )
                            : CustomPaint(
                                painter: _ChartPainter(
                                  weights: weights,
                                  labels: labels,
                                  lineColor: AppColors.accentGreen,
                                ),
                                child: const SizedBox.expand(),
                              ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                // ── Recent sessions list ───────────────────────────────
                Text(
                  'Recent Sessions',
                  style: GoogleFonts.poppins(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 10),
                if (_analytics != null)
                  ..._analytics!.recentTrend.reversed
                      .take(5)
                      .map((p) => _SessionRowApi(point: p))
                else if (widget.workoutApi == null)
                  ...List.generate(min(5, weights.length), (i) {
                    final idx = weights.length - 1 - i;
                    return _SessionRowLocal(
                      label: labels[idx],
                      weight: weights[idx],
                    );
                  }),
              ],
            ),
    );
  }

  String _monthAbbr(int month) => const [
    '',
    'Jan',
    'Feb',
    'Mar',
    'Apr',
    'May',
    'Jun',
    'Jul',
    'Aug',
    'Sep',
    'Oct',
    'Nov',
    'Dec',
  ][month];

  String _fmtVolume(double v) {
    if (v >= 1000) {
      return '${(v / 1000).toStringAsFixed(1)}k kg';
    }
    return '${v.toStringAsFixed(0)} kg';
  }
}

// ── Error body ───────────────────────────────────────────────────────────────

class _ErrorBody extends StatelessWidget {
  const _ErrorBody({required this.message, required this.onRetry});
  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.error_outline_rounded,
              size: 44,
              color: AppColors.textMuted,
            ),
            const SizedBox(height: 12),
            Text(
              message,
              style: GoogleFonts.poppins(
                fontSize: 12,
                color: AppColors.textMuted,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh_rounded),
              label: Text('Retry', style: GoogleFonts.poppins()),
            ),
          ],
        ),
      ),
    );
  }
}

class _TemplateExerciseBody extends StatelessWidget {
  const _TemplateExerciseBody({
    required this.exerciseName,
    this.muscle,
  });

  final String exerciseName;
  final String? muscle;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.fitness_center_rounded,
              size: 48,
              color: AppColors.textMuted.withAlpha(120),
            ),
            const SizedBox(height: 12),
            Text(
              exerciseName,
              textAlign: TextAlign.center,
              style: GoogleFonts.poppins(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary,
              ),
            ),
            if (muscle != null) ...[
              const SizedBox(height: 4),
              Text(
                muscle!,
                style: GoogleFonts.poppins(
                  fontSize: 13,
                  color: AppColors.textMuted,
                ),
              ),
            ],
            const SizedBox(height: 12),
            Text(
              'This exercise comes from your saved workout plan, so detailed analytics are not available yet.',
              textAlign: TextAlign.center,
              style: GoogleFonts.poppins(
                fontSize: 13,
                color: AppColors.textMuted,
                height: 1.5,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Log a few real sessions for this exercise to unlock progress charts.',
              textAlign: TextAlign.center,
              style: GoogleFonts.poppins(
                fontSize: 12,
                color: AppColors.textSecondary,
                height: 1.5,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Stat card ─────────────────────────────────────────────────────────────────

class _StatCard extends StatelessWidget {
  const _StatCard({
    required this.label,
    required this.value,
    required this.icon,
    required this.iconColor,
  });
  final String label;
  final String value;
  final IconData icon;
  final Color iconColor;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withAlpha(8),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: iconColor.withAlpha(20),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: iconColor, size: 20),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    value,
                    style: GoogleFonts.poppins(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  Text(
                    label,
                    style: GoogleFonts.poppins(
                      fontSize: 11,
                      color: AppColors.textMuted,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Session rows ─────────────────────────────────────────────────────────────

class _SessionRowApi extends StatelessWidget {
  const _SessionRowApi({required this.point});
  final PerformancePoint point;

  @override
  Widget build(BuildContext context) {
    final d = point.date;
    const months = [
      '',
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    final label = '${months[d.month]} ${d.day}';
    return _SessionRowBase(
      label: label,
      weight: point.maxWeight,
      subtitle:
          '${point.totalReps} reps · ${point.volume.toStringAsFixed(0)} kg vol',
    );
  }
}

class _SessionRowLocal extends StatelessWidget {
  const _SessionRowLocal({required this.label, required this.weight});
  final String label;
  final double weight;

  @override
  Widget build(BuildContext context) {
    return _SessionRowBase(label: label, weight: weight);
  }
}

class _SessionRowBase extends StatelessWidget {
  const _SessionRowBase({
    required this.label,
    required this.weight,
    this.subtitle,
  });
  final String label;
  final double weight;
  final String? subtitle;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(6),
            blurRadius: 6,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: Row(
        children: [
          const Icon(
            Icons.calendar_today_rounded,
            size: 16,
            color: AppColors.textMuted,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: GoogleFonts.poppins(
                    fontSize: 13,
                    color: AppColors.textSecondary,
                  ),
                ),
                if (subtitle != null)
                  Text(
                    subtitle!,
                    style: GoogleFonts.poppins(
                      fontSize: 11,
                      color: AppColors.textMuted,
                    ),
                  ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: AppColors.accentGreenSoft,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              '${weight.toStringAsFixed(1)} kg',
              style: GoogleFonts.poppins(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: AppColors.accentGreen,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Chart painter ─────────────────────────────────────────────────────────────

class _ChartPainter extends CustomPainter {
  const _ChartPainter({
    required this.weights,
    required this.labels,
    required this.lineColor,
  });

  final List<double> weights;
  final List<String> labels;
  final Color lineColor;

  static const _padLeft = 46.0;
  static const _padRight = 12.0;
  static const _padTop = 12.0;
  static const _padBottom = 32.0;

  @override
  void paint(Canvas canvas, Size size) {
    if (weights.isEmpty) {
      return;
    }

    final chartLeft = _padLeft;
    final chartRight = size.width - _padRight;
    final chartTop = _padTop;
    final chartBottom = size.height - _padBottom;
    final chartWidth = chartRight - chartLeft;
    final chartHeight = chartBottom - chartTop;

    // Y axis range with 10% padding
    final rawMax = weights.reduce(max);
    final rawMin = weights.reduce(min);
    final rawRange = rawMax == rawMin ? 10.0 : rawMax - rawMin;
    final yMin = rawMin - rawRange * 0.15;
    final yMax = rawMax + rawRange * 0.15;
    final yRange = yMax - yMin;

    Offset toPixel(int i, double v) {
      final x = weights.length == 1
          ? chartLeft + chartWidth * 0.5
          : chartLeft + chartWidth * i / (weights.length - 1);
      final y = chartBottom - chartHeight * (v - yMin) / yRange;
      return Offset(x, y);
    }

    // Grid lines (4 horizontal)
    final gridPaint = Paint()
      ..color = AppColors.divider
      ..strokeWidth = 1;
    for (var i = 0; i <= 4; i++) {
      final y = chartTop + chartHeight * i / 4;
      canvas.drawLine(Offset(chartLeft, y), Offset(chartRight, y), gridPaint);
    }

    // Gradient fill under the line
    if (weights.length > 1) {
      final fillPath = Path();
      for (var i = 0; i < weights.length; i++) {
        final p = toPixel(i, weights[i]);
        if (i == 0) {
          fillPath.moveTo(p.dx, p.dy);
        } else {
          final prev = toPixel(i - 1, weights[i - 1]);
          final cpx = (prev.dx + p.dx) / 2;
          fillPath.cubicTo(cpx, prev.dy, cpx, p.dy, p.dx, p.dy);
        }
      }
      final lastPt = toPixel(weights.length - 1, weights.last);
      final firstPt = toPixel(0, weights.first);
      fillPath.lineTo(lastPt.dx, chartBottom);
      fillPath.lineTo(firstPt.dx, chartBottom);
      fillPath.close();

      final fillPaint = Paint()
        ..shader =
            LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [lineColor.withAlpha(70), lineColor.withAlpha(0)],
            ).createShader(
              Rect.fromLTRB(chartLeft, chartTop, chartRight, chartBottom),
            );
      canvas.drawPath(fillPath, fillPaint);
    }

    // Line
    if (weights.length > 1) {
      final linePath = Path();
      for (var i = 0; i < weights.length; i++) {
        final p = toPixel(i, weights[i]);
        if (i == 0) {
          linePath.moveTo(p.dx, p.dy);
        } else {
          final prev = toPixel(i - 1, weights[i - 1]);
          final cpx = (prev.dx + p.dx) / 2;
          linePath.cubicTo(cpx, prev.dy, cpx, p.dy, p.dx, p.dy);
        }
      }
      canvas.drawPath(
        linePath,
        Paint()
          ..color = lineColor
          ..strokeWidth = 2.5
          ..style = PaintingStyle.stroke
          ..strokeCap = StrokeCap.round
          ..strokeJoin = StrokeJoin.round,
      );
    }

    // Dots
    final dotFill = Paint()
      ..color = lineColor
      ..style = PaintingStyle.fill;
    final dotBorder = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.fill;
    for (var i = 0; i < weights.length; i++) {
      final p = toPixel(i, weights[i]);
      canvas.drawCircle(p, 6.5, dotBorder);
      canvas.drawCircle(p, 4.5, dotFill);
    }

    // Y-axis labels
    final tp = TextPainter(textDirection: TextDirection.ltr);
    for (var i = 0; i <= 4; i++) {
      final y = chartTop + chartHeight * i / 4;
      final v = yMax - yRange * i / 4;
      tp.text = TextSpan(
        text: v.toStringAsFixed(0),
        style: const TextStyle(
          fontSize: 10,
          color: AppColors.textMuted,
          fontWeight: FontWeight.w500,
        ),
      );
      tp.layout();
      tp.paint(canvas, Offset(chartLeft - tp.width - 6, y - tp.height / 2));
    }

    // X-axis labels (show every 2nd if many points)
    final step = weights.length > 6 ? 2 : 1;
    for (var i = 0; i < weights.length; i += step) {
      final p = toPixel(i, weights[i]);
      tp.text = TextSpan(
        text: labels[i],
        style: const TextStyle(fontSize: 9, color: AppColors.textMuted),
      );
      tp.layout();
      tp.paint(canvas, Offset(p.dx - tp.width / 2, chartBottom + 6));
    }
  }

  @override
  bool shouldRepaint(covariant _ChartPainter old) =>
      old.weights != weights || old.labels != labels;
}
