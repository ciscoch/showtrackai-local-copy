// lib/widgets/location_input_field.dart
import 'package:flutter/material.dart';
import 'package:your_package_name/models/location_weather.dart';

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
  WeatherData? _currentWeather;
  final _controller = TextEditingController();

  @override
  void initState() {
    super.initState();
    _currentLocation = widget.initialLocation;
    _currentWeather  = widget.initialWeather;
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
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Location', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            TextField(
              controller: _controller,
              decoration: const InputDecoration(
                hintText: 'Enter a location (city, ranch, etc.)',
                border: OutlineInputBorder(),
              ),
              onChanged: (value) {
                setState(() {
                  _currentLocation = LocationData(locationName: value);
                });
                widget.onLocationChanged(_currentLocation, _currentWeather);
              },
            ),
            if (_currentWeather != null) ...[
              const SizedBox(height: 8),
              Text(
                'Weather: ${_currentWeather!.description ?? ''}  '
                '${_currentWeather!.tempC?.toStringAsFixed(1) ?? '--'} °C',
              ),
            ],
          ],
        ),
      ),
    );
  }
}
