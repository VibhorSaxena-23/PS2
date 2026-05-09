import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/theme/app_colors.dart';
import '_auth_widgets.dart';
import 'register_step2_page.dart';
import 'sign_in_page.dart';

class RegisterStep1Page extends StatefulWidget {
  const RegisterStep1Page({super.key});

  @override
  State<RegisterStep1Page> createState() => _RegisterStep1PageState();
}

class _RegisterStep1PageState extends State<RegisterStep1Page> {
  final _firstNameCtrl = TextEditingController();
  final _lastNameCtrl = TextEditingController();

  @override
  void dispose() {
    _firstNameCtrl.dispose();
    _lastNameCtrl.dispose();
    super.dispose();
  }

  bool get _isValid =>
      _firstNameCtrl.text.trim().isNotEmpty &&
      _lastNameCtrl.text.trim().isNotEmpty;

  void _next() {
    if (!_isValid) return;
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => RegisterStep2Page(
          firstName: _firstNameCtrl.text.trim(),
          lastName: _lastNameCtrl.text.trim(),
        ),
      ),
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
                'Create Account',
                style: GoogleFonts.poppins(
                  fontSize: 34,
                  fontWeight: FontWeight.w800,
                  color: AppColors.textPrimary,
                  height: 1.1,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'Step 1 of 2 — Your name',
                style: GoogleFonts.poppins(
                  fontSize: 14,
                  color: AppColors.textSecondary,
                ),
              ),
              const SizedBox(height: 36),

              // ── First Name ────────────────────────────────────────────
              AuthTextField(
                controller: _firstNameCtrl,
                hintText: 'John',
                labelText: 'First Name',
                prefixIcon: Icons.person_outline_rounded,
                onChanged: (_) => setState(() {}),
              ),
              const SizedBox(height: 14),

              // ── Last Name ─────────────────────────────────────────────
              AuthTextField(
                controller: _lastNameCtrl,
                hintText: 'Doe',
                labelText: 'Last Name',
                prefixIcon: Icons.person_outline_rounded,
                onChanged: (_) => setState(() {}),
              ),
              const SizedBox(height: 32),

              // ── Next button ───────────────────────────────────────────
              AuthPrimaryButton(
                label: 'Next',
                onPressed: _isValid ? _next : null,
              ),
              const SizedBox(height: 32),

              AuthBottomLink(
                question: 'Already have an account?  ',
                action: 'Sign In',
                onTap: () => Navigator.pushReplacement(
                  context,
                  MaterialPageRoute(builder: (_) => const SignInPage()),
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
