// lib/services/weather_service.dart
// Weather service for real weather data integration

import '../models/journal_entry.dart' show WeatherData;

class WeatherService {
  // TODO: Add real weather API configuration
  static const String? _apiKey = null; // Replace with real API key from environment
  static const String? _apiUrl = null; // Replace with real weather API URL
  
  /// Get weather by GPS coordinates
  /// Returns null if no weather API is configured or if API call fails
  Future<WeatherData?> getWeatherByLocation(double lat, double lon) async {
    if (_apiKey == null || _apiUrl == null) {
      print('Weather API not configured - weather data unavailable');
      return null;
    }
    
    try {
      // TODO: Implement real weather API call
      // Example implementation would go here:
      // final response = await http.get(Uri.parse('$_apiUrl?lat=$lat&lon=$lon&key=$_apiKey'));
      // Parse response and return WeatherData
      
      throw UnimplementedError('Real weather API integration not implemented yet');
    } catch (e) {
      print('Error fetching weather by location: $e');
      return null;
    }
  }
  
  /// Get weather by city name
  /// Returns null if no weather API is configured or if API call fails
  Future<WeatherData?> getWeatherByCityName(String cityName) async {
    if (_apiKey == null || _apiUrl == null) {
      print('Weather API not configured - weather data unavailable');
      return null;
    }
    
    try {
      // TODO: Implement real weather API call
      // Example implementation would go here:
      // final response = await http.get(Uri.parse('$_apiUrl?q=$cityName&key=$_apiKey'));
      // Parse response and return WeatherData
      
      throw UnimplementedError('Real weather API integration not implemented yet');
    } catch (e) {
      print('Error fetching weather by city: $e');
      return null;
    }
  }
  
  /// Get a compact weather description for display
  String getWeatherDescription(WeatherData? weather) {
    if (weather == null) {
      return 'Weather data not available';
    }
    
    final parts = <String>[];
    if (weather.temperature != null) {
      parts.add('${weather.temperature!.round()}°C');
    }
    if (weather.description != null) {
      parts.add(weather.description!);
    }
    
    return parts.isEmpty ? 'No weather data' : parts.join(' - ');
  }
  
  /// Get compact weather JSON for storage
  Map<String, dynamic> getCompactWeatherJson(WeatherData weather) {
    return {
      'temp': weather.temperature,
      'condition': weather.condition,
      'desc': weather.description,
      'humidity': weather.humidity,
      'wind': weather.windSpeed,
      'captured_at': DateTime.now().toIso8601String(),
    };
  }
  
  /// Create WeatherData from compact JSON
  WeatherData fromCompactJson(Map<String, dynamic> json) {
    return WeatherData(
      temperature: json['temp']?.toDouble(),
      condition: json['condition'],
      description: json['desc'],
      humidity: json['humidity'],
      windSpeed: json['wind']?.toDouble(),
    );
  }
  

}