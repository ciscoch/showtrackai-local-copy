// lib/test_weather_pill.dart
// Test file for WeatherPill widget functionality - FOR TESTING ONLY

import 'package:flutter/material.dart';
import 'models/journal_entry.dart';
import 'widgets/weather_pill.dart';

class TestWeatherPillPage extends StatelessWidget {
  const TestWeatherPillPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Weather Pill Test'),
        backgroundColor: Colors.green.shade600,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Weather Pill Examples',
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 20),
            
            // Test Case 1: Complete weather data
            const Text(
              'Complete Weather Data (Clear Day):',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 8),
            WeatherPill(
              weatherData: WeatherData(
                temperature: 22.0, // 72°F
                condition: 'clear sky',
                description: 'Clear sunny day',
                humidity: 45,
                windSpeed: 8.0,
              ),
              compact: true,
            ),
            const SizedBox(height: 8),
            WeatherPillExpanded(
              weatherData: WeatherData(
                temperature: 22.0,
                condition: 'clear sky',
                description: 'Clear sunny day',
                humidity: 45,
                windSpeed: 8.0,
              ),
            ),
            const SizedBox(height: 20),
            
            // Test Case 2: Rainy weather
            const Text(
              'Rainy Weather:',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 8),
            WeatherPill(
              weatherData: WeatherData(
                temperature: 15.0, // 59°F
                condition: 'light rain',
                description: 'Light rain showers',
                humidity: 85,
                windSpeed: 12.0,
              ),
              compact: true,
            ),
            const SizedBox(height: 8),
            WeatherPillExpanded(
              weatherData: WeatherData(
                temperature: 15.0,
                condition: 'light rain',
                description: 'Light rain showers',
                humidity: 85,
                windSpeed: 12.0,
              ),
            ),
            const SizedBox(height: 20),
            
            // Test Case 3: Cloudy weather
            const Text(
              'Cloudy Weather:',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 8),
            WeatherPill(
              weatherData: WeatherData(
                temperature: 18.0, // 64°F
                condition: 'scattered clouds',
                description: 'Partly cloudy',
                humidity: 60,
                windSpeed: 5.0,
              ),
              compact: true,
            ),
            const SizedBox(height: 8),
            WeatherPillExpanded(
              weatherData: WeatherData(
                temperature: 18.0,
                condition: 'scattered clouds',
                description: 'Partly cloudy',
                humidity: 60,
                windSpeed: 5.0,
              ),
            ),
            const SizedBox(height: 20),
            
            // Test Case 4: Minimal data (null safety test)
            const Text(
              'Minimal Weather Data (Null Safety Test):',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 8),
            WeatherPill(
              weatherData: WeatherData(
                temperature: 20.0,
                condition: null,
                description: null,
                humidity: null,
                windSpeed: null,
              ),
              compact: true,
            ),
            const SizedBox(height: 8),
            WeatherPillExpanded(
              weatherData: WeatherData(
                temperature: 20.0,
                condition: null,
                description: null,
                humidity: null,
                windSpeed: null,
              ),
            ),
            const SizedBox(height: 20),
            
            // Test Case 5: Only condition data
            const Text(
              'Condition Only:',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 8),
            WeatherPill(
              weatherData: WeatherData(
                temperature: null,
                condition: 'thunderstorm',
                description: 'Thunderstorms with heavy rain',
                humidity: null,
                windSpeed: null,
              ),
              compact: true,
            ),
            const SizedBox(height: 8),
            WeatherPillExpanded(
              weatherData: WeatherData(
                temperature: null,
                condition: 'thunderstorm',
                description: 'Thunderstorms with heavy rain',
                humidity: null,
                windSpeed: null,
              ),
            ),
            const SizedBox(height: 20),
            
            // Test Case 6: Very cold weather
            const Text(
              'Cold Weather (Winter):',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 8),
            WeatherPill(
              weatherData: WeatherData(
                temperature: -5.0, // 23°F
                condition: 'snow',
                description: 'Light snow',
                humidity: 95,
                windSpeed: 15.0,
              ),
              compact: true,
            ),
            const SizedBox(height: 8),
            WeatherPillExpanded(
              weatherData: WeatherData(
                temperature: -5.0,
                condition: 'snow',
                description: 'Light snow',
                humidity: 95,
                windSpeed: 15.0,
              ),
            ),
            const SizedBox(height: 20),
            
            // Test Case 7: Hot summer weather
            const Text(
              'Hot Summer Weather:',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 8),
            WeatherPill(
              weatherData: WeatherData(
                temperature: 35.0, // 95°F
                condition: 'clear sky',
                description: 'Hot and sunny',
                humidity: 30,
                windSpeed: 3.0,
              ),
              compact: true,
            ),
            const SizedBox(height: 8),
            WeatherPillExpanded(
              weatherData: WeatherData(
                temperature: 35.0,
                condition: 'clear sky',
                description: 'Hot and sunny',
                humidity: 30,
                windSpeed: 3.0,
              ),
            ),
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }
}

/// Helper function to add test button to any screen for quick access
Widget buildTestWeatherPillButton(BuildContext context) {
  return FloatingActionButton.extended(
    onPressed: () {
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (context) => const TestWeatherPillPage(),
        ),
      );
    },
    backgroundColor: Colors.blue.shade600,
    icon: const Icon(Icons.wb_cloudy),
    label: const Text('Test Weather'),
  );
}