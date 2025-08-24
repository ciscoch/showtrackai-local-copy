// lib/models/location_weather.dart
// Minimal models for location and weather - no plugins required

class LocationData {
  final String? locationName;
  
  const LocationData({this.locationName});
  
  bool get hasLocation => locationName != null && locationName!.isNotEmpty;
  
  @override
  String toString() => locationName ?? 'No location set';
}

class WeatherData {
  final double? tempC;
  final String? description;
  
  const WeatherData({this.tempC, this.description});
  
  bool get hasWeather => tempC != null || description != null;
  
  String get temperatureDisplay => tempC != null ? '${tempC!.toStringAsFixed(1)}°C' : '';
  
  @override
  String toString() => description ?? 'No weather data';
}
