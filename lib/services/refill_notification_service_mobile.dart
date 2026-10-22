import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:geolocator/geolocator.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timezone/data/latest.dart' as tz;
import 'package:timezone/timezone.dart' as tz;

import 'bar_service.dart';

class RefillNotificationService {
  RefillNotificationService._();

  static final RefillNotificationService instance =
      RefillNotificationService._();

  static const double triggerRadiusMeters = 100;
  static const Duration merchantCooldown = Duration(hours: 2);
  static const String _channelId = 'nearby_refill_channel';
  static const String _channelName = 'Refill vicini';
  static const String _birthdayChannelId = 'birthday_notifications';
  static const String _birthdayChannelName = 'Compleanni';
  static const String _birthdayChannelDescription =
      'Promemoria annuali per il compleanno.';
  static const String _channelDescription =
      'Avvisi quando sei vicino a un punto refill.';
  static const String _trackingChannelName = 'Controllo refill in background';
  static const String _merchantPrefix = 'refill_notified_';
  static const MethodChannel _geofenceChannel = MethodChannel(
    'fairwater/refill_geofence',
  );

  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();

  List<BarSpot> _bars = const <BarSpot>[];
  final BarService _barService = BarService();
  StreamSubscription<List<BarSpot>>? _barsSubscription;
  StreamSubscription<Position>? _positionSubscription;
  bool _initialized = false;
  bool _checking = false;
  bool _permissionsRequested = false;
  bool _backgroundLocationRequested = false;
  bool _startingMonitoring = false;

  Future<void> initialize() async {
    if (kIsWeb) {
      return;
    }

    if (_initialized) {
      return;
    }

    const androidSettings = AndroidInitializationSettings(
      '@mipmap/ic_launcher',
    );
    const iosSettings = DarwinInitializationSettings(
      defaultPresentAlert: true,
      defaultPresentBadge: true,
      defaultPresentSound: true,
    );

    tz.initializeTimeZones();

    await _plugin.initialize(
      const InitializationSettings(android: androidSettings, iOS: iosSettings),
    );

    await _plugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >()
        ?.createNotificationChannel(
          const AndroidNotificationChannel(
            _channelId,
            _channelName,
            description: _channelDescription,
            importance: Importance.high,
          ),
        );

    await _plugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >()
        ?.createNotificationChannel(
          const AndroidNotificationChannel(
            _birthdayChannelId,
            _birthdayChannelName,
            description: _birthdayChannelDescription,
            importance: Importance.defaultImportance,
          ),
        );

    _initialized = true;
  }

  Future<void> requestPermissions() async {
    if (kIsWeb) {
      return;
    }

    if (_permissionsRequested) {
      return;
    }

    await _plugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >()
        ?.requestNotificationsPermission();

    await _plugin
        .resolvePlatformSpecificImplementation<
          IOSFlutterLocalNotificationsPlugin
        >()
        ?.requestPermissions(alert: true, badge: true, sound: true);

    _permissionsRequested = true;
  }

  Future<bool> ensureLocationPermissions() async {
    final enabled = await Geolocator.isLocationServiceEnabled();
    if (!enabled) {
      return false;
    }

    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }

    final shouldRequestBackgroundLocation =
        !kIsWeb &&
        (defaultTargetPlatform == TargetPlatform.android ||
            defaultTargetPlatform == TargetPlatform.iOS);
    if (permission == LocationPermission.whileInUse &&
        !_backgroundLocationRequested &&
        shouldRequestBackgroundLocation) {
      _backgroundLocationRequested = true;
      permission = await Geolocator.requestPermission();
    }

    if (permission == LocationPermission.denied ||
        permission == LocationPermission.deniedForever) {
      return false;
    }

    return true;
  }

  Future<void> startBackgroundMonitoring() async {
    if (kIsWeb) {
      return;
    }

    if (_positionSubscription != null || _startingMonitoring) {
      return;
    }

    _startingMonitoring = true;
    try {
      await initialize();
      await requestPermissions();

      final hasLocationPermission = await ensureLocationPermissions();
      if (!hasLocationPermission) {
        return;
      }

      _barsSubscription ??= _barService.watchBars().listen((bars) async {
        updateBars(bars);
        await _syncAndroidGeofences(bars);
        final lastPosition = await Geolocator.getLastKnownPosition();
        if (lastPosition != null) {
          await checkNearbyRefills(lastPosition);
        }
      });

      try {
        final current = await Geolocator.getCurrentPosition(
          locationSettings: const LocationSettings(
            accuracy: LocationAccuracy.high,
          ),
        );
        await checkNearbyRefills(current);
      } catch (_) {
        // The stream below will retry when the platform emits a fresh position.
      }

      _positionSubscription =
          Geolocator.getPositionStream(
            locationSettings: _backgroundLocationSettings(),
          ).listen(
            checkNearbyRefills,
            onError: (_) {
              _positionSubscription?.cancel();
              _positionSubscription = null;
            },
          );
    } finally {
      _startingMonitoring = false;
    }
  }

  LocationSettings _backgroundLocationSettings() {
    if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
      return AndroidSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 25,
        intervalDuration: const Duration(seconds: 30),
        foregroundNotificationConfig: const ForegroundNotificationConfig(
          notificationTitle: 'FairWater attivo',
          notificationText:
              'Controllo i punti refill vicini anche a schermo bloccato.',
          notificationChannelName: _trackingChannelName,
          enableWakeLock: true,
          setOngoing: true,
        ),
      );
    }

    if (!kIsWeb && defaultTargetPlatform == TargetPlatform.iOS) {
      return AppleSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 25,
        activityType: ActivityType.other,
        pauseLocationUpdatesAutomatically: false,
        showBackgroundLocationIndicator: true,
      );
    }

    return const LocationSettings(
      accuracy: LocationAccuracy.high,
      distanceFilter: 25,
    );
  }

  Future<void> stopBackgroundMonitoring() async {
    await _positionSubscription?.cancel();
    _positionSubscription = null;
    await _barsSubscription?.cancel();
    _barsSubscription = null;
    _bars = const <BarSpot>[];
    await _clearAndroidGeofences();
  }

  Future<void> _syncAndroidGeofences(List<BarSpot> bars) async {
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) {
      return;
    }

    try {
      await _geofenceChannel.invokeMethod<void>('syncGeofences', {
        'bars': bars
            .map(
              (bar) => {
                'id': bar.id,
                'name': bar.name,
                'latitude': bar.location.latitude,
                'longitude': bar.location.longitude,
                'radiusMeters': triggerRadiusMeters,
              },
            )
            .toList(),
        'cooldownMinutes': merchantCooldown.inMinutes,
      });
    } catch (_) {
      // The foreground stream remains active if native geofencing is unavailable.
    }
  }

  Future<void> _clearAndroidGeofences() async {
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) {
      return;
    }

    try {
      await _geofenceChannel.invokeMethod<void>('clearGeofences');
    } catch (_) {
      // Best effort cleanup; Android removes geofences when the app is uninstalled.
    }
  }

  void updateBars(List<BarSpot> bars) {
    _bars = List<BarSpot>.unmodifiable(bars);
  }

  Future<void> checkNearbyRefills(Position position) async {
    if (!_initialized || _checking || _bars.isEmpty) {
      return;
    }

    _checking = true;
    try {
      final now = DateTime.now();
      final prefs = await SharedPreferences.getInstance();

      for (final bar in _bars) {
        final distance = Geolocator.distanceBetween(
          position.latitude,
          position.longitude,
          bar.location.latitude,
          bar.location.longitude,
        );

        if (distance > triggerRadiusMeters) {
          continue;
        }

        final lastSent = _lastSentAt(prefs, bar.id);
        if (lastSent != null && now.difference(lastSent) < merchantCooldown) {
          continue;
        }

        await _showNotification(bar, distance.round());
        await prefs.setString(_storageKey(bar.id), now.toIso8601String());
      }
    } finally {
      _checking = false;
    }
  }

  DateTime? _lastSentAt(SharedPreferences prefs, String merchantId) {
    final rawValue = prefs.getString(_storageKey(merchantId));
    if (rawValue == null || rawValue.isEmpty) {
      return null;
    }
    return DateTime.tryParse(rawValue);
  }

  String _storageKey(String merchantId) => '$_merchantPrefix$merchantId';

  Future<void> scheduleBirthdayNotification({
    required String birthDate,
    required String userName,
  }) async {
    if (kIsWeb) {
      return;
    }
    try {
      await initialize();
      await requestPermissions();

      final parsed = DateTime.tryParse(birthDate);
      if (parsed == null) {
        return;
      }

      final now = DateTime.now();
      var nextBirthday = DateTime(now.year, parsed.month, parsed.day, 10, 0);
      if (!nextBirthday.isAfter(now)) {
        nextBirthday = DateTime(now.year + 1, parsed.month, parsed.day, 10, 0);
      }

      final scheduledDate = tz.TZDateTime.from(nextBirthday, tz.local);
      final pending = await _plugin.pendingNotificationRequests();
      final alreadyScheduled = pending.any(
        (request) => request.id == _birthdayNotificationId(userName),
      );
      if (alreadyScheduled) {
        await _plugin.cancel(_birthdayNotificationId(userName));
      }

      await _plugin.zonedSchedule(
        _birthdayNotificationId(userName),
        'Buon compleanno, $userName!',
        'Oggi è il tuo giorno speciale. Dedica un momento a te e ai tuoi ritmi.',
        scheduledDate,
        const NotificationDetails(
          android: AndroidNotificationDetails(
            _birthdayChannelId,
            _birthdayChannelName,
            channelDescription: _birthdayChannelDescription,
            importance: Importance.defaultImportance,
            priority: Priority.defaultPriority,
          ),
          iOS: DarwinNotificationDetails(),
        ),
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        uiLocalNotificationDateInterpretation:
            UILocalNotificationDateInterpretation.absoluteTime,
        matchDateTimeComponents: DateTimeComponents.dateAndTime,
      );
    } catch (_) {
      // Best effort; birthday notifications are optional.
    }
  }

  Future<void> _showNotification(BarSpot bar, int distanceMeters) async {
    final title = 'Punto refill vicino';
    final body =
        '${bar.name} e a circa $distanceMeters m da te. Passa per un refill nelle vicinanze.';

    const androidDetails = AndroidNotificationDetails(
      _channelId,
      _channelName,
      channelDescription: _channelDescription,
      importance: Importance.high,
      priority: Priority.high,
    );
    const iosDetails = DarwinNotificationDetails();

    await _plugin.show(
      _notificationIdForBar(bar.id),
      title,
      body,
      const NotificationDetails(android: androidDetails, iOS: iosDetails),
    );
  }

  int _notificationIdForBar(String barId) => barId.hashCode & 0x7fffffff;

  int _birthdayNotificationId(String userName) =>
      ('birthday_${userName.toLowerCase()}'.hashCode & 0x7fffffff);
}
