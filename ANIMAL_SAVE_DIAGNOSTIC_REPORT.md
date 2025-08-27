# ShowTrackAI Animal Save Issue Investigation Report
## Linear Issue SHO-5: Users Cannot Save Animal Edits

### Issue Summary
Users are reporting they cannot save edits to animals in the ShowTrackAI app. The edit screen appears to work but saves fail silently or with errors.

### Code Analysis Results ✅

**Core Files Status:**
- ✅ AnimalEditScreen exists with proper _updateAnimal method
- ✅ AnimalService.updateAnimal method correctly implemented  
- ✅ Authentication checks present in both UI and service
- ✅ Error handling and user feedback implemented
- ✅ Form validation present
- ✅ Loading states managed properly

### Most Likely Root Causes

#### 1. **Authentication Context Loss** 🔴 HIGH PROBABILITY
**Issue:** User authentication may expire or become invalid during edit session
**Evidence:** 
- Long editing sessions could trigger token expiry
- AuthService has complex token refresh logic
- RLS policies require valid authentication

**Debug Steps:**
```dart
// Add to _updateAnimal method in AnimalEditScreen
print('🔐 Auth check: ${_authService.isAuthenticated}');
print('👤 Current user: ${_authService.currentUser?.id}');
print('🎫 Session valid: ${await _authService.validateSession()}');
```

#### 2. **RLS Policy Conflicts** 🔴 HIGH PROBABILITY  
**Issue:** Row Level Security policies may be too restrictive
**Evidence:**
- Recent migration `20250227_animal_security_fixes.sql` added strict RLS
- UpdateAnimal requires both USING and WITH CHECK policies to pass
- User ID mismatch could cause silent failures

**Debug Steps:**
```sql
-- Check if animal belongs to authenticated user
SELECT id, user_id, name FROM animals WHERE id = 'animal-id-here';

-- Check if RLS is blocking the update
SELECT * FROM pg_policies WHERE tablename = 'animals';
```

#### 3. **Input Sanitization Rejection** 🟡 MEDIUM PROBABILITY
**Issue:** InputSanitizer may be rejecting valid inputs
**Evidence:**  
- Strict sanitization rules could reject legitimate animal names/data
- NULL returns from sanitizer could cause validation failures

**Debug Steps:**
```dart
// Add to _updateAnimal method before sanitization
print('📝 Original name: "${_nameController.text}"');
final sanitizedName = InputSanitizer.sanitizeAnimalName(_nameController.text);
print('🧹 Sanitized name: "$sanitizedName"');
```

#### 4. **Network/Supabase Errors** 🟡 MEDIUM PROBABILITY
**Issue:** Supabase connection issues or API errors
**Evidence:**
- Timeout errors could cause silent failures
- Supabase service disruptions

**Debug Steps:**
- Check browser Network tab for failed requests
- Check Supabase dashboard for error logs
- Monitor console for network errors

### Immediate Debugging Script