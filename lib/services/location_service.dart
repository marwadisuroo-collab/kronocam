import 'package:geocoding/geocoding.dart';
import 'package:geolocator/geolocator.dart';

class LocationResult {
  final double latitude;
  final double longitude;
  final String? address;

  const LocationResult({
    required this.latitude,
    required this.longitude,
    this.address,
  });
}

class LocationService {
  static Stream<Position> get positionStream => Geolocator.getPositionStream(
    locationSettings: const LocationSettings(
      accuracy: LocationAccuracy.high,
      distanceFilter: 5,
    ),
  );

  static Future<LocationResult> fromCoordinates(
    double latitude,
    double longitude,
  ) async {
    return _toResultValues(latitude, longitude);
  }

  static Future<LocationResult?> getCachedLocation() async {
    try {
      final position = await Geolocator.getLastKnownPosition();
      if (position == null) return null;
      return LocationResult(
        latitude: position.latitude,
        longitude: position.longitude,
      );
    } catch (_) {
      return null;
    }
  }

  static Future<LocationResult?> getCurrentLocation() async {
    try {
      if (!await Geolocator.isLocationServiceEnabled()) return null;

      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        return null;
      }

      // Use the last fix immediately, then prefer a fresh high-accuracy fix.
      final cached = await Geolocator.getLastKnownPosition();
      Position position;
      try {
        position = await Geolocator.getCurrentPosition(
          locationSettings: const LocationSettings(
            accuracy: LocationAccuracy.high,
            timeLimit: Duration(seconds: 8),
          ),
        );
      } catch (_) {
        if (cached == null) rethrow;
        position = cached;
      }
      return await _toResult(position);
    } catch (_) {
      return null;
    }
  }

  static Future<LocationResult> _toResult(Position position) async {
    return _toResultValues(position.latitude, position.longitude);
  }

  static Future<LocationResult> _toResultValues(
    double latitude,
    double longitude,
  ) async {
    String? address;
    try {
      final placemarks = await placemarkFromCoordinates(
          latitude,
          longitude,
      );
      if (placemarks.isNotEmpty) {
        final place = placemarks.first;
        final parts = <String>[
          if ((place.locality ?? '').trim().isNotEmpty) place.locality!.trim(),
          if ((place.administrativeArea ?? '').trim().isNotEmpty)
            place.administrativeArea!.trim(),
          if ((place.country ?? '').trim().isNotEmpty) place.country!.trim(),
        ];
        if (parts.isNotEmpty) address = parts.join(', ');
      }
    } catch (_) {}
    return LocationResult(
      latitude: latitude,
      longitude: longitude,
      address: address,
    );
  }
}
