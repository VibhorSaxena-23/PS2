/// Check-in / Check-out UX flow for the Gym feature.
///
/// Entry point  : [launchCheckInFlow] — called from GymHubPage.
/// Screen order :
///   1. CheckInConfirmPage  → 2. CheckInSuccessPage → 3. ActiveSessionPage
///                                                   ↕ (back)
///   3. ActiveSessionPage   → checkout modal        → 4. SessionSummaryPage
///   Any page               → 5. AttendanceHistoryPage (pushed)
library;

import 'dart:async';
import 'dart:convert' show jsonDecode;

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:permission_handler/permission_handler.dart';

import '../../../core/theme/app_colors.dart';
import '../data/gym_api.dart';
import '../models/gym_models.dart';

// ── Colours used throughout this flow ────────────────────────────────────────

const _green = Color(0xFF16A34A);
const _greenSoft = Color(0xFFDCFCE7);
const _accent = Color(0xFF4F46E5);
const _dark = Color(0xFF1A1A2E);

// ── Entry-point helper ────────────────────────────────────────────────────────

/// Call this instead of the raw check-in API.  Checks for an active session
/// first; if one is found the user jumps straight to [ActiveSessionPage].
Future<void> launchCheckInFlow({
  required BuildContext context,
  required GymApi gymApi,
  required GymMembership membership,
  required VoidCallback onFlowComplete,
}) async {
  // Show a tiny loading indicator while we probe for an active session.
  showDialog(
    context: context,
    barrierDismissible: false,
    builder: (_) => const Center(child: CircularProgressIndicator()),
  );

  GymAttendance? active;
  try {
    final records = await gymApi.getAttendance(
      gymId: membership.gymId,
      limit: 10,
    );
    active = records.where((a) => a.isActive).firstOrNull;
  } catch (_) {
    // On error just continue to confirm page.
  } finally {
    if (context.mounted) Navigator.of(context).pop(); // dismiss loader
  }

  if (!context.mounted) return;

  if (active != null) {
    // Already checked in — skip straight to the active session screen.
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ActiveSessionPage(
          gymApi: gymApi,
          attendance: active!,
          gymName: membership.gymName,
        ),
      ),
    );
  } else {
    await _startQrCheckInFlow(
      context: context,
      gymApi: gymApi,
      membership: membership,
    );
  }
  onFlowComplete();
}

Future<void> _startQrCheckInFlow({
  required BuildContext context,
  required GymApi gymApi,
  required GymMembership membership,
}) async {
  final qrData = await Navigator.of(context).push<Map<String, dynamic>>(
    MaterialPageRoute(
      builder: (_) => _QrScanPage(expectedGymId: membership.gymId),
    ),
  );
  if (!context.mounted || qrData == null) return;

  try {
    final attendance = await gymApi.checkIn(
      qrData['gymId'] as String,
      qrData['token'] as String,
      timestamp: qrData['timestamp'] as int?,
    );
    if (!context.mounted) return;

    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => CheckInSuccessPage(
          gymApi: gymApi,
          attendance: attendance,
          gymName: membership.gymName,
        ),
      ),
    );
  } catch (e) {
    final raw = e.toString().toLowerCase();
    if (raw.contains('already checked in') || raw.contains('active session')) {
      await _openActiveSessionPage(
        context: context,
        gymApi: gymApi,
        membership: membership,
      );
      return;
    }

    if (!context.mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(_friendlyError(e.toString()))));
  }
}

Future<void> _openActiveSessionPage({
  required BuildContext context,
  required GymApi gymApi,
  required GymMembership membership,
}) async {
  try {
    final records = await gymApi.getAttendance(
      gymId: membership.gymId,
      limit: 10,
    );
    final active = records.where((a) => a.isActive).firstOrNull;
    if (!context.mounted || active == null) return;

    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ActiveSessionPage(
          gymApi: gymApi,
          attendance: active,
          gymName: membership.gymName,
        ),
      ),
    );
  } catch (_) {}
}

// ═════════════════════════════════════════════════════════════════════════════
//  1. Check-In Confirmation Screen
// ═════════════════════════════════════════════════════════════════════════════

class CheckInConfirmPage extends StatefulWidget {
  const CheckInConfirmPage({
    super.key,
    required this.gymApi,
    required this.membership,
  });

  final GymApi gymApi;
  final GymMembership membership;

  @override
  State<CheckInConfirmPage> createState() => _CheckInConfirmPageState();
}

class _CheckInConfirmPageState extends State<CheckInConfirmPage> {
  bool _confirming = false;
  String? _error;

  // Opens the QR scanner and on a valid scan submits the check-in request.
  Future<void> _confirm() async {
    setState(() => _error = null);

    // Push QR scanner screen; it returns a Map with {gymId, token, timestamp?}
    // when the user successfully scans the gym's entrance QR code.
    final qrData = await Navigator.of(context).push<Map<String, dynamic>>(
      MaterialPageRoute(
        builder: (_) => _QrScanPage(expectedGymId: widget.membership.gymId),
      ),
    );
    if (!mounted || qrData == null) return;

    setState(() {
      _confirming = true;
      _error = null;
    });

    try {
      final attendance = await widget.gymApi.checkIn(
        qrData['gymId'] as String,
        qrData['token'] as String,
        timestamp: qrData['timestamp'] as int?,
      );
      if (!mounted) return;

      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (_) => CheckInSuccessPage(
            gymApi: widget.gymApi,
            attendance: attendance,
            gymName: widget.membership.gymName,
          ),
        ),
      );
    } catch (e) {
      final raw = e.toString().toLowerCase();
      if (raw.contains('already checked in') ||
          raw.contains('active session')) {
        if (!mounted) return;
        _goToActiveSession();
        return;
      }
      setState(() {
        _confirming = false;
        _error = _friendlyError(e.toString());
      });
    }
  }

  Future<void> _goToActiveSession() async {
    try {
      final records = await widget.gymApi.getAttendance(
        gymId: widget.membership.gymId,
        limit: 10,
      );
      final active = records.where((a) => a.isActive).firstOrNull;
      if (!mounted) return;

      if (active != null) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(
            builder: (_) => ActiveSessionPage(
              gymApi: widget.gymApi,
              attendance: active,
              gymName: widget.membership.gymName,
            ),
          ),
        );
      } else {
        setState(() {
          _confirming = false;
          _error = 'You appear to already be checked in. Please refresh.';
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _confirming = false;
          _error = 'Already checked in. Could not load active session.';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final isActive = widget.membership.status.toUpperCase() == 'ACTIVE';

    return Scaffold(
      backgroundColor: AppColors.scaffoldBg,
      appBar: AppBar(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
        foregroundColor: AppColors.textPrimary,
        elevation: 0,
        title: Text(
          'Check In',
          style: GoogleFonts.poppins(fontWeight: FontWeight.w700),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Gym card ────────────────────────────────────────────────────
            _InfoCard(
              children: [
                _IconRow(
                  icon: Icons.fitness_center_rounded,
                  color: _accent,
                  label: 'Gym',
                  value: widget.membership.gymName,
                ),
                const SizedBox(height: 14),
                _IconRow(
                  icon: Icons.access_time_rounded,
                  color: _green,
                  label: 'Check-in time',
                  value: DateFormat('EEE, MMM d • h:mm a').format(now),
                ),
                const SizedBox(height: 14),
                _IconRow(
                  icon: Icons.card_membership_rounded,
                  color: isActive ? _green : AppColors.error,
                  label: 'Membership',
                  value: widget.membership.status,
                  valueColor: isActive ? _green : AppColors.error,
                ),
              ],
            ),

            if (_error != null) ...[
              const SizedBox(height: 16),
              _ErrorBanner(message: _error!),
            ],

            const SizedBox(height: 32),

            // ── Confirm button ───────────────────────────────────────────────
            _PrimaryButton(
              label: 'Confirm Check-In',
              icon: Icons.qr_code_scanner_rounded,
              color: _green,
              loading: _confirming,
              disabled: !isActive,
              onTap: _confirm,
            ),
            const SizedBox(height: 12),
            _SecondaryButton(
              label: 'Cancel',
              onTap: _confirming ? null : () => Navigator.of(context).pop(),
            ),

            if (!isActive) ...[
              const SizedBox(height: 16),
              _WarningBanner(
                message:
                    'Your membership is not active. '
                    'Please renew before checking in.',
              ),
            ],
          ],
        ),
      ),
    );
  }
}

// ═════════════════════════════════════════════════════════════════════════════
//  1b. QR Scanner Screen
// ═════════════════════════════════════════════════════════════════════════════

// Scans the gym's permanent QR code and returns {gymId, token, timestamp?}.
// The QR code encodes JSON: {"gymId": "...", "token": "v2.xxx", "timestamp": 0}
class _QrScanPage extends StatefulWidget {
  const _QrScanPage({required this.expectedGymId});
  final String expectedGymId;

  @override
  State<_QrScanPage> createState() => _QrScanPageState();
}

class _QrScanPageState extends State<_QrScanPage> {
  bool _processed = false;
  String? _error;

  bool _cameraReady = false;

  @override
  void initState() {
    super.initState();
    _prepareCamera();
  }

  Future<void> _prepareCamera() async {
    final status = await Permission.camera.status;
    if (status.isGranted) {
      if (mounted) setState(() => _cameraReady = true);
      return;
    }

    final result = await Permission.camera.request();
    if (!mounted) return;

    if (result.isGranted) {
      setState(() {
        _cameraReady = true;
        _error = null;
      });
      return;
    }

    setState(() {
      _cameraReady = false;
      _error = result.isPermanentlyDenied
          ? 'Camera permission is turned off. Open Settings to scan QR codes.'
          : 'Camera permission is required to scan QR codes.';
    });
  }

  void _onDetect(BarcodeCapture capture) {
    if (_processed) return;
    final raw = capture.barcodes.firstOrNull?.rawValue;
    if (raw == null || raw.isEmpty) return;

    final data = _parseQrPayload(raw);
    final gymId = data['gymId'];
    final token = data['token'];
    final timestamp = data['timestamp'];

    if (gymId == null || token == null) {
      setState(() => _error = 'QR code is missing required fields.');
      return;
    }
    if (gymId != widget.expectedGymId) {
      setState(() => _error = 'This QR code belongs to a different gym.');
      return;
    }

    _processed = true;
    Navigator.of(context).pop<Map<String, dynamic>>({
      'gymId': gymId,
      'token': token,
      'timestamp': timestamp,
    });
  }

  Map<String, dynamic> _parseQrPayload(String raw) {
    // Preferred format: JSON payload with gymId + token.
    try {
      final decoded = jsonDecode(raw);
      if (decoded is Map) {
        final map = Map<String, dynamic>.from(decoded);
        final gymId = (map['gymId'] ?? map['gym_id'])?.toString();
        final token = (map['token'] ?? map['qrToken'] ?? map['qr_token'])
            ?.toString();
        final timestamp = _parseTimestamp(map['timestamp']);
        return {
          'gymId': gymId,
          'token': token,
          'timestamp': timestamp,
        };
      }
    } catch (_) {
      // Not JSON, handled below as legacy static token format.
    }

    // Legacy/printed QR support: raw token only.
    final trimmed = raw.trim();
    if (trimmed.startsWith('v2.') && trimmed.length > 10) {
      return {
        'gymId': widget.expectedGymId,
        'token': trimmed,
        'timestamp': null,
      };
    }

    return const {
      'gymId': null,
      'token': null,
      'timestamp': null,
    };
  }

  int? _parseTimestamp(dynamic value) {
    if (value == null) return null;
    final parsed = switch (value) {
      int v => v,
      num v => v.toInt(),
      String v => int.tryParse(v),
      _ => null,
    };
    if (parsed == null || parsed <= 0) return null;
    return parsed;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        title: Text(
          'Scan Gym QR Code',
          style: GoogleFonts.poppins(fontWeight: FontWeight.w700),
        ),
        actions: [
          IconButton(
            tooltip: 'Retry camera',
            onPressed: _prepareCamera,
            icon: const Icon(Icons.refresh_rounded),
          ),
        ],
      ),
      body: Stack(
        children: [
          Positioned.fill(
            child: _cameraReady
                ? MobileScanner(onDetect: _onDetect)
                : const ColoredBox(color: Colors.black),
          ),
          // Overlay frame
          Center(
            child: Container(
              width: 240,
              height: 240,
              decoration: BoxDecoration(
                border: Border.all(color: _accent, width: 3),
                borderRadius: BorderRadius.circular(16),
              ),
            ),
          ),
          Positioned(
            bottom: 48,
            left: 24,
            right: 24,
            child: Column(
              children: [
                Text(
                  'Point the camera at the QR code\ndisplayed at the gym entrance.',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.poppins(color: Colors.white, fontSize: 14),
                ),
                if (!_cameraReady) ...[
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.12),
                      ),
                    ),
                    child: Column(
                      children: [
                        Text(
                          _error ?? 'Opening camera...',
                          textAlign: TextAlign.center,
                          style: GoogleFonts.poppins(
                            color: Colors.white,
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        if (_error != null) ...[
                          const SizedBox(height: 12),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              TextButton(
                                onPressed: _prepareCamera,
                                child: const Text('Try again'),
                              ),
                              const SizedBox(width: 8),
                              TextButton(
                                onPressed: openAppSettings,
                                child: const Text('Open Settings'),
                              ),
                            ],
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
                if (_cameraReady && _error != null) ...[
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 10,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.red.shade700,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      _error!,
                      textAlign: TextAlign.center,
                      style: GoogleFonts.poppins(
                        color: Colors.white,
                        fontSize: 13,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ═════════════════════════════════════════════════════════════════════════════
//  2. Check-In Success Screen
// ═════════════════════════════════════════════════════════════════════════════

class CheckInSuccessPage extends StatelessWidget {
  const CheckInSuccessPage({
    super.key,
    required this.gymApi,
    required this.attendance,
    required this.gymName,
  });

  final GymApi gymApi;
  final GymAttendance attendance;
  final String gymName;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.scaffoldBg,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            children: [
              const Spacer(),

              // ── Success graphic ───────────────────────────────────────────
              Container(
                width: 100,
                height: 100,
                decoration: const BoxDecoration(
                  color: _greenSoft,
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.check_rounded, size: 56, color: _green),
              ),
              const SizedBox(height: 24),
              Text(
                'Checked In!',
                style: GoogleFonts.poppins(
                  fontSize: 28,
                  fontWeight: FontWeight.w800,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                gymName,
                style: GoogleFonts.poppins(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textSecondary,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                DateFormat('EEEE, MMM d • h:mm a').format(attendance.checkedIn),
                style: GoogleFonts.poppins(
                  fontSize: 13,
                  color: AppColors.textMuted,
                ),
              ),

              const Spacer(),

              // ── CTAs ───────────────────────────────────────────────────────
              _PrimaryButton(
                label: 'View Active Session',
                icon: Icons.timer_rounded,
                color: _green,
                onTap: () => Navigator.of(context).pushReplacement(
                  MaterialPageRoute(
                    builder: (_) => ActiveSessionPage(
                      gymApi: gymApi,
                      attendance: attendance,
                      gymName: gymName,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              _SecondaryButton(
                label: 'Back to Gyms',
                onTap: () => Navigator.of(context).pop(),
              ),
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
  }
}

// ═════════════════════════════════════════════════════════════════════════════
//  3. Active Session Screen (with live elapsed timer)
// ═════════════════════════════════════════════════════════════════════════════

class ActiveSessionPage extends StatefulWidget {
  const ActiveSessionPage({
    super.key,
    required this.gymApi,
    required this.attendance,
    required this.gymName,
  });

  final GymApi gymApi;
  final GymAttendance attendance;
  final String gymName;

  @override
  State<ActiveSessionPage> createState() => _ActiveSessionPageState();
}

class _ActiveSessionPageState extends State<ActiveSessionPage> {
  late Timer _timer;
  Duration _elapsed = Duration.zero;
  bool _checkingOut = false;

  @override
  void initState() {
    super.initState();
    _elapsed = DateTime.now().difference(widget.attendance.checkedIn);
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) {
        setState(() {
          _elapsed = DateTime.now().difference(widget.attendance.checkedIn);
        });
      }
    });
  }

  @override
  void dispose() {
    _timer.cancel();
    super.dispose();
  }

  String _formatElapsed(Duration d) {
    final h = d.inHours.toString().padLeft(2, '0');
    final m = (d.inMinutes % 60).toString().padLeft(2, '0');
    final s = (d.inSeconds % 60).toString().padLeft(2, '0');
    return '$h:$m:$s';
  }

  Future<void> _checkout() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => _CheckOutDialog(
        gymName: widget.gymName,
        checkedIn: widget.attendance.checkedIn,
      ),
    );
    if (confirmed != true || !mounted) return;

    setState(() => _checkingOut = true);
    try {
      final updated = await widget.gymApi.checkOut(widget.attendance.gymId);
      if (!mounted) return;
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (_) => SessionSummaryPage(attendance: updated),
        ),
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(_friendlyError(e.toString()))));
        setState(() => _checkingOut = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.scaffoldBg,
      appBar: AppBar(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
        foregroundColor: AppColors.textPrimary,
        elevation: 0,
        title: Text(
          'Active Session',
          style: GoogleFonts.poppins(fontWeight: FontWeight.w700),
        ),
        actions: [
          TextButton.icon(
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => AttendanceHistoryPage(gymApi: widget.gymApi),
              ),
            ),
            icon: const Icon(Icons.history_rounded, size: 18),
            label: const Text('History'),
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            // ── Timer card ───────────────────────────────────────────────────
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 36, horizontal: 24),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [_dark, Color(0xFF16213E)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(24),
              ),
              child: Column(
                children: [
                  Text(
                    'Time in gym',
                    style: GoogleFonts.poppins(
                      fontSize: 14,
                      color: Colors.white.withAlpha(160),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    _formatElapsed(_elapsed),
                    style: GoogleFonts.poppins(
                      fontSize: 52,
                      fontWeight: FontWeight.w800,
                      color: Colors.white,
                      letterSpacing: 2,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: _greenSoft.withAlpha(30),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 8,
                          height: 8,
                          decoration: const BoxDecoration(
                            color: _green,
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          'Active',
                          style: GoogleFonts.poppins(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: _green,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // ── Session info card ────────────────────────────────────────────
            _InfoCard(
              children: [
                _IconRow(
                  icon: Icons.fitness_center_rounded,
                  color: _accent,
                  label: 'Gym',
                  value: widget.gymName,
                ),
                const SizedBox(height: 14),
                _IconRow(
                  icon: Icons.login_rounded,
                  color: _green,
                  label: 'Checked in',
                  value: DateFormat(
                    'h:mm a',
                  ).format(widget.attendance.checkedIn),
                ),
              ],
            ),

            const Spacer(),

            // ── CTAs ─────────────────────────────────────────────────────────
            _PrimaryButton(
              label: 'Check Out',
              icon: Icons.logout_rounded,
              color: AppColors.error,
              loading: _checkingOut,
              onTap: _checkout,
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }
}

// ═════════════════════════════════════════════════════════════════════════════
//  4. Check-Out Confirmation Dialog
// ═════════════════════════════════════════════════════════════════════════════

class _CheckOutDialog extends StatelessWidget {
  const _CheckOutDialog({required this.gymName, required this.checkedIn});

  final String gymName;
  final DateTime checkedIn;

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final duration = now.difference(checkedIn);
    final h = duration.inHours;
    final m = duration.inMinutes % 60;

    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: Text(
        'Check Out?',
        style: GoogleFonts.poppins(fontWeight: FontWeight.w700),
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            gymName,
            style: GoogleFonts.poppins(
              fontWeight: FontWeight.w600,
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: 8),
          _DialogRow(
            label: 'Checked in',
            value: DateFormat('h:mm a').format(checkedIn),
          ),
          _DialogRow(
            label: 'Check out',
            value: DateFormat('h:mm a').format(now),
          ),
          _DialogRow(label: 'Duration', value: h > 0 ? '${h}h ${m}m' : '${m}m'),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: const Text('Cancel'),
        ),
        FilledButton(
          style: FilledButton.styleFrom(backgroundColor: AppColors.error),
          onPressed: () => Navigator.of(context).pop(true),
          child: const Text('Check Out'),
        ),
      ],
    );
  }
}

class _DialogRow extends StatelessWidget {
  const _DialogRow({required this.label, required this.value});
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: GoogleFonts.poppins(
              fontSize: 13,
              color: AppColors.textMuted,
            ),
          ),
          Text(
            value,
            style: GoogleFonts.poppins(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: AppColors.textPrimary,
            ),
          ),
        ],
      ),
    );
  }
}

// ═════════════════════════════════════════════════════════════════════════════
//  5. Session Summary Screen (after checkout)
// ═════════════════════════════════════════════════════════════════════════════

class SessionSummaryPage extends StatelessWidget {
  const SessionSummaryPage({super.key, required this.attendance});

  final GymAttendance attendance;

  @override
  Widget build(BuildContext context) {
    final checkIn = attendance.checkedIn;
    final checkOut = attendance.checkOut ?? DateTime.now();
    final duration = checkOut.difference(checkIn);
    final h = duration.inHours;
    final m = duration.inMinutes % 60;
    final durationLabel = h > 0 ? '${h}h ${m}m' : '${m}m';

    return Scaffold(
      backgroundColor: AppColors.scaffoldBg,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            children: [
              const Spacer(),

              // ── Summary graphic ───────────────────────────────────────────
              Container(
                width: 90,
                height: 90,
                decoration: BoxDecoration(
                  color: AppColors.accentGreenSoft,
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.emoji_events_rounded,
                  size: 48,
                  color: _green,
                ),
              ),
              const SizedBox(height: 20),
              Text(
                'Session Complete',
                style: GoogleFonts.poppins(
                  fontSize: 26,
                  fontWeight: FontWeight.w800,
                  color: AppColors.textPrimary,
                ),
              ),
              Text(
                attendance.gymName ?? 'Gym',
                style: GoogleFonts.poppins(
                  fontSize: 15,
                  color: AppColors.textSecondary,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 28),

              // ── Stats row ─────────────────────────────────────────────────
              Container(
                padding: const EdgeInsets.symmetric(vertical: 20),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: AppColors.divider),
                ),
                child: Row(
                  children: [
                    _SummaryCell(
                      label: 'Duration',
                      value: durationLabel,
                      icon: Icons.timer_rounded,
                      color: _accent,
                    ),
                    Container(width: 1, height: 40, color: AppColors.divider),
                    _SummaryCell(
                      label: 'Checked in',
                      value: DateFormat('h:mm a').format(checkIn),
                      icon: Icons.login_rounded,
                      color: _green,
                    ),
                    Container(width: 1, height: 40, color: AppColors.divider),
                    _SummaryCell(
                      label: 'Checked out',
                      value: DateFormat('h:mm a').format(checkOut),
                      icon: Icons.logout_rounded,
                      color: AppColors.error,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              _InfoCard(
                children: [
                  _IconRow(
                    icon: Icons.calendar_today_rounded,
                    color: AppColors.textMuted,
                    label: 'Date',
                    value: DateFormat('EEEE, MMMM d, yyyy').format(checkIn),
                  ),
                ],
              ),

              const Spacer(),

              // ── CTA ───────────────────────────────────────────────────────
              _PrimaryButton(
                label: 'Done',
                icon: Icons.check_rounded,
                color: _dark,
                onTap: () {
                  // Pop until we're back at GymHubPage.
                  Navigator.of(context).popUntil((route) => route.isFirst);
                },
              ),
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
  }
}

class _SummaryCell extends StatelessWidget {
  const _SummaryCell({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
  });
  final String label;
  final String value;
  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        children: [
          Icon(icon, size: 20, color: color),
          const SizedBox(height: 4),
          Text(
            value,
            style: GoogleFonts.poppins(
              fontSize: 13,
              fontWeight: FontWeight.w700,
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
    );
  }
}

// ═════════════════════════════════════════════════════════════════════════════
//  6. Attendance History Screen
// ═════════════════════════════════════════════════════════════════════════════

class AttendanceHistoryPage extends StatefulWidget {
  const AttendanceHistoryPage({
    super.key,
    required this.gymApi,
    this.filterGymId,
  });

  final GymApi gymApi;
  final String? filterGymId;

  @override
  State<AttendanceHistoryPage> createState() => _AttendanceHistoryPageState();
}

class _AttendanceHistoryPageState extends State<AttendanceHistoryPage> {
  final List<GymAttendance> _items = [];
  final ScrollController _scroll = ScrollController();

  static const _pageSize = 20;
  bool _hasMore = true;
  bool _loading = false;
  bool _initialLoad = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _scroll.addListener(_onScroll);
    _fetchMore(reset: true);
  }

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scroll.position.pixels >= _scroll.position.maxScrollExtent - 200 &&
        !_loading &&
        _hasMore) {
      _fetchMore();
    }
  }

  Future<void> _fetchMore({bool reset = false}) async {
    if (_loading) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final offset = reset ? 0 : _items.length;
      final result = await widget.gymApi.getAttendance(
        gymId: widget.filterGymId,
        limit: _pageSize,
        offset: offset,
      );
      if (!mounted) return;
      setState(() {
        if (reset) _items.clear();
        _items.addAll(result);
        _hasMore = result.length == _pageSize;
        _loading = false;
        _initialLoad = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = _friendlyError(e.toString());
        _loading = false;
        _initialLoad = false;
      });
    }
  }

  Future<void> _refresh() => _fetchMore(reset: true);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.scaffoldBg,
      appBar: AppBar(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
        foregroundColor: AppColors.textPrimary,
        elevation: 0,
        title: Text(
          'Session History',
          style: GoogleFonts.poppins(fontWeight: FontWeight.w700),
        ),
      ),
      body: _initialLoad
          ? const Center(child: CircularProgressIndicator())
          : _error != null && _items.isEmpty
          ? _buildError()
          : RefreshIndicator(
              onRefresh: _refresh,
              child: _items.isEmpty
                  ? _buildEmpty()
                  : ListView.builder(
                      controller: _scroll,
                      padding: const EdgeInsets.all(16),
                      itemCount: _items.length + (_loading ? 1 : 0),
                      itemBuilder: (context, index) {
                        if (index == _items.length) {
                          return const Padding(
                            padding: EdgeInsets.all(16),
                            child: Center(child: CircularProgressIndicator()),
                          );
                        }
                        return _AttendanceTile(attendance: _items[index]);
                      },
                    ),
            ),
    );
  }

  Widget _buildEmpty() {
    return ListView(
      children: [
        const SizedBox(height: 120),
        Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.history_rounded, size: 56, color: AppColors.textMuted),
              const SizedBox(height: 12),
              Text(
                'No sessions yet',
                style: GoogleFonts.poppins(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'Check in to your gym to track sessions.',
                style: GoogleFonts.poppins(
                  fontSize: 13,
                  color: AppColors.textMuted,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildError() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline, size: 48, color: AppColors.error),
            const SizedBox(height: 12),
            Text(
              _error!,
              textAlign: TextAlign.center,
              style: GoogleFonts.poppins(
                fontSize: 13,
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: _refresh,
              icon: const Icon(Icons.refresh, size: 18),
              label: const Text('Retry'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.btnDark,
                foregroundColor: Colors.white,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _AttendanceTile extends StatelessWidget {
  const _AttendanceTile({required this.attendance});
  final GymAttendance attendance;

  @override
  Widget build(BuildContext context) {
    final checkIn = attendance.checkedIn;
    final checkOut = attendance.checkOut;
    final duration = checkOut != null
        ? checkOut.difference(checkIn)
        : DateTime.now().difference(checkIn);
    final h = duration.inHours;
    final m = duration.inMinutes % 60;
    final durationLabel = h > 0 ? '${h}h ${m}m' : '${m}m';

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: attendance.isActive ? _green.withAlpha(60) : AppColors.divider,
          width: attendance.isActive ? 1.5 : 1,
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: attendance.isActive ? _greenSoft : AppColors.scaffoldBg,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              attendance.isActive
                  ? Icons.fitness_center_rounded
                  : Icons.check_circle_outline_rounded,
              size: 22,
              color: attendance.isActive ? _green : AppColors.textMuted,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        attendance.gymName ?? 'Gym',
                        style: GoogleFonts.poppins(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textPrimary,
                        ),
                      ),
                    ),
                    if (attendance.isActive)
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: _greenSoft,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          'Active',
                          style: GoogleFonts.poppins(
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                            color: _green,
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  DateFormat('EEE, MMM d').format(checkIn),
                  style: GoogleFonts.poppins(
                    fontSize: 12,
                    color: AppColors.textMuted,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                durationLabel,
                style: GoogleFonts.poppins(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: attendance.isActive ? _green : AppColors.textPrimary,
                ),
              ),
              Text(
                '${DateFormat('h:mm a').format(checkIn)} → '
                '${checkOut != null ? DateFormat('h:mm a').format(checkOut) : 'Now'}',
                style: GoogleFonts.poppins(
                  fontSize: 10,
                  color: AppColors.textMuted,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ═════════════════════════════════════════════════════════════════════════════
//  Shared small widgets
// ═════════════════════════════════════════════════════════════════════════════

class _InfoCard extends StatelessWidget {
  const _InfoCard({required this.children});
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.divider),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: children,
      ),
    );
  }
}

class _IconRow extends StatelessWidget {
  const _IconRow({
    required this.icon,
    required this.color,
    required this.label,
    required this.value,
    this.valueColor,
  });
  final IconData icon;
  final Color color;
  final String label;
  final String value;
  final Color? valueColor;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color: color.withAlpha(20),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, size: 18, color: color),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: GoogleFonts.poppins(
                  fontSize: 11,
                  color: AppColors.textMuted,
                ),
              ),
              Text(
                value,
                style: GoogleFonts.poppins(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: valueColor ?? AppColors.textPrimary,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _PrimaryButton extends StatelessWidget {
  const _PrimaryButton({
    required this.label,
    required this.icon,
    required this.color,
    required this.onTap,
    this.loading = false,
    this.disabled = false,
  });
  final String label;
  final IconData icon;
  final Color color;
  final VoidCallback? onTap;
  final bool loading;
  final bool disabled;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 52,
      child: ElevatedButton.icon(
        onPressed: (loading || disabled) ? null : onTap,
        icon: loading
            ? const SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Colors.white,
                ),
              )
            : Icon(icon, size: 20),
        label: Text(label),
        style: ElevatedButton.styleFrom(
          backgroundColor: color,
          foregroundColor: Colors.white,
          disabledBackgroundColor: color.withAlpha(80),
          disabledForegroundColor: Colors.white.withAlpha(180),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          textStyle: GoogleFonts.poppins(
            fontSize: 15,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }
}

class _SecondaryButton extends StatelessWidget {
  const _SecondaryButton({required this.label, required this.onTap});
  final String label;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 48,
      child: OutlinedButton(
        onPressed: onTap,
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.textSecondary,
          side: const BorderSide(color: AppColors.divider),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          textStyle: GoogleFonts.poppins(
            fontSize: 14,
            fontWeight: FontWeight.w600,
          ),
        ),
        child: Text(label),
      ),
    );
  }
}

class _ErrorBanner extends StatelessWidget {
  const _ErrorBanner({required this.message});
  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.errorSoft,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.error.withAlpha(60)),
      ),
      child: Row(
        children: [
          const Icon(Icons.error_outline, color: AppColors.error, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              style: GoogleFonts.poppins(fontSize: 13, color: AppColors.error),
            ),
          ),
        ],
      ),
    );
  }
}

class _WarningBanner extends StatelessWidget {
  const _WarningBanner({required this.message});
  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF7ED),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFF59E0B).withAlpha(80)),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.warning_amber_rounded,
            color: Color(0xFFD97706),
            size: 20,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              style: GoogleFonts.poppins(
                fontSize: 13,
                color: const Color(0xFF92400E),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Helpers ───────────────────────────────────────────────────────────────────

String _friendlyError(String raw) {
  final lower = raw.toLowerCase();
  if (lower.contains('statuscode: 503') ||
      lower.contains('qr check-in is temporarily unavailable') ||
      lower.contains('qr configuration is missing')) {
    return 'Gym QR check-in is not configured yet. Please ask the gym/admin to refresh QR setup.';
  }
  if (lower.contains('statuscode: 422') || lower.contains('validation failed')) {
    return 'Invalid QR payload. Please scan the official gym entrance QR again.';
  }
  if (lower.contains('invalid or expired qr code') ||
      (lower.contains('statuscode: 400') && lower.contains('qr'))) {
    return 'Invalid or expired QR. Please rescan a fresh gym QR code.';
  }
  if (lower.contains('already checked in') ||
      lower.contains('active session')) {
    return 'You are already checked in.';
  }
  if (lower.contains('active membership') || lower.contains('no membership')) {
    return 'Active membership required.';
  }
  if (lower.contains('network') || lower.contains('socket')) {
    return 'Network error. Check your connection and try again.';
  }
  // Strip "Exception: ApiException: " prefix that often appears.
  return raw.replaceAll('Exception: ', '').replaceAll('ApiException: ', '');
}
