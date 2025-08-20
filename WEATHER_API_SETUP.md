# 🌤️ Weather API Configuration

## Your OpenWeatherMap API Key
```
YOUR_API_KEY_HERE
```

---

## 🚀 Local Testing

### Quick Test with Real Weather:
```bash
cd /Users/francisco/Documents/CALUDE/showtrackai-local-copy

# Use the new test script with API key built-in
./test_geolocation_with_api.sh
```

### Manual Testing:
```bash
# Run with API key
flutter run -d chrome \
  --dart-define=OPENWEATHER_API_KEY=YOUR_API_KEY_HERE \
  --web-browser-flag "--enable-features=WebRTC"
```

---

## 🌐 Netlify Deployment Configuration

### Add to Netlify Environment Variables:

1. **Go to Netlify Dashboard**
   - Site settings → Environment variables

2. **Add New Variable:**
   - Key: `OPENWEATHER_API_KEY`
   - Value: `YOUR_API_KEY_HERE`
   - Scopes: All deploy contexts

3. **Update Build Script** (already done in netlify-build.sh):
   ```bash
   flutter build web --release \
     --dart-define OPENWEATHER_API_KEY=${OPENWEATHER_API_KEY}
   ```

---

## ✅ What Works Now

### With API Key Configured:
- **Location Capture**: GPS coordinates captured
- **Reverse Geocoding**: Address lookup from coordinates
- **Weather Data**: 
  - Current temperature (°C)
  - Weather conditions (Clear, Cloudy, Rain, etc.)
  - Humidity percentage
  - Wind speed (m/s)
- **Caching**: 30-minute cache to reduce API calls

### API Limits (Free Tier):
- **1,000 calls/day** (more than enough)
- **60 calls/minute** max
- **Current weather** data included
- **5-day forecast** available if needed

---

## 🧪 Testing the Integration

### 1. Start the App:
```bash
./test_geolocation_with_api.sh
```

### 2. Navigate to Journal Entry:
- Open the dashboard
- Click "New Journal Entry" or similar

### 3. Enable Location:
- Toggle the location switch ON
- Allow browser location permissions

### 4. Verify Data:
You should see:
- ✅ Latitude/Longitude coordinates
- ✅ Address (street, city, country)
- ✅ Temperature in Celsius
- ✅ Weather description
- ✅ Humidity percentage
- ✅ Wind speed

---

## 🔍 Troubleshooting

### If Weather Not Showing:
1. **Check Console**: Open browser dev tools (F12)
2. **Look for**: "Weather API key is configured: true"
3. **Verify**: No CORS errors in network tab

### Common Issues:
- **Location Permission Denied**: Check browser settings
- **Weather Not Loading**: API key might have typo
- **Empty Weather**: API call might be failing

### Debug Mode:
Check browser console for these messages:
```
✅ Weather service initialized with API key
✅ Fetching weather for coordinates: [lat], [lng]
✅ Weather fetched: [temp]°C, [conditions]
```

---

## 📦 Files Using the API Key

1. **Weather Service**: `lib/services/weather_service.dart`
   - Reads from environment variable
   - Makes API calls to OpenWeatherMap
   - Caches results for 30 minutes

2. **Build Script**: `netlify-build.sh`
   - Passes API key during build
   - Uses `--dart-define` flag

3. **Test Scripts**:
   - `test_geolocation_with_api.sh` - Has key built-in
   - `test_geolocation.sh` - Prompts for key

---

## 🔒 Security Notes

- **Never commit** the API key to git
- `.env.local` is in gitignore (safe)
- Use environment variables in production
- API key is for weather data only (low risk)
- Free tier limits prevent abuse

---

## 🎯 Next Steps

1. **Test Locally** ✅ Ready to test
2. **Add to Netlify** → Site settings → Environment variables
3. **Deploy** → Push to main branch
4. **Verify** → Check production has weather data

---

*API Key configured and ready for testing*  
*Weather service will work with real data*