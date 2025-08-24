// lib/widgets/location_input_field.dart
// Simple text-based location input - no GPS or permissions required

import 'package:flutter/material.dart';
import 'package:showtrackai_journaling/models/location_weather.dart';

class LocationInputField extends StatefulWidget {
  final void Function(LocationData?, WeatherData?) onLocationChanged;
  final LocationData? initialLocation;
  final WeatherData? initialWeather;

  const LocationInputField({
    super.key,
    required this.onLocationChanged,
    this.initialLocation,
    this.initialWeather,
  });

  @override
  State<LocationInputField> createState() => _LocationInputFieldState();
}

class _LocationInputFieldState extends State<LocationInputField> {
  LocationData? _currentLocation;
  WeatherData? _currentWeather; // stays null unless you later add a city-based fetch
  final _controller = TextEditingController();

  @override
  void initState() {
    super.initState();
    _currentLocation = widget.initialLocation;
    _currentWeather = widget.initialWeather;
    _controller.text = widget.initialLocation?.locationName ?? '';
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.all(12),
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                Icon(Icons.location_on, 
                  color: Theme.of(context).primaryColor,
                  size: 20,
                ),
                const SizedBox(width: 8),
                Text(
                  'Location (optional)', 
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _controller,
              decoration: InputDecoration(
                hintText: 'Enter city, farm, or ranch name',
                helperText: 'Manual entry only - no GPS tracking',
                prefixIcon: const Icon(Icons.edit_location, size: 20),
                border: const OutlineInputBorder(),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
                suffixIcon: _controller.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear, size: 20),
                        onPressed: () {
                          _controller.clear();
                          _currentLocation = null;
                          widget.onLocationChanged(_currentLocation, _currentWeather);
                          setState(() {});
                        },
                      )
                    : null,
              ),
              onChanged: (value) {
                _currentLocation = LocationData(
                  locationName: value.trim().isEmpty ? null : value.trim(),
                );
                widget.onLocationChanged(_currentLocation, _currentWeather);
                setState(() {});
              },
            ),
            if (_currentLocation?.hasLocation == true) ...[
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: Theme.of(context).primaryColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.check_circle,
                      size: 16,
                      color: Theme.of(context).primaryColor,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      'Location set: ${_currentLocation!.locationName}',
                      style: TextStyle(
                        fontSize: 12,
                        color: Theme.of(context).primaryColor,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}