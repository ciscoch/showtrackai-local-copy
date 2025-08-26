import 'dart:async';
import 'package:flutter/services.dart';
import 'package:geolocator/geolocator.dart';
import 'package:permission_handler/permission_handler.dart';
import '../models/journal_entry.dart' show LocationData;

/// Service for handling geolocation permissions and GPS data
/// Provides comprehensive location services for the ShowTrackAI app
class GeolocationService {
  static const String _tag = 'GeolocationService';
  
  // Cache the last known location for 5 minutes
  static Position? _lastKnownPosition;
  static DateTime? _lastLocationTime;
  static const Duration _locationCacheTimeout = Duration(minutes: 5);
  
  /// Check if location services are enabled and permission is granted
  static Future<LocationPermissionStatus> checkLocationStatus() async {
    try {
      // Check if location services are enabled
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        return LocationPermissionStatus.serviceDisabled;
      }

      // Check location permission
      final permission = await Geolocator.checkPermission();
      
      switch (permission) {
        case LocationPermission.always:
        case LocationPermission.whileInUse:
          return LocationPermissionStatus.granted;
        case LocationPermission.denied:
          return LocationPermissionStatus.denied;
        case LocationPermission.deniedForever:
          return LocationPermissionStatus.deniedForever;
        case LocationPermission.unableToDetermine:
          return LocationPermissionStatus.unknown;
      }
    } catch (e) {
      print('$_tag: Error checking location status: $e');
      return LocationPermissionStatus.error;
    }
  }

  /// Request location permission from user
  static Future<LocationPermissionStatus> requestLocationPermission() async {
    try {
      // First check if location services are enabled
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        // Try to prompt user to enable location services
        final opened = await Geolocator.openLocationSettings();
        if (!opened) {
          return LocationPermissionStatus.serviceDisabled;
        }
        
        // Check again after user potentially enabled services
        final stillDisabled = !await Geolocator.isLocationServiceEnabled();
        if (stillDisabled) {
          return LocationPermissionStatus.serviceDisabled;
        }
      }

      // Request permission
      final permission = await Geolocator.requestPermission();
      
      switch (permission) {
        case LocationPermission.always:
        case LocationPermission.whileInUse:
          return LocationPermissionStatus.granted;
        case LocationPermission.denied:
          return LocationPermissionStatus.denied;
        case LocationPermission.deniedForever:
          return LocationPermissionStatus.deniedForever;
        case LocationPermission.unableToDetermine:
          return LocationPermissionStatus.unknown;
      }
    } catch (e) {
      print('$_tag: Error requesting location permission: $e');
      return LocationPermissionStatus.error;
    }
  }

  /// Get current location with comprehensive error handling
  static Future<LocationResult> getCurrentLocation({
    bool requestPermissionIfNeeded = true,
    Duration timeout = const Duration(seconds: 15),
    LocationAccuracy accuracy = LocationAccuracy.high,
  }) async {
    try {
      // Check permission status first
      var status = await checkLocationStatus();
      
      if (status != LocationPermissionStatus.granted) {
        if (requestPermissionIfNeeded && status == LocationPermissionStatus.denied) {
          status = await requestLocationPermission();
        }
        
        if (status != LocationPermissionStatus.granted) {
          return LocationResult.error(
            'Location permission required',
            _getStatusMessage(status),
          );
        }
      }

      // Check if we have a recent cached location
      if (_lastKnownPosition != null && 
          _lastLocationTime != null && 
          DateTime.now().difference(_lastLocationTime!) < _locationCacheTimeout) {
        return LocationResult.success(await _positionToLocationData(_lastKnownPosition!));
      }

      // Get current position
      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: accuracy,
        timeLimit: timeout,
      );

      // Cache the position
      _lastKnownPosition = position;
      _lastLocationTime = DateTime.now();

      // Convert to LocationData
      final locationData = await _positionToLocationData(position);
      return LocationResult.success(locationData);

    } on LocationServiceDisabledException {
      return LocationResult.error(
        'Location services disabled',
        'Please enable location services in your device settings',
      );
    } on PermissionDeniedException {
      return LocationResult.error(
        'Location permission denied',
        'Location permission is required to capture your current location',
      );
    } on TimeoutException {
      return LocationResult.error(
        'Location timeout',
        'Unable to get location within ${timeout.inSeconds} seconds. Please try again.',
      );
    } catch (e) {
      print('$_tag: Error getting current location: $e');
      
      // Try to return last known location as fallback
      if (_lastKnownPosition != null) {
        final locationData = await _positionToLocationData(_lastKnownPosition!);
        return LocationResult.cached(locationData);
      }
      
      return LocationResult.error(
        'Location unavailable',
        'Unable to get current location: ${e.toString()}',
      );
    }
  }

  /// Get last known location (faster but potentially stale)
  static Future<LocationResult> getLastKnownLocation() async {
    try {
      // Check permission first
      final status = await checkLocationStatus();
      if (status != LocationPermissionStatus.granted) {
        return LocationResult.error(
          'Location permission required',
          _getStatusMessage(status),
        );
      }

      // Try to get last known position
      final position = await Geolocator.getLastKnownPosition();
      
      if (position != null) {
        final locationData = await _positionToLocationData(position);
        return LocationResult.cached(locationData);
      } else {
        return LocationResult.error(
          'No cached location',
          'No previous location data available. Try getting current location.',
        );
      }
    } catch (e) {
      print('$_tag: Error getting last known location: $e');
      return LocationResult.error(
        'Location unavailable',
        e.toString(),
      );
    }
  }

  /// Watch location changes (for real-time tracking)
  static Stream<LocationResult> watchLocation({
    LocationAccuracy accuracy = LocationAccuracy.high,
    int distanceFilter = 10,
  }) async* {
    try {
      // Check permission
      final status = await checkLocationStatus();
      if (status != LocationPermissionStatus.granted) {
        yield LocationResult.error(
          'Location permission required',
          _getStatusMessage(status),
        );
        return;
      }

      // Create location settings
      const locationSettings = LocationSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 10,
      );

      // Stream location updates
      await for (final position in Geolocator.getPositionStream(locationSettings: locationSettings)) {
        // Cache the position
        _lastKnownPosition = position;
        _lastLocationTime = DateTime.now();
        
        final locationData = await _positionToLocationData(position);
        yield LocationResult.success(locationData);
      }
    } catch (e) {
      print('$_tag: Error watching location: $e');
      yield LocationResult.error(
        'Location streaming error',
        e.toString(),
      );
    }
  }

  /// Calculate distance between two locations
  static double calculateDistance(
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

  /// Open device location settings
  static Future<bool> openLocationSettings() async {
    try {
      return await Geolocator.openLocationSettings();
    } catch (e) {
      print('$_tag: Error opening location settings: $e');
      return false;
    }
  }

  /// Open app-specific permission settings
  static Future<bool> openAppSettings() async {
    try {
      return await openAppSettings();
    } catch (e) {
      print('$_tag: Error opening app settings: $e');
      return false;
    }
  }

  /// Convert Position to LocationData with reverse geocoding
  static Future<LocationData> _positionToLocationData(Position position) async {
    try {
      // For now, we'll use a simple address format
      // In a real implementation, you might want to add reverse geocoding
      final address = 'Lat: ${position.latitude.toStringAsFixed(4)}, '
                     'Lon: ${position.longitude.toStringAsFixed(4)}';

      return LocationData(
        latitude: position.latitude,
        longitude: position.longitude,
        address: address,
        name: 'Current Location',
        accuracy: position.accuracy,
        capturedAt: position.timestamp ?? DateTime.now(),
      );
    } catch (e) {
      print('$_tag: Error converting position to location data: $e');
      return LocationData(
        latitude: position.latitude,
        longitude: position.longitude,
        address: 'Location captured',
        name: 'Current Location',
        accuracy: position.accuracy,
        capturedAt: position.timestamp ?? DateTime.now(),
      );
    }
  }

  /// Get human-readable status message
  static String _getStatusMessage(LocationPermissionStatus status) {
    switch (status) {
      case LocationPermissionStatus.granted:
        return 'Location permission granted';
      case LocationPermissionStatus.denied:
        return 'Location permission denied. Please grant permission to capture location.';
      case LocationPermissionStatus.deniedForever:
        return 'Location permission permanently denied. Please enable in app settings.';
      case LocationPermissionStatus.serviceDisabled:
        return 'Location services are disabled. Please enable in device settings.';
      case LocationPermissionStatus.unknown:
        return 'Unable to determine location permission status';
      case LocationPermissionStatus.error:
        return 'Error checking location permission';
    }
  }

  /// Clear cached location data
  static void clearCache() {
    _lastKnownPosition = null;
    _lastLocationTime = null;
  }

  /// Get mock location for testing/demo purposes
  static LocationResult getMockLocation() {
    final mockLocation = LocationData(
      latitude: 39.7392,
      longitude: -104.9903,
      address: 'Denver, CO 80202, USA',
      name: 'Agricultural Education Center',
      accuracy: 5.0,
      capturedAt: DateTime.now(),
    );
    
    return LocationResult.success(mockLocation);
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

/// Configuration for location requests
class LocationConfig {
  final LocationAccuracy accuracy;
  final Duration timeout;
  final int distanceFilter;
  final bool requestPermissionIfNeeded;
  final bool useCachedLocation;

  const LocationConfig({
    this.accuracy = LocationAccuracy.high,
    this.timeout = const Duration(seconds: 15),
    this.distanceFilter = 10,
    this.requestPermissionIfNeeded = true,
    this.useCachedLocation = true,
  });

  /// High accuracy configuration (for precise location)
  static const LocationConfig highAccuracy = LocationConfig(
    accuracy: LocationAccuracy.best,
    timeout: Duration(seconds: 30),
    distanceFilter: 5,
  );

  /// Balanced configuration (good accuracy, reasonable battery usage)
  static const LocationConfig balanced = LocationConfig(
    accuracy: LocationAccuracy.high,
    timeout: Duration(seconds: 15),
    distanceFilter: 10,
  );

  /// Power saving configuration (lower accuracy, better battery)
  static const LocationConfig powerSaving = LocationConfig(
    accuracy: LocationAccuracy.medium,
    timeout: Duration(seconds: 10),
    distanceFilter: 50,
  );
}