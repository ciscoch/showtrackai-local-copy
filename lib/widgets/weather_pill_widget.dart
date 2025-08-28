// lib/widgets/weather_pill_widget.dart
// Weather information display pill for journal entries

import 'package:flutter/material.dart';
import '../models/journal_entry.dart' show WeatherData;
import '../services/weather_service.dart';

class WeatherPillWidget extends StatelessWidget {
  final WeatherData? weatherData;
  final bool isLoading;
  final VoidCallback? onTap;
  final VoidCallback? onRefresh;
  final bool showRefreshButton;
  final bool isCompact;

  const WeatherPillWidget({
    super.key,
    this.weatherData,
    this.isLoading = false,
    this.onTap,
    this.onRefresh,
    this.showRefreshButton = true,
    this.isCompact = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        gradient: _getWeatherGradient(),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: onTap,
          child: Padding(
            padding: EdgeInsets.all(isCompact ? 8.0 : 12.0),
            child: isLoading ? _buildLoadingState() : _buildWeatherContent(),
          ),
        ),
      ),
    );
  }

  Widget _buildLoadingState() {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          width: 16,
          height: 16,
          child: CircularProgressIndicator(
            strokeWidth: 2,
            color: Colors.white,
          ),
        ),
        const SizedBox(width: 8),
        Text(
          'Loading weather...',
          style: TextStyle(
            color: Colors.white,
            fontSize: isCompact ? 12 : 14,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }

  Widget _buildWeatherContent() {
    if (weatherData == null) {
      return _buildNoWeatherState();
    }

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          _getWeatherIcon(),
          color: Colors.white,
          size: isCompact ? 16 : 20,
        ),
        const SizedBox(width: 8),
        Flexible(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                _getTemperatureText(),
                style: TextStyle(
                  color: Colors.white,
                  fontSize: isCompact ? 14 : 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
              if (!isCompact && weatherData!.description != null)
                Text(
                  weatherData!.description!,
                  style: const TextStyle(
                    color: Colors.white70,
                    fontSize: 12,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
            ],
          ),
        ),
        if (showRefreshButton && onRefresh != null) ...[
          const SizedBox(width: 8),
          IconButton(
            onPressed: onRefresh,
            icon: const Icon(
              Icons.refresh,
              color: Colors.white70,
              size: 16,
            ),
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(
              minWidth: 24,
              minHeight: 24,
            ),
            tooltip: 'Refresh weather',
          ),
        ],
      ],
    );
  }

  Widget _buildNoWeatherState() {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          Icons.cloud_off,
          color: Colors.white70,
          size: isCompact ? 16 : 20,
        ),
        const SizedBox(width: 8),
        Text(
          'Weather unavailable',
          style: TextStyle(
            color: Colors.white70,
            fontSize: isCompact ? 12 : 14,
          ),
        ),
        if (showRefreshButton && onRefresh != null) ...[
          const SizedBox(width: 8),
          IconButton(
            onPressed: onRefresh,
            icon: const Icon(
              Icons.refresh,
              color: Colors.white70,
              size: 16,
            ),
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(
              minWidth: 24,
              minHeight: 24,
            ),
            tooltip: 'Try again',
          ),
        ],
      ],
    );
  }

  String _getTemperatureText() {
    if (weatherData?.temperature == null) return '--°';
    return '${weatherData!.temperature!.round()}°F';
  }

  IconData _getWeatherIcon() {
    if (weatherData?.condition == null) return Icons.cloud;
    
    final condition = weatherData!.condition!.toLowerCase();
    
    if (condition.contains('clear') || condition.contains('sun')) {
      return Icons.wb_sunny;
    } else if (condition.contains('cloud')) {
      return Icons.cloud;
    } else if (condition.contains('rain') || condition.contains('drizzle')) {
      return Icons.grain;
    } else if (condition.contains('snow')) {
      return Icons.ac_unit;
    } else if (condition.contains('thunder') || condition.contains('storm')) {
      return Icons.flash_on;
    } else if (condition.contains('fog') || condition.contains('mist')) {
      return Icons.blur_on;
    } else {
      return Icons.cloud;
    }
  }

  LinearGradient _getWeatherGradient() {
    if (weatherData?.condition == null) {
      return const LinearGradient(
        colors: [Color(0xFF757575), Color(0xFF9E9E9E)],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      );
    }

    final condition = weatherData!.condition!.toLowerCase();
    
    if (condition.contains('clear') || condition.contains('sun')) {
      return const LinearGradient(
        colors: [Color(0xFFFF9800), Color(0xFFFFC107)],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      );
    } else if (condition.contains('rain') || condition.contains('drizzle')) {
      return const LinearGradient(
        colors: [Color(0xFF2196F3), Color(0xFF03A9F4)],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      );
    } else if (condition.contains('snow')) {
      return const LinearGradient(
        colors: [Color(0xFF9E9E9E), Color(0xFFE0E0E0)],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      );
    } else if (condition.contains('thunder') || condition.contains('storm')) {
      return const LinearGradient(
        colors: [Color(0xFF673AB7), Color(0xFF9C27B0)],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      );
    } else {
      // Cloudy/overcast
      return const LinearGradient(
        colors: [Color(0xFF607D8B), Color(0xFF78909C)],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      );
    }
  }

  /// Create a compact version for use in small spaces
  static Widget compact({
    WeatherData? weatherData,
    bool isLoading = false,
    VoidCallback? onTap,
    VoidCallback? onRefresh,
  }) {
    return WeatherPillWidget(
      weatherData: weatherData,
      isLoading: isLoading,
      onTap: onTap,
      onRefresh: onRefresh,
      isCompact: true,
      showRefreshButton: false,
    );
  }

  /// Create a detailed version with refresh capability
  static Widget detailed({
    WeatherData? weatherData,
    bool isLoading = false,
    VoidCallback? onTap,
    VoidCallback? onRefresh,
  }) {
    return WeatherPillWidget(
      weatherData: weatherData,
      isLoading: isLoading,
      onTap: onTap,
      onRefresh: onRefresh,
      isCompact: false,
      showRefreshButton: true,
    );
  }
}

/// Utility extension for weather service integration
extension WeatherPillHelper on WeatherService {
  Widget buildWeatherPill({
    WeatherData? weatherData,
    bool isLoading = false,
    VoidCallback? onRefresh,
    bool isCompact = false,
  }) {
    return WeatherPillWidget(
      weatherData: weatherData,
      isLoading: isLoading,
      onRefresh: onRefresh,
      isCompact: isCompact,
      onTap: weatherData != null
          ? () => debugPrint('Weather: ${getWeatherSummary(weatherData!)}')
          : null,
    );
  }
}