import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import '../services/location_service.dart';
import '../services/weather_service.dart';
import '../models/journal_entry.dart';

/// Widget for capturing and displaying location and weather data
/// Provides both automatic GPS capture and manual entry options
class LocationInputField extends StatefulWidget {
  final Function(LocationData?, WeatherData?) onLocationChanged;
  final LocationData? initialLocation;
  final WeatherData? initialWeather;

  const LocationInputField({
    Key? key,
    required this.onLocationChanged,
    this.initialLocation,
    this.initialWeather,
  }) : super(key: key);

  @override
  State<LocationInputField> createState() => _LocationInputFieldState();
}

class _LocationInputFieldState extends State<LocationInputField> {
  final LocationService _locationService = LocationService();
  final WeatherService _weatherService = WeatherService();
  final TextEditingController _manualLocationController = TextEditingController();
  
  LocationData? _currentLocation;
  WeatherData? _currentWeather;
  bool _isLoading = false;
  bool _useCurrentLocation = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _currentLocation = widget.initialLocation;
    _currentWeather = widget.initialWeather;
    if (_currentLocation != null) {
      _useCurrentLocation = true;
      _manualLocationController.text = _currentLocation!.locationName ?? '';
    }
  }

  /// Capture current GPS location and fetch weather
  Future<void> _getCurrentLocation() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      // Get GPS position
      final position = await _locationService.getCurrentLocation();
      
      if (position != null) {
        // Get human-readable address
        final address = await _locationService.getAddressFromCoordinates(
          position.latitude,
          position.longitude,
        );
        
        // Create location data object
        final locationData = LocationData(
          latitude: position.latitude,
          longitude: position.longitude,
          address: address,
          locationName: _manualLocationController.text.isNotEmpty 
            ? _manualLocationController.text 
            : null,
          accuracy: position.accuracy,
          capturedAt: DateTime.now(),
        );
        
        // Fetch weather for this location
        final weatherData = await _weatherService.getWeatherByLocation(
          position.latitude,
          position.longitude,
        );
        
        setState(() {
          _currentLocation = locationData;
          _currentWeather = weatherData;
          _useCurrentLocation = true;
        });
        
        // Notify parent widget of changes
        widget.onLocationChanged(locationData, weatherData);
      } else {
        setState(() {
          _errorMessage = 'Unable to get location. Please enable location services.';
        });
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'Error getting location: ${e.toString()}';
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  /// Clear location and weather data
  void _clearLocation() {
    setState(() {
      _currentLocation = null;
      _currentWeather = null;
      _useCurrentLocation = false;
      _manualLocationController.clear();
    });
    widget.onLocationChanged(null, null);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Location & Weather',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Icon(
                  Icons.location_on,
                  color: theme.primaryColor,
                ),
              ],
            ),
            const SizedBox(height: 16),
            
            // Location toggle and capture button
            Row(
              children: [
                Expanded(
                  child: SwitchListTile(
                    title: const Text('Use GPS location'),
                    subtitle: const Text('Capture current location'),
                    value: _useCurrentLocation,
                    onChanged: (bool value) {
                      setState(() {
                        _useCurrentLocation = value;
                      });
                      if (value) {
                        _getCurrentLocation();
                      } else {
                        _clearLocation();
                      }
                    },
                    contentPadding: EdgeInsets.zero,
                  ),
                ),
                if (_useCurrentLocation && !_isLoading)
                  IconButton(
                    icon: const Icon(Icons.refresh),
                    onPressed: _getCurrentLocation,
                    tooltip: 'Refresh location',
                  ),
              ],
            ),
            
            // Manual location name input
            TextField(
              controller: _manualLocationController,
              decoration: InputDecoration(
                labelText: 'Location name (optional)',
                hintText: 'e.g., Barn A, North Pasture, Show Arena',
                border: const OutlineInputBorder(),
                prefixIcon: const Icon(Icons.edit_location),
                suffixIcon: _manualLocationController.text.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.clear),
                      onPressed: () {
                        _manualLocationController.clear();
                        if (_currentLocation != null) {
                          final updatedLocation = LocationData(
                            latitude: _currentLocation!.latitude,
                            longitude: _currentLocation!.longitude,
                            address: _currentLocation!.address,
                            locationName: null,
                            accuracy: _currentLocation!.accuracy,
                            capturedAt: _currentLocation!.capturedAt,
                          );
                          widget.onLocationChanged(updatedLocation, _currentWeather);
                        }
                      },
                    )
                  : null,
              ),
              onChanged: (value) {
                if (_currentLocation != null) {
                  final updatedLocation = LocationData(
                    latitude: _currentLocation!.latitude,
                    longitude: _currentLocation!.longitude,
                    address: _currentLocation!.address,
                    locationName: value.isNotEmpty ? value : null,
                    accuracy: _currentLocation!.accuracy,
                    capturedAt: _currentLocation!.capturedAt,
                  );
                  widget.onLocationChanged(updatedLocation, _currentWeather);
                } else if (value.isNotEmpty) {
                  // Manual location only
                  widget.onLocationChanged(
                    LocationData(locationName: value),
                    null,
                  );
                }
              },
            ),
            
            const SizedBox(height: 12),
            
            // Loading indicator
            if (_isLoading)
              const Center(
                child: Padding(
                  padding: EdgeInsets.all(16.0),
                  child: CircularProgressIndicator(),
                ),
              ),
            
            // Error message
            if (_errorMessage != null && !_isLoading)
              Container(
                padding: const EdgeInsets.all(12),
                margin: const EdgeInsets.only(bottom: 12),
                decoration: BoxDecoration(
                  color: Colors.red.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.red.shade200),
                ),
                child: Row(
                  children: [
                    Icon(Icons.error_outline, color: Colors.red.shade700),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _errorMessage!,
                        style: TextStyle(color: Colors.red.shade700),
                      ),
                    ),
                  ],
                ),
              ),
            
            // Location display
            if (_currentLocation != null && 
                _currentLocation!.latitude != null && 
                !_isLoading)
              Container(
                padding: const EdgeInsets.all(12),
                margin: const EdgeInsets.only(bottom: 12),
                decoration: BoxDecoration(
                  color: Colors.green.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.green.shade200),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          Icons.check_circle,
                          color: Colors.green.shade700,
                          size: 20,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'Location captured',
                          style: TextStyle(
                            color: Colors.green.shade700,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    if (_currentLocation!.locationName != null)
                      Text(
                        _currentLocation!.locationName!,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    if (_currentLocation!.address != null)
                      Text(
                        _currentLocation!.address!,
                        style: const TextStyle(fontSize: 14),
                      ),
                    if (_currentLocation!.latitude != null)
                      Text(
                        'Coordinates: ${_currentLocation!.latitude?.toStringAsFixed(6)}, '
                        '${_currentLocation!.longitude?.toStringAsFixed(6)}',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey.shade600,
                        ),
                      ),
                    if (_currentLocation!.accuracy != null)
                      Text(
                        'Accuracy: ±${_currentLocation!.accuracy!.toStringAsFixed(0)}m',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey.shade600,
                        ),
                      ),
                  ],
                ),
              ),
            
            // Weather display
            if (_currentWeather != null && !_isLoading)
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.blue.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.blue.shade200),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          Icons.cloud,
                          color: Colors.blue.shade700,
                          size: 20,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'Weather conditions',
                          style: TextStyle(
                            color: Colors.blue.shade700,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.baseline,
                              textBaseline: TextBaseline.alphabetic,
                              children: [
                                Text(
                                  '${_currentWeather!.temperature.toStringAsFixed(1)}°C',
                                  style: const TextStyle(
                                    fontSize: 24,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  '${(_currentWeather!.temperature * 9/5 + 32).toStringAsFixed(1)}°F',
                                  style: TextStyle(
                                    fontSize: 16,
                                    color: Colors.grey.shade600,
                                  ),
                                ),
                              ],
                            ),
                            Text(
                              _currentWeather!.description ?? 
                              _currentWeather!.conditions,
                              style: const TextStyle(fontSize: 14),
                            ),
                          ],
                        ),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            if (_currentWeather!.humidity != null)
                              Row(
                                children: [
                                  Icon(
                                    Icons.water_drop,
                                    size: 16,
                                    color: Colors.blue.shade600,
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    '${_currentWeather!.humidity!.round()}%',
                                    style: const TextStyle(fontSize: 12),
                                  ),
                                ],
                              ),
                            if (_currentWeather!.windSpeed != null)
                              Row(
                                children: [
                                  Icon(
                                    Icons.air,
                                    size: 16,
                                    color: Colors.blue.shade600,
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    '${_currentWeather!.windSpeed!.toStringAsFixed(1)} m/s',
                                    style: const TextStyle(fontSize: 12),
                                  ),
                                ],
                              ),
                          ],
                        ),
                      ],
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    _manualLocationController.dispose();
    super.dispose();
  }
}