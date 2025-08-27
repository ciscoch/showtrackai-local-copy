# Create Test User in Supabase Dashboard

## Steps to Create Test User:

1. **Go to Supabase Dashboard**
   - Navigate to: https://supabase.com/dashboard
   - Select your project: `showtrackai-local-copy` 

2. **Navigate to Authentication**
   - Click on "Authentication" in the left sidebar
   - Click on "Users" tab

3. **Add New User**
   - Click "Add User" button
   - Fill in the form:
     - **Email**: `test-elite@example.com`
     - **Password**: `test123456`
     - **Auto Confirm User**: ✓ (Check this box)
     - **Email Confirm**: ✓ (Check this box)

4. **Create User**
   - Click "Create User"
   - User should appear in the users list

5. **Verify User Creation**
   - Look for `test-elite@example.com` in the users list
   - Status should show as "Confirmed"

## Test the Login
- Return to your app
- Use "Quick Sign In (Test User)" button
- Should now authenticate successfully

## Alternative: Manual SQL Insert
If the dashboard method doesn't work, you can create the user via SQL:

```sql
-- This should be run in Supabase SQL Editor
INSERT INTO auth.users (
  id,
  email,
  encrypted_password,
  email_confirmed_at,
  created_at,
  updated_at,
  confirmation_token,
  email_confirm_status
) VALUES (
  gen_random_uuid(),
  'test-elite@example.com',
  crypt('test123456', gen_salt('bf')),
  NOW(),
  NOW(),
  NOW(),
  '',
  1
);
```

⚠️ **Note**: The manual SQL method requires careful handling and may not work with all Supabase configurations. Use the Dashboard method first.