import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:mockito/annotations.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:geolocator/geolocator.dart';

import '../../lib/services/weather_service.dart';
import '../../lib/models/location_weather.dart';
import 'weather_service_test.mocks.dart';

@GenerateMocks([
  http.Client,
  SharedPreferences,
])
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  
  group('WeatherService Tests', () {
    late MockClient mockHttpClient;
    late MockSharedPreferences mockPrefs;
    late WeatherService service;
    
    const String apiKey = 'test-api-key';
    const double testLat = 40.1234;
    const double testLon = -86.5678;
    const String testCity = 'West Lafayette';
    const String testState = 'IN';
    
    setUp(() {
      mockHttpClient = MockClient();
      mockPrefs = MockSharedPreferences();
      SharedPreferences.setMockInitialValues({});
      
      service = WeatherService(
        apiKey: apiKey,
        httpClient: mockHttpClient,
      );
      
      // Mock Geolocator permissions and services
      GeolocatorPlatform.instance = MockGeolocatorPlatform();
    });

    group('fetchWeatherByCoordinates', () {
      test('should fetch weather data successfully', () async {
        // Arrange
        final expectedWeatherData = _createMockWeatherResponse();
        
        when(mockHttpClient.get(
          argThat(allOf(
            contains('api.openweathermap.org'),
            contains('lat=$testLat'),
            contains('lon=$testLon'),
            contains('appid=$apiKey'),
          )),
        )).thenAnswer((_) async => http.Response(
          jsonEncode(expectedWeatherData),
          200,
        ));
        
        when(mockPrefs.setString(any, any)).thenAnswer((_) async => true);
        
        // Act
        final result = await service.fetchWeatherByCoordinates(testLat, testLon);
        
        // Assert
        expect(result, isNotNull);
        expect(result!.temperature, equals(72.5));
        expect(result.condition, equals('Clear'));
        expect(result.description, equals('clear sky'));
        expect(result.humidity, equals(65));
        expect(result.windSpeed, equals(5.2));
        expect(result.city, equals('West Lafayette'));
        
        // Verify caching
        verify(mockPrefs.setString(
          argThat(contains('weather_cache')),
          argThat(contains('"temperature":72.5')),
        )).called(1);
      });

      test('should return cached weather when API fails', () async {
        // Arrange
        final cachedWeather = LocationWeather(
          latitude: testLat,
          longitude: testLon,
          city: testCity,
          state: testState,
          temperature: 68.0,
          condition: 'Clouds',
          description: 'partly cloudy',
          humidity: 70,
          windSpeed: 3.5,
          timestamp: DateTime.now().subtract(const Duration(minutes: 30)),
        );
        
        when(mockHttpClient.get(any))
            .thenThrow(Exception('Network error'));
        
        when(mockPrefs.getString(argThat(contains('weather_cache'))))
            .thenReturn(jsonEncode(cachedWeather.toJson()));
        
        // Act
        final result = await service.fetchWeatherByCoordinates(testLat, testLon);
        
        // Assert
        expect(result, isNotNull);
        expect(result!.temperature, equals(68.0));
        expect(result.condition, equals('Clouds'));
        
        // Verify cache was checked
        verify(mockPrefs.getString(argThat(contains('weather_cache')))).called(1);
      });

      test('should handle invalid API response gracefully', () async {
        // Arrange
        when(mockHttpClient.get(any))
            .thenAnswer((_) async => http.Response('Invalid JSON', 200));
        
        when(mockPrefs.getString(any)).thenReturn(null);
        
        // Act
        final result = await service.fetchWeatherByCoordinates(testLat, testLon);
        
        // Assert
        expect(result, isNull);
      });

      test('should respect cache expiration time', () async {
        // Arrange
        final oldCachedWeather = LocationWeather(
          latitude: testLat,
          longitude: testLon,
          city: testCity,
          state: testState,
          temperature: 68.0,
          condition: 'Clouds',
          description: 'partly cloudy',
          humidity: 70,
          windSpeed: 3.5,
          timestamp: DateTime.now().subtract(const Duration(hours: 2)), // Old cache
        );
        
        final newWeatherData = _createMockWeatherResponse();
        
        when(mockPrefs.getString(argThat(contains('weather_cache'))))
            .thenReturn(jsonEncode(oldCachedWeather.toJson()));
        
        when(mockHttpClient.get(any))
            .thenAnswer((_) async => http.Response(jsonEncode(newWeatherData), 200));
        
        when(mockPrefs.setString(any, any)).thenAnswer((_) async => true);
        
        // Act
        final result = await service.fetchWeatherByCoordinates(
          testLat, 
          testLon,
          maxCacheAge: const Duration(hours: 1),
        );
        
        // Assert
        expect(result, isNotNull);
        expect(result!.temperature, equals(72.5)); // New data, not cached
        
        // Verify API was called despite cache existing
        verify(mockHttpClient.get(any)).called(1);
      });

      test('should handle API rate limiting', () async {
        // Arrange
        when(mockHttpClient.get(any))
            .thenAnswer((_) async => http.Response(
              jsonEncode({'cod': 429, 'message': 'Too many requests'}),
              429,
            ));
        
        when(mockPrefs.getString(any)).thenReturn(null);
        
        // Act
        final result = await service.fetchWeatherByCoordinates(testLat, testLon);
        
        // Assert
        expect(result, isNull);
        
        // Could also verify rate limit handling logic if implemented
      });
    });

    group('fetchWeatherByCity', () {
      test('should fetch weather by city and state', () async {
        // Arrange
        final expectedWeatherData = _createMockWeatherResponse();
        
        when(mockHttpClient.get(
          argThat(allOf(
            contains('api.openweathermap.org'),
            contains('q=$testCity,$testState,US'),
            contains('appid=$apiKey'),
          )),
        )).thenAnswer((_) async => http.Response(
          jsonEncode(expectedWeatherData),
          200,
        ));
        
        when(mockPrefs.setString(any, any)).thenAnswer((_) async => true);
        
        // Act
        final result = await service.fetchWeatherByCity(testCity, testState);
        
        // Assert
        expect(result, isNotNull);
        expect(result!.city, equals('West Lafayette'));
        expect(result.temperature, equals(72.5));
      });

      test('should handle city not found error', () async {
        // Arrange
        when(mockHttpClient.get(any))
            .thenAnswer((_) async => http.Response(
              jsonEncode({'cod': '404', 'message': 'city not found'}),
              404,
            ));
        
        when(mockPrefs.getString(any)).thenReturn(null);
        
        // Act
        final result = await service.fetchWeatherByCity('NonexistentCity', 'XX');
        
        // Assert
        expect(result, isNull);
      });

      test('should sanitize city names with special characters', () async {
        // Arrange
        final expectedWeatherData = _createMockWeatherResponse();
        
        when(mockHttpClient.get(any))
            .thenAnswer((_) async => http.Response(
              jsonEncode(expectedWeatherData),
              200,
            ));
        
        when(mockPrefs.setString(any, any)).thenAnswer((_) async => true);
        
        // Act
        await service.fetchWeatherByCity("O'Fallon", 'IL');
        
        // Assert
        verify(mockHttpClient.get(
          argThat(contains(Uri.encodeComponent("O'Fallon"))),
        )).called(1);
      });
    });

    group('getCurrentLocationWeather', () {
      test('should get weather for current location', () async {
        // Arrange
        final mockPosition = Position(
          latitude: testLat,
          longitude: testLon,
          timestamp: DateTime.now(),
          accuracy: 10.0,
          altitude: 100.0,
          heading: 0.0,
          speed: 0.0,
          speedAccuracy: 0.0,
          altitudeAccuracy: 0.0,
          headingAccuracy: 0.0,
        );
        
        final expectedWeatherData = _createMockWeatherResponse();
        
        // Mock location permission and service
        when(MockGeolocatorPlatform.checkPermission())
            .thenAnswer((_) async => LocationPermission.whileInUse);
        
        when(MockGeolocatorPlatform.isLocationServiceEnabled())
            .thenAnswer((_) async => true);
        
        when(MockGeolocatorPlatform.getCurrentPosition(any))
            .thenAnswer((_) async => mockPosition);
        
        when(mockHttpClient.get(any))
            .thenAnswer((_) async => http.Response(
              jsonEncode(expectedWeatherData),
              200,
            ));
        
        when(mockPrefs.setString(any, any)).thenAnswer((_) async => true);
        
        // Act
        final result = await service.getCurrentLocationWeather();
        
        // Assert
        expect(result, isNotNull);
        expect(result!.latitude, equals(testLat));
        expect(result.longitude, equals(testLon));
        expect(result.temperature, equals(72.5));
      });

      test('should handle location permission denied', () async {
        // Arrange
        when(MockGeolocatorPlatform.checkPermission())
            .thenAnswer((_) async => LocationPermission.denied);
        
        when(MockGeolocatorPlatform.requestPermission())
            .thenAnswer((_) async => LocationPermission.denied);
        
        // Act
        final result = await service.getCurrentLocationWeather();
        
        // Assert
        expect(result, isNull);
        
        // Verify no API call was made
        verifyNever(mockHttpClient.get(any));
      });

      test('should handle location service disabled', () async {
        // Arrange
        when(MockGeolocatorPlatform.checkPermission())
            .thenAnswer((_) async => LocationPermission.whileInUse);
        
        when(MockGeolocatorPlatform.isLocationServiceEnabled())
            .thenAnswer((_) async => false);
        
        // Act
        final result = await service.getCurrentLocationWeather();
        
        // Assert
        expect(result, isNull);
        
        // Verify no API call was made
        verifyNever(mockHttpClient.get(any));
      });

      test('should handle location timeout', () async {
        // Arrange
        when(MockGeolocatorPlatform.checkPermission())
            .thenAnswer((_) async => LocationPermission.whileInUse);
        
        when(MockGeolocatorPlatform.isLocationServiceEnabled())
            .thenAnswer((_) async => true);
        
        when(MockGeolocatorPlatform.getCurrentPosition(any))
            .thenAnswer((_) => Future.delayed(
              const Duration(seconds: 35),
              () => throw TimeoutException('Location timeout'),
            ));
        
        // Act
        final result = await service.getCurrentLocationWeather(
          locationTimeout: const Duration(seconds: 5),
        );
        
        // Assert
        expect(result, isNull);
      });
    });

    group('Weather Data Formatting', () {
      test('should format temperature correctly for display', () async {
        // Arrange
        final weather = LocationWeather(
          latitude: testLat,
          longitude: testLon,
          city: testCity,
          state: testState,
          temperature: 72.456789,
          condition: 'Clear',
          description: 'clear sky',
          humidity: 65,
          windSpeed: 5.2,
          timestamp: DateTime.now(),
        );
        
        // Act
        final formatted = service.formatWeatherForDisplay(weather);
        
        // Assert
        expect(formatted['temperature'], equals('72.5°F'));
        expect(formatted['humidity'], equals('65%'));
        expect(formatted['windSpeed'], equals('5.2 mph'));
        expect(formatted['condition'], equals('Clear'));
      });

      test('should convert temperature units', () async {
        // Act
        final celsius = service.fahrenheitToCelsius(72.0);
        final fahrenheit = service.celsiusToFahrenheit(22.22);
        
        // Assert
        expect(celsius.toStringAsFixed(1), equals('22.2'));
        expect(fahrenheit.toStringAsFixed(1), equals('72.0'));
      });

      test('should generate weather icon based on condition', () async {
        // Act
        final clearIcon = service.getWeatherIcon('Clear');
        final rainIcon = service.getWeatherIcon('Rain');
        final snowIcon = service.getWeatherIcon('Snow');
        final cloudsIcon = service.getWeatherIcon('Clouds');
        final unknownIcon = service.getWeatherIcon('Unknown');
        
        // Assert
        expect(clearIcon, equals('☀️'));
        expect(rainIcon, equals('🌧️'));
        expect(snowIcon, equals('❄️'));
        expect(cloudsIcon, equals('☁️'));
        expect(unknownIcon, equals('🌤️'));
      });
    });

    group('Batch Weather Fetching', () {
      test('should fetch weather for multiple locations', () async {
        // Arrange
        final locations = [
          {'lat': 40.0, 'lon': -86.0},
          {'lat': 41.0, 'lon': -87.0},
          {'lat': 42.0, 'lon': -88.0},
        ];
        
        when(mockHttpClient.get(any))
            .thenAnswer((_) async => http.Response(
              jsonEncode(_createMockWeatherResponse()),
              200,
            ));
        
        when(mockPrefs.setString(any, any)).thenAnswer((_) async => true);
        
        // Act
        final results = await service.fetchBatchWeather(locations);
        
        // Assert
        expect(results, hasLength(3));
        verify(mockHttpClient.get(any)).called(3);
      });

      test('should handle partial batch failures', () async {
        // Arrange
        final locations = [
          {'lat': 40.0, 'lon': -86.0},
          {'lat': 41.0, 'lon': -87.0},
        ];
        
        // First succeeds, second fails
        when(mockHttpClient.get(any))
            .thenAnswer((_) async => http.Response(
              jsonEncode(_createMockWeatherResponse()),
              200,
            ))
            .thenAnswer((_) async => http.Response('Error', 500));
        
        when(mockPrefs.setString(any, any)).thenAnswer((_) async => true);
        when(mockPrefs.getString(any)).thenReturn(null);
        
        // Act
        final results = await service.fetchBatchWeather(locations);
        
        // Assert
        expect(results, hasLength(2));
        expect(results[0], isNotNull);
        expect(results[1], isNull);
      });
    });

    group('Weather Alerts', () {
      test('should identify severe weather conditions', () async {
        // Arrange
        final severeWeather = LocationWeather(
          latitude: testLat,
          longitude: testLon,
          city: testCity,
          state: testState,
          temperature: 95.0,
          condition: 'Thunderstorm',
          description: 'heavy thunderstorm',
          humidity: 90,
          windSpeed: 35.0,
          timestamp: DateTime.now(),
        );
        
        // Act
        final alerts = service.checkForWeatherAlerts(severeWeather);
        
        // Assert
        expect(alerts, isNotEmpty);
        expect(alerts, contains('High temperature warning'));
        expect(alerts, contains('Severe weather alert'));
        expect(alerts, contains('High wind warning'));
      });

      test('should not generate alerts for normal weather', () async {
        // Arrange
        final normalWeather = LocationWeather(
          latitude: testLat,
          longitude: testLon,
          city: testCity,
          state: testState,
          temperature: 72.0,
          condition: 'Clear',
          description: 'clear sky',
          humidity: 50,
          windSpeed: 5.0,
          timestamp: DateTime.now(),
        );
        
        // Act
        final alerts = service.checkForWeatherAlerts(normalWeather);
        
        // Assert
        expect(alerts, isEmpty);
      });
    });
  });
}

// Helper functions
Map<String, dynamic> _createMockWeatherResponse() {
  return {
    'coord': {
      'lon': -86.5678,
      'lat': 40.1234,
    },
    'weather': [
      {
        'id': 800,
        'main': 'Clear',
        'description': 'clear sky',
        'icon': '01d',
      }
    ],
    'main': {
      'temp': 295.65, // Kelvin (72.5°F)
      'feels_like': 295.65,
      'temp_min': 294.15,
      'temp_max': 297.15,
      'pressure': 1013,
      'humidity': 65,
    },
    'wind': {
      'speed': 5.2,
      'deg': 180,
    },
    'clouds': {
      'all': 0,
    },
    'dt': 1643723400,
    'sys': {
      'country': 'US',
      'sunrise': 1643709600,
      'sunset': 1643745600,
    },
    'timezone': -18000,
    'id': 4926563,
    'name': 'West Lafayette',
    'cod': 200,
  };
}

// Mock Geolocator Platform
class MockGeolocatorPlatform extends Mock implements GeolocatorPlatform {
  static LocationPermission _permission = LocationPermission.denied;
  static bool _serviceEnabled = true;
  static Position? _position;
  
  static Future<LocationPermission> checkPermission() async => _permission;
  
  static Future<LocationPermission> requestPermission() async => _permission;
  
  static Future<bool> isLocationServiceEnabled() async => _serviceEnabled;
  
  static Future<Position> getCurrentPosition(LocationSettings? settings) async {
    if (_position != null) return _position!;
    throw Exception('No position available');
  }
}