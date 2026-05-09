import 'dart:async';
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_map_cancellable_tile_provider/flutter_map_cancellable_tile_provider.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:latlong2/latlong.dart';

import '../../../core/config/app_config.dart';
import '../../../core/network/api_exception.dart';
import '../data/gym_api.dart';
import '../models/gym_models.dart';
import 'checkin_flow.dart';
import 'gym_detail_page.dart';

// ══════════════════════════════════════════════════════════════════════════════
//  GymHubPage  –  Discover tab
// ══════════════════════════════════════════════════════════════════════════════

class GymHubPage extends StatefulWidget {
  const GymHubPage({super.key, required this.gymApi});
  final GymApi gymApi;

  @override
  State<GymHubPage> createState() => _GymHubPageState();
}

class _GymHubPageState extends State<GymHubPage> {
  static const double _approximateAccuracyMeters = 1500;
  static const double _significantMoveMeters = 250;
  static const double _discoverRadiusKm = 100;

  // ── Data ────────────────────────────────────────────────────────────────────
  List<GymDiscover> _gyms = [];
  GymInfo? _info;
  bool _loading = true;
  String? _error;
  int _loadGeneration = 0;
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  // ── Location ────────────────────────────────────────────────────────────────
  LatLng _center = const LatLng(20.5937, 78.9629);
  LatLng? _userLocation;
  String _locationLabel = 'Locating…';
  bool _locating = false;
  bool _locationPromptOpen = false;

  // ── Map ─────────────────────────────────────────────────────────────────────
  final MapController _mapController = MapController();
  bool _mapReady = false;
  LatLng? _pendingMapCenter;
  double? _pendingMapZoom;
  List<LatLng>? _pendingFitPoints;
  int? _selectedGymIndex;

  // ── Horizontal scroll ───────────────────────────────────────────────────────
  final ScrollController _scrollController = ScrollController();
  final PageController _cardPageController = PageController(
    viewportFraction: .82,
  );

  @override
  void initState() {
    super.initState();
    // Location-first flow: ask for location, then load nearby gyms.
    unawaited(_resolveLocationForMap(refreshGyms: true));
  }

  @override
  void dispose() {
    _mapController.dispose();
    _cardPageController.dispose();
    _scrollController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  void _onMapReady() {
    _mapReady = true;
    final pendingCenter = _pendingMapCenter;
    final pendingZoom = _pendingMapZoom;
    final pendingFitPoints = _pendingFitPoints;
    _pendingMapCenter = null;
    _pendingMapZoom = null;
    _pendingFitPoints = null;

    if (pendingCenter != null) {
      _mapController.move(pendingCenter, pendingZoom ?? 13);
    }
    if (pendingFitPoints != null && pendingFitPoints.isNotEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _fitMapToPointsSafely(pendingFitPoints);
      });
    }
  }

  void _moveMapSafely(LatLng center, double zoom) {
    _center = center;
    if (!_mapReady) {
      _pendingMapCenter = center;
      _pendingMapZoom = zoom;
      return;
    }

    _mapController.move(center, zoom);
  }

  List<LatLng> _mapFitPointsFor(
    List<GymDiscover> gyms, {
    bool includeUser = true,
  }) {
    return [
      if (includeUser && _userLocation != null) _userLocation!,
      ...gyms.map((gym) => LatLng(gym.latitude, gym.longitude)),
    ];
  }

  void _fitMapToPointsSafely(List<LatLng> points, {double maxZoom = 14.5}) {
    if (points.isEmpty) return;
    if (points.length == 1) {
      _moveMapSafely(points.first, maxZoom);
      return;
    }

    if (!_mapReady) {
      _pendingFitPoints = List<LatLng>.from(points);
      return;
    }

    _mapController.fitCamera(
      CameraFit.bounds(
        bounds: LatLngBounds.fromPoints(points),
        padding: const EdgeInsets.fromLTRB(48, 64, 48, 118),
        maxZoom: maxZoom,
        minZoom: 5,
      ),
    );
    _center = _mapController.camera.center;
  }

  void _fitMapToCurrentResults() {
    _fitMapToPointsSafely(_mapFitPointsFor(_visibleGyms));
  }

  List<GymDiscover> get _visibleGyms {
    final query = _searchQuery.trim();
    if (query.isEmpty) return _gyms;
    return _gyms.where((gym) {
      final haystack = [
        gym.name,
        gym.location,
        gym.description ?? '',
      ].join(' ').toLowerCase();
      return haystack.contains(query);
    }).toList();
  }

  GymDiscover? get _selectedGym {
    final index = _selectedGymIndex;
    final gyms = _visibleGyms;
    if (index == null || index < 0 || index >= gyms.length) return null;
    return gyms[index];
  }

  void _setSearchQuery(String value) {
    setState(() {
      _searchQuery = value.trim().toLowerCase();
      _selectedGymIndex = null;
    });

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_cardPageController.hasClients) return;
      if (_visibleGyms.isNotEmpty) {
        _cardPageController.jumpToPage(0);
        _fitMapToCurrentResults();
      }
    });
  }

  void _clearSearch() {
    _searchController.clear();
    _setSearchQuery('');
  }

  Future<void> _scrollToGymList() async {
    if (!_scrollController.hasClients) return;
    await _scrollController.animateTo(
      _scrollController.position.maxScrollExtent,
      duration: const Duration(milliseconds: 400),
      curve: Curves.easeOutCubic,
    );
  }

  String _selectedGymDistanceText() {
    final gym = _selectedGym;
    if (gym == null) return 'Tap a gym to see its distance';
    return _selectedGymDistanceLabel(
      _distanceFromUserToGym(gym),
      _userLocation != null,
    );
  }

  String _gymTypeLabel(GymDiscover gym) {
    final raw = gym.gymType ?? gym.institutionType;
    if (raw == null || raw.trim().isEmpty) return 'Gym';
    return raw
        .replaceAll('_', ' ')
        .toLowerCase()
        .split(' ')
        .where((part) => part.isNotEmpty)
        .map((part) => '${part[0].toUpperCase()}${part.substring(1)}')
        .join(' ');
  }

  bool get _browserLocationOverlapsGym {
    final userLocation = _userLocation;
    if (!kIsWeb || userLocation == null) return false;
    return _gyms.any((gym) {
      final meters = Geolocator.distanceBetween(
        userLocation.latitude,
        userLocation.longitude,
        gym.latitude,
        gym.longitude,
      );
      return meters <= 25;
    });
  }

  double? _distanceFromUserToGym(GymDiscover gym) {
    final userLocation = _userLocation;
    if (userLocation == null) return null;
    return Geolocator.distanceBetween(
          userLocation.latitude,
          userLocation.longitude,
          gym.latitude,
          gym.longitude,
        ) /
        1000;
  }

  List<Polyline<Object>> _buildRoutePolylines() {
    final userLocation = _userLocation;
    final selectedGym = _selectedGym;
    if (userLocation == null || selectedGym == null) return const [];

    final points = [
      userLocation,
      LatLng(selectedGym.latitude, selectedGym.longitude),
    ];

    return [
      Polyline<Object>(
        points: points,
        strokeWidth: 10,
        color: const Color(0xFF111827).withAlpha(40),
        borderStrokeWidth: 10,
        borderColor: Colors.white.withAlpha(90),
        strokeCap: StrokeCap.round,
        strokeJoin: StrokeJoin.round,
        pattern: StrokePattern.dashed(segments: [18, 10]),
      ),
      Polyline<Object>(
        points: points,
        strokeWidth: 4,
        color: const Color(0xFF4F46E5).withAlpha(220),
        strokeCap: StrokeCap.round,
        strokeJoin: StrokeJoin.round,
        pattern: StrokePattern.dashed(segments: [14, 8]),
      ),
    ];
  }

  // ── Location — updates the map center and refreshes the gym list ──────────

  void _logResolvedPosition(String source, Position position) {
    debugPrint(
      'Gym discovery location[$source]: '
      'lat=${position.latitude} lng=${position.longitude} '
      'accuracy=${position.accuracy.toStringAsFixed(1)}m '
      'timestamp=${position.timestamp.toIso8601String()}',
    );
  }

  void _applyResolvedLocation(
    Position position, {
    double zoom = 13,
    String source = 'live',
  }) {
    _logResolvedPosition(source, position);
    final latLng = LatLng(position.latitude, position.longitude);
    setState(() {
      _userLocation = latLng;
      _center = latLng;
      _locationLabel = position.accuracy > _approximateAccuracyMeters
          ? 'Approximate location'
          : 'Near you';
      _locating = false;
    });
    _moveMapSafely(latLng, zoom);
  }

  bool _hasSignificantLocationChange(Position previous, Position next) {
    return Geolocator.distanceBetween(
          previous.latitude,
          previous.longitude,
          next.latitude,
          next.longitude,
        ) >
        _significantMoveMeters;
  }

  Future<Position?> _getReliableCurrentPosition() async {
    if (kIsWeb) {
      return _getFreshWebPosition();
    }

    final attempts = <LocationSettings>[
      const LocationSettings(
        accuracy: LocationAccuracy.high,
        timeLimit: Duration(seconds: 12),
      ),
      const LocationSettings(
        accuracy: LocationAccuracy.medium,
        timeLimit: Duration(seconds: 18),
      ),
      const LocationSettings(
        accuracy: LocationAccuracy.low,
        timeLimit: Duration(seconds: 20),
      ),
    ];

    for (final settings in attempts) {
      try {
        return await Geolocator.getCurrentPosition(locationSettings: settings);
      } catch (err) {
        debugPrint('Current position attempt failed: $err');
      }
    }

    try {
      return await Geolocator.getPositionStream(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.medium,
          distanceFilter: 0,
        ),
      ).first.timeout(const Duration(seconds: 12));
    } catch (err) {
      debugPrint('Position stream fallback failed: $err');
      return null;
    }
  }

  Future<Position?> _getFreshWebPosition() async {
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
        debugPrint('Fresh web position attempt failed: $err');
      }
    }

    try {
      return await Geolocator.getPositionStream(
        locationSettings: WebSettings(
          accuracy: LocationAccuracy.high,
          distanceFilter: 0,
          maximumAge: Duration.zero,
        ),
      ).first.timeout(const Duration(seconds: 20));
    } catch (err) {
      debugPrint('Fresh web position stream failed: $err');
      return null;
    }
  }

  Future<void> _resolveLocationForMap({bool refreshGyms = true}) async {
    setState(() {
      _locating = true;
      _error = null;
    });
    try {
      // On web, we should still attempt geolocation directly because browser
      // permission UX does not always map cleanly to service-enabled checks.
      final serviceEnabled = kIsWeb
          ? true
          : await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        _stopLocationDiscovery(label: 'Location off');
        unawaited(
          _showLocationPrompt(
            title: 'Turn on location services',
            message:
                'Enable location to see gyms within ${_discoverRadiusKm.toStringAsFixed(0)} km of you.',
            canOpenLocationSettings: !kIsWeb,
          ),
        );
        return;
      }

      var perm = await Geolocator.checkPermission();
      if (perm == LocationPermission.denied) {
        perm = await Geolocator.requestPermission();
      }
      if (perm == LocationPermission.deniedForever) {
        _stopLocationDiscovery(label: 'Location blocked');
        unawaited(
          _showLocationPrompt(
            title: 'Location permission blocked',
            message:
                'Allow location from app settings to get nearby gyms. We will not show fallback cities.',
            canOpenAppSettings: true,
          ),
        );
        return;
      }
      if (perm == LocationPermission.denied) {
        _stopLocationDiscovery(label: 'Location needed');
        unawaited(
          _showLocationPrompt(
            title: 'Allow location access',
            message:
                'Turn on location permission to load gyms near your current position only.',
          ),
        );
        return;
      }

      final cached = kIsWeb ? null : await Geolocator.getLastKnownPosition();
      var loadedFromCached = false;
      if (cached != null && mounted) {
        _applyResolvedLocation(cached, zoom: 12, source: 'cached');
        if (refreshGyms) {
          loadedFromCached = true;
          unawaited(_load());
        }
      }

      final pos = await _getReliableCurrentPosition();
      if (!mounted) return;

      if (pos != null) {
        final shouldReload =
            !loadedFromCached ||
            cached == null ||
            _hasSignificantLocationChange(cached, pos);
        _applyResolvedLocation(pos, source: kIsWeb ? 'fresh-web' : 'live');
        if (refreshGyms && shouldReload) {
          await _load();
        }
        return;
      }

      if (cached != null) {
        setState(() {
          _locating = false;
          _locationLabel = 'Approximate location';
        });
        return;
      }
    } catch (err) {
      debugPrint('Location resolve failed: $err');
      if (_userLocation != null) {
        setState(() {
          _locating = false;
          _locationLabel = 'Approximate location';
        });
        if (refreshGyms) {
          await _load();
        }
        return;
      }
    }

    _stopLocationDiscovery(label: 'Location unavailable');
    unawaited(
      _showLocationPrompt(
        title: 'Unable to detect location',
        message:
            'We could not lock your current location yet. Retry once GPS is stable. No fallback city gyms will be shown.',
      ),
    );
  }

  Future<void> _showLocationPrompt({
    required String title,
    required String message,
    bool canOpenAppSettings = false,
    bool canOpenLocationSettings = false,
  }) async {
    if (!mounted || _locationPromptOpen) return;
    _locationPromptOpen = true;
    try {
      await showModalBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        builder: (ctx) {
          return SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(18, 18, 18, 14),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: GoogleFonts.poppins(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: const Color(0xFF111827),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    message,
                    style: GoogleFonts.poppins(
                      fontSize: 13,
                      color: const Color(0xFF4B5563),
                    ),
                  ),
                  const SizedBox(height: 16),
                  if (canOpenLocationSettings)
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: () async {
                          Navigator.of(ctx).pop();
                          await Geolocator.openLocationSettings();
                          if (!mounted) return;
                          await _resolveLocationForMap(refreshGyms: true);
                        },
                        icon: const Icon(Icons.location_searching_rounded),
                        label: const Text('Open Location Settings'),
                      ),
                    ),
                  if (canOpenAppSettings)
                    Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          onPressed: () async {
                            Navigator.of(ctx).pop();
                            await Geolocator.openAppSettings();
                            if (!mounted) return;
                            await _resolveLocationForMap(refreshGyms: true);
                          },
                          icon: const Icon(Icons.settings_rounded),
                          label: const Text('Open App Settings'),
                        ),
                      ),
                    ),
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        onPressed: () async {
                          Navigator.of(ctx).pop();
                          await _resolveLocationForMap(refreshGyms: true);
                        },
                        icon: const Icon(Icons.my_location_rounded),
                        label: const Text('Retry current location'),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      );
    } finally {
      _locationPromptOpen = false;
    }
  }

  void _stopLocationDiscovery({required String label}) {
    if (!mounted) return;
    setState(() {
      _userLocation = null;
      _gyms = [];
      _selectedGymIndex = null;
      _locationLabel = label;
      _locating = false;
      _loading = false;
      _error = null;
    });
  }

  // ── Data loading ─────────────────────────────────────────────────────────────

  Future<void> _load() async {
    final generation = ++_loadGeneration;
    setState(() {
      _loading = true;
      _error = null;
    });

    // Fire gym list and user info concurrently but INDEPENDENTLY.
    // Info is non-critical — patches the membership banner after first paint.
    unawaited(_loadInfo());

    try {
      final gyms = await _fetchAllGyms();
      if (!mounted || generation != _loadGeneration) return;
      setState(() {
        _gyms = gyms;
        _loading = false;
        final selectedIndex = _selectedGymIndex;
        _selectedGymIndex = gyms.isEmpty
            ? null
            : (selectedIndex != null && selectedIndex < gyms.length
                  ? selectedIndex
                  : 0);
        if (_userLocation != null && _gyms.isEmpty) {
          _locationLabel = 'No gyms nearby';
        }
      });
      if (gyms.isNotEmpty) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted || generation != _loadGeneration) return;
          _fitMapToCurrentResults();
        });
      }
    } catch (e) {
      if (!mounted || generation != _loadGeneration) return;
      debugPrint('Gym discover failed: $e');
      setState(() {
        _gyms = [];
        _error = e is ApiException && e.message.isNotEmpty
            ? e.message
            : 'Could not load gyms. Check your connection.';
        _loading = false;
      });
    }
  }

  /// Uses the web service's geo-based discover endpoint.
  /// Discovery is location-only: no fallback city or seed coordinates are used.
  Future<List<GymDiscover>> _fetchAllGyms() async {
    final userLocation = _userLocation;
    if (userLocation == null) return const [];

    final lat = userLocation.latitude;
    final lng = userLocation.longitude;
    debugPrint(
      'Discover gyms request: baseUrl=${AppConfig.webApiBaseUrl} lat=$lat lng=$lng radius=$_discoverRadiusKm',
    );
    return widget.gymApi.discoverGyms(
      lat: lat,
      lng: lng,
      radiusKm: _discoverRadiusKm,
      limit: 100,
    );
  }

  /// Loads membership info silently after first paint.
  Future<void> _loadInfo() async {
    try {
      final info = await widget.gymApi.getInfo();
      if (!mounted) return;
      setState(() => _info = _restrictToSingle(info));
    } catch (_) {
      // Non-critical — membership banner simply won't show
    }
  }

  GymInfo _restrictToSingle(GymInfo info) {
    if (info.memberships.length <= 1) return info;
    final primary = info.memberships.firstWhere(
      (m) => m.status.toUpperCase() == 'ACTIVE',
      orElse: () => info.memberships.first,
    );
    return GymInfo(memberships: [primary]);
  }

  // ── Active membership ────────────────────────────────────────────────────────

  GymMembership? get _activeMembership => _info?.memberships
      .where((m) => m.status.toUpperCase() == 'ACTIVE')
      .firstOrNull;

  // ── Build ────────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      body: Column(
        children: [
          _buildTopBar(),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : _error != null
                ? _buildError()
                : _buildBody(),
          ),
        ],
      ),
    );
  }

  // ── Top bar (location + header) ───────────────────────────────────────────

  Widget _buildTopBar() {
    return Container(
      color: Colors.white,
      padding: EdgeInsets.only(
        top: MediaQuery.of(context).padding.top + 8,
        left: 16,
        right: 16,
        bottom: 12,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Location pill
          GestureDetector(
            onTap: _resolveLocationForMap,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: const Color(0xFFF3F4F6),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    Icons.location_on_rounded,
                    size: 18,
                    color: Color(0xFF4F46E5),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    _locating ? 'Detecting location…' : _locationLabel,
                    style: GoogleFonts.poppins(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: const Color(0xFF111827),
                    ),
                  ),
                  const SizedBox(width: 4),
                  const Icon(
                    Icons.keyboard_arrow_down_rounded,
                    size: 18,
                    color: Color(0xFF6B7280),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 10),
          // Title row
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Discover Gyms',
                    style: GoogleFonts.poppins(
                      fontSize: 22,
                      fontWeight: FontWeight.w800,
                      color: const Color(0xFF111827),
                    ),
                  ),
                  if (_visibleGyms.isNotEmpty)
                    Text(
                      '${_visibleGyms.length} gym${_visibleGyms.length == 1 ? '' : 's'} registered',
                      style: GoogleFonts.poppins(
                        fontSize: 12,
                        color: const Color(0xFF6B7280),
                      ),
                    ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _searchController,
            onChanged: _setSearchQuery,
            textInputAction: TextInputAction.search,
            decoration: InputDecoration(
              hintText: 'Search gyms, locations, or descriptions',
              hintStyle: GoogleFonts.poppins(
                fontSize: 13,
                color: const Color(0xFF9CA3AF),
              ),
              prefixIcon: const Icon(
                Icons.search_rounded,
                size: 20,
                color: Color(0xFF6B7280),
              ),
              suffixIcon: _searchQuery.isEmpty
                  ? null
                  : IconButton(
                      onPressed: _clearSearch,
                      icon: const Icon(Icons.close_rounded, size: 18),
                    ),
              filled: true,
              fillColor: const Color(0xFFF3F4F6),
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 14,
                vertical: 12,
              ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: BorderSide.none,
              ),
            ),
            style: GoogleFonts.poppins(
              fontSize: 13,
              color: const Color(0xFF111827),
            ),
          ),
        ],
      ),
    );
  }

  // ── Main body ─────────────────────────────────────────────────────────────

  Widget _buildBody() {
    return RefreshIndicator(
      onRefresh: () => _userLocation == null
          ? _resolveLocationForMap(refreshGyms: true)
          : _load(),
      child: CustomScrollView(
        controller: _scrollController,
        slivers: [
          // MAP
          SliverToBoxAdapter(child: _buildMap()),
          // MEMBERSHIP BANNER
          if (_activeMembership != null)
            SliverToBoxAdapter(child: _buildMembershipBanner()),
          // HORIZONTAL QUICK CARDS
          if (_visibleGyms.isNotEmpty) ...[
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 20, 16, 0),
                child: Wrap(
                  spacing: 8,
                  runSpacing: 6,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    Text(
                      'All Gyms',
                      style: GoogleFonts.poppins(
                        fontSize: 17,
                        fontWeight: FontWeight.w700,
                        color: const Color(0xFF111827),
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    TextButton(
                      onPressed: _scrollToGymList,
                      style: TextButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                        minimumSize: Size.zero,
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                      child: Text(
                        'View All',
                        style: GoogleFonts.poppins(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: const Color(0xFF4F46E5),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            SliverToBoxAdapter(child: _buildHorizontalCards()),
          ] else if (_searchQuery.isNotEmpty) ...[
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 20, 16, 0),
                child: _SearchEmptyState(
                  query: _searchController.text.trim(),
                  onClear: _clearSearch,
                ),
              ),
            ),
          ] else ...[
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 20, 16, 0),
                child: _NearbyEmptyState(
                  hasLocation: _userLocation != null,
                  radiusKm: _discoverRadiusKm,
                  onRetry: () => _resolveLocationForMap(refreshGyms: true),
                ),
              ),
            ),
          ],
          // FULL VERTICAL LIST
          if (_visibleGyms.isNotEmpty)
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(16, 20, 16, 32),
              sliver: SliverList(
                delegate: SliverChildBuilderDelegate(
                  (ctx, i) => _GymListCard(
                    gym: _visibleGyms[i],
                    distanceKm: _distanceFromUserToGym(_visibleGyms[i]),
                    isJoined: _activeMembership?.gymId == _visibleGyms[i].id,
                    hasUserLocation: _userLocation != null,
                    onTap: () => _openDetail(_visibleGyms[i]),
                  ),
                  childCount: _visibleGyms.length,
                ),
              ),
            ),
        ],
      ),
    );
  }

  // ── Map ──────────────────────────────────────────────────────────────────

  Widget _buildMap() {
    return SizedBox(
      height: 288,
      child: Stack(
        children: [
          FlutterMap(
            mapController: _mapController,
            options: MapOptions(
              initialCenter: _center,
              initialZoom: 13,
              minZoom: 5,
              maxZoom: 18,
              onMapReady: _onMapReady,
              interactionOptions: const InteractionOptions(
                flags: InteractiveFlag.all,
              ),
            ),
            children: [
              TileLayer(
                urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                userAgentPackageName: 'com.flexicurl.app',
                tileProvider: CancellableNetworkTileProvider(),
              ),
              if (_userLocation != null)
                CircleLayer(
                  circles: [
                    CircleMarker(
                      point: _userLocation!,
                      radius: _discoverRadiusKm * 1000,
                      useRadiusInMeter: true,
                      color: const Color(0xFF4F46E5).withAlpha(12),
                      borderColor: const Color(0xFF4F46E5).withAlpha(70),
                      borderStrokeWidth: 1.2,
                    ),
                  ],
                ),
              if (_buildRoutePolylines().isNotEmpty)
                PolylineLayer(polylines: _buildRoutePolylines()),
              Positioned.fill(
                child: IgnorePointer(
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          const Color(0xFFF8FAFC).withAlpha(20),
                          const Color(0xFF4F46E5).withAlpha(18),
                          const Color(0xFF0F172A).withAlpha(16),
                        ],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                    ),
                  ),
                ),
              ),
              // Gym markers
              MarkerLayer(
                markers: [
                  // Gym markers
                  ..._visibleGyms.asMap().entries.map((e) {
                    final i = e.key;
                    final gym = e.value;
                    return Marker(
                      point: LatLng(gym.latitude, gym.longitude),
                      width: 132,
                      height: 76,
                      alignment: Alignment.bottomCenter,
                      child: GestureDetector(
                        onTap: () {
                          setState(() => _selectedGymIndex = i);
                          if (_cardPageController.hasClients) {
                            _cardPageController.animateToPage(
                              i,
                              duration: const Duration(milliseconds: 300),
                              curve: Curves.easeInOut,
                            );
                          }
                          _moveMapSafely(
                            LatLng(gym.latitude, gym.longitude),
                            15,
                          );
                        },
                        child: _GymMapMarker(
                          gym: gym,
                          distanceKm: _distanceFromUserToGym(gym),
                          isSelected: _selectedGymIndex == i,
                          hasUserLocation: _userLocation != null,
                        ),
                      ),
                    );
                  }),
                  // User location marker is last so it stays visible above gym tags.
                  if (_userLocation != null)
                    Marker(
                      point: _userLocation!,
                      width: 98,
                      height: 92,
                      alignment: Alignment.center,
                      child: const _UserLocationPin(),
                    ),
                ],
              ),
            ],
          ),
          Positioned(
            left: 12,
            top: 12,
            child: _MapLegendChip(
              title: 'Rapid map',
              subtitle:
                  '${_visibleGyms.length} live tag${_visibleGyms.length == 1 ? '' : 's'}',
            ),
          ),
          if (_selectedGym != null)
            Positioned(
              left: 12,
              bottom: 12,
              right: 12,
              child: _SelectedGymInfoCard(
                name: _selectedGym!.name,
                type: _gymTypeLabel(_selectedGym!),
                address: _selectedGym!.location,
                distance: _selectedGymDistanceText(),
              ),
            ),
          if (_browserLocationOverlapsGym)
            const Positioned(
              right: 12,
              top: 12,
              child: _LocationOverlapWarning(),
            ),
          Positioned(
            right: 12,
            top: 12,
            child: _MapModeBadge(
              icon: Icons.alt_route_rounded,
              label: 'Location tags',
              accent: const Color(0xFF111827),
            ),
          ),
          // Fit-results FAB
          Positioned(
            right: 12,
            bottom: 60,
            child: Tooltip(
              message: 'Fit gyms on map',
              child: GestureDetector(
                onTap: _fitMapToCurrentResults,
                child: Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withAlpha(30),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: const Icon(
                    Icons.center_focus_strong_rounded,
                    size: 20,
                    color: Color(0xFF111827),
                  ),
                ),
              ),
            ),
          ),
          // Locate-me FAB
          Positioned(
            right: 12,
            bottom: 12,
            child: GestureDetector(
              onTap: () async {
                // _resolveLocationForMap() already calls _load() after GPS resolves.
                await _resolveLocationForMap();
              },
              child: Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withAlpha(30),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: _locating
                    ? const Padding(
                        padding: EdgeInsets.all(10),
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(
                        Icons.my_location_rounded,
                        size: 20,
                        color: Color(0xFF4F46E5),
                      ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Membership banner ─────────────────────────────────────────────────────

  Widget _buildMembershipBanner() {
    final m = _activeMembership!;
    final daysLeft = m.endDate?.difference(DateTime.now()).inDays;
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 16, 16, 0),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF1A1A2E), Color(0xFF4F46E5)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
      ),
      padding: const EdgeInsets.all(18),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white.withAlpha(30),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    'Active Membership',
                    style: GoogleFonts.poppins(
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                      color: const Color(0xFF86EFAC),
                    ),
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  m.gymName,
                  style: GoogleFonts.poppins(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ),
                if (daysLeft != null)
                  Text(
                    'Expires in $daysLeft day${daysLeft == 1 ? '' : 's'}',
                    style: GoogleFonts.poppins(
                      fontSize: 12,
                      color: Colors.white.withAlpha(180),
                    ),
                  ),
              ],
            ),
          ),
          if (m.status.toUpperCase() == 'ACTIVE')
            ElevatedButton.icon(
              onPressed: () => launchCheckInFlow(
                context: context,
                gymApi: widget.gymApi,
                membership: m,
                onFlowComplete: _load,
              ),
              icon: const Icon(Icons.qr_code_scanner, size: 16),
              label: const Text('Scan QR'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.white,
                foregroundColor: const Color(0xFF1A1A2E),
                elevation: 0,
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 10,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                textStyle: GoogleFonts.poppins(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
        ],
      ),
    );
  }

  // ── Horizontal card strip ─────────────────────────────────────────────────

  Widget _buildHorizontalCards() {
    return SizedBox(
      height: 200,
      child: PageView.builder(
        controller: _cardPageController,
        itemCount: _visibleGyms.length,
        onPageChanged: (i) {
          setState(() => _selectedGymIndex = i);
          _moveMapSafely(
            LatLng(_visibleGyms[i].latitude, _visibleGyms[i].longitude),
            14,
          );
        },
        itemBuilder: (ctx, i) => _GymHorizontalCard(
          gym: _visibleGyms[i],
          distanceKm: _distanceFromUserToGym(_visibleGyms[i]),
          colorIndex: i,
          isJoined: _activeMembership?.gymId == _visibleGyms[i].id,
          hasUserLocation: _userLocation != null,
          onTap: () => _openDetail(_visibleGyms[i]),
        ),
      ),
    );
  }

  // ── Error ─────────────────────────────────────────────────────────────────

  Widget _buildError() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.wifi_off_rounded,
              size: 48,
              color: Color(0xFFEF4444),
            ),
            const SizedBox(height: 12),
            Text(
              'Could not load gyms',
              style: GoogleFonts.poppins(
                fontSize: 16,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              _error!,
              textAlign: TextAlign.center,
              style: GoogleFonts.poppins(
                fontSize: 12,
                color: const Color(0xFF6B7280),
              ),
            ),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: () => _resolveLocationForMap(refreshGyms: true),
              icon: const Icon(Icons.refresh),
              label: const Text('Use current location'),
            ),
          ],
        ),
      ),
    );
  }

  // ── Navigation ────────────────────────────────────────────────────────────

  void _openDetail(GymDiscover gym) {
    final isJoined = _activeMembership?.gymId == gym.id;
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => _GymPreviewSheet(
        gym: gym,
        distanceKm: _distanceFromUserToGym(gym),
        isJoined: isJoined,
        hasUserLocation: _userLocation != null,
        onViewDetails: () {
          Navigator.of(context).pop(); // close sheet
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => GymDetailPage(
                gym: gym,
                distanceKmOverride: _distanceFromUserToGym(gym),
                gymApi: widget.gymApi,
                isJoined: isJoined,
                onChanged: _load,
                onSubscriptionRequested: () {
                  if (!mounted) return;
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                        'Cash request sent to ${gym.name}. The owner will approve it.',
                      ),
                    ),
                  );
                },
              ),
            ),
          );
        },
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
//  User location blue dot
// ══════════════════════════════════════════════════════════════════════════════

class _MapLegendChip extends StatelessWidget {
  const _MapLegendChip({required this.title, required this.subtitle});

  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(maxWidth: 220),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white.withAlpha(235),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE5E7EB)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(12),
            blurRadius: 14,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 10,
            height: 10,
            decoration: const BoxDecoration(
              color: Color(0xFF4F46E5),
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 10),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: GoogleFonts.poppins(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: const Color(0xFF111827),
                ),
              ),
              Text(
                subtitle,
                style: GoogleFonts.poppins(
                  fontSize: 10,
                  color: const Color(0xFF6B7280),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _MapModeBadge extends StatelessWidget {
  const _MapModeBadge({
    required this.icon,
    required this.label,
    required this.accent,
  });

  final IconData icon;
  final String label;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white.withAlpha(238),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: const Color(0xFFE5E7EB)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(12),
            blurRadius: 14,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: accent),
          const SizedBox(width: 8),
          Text(
            label,
            style: GoogleFonts.poppins(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: const Color(0xFF111827),
            ),
          ),
        ],
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
//  Gym map marker (price bubble)
// ══════════════════════════════════════════════════════════════════════════════

class _NearbyEmptyState extends StatelessWidget {
  const _NearbyEmptyState({
    required this.hasLocation,
    required this.radiusKm,
    required this.onRetry,
  });

  final bool hasLocation;
  final double radiusKm;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            hasLocation ? 'No gyms nearby' : 'Location required',
            style: GoogleFonts.poppins(
              fontSize: 15,
              fontWeight: FontWeight.w700,
              color: const Color(0xFF111827),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            hasLocation
                ? 'No approved gyms were found within ${radiusKm.toStringAsFixed(0)} km of your current location.'
                : 'Allow location access to load gyms near your current position. Fallback city gyms are disabled.',
            style: GoogleFonts.poppins(
              fontSize: 12,
              color: const Color(0xFF6B7280),
              height: 1.35,
            ),
          ),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: onRetry,
            icon: const Icon(Icons.my_location_rounded, size: 18),
            label: const Text('Retry current location'),
          ),
        ],
      ),
    );
  }
}

class _SearchEmptyState extends StatelessWidget {
  const _SearchEmptyState({required this.query, required this.onClear});

  final String query;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'No gyms found',
            style: GoogleFonts.poppins(
              fontSize: 15,
              fontWeight: FontWeight.w700,
              color: const Color(0xFF111827),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'We could not find any gyms for "$query". Try a different name, location, or description keyword.',
            style: GoogleFonts.poppins(
              fontSize: 12,
              color: const Color(0xFF6B7280),
              height: 1.35,
            ),
          ),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: onClear,
            icon: const Icon(Icons.clear_rounded, size: 18),
            label: const Text('Clear Search'),
          ),
        ],
      ),
    );
  }
}

class _SelectedGymInfoCard extends StatelessWidget {
  const _SelectedGymInfoCard({
    required this.name,
    required this.type,
    required this.address,
    required this.distance,
  });

  final String name;
  final String type;
  final String address;
  final String distance;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white.withAlpha(240),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE5E7EB)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(12),
            blurRadius: 14,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 10,
                height: 10,
                decoration: const BoxDecoration(
                  color: Color(0xFF22C55E),
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.poppins(
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                    color: const Color(0xFF111827),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Wrap(
            spacing: 8,
            runSpacing: 4,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              _MiniInfoPill(icon: Icons.apartment_rounded, label: type),
              _MiniInfoPill(icon: Icons.near_me_outlined, label: distance),
            ],
          ),
          const SizedBox(height: 6),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(
                Icons.place_outlined,
                size: 14,
                color: Color(0xFF6B7280),
              ),
              const SizedBox(width: 5),
              Expanded(
                child: Text(
                  address.isEmpty ? 'Address unavailable' : address,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.poppins(
                    fontSize: 10.5,
                    height: 1.25,
                    color: const Color(0xFF4B5563),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _MiniInfoPill extends StatelessWidget {
  const _MiniInfoPill({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: const Color(0xFFF3F4F6),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: const Color(0xFF4F46E5)),
          const SizedBox(width: 4),
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: GoogleFonts.poppins(
              fontSize: 10,
              fontWeight: FontWeight.w700,
              color: const Color(0xFF374151),
            ),
          ),
        ],
      ),
    );
  }
}

class _LocationOverlapWarning extends StatelessWidget {
  const _LocationOverlapWarning();

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(maxWidth: 190),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFFFFFBEB).withAlpha(245),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFF59E0B).withAlpha(160)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(12),
            blurRadius: 14,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(
            Icons.warning_amber_rounded,
            size: 16,
            color: Color(0xFFD97706),
          ),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              'Browser location matches a gym',
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: GoogleFonts.poppins(
                fontSize: 10,
                fontWeight: FontWeight.w700,
                color: const Color(0xFF92400E),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _GymMapMarker extends StatefulWidget {
  const _GymMapMarker({
    required this.gym,
    required this.distanceKm,
    required this.isSelected,
    required this.hasUserLocation,
  });

  final GymDiscover gym;
  final double? distanceKm;
  final bool isSelected;
  final bool hasUserLocation;

  @override
  State<_GymMapMarker> createState() => _GymMapMarkerState();
}

class _GymMapMarkerState extends State<_GymMapMarker>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulseController = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1400),
  );

  @override
  void initState() {
    super.initState();
    if (widget.isSelected) {
      _pulseController.repeat(reverse: true);
    }
  }

  @override
  void didUpdateWidget(covariant _GymMapMarker oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isSelected && !_pulseController.isAnimating) {
      _pulseController.repeat(reverse: true);
    } else if (!widget.isSelected && _pulseController.isAnimating) {
      _pulseController.stop();
      _pulseController.value = 0;
    }
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final distanceLabel = _distanceLabel(
      widget.distanceKm,
      hasUserLocation: widget.hasUserLocation,
    );
    final label = widget.isSelected ? widget.gym.name : widget.gym.name;

    return AnimatedScale(
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOutBack,
      scale: widget.isSelected ? 1.08 : 1.0,
      child: SizedBox(
        width: 132,
        height: 76,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            AnimatedBuilder(
              animation: _pulseController,
              builder: (context, child) {
                final pulse = widget.isSelected ? _pulseController.value : 0.0;
                return Stack(
                  alignment: Alignment.center,
                  children: [
                    if (widget.isSelected)
                      Container(
                        width: 42 + (pulse * 18),
                        height: 42 + (pulse * 18),
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: const Color(
                            0xFF4F46E5,
                          ).withAlpha((50 * (1 - pulse)).round()),
                        ),
                      ),
                    child!,
                  ],
                );
              },
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    constraints: const BoxConstraints(maxWidth: 132),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 9,
                      vertical: 7,
                    ),
                    decoration: BoxDecoration(
                      color: widget.isSelected
                          ? const Color(0xFF4F46E5)
                          : Colors.white.withAlpha(245),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: widget.isSelected
                            ? const Color(0xFF4F46E5)
                            : const Color(0xFFD1D5DB),
                        width: widget.isSelected ? 1.5 : 1,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: widget.isSelected
                              ? const Color(0xFF4F46E5).withAlpha(70)
                              : Colors.black.withAlpha(22),
                          blurRadius: widget.isSelected ? 14 : 9,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(
                              Icons.location_on_rounded,
                              size: 15,
                              color: widget.isSelected
                                  ? Colors.white
                                  : const Color(0xFF4F46E5),
                            ),
                            const SizedBox(width: 4),
                            Expanded(
                              child: Text(
                                label,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: GoogleFonts.poppins(
                                  fontSize: 10.5,
                                  fontWeight: FontWeight.w800,
                                  color: widget.isSelected
                                      ? Colors.white
                                      : const Color(0xFF111827),
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 2),
                        Text(
                          distanceLabel,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.poppins(
                            fontSize: 9,
                            fontWeight: FontWeight.w600,
                            color: widget.isSelected
                                ? Colors.white.withAlpha(230)
                                : const Color(0xFF6B7280),
                          ),
                        ),
                      ],
                    ),
                  ),
                  CustomPaint(
                    size: const Size(14, 7),
                    painter: _MarkerTailPainter(
                      color: widget.isSelected
                          ? const Color(0xFF4F46E5)
                          : Colors.white,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

String _distanceLabel(double? km, {required bool hasUserLocation}) {
  if (!hasUserLocation) return 'Enable location';
  if (km == null) return 'Distance unavailable';
  if (km < 1) return '${(km * 1000).round()} m away';
  return '${km.toStringAsFixed(km < 10 ? 1 : 0)} km away';
}

String _selectedGymDistanceLabel(double? km, bool hasUserLocation) {
  if (!hasUserLocation) return 'Turn on location to show distance';
  if (km == null) return 'Distance unavailable';
  if (km < 1) return 'About ${(km * 1000).round()} m away';
  return 'About ${km.toStringAsFixed(km < 10 ? 1 : 0)} km away';
}

class _UserLocationPin extends StatefulWidget {
  const _UserLocationPin();

  @override
  State<_UserLocationPin> createState() => _UserLocationPinState();
}

class _UserLocationPinState extends State<_UserLocationPin>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1600),
  )..repeat();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        final t = _controller.value;
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: const Color(
                  0xFF4F46E5,
                ).withAlpha((18 + (22 * (1 - t))).round()),
                border: Border.all(color: const Color(0xFF4F46E5), width: 2),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF4F46E5).withAlpha(40),
                    blurRadius: 14,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Center(
                child: Transform.scale(
                  scale: 1 + (t * 0.08),
                  child: const Icon(
                    Icons.my_location_rounded,
                    size: 18,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 4),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: Colors.white.withAlpha(235),
                borderRadius: BorderRadius.circular(999),
                border: Border.all(color: const Color(0xFFE5E7EB)),
              ),
              child: Text(
                'Your location',
                style: GoogleFonts.poppins(
                  fontSize: 9,
                  fontWeight: FontWeight.w700,
                  color: const Color(0xFF4F46E5),
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

class _MarkerTailPainter extends CustomPainter {
  _MarkerTailPainter({required this.color});
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = color;
    final path = ui.Path()
      ..moveTo(0, 0)
      ..lineTo(size.width / 2, size.height)
      ..lineTo(size.width, 0)
      ..close();
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(_MarkerTailPainter old) => old.color != color;
}

// ══════════════════════════════════════════════════════════════════════════════
//  Horizontal gym card (PageView strip)
// ══════════════════════════════════════════════════════════════════════════════

// Distinct gradient palettes for gym cards
const List<List<Color>> _gymGradients = [
  [Color(0xFF4F46E5), Color(0xFF7C3AED)],
  [Color(0xFF059669), Color(0xFF0891B2)],
  [Color(0xFFDC2626), Color(0xFFDB2777)],
  [Color(0xFFD97706), Color(0xFFEA580C)],
  [Color(0xFF0369A1), Color(0xFF0284C7)],
  [Color(0xFF7C3AED), Color(0xFFDB2777)],
];

class _GymHorizontalCard extends StatelessWidget {
  const _GymHorizontalCard({
    required this.gym,
    required this.distanceKm,
    required this.colorIndex,
    required this.isJoined,
    required this.hasUserLocation,
    required this.onTap,
  });
  final GymDiscover gym;
  final double? distanceKm;
  final int colorIndex;
  final bool isJoined;
  final bool hasUserLocation;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final grad = _gymGradients[colorIndex % _gymGradients.length];
    final priceLabel = gym.minPrice != null
        ? '\$${gym.minPrice!.toStringAsFixed(0)}/mo'
        : null;
    final distanceLabel = _distanceLabel(
      distanceKm,
      hasUserLocation: hasUserLocation,
    );

    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(left: 8, right: 4, top: 12, bottom: 8),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: grad[0].withAlpha(60),
              blurRadius: 16,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(20),
          child: Stack(
            children: [
              // Branded fallback art when a gym has no uploaded photo.
              Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: grad,
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                ),
              ),
              // Gym icon watermark
              Positioned(
                right: -20,
                top: -20,
                child: Icon(
                  Icons.fitness_center_rounded,
                  size: 100,
                  color: Colors.white.withAlpha(20),
                ),
              ),
              // Content
              Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Price badge
                    if (priceLabel != null)
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.black.withAlpha(50),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          priceLabel,
                          style: GoogleFonts.poppins(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    const Spacer(),
                    // Status row
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 3,
                          ),
                          decoration: BoxDecoration(
                            color: const Color(0xFF22C55E),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            'Open',
                            style: GoogleFonts.poppins(
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                              color: Colors.white,
                            ),
                          ),
                        ),
                        if (isJoined) ...[
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 3,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.white.withAlpha(30),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              'Member',
                              style: GoogleFonts.poppins(
                                fontSize: 10,
                                fontWeight: FontWeight.w700,
                                color: Colors.white,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      gym.name,
                      style: GoogleFonts.poppins(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Wrap(
                      spacing: 6,
                      runSpacing: 4,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        const Icon(
                          Icons.star_rounded,
                          size: 13,
                          color: Color(0xFFFBBF24),
                        ),
                        Text(
                          '4.${(8 - colorIndex % 3)}',
                          style: GoogleFonts.poppins(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: Colors.white,
                          ),
                        ),
                        const Icon(
                          Icons.location_on_outlined,
                          size: 12,
                          color: Colors.white70,
                        ),
                        Text(
                          distanceLabel,
                          style: GoogleFonts.poppins(
                            fontSize: 11,
                            color: Colors.white70,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
//  Full gym list card (vertical list)
// ══════════════════════════════════════════════════════════════════════════════

class _GymListCard extends StatelessWidget {
  const _GymListCard({
    required this.gym,
    required this.distanceKm,
    required this.isJoined,
    required this.hasUserLocation,
    required this.onTap,
  });
  final GymDiscover gym;
  final double? distanceKm;
  final bool isJoined;
  final bool hasUserLocation;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withAlpha(12),
              blurRadius: 16,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              // Gym icon block
              Container(
                width: 60,
                height: 60,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      const Color(0xFF4F46E5).withAlpha(200),
                      const Color(0xFF7C3AED).withAlpha(200),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Icon(
                  Icons.fitness_center_rounded,
                  color: Colors.white,
                  size: 28,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      gym.name,
                      style: GoogleFonts.poppins(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: const Color(0xFF111827),
                      ),
                    ),
                    const SizedBox(height: 3),
                    Wrap(
                      spacing: 6,
                      runSpacing: 4,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        if (gym.planCount > 0) ...[
                          const Icon(
                            Icons.card_membership_rounded,
                            size: 13,
                            color: Color(0xFF16A34A),
                          ),
                          Text(
                            '${gym.planCount} plan${gym.planCount == 1 ? '' : 's'}',
                            style: GoogleFonts.poppins(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: const Color(0xFF374151),
                            ),
                          ),
                        ] else if (gym.minPrice != null) ...[
                          const Icon(
                            Icons.payments_outlined,
                            size: 13,
                            color: Color(0xFF16A34A),
                          ),
                          Text(
                            'From \$${gym.minPrice!.toStringAsFixed(0)}',
                            style: GoogleFonts.poppins(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: const Color(0xFF374151),
                            ),
                          ),
                        ],
                        if (gym.facilities.isNotEmpty) ...[
                          const Icon(
                            Icons.fitness_center_rounded,
                            size: 12,
                            color: Color(0xFF6B7280),
                          ),
                          Text(
                            '${gym.facilities.length} facilities',
                            style: GoogleFonts.poppins(
                              fontSize: 12,
                              color: const Color(0xFF6B7280),
                            ),
                          ),
                        ],
                        if (hasUserLocation) ...[
                          const Icon(
                            Icons.near_me_outlined,
                            size: 12,
                            color: Color(0xFF9CA3AF),
                          ),
                          Text(
                            _distanceLabel(distanceKm, hasUserLocation: true),
                            style: GoogleFonts.poppins(
                              fontSize: 12,
                              color: const Color(0xFF6B7280),
                            ),
                          ),
                        ] else ...[
                          const Icon(
                            Icons.location_on_outlined,
                            size: 12,
                            color: Color(0xFF9CA3AF),
                          ),
                          Text(
                            'Enable location for distance',
                            style: GoogleFonts.poppins(
                              fontSize: 12,
                              color: const Color(0xFF6B7280),
                            ),
                          ),
                        ],
                        if (gym.checkInEnabled ||
                            gym.trialAvailable ||
                            gym.membershipRequired)
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: const Color(0xFFDCFCE7),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              gym.checkInEnabled
                                  ? 'QR check-in'
                                  : gym.trialAvailable
                                  ? 'Trial'
                                  : 'Members',
                              style: GoogleFonts.poppins(
                                fontSize: 10,
                                fontWeight: FontWeight.w600,
                                color: const Color(0xFF16A34A),
                              ),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 3),
                    Text(
                      gym.location,
                      style: GoogleFonts.poppins(
                        fontSize: 11,
                        color: const Color(0xFF9CA3AF),
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  if (gym.minPrice != null)
                    Text(
                      '\$${gym.minPrice!.toStringAsFixed(0)}',
                      style: GoogleFonts.poppins(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        color: const Color(0xFF4F46E5),
                      ),
                    ),
                  if (gym.minPrice != null)
                    Text(
                      '/mo',
                      style: GoogleFonts.poppins(
                        fontSize: 10,
                        color: const Color(0xFF9CA3AF),
                      ),
                    ),
                  const SizedBox(height: 4),
                  if (isJoined)
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFFEDE9FE),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        'Member',
                        style: GoogleFonts.poppins(
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          color: const Color(0xFF4F46E5),
                        ),
                      ),
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
//  Gym Preview Bottom Sheet (tap → full GymDetailPage)
// ══════════════════════════════════════════════════════════════════════════════

class _GymPreviewSheet extends StatelessWidget {
  const _GymPreviewSheet({
    required this.gym,
    required this.distanceKm,
    required this.isJoined,
    required this.hasUserLocation,
    required this.onViewDetails,
  });
  final GymDiscover gym;
  final double? distanceKm;
  final bool isJoined;
  final bool hasUserLocation;
  final VoidCallback onViewDetails;

  @override
  Widget build(BuildContext context) {
    final priceLabel = gym.minPrice != null
        ? '\$${gym.minPrice!.toStringAsFixed(0)}/mo'
        : null;

    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Handle
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: const Color(0xFFE5E7EB),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 16),
          // Branded fallback art when a gym has no uploaded photo.
          Container(
            height: 140,
            width: double.infinity,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(18),
              gradient: const LinearGradient(
                colors: [Color(0xFF4F46E5), Color(0xFF7C3AED)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
            child: Stack(
              children: [
                Center(
                  child: Icon(
                    Icons.fitness_center_rounded,
                    size: 60,
                    color: Colors.white.withAlpha(40),
                  ),
                ),
                if (priceLabel != null)
                  Positioned(
                    bottom: 10,
                    left: 10,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 5,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.black.withAlpha(100),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Text(
                        'From $priceLabel',
                        style: GoogleFonts.poppins(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
                if (isJoined)
                  Positioned(
                    top: 10,
                    right: 10,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFF22C55E),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        'Member',
                        style: GoogleFonts.poppins(
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          // Name + live gym metadata
          Align(
            alignment: Alignment.centerLeft,
            child: Text(
              gym.name,
              style: GoogleFonts.poppins(
                fontSize: 20,
                fontWeight: FontWeight.w800,
                color: const Color(0xFF111827),
              ),
            ),
          ),
          const SizedBox(height: 6),
          Wrap(
            spacing: 12,
            runSpacing: 4,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              if (gym.planCount > 0) ...[
                const Icon(
                  Icons.card_membership_rounded,
                  size: 15,
                  color: Color(0xFF16A34A),
                ),
                Text(
                  '${gym.planCount} plan${gym.planCount == 1 ? '' : 's'}',
                  style: GoogleFonts.poppins(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: const Color(0xFF374151),
                  ),
                ),
              ] else if (priceLabel != null) ...[
                const Icon(
                  Icons.payments_outlined,
                  size: 15,
                  color: Color(0xFF16A34A),
                ),
                Text(
                  'From $priceLabel',
                  style: GoogleFonts.poppins(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: const Color(0xFF374151),
                  ),
                ),
              ],
              const Icon(
                Icons.near_me_outlined,
                size: 13,
                color: Color(0xFF9CA3AF),
              ),
              Text(
                hasUserLocation
                    ? _distanceLabel(distanceKm, hasUserLocation: true)
                    : 'Enable location for distance',
                style: GoogleFonts.poppins(
                  fontSize: 12,
                  color: const Color(0xFF6B7280),
                ),
              ),
              if (gym.facilities.isNotEmpty) ...[
                const Icon(
                  Icons.fitness_center_rounded,
                  size: 13,
                  color: Color(0xFF9CA3AF),
                ),
                Text(
                  '${gym.facilities.length} facilities',
                  style: GoogleFonts.poppins(
                    fontSize: 12,
                    color: const Color(0xFF6B7280),
                  ),
                ),
              ],
              if (gym.checkInEnabled || gym.trialAvailable)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 7,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFFDCFCE7),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    gym.checkInEnabled ? 'QR check-in' : 'Trial available',
                    style: GoogleFonts.poppins(
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                      color: const Color(0xFF16A34A),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 6),
          Align(
            alignment: Alignment.centerLeft,
            child: Text(
              gym.location,
              style: GoogleFonts.poppins(
                fontSize: 12,
                color: const Color(0xFF9CA3AF),
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const SizedBox(height: 18),
          // View Details button
          SizedBox(
            width: double.infinity,
            height: 50,
            child: ElevatedButton(
              onPressed: onViewDetails,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF1A1A2E),
                foregroundColor: Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              child: Text(
                'View Details',
                style: GoogleFonts.poppins(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
          SizedBox(height: MediaQuery.of(context).padding.bottom + 16),
        ],
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
//  Formatters (local)
// ══════════════════════════════════════════════════════════════════════════════

// ignore: unused_element
String _fmtPrice(double p) =>
    NumberFormat.currency(symbol: '\$', decimalDigits: 0).format(p);
