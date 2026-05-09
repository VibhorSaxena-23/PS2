import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/theme/app_colors.dart';
import '../data/auth_api.dart';
import '../data/auth_models.dart';
import '../../../app.dart' show AppHomeEntry;
import 'reset_password_page.dart';

class OtpVerifyPage extends StatefulWidget {
  const OtpVerifyPage({
    super.key,
    this.email,
    this.phoneNumber,
    required this.purpose, // 'VERIFY' | 'PASSWORD_RESET' | 'LOGIN'
  }) : assert(
          (email != null && email != '') || (phoneNumber != null && phoneNumber != ''),
          'Either email or phoneNumber is required.',
        );

  final String? email;
  final String? phoneNumber;
  final String purpose;

  @override
  State<OtpVerifyPage> createState() => _OtpVerifyPageState();
}
class _OtpVerifyPageState extends State<OtpVerifyPage> {
  static const _length = 6;

  late final List<TextEditingController> _controllers;
  late final List<FocusNode> _focusNodes;

  int _resendSeconds = 42;
  Timer? _resendTimer;
  bool _loading = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _controllers = List.generate(_length, (_) => TextEditingController());
    _focusNodes  = List.generate(_length, (_) => FocusNode());
    _startResendTimer();
  }

  @override
  void dispose() {
    for (final c in _controllers) { c.dispose(); }
    for (final f in _focusNodes) { f.dispose(); }
    _resendTimer?.cancel();
    super.dispose();
  }

  void _startResendTimer() {
    _resendTimer?.cancel();
    _resendSeconds = 42;
    _resendTimer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) { t.cancel(); return; }
      setState(() {
        _resendSeconds--;
        if (_resendSeconds <= 0) t.cancel();
      });
    });
  }

  String get _otp => _controllers.map((c) => c.text).join();
  bool get _isComplete => _otp.length == _length;
  String get _identifier => widget.email ?? widget.phoneNumber ?? '';
  String get _channel => widget.email != null ? 'EMAIL' : 'PHONE';

  // ── Resend ─────────────────────────────────────────────────────────────────

  Future<void> _resend() async {
    try {
      if (widget.purpose == 'PASSWORD_RESET') {
        await AuthApi.instance.forgotPassword(
          ForgotPasswordRequest(
            email: widget.email,
            phoneNumber: widget.phoneNumber,
            channel: _channel,
          ),
        );
      } else {
        await AuthApi.instance.requestOtp(
          OtpRequest(
            email: widget.email,
            phoneNumber: widget.phoneNumber,
            purpose: widget.purpose,
            channel: _channel,
          ),
        );
      }
      _startResendTimer();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString())),
      );
    }
  }

  // ── Verify ─────────────────────────────────────────────────────────────────

  Future<void> _verify() async {
    if (!_isComplete || _loading) return;
    setState(() { _loading = true; _error = null; });

    try {
      if (widget.purpose == 'PASSWORD_RESET') {
        final res = await AuthApi.instance.verifyForgotPasswordOtp(
          VerifyOtpRequest(
            email: widget.email,
            phoneNumber: widget.phoneNumber,
            code: _otp,
            purpose: widget.purpose,
            channel: _channel,
          ),
        );
        if (!mounted) return;
        final token = res.resetToken ?? '';
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(
            builder: (_) => ResetPasswordPage(resetToken: token),
          ),
        );
      } else {
        // VERIFY or LOGIN
        final res = await AuthApi.instance.verifyOtp(
          VerifyOtpRequest(
            email: widget.email,
            phoneNumber: widget.phoneNumber,
            code: _otp,
            purpose: widget.purpose,
            channel: _channel,
          ),
        );
        final token = res.accessToken ?? '';
        if (token.isNotEmpty) {
          await saveAuthState(token: token, authApi: AuthApi.instance);
        }
        if (!mounted) return;
        _goHome();
      }
    } on AuthException catch (e) {
      setState(() { _error = e.message; _loading = false; });
    } catch (e) {
      setState(() { _error = 'Network error. Check your connection.'; _loading = false; });
    }
  }

  void _goHome() {
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(
        builder: (ctx) => const AppHomeEntry(),
      ),
      (route) => false,
    );
  }

  // ── OTP input ──────────────────────────────────────────────────────────────

  void _onOtpChanged(int index, String value) {
    if (value.length == 1) {
      if (index < _length - 1) {
        FocusScope.of(context).requestFocus(_focusNodes[index + 1]);
      } else {
        _focusNodes[index].unfocus();
      }
    }
    setState(() {});
  }

  void _onKeyEvent(int index, KeyEvent event) {
    if (event is KeyDownEvent &&
        event.logicalKey == LogicalKeyboardKey.backspace &&
        _controllers[index].text.isEmpty &&
        index > 0) {
      FocusScope.of(context).requestFocus(_focusNodes[index - 1]);
      _controllers[index - 1].clear();
      setState(() {});
    }
  }

  // ── Build ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.scaffoldBg,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            children: [
              const SizedBox(height: 16),
              Align(
                alignment: Alignment.centerLeft,
                child: IconButton(
                  onPressed: () => Navigator.maybePop(context),
                  icon: const Icon(Icons.arrow_back_rounded),
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 36),

              // ── Mail icon ───────────────────────────────────────────────
              Container(
                width: 72,
                height: 72,
                decoration: BoxDecoration(
                  color: AppColors.accentGreenSoft,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const Center(
                  child: Icon(
                    Icons.mail_outline_rounded,
                    size: 36,
                    color: AppColors.accentGreen,
                  ),
                ),
              ),
              const SizedBox(height: 28),

              // ── Title ───────────────────────────────────────────────────
              Text(
                widget.purpose == 'PASSWORD_RESET'
                    ? 'Reset Password'
                    : 'Verify Code',
                style: GoogleFonts.poppins(
                  fontSize: 30,
                  fontWeight: FontWeight.w800,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                "We've sent a code to",
                style: GoogleFonts.poppins(
                  fontSize: 14,
                  color: AppColors.textSecondary,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 2),
              Text(
                _identifier,
                style: GoogleFonts.poppins(
                  fontSize: 14,
                  color: AppColors.textPrimary,
                  fontWeight: FontWeight.w600,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 36),

              // ── OTP boxes ───────────────────────────────────────────────
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: List.generate(
                  _length,
                  (i) => _OtpBox(
                    controller: _controllers[i],
                    focusNode: _focusNodes[i],
                    onChanged: (v) => _onOtpChanged(i, v),
                    onKeyEvent: (e) => _onKeyEvent(i, e),
                    autofocus: i == 0,
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // ── Error banner ────────────────────────────────────────────
              if (_error != null) ...[
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFEE2E2),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Row(children: [
                    const Icon(Icons.error_outline_rounded,
                        size: 16, color: Color(0xFFDC2626)),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(_error!,
                          style: GoogleFonts.poppins(
                              fontSize: 12, color: const Color(0xFFDC2626))),
                    ),
                  ]),
                ),
                const SizedBox(height: 12),
              ],

              // ── Resend countdown ────────────────────────────────────────
              _resendSeconds > 0
                  ? Text(
                      'Resend code in ${_resendSeconds}s',
                      style: GoogleFonts.poppins(
                        fontSize: 13,
                        color: AppColors.textMuted,
                      ),
                    )
                  : TextButton(
                      onPressed: _resend,
                      child: Text(
                        'Resend Code',
                        style: GoogleFonts.poppins(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textPrimary,
                        ),
                      ),
                    ),
              const SizedBox(height: 28),

              // ── Verify button ───────────────────────────────────────────
              SizedBox(
                width: double.infinity,
                height: 54,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _isComplete
                        ? AppColors.btnDark
                        : const Color(0xFF9CA3AF),
                    foregroundColor: Colors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                    textStyle: GoogleFonts.poppins(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  onPressed: (_isComplete && !_loading) ? _verify : null,
                  child: _loading
                      ? const SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(
                            strokeWidth: 2.5,
                            color: Colors.white,
                          ),
                        )
                      : const Text('Verify Code'),
                ),
              ),
              const SizedBox(height: 20),

              // ── Spam hint ───────────────────────────────────────────────
              Text(
                "Didn't receive the code? Check your spam folder",
                style: GoogleFonts.poppins(
                  fontSize: 12,
                  color: AppColors.textMuted,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }
}

class _OtpBox extends StatelessWidget {
  const _OtpBox({
    required this.controller,
    required this.focusNode,
    required this.onChanged,
    required this.onKeyEvent,
    this.autofocus = false,
  });

  final TextEditingController controller;
  final FocusNode focusNode;
  final ValueChanged<String> onChanged;
  final ValueChanged<KeyEvent> onKeyEvent;
  final bool autofocus;

  @override
  Widget build(BuildContext context) {
    return KeyboardListener(
      focusNode: FocusNode(),
      onKeyEvent: onKeyEvent,
      child: SizedBox(
        width: 48,
        height: 58,
        child: TextField(
          controller: controller,
          focusNode: focusNode,
          autofocus: autofocus,
          maxLength: 1,
          textAlign: TextAlign.center,
          keyboardType: TextInputType.number,
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          style: GoogleFonts.poppins(
            fontSize: 22,
            fontWeight: FontWeight.w700,
            color: AppColors.textPrimary,
          ),
          decoration: InputDecoration(
            counterText: '',
            contentPadding: EdgeInsets.zero,
            filled: true,
            fillColor: AppColors.white,
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(
                  color: AppColors.inputBorder, width: 1.5),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: AppColors.btnDark, width: 2),
            ),
          ),
          onChanged: onChanged,
        ),
      ),
    );
  }
}
