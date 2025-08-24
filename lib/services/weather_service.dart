// lib/services/weather_service.dart
// Stub weather service - can be enhanced later with city-based queries

import '../models/location_weather.dart';

class WeatherService {
  // Stub: Previously used coordinates, now disabled
  Future<WeatherData?> getWeatherByLocation(double lat, double lon) async {
    // No longer using coordinates - return null
    return null;
  }
  
  // Future enhancement: Get weather by city name (no GPS required)
  Future<WeatherData?> getWeatherByCityName(String cityName) async {
    // TODO: Implement city-based weather lookup if needed
    // Example: Use OpenWeather API with q=cityName parameter
    // For now, return null to keep it simple
    return null;
  }
  
  // Get a simple weather description
  String getWeatherDescription(WeatherData? weather) {
    if (weather == null || !weather.hasWeather) {
      return 'Weather data not available';
    }
    
    final parts = <String>[];
    if (weather.tempC != null) {
      parts.add(weather.temperatureDisplay);
    }
    if (weather.description != null) {
      parts.add(weather.description!);
    }
    
    return parts.isEmpty ? 'No weather data' : parts.join(' - ');
  }
  
  // Mock weather for testing (optional)
  WeatherData getMockWeather() {
    return const WeatherData(
      tempC: 22.5,
      description: 'Partly cloudy',
    );
  }
}