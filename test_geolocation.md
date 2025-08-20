# 🧪 Geolocation Feature - Local Testing Guide

## Quick Start for Testing

### 1. Install Dependencies
```bash
cd /Users/francisco/Documents/CALUDE/showtrackai-local-copy
flutter pub get
```

### 2. Run Local Development
```bash
# Option 1: Flutter Web (Recommended for testing)
flutter run -d chrome

# Option 2: With Netlify Functions
npx netlify dev --port 3009
```

### 3. Test the Location Feature

#### Step-by-Step Testing Process:

1. **Open the Journal Entry Form**
   - Navigate to the Journal section
   - Click "New Journal Entry"

2. **Test GPS Location Capture**
   - Toggle "Use GPS location" switch to ON
   - Browser will prompt for location permission - Click "Allow"
   - Location should be captured automatically
   - Verify you see:
     - ✅ Green "Location captured" box
     - GPS coordinates
     - Human-readable address (if available)
     - Accuracy in meters

3. **Test Weather Data**
   - When location is captured, weather should load automatically
   - Verify you see:
     - 🌤️ Blue weather conditions box
     - Temperature in °C and °F
     - Weather conditions (Clear, Cloudy, etc.)
     - Humidity percentage
     - Wind speed (if available)

4. **Test Manual Location Entry**
   - Enter a custom location name like "Barn A" or "North Pasture"
   - This will be saved along with GPS coordinates

5. **Test Without Location**
   - Toggle "Use GPS location" OFF
   - Verify location/weather data is cleared
   - Can still enter manual location name only

### 4. Test Scenarios

#### ✅ Success Scenarios:
- [ ] Location permission granted → GPS coordinates captured
- [ ] Weather data loads after location capture
- [ ] Manual location name can be added
- [ ] Location data persists when navigating form
- [ ] Submit journal entry with location data

#### ⚠️ Error Scenarios to Test:
- [ ] Location permission denied → Shows error message
- [ ] No internet connection → Mock weather data shown
- [ ] GPS timeout → Shows appropriate error
- [ ] Invalid API key → Returns mock weather data

### 5. Verify Data Flow

```javascript
// Check browser console for debug output:
// Open Chrome DevTools (F12) → Console tab

// You should see:
"Location captured: 37.7749, -122.4194"
"Accuracy: 20 meters"
"Address found: Market St, San Francisco, CA 94103, USA"
"Using cached weather data" // or "Fetching weather from API"
"Weather fetched: 22.5°C, Clear"
```

### 6. Test Mock Data (No API Key)

Since the weather API key is not configured, the app will use mock data:
- Temperature varies by time of day
- Weather conditions rotate through realistic options
- Humidity ranges from 45-75%

To test with real weather data:
1. Get a free API key from [OpenWeatherMap](https://openweathermap.org/api)
2. Update `/lib/services/weather_service.dart`:
   ```dart
   static const String _apiKey = 'YOUR_ACTUAL_API_KEY';
   ```

### 7. Browser Compatibility

| Browser | GPS Support | Expected Behavior |
|---------|------------|-------------------|
| Chrome | ✅ Full | All features work |
| Firefox | ✅ Full | All features work |
| Safari | ✅ Full | May need HTTPS for location |
| Edge | ✅ Full | All features work |

### 8. Common Issues & Solutions

#### Issue: "Location permission denied"
**Solution:** 
- Check browser settings → Site Settings → Location
- Ensure location is allowed for localhost:3009

#### Issue: "Unable to get location"
**Solution:**
- Check if location services are enabled on your device
- Try refreshing the page
- Check browser console for specific errors

#### Issue: Weather not loading
**Solution:**
- Check internet connection
- Verify mock data is working (should show even without API)
- Check browser console for API errors

### 9. Local Storage Testing

The app caches weather data for 30 minutes. To test caching:

1. Capture location → Weather loads
2. Check Application → Local Storage in DevTools
3. Look for keys starting with `weather_cache_`
4. Refresh page within 30 minutes
5. Should see "Using cached weather data" in console

### 10. Submit Test Entry

Complete journal entry with location data:
```json
{
  "title": "Morning Feed - Test",
  "description": "Testing location feature with morning feeding routine...",
  "location": {
    "latitude": 37.7749,
    "longitude": -122.4194,
    "address": "Market St, San Francisco, CA",
    "locationName": "Barn A",
    "accuracy": 20
  },
  "weather": {
    "temperature": 22.5,
    "conditions": "Clear",
    "humidity": 65,
    "windSpeed": 3.5
  }
}
```

## Testing Checklist

### Pre-Flight Checks:
- [ ] Dependencies installed (`flutter pub get`)
- [ ] Browser location services enabled
- [ ] Internet connection active

### Feature Tests:
- [ ] GPS location capture works
- [ ] Address reverse geocoding displays
- [ ] Weather data loads (mock or real)
- [ ] Manual location name entry works
- [ ] Location toggle ON/OFF functions
- [ ] Error messages display appropriately
- [ ] Form submission includes location data

### Integration Tests:
- [ ] Journal entry saves with location
- [ ] Location data appears in saved entries
- [ ] Weather cache works (30-minute cache)
- [ ] Works without internet (mock data)

## Next Steps

After successful local testing:
1. Deploy to Netlify for production testing
2. Test on actual mobile devices
3. Gather user feedback
4. Monitor for any GPS/weather API issues

---

**Ready to test?** Start with Step 1 above and work through each scenario.