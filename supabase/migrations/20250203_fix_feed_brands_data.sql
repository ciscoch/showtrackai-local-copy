-- =============================================
-- FIX FEED BRANDS DATA
-- =============================================
-- Description: Ensure feed_brands and feed_products tables have proper data
-- This migration handles cases where previous migrations may have failed silently
-- Date: 2025-02-03
-- =============================================

-- First, check if feed_brands table has any data
DO $$
DECLARE
    brand_count INTEGER;
    product_count INTEGER;
BEGIN
    SELECT COUNT(*) INTO brand_count FROM feed_brands;
    RAISE NOTICE 'Current brand count: %', brand_count;
    
    SELECT COUNT(*) INTO product_count FROM feed_products;
    RAISE NOTICE 'Current product count: %', product_count;
END;
$$;

-- Ensure all brands have proper non-null required fields
UPDATE feed_brands 
SET 
    is_active = COALESCE(is_active, true),
    created_at = COALESCE(created_at, NOW()),
    updated_at = COALESCE(updated_at, NOW())
WHERE 
    is_active IS NULL 
    OR created_at IS NULL 
    OR updated_at IS NULL;

-- Re-insert brands if they don't exist (using explicit IDs for consistency)
INSERT INTO feed_brands (id, name, is_active, created_at, updated_at) VALUES
    ('b1000001-0000-0000-0000-000000000001', 'Purina', true, NOW(), NOW()),
    ('b1000001-0000-0000-0000-000000000002', 'Jacoby', true, NOW(), NOW()),
    ('b1000001-0000-0000-0000-000000000003', 'Sunglo', true, NOW(), NOW()),
    ('b1000001-0000-0000-0000-000000000004', 'Lindner', true, NOW(), NOW()),
    ('b1000001-0000-0000-0000-000000000005', 'ADM/MoorMan''s ShowTec', true, NOW(), NOW()),
    ('b1000001-0000-0000-0000-000000000006', 'Nutrena', true, NOW(), NOW()),
    ('b1000001-0000-0000-0000-000000000007', 'Bluebonnet', true, NOW(), NOW()),
    ('b1000001-0000-0000-0000-000000000008', 'Kalmbach', true, NOW(), NOW()),
    ('b1000001-0000-0000-0000-000000000009', 'Umbarger', true, NOW(), NOW()),
    ('b1000001-0000-0000-0000-000000000010', 'Show Rite', true, NOW(), NOW())
ON CONFLICT (name) 
DO UPDATE SET 
    is_active = EXCLUDED.is_active,
    updated_at = NOW()
WHERE feed_brands.is_active IS DISTINCT FROM EXCLUDED.is_active;

-- Clean up any duplicate or invalid brands
DELETE FROM feed_brands 
WHERE id NOT IN (
    SELECT MIN(id) 
    FROM feed_brands 
    GROUP BY LOWER(TRIM(name))
);

-- Ensure products reference valid brands
DELETE FROM feed_products 
WHERE brand_id NOT IN (SELECT id FROM feed_brands);

-- Re-insert some essential products if missing
-- This ensures at least some products exist for testing
DO $$
DECLARE
    purina_id UUID;
    jacoby_id UUID;
    sunglo_id UUID;
BEGIN
    -- Get brand IDs
    SELECT id INTO purina_id FROM feed_brands WHERE name = 'Purina' LIMIT 1;
    SELECT id INTO jacoby_id FROM feed_brands WHERE name = 'Jacoby' LIMIT 1;
    SELECT id INTO sunglo_id FROM feed_brands WHERE name = 'Sunglo' LIMIT 1;
    
    -- Insert essential products if brands exist
    IF purina_id IS NOT NULL THEN
        INSERT INTO feed_products (brand_id, name, species, type, is_active) VALUES
            (purina_id, 'Honor Show Chow Fitter''s Edge', ARRAY['cattle', 'goat', 'sheep'], 'feed', true),
            (purina_id, 'Honor Show Chow Impulse Goat R20', ARRAY['goat'], 'feed', true),
            (purina_id, 'High Octane Champion Drive', ARRAY['cattle', 'swine', 'goat', 'sheep'], 'supplement', true)
        ON CONFLICT (brand_id, name) 
        DO UPDATE SET 
            species = EXCLUDED.species,
            type = EXCLUDED.type,
            is_active = EXCLUDED.is_active,
            updated_at = NOW();
    END IF;
    
    IF jacoby_id IS NOT NULL THEN
        INSERT INTO feed_products (brand_id, name, species, type, is_active) VALUES
            (jacoby_id, 'Supreme Lamb Grower', ARRAY['sheep'], 'feed', true),
            (jacoby_id, 'Show Goat Developer', ARRAY['goat'], 'feed', true),
            (jacoby_id, 'All-Species Show Mineral', ARRAY['cattle', 'goat', 'sheep', 'swine'], 'mineral', true)
        ON CONFLICT (brand_id, name) 
        DO UPDATE SET 
            species = EXCLUDED.species,
            type = EXCLUDED.type,
            is_active = EXCLUDED.is_active,
            updated_at = NOW();
    END IF;
    
    IF sunglo_id IS NOT NULL THEN
        INSERT INTO feed_products (brand_id, name, species, type, is_active) VALUES
            (sunglo_id, 'Explode Supplement', ARRAY['swine'], 'supplement', true),
            (sunglo_id, 'Show Pig Grower', ARRAY['swine'], 'feed', true)
        ON CONFLICT (brand_id, name) 
        DO UPDATE SET 
            species = EXCLUDED.species,
            type = EXCLUDED.type,
            is_active = EXCLUDED.is_active,
            updated_at = NOW();
    END IF;
END;
$$;

-- Ensure all products have required non-null fields
UPDATE feed_products 
SET 
    species = COALESCE(species, ARRAY['cattle', 'goat', 'sheep', 'swine']),
    is_active = COALESCE(is_active, true),
    created_at = COALESCE(created_at, NOW()),
    updated_at = COALESCE(updated_at, NOW())
WHERE 
    species IS NULL OR species = '{}' 
    OR is_active IS NULL 
    OR created_at IS NULL 
    OR updated_at IS NULL;

-- Final validation
DO $$
DECLARE
    brand_count INTEGER;
    product_count INTEGER;
    null_id_brands INTEGER;
    null_name_brands INTEGER;
    inactive_brands INTEGER;
BEGIN
    -- Count total brands
    SELECT COUNT(*) INTO brand_count FROM feed_brands;
    
    -- Count brands with issues
    SELECT COUNT(*) INTO null_id_brands FROM feed_brands WHERE id IS NULL;
    SELECT COUNT(*) INTO null_name_brands FROM feed_brands WHERE name IS NULL OR name = '';
    SELECT COUNT(*) INTO inactive_brands FROM feed_brands WHERE is_active = false;
    
    -- Count products
    SELECT COUNT(*) INTO product_count FROM feed_products;
    
    -- Report results
    RAISE NOTICE '===========================================';
    RAISE NOTICE 'Feed Brands Data Fix Complete';
    RAISE NOTICE '===========================================';
    RAISE NOTICE 'Total brands: %', brand_count;
    RAISE NOTICE 'Active brands: %', brand_count - inactive_brands;
    RAISE NOTICE 'Total products: %', product_count;
    
    -- Warnings
    IF null_id_brands > 0 THEN
        RAISE WARNING 'Found % brands with NULL ids!', null_id_brands;
    END IF;
    
    IF null_name_brands > 0 THEN
        RAISE WARNING 'Found % brands with NULL or empty names!', null_name_brands;
    END IF;
    
    IF brand_count < 10 THEN
        RAISE WARNING 'Expected at least 10 brands, found only %', brand_count;
    END IF;
    
    IF product_count < 10 THEN
        RAISE WARNING 'Expected more products, found only %', product_count;
    END IF;
    
    IF brand_count >= 10 AND product_count >= 10 THEN
        RAISE NOTICE '✅ Feed data successfully restored!';
    END IF;
END;
$$;

-- Create a simple verification view
CREATE OR REPLACE VIEW v_feed_brands_status AS
SELECT 
    COUNT(*) as total_brands,
    COUNT(*) FILTER (WHERE is_active = true) as active_brands,
    COUNT(*) FILTER (WHERE id IS NULL) as null_id_count,
    COUNT(*) FILTER (WHERE name IS NULL OR name = '') as null_name_count,
    MIN(created_at) as oldest_brand_date,
    MAX(updated_at) as newest_update
FROM feed_brands;

-- Grant permissions on the status view
GRANT SELECT ON v_feed_brands_status TO authenticated;

-- Final check query that can be run to verify the fix worked
-- This will be displayed in the migration output
SELECT 
    'Brands Status:' as check_type,
    total_brands,
    active_brands,
    CASE 
        WHEN total_brands >= 10 THEN '✅ PASS'
        ELSE '❌ FAIL - Not enough brands'
    END as status
FROM v_feed_brands_status
UNION ALL
SELECT 
    'Products Status:' as check_type,
    COUNT(*) as total_count,
    COUNT(*) FILTER (WHERE is_active = true) as active_count,
    CASE 
        WHEN COUNT(*) >= 10 THEN '✅ PASS'
        ELSE '❌ FAIL - Not enough products'
    END as status
FROM feed_products
GROUP BY check_type;