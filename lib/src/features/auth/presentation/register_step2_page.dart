import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/theme/app_colors.dart';
import '../data/auth_api.dart';
import '../data/auth_models.dart';
import '../../../app.dart' show AppHomeEntry;
import 'otp_verify_page.dart';
import '_auth_widgets.dart';

class RegisterStep2Page extends StatefulWidget {
  const RegisterStep2Page({
    super.key,
    required this.firstName,
    required this.lastName,
  });

  final String firstName;
  final String lastName;

  @override
  State<RegisterStep2Page> createState() => _RegisterStep2PageState();
}
class _RegisterStep2PageState extends State<RegisterStep2Page> {
  final _emailCtrl    = TextEditingController();
  final _phoneCtrl    = TextEditingController();
  final _passwordCtrl = TextEditingController();
  bool _obscurePassword = true;
  bool _loading = false;
  String? _error;

  @override
  void dispose() {
    _emailCtrl.dispose();
    _phoneCtrl.dispose();
    _passwordCtrl.dispose();
    super.dispose();
  }

  bool get _isValid =>
      (_emailCtrl.text.trim().isNotEmpty || _phoneCtrl.text.trim().isNotEmpty) &&
      _passwordCtrl.text.length >= 8;

  Future<void> _createAccount() async {
    if (!_isValid || _loading) return;
    setState(() { _loading = true; _error = null; });

    try {
      final res = await AuthApi.instance.register(
        RegisterRequest(
          firstName:   widget.firstName,
          lastName:    widget.lastName,
          email: _emailCtrl.text.trim().isEmpty ? null : _emailCtrl.text.trim(),
          phoneNumber: _phoneCtrl.text.trim().isEmpty ? null : _phoneCtrl.text.trim(),
          password:    _passwordCtrl.text,
        ),
      );

      if (res.requiresOtp) {
        if (!mounted) return;
        await Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => OtpVerifyPage(
              email: _emailCtrl.text.trim().isEmpty ? null : _emailCtrl.text.trim(),
              phoneNumber: _phoneCtrl.text.trim().isEmpty ? null : _phoneCtrl.text.trim(),
              purpose: 'VERIFY',
            ),
          ),
        );
      } else {
        final token = res.accessToken ?? '';
        if (token.isNotEmpty) {
          await saveAuthState(token: token, authApi: AuthApi.instance);
        }
        if (!mounted) return;
        _goHome();
      }
    } on AuthException catch (e) {
      setState(() { _error = e.message; });
    } catch (e) {
      setState(() { _error = 'Network error. Check your connection.'; });
    } finally {
      if (mounted) {
        setState(() { _loading = false; });
      }
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.scaffoldBg,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 8),
              const AuthBackButton(),
              const SizedBox(height: 28),

              // ── Heading ───────────────────────────────────────────────
              Text(
                'Almost There',
                style: GoogleFonts.poppins(
                  fontSize: 34,
                  fontWeight: FontWeight.w800,
                  color: AppColors.textPrimary,
                  height: 1.1,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Step 2 of 2 — Account details',
                style: GoogleFonts.poppins(
                  fontSize: 14,
                  color: AppColors.textSecondary,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Welcome, ${widget.firstName}!',
                style: GoogleFonts.poppins(
                  fontSize: 13,
                  color: AppColors.textMuted,
                  fontStyle: FontStyle.italic,
                ),
              ),
              const SizedBox(height: 32),

              // Error banner
              if (_error != null) ...[
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 14, vertical: 10),
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
                              fontSize: 12,
                              color: const Color(0xFFDC2626))),
                    ),
                  ]),
                ),
                const SizedBox(height: 16),
              ],

              // ── Email ─────────────────────────────────────────────────
              AuthTextField(
                controller: _emailCtrl,
                hintText: 'your@email.com',
                prefixIcon: Icons.mail_outline_rounded,
                keyboardType: TextInputType.emailAddress,
                onChanged: (_) => setState(() {}),
              ),
              const SizedBox(height: 14),

              // ── Phone ─────────────────────────────────────────────────
              AuthTextField(
                controller: _phoneCtrl,
                hintText: '+1 (555) 000 0000',
                prefixIcon: Icons.phone_outlined,
                keyboardType: TextInputType.phone,
                onChanged: (_) => setState(() {}),
              ),
              const SizedBox(height: 14),

              // ── Password ──────────────────────────────────────────────
              AuthTextField(
                controller: _passwordCtrl,
                hintText: 'Create a password',
                prefixIcon: Icons.lock_outline_rounded,
                obscureText: _obscurePassword,
                onChanged: (_) => setState(() {}),
                suffixIcon: IconButton(
                  icon: Icon(
                    _obscurePassword
                        ? Icons.visibility_off_outlined
                        : Icons.visibility_outlined,
                    color: AppColors.textMuted,
                    size: 20,
                  ),
                  onPressed: () =>
                      setState(() => _obscurePassword = !_obscurePassword),
                ),
              ),
              const SizedBox(height: 6),
              Padding(
                padding: const EdgeInsets.only(left: 4),
                child: Text(
                  'Must be at least 8 characters',
                  style: GoogleFonts.poppins(
                    fontSize: 12,
                    color: AppColors.textMuted,
                  ),
                ),
              ),
              const SizedBox(height: 32),

              // ── Create Account button ─────────────────────────────────
              AuthPrimaryButton(
                label: 'Create Account',
                isLoading: _loading,
                onPressed: _isValid && !_loading ? _createAccount : null,
              ),
              const SizedBox(height: 20),

              // ── Terms ─────────────────────────────────────────────────
              Center(
                child: Text.rich(
                  TextSpan(
                    style: GoogleFonts.poppins(
                      fontSize: 11.5,
                      color: AppColors.textMuted,
                    ),
                    children: [
                      const TextSpan(text: 'By continuing, you agree to our '),
                      TextSpan(
                        text: 'Terms',
                        style: GoogleFonts.poppins(
                          color: AppColors.textPrimary,
                          fontWeight: FontWeight.w600,
                          decoration: TextDecoration.underline,
                        ),
                      ),
                      const TextSpan(text: ' and\n'),
                      TextSpan(
                        text: 'Privacy Policy',
                        style: GoogleFonts.poppins(
                          color: AppColors.textPrimary,
                          fontWeight: FontWeight.w600,
                          decoration: TextDecoration.underline,
                        ),
                      ),
                    ],
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }
}
