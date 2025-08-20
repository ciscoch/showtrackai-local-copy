# 🔧 Netlify Environment Variables Setup Guide

## Critical: Geolocation Weather Feature Configuration

The geolocation toggle with weather feature requires environment variables to be configured in your Netlify dashboard. Without these, the feature will appear but weather data won't load.

## 📝 Required Environment Variables

Set these in **Netlify Dashboard → Site Settings → Environment Variables**:

| Variable | Value | Required | Description |
|----------|-------|----------|-------------|
| `SUPABASE_URL` | `https://zifbuzsdhparxlhsifdi.supabase.co` | ✅ Yes | Your Supabase project URL |
| `SUPABASE_ANON_KEY` | `[your-supabase-anon-key]` | ✅ Yes | Supabase anonymous key |
| `OPENWEATHER_API_KEY` | `[your-openweather-api-key]` | ✅ Yes | OpenWeatherMap API key for weather data |
| `DEMO_EMAIL` | `[demo-email]` | ⚠️ Optional | Demo account email |
| `DEMO_PASSWORD` | `[demo-password]` | ⚠️ Optional | Demo account password |

## 🚀 Step-by-Step Setup

### 1. Access Netlify Environment Variables

1. Go to [Netlify Dashboard](https://app.netlify.com)
2. Select your site: `mellifluous-speculoos-46225c`
3. Navigate to **Site configuration** → **Environment variables**
4. Click **Add a variable**

### 2. Add OpenWeather API Key (CRITICAL FOR WEATHER)

```
Key: OPENWEATHER_API_KEY
Values: 
  - Production: [your-api-key]
  - All deploy contexts: ✅
```

**Get your API key from:** https://openweathermap.org/api

### 3. Add Supabase Configuration

```
Key: SUPABASE_URL
Values: 
  - Production: https://zifbuzsdhparxlhsifdi.supabase.co
  - All deploy contexts: ✅
```

```
Key: SUPABASE_ANON_KEY
Values: 
  - Production: [your-supabase-anon-key]
  - All deploy contexts: ✅
```

### 4. Trigger Rebuild

After adding all environment variables:
1. Go to **Deploys** tab
2. Click **Trigger deploy** → **Deploy site**
3. Wait for build to complete (~5 minutes)

## ✅ Verification

### Check if Environment Variables are Working:

1. **Visit your deployed site**
2. **Navigate to:** Journal → New Entry
3. **Look for:** "Location & Weather" section
4. **Toggle:** "Use GPS location" switch
5. **Expected result:** 
   - GPS coordinates captured
   - Weather data displayed (temperature, conditions)
   - No "API key not configured" warning

### If Weather Still Doesn't Work:

1. **Check browser console** for errors (F12 → Console)
2. **Verify API key** is valid at OpenWeatherMap
3. **Clear browser cache** (Cmd+Shift+R)
4. **Check build logs** in Netlify for environment variable warnings

## 🔍 Debugging

### Test Weather API Directly:

```bash
# Replace with your API key
API_KEY="your-api-key-here"
curl "https://api.openweathermap.org/data/2.5/weather?lat=37.7749&lon=-122.4194&appid=$API_KEY&units=imperial"
```

### Check Build Output:

In Netlify build logs, you should see:
```
flutter build web --release \
  --dart-define OPENWEATHER_API_KEY=${OPENWEATHER_API_KEY} \
  ...
```

## ⚠️ Security Notes

- **NEVER** commit API keys to git
- **NEVER** hardcode API keys in source files
- **ALWAYS** use environment variables for sensitive data
- The `.env.local` file is for local development only

## 📊 Current Status

As of the latest deployment:
- ✅ Geolocation toggle is implemented and visible
- ✅ GPS capture works on HTTPS sites
- ⚠️ Weather data requires `OPENWEATHER_API_KEY` in Netlify
- ✅ All other features working correctly

## 🆘 Troubleshooting

| Issue | Solution |
|-------|----------|
| "Weather data unavailable" message | Set `OPENWEATHER_API_KEY` in Netlify |
| GPS toggle not visible | Clear cache, check Journal → New Entry (not quick entry) |
| Location permission denied | Enable location in browser settings |
| Blank weather after GPS capture | API key not configured or invalid |

## 📚 Additional Resources

- [OpenWeatherMap API Documentation](https://openweathermap.org/current)
- [Netlify Environment Variables Guide](https://docs.netlify.com/environment-variables/overview/)
- [Flutter Web Deployment Guide](https://docs.flutter.dev/deployment/web)

---

**Important:** After setting environment variables, you must redeploy for changes to take effect!