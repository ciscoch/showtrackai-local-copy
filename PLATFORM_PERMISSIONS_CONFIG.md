# Platform Permissions Configuration for Geolocation

## Overview
This guide explains how to configure platform-specific permissions for the geolocation feature in ShowTrackAI.

## Web Configuration (Current Platform)

### 1. Browser Permissions
Web browsers will automatically prompt users for location permission when the app requests it. No additional configuration needed in the code.

### 2. HTTPS Requirement
**Important:** Geolocation API only works on secure contexts (HTTPS) or localhost.
- Local testing: Works on `http://localhost` or `http://127.0.0.1`
- Production: Must be served over HTTPS (Netlify provides this automatically)

### 3. Testing Locally
```bash
# Run the Flutter web app locally
flutter run -d chrome --web-port=8080

# Or for release mode
flutter run -d chrome --web-port=8080 --release
```

## iOS Configuration (Future)

When you add iOS support, create `ios/Runner/Info.plist` and add:

```xml
<key>NSLocationWhenInUseUsageDescription</key>
<string>ShowTrackAI needs location access to tag your journal entries with location data for better tracking of your agricultural activities.</string>

<key>NSLocationAlwaysUsageDescription</key>
<string>ShowTrackAI needs location access to automatically tag your journal entries with location data.</string>

<key>NSLocationAlwaysAndWhenInUseUsageDescription</key>
<string>ShowTrackAI uses your location to enhance journal entries with geographic and weather data.</string>
```

## Android Configuration (Future)

When you add Android support, update `android/app/src/main/AndroidManifest.xml`:

```xml
<manifest xmlns:android="http://schemas.android.com/apk/res/android">
    <!-- Permissions -->
    <uses-permission android:name="android.permission.ACCESS_FINE_LOCATION" />
    <uses-permission android:name="android.permission.ACCESS_COARSE_LOCATION" />
    <uses-permission android:name="android.permission.INTERNET" />
    
    <application>
        <!-- Your existing configuration -->
    </application>
</manifest>
```

Also update `android/app/build.gradle`:

```gradle
android {
    compileSdkVersion 34
    
    defaultConfig {
        minSdkVersion 21  // Minimum for geolocator
        targetSdkVersion 34
    }
}
```

## Testing Permissions

### Web Browser Testing

1. **Chrome DevTools Location Override:**
   - Open Chrome DevTools (F12)
   - Click three dots menu → More tools → Sensors
   - Under Location, select a preset or enter custom coordinates
   - Test different locations without moving

2. **Permission States:**
   - Granted: User allowed location access
   - Denied: User blocked location access
   - Prompt: User hasn't decided yet

3. **Reset Permissions (Chrome):**
   - Click lock icon in address bar
   - Click "Site settings"
   - Reset "Location" permission
   - Refresh page

### Mobile Testing (Future)

1. **iOS Simulator:**
   - Debug → Location → Custom Location
   - Enter latitude and longitude

2. **Android Emulator:**
   - Extended controls → Location
   - Set custom coordinates

## Error Handling

The LocationService already handles these scenarios:

1. **Location Services Disabled:**
   - Shows message: "Location services are disabled"
   - Fallback to manual location entry

2. **Permission Denied:**
   - Shows message: "Unable to get location. Please enable location services."
   - User can still enter location name manually

3. **Permission Permanently Denied:**
   - Opens app settings for user to enable manually
   - Falls back to manual entry

4. **Timeout:**
   - 10-second timeout for location requests
   - Falls back to manual entry if GPS takes too long

## Privacy Considerations

1. **User Consent:**
   - Always request permission before accessing location
   - Explain why location is needed in the UI

2. **Data Minimization:**
   - Only collect location when user explicitly enables it
   - Location is optional for journal entries

3. **Local Testing:**
   - No location data is sent to servers during local testing
   - Weather API uses sample data when API key not configured

## Security Notes

1. **API Keys:**
   - OpenWeatherMap API key should be configured in environment variables
   - Never commit API keys to version control
   - For testing, the service returns sample weather data

2. **HTTPS Enforcement:**
   - Geolocation API requires secure context
   - Netlify automatically provides SSL certificates

## Verification Checklist

- [ ] Web app runs on localhost with location features
- [ ] Location permission prompt appears when requested
- [ ] GPS coordinates are captured correctly
- [ ] Address reverse geocoding works
- [ ] Weather data displays (sample or real)
- [ ] Manual location name entry works
- [ ] Error messages display appropriately
- [ ] Location can be cleared/reset
- [ ] App works when permission is denied (fallback mode)

## Current Status

✅ **Web Platform:** Ready for testing
⏳ **iOS Platform:** Configuration provided for future use
⏳ **Android Platform:** Configuration provided for future use

The geolocation feature is fully functional for web testing on localhost.