// lib/models/location_weather.dart
class LocationData {
  final String? locationName;
  final double? latitude;
  final double? longitude;

  const LocationData({this.locationName, this.latitude, this.longitude});

  LocationData copyWith({String? locationName, double? latitude, double? longitude}) {
    return LocationData(
      locationName: locationName ?? this.locationName,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
    );
  }

  Map<String, dynamic> toJson() => {
    "locationName": locationName,
    "latitude": latitude,
    "longitude": longitude,
  };

  factory LocationData.fromJson(Map<String, dynamic> j) => LocationData(
    locationName: j["locationName"] as String?,
    latitude: (j["latitude"] as num?)?.toDouble(),
    longitude: (j["longitude"] as num?)?.toDouble(),
  );
}

class WeatherData {
  final double? tempC;       // use metric in your API call
  final int? humidity;       // %
  final double? windKph;
  final String? description; // e.g., "clear sky"
  final String? icon;        // API icon id
  final DateTime fetchedAt;

  WeatherData({
    this.tempC,
    this.humidity,
    this.windKph,
    this.description,
    this.icon,
    DateTime? fetchedAt,
  }) : fetchedAt = fetchedAt ?? DateTime.now();

  double? get tempF => tempC == null ? null : (tempC! * 9 / 5 + 32);

  Map<String, dynamic> toJson() => {
    "tempC": tempC,
    "humidity": humidity,
    "windKph": windKph,
    "description": description,
    "icon": icon,
    "fetchedAt": fetchedAt.toIso8601String(),
  };

  // Helper for OpenWeather (assuming &units=metric)
  factory WeatherData.fromOpenWeather(Map<String, dynamic> j) {
    final main = (j["main"] as Map?) ?? {};
    final wind = (j["wind"] as Map?) ?? {};
    final weatherList = (j["weather"] as List?) ?? const [];
    final w0 = weatherList.isNotEmpty ? (weatherList.first as Map) : const {};

    return WeatherData(
      tempC: (main["temp"] as num?)?.toDouble(),
      humidity: (main["humidity"] as num?)?.toInt(),
      windKph: (wind["speed"] as num?)?.toDouble(),
      description: w0["description"] as String?,
      icon: w0["icon"] as String?,
    );
  }
}
