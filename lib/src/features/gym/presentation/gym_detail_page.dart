import 'package:flutter/services.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/network/api_exception.dart';
import '../data/gym_api.dart';
import '../models/gym_models.dart';

class GymDetailPage extends StatefulWidget {
  const GymDetailPage({
    super.key,
    required this.gym,
    required this.gymApi,
    required this.isJoined,
    required this.onChanged,
    this.distanceKmOverride,
    this.onSubscriptionRequested,
    this.preloadedDetail,
  });

  final GymDiscover gym;
  final GymApi gymApi;
  final bool isJoined;
  final VoidCallback onChanged;
  final double? distanceKmOverride;
  final VoidCallback? onSubscriptionRequested;

  /// Provide a pre-built [GymDetail] to skip the backend fetch (used for dummy/demo gyms).
  final GymDetail? preloadedDetail;

  @override
  State<GymDetailPage> createState() => _GymDetailPageState();
}

class _GymDetailPageState extends State<GymDetailPage> {
  GymDetail? _detail;
  List<GymPlan> _plans = [];
  bool _loading = true;
  String? _selectedPlanId;
  int _carouselIndex = 0;
  bool _isFavorite = false;

  static const _facilityIcons = {
    'cardio': Icons.directions_run_rounded,
    'weights': Icons.fitness_center_rounded,
    'free weights': Icons.fitness_center_rounded,
    'classes': Icons.groups_rounded,
    'group classes': Icons.groups_rounded,
    'yoga': Icons.self_improvement_rounded,
    'sauna': Icons.water_rounded,
    'locker': Icons.lock_outline_rounded,
    'training': Icons.person_rounded,
    'personal training': Icons.person_rounded,
    'parking': Icons.local_parking_rounded,
    'wifi': Icons.wifi_rounded,
    'wi-fi': Icons.wifi_rounded,
    'pool': Icons.pool_rounded,
    'crossfit': Icons.sports_gymnastics_rounded,
  };

  IconData _iconForFacility(String name) {
    final key = name.trim().toLowerCase();
    return _facilityIcons[key] ?? Icons.check_circle_outline_rounded;
  }

  static const _weekdayCodes = [
    'MON',
    'TUE',
    'WED',
    'THU',
    'FRI',
    'SAT',
    'SUN',
  ];

  bool _isOpenNow(String? open, String? close, List<String> days) {
    if (open == null || close == null) return false;
    final now = DateTime.now();
    if (days.isNotEmpty) {
      final today = _weekdayCodes[now.weekday - 1];
      final upper = days.map((d) => d.toUpperCase()).toList();
      if (!upper.contains(today)) return false;
    }
    final openMin = _toMinutes(open);
    final closeMin = _toMinutes(close);
    if (openMin == null || closeMin == null) return false;
    final nowMin = now.hour * 60 + now.minute;
    return nowMin >= openMin && nowMin <= closeMin;
  }

  int? _toMinutes(String hhmm) {
    final parts = hhmm.split(':');
    if (parts.length < 2) return null;
    final h = int.tryParse(parts[0]);
    final m = int.tryParse(parts[1]);
    if (h == null || m == null) return null;
    return h * 60 + m;
  }

  String _formatTime(String hhmm) {
    final parts = hhmm.split(':');
    if (parts.length < 2) return hhmm;
    final h = int.tryParse(parts[0]);
    final m = int.tryParse(parts[1]);
    if (h == null || m == null) return hhmm;
    final period = h >= 12 ? 'PM' : 'AM';
    final h12 = h % 12 == 0 ? 12 : h % 12;
    final mm = m.toString().padLeft(2, '0');
    return '$h12:$mm $period';
  }

  Widget _buildContactRow() {
    final phone = _detail?.phoneNumber ?? widget.gym.phoneNumber;
    final email = _detail?.email ?? widget.gym.email;
    if ((phone == null || phone.isEmpty) && (email == null || email.isEmpty)) {
      return const SizedBox.shrink();
    }
    return Padding(
      padding: const EdgeInsets.only(top: 10),
      child: Wrap(
        spacing: 14,
        runSpacing: 6,
        children: [
          if (phone != null && phone.isNotEmpty)
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.phone_outlined,
                  size: 14,
                  color: Color(0xFF6B7280),
                ),
                const SizedBox(width: 4),
                Text(
                  phone,
                  style: GoogleFonts.poppins(
                    fontSize: 12,
                    color: const Color(0xFF6B7280),
                  ),
                ),
              ],
            ),
          if (email != null && email.isNotEmpty)
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.mail_outline_rounded,
                  size: 14,
                  color: Color(0xFF6B7280),
                ),
                const SizedBox(width: 4),
                Text(
                  email,
                  style: GoogleFonts.poppins(
                    fontSize: 12,
                    color: const Color(0xFF6B7280),
                  ),
                ),
              ],
            ),
        ],
      ),
    );
  }

  // Branded fallback colors used only when the gym has no uploaded photos.
  static const _carouselGradients = [
    [Color(0xFF4F46E5), Color(0xFF7C3AED)],
    [Color(0xFF059669), Color(0xFF0891B2)],
    [Color(0xFFDC2626), Color(0xFFDB2777)],
  ];

  @override
  void initState() {
    super.initState();
    _loadFavorite();
    if (widget.preloadedDetail != null) {
      _detail = widget.preloadedDetail;
      _loading = false;
    } else {
      _loadDetail();
    }
  }

  String get _favoriteKey => 'favorite_gym_${widget.gym.id}';

  Future<void> _loadFavorite() async {
    final prefs = await SharedPreferences.getInstance();
    if (!mounted) return;
    setState(() => _isFavorite = prefs.getBool(_favoriteKey) ?? false);
  }

  Future<void> _toggleFavorite() async {
    final next = !_isFavorite;
    setState(() => _isFavorite = next);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_favoriteKey, next);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          next
              ? 'Saved ${widget.gym.name} to favorites'
              : 'Removed from favorites',
        ),
      ),
    );
  }

  List<String> get _carouselImages {
    final urls = <String>[];
    void addUrl(String? value) {
      final url = value?.trim();
      if (url == null || url.isEmpty || urls.contains(url)) return;
      urls.add(url);
    }

    addUrl(_detail?.coverImage);
    addUrl(_detail?.gymLogo);
    for (final url in _detail?.gymImages ?? const <String>[]) {
      addUrl(url);
    }
    addUrl(widget.gym.coverImage);
    addUrl(widget.gym.gymLogo);

    return urls;
  }

  Future<void> _shareGymInfo() async {
    final detail = _detail;
    final lines = <String>[widget.gym.name, widget.gym.location];
    final open = detail?.openingTime ?? widget.gym.openingTime;
    final close = detail?.closingTime ?? widget.gym.closingTime;
    if (open != null && close != null) {
      lines.add('Hours: ${_formatTime(open)} - ${_formatTime(close)}');
    }
    final phone = detail?.phoneNumber ?? widget.gym.phoneNumber;
    if (phone != null && phone.isNotEmpty) lines.add('Phone: $phone');
    final email = detail?.email ?? widget.gym.email;
    if (email != null && email.isNotEmpty) lines.add('Email: $email');

    await Clipboard.setData(ClipboardData(text: lines.join('\n')));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Gym details copied to clipboard')),
    );
  }

  Future<void> _loadDetail() async {
    try {
      final results = await Future.wait([
        widget.gymApi.getGymDetail(widget.gym.id),
        widget.gymApi.getGymPlans(widget.gym.id),
      ]);
      if (!mounted) return;
      setState(() {
        _detail = results[0] as GymDetail;
        _plans = results[1] as List<GymPlan>;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _loading = false);
    }
  }

  GymPlan? get _selectedPlan {
    if (_selectedPlanId == null) return null;
    return _plans.where((p) => p.id == _selectedPlanId).firstOrNull;
  }

  void _openBooking() {
    final plan = _selectedPlan;
    if (plan == null) return;
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => _BookingConfirmSheet(
        gym: widget.gym,
        plan: plan,
        gymApi: widget.gymApi,
        onSuccess: () {
          widget.onChanged();
          widget.onSubscriptionRequested?.call();
          Navigator.of(context).pop(); // dismiss sheet
          Navigator.of(context).pop(); // back to discover
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final plans = _plans;

    return Scaffold(
      backgroundColor: Colors.white,
      body: CustomScrollView(
        slivers: [
          // ── Image carousel header ────────────────────────────────────────
          SliverToBoxAdapter(child: _buildCarousel()),
          // ── Gym info ─────────────────────────────────────────────────────
          SliverToBoxAdapter(child: _buildInfo()),
          // ── Facilities ───────────────────────────────────────────────────
          SliverToBoxAdapter(child: _buildFacilities()),
          // ── Plans ────────────────────────────────────────────────────────
          if (_loading)
            const SliverToBoxAdapter(
              child: Padding(
                padding: EdgeInsets.all(32),
                child: Center(child: CircularProgressIndicator()),
              ),
            )
          else if (plans.isNotEmpty)
            SliverToBoxAdapter(child: _buildPlans(plans)),
          // ── Live gym snapshot ────────────────────────────────────────────
          SliverToBoxAdapter(child: _buildReviews()),
          // Bottom spacing for sticky button
          const SliverToBoxAdapter(child: SizedBox(height: 100)),
        ],
      ),
      // ── Sticky bottom CTA ────────────────────────────────────────────────
      bottomNavigationBar: _buildBottomCTA(),
    );
  }

  // ── Carousel ─────────────────────────────────────────────────────────────

  Widget _buildCarousel() {
    final images = _carouselImages;
    return SizedBox(
      height: 280,
      child: Stack(
        children: [
          PageView.builder(
            itemCount: images.isNotEmpty
                ? images.length
                : _carouselGradients.length,
            onPageChanged: (i) => setState(() => _carouselIndex = i),
            itemBuilder: (ctx, i) {
              if (images.isNotEmpty) {
                final imageUrl = images[i];
                return Stack(
                  fit: StackFit.expand,
                  children: [
                    Image.network(
                      imageUrl,
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) {
                        final grad =
                            _carouselGradients[i % _carouselGradients.length];
                        return Container(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: grad,
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                          ),
                        );
                      },
                    ),
                    Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            Colors.black.withAlpha(60),
                            Colors.black.withAlpha(20),
                            Colors.black.withAlpha(70),
                          ],
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                        ),
                      ),
                    ),
                    Positioned(
                      left: 20,
                      right: 20,
                      bottom: 30,
                      child: Text(
                        widget.gym.name,
                        style: GoogleFonts.poppins(
                          fontSize: 22,
                          fontWeight: FontWeight.w800,
                          color: Colors.white,
                          shadows: [
                            Shadow(
                              blurRadius: 10,
                              color: Colors.black.withAlpha(120),
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                );
              }

              final grad = _carouselGradients[i % _carouselGradients.length];
              return Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: grad,
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                ),
                child: Center(
                  child: Icon(
                    Icons.fitness_center_rounded,
                    size: 80,
                    color: Colors.white.withAlpha(40),
                  ),
                ),
              );
            },
          ),
          // Back button
          Positioned(
            top: MediaQuery.of(context).padding.top + 8,
            left: 12,
            child: _circleButton(
              Icons.arrow_back_rounded,
              () => Navigator.of(context).pop(),
            ),
          ),
          // Share + Favorite
          Positioned(
            top: MediaQuery.of(context).padding.top + 8,
            right: 12,
            child: Row(
              children: [
                _circleButton(
                  _isFavorite
                      ? Icons.favorite_rounded
                      : Icons.favorite_border_rounded,
                  _toggleFavorite,
                ),
                const SizedBox(width: 8),
                _circleButton(Icons.share_rounded, _shareGymInfo),
              ],
            ),
          ),
          // Page indicator dots
          Positioned(
            bottom: 16,
            left: 0,
            right: 0,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(
                images.isNotEmpty ? images.length : _carouselGradients.length,
                (i) => AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  margin: const EdgeInsets.symmetric(horizontal: 3),
                  width: _carouselIndex == i ? 24 : 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: _carouselIndex == i
                        ? Colors.white
                        : Colors.white.withAlpha(100),
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _circleButton(IconData icon, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: Colors.black.withAlpha(60),
          shape: BoxShape.circle,
        ),
        child: Icon(icon, size: 20, color: Colors.white),
      ),
    );
  }

  // ── Info section ──────────────────────────────────────────────────────────

  Widget _buildInfo() {
    final detailFacilities = _detail?.facilities ?? const <String>[];
    final facilities = detailFacilities.isNotEmpty
        ? detailFacilities
        : widget.gym.facilities;
    final planCount = widget.gym.planCount > 0
        ? widget.gym.planCount
        : _plans.length;
    final distanceKm = widget.distanceKmOverride ?? widget.gym.distanceKm;
    final distanceLabel = distanceKm != null
        ? '${distanceKm.toStringAsFixed(1)} km away'
        : widget.gym.location.split(',').first;
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Name
          Text(
            widget.gym.name,
            style: GoogleFonts.poppins(
              fontSize: 24,
              fontWeight: FontWeight.w800,
              color: const Color(0xFF111827),
            ),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              if (planCount > 0)
                _InfoChip(
                  label: '$planCount plan${planCount == 1 ? '' : 's'}',
                  color: const Color(0xFFDCFCE7),
                  textColor: const Color(0xFF15803D),
                ),
              _InfoChip(
                label: distanceLabel,
                color: const Color(0xFFF3F4F6),
                textColor: const Color(0xFF374151),
              ),
              if (facilities.isNotEmpty)
                _InfoChip(
                  label:
                      '${facilities.length} facilit${facilities.length == 1 ? 'y' : 'ies'}',
                  color: const Color(0xFFEFF6FF),
                  textColor: const Color(0xFF1D4ED8),
                ),
              if (widget.gym.checkInEnabled)
                _InfoChip(
                  label: 'QR check-in',
                  color: const Color(0xFFECFDF5),
                  textColor: const Color(0xFF047857),
                ),
              if (widget.gym.trialAvailable)
                _InfoChip(
                  label: 'Trial available',
                  color: const Color(0xFFFFF7ED),
                  textColor: const Color(0xFFC2410C),
                ),
            ],
          ),
          const SizedBox(height: 8),
          // Address
          Row(
            children: [
              const Icon(
                Icons.location_on_outlined,
                size: 16,
                color: Color(0xFF9CA3AF),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  widget.gym.location,
                  style: GoogleFonts.poppins(
                    fontSize: 13,
                    color: const Color(0xFF6B7280),
                  ),
                ),
              ),
            ],
          ),
          // Description
          if (widget.gym.description != null) ...[
            const SizedBox(height: 12),
            Text(
              widget.gym.description!,
              style: GoogleFonts.poppins(
                fontSize: 13,
                color: const Color(0xFF6B7280),
                height: 1.6,
              ),
            ),
          ],
          // Open/Closed badge + hours
          const SizedBox(height: 12),
          Builder(
            builder: (_) {
              final detail = _detail;
              final open = detail?.openingTime ?? widget.gym.openingTime;
              final close = detail?.closingTime ?? widget.gym.closingTime;
              final days = (detail?.workingDays.isNotEmpty ?? false)
                  ? detail!.workingDays
                  : widget.gym.workingDays;
              final isOpen = _isOpenNow(open, close, days);
              final hoursLabel = (open != null && close != null)
                  ? '${_formatTime(open)} – ${_formatTime(close)}'
                  : 'Hours not available';
              return Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: isOpen
                          ? const Color(0xFFDCFCE7)
                          : const Color(0xFFFEE2E2),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      isOpen ? 'Open Now' : 'Closed',
                      style: GoogleFonts.poppins(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: isOpen
                            ? const Color(0xFF16A34A)
                            : const Color(0xFFDC2626),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      hoursLabel,
                      style: GoogleFonts.poppins(
                        fontSize: 12,
                        color: const Color(0xFF9CA3AF),
                      ),
                    ),
                  ),
                ],
              );
            },
          ),
          if ((_detail?.workingDays.isNotEmpty ?? false) ||
              widget.gym.workingDays.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(
              'Open: ${((_detail?.workingDays.isNotEmpty ?? false) ? _detail!.workingDays : widget.gym.workingDays).join(', ')}',
              style: GoogleFonts.poppins(
                fontSize: 11,
                color: const Color(0xFF9CA3AF),
              ),
            ),
          ],
          _buildContactRow(),
          const SizedBox(height: 8),
          const Divider(color: Color(0xFFF3F4F6)),
        ],
      ),
    );
  }

  // ── Facilities ────────────────────────────────────────────────────────────

  Widget _buildFacilities() {
    final facilities = (_detail?.facilities.isNotEmpty ?? false)
        ? _detail!.facilities
        : widget.gym.facilities;
    if (facilities.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Facilities',
            style: GoogleFonts.poppins(
              fontSize: 17,
              fontWeight: FontWeight.w700,
              color: const Color(0xFF111827),
            ),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: facilities.map((f) {
              return Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: const Color(0xFFF0F9FF),
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(color: const Color(0xFFBAE6FD)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      _iconForFacility(f),
                      size: 16,
                      color: const Color(0xFF0369A1),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      f,
                      style: GoogleFonts.poppins(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: const Color(0xFF0369A1),
                      ),
                    ),
                  ],
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 8),
          const Divider(color: Color(0xFFF3F4F6)),
        ],
      ),
    );
  }

  // ── Plans ─────────────────────────────────────────────────────────────────

  Widget _buildPlans(List<GymPlan> plans) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Membership Plans',
            style: GoogleFonts.poppins(
              fontSize: 17,
              fontWeight: FontWeight.w700,
              color: const Color(0xFF111827),
            ),
          ),
          const SizedBox(height: 12),
          ...plans.map((plan) {
            final selected = _selectedPlanId == plan.id;
            final months = (plan.duration / 30).round();
            final perMonth = plan.price / (months > 0 ? months : 1);
            final label = months <= 1
                ? 'Monthly'
                : months <= 3
                ? 'Quarterly'
                : months <= 6
                ? 'Half-Yearly'
                : 'Annual';
            final isBestValue = months >= 6;

            return GestureDetector(
              onTap: () => setState(() => _selectedPlanId = plan.id),
              child: Container(
                margin: const EdgeInsets.only(bottom: 12),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: selected
                      ? const Color(0xFFF0F0FF)
                      : const Color(0xFFF9FAFB),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: selected
                        ? const Color(0xFF4F46E5)
                        : const Color(0xFFE5E7EB),
                    width: selected ? 2 : 1,
                  ),
                ),
                child: Stack(
                  children: [
                    Row(
                      children: [
                        Icon(
                          selected
                              ? Icons.radio_button_checked_rounded
                              : Icons.radio_button_unchecked_rounded,
                          color: selected
                              ? const Color(0xFF4F46E5)
                              : const Color(0xFF9CA3AF),
                          size: 22,
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                plan.name.isNotEmpty ? plan.name : label,
                                style: GoogleFonts.poppins(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w700,
                                  color: const Color(0xFF111827),
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                '${plan.duration} days',
                                style: GoogleFonts.poppins(
                                  fontSize: 12,
                                  color: const Color(0xFF6B7280),
                                ),
                              ),
                            ],
                          ),
                        ),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text(
                              '\$${plan.price.toStringAsFixed(0)}',
                              style: GoogleFonts.poppins(
                                fontSize: 20,
                                fontWeight: FontWeight.w800,
                                color: const Color(0xFF4F46E5),
                              ),
                            ),
                            Text(
                              '\$${perMonth.toStringAsFixed(0)}/mo',
                              style: GoogleFonts.poppins(
                                fontSize: 11,
                                color: const Color(0xFF9CA3AF),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                    if (isBestValue)
                      Positioned(
                        top: -4,
                        right: -4,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: const Color(0xFF22C55E),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            'Best Value',
                            style: GoogleFonts.poppins(
                              fontSize: 9,
                              fontWeight: FontWeight.w700,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            );
          }),
          const SizedBox(height: 8),
          const Divider(color: Color(0xFFF3F4F6)),
        ],
      ),
    );
  }

  // ── Reviews ───────────────────────────────────────────────────────────────

  Widget _buildReviews() {
    final detail = _detail;
    final open = detail?.openingTime ?? widget.gym.openingTime;
    final close = detail?.closingTime ?? widget.gym.closingTime;
    final detailFacilities = detail?.facilities ?? const <String>[];
    final facilities = detailFacilities.isNotEmpty
        ? detailFacilities
        : widget.gym.facilities;
    final planCount = widget.gym.planCount > 0
        ? widget.gym.planCount
        : _plans.length;
    final detailDays = detail?.workingDays ?? const <String>[];
    final isOpen = _isOpenNow(
      open,
      close,
      detailDays.isNotEmpty ? detailDays : widget.gym.workingDays,
    );
    final hoursLabel = open != null && close != null
        ? '${_formatTime(open)} - ${_formatTime(close)}'
        : 'Hours unavailable';

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Gym Snapshot',
            style: GoogleFonts.poppins(
              fontSize: 17,
              fontWeight: FontWeight.w700,
              color: const Color(0xFF111827),
            ),
          ),
          const SizedBox(height: 8),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFFF9FAFB),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFFE5E7EB)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    _InfoChip(
                      label: isOpen ? 'Open now' : 'Closed',
                      color: isOpen
                          ? const Color(0xFFDCFCE7)
                          : const Color(0xFFFEE2E2),
                      textColor: isOpen
                          ? const Color(0xFF16A34A)
                          : const Color(0xFFDC2626),
                    ),
                    _InfoChip(
                      label: '$planCount plan${planCount == 1 ? '' : 's'}',
                      color: const Color(0xFFEEF2FF),
                      textColor: const Color(0xFF4F46E5),
                    ),
                    _InfoChip(
                      label: '${facilities.length} facilities',
                      color: const Color(0xFFF0FDF4),
                      textColor: const Color(0xFF16A34A),
                    ),
                    _InfoChip(
                      label: hoursLabel,
                      color: const Color(0xFFF3F4F6),
                      textColor: const Color(0xFF374151),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                _DetailRow(
                  icon: Icons.fitness_center_rounded,
                  label: 'Training access',
                  value: widget.gym.membershipRequired
                      ? 'Membership required'
                      : 'Walk-ins allowed',
                ),
                const SizedBox(height: 10),
                _DetailRow(
                  icon: Icons.qr_code_scanner_rounded,
                  label: 'Check-in',
                  value: widget.gym.checkInEnabled
                      ? 'QR check-in enabled'
                      : 'Check-in not configured',
                ),
                const SizedBox(height: 10),
                _DetailRow(
                  icon: Icons.timer_outlined,
                  label: 'Auto checkout',
                  value: widget.gym.autoCheckoutMinutes != null
                      ? '${widget.gym.autoCheckoutMinutes} minutes'
                      : 'Not set',
                ),
                if (widget.gym.gymType != null &&
                    widget.gym.gymType!.isNotEmpty) ...[
                  const SizedBox(height: 10),
                  _DetailRow(
                    icon: Icons.category_outlined,
                    label: 'Gym type',
                    value: widget.gym.gymType!,
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── Sticky bottom CTA ────────────────────────────────────────────────────

  Widget _buildBottomCTA() {
    final plan = _selectedPlan;

    return Container(
      padding: EdgeInsets.fromLTRB(
        20,
        12,
        20,
        MediaQuery.of(context).padding.bottom + 12,
      ),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(15),
            blurRadius: 20,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: Row(
        children: [
          if (plan != null) ...[
            Expanded(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '\$${plan.price.toStringAsFixed(0)}',
                    style: GoogleFonts.poppins(
                      fontSize: 22,
                      fontWeight: FontWeight.w800,
                      color: const Color(0xFF111827),
                    ),
                  ),
                  Text(
                    plan.name,
                    style: GoogleFonts.poppins(
                      fontSize: 12,
                      color: const Color(0xFF6B7280),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 16),
          ],
          Expanded(
            flex: plan != null ? 2 : 1,
            child: SizedBox(
              height: 52,
              child: ElevatedButton(
                onPressed: widget.isJoined
                    ? null
                    : plan != null
                    ? _openBooking
                    : null,
                style: ElevatedButton.styleFrom(
                  backgroundColor: widget.isJoined
                      ? const Color(0xFF22C55E)
                      : const Color(0xFF1A1A2E),
                  foregroundColor: Colors.white,
                  elevation: 0,
                  disabledBackgroundColor: plan == null && !widget.isJoined
                      ? const Color(0xFFD1D5DB)
                      : null,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  textStyle: GoogleFonts.poppins(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                child: Text(
                  widget.isJoined
                      ? 'Already a Member'
                      : plan != null
                      ? 'Book Now'
                      : 'Select a Plan',
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Booking confirmation sheet ───────────────────────────────────────────────

enum _PaymentMethod { cash, razorpay }

class _BookingConfirmSheet extends StatefulWidget {
  const _BookingConfirmSheet({
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
  State<_BookingConfirmSheet> createState() => _BookingConfirmSheetState();
}

class _BookingConfirmSheetState extends State<_BookingConfirmSheet> {
  bool _loading = false;
  String? _error;
  _PaymentMethod _paymentMethod = _PaymentMethod.cash;

  Future<void> _register() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      if (_paymentMethod != _PaymentMethod.cash) {
        throw const FormatException(
          'Razorpay checkout is not wired yet. Please choose cash to request approval.',
        );
      }

      // Cash flow: create a pending subscription that the gym owner can approve.
      await widget.gymApi.subscribe(
        gymId: widget.gym.id,
        planId: widget.plan.id,
        gymName: widget.gym.name,
        planName: widget.plan.name,
        planPrice: widget.plan.price,
      );
      if (!mounted) return;
      widget.onSuccess();
    } catch (e) {
      if (!mounted) return;
      final msg = e is ApiException ? e.message : e.toString();
      setState(() {
        _loading = false;
        _error = msg;
      });
    }
  }

  Widget _buildPaymentTile({
    required _PaymentMethod method,
    required IconData icon,
    required String title,
    required String subtitle,
    bool disabled = false,
    String? comingSoonLabel,
  }) {
    final selected = _paymentMethod == method && !disabled;
    return GestureDetector(
      onTap: disabled ? null : () => setState(() => _paymentMethod = method),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: disabled
              ? const Color(0xFFF9FAFB)
              : selected
              ? const Color(0xFFF0F0FF)
              : Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: disabled
                ? const Color(0xFFE5E7EB)
                : selected
                ? const Color(0xFF4F46E5)
                : const Color(0xFFE5E7EB),
            width: selected ? 2 : 1,
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: disabled
                    ? const Color(0xFFF3F4F6)
                    : selected
                    ? const Color(0xFFEEF2FF)
                    : const Color(0xFFF3F4F6),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(
                icon,
                size: 20,
                color: disabled
                    ? const Color(0xFFD1D5DB)
                    : selected
                    ? const Color(0xFF4F46E5)
                    : const Color(0xFF6B7280),
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        title,
                        style: GoogleFonts.poppins(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: disabled
                              ? const Color(0xFFD1D5DB)
                              : const Color(0xFF111827),
                        ),
                      ),
                      if (comingSoonLabel != null) ...[
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 7,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF3F4F6),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            comingSoonLabel,
                            style: GoogleFonts.poppins(
                              fontSize: 9,
                              fontWeight: FontWeight.w700,
                              color: const Color(0xFF9CA3AF),
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: GoogleFonts.poppins(
                      fontSize: 11,
                      color: disabled
                          ? const Color(0xFFD1D5DB)
                          : const Color(0xFF9CA3AF),
                    ),
                  ),
                ],
              ),
            ),
            if (!disabled)
              Icon(
                selected
                    ? Icons.check_circle_rounded
                    : Icons.radio_button_unchecked_rounded,
                size: 22,
                color: selected
                    ? const Color(0xFF4F46E5)
                    : const Color(0xFFD1D5DB),
              ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final months = (widget.plan.duration / 30).round();
    final now = DateTime.now();
    final end = now.add(Duration(days: widget.plan.duration));
    final amountStr = '₹${widget.plan.price.toStringAsFixed(0)}';

    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      padding: EdgeInsets.fromLTRB(
        24,
        16,
        24,
        MediaQuery.of(context).padding.bottom + 24,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Handle bar
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: const Color(0xFFE5E7EB),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 20),
            Text(
              'Confirm Registration',
              style: GoogleFonts.poppins(
                fontSize: 20,
                fontWeight: FontWeight.w800,
                color: const Color(0xFF111827),
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'You\'re about to join ${widget.gym.name}',
              style: GoogleFonts.poppins(
                fontSize: 13,
                color: const Color(0xFF6B7280),
              ),
            ),
            const SizedBox(height: 20),

            // ── Order summary card ─────────────────────────────────────────
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFFF9FAFB),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xFFF3F4F6)),
              ),
              child: Column(
                children: [
                  _Row('Gym', widget.gym.name),
                  _Row('Plan', widget.plan.name),
                  _Row('Duration', '$months month${months == 1 ? '' : 's'}'),
                  _Row('Start Date', '${now.day}/${now.month}/${now.year}'),
                  _Row('End Date', '${end.day}/${end.month}/${end.year}'),
                  const Divider(height: 20, color: Color(0xFFE5E7EB)),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Total Amount',
                        style: GoogleFonts.poppins(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: const Color(0xFF111827),
                        ),
                      ),
                      Text(
                        amountStr,
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
            const SizedBox(height: 20),

            // ── Payment method ─────────────────────────────────────────────
            Text(
              'Payment Method',
              style: GoogleFonts.poppins(
                fontSize: 15,
                fontWeight: FontWeight.w700,
                color: const Color(0xFF111827),
              ),
            ),
            const SizedBox(height: 10),

            _buildPaymentTile(
              method: _PaymentMethod.cash,
              icon: Icons.payments_outlined,
              title: 'Pay Cash at Gym',
              subtitle: 'Hand over payment at the reception',
            ),

            _buildPaymentTile(
              method: _PaymentMethod.razorpay,
              icon: Icons.credit_card_rounded,
              title: 'Online Payment',
              subtitle: 'Cash payment is active for this release',
              disabled: true,
              comingSoonLabel: 'Not enabled',
            ),

            // ── Cash instruction note ──────────────────────────────────────
            if (_paymentMethod == _PaymentMethod.cash) ...[
              const SizedBox(height: 4),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 10,
                ),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFFBEB),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: const Color(0xFFFDE68A)),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(
                      Icons.info_outline_rounded,
                      size: 16,
                      color: Color(0xFFD97706),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Visit the gym and pay $amountStr at the reception. Your enrollment request is submitted now — the gym owner will activate your plan upon receiving payment.',
                        style: GoogleFonts.poppins(
                          fontSize: 11,
                          color: const Color(0xFF92400E),
                          height: 1.5,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],

            // ── Error banner ───────────────────────────────────────────────
            if (_error != null) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 10,
                ),
                decoration: BoxDecoration(
                  color: const Color(0xFFFEE2E2),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.error_outline_rounded,
                      size: 16,
                      color: Color(0xFFDC2626),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _error!,
                        style: GoogleFonts.poppins(
                          fontSize: 12,
                          color: const Color(0xFFDC2626),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],

            const SizedBox(height: 24),

            // ── Confirm button ─────────────────────────────────────────────
            SizedBox(
              width: double.infinity,
              height: 54,
              child: ElevatedButton(
                onPressed: _loading ? null : _register,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF1A1A2E),
                  foregroundColor: Colors.white,
                  disabledBackgroundColor: const Color(0xFF9CA3AF),
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  textStyle: GoogleFonts.poppins(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                child: _loading
                    ? const SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(
                          color: Colors.white,
                          strokeWidth: 2.5,
                        ),
                      )
                    : const Text('Confirm & Register'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Row extends StatelessWidget {
  const _Row(this.label, this.value);
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
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
              textAlign: TextAlign.end,
              style: GoogleFonts.poppins(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: const Color(0xFF374151),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _InfoChip extends StatelessWidget {
  const _InfoChip({
    required this.label,
    required this.color,
    required this.textColor,
  });

  final String label;
  final Color color;
  final Color textColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: GoogleFonts.poppins(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: textColor,
        ),
      ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  const _DetailRow({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 18, color: const Color(0xFF4F46E5)),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: GoogleFonts.poppins(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: const Color(0xFF6B7280),
                ),
              ),
              Text(
                value,
                style: GoogleFonts.poppins(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: const Color(0xFF111827),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
