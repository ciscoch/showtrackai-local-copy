// lib/services/weather_service.dart
// Weather service for real weather data integration with API support

import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import '../models/journal_entry.dart' show WeatherData;

class WeatherService {
  // Weather API Configuration - supports multiple providers
  static const String? _openWeatherApiKey = String.fromEnvironment('OPENWEATHER_API_KEY');
  static const String? _weatherApiKey = String.fromEnvironment('WEATHERAPI_KEY');
  static const String _openWeatherBaseUrl = 'https://api.openweathermap.org/data/2.5';
  static const String _weatherApiBaseUrl = 'https://api.weatherapi.com/v1';
  
  // IP-based location service for fallback weather
  static const String _ipGeolocationUrl = 'https://ipapi.co/json/';
  
  /// Get weather by GPS coordinates using OpenWeatherMap API
  Future<WeatherData?> getWeatherByLocation(double lat, double lon) async {
    if (_openWeatherApiKey != null && _openWeatherApiKey!.isNotEmpty) {
      return await _getOpenWeatherByCoordinates(lat, lon);
    } else if (_weatherApiKey != null && _weatherApiKey!.isNotEmpty) {
      return await _getWeatherApiByCoordinates(lat, lon);
    }
    
    print('No weather API key configured - using fallback weather generation');
    return _generateFallbackWeather(lat, lon);
  }
  
  /// Get weather by city name
  Future<WeatherData?> getWeatherByCityName(String cityName) async {
    if (_openWeatherApiKey != null && _openWeatherApiKey!.isNotEmpty) {
      return await _getOpenWeatherByCity(cityName);
    } else if (_weatherApiKey != null && _weatherApiKey!.isNotEmpty) {
      return await _getWeatherApiByCity(cityName);
    }
    
    print('No weather API key configured - using fallback weather for $cityName');
    return _generateFallbackWeatherForCity(cityName);
  }
  
  /// Get weather automatically by IP location (fallback method)
  Future<WeatherData?> getWeatherByIP() async {
    try {
      // Get location from IP
      final ipResponse = await http.get(
        Uri.parse(_ipGeolocationUrl),
        headers: {'User-Agent': 'ShowTrackAI/1.0'},
      ).timeout(const Duration(seconds: 10));
      
      if (ipResponse.statusCode == 200) {
        final ipData = json.decode(ipResponse.body);
        final latitude = double.tryParse(ipData['latitude'].toString());
        final longitude = double.tryParse(ipData['longitude'].toString());
        final city = ipData['city'] ?? 'Unknown';
        
        if (latitude != null && longitude != null) {
          final weather = await getWeatherByLocation(latitude, longitude);
          return weather;
        } else if (city != 'Unknown') {
          return await getWeatherByCityName(city);
        }
      }
    } catch (e) {
      print('IP-based weather lookup failed: $e');
    }
    
    return _generateGenericFallbackWeather();
  }
  
  /// OpenWeatherMap API implementation
  Future<WeatherData?> _getOpenWeatherByCoordinates(double lat, double lon) async {
    try {
      final url = '$_openWeatherBaseUrl/weather?lat=$lat&lon=$lon&appid=$_openWeatherApiKey&units=imperial';
      final response = await http.get(
        Uri.parse(url),
        headers: {'User-Agent': 'ShowTrackAI/1.0'},
      ).timeout(const Duration(seconds: 15));
      
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return _parseOpenWeatherResponse(data);
      } else {
        print('OpenWeatherMap API error: ${response.statusCode} - ${response.body}');
      }
    } catch (e) {
      print('OpenWeatherMap API request failed: $e');
    }
    
    return null;
  }
  
  Future<WeatherData?> _getOpenWeatherByCity(String cityName) async {
    try {
      final url = '$_openWeatherBaseUrl/weather?q=$cityName&appid=$_openWeatherApiKey&units=imperial';
      final response = await http.get(
        Uri.parse(url),
        headers: {'User-Agent': 'ShowTrackAI/1.0'},
      ).timeout(const Duration(seconds: 15));
      
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return _parseOpenWeatherResponse(data);
      } else {
        print('OpenWeatherMap city lookup error: ${response.statusCode} - ${response.body}');
      }
    } catch (e) {
      print('OpenWeatherMap city request failed: $e');
    }
    
    return null;
  }
  
  /// WeatherAPI implementation (alternative provider)
  Future<WeatherData?> _getWeatherApiByCoordinates(double lat, double lon) async {
    try {
      final url = '$_weatherApiBaseUrl/current.json?key=$_weatherApiKey&q=$lat,$lon&aqi=no';
      final response = await http.get(
        Uri.parse(url),
        headers: {'User-Agent': 'ShowTrackAI/1.0'},
      ).timeout(const Duration(seconds: 15));
      
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return _parseWeatherApiResponse(data);
      } else {
        print('WeatherAPI error: ${response.statusCode} - ${response.body}');
      }
    } catch (e) {
      print('WeatherAPI request failed: $e');
    }
    
    return null;
  }
  
  Future<WeatherData?> _getWeatherApiByCity(String cityName) async {
    try {
      final url = '$_weatherApiBaseUrl/current.json?key=$_weatherApiKey&q=$cityName&aqi=no';
      final response = await http.get(
        Uri.parse(url),
        headers: {'User-Agent': 'ShowTrackAI/1.0'},
      ).timeout(const Duration(seconds: 15));
      
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return _parseWeatherApiResponse(data);
      } else {
        print('WeatherAPI city lookup error: ${response.statusCode} - ${response.body}');
      }
    } catch (e) {
      print('WeatherAPI city request failed: $e');
    }
    
    return null;
  }
  
  /// Parse OpenWeatherMap API response
  WeatherData _parseOpenWeatherResponse(Map<String, dynamic> data) {
    final main = data['main'] ?? {};
    final weather = (data['weather'] as List?)?.first ?? {};
    final wind = data['wind'] ?? {};
    
    return WeatherData(
      temperature: (main['temp'] as num?)?.toDouble(),
      condition: weather['main']?.toString(),
      description: weather['description']?.toString(),
      humidity: main['humidity'] as int?,
      windSpeed: (wind['speed'] as num?)?.toDouble(),
    );
  }
  
  /// Parse WeatherAPI response
  WeatherData _parseWeatherApiResponse(Map<String, dynamic> data) {
    final current = data['current'] ?? {};
    final condition = current['condition'] ?? {};
    
    return WeatherData(
      temperature: (current['temp_f'] as num?)?.toDouble(),
      condition: condition['text']?.toString(),
      description: condition['text']?.toString(),
      humidity: current['humidity'] as int?,
      windSpeed: (current['wind_mph'] as num?)?.toDouble(),
    );
  }
  
  /// Generate realistic fallback weather based on coordinates and season
  WeatherData _generateFallbackWeather(double lat, double lon) {
    final now = DateTime.now();
    final month = now.month;
    final hour = now.hour;
    
    // Determine season and rough climate zone
    final isWinter = month == 12 || month == 1 || month == 2;
    final isSummer = month == 6 || month == 7 || month == 8;
    final isNorthern = lat > 0;
    
    // Generate temperature based on season and location
    double baseTemp;
    if (isWinter && isNorthern) {
      baseTemp = 35 + (lat.abs() / 90) * 20; // Colder in north
    } else if (isSummer && isNorthern) {
      baseTemp = 75 + (90 - lat.abs()) / 90 * 15; // Warmer in south
    } else {
      baseTemp = 60; // Spring/fall default
    }
    
    // Add daily temperature variation
    final tempVariation = 10 * (0.5 - (hour - 14).abs() / 24);
    final temperature = baseTemp + tempVariation + (DateTime.now().millisecond % 10 - 5);
    
    // Generate conditions based on temperature and season
    final conditions = _getSeasonalConditions(temperature, month);
    final selectedCondition = conditions[DateTime.now().second % conditions.length];
    
    return WeatherData(
      temperature: temperature,
      condition: selectedCondition['condition'],
      description: selectedCondition['description'],
      humidity: 45 + (DateTime.now().minute % 40),
      windSpeed: 5.0 + (DateTime.now().second % 10),
    );
  }
  
  /// Generate fallback weather for specific cities
  WeatherData _generateFallbackWeatherForCity(String cityName) {
    // Common city coordinates for better weather simulation
    final cityCoords = {
      'denver': [39.7392, -104.9903],
      'chicago': [41.8781, -87.6298],
      'houston': [29.7604, -95.3698],
      'phoenix': [33.4484, -112.0740],
      'los angeles': [34.0522, -118.2437],
      'new york': [40.7128, -74.0060],
      'miami': [25.7617, -80.1918],
    };
    
    final normalizedCity = cityName.toLowerCase();
    final coords = cityCoords[normalizedCity] ?? [39.0, -98.0]; // US geographic center
    
    return _generateFallbackWeather(coords[0], coords[1]);
  }
  
  /// Generate generic fallback weather when all else fails
  WeatherData _generateGenericFallbackWeather() {
    return _generateFallbackWeather(39.0, -98.0); // Geographic center of US
  }
  
  /// Get seasonal weather conditions for realistic fallback
  List<Map<String, String>> _getSeasonalConditions(double temperature, int month) {
    if (temperature < 32) {
      return [
        {'condition': 'Snow', 'description': 'Light snow'},
        {'condition': 'Clouds', 'description': 'Overcast'},
        {'condition': 'Clear', 'description': 'Cold and clear'},
      ];
    } else if (temperature < 50) {
      return [
        {'condition': 'Clouds', 'description': 'Partly cloudy'},
        {'condition': 'Clear', 'description': 'Cool and clear'},
        {'condition': 'Rain', 'description': 'Light rain'},
      ];
    } else if (temperature < 75) {
      return [
        {'condition': 'Clear', 'description': 'Pleasant weather'},
        {'condition': 'Clouds', 'description': 'Partly cloudy'},
        {'condition': 'Rain', 'description': 'Scattered showers'},
      ];
    } else {
      return [
        {'condition': 'Clear', 'description': 'Hot and sunny'},
        {'condition': 'Clouds', 'description': 'Hot and humid'},
        {'condition': 'Thunderstorm', 'description': 'Afternoon thunderstorms'},
      ];
    }
  }
  
  /// Get a compact weather description for display
  String getWeatherDescription(WeatherData? weather) {
    if (weather == null) {
      return 'Weather data not available';
    }
    
    final parts = <String>[];
    if (weather.temperature != null) {
      parts.add('${weather.temperature!.round()}°F');
    }
    if (weather.description != null) {
      parts.add(weather.description!);
    }
    
    return parts.isEmpty ? 'No weather data' : parts.join(' - ');
  }
  
  /// Get weather summary with additional details
  String getWeatherSummary(WeatherData weather) {
    final parts = <String>[];
    
    if (weather.temperature != null) {
      parts.add('${weather.temperature!.round()}°F');
    }
    
    if (weather.description != null) {
      parts.add(weather.description!);
    }
    
    final details = <String>[];
    if (weather.humidity != null) {
      details.add('Humidity: ${weather.humidity}%');
    }
    if (weather.windSpeed != null) {
      details.add('Wind: ${weather.windSpeed!.toStringAsFixed(1)} mph');
    }
    
    final summary = parts.join(' - ');
    final detailsText = details.isEmpty ? '' : ' (${details.join(', ')})';
    
    return summary + detailsText;
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
  
  /// Check if weather API is configured
  bool get isApiConfigured {
    return (_openWeatherApiKey != null && _openWeatherApiKey!.isNotEmpty) ||
           (_weatherApiKey != null && _weatherApiKey!.isNotEmpty);
  }
  
  /// Get configuration status for debugging
  String get configurationStatus {
    final hasOpenWeather = _openWeatherApiKey != null && _openWeatherApiKey!.isNotEmpty;
    final hasWeatherApi = _weatherApiKey != null && _weatherApiKey!.isNotEmpty;
    
    if (hasOpenWeather && hasWeatherApi) {
      return 'Both OpenWeatherMap and WeatherAPI configured';
    } else if (hasOpenWeather) {
      return 'OpenWeatherMap API configured';
    } else if (hasWeatherApi) {
      return 'WeatherAPI configured';
    } else {
      return 'No weather API configured - using fallback weather generation';
    }
  }
}