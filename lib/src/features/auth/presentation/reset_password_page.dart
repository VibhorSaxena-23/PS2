import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/theme/app_colors.dart';
import '../data/auth_api.dart';
import '../data/auth_models.dart';
import '_auth_widgets.dart';
import 'sign_in_page.dart';

class ResetPasswordPage extends StatefulWidget {
  const ResetPasswordPage({super.key, required this.resetToken});

  final String resetToken;

  @override
  State<ResetPasswordPage> createState() => _ResetPasswordPageState();
}

class _ResetPasswordPageState extends State<ResetPasswordPage> {
  final _passwordCtrl = TextEditingController();
  final _confirmCtrl  = TextEditingController();
  bool _obscurePassword = true;
  bool _obscureConfirm  = true;
  bool _loading = false;
  String? _error;

  @override
  void dispose() {
    _passwordCtrl.dispose();
    _confirmCtrl.dispose();
    super.dispose();
  }

  bool get _isValid =>
      _passwordCtrl.text.length >= 8 &&
      _passwordCtrl.text == _confirmCtrl.text;

  Future<void> _submit() async {
    if (!_isValid || _loading) return;
    setState(() { _loading = true; _error = null; });

    try {
      await AuthApi.instance.resetPassword(
        ResetPasswordRequest(
          token: widget.resetToken,
          newPassword: _passwordCtrl.text,
        ),
      );
      if (!mounted) return;
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const SignInPage()),
        (route) => false,
      );
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Password reset! Please sign in.')),
      );
    } on AuthException catch (e) {
      setState(() { _error = e.message; _loading = false; });
    } catch (e) {
      setState(() { _error = 'Network error. Check your connection.'; _loading = false; });
    }
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

              Text(
                'New Password',
                style: GoogleFonts.poppins(
                  fontSize: 34,
                  fontWeight: FontWeight.w800,
                  color: AppColors.textPrimary,
                  height: 1.1,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'Choose a strong password',
                style: GoogleFonts.poppins(
                    fontSize: 14, color: AppColors.textSecondary),
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

              AuthTextField(
                controller: _passwordCtrl,
                hintText: 'New password',
                prefixIcon: Icons.lock_outline_rounded,
                obscureText: _obscurePassword,
                onChanged: (_) => setState(() => _error = null),
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
                      fontSize: 12, color: AppColors.textMuted),
                ),
              ),
              const SizedBox(height: 14),

              AuthTextField(
                controller: _confirmCtrl,
                hintText: 'Confirm new password',
                prefixIcon: Icons.lock_outline_rounded,
                obscureText: _obscureConfirm,
                onChanged: (_) => setState(() => _error = null),
                suffixIcon: IconButton(
                  icon: Icon(
                    _obscureConfirm
                        ? Icons.visibility_off_outlined
                        : Icons.visibility_outlined,
                    color: AppColors.textMuted,
                    size: 20,
                  ),
                  onPressed: () =>
                      setState(() => _obscureConfirm = !_obscureConfirm),
                ),
              ),
              const SizedBox(height: 32),

              AuthPrimaryButton(
                label: 'Reset Password',
                isLoading: _loading,
                onPressed: _isValid && !_loading ? _submit : null,
              ),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }
}
