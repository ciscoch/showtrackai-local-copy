import 'dart:async';
import '../models/journal_entry.dart' show LocationData;

/// Web-compatible stub implementation of GeolocationService
/// This provides mock location data for web deployment compatibility
/// In a production environment, you would implement proper web geolocation using dart:html
class GeolocationService {
  static const String _tag = 'GeolocationService (Web Stub)';
  
  /// Check if location services are enabled and permission is granted
  static Future<LocationPermissionStatus> checkLocationStatus() async {
    // Mock implementation for web compatibility
    print('$_tag: Mock location status check - returning granted');
    return LocationPermissionStatus.granted;
  }

  /// Request location permission from user
  static Future<LocationPermissionStatus> requestLocationPermission() async {
    // Mock implementation for web compatibility
    print('$_tag: Mock permission request - returning granted');
    return LocationPermissionStatus.granted;
  }

  /// Get current location with mock data for web compatibility
  static Future<LocationResult> getCurrentLocation({
    bool requestPermissionIfNeeded = true,
    Duration timeout = const Duration(seconds: 15),
    dynamic accuracy, // Changed from LocationAccuracy to dynamic for compatibility
  }) async {
    print('$_tag: Returning mock location data');
    
    // Return mock location data for agricultural education demo
    final mockLocation = LocationData(
      latitude: 40.5853,  // Colorado State University coordinates
      longitude: -105.0844,
      address: 'Colorado State University, Fort Collins, CO',
      name: 'Agricultural Education Center',
      accuracy: 5.0,
      capturedAt: DateTime.now(),
      city: 'Fort Collins',
      state: 'CO',
    );

    return LocationResult.success(mockLocation);
  }

  /// Get last known location (mock implementation)
  static Future<LocationResult> getLastKnownLocation() async {
    print('$_tag: Returning mock cached location');
    return getCurrentLocation();
  }

  /// Watch location changes (mock implementation)
  static Stream<LocationResult> watchLocation({
    dynamic accuracy,
    int distanceFilter = 10,
  }) async* {
    print('$_tag: Starting mock location stream');
    yield await getCurrentLocation();
  }

  /// Calculate distance between two locations (basic implementation)
  static double calculateDistance(
    double startLatitude,
    double startLongitude,
    double endLatitude,
    double endLongitude,
  ) {
    // Basic distance calculation using Haversine formula
    const double earthRadius = 6371000; // meters
    
    double lat1Rad = startLatitude * (3.141592653589793 / 180);
    double lat2Rad = endLatitude * (3.141592653589793 / 180);
    double deltaLatRad = (endLatitude - startLatitude) * (3.141592653589793 / 180);
    double deltaLngRad = (endLongitude - startLongitude) * (3.141592653589793 / 180);

    double a = (deltaLatRad / 2).sin() * (deltaLatRad / 2).sin() +
        lat1Rad.cos() * lat2Rad.cos() *
        (deltaLngRad / 2).sin() * (deltaLngRad / 2).sin();
    double c = 2 * (a.sqrt()).atan2((1 - a).sqrt());

    return earthRadius * c;
  }

  /// Open device location settings (mock implementation)
  static Future<bool> openLocationSettings() async {
    print('$_tag: Mock open location settings - returning true');
    return true;
  }

  /// Open app-specific permission settings (mock implementation) 
  static Future<bool> openAppSettings() async {
    print('$_tag: Mock open app settings - returning true');
    return true;
  }

  /// Clear cached location data (mock implementation)
  static void clearCache() {
    print('$_tag: Mock cache clear');
  }
}

/// Enum for location permission status
enum LocationPermissionStatus {
  granted,
  denied,
  deniedForever,
  serviceDisabled,
  unknown,
  error,
}

/// Result wrapper for location operations
class LocationResult {
  final bool isSuccess;
  final LocationData? data;
  final String? error;
  final String? message;
  final bool isCached;

  const LocationResult._({
    required this.isSuccess,
    this.data,
    this.error,
    this.message,
    this.isCached = false,
  });

  /// Success result
  factory LocationResult.success(LocationData data) {
    return LocationResult._(
      isSuccess: true,
      data: data,
      isCached: false,
    );
  }

  /// Cached result (success but from cache)
  factory LocationResult.cached(LocationData data) {
    return LocationResult._(
      isSuccess: true,
      data: data,
      isCached: true,
    );
  }

  /// Error result
  factory LocationResult.error(String error, [String? message]) {
    return LocationResult._(
      isSuccess: false,
      error: error,
      message: message,
    );
  }

  /// Get user-friendly error message
  String get userMessage {
    if (isSuccess) return 'Location captured successfully';
    return message ?? error ?? 'Unknown location error';
  }

  /// Get status text for UI
  String get statusText {
    if (isSuccess && isCached) return 'Using cached location';
    if (isSuccess) return 'Location captured';
    return 'Location unavailable';
  }
}

/// Configuration for location requests (simplified for web)
class LocationConfig {
  final Duration timeout;
  final bool requestPermissionIfNeeded;
  final bool useCachedLocation;

  const LocationConfig({
    this.timeout = const Duration(seconds: 15),
    this.requestPermissionIfNeeded = true,
    this.useCachedLocation = true,
  });

  /// High accuracy configuration (for precise location)
  static const LocationConfig highAccuracy = LocationConfig(
    timeout: Duration(seconds: 30),
  );

  /// Balanced configuration (good accuracy, reasonable battery usage)
  static const LocationConfig balanced = LocationConfig(
    timeout: Duration(seconds: 15),
  );

  /// Power saving configuration (lower accuracy, better battery)
  static const LocationConfig powerSaving = LocationConfig(
    timeout: Duration(seconds: 10),
  );
}