import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:your_package_name/models/location_weather.dart';

// example signatures you referenced in logs:
class WeatherService {
  Future<WeatherData?> getWeatherByLocation(double lat, double lon) async {
    // call your API (e.g., OpenWeather with &units=metric), then:
    // final json = ...;
    // return WeatherData.fromOpenWeather(json);
    return null; // placeholder until your API code is in place
  }

  String getWeatherDescription(WeatherData weather) {
    final t = weather.tempC == null ? '--' : weather.tempC!.toStringAsFixed(1);
    return '${weather.description ?? '—'}  $t°C  '
           'H:${weather.humidity ?? 0}%  '
           'W:${weather.windKph?.toStringAsFixed(1) ?? '0'}kph';
  }
}
/// Service for handling location-based operations
/// Cross-platform version that works on web, Android, and iOS
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
        // Location services are disabled
        return false;
      }

      LocationPermission permission = await Geolocator.checkPermission();

      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          // Location permission denied by user
          return false;
        }
      }

      if (permission == LocationPermission.deniedForever) {
        // Location permission permanently denied
        // On web, we can't open app settings, but we can provide instructions
        if (kIsWeb) {
          // Web: User needs to enable location in browser settings
        } else {
          // Mobile: User needs to enable location in app settings
          // For mobile, we could show a dialog to guide users to settings
        }
        return false;
      }

      // Location permission granted: $permission
      return true;
    } catch (e) {
      // Error checking location permission: $e
      return false;
    }
  }

  /// Get current GPS location
  Future<Position?> getCurrentLocation() async {
    try {
      // Request permission first
      bool hasPermission = await requestLocationPermission();
      if (!hasPermission) {
        // Location permission denied
        return null;
      }

      // Get current position with timeout
      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
        timeLimit: const Duration(seconds: 10),
      );

      // Location captured: ${position.latitude}, ${position.longitude}
      return position;
    } catch (e) {
      // Error getting current location: $e
      return null;
    }
  }

  /// Get human-readable address from coordinates
  Future<String?> getAddressFromCoordinates(double latitude, double longitude) async {
    try {
      List<Placemark> placemarks = await placemarkFromCoordinates(
        latitude,
        longitude,
      );

      if (placemarks.isNotEmpty) {
        Placemark place = placemarks[0];
        
        // Build address string from components
        List<String> addressParts = [];
        
        if (place.street != null && place.street!.isNotEmpty) {
          addressParts.add(place.street!);
        }
        if (place.locality != null && place.locality!.isNotEmpty) {
          addressParts.add(place.locality!);
        }
        if (place.administrativeArea != null && place.administrativeArea!.isNotEmpty) {
          addressParts.add(place.administrativeArea!);
        }
        if (place.postalCode != null && place.postalCode!.isNotEmpty) {
          addressParts.add(place.postalCode!);
        }
        if (place.country != null && place.country!.isNotEmpty) {
          addressParts.add(place.country!);
        }
        
        return addressParts.join(', ');
      }
      
      return null;
    } catch (e) {
      // Error getting address from coordinates: $e
      return null;
    }
  }

  /// Check if location services are available
  Future<bool> isLocationServiceEnabled() async {
    try {
      return await Geolocator.isLocationServiceEnabled();
    } catch (e) {
      // Error checking location service: $e
      return false;
    }
  }

  /// Get current location permission status
  Future<LocationPermission> getPermissionStatus() async {
    try {
      return await Geolocator.checkPermission();
    } catch (e) {
      // Error getting permission status: $e
      return LocationPermission.denied;
    }
  }

  /// Get last known location (may be stale but faster)
  /// Useful for quick location without waiting for GPS fix
  Future<Position?> getLastKnownLocation() async {
    try {
      final hasPermission = await requestLocationPermission();
      if (!hasPermission) {
        // Location permission not granted for last known position
        return null;
      }

      return await Geolocator.getLastKnownPosition();
    } catch (e) {
      // Error getting last known location: $e
      return null;
    }
  }

  /// Calculate distance between two GPS points in meters
  /// Useful for proximity features and geofencing
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
}
