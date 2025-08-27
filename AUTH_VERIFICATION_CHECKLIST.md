# Authentication Verification Checklist

## 1. User Authentication Status
- [ ] Check if user is logged in: `_authService.isAuthenticated`
- [ ] Verify current user exists: `_authService.currentUser != null`
- [ ] Check user ID is valid: `_authService.currentUser?.id`

## 2. Session Validity
- [ ] Test session validation: `await _authService.validateSession()`
- [ ] Check session expiry time
- [ ] Verify auth headers: `_authService.getAuthHeaders()`

## 3. Token Refresh
- [ ] Check if token needs refresh
- [ ] Test manual token refresh: `await _authService.refreshSession()`
- [ ] Verify new token is used in requests

## 4. Common Auth Issues
- [ ] Session expired during long edit sessions
- [ ] Token refresh failed
- [ ] Network interruption during auth
- [ ] Multiple browser tabs causing auth conflicts

## 5. Quick Tests
- [ ] Try saving immediately after login
- [ ] Test save after 30+ minutes of editing
- [ ] Check save with different user accounts
- [ ] Test with network interruption/restore

## Debug Commands to Run:
```dart
// In _updateAnimal method:
print('Auth Status: ${_authService.isAuthenticated}');
print('User ID: ${_authService.currentUser?.id}');
print('Session Valid: ${await _authService.validateSession()}');
print('Auth Headers: ${_authService.getAuthHeaders()}');
```
