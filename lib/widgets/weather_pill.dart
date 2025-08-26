// lib/widgets/weather_pill.dart
// Weather pill widget for displaying compact weather information

import 'package:flutter/material.dart';
import '../models/journal_entry.dart';

class WeatherPill extends StatelessWidget {
  final WeatherData weatherData;
  final bool compact;

  const WeatherPill({
    super.key,
    required this.weatherData,
    this.compact = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: compact ? 8 : 12,
        vertical: compact ? 4 : 6,
      ),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            _getWeatherColor(weatherData.condition).withOpacity(0.1),
            _getWeatherColor(weatherData.condition).withOpacity(0.05),
          ],
        ),
        borderRadius: BorderRadius.circular(compact ? 12 : 16),
        border: Border.all(
          color: _getWeatherColor(weatherData.condition).withOpacity(0.3),
          width: 1,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            _getWeatherIcon(weatherData.condition),
            size: compact ? 14 : 16,
            color: _getWeatherColor(weatherData.condition),
          ),
          const SizedBox(width: 6),
          Text(
            _buildWeatherText(),
            style: TextStyle(
              color: _getWeatherColor(weatherData.condition),
              fontSize: compact ? 11 : 12,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  String _buildWeatherText() {
    final parts = <String>[];
    
    // Temperature (always show if available)
    if (weatherData.temperature != null) {
      final temp = weatherData.temperature!;
      final fahrenheit = (temp * 9/5) + 32; // Convert to Fahrenheit for US agricultural context
      parts.add('${fahrenheit.round()}°F');
    }
    
    // Wind speed
    if (weatherData.windSpeed != null && weatherData.windSpeed! > 0) {
      parts.add('${weatherData.windSpeed!.round()}mph');
    }
    
    // Condition or description (prioritize condition as it's usually shorter)
    if (weatherData.condition != null && weatherData.condition!.isNotEmpty) {
      parts.add(_getShortCondition(weatherData.condition!));
    } else if (weatherData.description != null && weatherData.description!.isNotEmpty) {
      parts.add(_getShortCondition(weatherData.description!));
    }
    
    return parts.join(' • ');
  }

  String _getShortCondition(String condition) {
    // Convert long conditions to shorter versions for display
    final shortConditions = {
      'clear sky': 'Clear',
      'few clouds': 'Partly Cloudy',
      'scattered clouds': 'Cloudy',
      'broken clouds': 'Cloudy',
      'overcast clouds': 'Overcast',
      'light rain': 'Light Rain',
      'moderate rain': 'Rain',
      'heavy intensity rain': 'Heavy Rain',
      'thunderstorm': 'Storm',
      'snow': 'Snow',
      'mist': 'Misty',
      'fog': 'Foggy',
    };
    
    final lowerCondition = condition.toLowerCase();
    for (final entry in shortConditions.entries) {
      if (lowerCondition.contains(entry.key)) {
        return entry.value;
      }
    }
    
    // Return first word capitalized if no match found
    return condition.split(' ').first.toLowerCase().replaceRange(0, 1, condition[0].toUpperCase());
  }

  IconData _getWeatherIcon(String? condition) {
    if (condition == null) return Icons.wb_cloudy_outlined;
    
    final lowerCondition = condition.toLowerCase();
    
    if (lowerCondition.contains('clear') || lowerCondition.contains('sunny')) {
      return Icons.wb_sunny;
    } else if (lowerCondition.contains('cloud')) {
      if (lowerCondition.contains('few') || lowerCondition.contains('scattered')) {
        return Icons.wb_cloudy_outlined;
      } else {
        return Icons.cloud;
      }
    } else if (lowerCondition.contains('rain') || lowerCondition.contains('drizzle')) {
      return Icons.grain;
    } else if (lowerCondition.contains('thunder') || lowerCondition.contains('storm')) {
      return Icons.flash_on;
    } else if (lowerCondition.contains('snow')) {
      return Icons.ac_unit;
    } else if (lowerCondition.contains('fog') || lowerCondition.contains('mist')) {
      return Icons.blur_on;
    } else if (lowerCondition.contains('wind')) {
      return Icons.air;
    } else {
      return Icons.wb_cloudy_outlined;
    }
  }

  Color _getWeatherColor(String? condition) {
    if (condition == null) return Colors.blue.shade600;
    
    final lowerCondition = condition.toLowerCase();
    
    if (lowerCondition.contains('clear') || lowerCondition.contains('sunny')) {
      return Colors.orange.shade600;
    } else if (lowerCondition.contains('cloud')) {
      return Colors.blue.shade600;
    } else if (lowerCondition.contains('rain') || lowerCondition.contains('drizzle')) {
      return Colors.blue.shade800;
    } else if (lowerCondition.contains('thunder') || lowerCondition.contains('storm')) {
      return Colors.deepPurple.shade700;
    } else if (lowerCondition.contains('snow')) {
      return Colors.lightBlue.shade700;
    } else if (lowerCondition.contains('fog') || lowerCondition.contains('mist')) {
      return Colors.blueGrey.shade600;
    } else if (lowerCondition.contains('wind')) {
      return Colors.teal.shade600;
    } else {
      return Colors.blue.shade600;
    }
  }
}

/// Expanded weather pill that shows more detailed information
class WeatherPillExpanded extends StatelessWidget {
  final WeatherData weatherData;

  const WeatherPillExpanded({
    super.key,
    required this.weatherData,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            _getWeatherColor(weatherData.condition).withOpacity(0.1),
            _getWeatherColor(weatherData.condition).withOpacity(0.05),
          ],
        ),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: _getWeatherColor(weatherData.condition).withOpacity(0.3),
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                _getWeatherIcon(weatherData.condition),
                size: 24,
                color: _getWeatherColor(weatherData.condition),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  weatherData.description ?? weatherData.condition ?? 'Weather Recorded',
                  style: TextStyle(
                    color: _getWeatherColor(weatherData.condition),
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              if (weatherData.temperature != null) ...[
                _buildWeatherDetail(
                  Icons.thermostat,
                  'Temperature',
                  '${((weatherData.temperature! * 9/5) + 32).round()}°F (${weatherData.temperature!.round()}°C)',
                ),
                const SizedBox(width: 16),
              ],
              if (weatherData.windSpeed != null && weatherData.windSpeed! > 0) ...[
                _buildWeatherDetail(
                  Icons.air,
                  'Wind',
                  '${weatherData.windSpeed!.round()} mph',
                ),
                const SizedBox(width: 16),
              ],
              if (weatherData.humidity != null) ...[
                _buildWeatherDetail(
                  Icons.water_drop_outlined,
                  'Humidity',
                  '${weatherData.humidity}%',
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildWeatherDetail(IconData icon, String label, String value) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          icon,
          size: 16,
          color: _getWeatherColor(weatherData.condition).withOpacity(0.7),
        ),
        const SizedBox(width: 4),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: TextStyle(
                fontSize: 10,
                color: _getWeatherColor(weatherData.condition).withOpacity(0.7),
                fontWeight: FontWeight.w500,
              ),
            ),
            Text(
              value,
              style: TextStyle(
                fontSize: 12,
                color: _getWeatherColor(weatherData.condition),
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ],
    );
  }

  IconData _getWeatherIcon(String? condition) {
    if (condition == null) return Icons.wb_cloudy_outlined;
    
    final lowerCondition = condition.toLowerCase();
    
    if (lowerCondition.contains('clear') || lowerCondition.contains('sunny')) {
      return Icons.wb_sunny;
    } else if (lowerCondition.contains('cloud')) {
      if (lowerCondition.contains('few') || lowerCondition.contains('scattered')) {
        return Icons.wb_cloudy_outlined;
      } else {
        return Icons.cloud;
      }
    } else if (lowerCondition.contains('rain') || lowerCondition.contains('drizzle')) {
      return Icons.grain;
    } else if (lowerCondition.contains('thunder') || lowerCondition.contains('storm')) {
      return Icons.flash_on;
    } else if (lowerCondition.contains('snow')) {
      return Icons.ac_unit;
    } else if (lowerCondition.contains('fog') || lowerCondition.contains('mist')) {
      return Icons.blur_on;
    } else if (lowerCondition.contains('wind')) {
      return Icons.air;
    } else {
      return Icons.wb_cloudy_outlined;
    }
  }

  Color _getWeatherColor(String? condition) {
    if (condition == null) return Colors.blue.shade600;
    
    final lowerCondition = condition.toLowerCase();
    
    if (lowerCondition.contains('clear') || lowerCondition.contains('sunny')) {
      return Colors.orange.shade600;
    } else if (lowerCondition.contains('cloud')) {
      return Colors.blue.shade600;
    } else if (lowerCondition.contains('rain') || lowerCondition.contains('drizzle')) {
      return Colors.blue.shade800;
    } else if (lowerCondition.contains('thunder') || lowerCondition.contains('storm')) {
      return Colors.deepPurple.shade700;
    } else if (lowerCondition.contains('snow')) {
      return Colors.lightBlue.shade700;
    } else if (lowerCondition.contains('fog') || lowerCondition.contains('mist')) {
      return Colors.blueGrey.shade600;
    } else if (lowerCondition.contains('wind')) {
      return Colors.teal.shade600;
    } else {
      return Colors.blue.shade600;
    }
  }
}