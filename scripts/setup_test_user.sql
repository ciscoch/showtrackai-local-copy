-- Test User Setup Script for ShowTrackAI
-- Run this in your Supabase SQL Editor to create the test user and verify database structure

-- First, let's check if our core tables exist
DO $$
BEGIN
    -- Check if animals table exists, if not create a basic version
    IF NOT EXISTS (SELECT FROM information_schema.tables WHERE table_name = 'animals') THEN
        CREATE TABLE animals (
            id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
            user_id UUID REFERENCES auth.users(id) ON DELETE CASCADE NOT NULL,
            name VARCHAR(255) NOT NULL,
            species VARCHAR(100) NOT NULL,
            breed VARCHAR(100),
            birth_date DATE,
            weight DECIMAL(10,2),
            color VARCHAR(100),
            ear_tag VARCHAR(50),
            purchase_date DATE,
            purchase_price DECIMAL(10,2),
            notes TEXT,
            metadata JSONB,
            created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
            updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
        );
        
        -- Enable RLS
        ALTER TABLE animals ENABLE ROW LEVEL SECURITY;
        
        -- Create basic policy
        CREATE POLICY "Users can access own animals" ON animals
            USING (auth.uid() = user_id)
            WITH CHECK (auth.uid() = user_id);
    END IF;

    -- Check if journal_entries table exists
    IF NOT EXISTS (SELECT FROM information_schema.tables WHERE table_name = 'journal_entries') THEN
        CREATE TABLE journal_entries (
            id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
            user_id UUID REFERENCES auth.users(id) ON DELETE CASCADE NOT NULL,
            title VARCHAR(255) NOT NULL,
            content TEXT NOT NULL,
            animal_id UUID REFERENCES animals(id) ON DELETE SET NULL,
            entry_date DATE NOT NULL DEFAULT CURRENT_DATE,
            weather_conditions JSONB,
            location_data JSONB,
            tags TEXT[],
            metadata JSONB,
            created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
            updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
        );
        
        -- Enable RLS
        ALTER TABLE journal_entries ENABLE ROW LEVEL SECURITY;
        
        -- Create basic policy
        CREATE POLICY "Users can access own journal entries" ON journal_entries
            USING (auth.uid() = user_id)
            WITH CHECK (auth.uid() = user_id);
    END IF;

    -- Check if user_profiles table exists (created by migration)
    IF NOT EXISTS (SELECT FROM information_schema.tables WHERE table_name = 'user_profiles') THEN
        CREATE TABLE user_profiles (
            id UUID REFERENCES auth.users(id) ON DELETE CASCADE PRIMARY KEY,
            email TEXT UNIQUE NOT NULL,
            birth_date DATE,
            parent_email TEXT,
            parent_consent BOOLEAN DEFAULT FALSE,
            parent_consent_date TIMESTAMP WITH TIME ZONE,
            is_minor BOOLEAN GENERATED ALWAYS AS (
                CASE 
                    WHEN birth_date IS NULL THEN NULL
                    WHEN EXTRACT(YEAR FROM AGE(CURRENT_DATE, birth_date)) < 13 THEN TRUE
                    ELSE FALSE
                END
            ) STORED,
            requires_parent_consent BOOLEAN GENERATED ALWAYS AS (
                CASE 
                    WHEN birth_date IS NULL THEN FALSE
                    WHEN EXTRACT(YEAR FROM AGE(CURRENT_DATE, birth_date)) < 13 THEN TRUE
                    ELSE FALSE
                END
            ) STORED,
            metadata JSONB,
            created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
            updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
        );
        
        -- Enable RLS
        ALTER TABLE user_profiles ENABLE ROW LEVEL SECURITY;
        
        -- Create basic policies
        CREATE POLICY "Users can access own profile" ON user_profiles
            USING (auth.uid() = id)
            WITH CHECK (auth.uid() = id);
    END IF;
    
    RAISE NOTICE 'Database tables verified/created successfully';
END
$$;

-- Now let's check if the test user already exists
DO $$
DECLARE 
    test_user_id UUID;
    test_user_exists BOOLEAN := FALSE;
BEGIN
    -- Check if test user exists in auth.users
    SELECT id INTO test_user_id
    FROM auth.users 
    WHERE email = 'test-elite@example.com';
    
    IF test_user_id IS NOT NULL THEN
        test_user_exists := TRUE;
        RAISE NOTICE 'Test user already exists with ID: %', test_user_id;
        
        -- Ensure user profile exists
        INSERT INTO user_profiles (id, email, birth_date)
        VALUES (test_user_id, 'test-elite@example.com', '1990-01-01'::DATE)
        ON CONFLICT (id) DO UPDATE SET 
            email = EXCLUDED.email,
            birth_date = COALESCE(user_profiles.birth_date, EXCLUDED.birth_date);
            
        RAISE NOTICE 'Test user profile verified/updated';
    ELSE
        RAISE NOTICE 'Test user does not exist. Please create it manually in Supabase Auth or run the user creation script.';
    END IF;
END
$$;

-- Create sample data for the test user (if user exists)
DO $$
DECLARE 
    test_user_id UUID;
    sample_animal_id UUID;
BEGIN
    -- Get test user ID
    SELECT id INTO test_user_id
    FROM auth.users 
    WHERE email = 'test-elite@example.com';
    
    IF test_user_id IS NOT NULL THEN
        -- Create a sample animal if none exists
        INSERT INTO animals (user_id, name, species, breed, birth_date, weight, color)
        VALUES (
            test_user_id,
            'Bessie',
            'cattle',
            'Holstein',
            '2023-03-15'::DATE,
            450.00,
            'Black and White'
        )
        ON CONFLICT DO NOTHING
        RETURNING id INTO sample_animal_id;
        
        -- If no conflict, get the animal ID
        IF sample_animal_id IS NULL THEN
            SELECT id INTO sample_animal_id
            FROM animals 
            WHERE user_id = test_user_id AND name = 'Bessie'
            LIMIT 1;
        END IF;
        
        -- Create sample journal entries
        INSERT INTO journal_entries (user_id, title, content, animal_id, entry_date)
        VALUES 
        (
            test_user_id,
            'Daily Health Check',
            'Performed routine health inspection. Bessie appears healthy with good appetite and normal behavior. Temperature: 101.2°F (normal range). No signs of illness or injury detected.',
            sample_animal_id,
            CURRENT_DATE
        ),
        (
            test_user_id,
            'Feed Adjustment',
            'Increased grain ration by 1 lb per day to support continued growth. Currently feeding 8 lbs grain + 12 lbs hay daily. Body condition score: 6/10. Target weight for show: 1100 lbs.',
            sample_animal_id,
            CURRENT_DATE - 1
        ),
        (
            test_user_id,
            'Exercise Session',
            'Walked Bessie for 30 minutes around the pasture. Worked on leading and stopping on command. She is responding well to training. Need to continue daily exercise routine.',
            sample_animal_id,
            CURRENT_DATE - 2
        )
        ON CONFLICT DO NOTHING;
        
        RAISE NOTICE 'Sample data created for test user';
    ELSE
        RAISE NOTICE 'Cannot create sample data - test user does not exist';
    END IF;
END
$$;

-- Verify the setup
DO $$
DECLARE 
    user_count INTEGER;
    animal_count INTEGER;
    journal_count INTEGER;
    test_user_id UUID;
BEGIN
    -- Get test user ID
    SELECT id INTO test_user_id FROM auth.users WHERE email = 'test-elite@example.com';
    
    IF test_user_id IS NOT NULL THEN
        SELECT COUNT(*) INTO animal_count FROM animals WHERE user_id = test_user_id;
        SELECT COUNT(*) INTO journal_count FROM journal_entries WHERE user_id = test_user_id;
        
        RAISE NOTICE 'Test user setup verification:';
        RAISE NOTICE '  - Test user ID: %', test_user_id;
        RAISE NOTICE '  - Animals created: %', animal_count;
        RAISE NOTICE '  - Journal entries created: %', journal_count;
        RAISE NOTICE '  - Setup completed successfully!';
    ELSE
        RAISE NOTICE 'Test user not found. Please create the user first.';
    END IF;
END
$$;

-- Instructions for manual user creation (if needed)
/*
If the test user doesn't exist, you need to create it manually:

1. Go to Supabase Dashboard > Authentication > Users
2. Click "Add User" 
3. Enter:
   - Email: test-elite@example.com  
   - Password: test123456
   - Confirm Password: test123456
4. Click "Create User"
5. Then run this script again to set up the profile and sample data

Alternatively, you can create the user programmatically by temporarily disabling email confirmation:
1. Go to Authentication > Settings 
2. Turn off "Enable email confirmations"
3. Use the signup flow in your app
4. Turn email confirmations back on
*/