import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';
import 'package:permission_handler/permission_handler.dart';

/// Service for handling location-based operations
/// Follows the existing service pattern from journal_service.dart
class LocationService {
  static final LocationService _instance = LocationService._internal();
  factory LocationService() => _instance;
  LocationService._internal();

  /// Check and request location permissions
  /// Returns true if permission is granted, false otherwise
  Future<bool> requestLocationPermission() async {
    try {
      // Check if location services are enabled
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        // Location services are not enabled
        // Could show a dialog to the user here
        return false;
      }

      LocationPermission permission = await Geolocator.checkPermission();

      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          // Permissions are denied
          return false;
        }
      }

      if (permission == LocationPermission.deniedForever) {
        // Permissions are permanently denied
        // Open app settings for user to manually enable
        await openAppSettings();
        return false;
      }

      // Permission granted (whileInUse or always)
      return true;
    } catch (e) {
      print('Error checking location permission: $e');
      return false;
    }
  }

  /// Get current GPS location
  /// Returns Position object with latitude, longitude, accuracy, etc.
  Future<Position?> getCurrentLocation({
    LocationAccuracy accuracy = LocationAccuracy.high,
    Duration? timeout,
  }) async {
    try {
      final hasPermission = await requestLocationPermission();
      if (!hasPermission) {
        print('Location permission not granted');
        return null;
      }

      // Get current position with specified accuracy
      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: accuracy,
        timeLimit: timeout ?? const Duration(seconds: 10),
      );

      print('Location captured: ${position.latitude}, ${position.longitude}');
      print('Accuracy: ${position.accuracy} meters');

      return position;
    } catch (e) {
      print('Error getting location: $e');
      return null;
    }
  }

  /// Convert GPS coordinates to human-readable address
  /// Uses reverse geocoding to get street address, city, etc.
  Future<String?> getAddressFromCoordinates(
    double latitude,
    double longitude,
  ) async {
    try {
      // Perform reverse geocoding
      List<Placemark> placemarks = await placemarkFromCoordinates(
        latitude,
        longitude,
      );

      if (placemarks.isNotEmpty) {
        Placemark place = placemarks[0];

        // Build comprehensive address string
        List<String> addressParts = [
          if (place.street != null && place.street!.isNotEmpty) place.street!,
          if (place.locality != null && place.locality!.isNotEmpty)
            place.locality!,
          if (place.administrativeArea != null &&
              place.administrativeArea!.isNotEmpty)
            place.administrativeArea!,
          if (place.postalCode != null && place.postalCode!.isNotEmpty)
            place.postalCode!,
          if (place.country != null && place.country!.isNotEmpty)
            place.country!,
        ];

        final address =
            addressParts.where((part) => part.isNotEmpty).join(', ');
        print('Address found: $address');
        return address;
      }

      return null;
    } catch (e) {
      print('Error getting address from coordinates: $e');
      return null;
    }
  }

  /// Calculate distance between two GPS points in meters
  /// Useful for geofencing or proximity features
  double calculateDistance(
    double startLatitude,
    double startLongitude,
    double endLatitude,
    double endLongitude,
  ) {
    return Geolocator.distanceBetween(
      startLatitude,
      startLongitude,
      endLatitude,
      endLongitude,
    );
  }

  /// Check if location services are available on this device
  Future<bool> isLocationServiceEnabled() async {
    return await Geolocator.isLocationServiceEnabled();
  }

  /// Get last known location (may be stale)
  /// Useful for quick location without waiting for GPS fix
  Future<Position?> getLastKnownLocation() async {
    try {
      final hasPermission = await requestLocationPermission();
      if (!hasPermission) return null;

      return await Geolocator.getLastKnownPosition();
    } catch (e) {
      print('Error getting last known location: $e');
      return null;
    }
  }

  /// Stream location updates for real-time tracking
  /// Returns a stream that emits new positions as device moves
  Stream<Position> getLocationStream({
    LocationAccuracy accuracy = LocationAccuracy.high,
    int distanceFilter = 10, // minimum distance (in meters) before update
  }) {
    return Geolocator.getPositionStream(
      locationSettings: LocationSettings(
        accuracy: accuracy,
        distanceFilter: distanceFilter,
      ),
    );
  }
}
