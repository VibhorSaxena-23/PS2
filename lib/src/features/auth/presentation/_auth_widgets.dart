import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/theme/app_colors.dart';

// ─────────────────────────────────────────────────────────────────────────────
//  AuthTextField
// ─────────────────────────────────────────────────────────────────────────────

class AuthTextField extends StatelessWidget {
  const AuthTextField({
    super.key,
    required this.hintText,
    required this.prefixIcon,
    this.controller,
    this.labelText,
    this.keyboardType,
    this.obscureText = false,
    this.suffixIcon,
    this.onChanged,
  });

  final String hintText;
  final IconData prefixIcon;
  final TextEditingController? controller;
  final String? labelText;
  final TextInputType? keyboardType;
  final bool obscureText;
  final Widget? suffixIcon;
  final ValueChanged<String>? onChanged;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      keyboardType: keyboardType,
      obscureText: obscureText,
      onChanged: onChanged,
      style: GoogleFonts.poppins(
        fontSize: 14,
        color: AppColors.textPrimary,
      ),
      decoration: InputDecoration(
        labelText: labelText,
        hintText: hintText,
        hintStyle: GoogleFonts.poppins(
          fontSize: 14,
          color: AppColors.textMuted,
        ),
        labelStyle: GoogleFonts.poppins(
          fontSize: 13,
          color: AppColors.textSecondary,
        ),
        prefixIcon: Icon(prefixIcon, color: AppColors.textMuted, size: 20),
        suffixIcon: suffixIcon,
        filled: true,
        fillColor: AppColors.white,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide:
              const BorderSide(color: AppColors.inputBorder, width: 1.5),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide:
              const BorderSide(color: AppColors.inputFocusBorder, width: 1.8),
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  AuthPrimaryButton
// ─────────────────────────────────────────────────────────────────────────────

class AuthPrimaryButton extends StatelessWidget {
  const AuthPrimaryButton({
    super.key,
    required this.label,
    this.onPressed,
    this.isLoading = false,
  });

  final String label;
  final VoidCallback? onPressed;
  final bool isLoading;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 54,
      child: ElevatedButton(
        onPressed: isLoading ? null : onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.btnDark,
          disabledBackgroundColor: const Color(0xFFD1D5DB),
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
        child: isLoading
            ? const SizedBox(
                width: 22,
                height: 22,
                child: CircularProgressIndicator(
                  strokeWidth: 2.5,
                  color: Colors.white,
                ),
              )
            : Text(label),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  AuthBackButton
// ─────────────────────────────────────────────────────────────────────────────

class AuthBackButton extends StatelessWidget {
  const AuthBackButton({super.key});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => Navigator.maybePop(context),
      child: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: AppColors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.inputBorder),
        ),
        child: const Icon(
          Icons.arrow_back_rounded,
          size: 20,
          color: AppColors.textPrimary,
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  AuthOrDivider
// ─────────────────────────────────────────────────────────────────────────────

class AuthOrDivider extends StatelessWidget {
  const AuthOrDivider({super.key, this.label = 'Or continue with'});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        const Expanded(
          child: Divider(color: AppColors.divider, thickness: 1),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Text(
            label,
            style: GoogleFonts.poppins(
              fontSize: 12,
              color: AppColors.textMuted,
            ),
          ),
        ),
        const Expanded(
          child: Divider(color: AppColors.divider, thickness: 1),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  SocialButton
// ─────────────────────────────────────────────────────────────────────────────

enum AuthSocialIcon { google, apple }

class SocialButton extends StatelessWidget {
  const SocialButton({
    super.key,
    required this.label,
    required this.iconAsset,
    this.onPressed,
  });

  final String label;
  final AuthSocialIcon iconAsset;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 52,
      child: OutlinedButton(
        onPressed: onPressed,
        style: OutlinedButton.styleFrom(
          backgroundColor: AppColors.white,
          foregroundColor: AppColors.textPrimary,
          side: const BorderSide(color: AppColors.inputBorder, width: 1.5),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          textStyle: GoogleFonts.poppins(
            fontSize: 14,
            fontWeight: FontWeight.w500,
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _icon(),
            const SizedBox(width: 10),
            Text(label),
          ],
        ),
      ),
    );
  }

  Widget _icon() {
    switch (iconAsset) {
      case AuthSocialIcon.google:
        return _GoogleIcon();
      case AuthSocialIcon.apple:
        return const Icon(Icons.apple, size: 22, color: AppColors.textPrimary);
    }
  }
}

/// Hand-drawn Google "G" using a CustomPainter so we have no external asset dep.
class _GoogleIcon extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      size: const Size(22, 22),
      painter: _GoogleGPainter(),
    );
  }
}

class _GoogleGPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width / 2;
    final cy = size.height / 2;
    final r = size.width / 2 - 1;

    // Blue arc
    final paintBlue = Paint()
      ..color = const Color(0xFF4285F4)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.8
      ..strokeCap = StrokeCap.round;
    canvas.drawArc(
      Rect.fromCircle(center: Offset(cx, cy), radius: r),
      -1.57, // -90° start
      4.71,  // 270°
      false,
      paintBlue,
    );

    // Red (top-right to right)
    final paintRed = Paint()
      ..color = const Color(0xFFEA4335)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.8
      ..strokeCap = StrokeCap.round;
    canvas.drawArc(
      Rect.fromCircle(center: Offset(cx, cy), radius: r),
      -1.57,
      1.05,
      false,
      paintRed,
    );

    // Horizontal bar for the "G"
    final paintBar = Paint()
      ..color = const Color(0xFF4285F4)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.8
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(
      Offset(cx, cy),
      Offset(cx + r, cy),
      paintBar,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

// ─────────────────────────────────────────────────────────────────────────────
//  AuthBottomLink
// ─────────────────────────────────────────────────────────────────────────────

class AuthBottomLink extends StatelessWidget {
  const AuthBottomLink({
    super.key,
    required this.question,
    required this.action,
    required this.onTap,
  });

  final String question;
  final String action;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: GestureDetector(
        onTap: onTap,
        child: Text.rich(
          TextSpan(
            style: GoogleFonts.poppins(
              fontSize: 13,
              color: AppColors.textMuted,
            ),
            children: [
              TextSpan(text: question),
              TextSpan(
                text: action,
                style: GoogleFonts.poppins(
                  color: AppColors.textPrimary,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
