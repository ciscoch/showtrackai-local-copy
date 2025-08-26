// lib/services/weather_service.dart
// Enhanced weather service with mock data for demo purposes

import 'dart:math';
import '../models/journal_entry.dart' show WeatherData;

class WeatherService {
  static final Random _random = Random();
  
  /// Get weather by GPS coordinates with enhanced mock data
  Future<WeatherData?> getWeatherByLocation(double lat, double lon) async {
    // Simulate API delay
    await Future.delayed(const Duration(milliseconds: 1500));
    
    // Return mock weather data based on location
    return _generateMockWeatherForLocation(lat, lon);
  }
  
  /// Get weather by city name with enhanced mock data
  Future<WeatherData?> getWeatherByCityName(String cityName) async {
    // Simulate API delay
    await Future.delayed(const Duration(milliseconds: 1200));
    
    // Return mock weather data based on city
    return _generateMockWeatherForCity(cityName);
  }
  
  /// Generate mock weather based on GPS coordinates
  WeatherData _generateMockWeatherForLocation(double lat, double lon) {
    // Base temperature on latitude (rough approximation)
    final baseTemp = 30 - (lat.abs() * 0.5);
    final temperature = baseTemp + (_random.nextDouble() * 10 - 5);
    
    return _createWeatherData(temperature);
  }
  
  /// Generate mock weather based on city name
  WeatherData _generateMockWeatherForCity(String cityName) {
    // Mock temperatures for common cities
    final cityTemperatures = {
      'Denver': 18.0,
      'Phoenix': 28.0,
      'Seattle': 12.0,
      'Miami': 26.0,
      'Chicago': 8.0,
      'Austin': 22.0,
      'Portland': 14.0,
    };
    
    final baseTemp = cityTemperatures[cityName] ?? 20.0;
    final temperature = baseTemp + (_random.nextDouble() * 8 - 4);
    
    return _createWeatherData(temperature);
  }
  
  /// Create WeatherData with realistic values
  WeatherData _createWeatherData(double temperature) {
    final conditions = ['clear', 'partly_cloudy', 'cloudy', 'overcast', 'light_rain'];
    final descriptions = [
      'Clear skies',
      'Partly cloudy',
      'Mostly cloudy',
      'Overcast skies',
      'Light rain showers',
    ];
    
    final conditionIndex = _random.nextInt(conditions.length);
    final humidity = 30 + _random.nextInt(50); // 30-80%
    final windSpeed = 2.0 + (_random.nextDouble() * 15); // 2-17 mph
    
    return WeatherData(
      temperature: double.parse(temperature.toStringAsFixed(1)),
      condition: conditions[conditionIndex],
      humidity: humidity,
      windSpeed: double.parse(windSpeed.toStringAsFixed(1)),
      description: descriptions[conditionIndex],
    );
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
  
  /// Get default weather for testing
  WeatherData getDefaultMockWeather() {
    return WeatherData(
      temperature: 22.5,
      condition: 'partly_cloudy',
      humidity: 65,
      windSpeed: 8.5,
      description: 'Partly cloudy with light breeze',
    );
  }
}