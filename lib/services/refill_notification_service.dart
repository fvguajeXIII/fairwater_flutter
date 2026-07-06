import 'dart:async';

import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:geolocator/geolocator.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'bar_service.dart';

class RefillNotificationService {
  RefillNotificationService._();

  static final RefillNotificationService instance =
      RefillNotificationService._();

  static const double triggerRadiusMeters = 100;
  static const Duration merchantCooldown = Duration(hours: 2);
  static const String _channelId = 'nearby_refill_channel';
  static const String _channelName = 'Refill vicini';
  static const String _channelDescription =
      'Avvisi quando sei vicino a un punto refill.';
  static const String _merchantPrefix = 'refill_notified_';

  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();

  List<BarSpot> _bars = const <BarSpot>[];
  bool _initialized = false;
  bool _checking = false;
  bool _permissionsRequested = false;

  Future<void> initialize() async {
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

    _initialized = true;
  }

  Future<void> requestPermissions() async {
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
}
