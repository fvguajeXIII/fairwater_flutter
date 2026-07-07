import 'package:geolocator/geolocator.dart';

class RefillNotificationService {
  RefillNotificationService._();

  static final RefillNotificationService instance =
      RefillNotificationService._();

  static const double triggerRadiusMeters = 100;

  Future<void> initialize() async {}

  Future<void> requestPermissions() async {}

  Future<bool> ensureLocationPermissions() async {
    final enabled = await Geolocator.isLocationServiceEnabled();
    if (!enabled) {
      return false;
    }

    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }

    return permission != LocationPermission.denied &&
        permission != LocationPermission.deniedForever;
  }

  Future<void> startBackgroundMonitoring() async {}

  Future<void> stopBackgroundMonitoring() async {}

  void updateBars(List<Object> bars) {}

  Future<void> checkNearbyRefills(Position position) async {}
}
