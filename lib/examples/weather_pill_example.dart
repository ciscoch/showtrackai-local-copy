// lib/examples/weather_pill_example.dart
// Example usage of WeatherPill widgets in ShowTrackAI

import 'package:flutter/material.dart';
import '../models/journal_entry.dart';
import '../widgets/weather_pill.dart';

class WeatherPillExamplePage extends StatelessWidget {
  const WeatherPillExamplePage({super.key});

  @override
  Widget build(BuildContext context) {
    // Sample weather data like what would come from a journal entry
    final sampleWeatherData = WeatherData(
      temperature: 22.2, // 72°F
      condition: 'clear sky',
      description: 'Clear and sunny',
      humidity: 45,
      windSpeed: 8.0,
    );

    return Scaffold(
      appBar: AppBar(
        title: const Text('Weather Pill Example'),
        backgroundColor: Colors.green.shade600,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Example of timeline card usage
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Daily Health Check - Holstein #247',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Performed comprehensive health assessment including temperature check, visual inspection, and feed evaluation.',
                    ),
                    const SizedBox(height: 12),
                    
                    // Weather pill in timeline context
                    WeatherPill(
                      weatherData: sampleWeatherData,
                      compact: true,
                    ),
                  ],
                ),
              ),
            ),
            
            const SizedBox(height: 24),
            
            // Example of expanded weather display
            const Text(
              'Expanded Weather View:',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            
            WeatherPillExpanded(weatherData: sampleWeatherData),
            
            const SizedBox(height: 24),
            
            // Show how it handles null data
            const Text(
              'Minimal Weather Data:',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            
            WeatherPill(
              weatherData: WeatherData(
                temperature: 18.0,
                condition: null,
                description: null,
                humidity: null,
                windSpeed: null,
              ),
              compact: true,
            ),
          ],
        ),
      ),
    );
  }
}