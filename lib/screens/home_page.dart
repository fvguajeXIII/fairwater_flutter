import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';
import 'package:url_launcher/url_launcher.dart';

import '../config/app_config.dart';
import '../services/address_search_service.dart';
import '../services/auth_service.dart';
import '../services/bar_service.dart';
import '../services/profile_service.dart';
import '../services/refill_notification_service.dart';
import '../services/sponsor_service.dart';
import '../theme/app_theme.dart';
import 'customer_qr_page.dart';
import 'profile_page.dart';
import 'refiller_home_page.dart';

const Color _kPrimary = AppColors.ocean;
const Color _kPrimaryDark = AppColors.deepOcean;
const Color _kSurface = AppColors.foam;
const double _kNearbyRadiusMeters = 5000;
const String _kGeoapifyTileUrl =
    'https://maps.geoapify.com/v1/tile/osm-bright/{z}/{x}/{y}.png?apiKey={apiKey}';
const String _kOpenStreetMapTileUrl =
    'https://tile.openstreetmap.org/{z}/{x}/{y}.png';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final AuthService _authService = AuthService();
  final BarService _barService = BarService();
  final ProfileService _profileService = ProfileService();
  final SponsorService _sponsorService = SponsorService();
  final MapController _mapController = MapController();
  final RefillNotificationService _refillNotificationService =
      RefillNotificationService.instance;
  late final Stream<List<BarSpot>> _barsStream;
  late final Stream<List<SponsorSpot>> _sponsorsStream;

  int _selectedIndex = 0;
  Position? _position;
  String? _locationError;
  bool _loadingLocation = true;
  bool _mapReady = false;
  LatLng? _pendingMapCenter;
  StreamSubscription<Position>? _positionSubscription;
  int? _lastObservedRefillCount;
  bool _customerInitialized = false;

  @override
  void initState() {
    super.initState();
    _barsStream = _barService.watchBars();
    _sponsorsStream = _sponsorService.watchSponsors();
  }

  @override
  void dispose() {
    _positionSubscription?.cancel();
    super.dispose();
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

      unawaited(_refillNotificationService.startBackgroundMonitoring());
      _startPositionMonitoring();

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

  void _startPositionMonitoring() {
    if (_positionSubscription != null) {
      return;
    }

    const settings = LocationSettings(
      accuracy: LocationAccuracy.high,
      distanceFilter: 25,
    );

    _positionSubscription =
        Geolocator.getPositionStream(locationSettings: settings).listen((
          position,
        ) async {
          if (!mounted) {
            return;
          }

          setState(() {
            _position = position;
            _locationError = null;
            _loadingLocation = false;
          });

          _queueMapMove(LatLng(position.latitude, position.longitude));
        });
  }

  LatLng get _currentLatLng {
    final position = _position;
    if (position == null) {
      return const LatLng(41.2879, 13.2490);
    }
    return LatLng(position.latitude, position.longitude);
  }

  void _queueMapMove(LatLng center) {
    if (!mounted) return;
    if (!_mapReady) {
      _pendingMapCenter = center;
      return;
    }
    _mapController.move(center, 14.8);
  }

  List<_NearbyBarView> _nearbyBars(List<BarSpot> bars) {
    final center = _currentLatLng;
    final nearbyBars =
        bars
            .map((bar) {
              final distanceMeters = Geolocator.distanceBetween(
                center.latitude,
                center.longitude,
                bar.location.latitude,
                bar.location.longitude,
              );
              return _NearbyBarView(
                bar: bar,
                location: bar.location,
                distanceMeters: distanceMeters,
              );
            })
            .where((bar) => bar.distanceMeters <= _kNearbyRadiusMeters)
            .toList()
          ..sort((a, b) => a.distanceMeters.compareTo(b.distanceMeters));

    return nearbyBars;
  }

  @override
  Widget build(BuildContext context) {
    final user = _authService.currentUser;
    if (user == null) return const SizedBox.shrink();

    return StreamBuilder<FairWaterUserProfile>(
      stream: _profileService.watchUserProfile(user.uid),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Scaffold(
            body: WaterBackdrop(
              child: Center(child: CircularProgressIndicator()),
            ),
          );
        }
        final profile = snapshot.data!;
        if (profile.isRefiller) return RefillerHomePage();

        if (!_customerInitialized) {
          _customerInitialized = true;
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (!mounted) return;
            _loadLocation();
          });
        }

        final previousCount = _lastObservedRefillCount;
        _lastObservedRefillCount = profile.refillCount;
        if (previousCount != null && profile.refillCount > previousCount) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) _showRefillThankYou();
          });
        }
        return _buildCustomerShell(profile);
      },
    );
  }

  Widget _buildCustomerShell(FairWaterUserProfile profile) {
    final pages = <Widget>[
      _buildHomeTab(),
      _buildRefillTab(),
      _buildSponsorTab(),
      ProfilePage(),
    ];

    return Scaffold(
      extendBody: true,
      body: IndexedStack(index: _selectedIndex, children: pages),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
      floatingActionButton: _QrScanButton(
        onPressed: () {
          Navigator.of(context).push(
            MaterialPageRoute(builder: (_) => CustomerQrPage(profile: profile)),
          );
        },
      ),
      bottomNavigationBar: _BottomNavBar(
        currentIndex: _selectedIndex,
        onSelected: (index) {
          setState(() {
            _selectedIndex = index;
          });
        },
      ),
    );
  }

  Widget _buildHomeTab() {
    return StreamBuilder<List<BarSpot>>(
      stream: _barsStream,
      builder: (context, snapshot) {
        final bars = snapshot.data ?? const <BarSpot>[];
        final nearbyBars = _nearbyBars(bars);

        return WaterBackdrop(
          child: SafeArea(
            bottom: false,
            child: CustomScrollView(
              slivers: [
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 14, 20, 0),
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
                const SliverToBoxAdapter(child: SizedBox(height: 18)),
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
                            color: AppColors.ink,
                          ),
                        ),
                        Text(
                          'Entro 5 km',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: AppColors.slate,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SliverToBoxAdapter(child: SizedBox(height: 12)),
                if (nearbyBars.isEmpty)
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(20, 0, 20, 120),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          const _EmptyNearbyBarsCard(),
                          const SizedBox(height: 14),
                          _CityRefillSearch(bars: bars, center: _currentLatLng),
                        ],
                      ),
                    ),
                  )
                else
                  SliverPadding(
                    padding: const EdgeInsets.fromLTRB(20, 0, 20, 120),
                    sliver: SliverList(
                      delegate: SliverChildBuilderDelegate(
                        (context, index) {
                          if (index.isOdd) {
                            return const SizedBox(height: 12);
                          }
                          final view = nearbyBars[index ~/ 2];
                          return _BarCard(view: view);
                        },
                        childCount: nearbyBars.isEmpty
                            ? 0
                            : nearbyBars.length * 2 - 1,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildRefillTab() {
    return StreamBuilder<List<BarSpot>>(
      stream: _barsStream,
      builder: (context, snapshot) {
        final bars = <BarSpot>[...?snapshot.data]
          ..sort((a, b) {
            if (a.featured != b.featured) {
              return a.featured ? -1 : 1;
            }
            return a.name.toLowerCase().compareTo(b.name.toLowerCase());
          });

        return WaterBackdrop(
          child: SafeArea(
            bottom: false,
            child: CustomScrollView(
              slivers: [
                if (bars.isEmpty)
                  const SliverToBoxAdapter(
                    child: Padding(
                      padding: EdgeInsets.fromLTRB(20, 14, 20, 120),
                      child: _EmptyRefillCard(),
                    ),
                  )
                else
                  SliverPadding(
                    padding: const EdgeInsets.fromLTRB(20, 14, 20, 120),
                    sliver: SliverList(
                      delegate: SliverChildBuilderDelegate((context, index) {
                        if (index.isOdd) {
                          return const SizedBox(height: 14);
                        }
                        final bar = bars[index ~/ 2];
                        return _RefillSpotCard(bar: bar);
                      }, childCount: bars.length * 2 - 1),
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildSponsorTab() {
    return StreamBuilder<List<SponsorSpot>>(
      stream: _sponsorsStream,
      builder: (context, snapshot) {
        final sponsors = <SponsorSpot>[...?snapshot.data]
          ..sort((a, b) {
            if (a.featured != b.featured) {
              return a.featured ? -1 : 1;
            }
            return a.name.toLowerCase().compareTo(b.name.toLowerCase());
          });

        return WaterBackdrop(
          child: SafeArea(
            bottom: false,
            child: CustomScrollView(
              slivers: [
                if (sponsors.isEmpty)
                  const SliverToBoxAdapter(
                    child: Padding(
                      padding: EdgeInsets.fromLTRB(20, 14, 20, 120),
                      child: _EmptySponsorsCard(),
                    ),
                  )
                else
                  SliverPadding(
                    padding: const EdgeInsets.fromLTRB(20, 14, 20, 120),
                    sliver: SliverList(
                      delegate: SliverChildBuilderDelegate((context, index) {
                        if (index.isOdd) {
                          return const SizedBox(height: 14);
                        }
                        final sponsor = sponsors[index ~/ 2];
                        return _SponsorCard(sponsor: sponsor);
                      }, childCount: sponsors.length * 2 - 1),
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _showRefillThankYou() {
    return showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        icon: const Icon(
          Icons.water_drop_rounded,
          color: AppColors.ocean,
          size: 48,
        ),
        title: const Text('Grazie per il tuo refill!'),
        content: const Text(
          'Le statistiche del tuo profilo sono state aggiornate. Un piccolo gesto, un grande impatto.',
          textAlign: TextAlign.center,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Continua'),
          ),
        ],
      ),
    );
  }
}

class _BottomNavBar extends StatelessWidget {
  const _BottomNavBar({required this.currentIndex, required this.onSelected});

  final int currentIndex;
  final ValueChanged<int> onSelected;

  @override
  Widget build(BuildContext context) {
    return BottomAppBar(
      height: 74,
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      color: Colors.white.withValues(alpha: 0.96),
      elevation: 10,
      shape: const CircularNotchedRectangle(),
      notchMargin: 10,
      child: Row(
        children: [
          Expanded(
            child: _NavItem(
              icon: Icons.home_rounded,
              label: 'Home',
              selected: currentIndex == 0,
              onTap: () => onSelected(0),
            ),
          ),
          Expanded(
            child: _NavItem(
              icon: Icons.local_drink_rounded,
              label: 'Refill',
              selected: currentIndex == 1,
              onTap: () => onSelected(1),
            ),
          ),
          const SizedBox(width: 54),
          Expanded(
            child: _NavItem(
              icon: Icons.campaign_rounded,
              label: 'Sponsor',
              selected: currentIndex == 2,
              onTap: () => onSelected(2),
            ),
          ),
          Expanded(
            child: _NavItem(
              icon: Icons.person_rounded,
              label: 'Profilo',
              selected: currentIndex == 3,
              onTap: () => onSelected(3),
            ),
          ),
        ],
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  const _NavItem({
    required this.icon,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = selected ? _kPrimaryDark : AppColors.iconMuted;
    final bg = selected ? AppColors.mist : Colors.transparent;

    return InkWell(
      borderRadius: BorderRadius.circular(20),
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 3, horizontal: 4),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          decoration: BoxDecoration(
            color: bg,
            borderRadius: BorderRadius.circular(18),
          ),
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, color: color, size: 19),
              const SizedBox(height: 4),
              Text(
                label,
                style: TextStyle(
                  fontSize: 9,
                  fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
                  color: color,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _QrScanButton extends StatelessWidget {
  const _QrScanButton({required this.onPressed});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 68,
      height: 68,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: AppDecorations.heroGradient,
        boxShadow: [
          BoxShadow(
            color: _kPrimary.withValues(alpha: 0.28),
            blurRadius: 28,
            offset: const Offset(0, 14),
          ),
        ],
      ),
      child: FloatingActionButton(
        elevation: 0,
        backgroundColor: Colors.transparent,
        foregroundColor: Colors.white,
        shape: const CircleBorder(),
        onPressed: onPressed,
        child: const Icon(Icons.qr_code_2_rounded, size: 30),
      ),
    );
  }
}

class _PlaceholderTab extends StatelessWidget {
  const _PlaceholderTab({required this.icon, required this.title});

  final IconData icon;
  final String title;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [AppColors.mist, _kSurface],
        ),
      ),
      child: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 84,
                  height: 84,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(28),
                    boxShadow: [
                      BoxShadow(
                        color: _kPrimary.withValues(alpha: 0.10),
                        blurRadius: 24,
                        offset: const Offset(0, 14),
                      ),
                    ],
                  ),
                  child: Icon(icon, size: 40, color: _kPrimaryDark),
                ),
                const SizedBox(height: 18),
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.w800,
                    color: AppColors.ink,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Sezione vuota per ora, la prepariamo nel prossimo step.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 14,
                    height: 1.5,
                    color: AppColors.slate,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _RefillSpotCard extends StatelessWidget {
  const _RefillSpotCard({required this.bar});

  final BarSpot bar;

  @override
  Widget build(BuildContext context) {
    final services = bar.services.isEmpty
        ? const <String>['Servizi in aggiornamento']
        : bar.services;
    final galleryImages = bar.galleryImages.take(6).toList();
    final socialEntries = bar.socialLinks.entries.toList()
      ..sort((a, b) => a.key.compareTo(b.key));

    return Container(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 22),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: AppColors.border),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.035),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(16),
                  color: AppColors.surfaceAlt,
                ),
                child: const Icon(
                  Icons.storefront_rounded,
                  color: _kPrimaryDark,
                  size: 24,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            bar.name,
                            style: const TextStyle(
                              fontSize: 19,
                              fontWeight: FontWeight.w700,
                              color: AppColors.ink,
                            ),
                          ),
                        ),
                        if (bar.featured)
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 9,
                              vertical: 5,
                            ),
                            decoration: BoxDecoration(
                              color: AppColors.surfaceAlt,
                              borderRadius: BorderRadius.circular(999),
                            ),
                            child: const Text(
                              'In evidenza',
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w700,
                                color: _kPrimaryDark,
                              ),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    _RefillDetailRow(
                      icon: Icons.location_on_outlined,
                      text: _buildAddress(bar),
                    ),
                    const SizedBox(height: 6),
                    _RefillDetailRow(
                      icon: Icons.schedule_rounded,
                      text: bar.openInfo,
                    ),
                    const SizedBox(height: 6),
                    _RefillDetailRow(
                      icon: Icons.water_drop_outlined,
                      text: bar.refillInfo,
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          _SectionHeader(
            title: 'Gallery',
            trailing: '${galleryImages.length} foto',
          ),
          const SizedBox(height: 12),
          SizedBox(
            height: 96,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: galleryImages.length,
              separatorBuilder: (_, _) => const SizedBox(width: 10),
              itemBuilder: (context, index) {
                return _GalleryThumbnail(
                  imageUrl: galleryImages[index],
                  index: index,
                  onTap: () => _openGalleryViewer(
                    context,
                    title: bar.name,
                    images: galleryImages,
                    initialIndex: index,
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 20),
          const Divider(height: 1, color: AppColors.line),
          const SizedBox(height: 20),
          const _SectionHeader(title: 'Servizi offerti'),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: services
                .map(
                  (service) => _InfoChip(
                    icon: Icons.check_circle_outline_rounded,
                    label: service,
                  ),
                )
                .toList(),
          ),
          const SizedBox(height: 20),
          const Divider(height: 1, color: AppColors.line),
          const SizedBox(height: 20),
          const _SectionHeader(title: 'Social'),
          const SizedBox(height: 12),
          if (socialEntries.isEmpty)
            Text(
              'Pagine social in aggiornamento.',
              style: TextStyle(fontSize: 13, color: AppColors.slate),
            )
          else
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: socialEntries
                  .map(
                    (entry) => _SocialLinkButton(
                      label: _socialLabel(entry.key),
                      icon: _socialIcon(entry.key),
                      onTap: () => _launchExternalLink(
                        context,
                        entry.value,
                        failureMessage:
                            'Non riesco ad aprire ${_socialLabel(entry.key)} in questo momento.',
                      ),
                    ),
                  )
                  .toList(),
            ),
        ],
      ),
    );
  }
}

class _SponsorCard extends StatelessWidget {
  const _SponsorCard({required this.sponsor});

  final SponsorSpot sponsor;

  @override
  Widget build(BuildContext context) {
    final socialEntries = sponsor.socialLinks.entries.toList()
      ..sort((a, b) => a.key.compareTo(b.key));

    return Container(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 22),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: AppColors.border),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.035),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(16),
                  color: AppColors.surfaceAlt,
                ),
                child: const Icon(
                  Icons.handshake_rounded,
                  color: _kPrimaryDark,
                  size: 24,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            sponsor.name,
                            style: const TextStyle(
                              fontSize: 19,
                              fontWeight: FontWeight.w700,
                              color: AppColors.ink,
                            ),
                          ),
                        ),
                        if (sponsor.featured)
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 9,
                              vertical: 5,
                            ),
                            decoration: BoxDecoration(
                              color: AppColors.surfaceAlt,
                              borderRadius: BorderRadius.circular(999),
                            ),
                            child: const Text(
                              'Sponsor partner',
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w700,
                                color: _kPrimaryDark,
                              ),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    _RefillDetailRow(
                      icon: Icons.store_mall_directory_outlined,
                      text: sponsor.category,
                    ),
                    const SizedBox(height: 6),
                    _RefillDetailRow(
                      icon: Icons.location_on_outlined,
                      text: sponsor.address,
                    ),
                    const SizedBox(height: 6),
                    _RefillDetailRow(
                      icon: Icons.favorite_outline_rounded,
                      text: sponsor.contribution,
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          const _SectionHeader(title: 'Messaggio di ringraziamento'),
          const SizedBox(height: 12),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFFF7FAFD),
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: const Color(0xFFE8EEF5)),
            ),
            child: Text(
              sponsor.thankYouMessage,
              style: TextStyle(fontSize: 13, height: 1.5, color: AppColors.ink),
            ),
          ),
          const SizedBox(height: 20),
          const Divider(height: 1, color: AppColors.line),
          const SizedBox(height: 20),
          const _SectionHeader(title: 'Contributo al progetto'),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: sponsor.supports
                .map(
                  (support) => _InfoChip(
                    icon: Icons.volunteer_activism_outlined,
                    label: support,
                  ),
                )
                .toList(),
          ),
          const SizedBox(height: 20),
          const Divider(height: 1, color: AppColors.line),
          const SizedBox(height: 20),
          const _SectionHeader(title: 'Social'),
          const SizedBox(height: 12),
          if (socialEntries.isEmpty)
            Text(
              'Pagine social in aggiornamento.',
              style: TextStyle(fontSize: 13, color: AppColors.slate),
            )
          else
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: socialEntries
                  .map(
                    (entry) => _SocialLinkButton(
                      label: _socialLabel(entry.key),
                      icon: _socialIcon(entry.key),
                      onTap: () => _launchExternalLink(
                        context,
                        entry.value,
                        failureMessage:
                            'Non riesco ad aprire ${_socialLabel(entry.key)} in questo momento.',
                      ),
                    ),
                  )
                  .toList(),
            ),
        ],
      ),
    );
  }
}

class _GalleryThumbnail extends StatelessWidget {
  const _GalleryThumbnail({
    required this.imageUrl,
    required this.index,
    required this.onTap,
  });

  final String imageUrl;
  final int index;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(18),
        child: Stack(
          children: [
            SizedBox(
              width: 120,
              height: 96,
              child: _GalleryImage(imageUrl: imageUrl),
            ),
            Positioned(
              top: 8,
              left: 8,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.45),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  '${index + 1}/6',
                  style: const TextStyle(
                    fontSize: 11,
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
  }
}

class _GalleryImage extends StatelessWidget {
  const _GalleryImage({required this.imageUrl});

  final String imageUrl;

  @override
  Widget build(BuildContext context) {
    return Image.network(
      imageUrl,
      fit: BoxFit.cover,
      loadingBuilder: (context, child, loadingProgress) {
        if (loadingProgress == null) {
          return child;
        }
        return Container(
          color: AppColors.surfaceAlt,
          alignment: Alignment.center,
          child: const SizedBox(
            width: 24,
            height: 24,
            child: CircularProgressIndicator(strokeWidth: 2.2),
          ),
        );
      },
      errorBuilder: (context, error, stackTrace) {
        return Container(
          color: AppColors.surfaceAlt,
          alignment: Alignment.center,
          child: const Icon(
            Icons.image_not_supported_outlined,
            color: _kPrimaryDark,
            size: 28,
          ),
        );
      },
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.title, this.trailing});

  final String title;
  final String? trailing;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Text(
          title,
          style: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w700,
            color: AppColors.ink,
          ),
        ),
        const Spacer(),
        if (trailing != null)
          Text(
            trailing!,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: AppColors.slate,
            ),
          ),
      ],
    );
  }
}

class _RefillDetailRow extends StatelessWidget {
  const _RefillDetailRow({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 2),
          child: Icon(icon, size: 15, color: AppColors.iconMuted),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            text,
            style: TextStyle(
              fontSize: 13,
              height: 1.45,
              color: AppColors.slate,
            ),
          ),
        ),
      ],
    );
  }
}

class _GalleryViewerDialog extends StatefulWidget {
  const _GalleryViewerDialog({
    required this.title,
    required this.images,
    required this.initialIndex,
  });

  final String title;
  final List<String> images;
  final int initialIndex;

  @override
  State<_GalleryViewerDialog> createState() => _GalleryViewerDialogState();
}

class _GalleryViewerDialogState extends State<_GalleryViewerDialog> {
  late final PageController _pageController;
  late int _currentIndex;

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex;
    _pageController = PageController(initialPage: widget.initialIndex);
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      child: Container(
        decoration: BoxDecoration(
          color: const Color(0xFF0F223A),
          borderRadius: BorderRadius.circular(28),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(18, 18, 10, 8),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.title,
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w800,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Foto ${_currentIndex + 1} di ${widget.images.length}',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: Colors.white.withValues(alpha: 0.75),
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.close_rounded, color: Colors.white),
                  ),
                ],
              ),
            ),
            AspectRatio(
              aspectRatio: 4 / 3,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(22),
                child: PageView.builder(
                  controller: _pageController,
                  itemCount: widget.images.length,
                  onPageChanged: (index) {
                    setState(() {
                      _currentIndex = index;
                    });
                  },
                  itemBuilder: (context, index) {
                    return _GalleryImage(imageUrl: widget.images[index]);
                  },
                ),
              ),
            ),
            const SizedBox(height: 14),
            SizedBox(
              height: 68,
              child: ListView.separated(
                padding: const EdgeInsets.fromLTRB(18, 0, 18, 18),
                scrollDirection: Axis.horizontal,
                itemCount: widget.images.length,
                separatorBuilder: (_, _) => const SizedBox(width: 10),
                itemBuilder: (context, index) {
                  final isSelected = index == _currentIndex;
                  return GestureDetector(
                    onTap: () {
                      _pageController.animateToPage(
                        index,
                        duration: const Duration(milliseconds: 220),
                        curve: Curves.easeOut,
                      );
                    },
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 180),
                      width: 76,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: isSelected ? Colors.white : Colors.transparent,
                          width: 2,
                        ),
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(14),
                        child: _GalleryImage(imageUrl: widget.images[index]),
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SocialLinkButton extends StatelessWidget {
  const _SocialLinkButton({
    required this.label,
    required this.icon,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return OutlinedButton.icon(
      onPressed: onTap,
      icon: Icon(icon, size: 16),
      label: Text(label),
      style: OutlinedButton.styleFrom(
        foregroundColor: _kPrimaryDark,
        side: const BorderSide(color: AppColors.border),
        backgroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        textStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
        elevation: 0,
      ),
    );
  }
}

class _EmptyRefillCard extends StatelessWidget {
  const _EmptyRefillCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Nessun punto refill disponibile per ora.',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: AppColors.ink,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Quando i locali saranno attivi, qui compariranno schede con orari, servizi e link social.',
            style: TextStyle(fontSize: 13, height: 1.4, color: AppColors.slate),
          ),
        ],
      ),
    );
  }
}

class _EmptySponsorsCard extends StatelessWidget {
  const _EmptySponsorsCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Nessuno sponsor disponibile per ora.',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: AppColors.ink,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Gli sponsor pubblicati dal CRM compariranno qui automaticamente.',
            style: TextStyle(fontSize: 13, height: 1.4, color: AppColors.slate),
          ),
        ],
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
    return Container(
      height: 420,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(30),
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: AppColors.ocean.withValues(alpha: 0.10),
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
                  urlTemplate: geoapifyApiKey.isNotEmpty
                      ? _kGeoapifyTileUrl
                      : _kOpenStreetMapTileUrl,
                  additionalOptions: geoapifyApiKey.isNotEmpty
                      ? const {'apiKey': geoapifyApiKey}
                      : const {},
                  userAgentPackageName: 'com.example.fairwater',
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
                RichAttributionWidget(
                  attributions: [
                    if (geoapifyApiKey.isNotEmpty)
                      TextSourceAttribution(
                        'Geoapify',
                        onTap: () => launchUrl(
                          Uri.parse('https://www.geoapify.com/'),
                          mode: LaunchMode.externalApplication,
                        ),
                      ),
                    TextSourceAttribution(
                      'OpenStreetMap contributors',
                      onTap: () => launchUrl(
                        Uri.parse('https://www.openstreetmap.org/copyright'),
                        mode: LaunchMode.externalApplication,
                      ),
                    ),
                  ],
                ),
              ],
            ),
            Positioned(
              top: 18,
              right: 18,
              child: _RoundActionButton(
                icon: Icons.my_location_rounded,
                onTap: onRefreshLocation,
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
            color: AppColors.ocean.withValues(alpha: 0.14),
          ),
        ),
        Container(
          width: 46,
          height: 46,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: Colors.white,
            border: Border.all(color: AppColors.ocean, width: 6),
            boxShadow: [
              BoxShadow(
                color: AppColors.ocean.withValues(alpha: 0.18),
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
                  color: highlighted ? _kPrimary : AppColors.ink,
                ),
              ),
              const SizedBox(height: 1),
              Text(
                subtitle,
                style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: AppColors.ink,
                ),
              ),
            ],
          ),
        ),
        Container(
          width: 18,
          height: 18,
          decoration: BoxDecoration(
            color: highlighted ? _kPrimary : AppColors.aqua,
            shape: BoxShape.circle,
            border: Border.all(color: Colors.white, width: 3),
            boxShadow: [
              BoxShadow(
                color: AppColors.ocean.withValues(alpha: 0.22),
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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
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
                              color: AppColors.ink,
                            ),
                          ),
                        ),
                        _DistanceBadge(distance: view.distanceLabel),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      _buildAddress(view.bar),
                      style: TextStyle(fontSize: 13, color: AppColors.slate),
                    ),
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        _InfoChip(
                          icon: Icons.water_drop_outlined,
                          label: view.bar.refillInfo,
                        ),
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
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: () => _openNavigation(context, view),
              icon: const Icon(Icons.navigation_rounded),
              label: const Text('Avvia navigazione'),
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
        color: AppColors.mist,
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

class _EmptyNearbyBarsCard extends StatelessWidget {
  const _EmptyNearbyBarsCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Nessun bar affiliato nel raggio di 5 km.',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: AppColors.ink,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Prova ad aggiornare la posizione o spostati leggermente per vedere altri punti vicini.',
            style: TextStyle(fontSize: 13, height: 1.4, color: AppColors.slate),
          ),
        ],
      ),
    );
  }
}

class _CityRefillSearch extends StatefulWidget {
  const _CityRefillSearch({required this.bars, required this.center});

  final List<BarSpot> bars;
  final LatLng center;

  @override
  State<_CityRefillSearch> createState() => _CityRefillSearchState();
}

class _CityRefillSearchState extends State<_CityRefillSearch> {
  final TextEditingController _cityController = TextEditingController();
  final AddressSearchService _addressSearchService = AddressSearchService();
  Timer? _searchDebounce;
  List<AddressSuggestion> _suggestions = const [];
  String _query = '';
  String? _selectedCity;
  LatLng? _selectedCenter;
  bool _searching = false;
  String? _searchError;

  @override
  void dispose() {
    _searchDebounce?.cancel();
    _cityController.dispose();
    super.dispose();
  }

  void _onCityChanged(String value) {
    _searchDebounce?.cancel();
    setState(() {
      _query = value;
      _selectedCity = null;
      _selectedCenter = null;
      _searchError = null;
      _suggestions = const [];
      _searching = value.trim().length >= 2;
    });
    final query = value.trim();
    if (query.length < 2) {
      setState(() => _searching = false);
      return;
    }
    _searchDebounce = Timer(const Duration(milliseconds: 350), () async {
      try {
        final suggestions = await _addressSearchService.autocomplete(
          query: query,
          sessionToken: 'home-city-search',
          type: 'city',
        );
        if (!mounted || _cityController.text.trim() != query) return;
        setState(() {
          _suggestions = suggestions;
          _searching = false;
        });
      } catch (_) {
        if (!mounted || _cityController.text.trim() != query) return;
        setState(() {
          _searching = false;
          _searchError =
              'Ricerca dei comuni non disponibile. Riprova tra poco.';
        });
      }
    });
  }

  void _selectCity(AddressSuggestion suggestion) {
    final city = suggestion.city.isEmpty
        ? (suggestion.mainText.isEmpty ? suggestion.label : suggestion.mainText)
        : suggestion.city;
    setState(() {
      _selectedCity = city;
      _selectedCenter = LatLng(suggestion.latitude, suggestion.longitude);
      _cityController.text = city;
      _query = city;
      _suggestions = const [];
      _searchError = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    final selectedCity = _selectedCity?.trim().toLowerCase();
    final results =
        selectedCity == null || selectedCity.isEmpty
              ? <_NearbyBarView>[]
              : widget.bars
                    .where(
                      (bar) => bar.city.trim().toLowerCase() == selectedCity,
                    )
                    .map((bar) {
                      final center = _selectedCenter ?? widget.center;
                      final distance = Geolocator.distanceBetween(
                        center.latitude,
                        center.longitude,
                        bar.location.latitude,
                        bar.location.longitude,
                      );
                      return _NearbyBarView(
                        bar: bar,
                        location: bar.location,
                        distanceMeters: distance,
                      );
                    })
                    .toList()
          ..sort((a, b) => a.distanceMeters.compareTo(b.distanceMeters));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(22),
            border: Border.all(color: AppColors.border),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Cerca punti refill in un comune',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  color: AppColors.ink,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'Cerca e seleziona un comune italiano per vedere i punti refill affiliati a FairWater.',
                style: TextStyle(
                  fontSize: 13,
                  height: 1.4,
                  color: AppColors.slate,
                ),
              ),
              const SizedBox(height: 14),
              TextField(
                controller: _cityController,
                textInputAction: TextInputAction.search,
                onChanged: _onCityChanged,
                decoration: InputDecoration(
                  hintText: 'Cerca un comune italiano',
                  prefixIcon: const Icon(Icons.location_city_rounded),
                  suffixIcon: _searching
                      ? const Padding(
                          padding: EdgeInsets.all(14),
                          child: SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          ),
                        )
                      : _query.isEmpty
                      ? null
                      : IconButton(
                          tooltip: 'Cancella ricerca',
                          onPressed: () {
                            _cityController.clear();
                            setState(() {
                              _query = '';
                              _selectedCity = null;
                              _selectedCenter = null;
                              _suggestions = const [];
                              _searchError = null;
                            });
                          },
                          icon: const Icon(Icons.close_rounded),
                        ),
                  filled: true,
                  fillColor: AppColors.surfaceMuted,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
            ],
          ),
        ),
        if (_searchError != null) ...[
          const SizedBox(height: 10),
          Text(_searchError!, style: TextStyle(color: AppColors.slate)),
        ],
        if (_suggestions.isNotEmpty) ...[
          const SizedBox(height: 10),
          Container(
            decoration: BoxDecoration(
              color: Colors.white,
              border: Border.all(color: AppColors.border),
              borderRadius: BorderRadius.circular(18),
            ),
            child: Column(
              children: [
                for (var i = 0; i < _suggestions.length; i++) ...[
                  if (i > 0) const Divider(height: 1),
                  ListTile(
                    leading: const Icon(
                      Icons.location_on_outlined,
                      color: _kPrimary,
                    ),
                    title: Text(
                      _suggestions[i].city.isEmpty
                          ? _suggestions[i].mainText
                          : _suggestions[i].city,
                    ),
                    subtitle: Text(_suggestions[i].secondaryText),
                    onTap: () => _selectCity(_suggestions[i]),
                  ),
                ],
              ],
            ),
          ),
        ],
        if (_selectedCity != null) ...[
          const SizedBox(height: 12),
          if (results.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
              child: Text(
                'Nessun punto refill affiliato trovato a "${_selectedCity!}".',
                style: TextStyle(fontSize: 13, color: AppColors.slate),
              ),
            )
          else
            for (var i = 0; i < results.length; i++) ...[
              if (i > 0) const SizedBox(height: 12),
              _BarCard(view: results[i]),
            ],
        ],
      ],
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
      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 8),
      decoration: BoxDecoration(
        color: AppColors.surfaceMuted,
        border: Border.all(color: AppColors.border),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: AppColors.slate),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: AppColors.ink,
            ),
          ),
        ],
      ),
    );
  }
}

class _NearbyBarView {
  const _NearbyBarView({
    required this.bar,
    required this.location,
    required this.distanceMeters,
  });

  final BarSpot bar;
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

String _formatDistance(double meters) {
  if (meters < 1000) {
    return '${meters.round()} m';
  }
  return '${(meters / 1000).toStringAsFixed(1)} km';
}

String _buildAddress(BarSpot bar) {
  final parts = <String>[
    if (bar.address.isNotEmpty) bar.address,
    if (bar.city.isNotEmpty) bar.city,
  ];

  if (parts.isEmpty) {
    return 'Indirizzo non disponibile';
  }

  return parts.join(', ');
}

Future<void> _openGalleryViewer(
  BuildContext context, {
  required String title,
  required List<String> images,
  required int initialIndex,
}) async {
  if (images.isEmpty) {
    return;
  }

  await showDialog<void>(
    context: context,
    builder: (_) => _GalleryViewerDialog(
      title: title,
      images: images,
      initialIndex: initialIndex,
    ),
  );
}

Future<void> _openNavigation(BuildContext context, _NearbyBarView view) async {
  final destinationLabel = Uri.encodeComponent(view.bar.name);
  final latitude = view.location.latitude;
  final longitude = view.location.longitude;

  final candidateUris = <Uri>[
    if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android)
      Uri.parse('geo:0,0?q=$latitude,$longitude($destinationLabel)'),
    if (!kIsWeb && defaultTargetPlatform == TargetPlatform.iOS)
      Uri.parse(
        'http://maps.apple.com/?daddr=$latitude,$longitude&q=$destinationLabel',
      ),
    Uri.parse(
      'https://www.google.com/maps/dir/?api=1&destination=$latitude,$longitude&travelmode=walking',
    ),
  ];

  for (final uri in candidateUris) {
    if (await launchUrl(uri, mode: LaunchMode.externalApplication)) {
      return;
    }
  }

  if (!context.mounted) {
    return;
  }

  ScaffoldMessenger.of(context).showSnackBar(
    const SnackBar(
      content: Text('Nessuna app di navigazione disponibile sul dispositivo.'),
    ),
  );
}

Future<void> _launchExternalLink(
  BuildContext context,
  String url, {
  required String failureMessage,
}) async {
  final uri = Uri.tryParse(url);
  if (uri == null) {
    if (!context.mounted) {
      return;
    }
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(failureMessage)));
    return;
  }

  if (await launchUrl(uri, mode: LaunchMode.externalApplication)) {
    return;
  }

  if (!context.mounted) {
    return;
  }

  ScaffoldMessenger.of(
    context,
  ).showSnackBar(SnackBar(content: Text(failureMessage)));
}

String _socialLabel(String key) {
  switch (key.toLowerCase()) {
    case 'instagram':
      return 'Instagram';
    case 'facebook':
      return 'Facebook';
    case 'tiktok':
      return 'TikTok';
    case 'website':
      return 'Sito web';
    default:
      return key;
  }
}

IconData _socialIcon(String key) {
  switch (key.toLowerCase()) {
    case 'instagram':
      return Icons.camera_alt_rounded;
    case 'facebook':
      return Icons.thumb_up_alt_rounded;
    case 'tiktok':
      return Icons.music_note_rounded;
    case 'website':
      return Icons.language_rounded;
    default:
      return Icons.open_in_new_rounded;
  }
}
