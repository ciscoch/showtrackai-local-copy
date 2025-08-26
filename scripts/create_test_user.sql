-- Create Test User Script for ShowTrackAI
-- This script creates the test user directly in Supabase
-- Run this in your Supabase SQL Editor

-- Option 1: Create user using Supabase's internal auth functions
-- Note: This requires admin privileges and may not work in all environments

DO $$
DECLARE
    new_user_id UUID;
BEGIN
    -- Try to create the test user
    -- Note: This uses internal Supabase functions that may not be available
    BEGIN
        -- Check if user already exists
        IF EXISTS (SELECT 1 FROM auth.users WHERE email = 'test-elite@example.com') THEN
            RAISE NOTICE 'Test user already exists!';
            
            -- Get the existing user ID
            SELECT id INTO new_user_id FROM auth.users WHERE email = 'test-elite@example.com';
            RAISE NOTICE 'Existing test user ID: %', new_user_id;
        ELSE
            -- This is a workaround - you'll need to create the user manually
            RAISE NOTICE 'Test user does not exist. Please create manually in Supabase Dashboard.';
            RAISE NOTICE 'Go to Authentication > Users > Add User';
            RAISE NOTICE 'Email: test-elite@example.com';
            RAISE NOTICE 'Password: test123456';
            RAISE NOTICE 'Then run setup_test_user.sql to create the profile and data.';
        END IF;
        
    EXCEPTION WHEN OTHERS THEN
        RAISE NOTICE 'Could not create user programmatically: %', SQLERRM;
        RAISE NOTICE 'Please create the user manually in Supabase Dashboard.';
    END;
END
$$;

-- Instructions for manual creation
/*
MANUAL CREATION STEPS:
======================

1. Go to your Supabase project dashboard
2. Navigate to Authentication > Users
3. Click "Add User" 
4. Fill in the form:
   - Email: test-elite@example.com
   - Password: test123456
   - Auto Confirm User: YES (check this box)
   - Email Confirm: YES (check this box)
5. Click "Create User"
6. The user will be created with a UUID (note this down)
7. Run setup_test_user.sql to create the profile and sample data

ALTERNATIVE - Create via API:
============================

You can also create the user using curl:

curl -X POST 'https://zifbuzsdhparxlhsifdi.supabase.co/auth/v1/admin/users' \
-H "apikey: YOUR_SERVICE_ROLE_KEY" \
-H "Authorization: Bearer YOUR_SERVICE_ROLE_KEY" \
-H "Content-Type: application/json" \
-d '{
  "email": "test-elite@example.com",
  "password": "test123456",
  "email_confirm": true,
  "phone_confirm": true
}'

Note: You need the service role key (not anon key) for this to work.
*/