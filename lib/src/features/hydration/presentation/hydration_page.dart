import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/theme/app_colors.dart';
import '../data/hydration_api.dart';
import '../models/hydration_models.dart';

class HydrationPage extends StatefulWidget {
  const HydrationPage({super.key, required this.api});

  final HydrationApi api;

  @override
  State<HydrationPage> createState() => _HydrationPageState();
}

class _HydrationPageState extends State<HydrationPage> {
  HydrationDailySummary? _daily;
  List<HydrationWeeklyEntry> _weekly = [];
  HydrationReminder? _reminder;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final results = await Future.wait<dynamic>([
        widget.api.getDailySummary(),
        widget.api.getWeeklySummary(),
      ]);
      _daily = results[0] as HydrationDailySummary;
      _weekly = results[1] as List<HydrationWeeklyEntry>;
    } catch (e) {
      _error = e.toString();
    }

    // Reminder is optional — don't fail if unavailable
    try {
      _reminder = await widget.api.getReminder();
    } catch (_) {}

    if (mounted) {
      setState(() => _loading = false);
    }
  }

  Future<void> _quickAdd(int ml) async {
    try {
      await widget.api.createLog(amountMl: ml);
      await _load();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to add: $e')),
        );
      }
    }
  }

  Future<void> _deleteEntry(HydrationLog log) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text('Delete Entry',
            style: GoogleFonts.poppins(fontWeight: FontWeight.w700)),
        content: Text('Remove ${log.amountMl.toStringAsFixed(0)} ml entry?',
            style: GoogleFonts.poppins()),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text('Cancel', style: GoogleFonts.poppins()),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text('Delete',
                style: GoogleFonts.poppins(color: Colors.red)),
          ),
        ],
      ),
    );
    if (confirmed != true) {
      return;
    }
    try {
      await widget.api.deleteLog(log.id);
      await _load();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to delete: $e')),
        );
      }
    }
  }

  Future<void> _editEntry(HydrationLog log) async {
    final result = await showDialog<int>(
      context: context,
      builder: (_) => _EditEntryDialog(initial: log.amountMl.round()),
    );
    if (result == null) {
      return;
    }
    try {
      await widget.api.updateLog(logId: log.id, amountMl: result);
      await _load();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to update: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.scaffoldBg,
      appBar: AppBar(
        backgroundColor: const Color(0xFF0891B2),
        surfaceTintColor: Colors.transparent,
        foregroundColor: Colors.white,
        title: Text('Hydration',
            style: GoogleFonts.poppins(
                fontWeight: FontWeight.w700, color: Colors.white)),
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            onPressed: _load,
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? _ErrorView(message: _error!, onRetry: _load)
              : RefreshIndicator(
                  onRefresh: _load,
                  child: ListView(
                    padding: const EdgeInsets.all(16),
                    children: [
                      if (_reminder != null && _reminder!.shouldNotify)
                        _ReminderBanner(reminder: _reminder!),
                      if (_reminder != null && _reminder!.shouldNotify)
                        const SizedBox(height: 12),
                      if (_daily != null) _ProgressCard(summary: _daily!),
                      const SizedBox(height: 16),
                      _QuickAddCard(onAdd: _quickAdd),
                      const SizedBox(height: 16),
                      if (_daily != null)
                        _EntriesCard(
                          entries: _daily!.entries,
                          onEdit: _editEntry,
                          onDelete: _deleteEntry,
                        ),
                      const SizedBox(height: 16),
                      if (_weekly.isNotEmpty) _WeeklyCard(weekly: _weekly),
                      const SizedBox(height: 16),
                    ],
                  ),
                ),
    );
  }
}

// ── Reminder banner ────────────────────────────────────────────────────────────

class _ReminderBanner extends StatelessWidget {
  const _ReminderBanner({required this.reminder});
  final HydrationReminder reminder;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF0891B2).withAlpha(20),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFF0891B2).withAlpha(60)),
      ),
      child: Row(
        children: [
          const Icon(Icons.notifications_active_rounded,
              color: Color(0xFF0891B2), size: 22),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              reminder.message ?? '',
              style: GoogleFonts.poppins(
                fontSize: 13,
                color: const Color(0xFF0891B2),
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Progress card ──────────────────────────────────────────────────────────────

class _ProgressCard extends StatelessWidget {
  const _ProgressCard({required this.summary});
  final HydrationDailySummary summary;

  @override
  Widget build(BuildContext context) {
    final progress =
        (summary.totalMl / summary.dailyGoalMl).clamp(0.0, 1.0);
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFF0891B2), Color(0xFF06B6D4)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.all(Radius.circular(24)),
      ),
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          SizedBox(
            width: 80,
            height: 110,
            child: _WaterGlass(progress: progress),
          ),
          const SizedBox(height: 16),
          Text(
            '${(summary.totalMl / 1000).toStringAsFixed(1)} L',
            style: GoogleFonts.poppins(
              fontSize: 36,
              fontWeight: FontWeight.w800,
              color: Colors.white,
              height: 1.0,
            ),
          ),
          Text(
            'of ${(summary.dailyGoalMl / 1000).toStringAsFixed(1)} L goal',
            style: GoogleFonts.poppins(
                fontSize: 14, color: Colors.white.withAlpha(200)),
          ),
          const SizedBox(height: 16),
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: LinearProgressIndicator(
              value: progress,
              backgroundColor: Colors.white.withAlpha(50),
              valueColor: const AlwaysStoppedAnimation(Colors.white),
              minHeight: 10,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '${summary.percentComplete.toStringAsFixed(0)}% · ${summary.remainingMl} ml remaining',
            style: GoogleFonts.poppins(
                fontSize: 12, color: Colors.white.withAlpha(200)),
          ),
        ],
      ),
    );
  }
}

// ── Water glass painter ────────────────────────────────────────────────────────

class _WaterGlass extends StatelessWidget {
  const _WaterGlass({required this.progress});
  final double progress;

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: _GlassPainter(progress: progress),
      child: const SizedBox.expand(),
    );
  }
}

class _GlassPainter extends CustomPainter {
  const _GlassPainter({required this.progress});
  final double progress;

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final glassPath = Path()
      ..moveTo(w * 0.15, 0)
      ..lineTo(0, h)
      ..lineTo(w, h)
      ..lineTo(w * 0.85, 0)
      ..close();
    canvas.save();
    canvas.clipPath(glassPath);
    final fillH = h * progress;
    canvas.drawRect(
      Rect.fromLTWH(0, h - fillH, w, fillH),
      Paint()..color = Colors.white.withAlpha(100),
    );
    canvas.restore();
    canvas.drawPath(
      glassPath,
      Paint()
        ..color = Colors.white.withAlpha(80)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3,
    );
  }

  @override
  bool shouldRepaint(covariant _GlassPainter old) => old.progress != progress;
}

// ── Quick add card ─────────────────────────────────────────────────────────────

class _QuickAddCard extends StatelessWidget {
  const _QuickAddCard({required this.onAdd});
  final void Function(int ml) onAdd;

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
              offset: const Offset(0, 2))
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Quick Add',
              style: GoogleFonts.poppins(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary)),
          const SizedBox(height: 14),
          Row(
            children: [250, 500, 1000].map((ml) {
              return Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: ElevatedButton(
                    onPressed: () => onAdd(ml),
                    style: ElevatedButton.styleFrom(
                      backgroundColor:
                          const Color(0xFF0891B2).withAlpha(20),
                      foregroundColor: const Color(0xFF0891B2),
                      elevation: 0,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                    ),
                    child: Text(
                      ml >= 1000 ? '+${ml ~/ 1000}L' : '+${ml}ml',
                      style: GoogleFonts.poppins(
                          fontSize: 13, fontWeight: FontWeight.w700),
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }
}

// ── Entries card ───────────────────────────────────────────────────────────────

class _EntriesCard extends StatelessWidget {
  const _EntriesCard({
    required this.entries,
    required this.onEdit,
    required this.onDelete,
  });
  final List<HydrationLog> entries;
  final void Function(HydrationLog) onEdit;
  final void Function(HydrationLog) onDelete;

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
              offset: const Offset(0, 2))
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text("Today's Log",
              style: GoogleFonts.poppins(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary)),
          const SizedBox(height: 12),
          if (entries.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Text('No entries yet. Use Quick Add to log water.',
                  style: GoogleFonts.poppins(
                      fontSize: 13, color: AppColors.textMuted)),
            )
          else
            ...entries.map(
              (log) => _EntryTile(
                log: log,
                onEdit: () => onEdit(log),
                onDelete: () => onDelete(log),
              ),
            ),
        ],
      ),
    );
  }
}

class _EntryTile extends StatelessWidget {
  const _EntryTile({
    required this.log,
    required this.onEdit,
    required this.onDelete,
  });
  final HydrationLog log;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  String get _time {
    final t = log.recordedAt.toLocal();
    final h = t.hour % 12 == 0 ? 12 : t.hour % 12;
    final m = t.minute.toString().padLeft(2, '0');
    final period = t.hour < 12 ? 'AM' : 'PM';
    return '$h:$m $period';
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: const Color(0xFF0891B2).withAlpha(20),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.water_drop_rounded,
                size: 18, color: Color(0xFF0891B2)),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(_time,
                    style: GoogleFonts.poppins(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textPrimary)),
                if (log.notes != null && log.notes!.isNotEmpty)
                  Text(log.notes!,
                      style: GoogleFonts.poppins(
                          fontSize: 11, color: AppColors.textMuted)),
              ],
            ),
          ),
          Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: const Color(0xFF0891B2).withAlpha(15),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text('${log.amountMl.toStringAsFixed(0)} ml',
                style: GoogleFonts.poppins(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: const Color(0xFF0891B2))),
          ),
          const SizedBox(width: 4),
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert_rounded,
                size: 18, color: AppColors.textMuted),
            onSelected: (value) {
              if (value == 'edit') {
                onEdit();
              } else if (value == 'delete') {
                onDelete();
              }
            },
            itemBuilder: (_) => [
              PopupMenuItem(
                value: 'edit',
                child: Text('Edit', style: GoogleFonts.poppins(fontSize: 13)),
              ),
              PopupMenuItem(
                value: 'delete',
                child: Text('Delete',
                    style: GoogleFonts.poppins(
                        fontSize: 13, color: Colors.red)),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ── Edit entry dialog ──────────────────────────────────────────────────────────

class _EditEntryDialog extends StatefulWidget {
  const _EditEntryDialog({required this.initial});
  final int initial;

  @override
  State<_EditEntryDialog> createState() => _EditEntryDialogState();
}

class _EditEntryDialogState extends State<_EditEntryDialog> {
  late final TextEditingController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = TextEditingController(text: widget.initial.toString());
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text('Edit Entry',
          style: GoogleFonts.poppins(fontWeight: FontWeight.w700)),
      content: TextField(
        controller: _ctrl,
        keyboardType: TextInputType.number,
        inputFormatters: [FilteringTextInputFormatter.digitsOnly],
        decoration: InputDecoration(
          labelText: 'Amount (ml)',
          labelStyle: GoogleFonts.poppins(),
          border: const OutlineInputBorder(),
        ),
        style: GoogleFonts.poppins(),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text('Cancel', style: GoogleFonts.poppins()),
        ),
        ElevatedButton(
          onPressed: () {
            final value = int.tryParse(_ctrl.text);
            if (value != null && value > 0) {
              Navigator.pop(context, value);
            }
          },
          child: Text('Save', style: GoogleFonts.poppins()),
        ),
      ],
    );
  }
}

// ── Weekly summary card ────────────────────────────────────────────────────────

class _WeeklyCard extends StatelessWidget {
  const _WeeklyCard({required this.weekly});
  final List<HydrationWeeklyEntry> weekly;

  String _shortDay(String dateStr) {
    try {
      final d = DateTime.parse(dateStr);
      const days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
      return days[d.weekday - 1];
    } catch (_) {
      return dateStr.substring(5);
    }
  }

  @override
  Widget build(BuildContext context) {
    final maxMl = weekly.fold<double>(
      1.0,
      (prev, e) => e.totalMl > prev ? e.totalMl : prev,
    );

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withAlpha(8),
              blurRadius: 10,
              offset: const Offset(0, 2))
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Last 7 Days',
              style: GoogleFonts.poppins(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary)),
          const SizedBox(height: 16),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: weekly.map((entry) {
              final barRatio =
                  maxMl > 0 ? entry.totalMl / maxMl : 0.0;
              final reached = entry.reached;
              return Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 3),
                  child: Column(
                    children: [
                      SizedBox(
                        height: 60,
                        child: Align(
                          alignment: Alignment.bottomCenter,
                          child: Container(
                            height: (60 * barRatio).clamp(4.0, 60.0),
                            decoration: BoxDecoration(
                              color: reached
                                  ? const Color(0xFF0891B2)
                                  : const Color(0xFF0891B2).withAlpha(50),
                              borderRadius: BorderRadius.circular(4),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(_shortDay(entry.date),
                          style: GoogleFonts.poppins(
                              fontSize: 10,
                              color: AppColors.textMuted)),
                    ],
                  ),
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Container(
                  width: 10,
                  height: 10,
                  decoration: BoxDecoration(
                      color: const Color(0xFF0891B2),
                      borderRadius: BorderRadius.circular(2))),
              const SizedBox(width: 6),
              Text('Goal reached',
                  style: GoogleFonts.poppins(
                      fontSize: 11, color: AppColors.textMuted)),
              const SizedBox(width: 16),
              Container(
                  width: 10,
                  height: 10,
                  decoration: BoxDecoration(
                      color: const Color(0xFF0891B2).withAlpha(50),
                      borderRadius: BorderRadius.circular(2))),
              const SizedBox(width: 6),
              Text('Below goal',
                  style: GoogleFonts.poppins(
                      fontSize: 11, color: AppColors.textMuted)),
            ],
          ),
        ],
      ),
    );
  }
}

// ── Error view ─────────────────────────────────────────────────────────────────

class _ErrorView extends StatelessWidget {
  const _ErrorView({required this.message, required this.onRetry});
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
            const Icon(Icons.wifi_off_rounded,
                size: 48, color: AppColors.textMuted),
            const SizedBox(height: 12),
            Text('Could not load hydration data',
                style: GoogleFonts.poppins(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary),
                textAlign: TextAlign.center),
            const SizedBox(height: 8),
            Text(message,
                style: GoogleFonts.poppins(
                    fontSize: 12, color: AppColors.textMuted),
                textAlign: TextAlign.center),
            const SizedBox(height: 20),
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
