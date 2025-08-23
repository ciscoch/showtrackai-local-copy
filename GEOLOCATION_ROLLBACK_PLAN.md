# ShowTrackAI Geolocation Rollback Plan

## Executive Summary
The ShowTrackAI app has experienced persistent deployment issues since adding geolocation features starting from commit `69ce5ef`. The issues stem from Flutter web incompatibilities with geolocation packages, CSP violations, and WASM compilation problems. This plan provides a surgical approach to remove geolocation while preserving app functionality.

## Timeline Analysis

### Key Commits
- **Last Stable Commit**: `e3d49db` (Aug 20) - "Mobile UI improvements for iPhone and small screens"
- **First Geolocation**: `69ce5ef` - "feat: Add geolocation and weather integration to journal entries"
- **Multiple Fix Attempts**: `7d200fd` through `83840f1` - Various failed attempts to fix geolocation

### Problematic Period
- **Start**: Commit `69ce5ef` (first geolocation integration)
- **End**: Current HEAD `7d200fd` (latest failed fix attempt)
- **Total Commits Affected**: ~15 commits focused on fixing geolocation issues

## Files to Modify/Remove

### 1. Service Files (TO REMOVE)
```
lib/services/location_service.dart
lib/services/location_service_safe.dart
lib/services/location_service_web.dart
lib/services/location_service_mobile.dart
lib/services/weather_service.dart
```

### 2. Widget Files (TO REMOVE)
```
lib/widgets/location_input_field.dart
```

### 3. Files to Modify (Remove Geolocation References)
```
lib/screens/journal_entry_form.dart
lib/widgets/financial_journal_card.dart
pubspec.yaml
```

### 4. Build/Deploy Files to Simplify
```
netlify.toml
netlify-build.sh
build-with-env.sh
```

## Step-by-Step Rollback Process

### Phase 1: Remove Dependencies
1. Edit `pubspec.yaml`:
   - Remove/comment out: `geolocator`, `geocoding`, `permission_handler`
   - Keep: `weather: ^3.1.1` (can work with manual city input)
   - Keep: `flutter_map`, `latlong2` (harmless, future use)

### Phase 2: Remove Service Files
```bash
# Remove all location service variants
rm lib/services/location_service*.dart
rm lib/services/weather_service.dart
```

### Phase 3: Remove Widget Files
```bash
rm lib/widgets/location_input_field.dart
```

### Phase 4: Clean Up Imports and Usage
1. **journal_entry_form.dart**:
   - Remove LocationInputField import
   - Remove location/weather fields from form
   - Keep basic journal functionality

2. **financial_journal_card.dart**:
   - Remove location-related imports
   - Remove location display logic
   - Keep financial tracking features

### Phase 5: Simplify Build Configuration
1. **netlify.toml**:
   - Remove complex CSP headers
   - Remove service worker configurations
   - Use simple Flutter build command

2. **netlify-build.sh**:
   - Remove --web-renderer flags
   - Remove WASM-specific configurations
   - Simple: `flutter build web --release`

## Preservation Strategy

### Features to Keep:
1. ✅ Mobile UI improvements (commit `e3d49db`)
2. ✅ Core journaling functionality
3. ✅ Financial tracking
4. ✅ FFA degree progress
5. ✅ Database integrations
6. ✅ All non-geolocation bug fixes

### Alternative Weather Implementation:
- Manual city input field
- Use weather API with city name instead of coordinates
- Store user's preferred location in preferences

## Implementation Commands

### Step 1: Create Clean Branch
```bash
git checkout -b remove-geolocation
git reset --hard e3d49db  # Reset to last stable commit
```

### Step 2: Cherry-Pick Non-Geolocation Fixes
```bash
# Identify and cherry-pick any critical fixes unrelated to geolocation
# (To be determined after reviewing individual commits)
```

### Step 3: Clean Dependencies
```bash
# Edit pubspec.yaml to remove geolocation packages
flutter pub get
flutter clean
```

### Step 4: Remove Problem Files
```bash
rm -rf lib/services/location_service*.dart
rm lib/services/weather_service.dart
rm lib/widgets/location_input_field.dart
```

### Step 5: Fix Imports
```bash
# Use grep to find and fix all imports
grep -r "location_service\|LocationService" lib/
grep -r "weather_service\|WeatherService" lib/
grep -r "location_input_field\|LocationInputField" lib/
```

### Step 6: Simplified Build
```bash
# Create simple build script
cat > netlify-build.sh << 'EOF'
#!/bin/bash
set -e
flutter clean
flutter pub get
flutter build web --release --dart-define=FLUTTER_WEB_CANVASKIT_URL=/canvaskit/
echo "Build complete!"
EOF
```

## Testing Checklist

### Local Testing:
- [ ] Flutter clean && flutter pub get
- [ ] Flutter build web --release
- [ ] Flutter run -d chrome
- [ ] Test all journal features
- [ ] Test financial tracking
- [ ] Test FFA progress
- [ ] Verify no console errors

### Deployment Testing:
- [ ] Deploy to Netlify preview
- [ ] Check for CSP errors
- [ ] Verify all assets load
- [ ] Test on multiple browsers
- [ ] Test on mobile devices

## Rollback Verification

### Success Criteria:
1. ✅ App builds without errors
2. ✅ Deploys to Netlify successfully
3. ✅ No CSP violations in console
4. ✅ All core features functional
5. ✅ No service worker issues
6. ✅ Clean browser console

### Performance Metrics:
- Build time: < 2 minutes
- Deploy time: < 3 minutes
- Page load: < 3 seconds
- No runtime errors

## Alternative Weather Solution (Post-Rollback)

### Manual Weather Integration:
```dart
// Simple weather with city input
class SimpleWeatherService {
  Future<Weather?> getWeatherByCity(String city) async {
    // Use weather package with city name
    // No geolocation required
  }
}
```

### User Preferences:
- Store preferred city in SharedPreferences
- Allow manual city selection
- No permission requests needed

## Risk Assessment

### Low Risk:
- Removing unused geolocation code
- Simplifying build process
- Returning to known working state

### Medium Risk:
- May need to recreate some non-geolocation improvements
- Weather feature will need manual location input

### Mitigation:
- Keep current branch as backup
- Document all removed features
- Plan for future mobile-only geolocation

## Timeline

### Immediate (Today):
1. Create rollback branch
2. Remove geolocation code
3. Test locally

### Day 2:
1. Fix any remaining import issues
2. Implement simple weather alternative
3. Deploy to Netlify preview

### Day 3:
1. Full testing
2. Deploy to production
3. Monitor for issues

## Conclusion

This rollback plan will restore ShowTrackAI to a stable, deployable state by:
1. Removing all problematic geolocation code
2. Preserving core functionality
3. Simplifying the build process
4. Eliminating Flutter web compatibility issues

The app will be simpler but stable, with weather features available through manual city input rather than GPS.