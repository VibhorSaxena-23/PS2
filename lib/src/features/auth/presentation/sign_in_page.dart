import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/theme/app_colors.dart';
import '../data/auth_api.dart';
import '../data/auth_models.dart';
import '../../../app.dart' show AppHomeEntry;
import '_auth_widgets.dart';
import 'otp_verify_page.dart';
import 'register_step1_page.dart';

class SignInPage extends StatefulWidget {
  const SignInPage({super.key});

  @override
  State<SignInPage> createState() => _SignInPageState();
}
class _SignInPageState extends State<SignInPage> {
  final _emailCtrl    = TextEditingController();
  final _passwordCtrl = TextEditingController();
  bool _obscurePassword = true;
  bool _loading = false;
  String? _error;

  @override
  void dispose() {
    _emailCtrl.dispose();
    _passwordCtrl.dispose();
    super.dispose();
  }

  // ── Forgot password ────────────────────────────────────────────────────────

  void _showForgotPassword() {
    final emailCtrl = TextEditingController(text: _emailCtrl.text.trim());
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text('Reset Password',
            style: GoogleFonts.poppins(fontWeight: FontWeight.w700)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              "Enter your email and we'll send a reset code.",
              style: GoogleFonts.poppins(
                  fontSize: 13, color: AppColors.textSecondary),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: emailCtrl,
              keyboardType: TextInputType.emailAddress,
              decoration: InputDecoration(
                hintText: 'your@email.com',
                hintStyle: GoogleFonts.poppins(color: AppColors.textMuted),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: const BorderSide(color: Color(0xFFE5E7EB)),
                ),
                contentPadding: const EdgeInsets.symmetric(
                    horizontal: 14, vertical: 12),
              ),
              style: GoogleFonts.poppins(fontSize: 14),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: Text('Cancel',
                style: GoogleFonts.poppins(color: AppColors.textMuted)),
          ),
          TextButton(
            onPressed: () async {
              final email = emailCtrl.text.trim();
              if (email.isEmpty) return;
              Navigator.of(ctx).pop();
              try {
                await AuthApi.instance.forgotPassword(
                  ForgotPasswordRequest(email: email, channel: 'EMAIL'),
                );
                if (!mounted) return;
                Navigator.of(context).push(MaterialPageRoute(
                  builder: (_) => OtpVerifyPage(
                    email: email,
                    purpose: 'PASSWORD_RESET',
                  ),
                ));
              } catch (e) {
                if (!mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text(e.toString())),
                );
              }
            },
            child: Text('Send Code',
                style: GoogleFonts.poppins(
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary)),
          ),
        ],
      ),
    );
  }

  // ── Sign in ────────────────────────────────────────────────────────────────

  Future<void> _signIn() async {
    final email    = _emailCtrl.text.trim();
    final password = _passwordCtrl.text;
    if (email.isEmpty || password.isEmpty) return;

    setState(() { _loading = true; _error = null; });

    try {
      final res = await AuthApi.instance.login(
        LoginRequest(email: email, password: password),
      );

      await saveAuthState(token: res.accessToken, authApi: AuthApi.instance);

      if (!mounted) return;
      _goHome();
    } on AuthException catch (e) {
      setState(() { _error = e.message; _loading = false; });
    } catch (e) {
      final msg = e.toString();
      final isTimeout = msg.contains('TimeoutException') ||
          msg.contains('connectionTimeout') ||
          msg.contains('receiveTimeout');
      final friendly = isTimeout
          ? 'Server is taking too long to respond. Make sure the backend is running.'
          : 'Cannot reach server. Make sure the backend is running and reachable.';
      setState(() { _error = friendly; _loading = false; });
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

  // ── Build ──────────────────────────────────────────────────────────────────

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
                'Welcome Back',
                style: GoogleFonts.poppins(
                  fontSize: 34, fontWeight: FontWeight.w800,
                  color: AppColors.textPrimary, height: 1.1,
                ),
              ),
              const SizedBox(height: 6),
              Text('Sign in to continue',
                  style: GoogleFonts.poppins(
                      fontSize: 14, color: AppColors.textSecondary)),
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
                              fontSize: 12, color: const Color(0xFFDC2626))),
                    ),
                  ]),
                ),
                const SizedBox(height: 16),
              ],

              AuthTextField(
                controller: _emailCtrl,
                hintText: 'your@email.com',
                prefixIcon: Icons.mail_outline_rounded,
                keyboardType: TextInputType.emailAddress,
                onChanged: (_) => setState(() => _error = null),
              ),
              const SizedBox(height: 14),

              AuthTextField(
                controller: _passwordCtrl,
                hintText: 'Enter your password',
                prefixIcon: Icons.lock_outline_rounded,
                obscureText: _obscurePassword,
                onChanged: (_) => setState(() => _error = null),
                suffixIcon: IconButton(
                  icon: Icon(
                    _obscurePassword
                        ? Icons.visibility_off_outlined
                        : Icons.visibility_outlined,
                    color: AppColors.textMuted, size: 20,
                  ),
                  onPressed: () =>
                      setState(() => _obscurePassword = !_obscurePassword),
                ),
              ),
              const SizedBox(height: 10),

              Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  onPressed: _showForgotPassword,
                  style: TextButton.styleFrom(
                    padding: EdgeInsets.zero,
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                  child: Text('Forgot Password?',
                      style: GoogleFonts.poppins(
                          fontSize: 13, fontWeight: FontWeight.w500,
                          color: AppColors.textPrimary)),
                ),
              ),
              const SizedBox(height: 28),

              AuthPrimaryButton(
                label: 'Sign In',
                isLoading: _loading,
                onPressed: _loading ? null : _signIn,
              ),
              const SizedBox(height: 32),

              AuthBottomLink(
                question: "Don't have an account?  ",
                action: 'Sign Up',
                onTap: () => Navigator.pushReplacement(
                  context,
                  MaterialPageRoute(
                      builder: (_) => const RegisterStep1Page()),
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
