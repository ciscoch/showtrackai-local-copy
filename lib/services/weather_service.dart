import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../models/journal_entry.dart';

/// Service for fetching weather data based on location
/// Uses OpenWeatherMap API with caching for efficiency
class WeatherService {
  static final WeatherService _instance = WeatherService._internal();
  factory WeatherService() => _instance;
  WeatherService._internal();

  // OpenWeatherMap API configuration
  // TODO: Move API key to environment variables for production
  static const String _apiKey = 'YOUR_OPENWEATHER_API_KEY';
  static const String _baseUrl = 'https://api.openweathermap.org/data/2.5/weather';
  
  // Cache configuration
  static const Duration _cacheDuration = Duration(minutes: 30);
  static const String _cachePrefix = 'weather_cache_';

  /// Fetch current weather data for given coordinates
  /// Returns WeatherData object with temperature, conditions, humidity
  Future<WeatherData?> getWeatherByLocation(
    double latitude,
    double longitude,
  ) async {
    try {
      // Check cache first to reduce API calls
      final cached = await _getCachedWeather(latitude, longitude);
      if (cached != null) {
        print('Using cached weather data');
        return cached;
      }

      // Fetch fresh data from API
      final weather = await _fetchWeatherFromAPI(latitude, longitude);
      
      if (weather != null) {
        // Cache the result for future use
        await _cacheWeather(latitude, longitude, weather);
      }
      
      return weather;
    } catch (e) {
      print('Error getting weather: $e');
      return null;
    }
  }

  /// Fetch weather data from OpenWeatherMap API
  Future<WeatherData?> _fetchWeatherFromAPI(
    double latitude,
    double longitude,
  ) async {
    try {
      // Build API URL with coordinates and units
      final url = Uri.parse(
        '$_baseUrl?lat=$latitude&lon=$longitude&appid=$_apiKey&units=metric',
      );
      
      print('Fetching weather from API: $url');
      
      // Make HTTP request with timeout
      final response = await http.get(url).timeout(
        const Duration(seconds: 10),
        onTimeout: () {
          throw Exception('Weather API request timed out');
        },
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        
        // Extract weather information from API response
        final weather = WeatherData(
          temperature: (data['main']['temp'] as num).toDouble(),
          conditions: data['weather'][0]['main'] ?? 'Unknown',
          humidity: (data['main']['humidity'] as num?)?.toDouble(),
        );
        
        print('Weather fetched: ${weather.temperature}°C, ${weather.conditions}');
        return weather;
      } else if (response.statusCode == 401) {
        print('Invalid API key. Please configure a valid OpenWeatherMap API key.');
        // Return mock data for testing when API key is not configured
        return _getMockWeatherData();
      } else {
        print('Weather API error: ${response.statusCode} - ${response.body}');
        return null;
      }
    } catch (e) {
      print('Error fetching weather from API: $e');
      // Return mock data for testing
      return _getMockWeatherData();
    }
  }

  /// Get cached weather data if available and not expired
  Future<WeatherData?> _getCachedWeather(
    double latitude,
    double longitude,
  ) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final key = '$_cachePrefix${latitude.toStringAsFixed(2)}_${longitude.toStringAsFixed(2)}';
      final cachedJson = prefs.getString(key);
      
      if (cachedJson != null) {
        final cacheData = json.decode(cachedJson);
        final timestamp = DateTime.parse(cacheData['timestamp']);
        
        // Check if cache is still valid
        if (DateTime.now().difference(timestamp) < _cacheDuration) {
          return WeatherData(
            temperature: (cacheData['temperature'] as num).toDouble(),
            conditions: cacheData['conditions'],
            humidity: (cacheData['humidity'] as num?)?.toDouble(),
          );
        } else {
          // Cache expired, remove it
          await prefs.remove(key);
        }
      }
    } catch (e) {
      print('Error reading weather cache: $e');
    }
    return null;
  }

  /// Cache weather data for future use
  Future<void> _cacheWeather(
    double latitude,
    double longitude,
    WeatherData weather,
  ) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final key = '$_cachePrefix${latitude.toStringAsFixed(2)}_${longitude.toStringAsFixed(2)}';
      
      final cacheData = {
        'timestamp': DateTime.now().toIso8601String(),
        'temperature': weather.temperature,
        'conditions': weather.conditions,
        'humidity': weather.humidity,
      };
      
      await prefs.setString(key, json.encode(cacheData));
      print('Weather data cached');
    } catch (e) {
      print('Error caching weather data: $e');
    }
  }

  /// Clear all cached weather data
  Future<void> clearWeatherCache() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final keys = prefs.getKeys().where((key) => key.startsWith(_cachePrefix));
      
      for (final key in keys) {
        await prefs.remove(key);
      }
      
      print('Weather cache cleared');
    } catch (e) {
      print('Error clearing weather cache: $e');
    }
  }

  /// Get mock weather data for testing without API
  /// Returns realistic weather data for development
  WeatherData _getMockWeatherData() {
    // Generate somewhat random but realistic weather
    final hour = DateTime.now().hour;
    final temp = 20.0 + (hour - 12).abs() * 0.5; // Temperature varies by time
    
    final conditions = [
      'Clear',
      'Clouds',
      'Rain',
      'Partly Cloudy',
    ];
    
    final condition = conditions[DateTime.now().minute % conditions.length];
    
    return WeatherData(
      temperature: temp,
      conditions: condition,
      humidity: 60.0 + (DateTime.now().minute % 30) - 15, // 45-75% humidity
    );
  }

  /// Convert weather condition to emoji for UI display
  String getWeatherEmoji(String condition) {
    switch (condition.toLowerCase()) {
      case 'clear':
        return '☀️';
      case 'clouds':
        return '☁️';
      case 'rain':
        return '🌧️';
      case 'drizzle':
        return '🌦️';
      case 'thunderstorm':
        return '⛈️';
      case 'snow':
        return '❄️';
      case 'mist':
      case 'fog':
        return '🌫️';
      default:
        return '🌤️';
    }
  }

  /// Get weather description in user-friendly format
  String getWeatherDescription(WeatherData weather) {
    final tempF = (weather.temperature * 9/5 + 32).round();
    final emoji = getWeatherEmoji(weather.conditions);
    
    String description = '$emoji ${weather.conditions} - ${weather.temperature.round()}°C / ${tempF}°F';
    
    if (weather.humidity != null) {
      description += ' - ${weather.humidity!.round()}% humidity';
    }
    
    return description;
  }
}