import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';

import '../services/auth_service.dart';

const Color _kPrimary = Color(0xFF1E73C6);
const Color _kPrimaryDark = Color(0xFF154F91);
const Color _kSurface = Color(0xFFF5F8FC);

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  static const _fallbackCenter = LatLng(41.9028, 12.4964);

  final AuthService _authService = AuthService();
  final MapController _mapController = MapController();

  Position? _position;
  String? _locationError;
  bool _loadingLocation = true;
  bool _mapReady = false;
  LatLng? _pendingMapCenter;

  @override
  void initState() {
    super.initState();
    _loadLocation();
  }

  Future<void> _loadLocation() async {
    setState(() {
      _loadingLocation = true;
      _locationError = null;
    });

    try {
      final enabled = await Geolocator.isLocationServiceEnabled();
      if (!enabled) {
        throw const _LocationException(
          'I servizi di posizione sono disattivati sul dispositivo.',
        );
      }

      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }

      if (permission == LocationPermission.denied) {
        throw const _LocationException(
          'Permesso posizione negato. Serve l autorizzazione per mostrare la tua posizione.',
        );
      }

      if (permission == LocationPermission.deniedForever) {
        throw const _LocationException(
          'Permesso posizione negato in modo permanente. Apri le impostazioni per abilitarlo.',
        );
      }

      final current = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );

      if (!mounted) return;
      setState(() {
        _position = current;
        _loadingLocation = false;
      });

      _queueMapMove(_currentLatLng);
    } on _LocationException catch (e) {
      if (!mounted) return;
      setState(() {
        _locationError = e.message;
        _loadingLocation = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _locationError = 'Non riesco a leggere la posizione in questo momento.';
        _loadingLocation = false;
      });
    }
  }

  LatLng get _currentLatLng {
    final position = _position;
    if (position == null) {
      return _fallbackCenter;
    }
    return LatLng(position.latitude, position.longitude);
  }

  List<_NearbyBarView> get _nearbyBars {
    final center = _currentLatLng;
    final bars = _bars.map((bar) {
      final location = _offsetLatLng(
        center,
        bar.northMeters,
        bar.eastMeters,
      );
      final distanceMeters = Geolocator.distanceBetween(
        center.latitude,
        center.longitude,
        location.latitude,
        location.longitude,
      );
      return _NearbyBarView(
        bar: bar,
        location: location,
        distanceMeters: distanceMeters,
      );
    }).toList();

    bars.sort((a, b) => a.distanceMeters.compareTo(b.distanceMeters));
    return bars;
  }

  void _queueMapMove(LatLng center) {
    if (!mounted) return;
    if (!_mapReady) {
      _pendingMapCenter = center;
      return;
    }
    _mapController.move(center, 14.8);
  }

  @override
  Widget build(BuildContext context) {
    final user = _authService.currentUser;
    final displayName = user?.displayName?.trim();
    final firstName = displayName == null || displayName.isEmpty
        ? 'Benvenuto'
        : displayName.split(' ').first;

    final nearbyBars = _nearbyBars;

    return Scaffold(
      extendBodyBehindAppBar: true,
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFFEAF4FF), _kSurface],
          ),
        ),
        child: SafeArea(
          child: CustomScrollView(
            slivers: [
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
                  child: Row(
                    children: [
                      Container(
                        width: 48,
                        height: 48,
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [_kPrimary, _kPrimaryDark],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: const Icon(
                          Icons.water_drop_rounded,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '$firstName, trova un refill',
                              style: const TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.w800,
                                color: Color(0xFF16324F),
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Mappa reale, geolocalizzazione attiva e bar affiliati nelle vicinanze.',
                              style: TextStyle(
                                fontSize: 13,
                                color: Colors.blueGrey.shade600,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 12),
                      _LogoutButton(onPressed: () => _authService.signOut()),
                    ],
                  ),
                ),
              ),
              const SliverToBoxAdapter(child: SizedBox(height: 4)),
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
              child: _LiveMapCard(
                    loading: _loadingLocation,
                    locationError: _locationError,
                    currentCenter: _currentLatLng,
                    bars: nearbyBars,
                    mapController: _mapController,
                    onRefreshLocation: _loadLocation,
                    onMapReady: () {
                      if (!mounted) return;
                      setState(() {
                        _mapReady = true;
                      });
                      final pendingCenter = _pendingMapCenter;
                      if (pendingCenter != null) {
                        _pendingMapCenter = null;
                        _queueMapMove(pendingCenter);
                      }
                    },
                  ),
                ),
              ),
              const SliverToBoxAdapter(child: SizedBox(height: 16)),
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Row(
                    children: [
                      Expanded(
                        child: _StatCard(
                          icon: Icons.my_location_rounded,
                          label: 'Posizione',
                          value: _position == null ? 'Fallback' : 'Attiva',
                          caption: _position == null
                              ? 'In attesa permesso'
                              : 'GPS rilevato',
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _StatCard(
                          icon: Icons.local_cafe_rounded,
                          label: 'Bar vicini',
                          value: '${nearbyBars.length}',
                          caption: 'in elenco',
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SliverToBoxAdapter(child: SizedBox(height: 22)),
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Bar affiliati',
                        style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.w800,
                          color: Color(0xFF16324F),
                        ),
                      ),
                      Text(
                        'Ordinati per distanza',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: Colors.blueGrey.shade500,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SliverToBoxAdapter(child: SizedBox(height: 12)),
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
                sliver: SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (context, index) {
                      if (index.isOdd) {
                        return const SizedBox(height: 12);
                      }
                      final view = nearbyBars[index ~/ 2];
                      return _BarCard(view: view);
                    },
                    childCount: nearbyBars.isEmpty ? 0 : nearbyBars.length * 2 - 1,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _LiveMapCard extends StatelessWidget {
  const _LiveMapCard({
    required this.loading,
    required this.locationError,
    required this.currentCenter,
    required this.bars,
    required this.mapController,
    required this.onRefreshLocation,
    required this.onMapReady,
  });

  final bool loading;
  final String? locationError;
  final LatLng currentCenter;
  final List<_NearbyBarView> bars;
  final MapController mapController;
  final VoidCallback onRefreshLocation;
  final VoidCallback onMapReady;

  @override
  Widget build(BuildContext context) {
    final isPermanentPermissionError =
        locationError?.contains('permanente') ?? false;

    return Container(
      height: 420,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(30),
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF1E73C6).withValues(alpha: 0.10),
            blurRadius: 28,
            offset: const Offset(0, 16),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(30),
        child: Stack(
          children: [
            FlutterMap(
              mapController: mapController,
              options: MapOptions(
                initialCenter: currentCenter,
                initialZoom: 14.8,
                onMapReady: onMapReady,
                interactionOptions: const InteractionOptions(
                  flags: InteractiveFlag.all,
                ),
              ),
              children: [
                TileLayer(
                  urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                  userAgentPackageName: 'fairwater',
                ),
                MarkerLayer(
                  markers: [
                    Marker(
                      point: currentCenter,
                      width: 72,
                      height: 72,
                      child: const _CurrentLocationMarker(),
                    ),
                    ...bars.map(
                      (view) => Marker(
                        point: view.location,
                        width: 140,
                        height: 84,
                        child: _MapBarMarker(
                          title: view.bar.name,
                          subtitle: _formatDistance(view.distanceMeters),
                          highlighted: view.bar.featured,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
            Positioned(
              top: 18,
              left: 18,
              child: _LocationPill(
                icon: Icons.gps_fixed_rounded,
                label: loading
                    ? 'Geolocalizzazione in corso'
                    : locationError == null
                        ? 'Geolocalizzazione attiva'
                        : 'Geolocalizzazione limitata',
                  accent: locationError == null ? _kPrimaryDark : Colors.deepOrange,
              ),
            ),
            Positioned(
              top: 18,
              right: 18,
              child: _RoundActionButton(
                icon: Icons.my_location_rounded,
                onTap: onRefreshLocation,
              ),
            ),
            if (locationError != null)
              Positioned(
                left: 18,
                right: 18,
                bottom: 84,
                child: _MapMessageCard(
                  title: 'Permesso posizione non disponibile',
                  subtitle: locationError!,
                  actionLabel: isPermanentPermissionError
                      ? 'Impostazioni'
                      : 'Riprova',
                  onAction: isPermanentPermissionError
                      ? () => Geolocator.openAppSettings()
                      : onRefreshLocation,
                ),
              ),
            Positioned(
              left: 18,
              right: 18,
              bottom: 18,
              child: _MapFooterCard(
                title: loading ? 'Recupero posizione' : 'Posizione rilevata',
                subtitle: loading
                    ? 'Sto leggendo il GPS del dispositivo'
                    : 'Bar e refill ordinati dalla tua posizione attuale',
                trailing: locationError == null ? 'Aggiornata ora' : 'Fallback attivo',
              ),
            ),
            if (loading)
              Container(
                color: Colors.white.withValues(alpha: 0.16),
                child: const Center(child: CircularProgressIndicator()),
              ),
          ],
        ),
      ),
    );
  }
}

class _LocationPill extends StatelessWidget {
  const _LocationPill({
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
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.90),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 18, color: accent),
          const SizedBox(width: 8),
          Text(
            label,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: Color(0xFF16324F),
            ),
          ),
        ],
      ),
    );
  }
}

class _RoundActionButton extends StatelessWidget {
  const _RoundActionButton({required this.icon, required this.onTap});

  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white.withValues(alpha: 0.92),
      shape: const CircleBorder(),
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onTap,
        child: SizedBox(
          width: 48,
          height: 48,
          child: Icon(icon, color: _kPrimary),
        ),
      ),
    );
  }
}

class _MapMessageCard extends StatelessWidget {
  const _MapMessageCard({
    required this.title,
    required this.subtitle,
    required this.actionLabel,
    required this.onAction,
  });

  final String title;
  final String subtitle;
  final String actionLabel;
  final VoidCallback onAction;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.96),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: const Color(0xFFE5EEF8)),
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: const Color(0xFFFFF3E8),
              borderRadius: BorderRadius.circular(14),
            ),
            child: const Icon(Icons.location_off_rounded, color: Colors.deepOrange),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF16324F),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.blueGrey.shade600,
                  ),
                ),
              ],
            ),
          ),
          TextButton(
            onPressed: onAction,
            child: Text(actionLabel),
          ),
        ],
      ),
    );
  }
}

class _MapFooterCard extends StatelessWidget {
  const _MapFooterCard({
    required this.title,
    required this.subtitle,
    required this.trailing,
  });

  final String title;
  final String subtitle;
  final String trailing;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.94),
        borderRadius: BorderRadius.circular(22),
      ),
      child: Row(
        children: [
          Container(
            width: 46,
            height: 46,
            decoration: BoxDecoration(
              color: const Color(0xFFEAF4FF),
              borderRadius: BorderRadius.circular(16),
            ),
            child: const Icon(
              Icons.location_on_rounded,
              color: _kPrimary,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF16324F),
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  subtitle,
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.blueGrey.shade600,
                  ),
                ),
              ],
            ),
          ),
          Text(
            trailing,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: _kPrimaryDark,
            ),
          ),
        ],
      ),
    );
  }
}

class _CurrentLocationMarker extends StatelessWidget {
  const _CurrentLocationMarker();

  @override
  Widget build(BuildContext context) {
    return Stack(
      alignment: Alignment.center,
      children: [
        Container(
          width: 72,
          height: 72,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: const Color(0xFF1E73C6).withValues(alpha: 0.14),
          ),
        ),
        Container(
          width: 46,
          height: 46,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: Colors.white,
            border: Border.all(color: const Color(0xFF1E73C6), width: 6),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF1E73C6).withValues(alpha: 0.18),
                blurRadius: 18,
              ),
            ],
          ),
          child: const Icon(Icons.person_pin_circle_rounded, color: _kPrimary),
        ),
      ],
    );
  }
}

class _MapBarMarker extends StatelessWidget {
  const _MapBarMarker({
    required this.title,
    required this.subtitle,
    required this.highlighted,
  });

  final String title;
  final String subtitle;
  final bool highlighted;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(14),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.12),
                blurRadius: 14,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Column(
            children: [
              Text(
                title,
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  color: highlighted ? _kPrimary : Colors.blueGrey.shade700,
                ),
              ),
              const SizedBox(height: 1),
              Text(
                subtitle,
                style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF16324F),
                ),
              ),
            ],
          ),
        ),
        Container(
          width: 18,
          height: 18,
          decoration: BoxDecoration(
            color: highlighted ? _kPrimary : const Color(0xFF64A8E1),
            shape: BoxShape.circle,
            border: Border.all(color: Colors.white, width: 3),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF1E73C6).withValues(alpha: 0.22),
                blurRadius: 12,
                spreadRadius: 2,
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _StatCard extends StatelessWidget {
  const _StatCard({
    required this.icon,
    required this.label,
    required this.value,
    required this.caption,
  });

  final IconData icon;
  final String label;
  final String value;
  final String caption;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 18,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: const Color(0xFFEAF4FF),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(icon, color: _kPrimary),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.blueGrey.shade500,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  value,
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF16324F),
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  caption,
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.blueGrey.shade500,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _BarCard extends StatelessWidget {
  const _BarCard({required this.view});

  final _NearbyBarView view;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 54,
            height: 54,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [_kPrimary, _kPrimaryDark],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(18),
            ),
            child: const Icon(
              Icons.local_cafe_rounded,
              color: Colors.white,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        view.bar.name,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                          color: Color(0xFF16324F),
                        ),
                      ),
                    ),
                    _DistanceBadge(distance: view.distanceLabel),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  view.bar.address,
                  style: TextStyle(
                    fontSize: 13,
                    color: Colors.blueGrey.shade600,
                  ),
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    _InfoChip(
                      icon: Icons.water_drop_outlined,
                      label: view.bar.refillInfo,
                    ),
                    const SizedBox(width: 8),
                    _InfoChip(
                      icon: Icons.schedule_rounded,
                      label: view.bar.openInfo,
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _DistanceBadge extends StatelessWidget {
  const _DistanceBadge({required this.distance});

  final String distance;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: const Color(0xFFEAF4FF),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        distance,
        style: const TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w800,
          color: _kPrimary,
        ),
      ),
    );
  }
}

class _InfoChip extends StatelessWidget {
  const _InfoChip({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFFF3F8FD),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 15, color: _kPrimary),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: Colors.blueGrey.shade700,
            ),
          ),
        ],
      ),
    );
  }
}

class _LogoutButton extends StatelessWidget {
  const _LogoutButton({required this.onPressed});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onPressed,
        child: const SizedBox(
          width: 48,
          height: 48,
          child: Icon(Icons.logout_rounded, color: Color(0xFF16324F)),
        ),
      ),
    );
  }
}

class _BarSpot {
  const _BarSpot({
    required this.name,
    required this.address,
    required this.refillInfo,
    required this.openInfo,
    required this.northMeters,
    required this.eastMeters,
    required this.featured,
  });

  final String name;
  final String address;
  final String refillInfo;
  final String openInfo;
  final double northMeters;
  final double eastMeters;
  final bool featured;
}

class _NearbyBarView {
  const _NearbyBarView({
    required this.bar,
    required this.location,
    required this.distanceMeters,
  });

  final _BarSpot bar;
  final LatLng location;
  final double distanceMeters;

  String get distanceLabel => _formatDistance(distanceMeters);
}

class _LocationException implements Exception {
  const _LocationException(this.message);

  final String message;

  @override
  String toString() => message;
}

LatLng _offsetLatLng(LatLng origin, double northMeters, double eastMeters) {
  final lat = origin.latitude + (northMeters / 111320.0);
  final lon = origin.longitude +
      (eastMeters / (111320.0 * math.cos(origin.latitude * math.pi / 180.0)));
  return LatLng(lat, lon);
}

String _formatDistance(double meters) {
  if (meters < 1000) {
    return '${meters.round()} m';
  }
  return '${(meters / 1000).toStringAsFixed(1)} km';
}

const List<_BarSpot> _bars = [
  _BarSpot(
    name: 'Caffe Centrale',
    address: 'Via Roma 18, centro citta',
    refillInfo: 'Refill attivo',
    openInfo: 'Aperto fino alle 22:00',
    northMeters: 180,
    eastMeters: 60,
    featured: true,
  ),
  _BarSpot(
    name: 'Bar del Corso',
    address: 'Corso Vittorio 42, zona stazione',
    refillInfo: '2 punti refill',
    openInfo: 'Aperto fino alle 20:30',
    northMeters: -260,
    eastMeters: 310,
    featured: false,
  ),
  _BarSpot(
    name: 'Lounge Drink',
    address: 'Piazza Italia 7, quartiere sud',
    refillInfo: 'Refill premium',
    openInfo: 'Aperto fino alle 23:00',
    northMeters: 420,
    eastMeters: -140,
    featured: false,
  ),
  _BarSpot(
    name: 'Bistro Verde',
    address: 'Via del Porto 11, lungomare',
    refillInfo: 'Copertura completa',
    openInfo: 'Aperto fino alle 21:00',
    northMeters: -780,
    eastMeters: -220,
    featured: false,
  ),
];
