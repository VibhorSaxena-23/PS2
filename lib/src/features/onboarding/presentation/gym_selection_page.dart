import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';

import '../../../core/utils/formatters.dart';
import '../../../shared/widgets/app_primary_button.dart';
import '../../../shared/widgets/onboarding_scaffold.dart';
import '../../gym/data/gym_api.dart';
import '../../gym/models/gym_models.dart';

class GymSelectionPage extends StatefulWidget {
  const GymSelectionPage({
    super.key,
    required this.gymApi,
    required this.onGymJoined,
    required this.onSkip,
    this.onBack,
  });

  final GymApi gymApi;
  final void Function(GymMembership membership, String gymId) onGymJoined;
  final VoidCallback onSkip;
  final VoidCallback? onBack;

  @override
  State<GymSelectionPage> createState() => _GymSelectionPageState();
}

class _GymSelectionPageState extends State<GymSelectionPage> {
  static const double _discoverRadiusKm = 100;
  List<GymDiscover>? _gyms;
  bool _loading = true;
  String? _error;
  String? _selectedGymId;
  String? _expandedGymId;
  bool _joining = false;

  @override
  void initState() {
    super.initState();
    unawaited(_refreshWithLocation());
  }

  Future<Position?> _resolveDiscoverPosition() async {
    try {
      final serviceEnabled = kIsWeb
          ? true
          : await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        return null;
      }

      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        return null;
      }

      final live = kIsWeb
          ? await _getFreshWebDiscoverPosition()
          : await _getNativeDiscoverPosition();
      if (live != null) {
        return live;
      }

      return kIsWeb ? null : await Geolocator.getLastKnownPosition();
    } catch (err) {
      debugPrint('Onboarding location resolve failed: $err');
      return null;
    }
  }

  Future<Position?> _getFreshWebDiscoverPosition() async {
    final attempts = <WebSettings>[
      WebSettings(
        accuracy: LocationAccuracy.high,
        maximumAge: Duration.zero,
        timeLimit: const Duration(seconds: 20),
      ),
      WebSettings(
        accuracy: LocationAccuracy.medium,
        maximumAge: Duration.zero,
        timeLimit: const Duration(seconds: 25),
      ),
    ];

    for (final settings in attempts) {
      try {
        return await Geolocator.getCurrentPosition(locationSettings: settings);
      } catch (err) {
        debugPrint('Onboarding fresh web position failed: $err');
      }
    }
    return null;
  }

  Future<Position?> _getNativeDiscoverPosition() async {
    final attempts = <LocationSettings>[
      const LocationSettings(
        accuracy: LocationAccuracy.high,
        timeLimit: Duration(seconds: 12),
      ),
      const LocationSettings(
        accuracy: LocationAccuracy.medium,
        timeLimit: Duration(seconds: 18),
      ),
    ];

    for (final settings in attempts) {
      try {
        return await Geolocator.getCurrentPosition(locationSettings: settings);
      } catch (err) {
        debugPrint('Onboarding native position failed: $err');
      }
    }
    return null;
  }

  Future<void> _refreshWithLocation() async {
    if (mounted) {
      setState(() {
        _loading = true;
        _error = null;
      });
    }

    final pos = await _resolveDiscoverPosition();
    if (!mounted) return;
    if (pos == null) {
      setState(() {
        _gyms = const [];
        _loading = false;
        _error =
            'Location is required to show nearby gyms. Please enable GPS/location permission and retry.';
      });
      return;
    }

    try {
      debugPrint(
        'Onboarding gym discovery location: '
        'lat=${pos.latitude} lng=${pos.longitude} '
        'accuracy=${pos.accuracy.toStringAsFixed(1)}m '
        'timestamp=${pos.timestamp.toIso8601String()}',
      );
      final gyms = await widget.gymApi.discoverGyms(
        lat: pos.latitude,
        lng: pos.longitude,
        radiusKm: _discoverRadiusKm,
        limit: 100,
      );
      if (!mounted) return;
      setState(() {
        _gyms = gyms;
        _error = null;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      debugPrint('Onboarding gym discover failed: $e');
      setState(() {
        _gyms = const [];
        _error = e.toString();
        _loading = false;
      });
    }
  }

  Future<void> _join() async {
    if (_selectedGymId == null) return;
    setState(() {
      _joining = true;
      _error = null;
    });
    try {
      final memberships = await widget.gymApi.getMemberships();
      if (memberships.isNotEmpty) {
        final alreadySelected = memberships.any(
          (membership) => membership.gymId == _selectedGymId,
        );
        if (alreadySelected) {
          final existing = memberships.firstWhere(
            (membership) => membership.gymId == _selectedGymId,
          );
          widget.onGymJoined(existing, _selectedGymId!);
          return;
        }

        setState(() {
          _error =
              'Only one gym membership is allowed at a time. Leave your current gym first.';
        });
        return;
      }

      final selectedGym = _gyms?.firstWhere(
        (gym) => gym.id == _selectedGymId,
        orElse: () => throw StateError('Selected gym could not be resolved.'),
      );
      if (selectedGym == null) {
        throw StateError('Selected gym could not be resolved.');
      }

      // The refactor backend now creates memberships through the plan step.
      // We keep the current onboarding UX by treating this step as gym selection
      // only, then hand off the actual membership request to PlanEnrollPage.
      final placeholderMembership = GymMembership(
        id: 'selected-${selectedGym.id}',
        userId: 'pending',
        gymId: selectedGym.id,
        gymName: selectedGym.name,
        status: 'PENDING',
        startDate: DateTime.now(),
        createdAt: DateTime.now(),
      );
      widget.onGymJoined(placeholderMembership, _selectedGymId!);
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _joining = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return OnboardingScaffold(
      title: 'Choose Your Gym',
      subtitle: 'Pick a gym near you to start your journey.',
      progress: 0.66,
      showBack: true,
      onBack: widget.onBack,
      bottom: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          AppPrimaryButton(
            label: 'Join & Continue',
            icon: Icons.handshake_outlined,
            isLoading: _joining,
            onPressed: _selectedGymId != null ? _join : null,
          ),
          const SizedBox(height: 10),
          TextButton(
            onPressed: widget.onSkip,
            child: const Text('Skip for now'),
          ),
        ],
      ),
      child: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_loading) {
      return const Padding(
        padding: EdgeInsets.all(32),
        child: Center(child: CircularProgressIndicator()),
      );
    }

    if (_error != null) {
      return _ErrorBanner(message: _error!, onRetry: _refreshWithLocation);
    }

    if (_gyms == null || _gyms!.isEmpty) {
      return const Padding(
        padding: EdgeInsets.all(24),
        child: Center(child: Text('No gyms found nearby.')),
      );
    }

    return Column(
      children: _gyms!.map((gym) {
        final selected = gym.id == _selectedGymId;
        return Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: _GymCard(
            gym: gym,
            isSelected: selected,
            isExpanded: gym.id == _expandedGymId,
            onTap: () => setState(() {
              _selectedGymId = gym.id;
              _expandedGymId = _expandedGymId == gym.id ? null : gym.id;
            }),
          ),
        );
      }).toList(),
    );
  }
}

class _GymCard extends StatelessWidget {
  const _GymCard({
    required this.gym,
    required this.isSelected,
    required this.isExpanded,
    required this.onTap,
  });

  final GymDiscover gym;
  final bool isSelected;
  final bool isExpanded;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: isSelected ? const Color(0xFF4F46E5) : const Color(0xFFD1D5DB),
          width: isSelected ? 2 : 1,
        ),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              Row(
                children: [
                  Icon(
                    isSelected
                        ? Icons.radio_button_checked
                        : Icons.radio_button_unchecked,
                    color: isSelected
                        ? const Color(0xFF4F46E5)
                        : const Color(0xFF9CA3AF),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          gym.name,
                          style: theme.textTheme.bodyLarge?.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(gym.location, style: theme.textTheme.bodyMedium),
                      ],
                    ),
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      if (gym.distanceKm != null)
                        Text(
                          '${gym.distanceKm!.toStringAsFixed(1)} km',
                          style: theme.textTheme.bodyMedium?.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      if (gym.minPrice != null)
                        Text(
                          'from ${Formatters.price(gym.minPrice!)}',
                          style: theme.textTheme.bodySmall,
                        ),
                    ],
                  ),
                  const SizedBox(width: 8),
                  Icon(
                    isExpanded ? Icons.expand_less : Icons.expand_more,
                    color: const Color(0xFF6B7280),
                  ),
                ],
              ),
              if (isExpanded) ...[
                const SizedBox(height: 12),
                const Divider(height: 1),
                const SizedBox(height: 12),
                Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    'About Gym',
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                const SizedBox(height: 6),
                Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    gym.description?.trim().isNotEmpty == true
                        ? gym.description!
                        : 'No description available yet.',
                    style: theme.textTheme.bodyMedium,
                  ),
                ),
                const SizedBox(height: 8),
                Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    gym.planCount > 0
                        ? 'Plans available: ${gym.planCount}'
                        : 'No plans available right now.',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: gym.planCount > 0
                          ? const Color(0xFF15803D)
                          : const Color(0xFFB45309),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _ErrorBanner extends StatelessWidget {
  const _ErrorBanner({required this.message, required this.onRetry});
  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Card(
      color: const Color(0xFFFEE2E2),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Text(message, textAlign: TextAlign.center),
            const SizedBox(height: 10),
            OutlinedButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh),
              label: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }
}
