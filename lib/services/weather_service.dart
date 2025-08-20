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
  // Using environment variable - must be set in Netlify dashboard
  static const String _apiKey = String.fromEnvironment(
    'OPENWEATHER_API_KEY',
    defaultValue: '', // No hardcoded keys for security
  );
  static const String _baseUrl =
      'https://api.openweathermap.org/data/2.5/weather';

  // Cache configuration
  static const Duration _cacheDuration = Duration(minutes: 30);
  static const String _cachePrefix = 'weather_cache_';

  /// Check if weather service is available (has API key configured)
  bool get isAvailable => _apiKey.isNotEmpty;

  /// Fetch current weather data for given coordinates
  /// Returns WeatherData object with temperature, conditions, humidity
  /// Returns null if API key is not configured or service is unavailable
  Future<WeatherData?> getWeatherByLocation(
    double latitude,
    double longitude,
  ) async {
    try {
      print('🌤️ WeatherService: Getting weather for lat: $latitude, lon: $longitude');
      print('🔑 API Key available: $isAvailable (key length: ${_apiKey.length})');
      
      // Return null immediately if no API key is configured
      if (!isAvailable) {
        print('❌ Weather API key not configured. Weather data will not be available.');
        return null;
      }

      // Check cache first to reduce API calls
      final cached = await _getCachedWeather(latitude, longitude);
      if (cached != null) {
        print('📦 Using cached weather data: ${cached.temperature}°F, ${cached.conditions}');
        return cached;
      }

      // Fetch fresh data from API
      print('🌐 Fetching fresh weather data from API...');
      final weather = await _fetchWeatherFromAPI(latitude, longitude);

      if (weather != null) {
        print('✅ Weather fetched successfully: ${weather.temperature}°F, ${weather.conditions}');
        // Cache the result for future use
        await _cacheWeather(latitude, longitude, weather);
      } else {
        print('❌ Weather fetch returned null - API call failed');
      }

      return weather;
    } catch (e) {
      print('❌ Error getting weather: $e');
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
        '$_baseUrl?lat=$latitude&lon=$longitude&appid=$_apiKey&units=imperial',
      );

      print('🌐 API URL: $url');

      // Make HTTP request with timeout
      final response = await http.get(url).timeout(
        const Duration(seconds: 10),
        onTimeout: () {
          throw Exception('Weather API request timed out');
        },
      );

      print('📡 API Response: Status ${response.statusCode}');
      
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        print('📊 API Response Data: ${data.toString().substring(0, 200)}...');

        // Extract weather information from API response
        final weather = WeatherData(
          temperature: (data['main']['temp'] as num).toDouble(),
          conditions: data['weather'][0]['main'] ?? 'Unknown',
          humidity: (data['main']['humidity'] as num?)?.toDouble(),
          windSpeed: (data['wind']?['speed'] as num?)?.toDouble(),
          description: data['weather'][0]['description'] ?? data['weather'][0]['main'],
        );

        print('✅ Weather parsed: ${weather.temperature}°F, ${weather.conditions}');
        return weather;
      } else if (response.statusCode == 401) {
        print('❌ Invalid API key (401). Please configure a valid OpenWeatherMap API key.');
        print('Response body: ${response.body}');
        return null;
      } else {
        print('❌ Weather API error: ${response.statusCode}');
        print('Response body: ${response.body}');
        return null;
      }
    } catch (e) {
      print('❌ Error fetching weather from API: $e');
      return null;
    }
  }

  /// Get cached weather data if available and not expired
  Future<WeatherData?> _getCachedWeather(
    double latitude,
    double longitude,
  ) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final key =
          '$_cachePrefix${latitude.toStringAsFixed(2)}_${longitude.toStringAsFixed(2)}';
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
            windSpeed: (cacheData['windSpeed'] as num?)?.toDouble(),
            description: cacheData['description'],
          );
        } else {
          // Cache expired, remove it
          await prefs.remove(key);
        }
      }
    } catch (e) {
      // Error reading weather cache: $e
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
      final key =
          '$_cachePrefix${latitude.toStringAsFixed(2)}_${longitude.toStringAsFixed(2)}';

      final cacheData = {
        'timestamp': DateTime.now().toIso8601String(),
        'temperature': weather.temperature,
        'conditions': weather.conditions,
        'humidity': weather.humidity,
        'windSpeed': weather.windSpeed,
        'description': weather.description,
      };

      await prefs.setString(key, json.encode(cacheData));
      // Weather data cached
    } catch (e) {
      // Error caching weather data: $e
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

      // Weather cache cleared
    } catch (e) {
      // Error clearing weather cache: $e
    }
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
    final emoji = getWeatherEmoji(weather.conditions);

    String description =
        '$emoji ${weather.conditions} - ${weather.temperature.round()}°F';

    if (weather.humidity != null) {
      description += ' - ${weather.humidity!.round()}% humidity';
    }

    return description;
  }
}
