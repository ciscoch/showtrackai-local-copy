import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';
import 'package:flutter/foundation.dart' show kIsWeb;

/// Service for handling location-based operations
/// Web-safe version that avoids permission_handler on web
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
        return false;
      }

      LocationPermission permission = await Geolocator.checkPermission();

      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          return false;
        }
      }

      if (permission == LocationPermission.deniedForever) {
        // On web, we can't open app settings
        if (!kIsWeb) {
          // Only use permission_handler on mobile platforms
          // This would require conditional import
        }
        return false;
      }

      return true;
    } catch (e) {
      print('Error checking location permission: $e');
      return false;
    }
  }

  /// Get current GPS location
  Future<Position?> getCurrentLocation() async {
    try {
      // Request permission first
      bool hasPermission = await requestLocationPermission();
      if (!hasPermission) {
        print('Location permission denied');
        return null;
      }

      // Get current position with timeout
      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
        timeLimit: const Duration(seconds: 10),
      );

      print('Location captured: ${position.latitude}, ${position.longitude}');
      return position;
    } catch (e) {
      print('Error getting current location: $e');
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
      print('Error getting address from coordinates: $e');
      return null;
    }
  }

  /// Check if location services are available
  Future<bool> isLocationServiceEnabled() async {
    try {
      return await Geolocator.isLocationServiceEnabled();
    } catch (e) {
      print('Error checking location service: $e');
      return false;
    }
  }

  /// Get current location permission status
  Future<LocationPermission> getPermissionStatus() async {
    try {
      return await Geolocator.checkPermission();
    } catch (e) {
      print('Error getting permission status: $e');
      return LocationPermission.denied;
    }
  }
}