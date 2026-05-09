import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

import '../data/gym_api.dart';
import '../models/gym_models.dart';

// ══════════════════════════════════════════════════════════════════════════════
//  PaymentFlowPage — method selection → card form → success receipt
// ══════════════════════════════════════════════════════════════════════════════

class PaymentFlowPage extends StatefulWidget {
  const PaymentFlowPage({
    super.key,
    required this.gym,
    required this.plan,
    required this.gymApi,
    required this.onSuccess,
  });

  final GymDiscover gym;
  final GymPlan plan;
  final GymApi gymApi;
  final VoidCallback onSuccess;

  @override
  State<PaymentFlowPage> createState() => _PaymentFlowPageState();
}

enum _PaymentStep { method, card, processing, success }

enum _PaymentMethod { card, upi, wallet }

class _PaymentFlowPageState extends State<PaymentFlowPage> {
  _PaymentStep _step = _PaymentStep.method;
  _PaymentMethod _method = _PaymentMethod.card;

  // Card fields
  final _cardNumberCtrl = TextEditingController();
  final _expiryCtrl = TextEditingController();
  final _cvvCtrl = TextEditingController();
  final _nameCtrl = TextEditingController();
  String? _error;

  @override
  void dispose() {
    _cardNumberCtrl.dispose();
    _expiryCtrl.dispose();
    _cvvCtrl.dispose();
    _nameCtrl.dispose();
    super.dispose();
  }

  bool get _cardValid =>
      _cardNumberCtrl.text.replaceAll(' ', '').length == 16 &&
      _expiryCtrl.text.length == 5 &&
      _cvvCtrl.text.length >= 3 &&
      _nameCtrl.text.trim().isNotEmpty;

  Future<void> _processPayment() async {
    setState(() {
      _step = _PaymentStep.processing;
      _error = null;
    });

    try {
      // Enroll via API — backend handles payment recording
      await widget.gymApi.enroll(
        gymId: widget.gym.id,
        planId: widget.plan.id,
        gymName: widget.gym.name,
        planName: widget.plan.name,
        planPrice: widget.plan.price,
        provider: _method == _PaymentMethod.upi
            ? 'upi'
            : _method == _PaymentMethod.wallet
                ? 'wallet'
                : 'card',
      );
      if (!mounted) return;
      setState(() => _step = _PaymentStep.success);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _step = _PaymentStep.card;
        _error = 'Payment failed. Please try again.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF9FAFB),
      appBar: _step == _PaymentStep.success
          ? null
          : AppBar(
              backgroundColor: Colors.white,
              elevation: 0,
              leading: IconButton(
                icon: const Icon(Icons.arrow_back_rounded,
                    color: Color(0xFF111827)),
                onPressed: () {
                  if (_step == _PaymentStep.card) {
                    setState(() => _step = _PaymentStep.method);
                  } else {
                    Navigator.of(context).pop();
                  }
                },
              ),
              title: Text(
                'Payment',
                style: GoogleFonts.poppins(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: const Color(0xFF111827),
                ),
              ),
              centerTitle: true,
            ),
      body: switch (_step) {
        _PaymentStep.method => _buildMethodSelection(),
        _PaymentStep.card => _buildCardForm(),
        _PaymentStep.processing => _buildProcessing(),
        _PaymentStep.success => _buildSuccess(),
      },
    );
  }

  // ── Order summary widget (shared) ─────────────────────────────────────────

  Widget _buildOrderSummary() {
    final months = (widget.plan.duration / 30).round();
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFF3F4F6)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF4F46E5), Color(0xFF7C3AED)],
                  ),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.fitness_center_rounded,
                    color: Colors.white, size: 24),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.gym.name,
                      style: GoogleFonts.poppins(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: const Color(0xFF111827),
                      ),
                    ),
                    Text(
                      '${widget.plan.name} · $months month${months == 1 ? '' : 's'}',
                      style: GoogleFonts.poppins(
                        fontSize: 12,
                        color: const Color(0xFF6B7280),
                      ),
                    ),
                  ],
                ),
              ),
              Text(
                '\$${widget.plan.price.toStringAsFixed(0)}',
                style: GoogleFonts.poppins(
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                  color: const Color(0xFF4F46E5),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ── Step 1: Method selection ──────────────────────────────────────────────

  Widget _buildMethodSelection() {
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildOrderSummary(),
          const SizedBox(height: 24),
          Text(
            'Select Payment Method',
            style: GoogleFonts.poppins(
              fontSize: 17,
              fontWeight: FontWeight.w700,
              color: const Color(0xFF111827),
            ),
          ),
          const SizedBox(height: 14),
          _MethodTile(
            icon: Icons.credit_card_rounded,
            label: 'Credit / Debit Card',
            subtitle: 'Visa, Mastercard, RuPay',
            selected: _method == _PaymentMethod.card,
            onTap: () => setState(() => _method = _PaymentMethod.card),
          ),
          const SizedBox(height: 10),
          _MethodTile(
            icon: Icons.account_balance_rounded,
            label: 'UPI',
            subtitle: 'Google Pay, PhonePe, Paytm',
            selected: _method == _PaymentMethod.upi,
            onTap: () => setState(() => _method = _PaymentMethod.upi),
          ),
          const SizedBox(height: 10),
          _MethodTile(
            icon: Icons.account_balance_wallet_rounded,
            label: 'Wallet',
            subtitle: 'Pay from wallet balance',
            selected: _method == _PaymentMethod.wallet,
            onTap: () => setState(() => _method = _PaymentMethod.wallet),
          ),
          const Spacer(),
          SizedBox(
            width: double.infinity,
            height: 54,
            child: ElevatedButton(
              onPressed: () {
                if (_method == _PaymentMethod.card) {
                  setState(() => _step = _PaymentStep.card);
                } else {
                  _processPayment();
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF1A1A2E),
                foregroundColor: Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
              child: Text(
                'Continue',
                style: GoogleFonts.poppins(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
          SizedBox(height: MediaQuery.of(context).padding.bottom + 8),
        ],
      ),
    );
  }

  // ── Step 2: Card form ─────────────────────────────────────────────────────

  Widget _buildCardForm() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildOrderSummary(),
          const SizedBox(height: 24),
          Text(
            'Card Details',
            style: GoogleFonts.poppins(
              fontSize: 17,
              fontWeight: FontWeight.w700,
              color: const Color(0xFF111827),
            ),
          ),
          const SizedBox(height: 14),
          if (_error != null) ...[
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: const Color(0xFFFEE2E2),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                children: [
                  const Icon(Icons.error_outline_rounded,
                      size: 16, color: Color(0xFFDC2626)),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(_error!,
                        style: GoogleFonts.poppins(
                            fontSize: 12, color: const Color(0xFFDC2626))),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),
          ],
          // Card number
          _CardField(
            controller: _cardNumberCtrl,
            label: 'Card Number',
            hint: '1234 5678 9012 3456',
            icon: Icons.credit_card_rounded,
            keyboardType: TextInputType.number,
            formatters: [
              FilteringTextInputFormatter.digitsOnly,
              _CardNumberFormatter(),
              LengthLimitingTextInputFormatter(19),
            ],
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: _CardField(
                  controller: _expiryCtrl,
                  label: 'Expiry',
                  hint: 'MM/YY',
                  icon: Icons.calendar_today_rounded,
                  keyboardType: TextInputType.number,
                  formatters: [
                    FilteringTextInputFormatter.digitsOnly,
                    _ExpiryFormatter(),
                    LengthLimitingTextInputFormatter(5),
                  ],
                  onChanged: (_) => setState(() {}),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: _CardField(
                  controller: _cvvCtrl,
                  label: 'CVV',
                  hint: '123',
                  icon: Icons.lock_outline_rounded,
                  obscure: true,
                  keyboardType: TextInputType.number,
                  formatters: [
                    FilteringTextInputFormatter.digitsOnly,
                    LengthLimitingTextInputFormatter(4),
                  ],
                  onChanged: (_) => setState(() {}),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          _CardField(
            controller: _nameCtrl,
            label: 'Name on Card',
            hint: 'John Doe',
            icon: Icons.person_outline_rounded,
            keyboardType: TextInputType.name,
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: 28),
          // Pay button
          SizedBox(
            width: double.infinity,
            height: 54,
            child: ElevatedButton(
              onPressed: _cardValid ? _processPayment : null,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF1A1A2E),
                foregroundColor: Colors.white,
                disabledBackgroundColor: const Color(0xFFD1D5DB),
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
              child: Text(
                'Pay \$${widget.plan.price.toStringAsFixed(0)}',
                style: GoogleFonts.poppins(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
          const SizedBox(height: 12),
          Center(
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.lock_outline_rounded,
                    size: 14, color: Color(0xFF9CA3AF)),
                const SizedBox(width: 4),
                Text(
                  'Secured by 256-bit encryption',
                  style: GoogleFonts.poppins(
                    fontSize: 11,
                    color: const Color(0xFF9CA3AF),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── Step 3: Processing ────────────────────────────────────────────────────

  Widget _buildProcessing() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(
            width: 48,
            height: 48,
            child: CircularProgressIndicator(strokeWidth: 3),
          ),
          const SizedBox(height: 20),
          Text(
            'Processing Payment...',
            style: GoogleFonts.poppins(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: const Color(0xFF374151),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Please wait, do not press back',
            style: GoogleFonts.poppins(
              fontSize: 13,
              color: const Color(0xFF9CA3AF),
            ),
          ),
        ],
      ),
    );
  }

  // ── Step 4: Success / Receipt ─────────────────────────────────────────────

  Widget _buildSuccess() {
    final months = (widget.plan.duration / 30).round();
    final now = DateTime.now();
    final endDate = now.add(Duration(days: widget.plan.duration));

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            const Spacer(flex: 2),
            // Success icon
            Container(
              width: 80,
              height: 80,
              decoration: const BoxDecoration(
                color: Color(0xFFDCFCE7),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.check_rounded,
                size: 44,
                color: Color(0xFF16A34A),
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'Payment Successful!',
              style: GoogleFonts.poppins(
                fontSize: 24,
                fontWeight: FontWeight.w800,
                color: const Color(0xFF111827),
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'Your membership is now active',
              style: GoogleFonts.poppins(
                fontSize: 14,
                color: const Color(0xFF6B7280),
              ),
            ),
            const SizedBox(height: 28),
            // Receipt card
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withAlpha(8),
                    blurRadius: 20,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Column(
                children: [
                  _ReceiptRow('Gym', widget.gym.name),
                  _ReceiptRow('Plan', widget.plan.name),
                  _ReceiptRow(
                      'Duration', '$months month${months == 1 ? '' : 's'}'),
                  _ReceiptRow('Start Date',
                      '${now.day}/${now.month}/${now.year}'),
                  _ReceiptRow('End Date',
                      '${endDate.day}/${endDate.month}/${endDate.year}'),
                  const Divider(height: 24, color: Color(0xFFF3F4F6)),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Amount Paid',
                        style: GoogleFonts.poppins(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: const Color(0xFF111827),
                        ),
                      ),
                      Text(
                        '\$${widget.plan.price.toStringAsFixed(0)}',
                        style: GoogleFonts.poppins(
                          fontSize: 20,
                          fontWeight: FontWeight.w800,
                          color: const Color(0xFF4F46E5),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const Spacer(flex: 3),
            // Done button
            SizedBox(
              width: double.infinity,
              height: 54,
              child: ElevatedButton(
                onPressed: () {
                  widget.onSuccess();
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF1A1A2E),
                  foregroundColor: Colors.white,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
                child: Text(
                  'Done',
                  style: GoogleFonts.poppins(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
//  Sub-widgets
// ══════════════════════════════════════════════════════════════════════════════

class _MethodTile extends StatelessWidget {
  const _MethodTile({
    required this.icon,
    required this.label,
    required this.subtitle,
    required this.selected,
    required this.onTap,
  });
  final IconData icon;
  final String label;
  final String subtitle;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: selected ? const Color(0xFFF0F0FF) : Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: selected
                ? const Color(0xFF4F46E5)
                : const Color(0xFFE5E7EB),
            width: selected ? 2 : 1,
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: selected
                    ? const Color(0xFF4F46E5).withAlpha(20)
                    : const Color(0xFFF3F4F6),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon,
                  size: 22,
                  color: selected
                      ? const Color(0xFF4F46E5)
                      : const Color(0xFF6B7280)),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: GoogleFonts.poppins(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: const Color(0xFF111827),
                    ),
                  ),
                  Text(
                    subtitle,
                    style: GoogleFonts.poppins(
                      fontSize: 11,
                      color: const Color(0xFF9CA3AF),
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              selected
                  ? Icons.radio_button_checked_rounded
                  : Icons.radio_button_unchecked_rounded,
              color: selected
                  ? const Color(0xFF4F46E5)
                  : const Color(0xFFD1D5DB),
              size: 22,
            ),
          ],
        ),
      ),
    );
  }
}

class _CardField extends StatelessWidget {
  const _CardField({
    required this.controller,
    required this.label,
    required this.hint,
    required this.icon,
    this.obscure = false,
    this.keyboardType,
    this.formatters,
    this.onChanged,
  });
  final TextEditingController controller;
  final String label;
  final String hint;
  final IconData icon;
  final bool obscure;
  final TextInputType? keyboardType;
  final List<TextInputFormatter>? formatters;
  final ValueChanged<String>? onChanged;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: GoogleFonts.poppins(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: const Color(0xFF374151),
          ),
        ),
        const SizedBox(height: 6),
        TextField(
          controller: controller,
          obscureText: obscure,
          keyboardType: keyboardType,
          inputFormatters: formatters,
          onChanged: onChanged,
          style: GoogleFonts.poppins(
            fontSize: 14,
            fontWeight: FontWeight.w500,
            color: const Color(0xFF111827),
          ),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: GoogleFonts.poppins(
                fontSize: 14, color: const Color(0xFFD1D5DB)),
            prefixIcon:
                Icon(icon, size: 18, color: const Color(0xFF9CA3AF)),
            filled: true,
            fillColor: Colors.white,
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: Color(0xFFE5E7EB)),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide:
                  const BorderSide(color: Color(0xFF4F46E5), width: 2),
            ),
          ),
        ),
      ],
    );
  }
}

class _ReceiptRow extends StatelessWidget {
  const _ReceiptRow(this.label, this.value);
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: GoogleFonts.poppins(
              fontSize: 13,
              color: const Color(0xFF9CA3AF),
            ),
          ),
          Flexible(
            child: Text(
              value,
              style: GoogleFonts.poppins(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: const Color(0xFF374151),
              ),
              textAlign: TextAlign.end,
            ),
          ),
        ],
      ),
    );
  }
}

// ── Input formatters ─────────────────────────────────────────────────────────

class _CardNumberFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
      TextEditingValue oldValue, TextEditingValue newValue) {
    final digits = newValue.text.replaceAll(' ', '');
    final buffer = StringBuffer();
    for (int i = 0; i < digits.length; i++) {
      if (i > 0 && i % 4 == 0) buffer.write(' ');
      buffer.write(digits[i]);
    }
    final formatted = buffer.toString();
    return TextEditingValue(
      text: formatted,
      selection: TextSelection.collapsed(offset: formatted.length),
    );
  }
}

class _ExpiryFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
      TextEditingValue oldValue, TextEditingValue newValue) {
    final digits = newValue.text.replaceAll('/', '');
    if (digits.length >= 3) {
      final formatted = '${digits.substring(0, 2)}/${digits.substring(2)}';
      return TextEditingValue(
        text: formatted,
        selection: TextSelection.collapsed(offset: formatted.length),
      );
    }
    return newValue;
  }
}
