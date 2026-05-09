import 'dart:math' show pi, min;

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart' show DateFormat;

import '../../../core/theme/app_colors.dart';
import '../../steps/step_service.dart';

class StepsDetailPage extends StatelessWidget {
  const StepsDetailPage({super.key});

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: StepService.instance,
      builder: (context, _) {
        final service = StepService.instance;
        final steps = service.todaySteps;
        final progress = service.progress;
        final weeklySteps = service.weekSteps.toList();
        if (weeklySteps.length == 7 &&
            weeklySteps.every((value) => value == 0)) {
          weeklySteps[6] = steps;
        }
        final labels = List.generate(7, (index) {
          final day = DateTime.now().subtract(Duration(days: 6 - index));
          return DateFormat('E').format(day);
        });
        final activeMinutes = steps == 0 ? 0 : (steps / 120).round();

        return Scaffold(
          backgroundColor: AppColors.scaffoldBg,
          appBar: AppBar(
            backgroundColor: const Color(0xFF16A34A),
            surfaceTintColor: Colors.transparent,
            foregroundColor: Colors.white,
            title: Text(
              'Steps',
              style: GoogleFonts.poppins(
                fontWeight: FontWeight.w700,
                color: Colors.white,
              ),
            ),
            elevation: 0,
          ),
          body: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Container(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Color(0xFF16A34A), Color(0xFF047857)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.all(Radius.circular(24)),
                ),
                padding: const EdgeInsets.all(24),
                child: Column(
                  children: [
                    SizedBox(
                      width: 160,
                      height: 160,
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          CustomPaint(
                            size: const Size(160, 160),
                            painter: _ArcPainter(progress: progress),
                          ),
                          Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                '$steps',
                                style: GoogleFonts.poppins(
                                  fontSize: 30,
                                  fontWeight: FontWeight.w800,
                                  color: Colors.white,
                                  height: 1.0,
                                ),
                              ),
                              Text(
                                'of ${StepService.dailyGoal}',
                                style: GoogleFonts.poppins(
                                  fontSize: 13,
                                  color: Colors.white.withAlpha(180),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      '${(progress * 100).toStringAsFixed(0)}% of daily goal',
                      style: GoogleFonts.poppins(
                        fontSize: 14,
                        color: Colors.white.withAlpha(220),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  _QuickStat(
                    icon: Icons.straighten_rounded,
                    label: 'Distance',
                    value: '${service.distanceKm.toStringAsFixed(1)} km',
                    color: const Color(0xFF16A34A),
                  ),
                  const SizedBox(width: 12),
                  _QuickStat(
                    icon: Icons.local_fire_department_rounded,
                    label: 'Cal Burned',
                    value: '${service.activeCalories.round()} kcal',
                    color: const Color(0xFFEA580C),
                  ),
                  const SizedBox(width: 12),
                  _QuickStat(
                    icon: Icons.timer_rounded,
                    label: 'Moving',
                    value: '$activeMinutes min',
                    color: const Color(0xFF059669),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              _SurfaceCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'This Week',
                      style: GoogleFonts.poppins(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 16),
                    SizedBox(
                      height: 130,
                      child: CustomPaint(
                        painter: _WeeklyBarPainter(
                          values: weeklySteps.map((s) => s.toDouble()).toList(),
                          labels: labels,
                          barColor: const Color(0xFF16A34A),
                          highlightIndex: 6,
                        ),
                        child: const SizedBox.expand(),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              _SurfaceCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Step Source',
                      style: GoogleFonts.poppins(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 12),
                    _SourceRow(
                      label: 'Sensor',
                      value: service.available
                          ? 'Device pedometer active'
                          : 'Waiting for device pedometer',
                    ),
                    _SourceRow(
                      label: 'Permission',
                      value: service.permissionDenied
                          ? 'Activity permission denied'
                          : 'Ready',
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Hourly split will appear when sensor history is available.',
                      style: GoogleFonts.poppins(
                        fontSize: 12,
                        color: AppColors.textMuted,
                        height: 1.4,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _QuickStat extends StatelessWidget {
  const _QuickStat({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
  });

  final IconData icon;
  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withAlpha(8),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          children: [
            Icon(icon, color: color, size: 24),
            const SizedBox(height: 6),
            Text(
              value,
              style: GoogleFonts.poppins(
                fontSize: 14,
                fontWeight: FontWeight.w800,
                color: AppColors.textPrimary,
              ),
            ),
            Text(
              label,
              style: GoogleFonts.poppins(
                fontSize: 10,
                color: AppColors.textMuted,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SurfaceCard extends StatelessWidget {
  const _SurfaceCard({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(8),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: child,
    );
  }
}

class _SourceRow extends StatelessWidget {
  const _SourceRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: GoogleFonts.poppins(
                fontSize: 12,
                color: AppColors.textMuted,
              ),
            ),
          ),
          Flexible(
            child: Text(
              value,
              textAlign: TextAlign.right,
              style: GoogleFonts.poppins(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: AppColors.textSecondary,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}

class _ArcPainter extends CustomPainter {
  const _ArcPainter({required this.progress});

  final double progress;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = min(size.width, size.height) / 2 - 10;
    const start = -pi * 0.75;
    const sweep = pi * 1.5;

    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      start,
      sweep,
      false,
      Paint()
        ..color = Colors.white.withAlpha(50)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 12
        ..strokeCap = StrokeCap.round,
    );
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      start,
      sweep * progress.clamp(0, 1),
      false,
      Paint()
        ..color = Colors.white
        ..style = PaintingStyle.stroke
        ..strokeWidth = 12
        ..strokeCap = StrokeCap.round,
    );
  }

  @override
  bool shouldRepaint(covariant _ArcPainter old) => old.progress != progress;
}

class _WeeklyBarPainter extends CustomPainter {
  const _WeeklyBarPainter({
    required this.values,
    required this.labels,
    required this.barColor,
    this.highlightIndex = -1,
  });

  final List<double> values;
  final List<String> labels;
  final Color barColor;
  final int highlightIndex;

  @override
  void paint(Canvas canvas, Size size) {
    if (values.isEmpty) return;
    const bottomPad = 24.0;
    final maxVal = values
        .reduce((a, b) => a > b ? a : b)
        .clamp(1.0, double.infinity);
    final barW = size.width / (values.length * 1.8);
    final gap = size.width / values.length;
    final chartH = size.height - bottomPad;
    final tp = TextPainter(textDirection: TextDirection.ltr);

    for (var i = 0; i < values.length; i++) {
      final barH = chartH * (values[i] / maxVal);
      final x = gap * i + gap / 2 - barW / 2;
      final y = chartH - barH;
      final isHighlight = i == highlightIndex;

      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(x, y, barW, barH),
          const Radius.circular(6),
        ),
        Paint()..color = isHighlight ? barColor : barColor.withAlpha(80),
      );

      tp.text = TextSpan(
        text: labels[i],
        style: TextStyle(
          fontSize: 10,
          color: isHighlight ? barColor : AppColors.textMuted,
          fontWeight: isHighlight ? FontWeight.w700 : FontWeight.normal,
        ),
      );
      tp.layout();
      tp.paint(
        canvas,
        Offset(x + barW / 2 - tp.width / 2, size.height - tp.height),
      );
    }
  }

  @override
  bool shouldRepaint(covariant _WeeklyBarPainter old) =>
      old.values != values || old.highlightIndex != highlightIndex;
}
