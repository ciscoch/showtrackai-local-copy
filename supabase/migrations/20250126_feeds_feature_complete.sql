-- =============================================
-- FEEDS FEATURE COMPLETE MIGRATION
-- =============================================
-- Description: Complete schema and seed data for animal feed tracking
-- Features: Brands, Products, Journal items, Recent feeds, RLS policies
-- Author: Database Admin
-- Date: 2025-01-26
-- =============================================

-- =============================================
-- SECTION 1: SCHEMA CREATION
-- =============================================

-- Drop existing tables if they exist (for clean migration)
DROP TABLE IF EXISTS user_feed_recent CASCADE;
DROP TABLE IF EXISTS journal_feed_items CASCADE;
DROP TABLE IF EXISTS feed_products CASCADE;
DROP TABLE IF EXISTS feed_brands CASCADE;

-- Create feed_brands table
CREATE TABLE feed_brands (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    name TEXT NOT NULL,
    is_active BOOLEAN DEFAULT true NOT NULL,
    created_at TIMESTAMPTZ DEFAULT NOW() NOT NULL,
    updated_at TIMESTAMPTZ DEFAULT NOW() NOT NULL,
    
    -- Ensure brand names are unique (case-insensitive)
    CONSTRAINT feed_brands_name_unique UNIQUE (name)
);

-- Create feed_products table
CREATE TABLE feed_products (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    brand_id UUID NOT NULL REFERENCES feed_brands(id) ON DELETE CASCADE,
    name TEXT NOT NULL,
    species TEXT[] NOT NULL DEFAULT '{}',
    type TEXT NOT NULL CHECK (type IN ('feed', 'mineral', 'supplement')),
    is_active BOOLEAN DEFAULT true NOT NULL,
    created_at TIMESTAMPTZ DEFAULT NOW() NOT NULL,
    updated_at TIMESTAMPTZ DEFAULT NOW() NOT NULL,
    
    -- Ensure product names are unique per brand (case-insensitive)
    CONSTRAINT feed_products_brand_name_unique UNIQUE (brand_id, name)
);

-- Create journal_feed_items table
CREATE TABLE journal_feed_items (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    entry_id UUID NOT NULL REFERENCES journal_entries(id) ON DELETE CASCADE,
    brand_id UUID REFERENCES feed_brands(id) ON DELETE SET NULL,
    product_id UUID REFERENCES feed_products(id) ON DELETE SET NULL,
    is_hay BOOLEAN DEFAULT false NOT NULL,
    quantity DECIMAL(10,2) NOT NULL CHECK (quantity > 0),
    unit TEXT NOT NULL DEFAULT 'lbs' CHECK (unit IN ('lbs', 'flakes', 'bags', 'scoops')),
    note TEXT,
    created_at TIMESTAMPTZ DEFAULT NOW() NOT NULL,
    user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE
);

-- Create user_feed_recent table for "Use Last" functionality
CREATE TABLE user_feed_recent (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    brand_id UUID REFERENCES feed_brands(id) ON DELETE CASCADE,
    product_id UUID REFERENCES feed_products(id) ON DELETE CASCADE,
    is_hay BOOLEAN DEFAULT false NOT NULL,
    quantity DECIMAL(10,2) NOT NULL CHECK (quantity > 0),
    unit TEXT NOT NULL DEFAULT 'lbs',
    last_used_at TIMESTAMPTZ DEFAULT NOW() NOT NULL,
    updated_at TIMESTAMPTZ DEFAULT NOW() NOT NULL,
    
    -- Ensure one recent entry per user/product combination
    CONSTRAINT user_feed_recent_unique UNIQUE (user_id, brand_id, product_id, is_hay)
);

-- =============================================
-- SECTION 2: INDEXES FOR PERFORMANCE
-- =============================================

-- Indexes for feed_brands
CREATE INDEX idx_feed_brands_name ON feed_brands(name);
CREATE INDEX idx_feed_brands_active ON feed_brands(is_active) WHERE is_active = true;

-- Indexes for feed_products
CREATE INDEX idx_feed_products_brand_id ON feed_products(brand_id);
CREATE INDEX idx_feed_products_name ON feed_products(name);
CREATE INDEX idx_feed_products_species ON feed_products USING GIN(species);
CREATE INDEX idx_feed_products_type ON feed_products(type);
CREATE INDEX idx_feed_products_active ON feed_products(is_active) WHERE is_active = true;
CREATE INDEX idx_feed_products_brand_active ON feed_products(brand_id, is_active) WHERE is_active = true;

-- Indexes for journal_feed_items
CREATE INDEX idx_journal_feed_items_entry_id ON journal_feed_items(entry_id);
CREATE INDEX idx_journal_feed_items_user_id ON journal_feed_items(user_id);
CREATE INDEX idx_journal_feed_items_brand_product ON journal_feed_items(brand_id, product_id);
CREATE INDEX idx_journal_feed_items_created_at ON journal_feed_items(created_at DESC);

-- Indexes for user_feed_recent
CREATE INDEX idx_user_feed_recent_user_id ON user_feed_recent(user_id);
CREATE INDEX idx_user_feed_recent_last_used ON user_feed_recent(user_id, last_used_at DESC);

-- =============================================
-- SECTION 3: ROW LEVEL SECURITY (RLS)
-- =============================================

-- Enable RLS on all tables
ALTER TABLE feed_brands ENABLE ROW LEVEL SECURITY;
ALTER TABLE feed_products ENABLE ROW LEVEL SECURITY;
ALTER TABLE journal_feed_items ENABLE ROW LEVEL SECURITY;
ALTER TABLE user_feed_recent ENABLE ROW LEVEL SECURITY;

-- Feed brands policies (public read for all authenticated users)
CREATE POLICY "feed_brands_read_all" ON feed_brands
    FOR SELECT TO authenticated
    USING (true);

CREATE POLICY "feed_brands_admin_write" ON feed_brands
    FOR ALL TO authenticated
    USING (
        EXISTS (
            SELECT 1 FROM user_profiles
            WHERE user_profiles.id = auth.uid()
            AND user_profiles.type = 'admin'
        )
    );

-- Feed products policies (public read for all authenticated users)
CREATE POLICY "feed_products_read_all" ON feed_products
    FOR SELECT TO authenticated
    USING (true);

CREATE POLICY "feed_products_admin_write" ON feed_products
    FOR ALL TO authenticated
    USING (
        EXISTS (
            SELECT 1 FROM user_profiles
            WHERE user_profiles.id = auth.uid()
            AND user_profiles.type = 'admin'
        )
    );

-- Journal feed items policies (users can only see/edit their own)
CREATE POLICY "journal_feed_items_own_read" ON journal_feed_items
    FOR SELECT TO authenticated
    USING (user_id = auth.uid());

CREATE POLICY "journal_feed_items_own_insert" ON journal_feed_items
    FOR INSERT TO authenticated
    WITH CHECK (user_id = auth.uid());

CREATE POLICY "journal_feed_items_own_update" ON journal_feed_items
    FOR UPDATE TO authenticated
    USING (user_id = auth.uid())
    WITH CHECK (user_id = auth.uid());

CREATE POLICY "journal_feed_items_own_delete" ON journal_feed_items
    FOR DELETE TO authenticated
    USING (user_id = auth.uid());

-- User feed recent policies (users can only see/edit their own)
CREATE POLICY "user_feed_recent_own_read" ON user_feed_recent
    FOR SELECT TO authenticated
    USING (user_id = auth.uid());

CREATE POLICY "user_feed_recent_own_insert" ON user_feed_recent
    FOR INSERT TO authenticated
    WITH CHECK (user_id = auth.uid());

CREATE POLICY "user_feed_recent_own_update" ON user_feed_recent
    FOR UPDATE TO authenticated
    USING (user_id = auth.uid())
    WITH CHECK (user_id = auth.uid());

CREATE POLICY "user_feed_recent_own_delete" ON user_feed_recent
    FOR DELETE TO authenticated
    USING (user_id = auth.uid());

-- =============================================
-- SECTION 4: FUNCTIONS AND TRIGGERS
-- =============================================

-- Function to update timestamps
CREATE OR REPLACE FUNCTION update_updated_at()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Add update triggers
CREATE TRIGGER update_feed_brands_updated_at
    BEFORE UPDATE ON feed_brands
    FOR EACH ROW
    EXECUTE FUNCTION update_updated_at();

CREATE TRIGGER update_feed_products_updated_at
    BEFORE UPDATE ON feed_products
    FOR EACH ROW
    EXECUTE FUNCTION update_updated_at();

CREATE TRIGGER update_user_feed_recent_updated_at
    BEFORE UPDATE ON user_feed_recent
    FOR EACH ROW
    EXECUTE FUNCTION update_updated_at();

-- Function to update user's recent feeds when a journal entry is created
CREATE OR REPLACE FUNCTION update_user_recent_feeds()
RETURNS TRIGGER AS $$
BEGIN
    -- Only process if we have brand and product info
    IF NEW.brand_id IS NOT NULL AND NEW.product_id IS NOT NULL THEN
        INSERT INTO user_feed_recent (
            user_id,
            brand_id,
            product_id,
            is_hay,
            quantity,
            unit,
            last_used_at
        ) VALUES (
            NEW.user_id,
            NEW.brand_id,
            NEW.product_id,
            NEW.is_hay,
            NEW.quantity,
            NEW.unit,
            NOW()
        )
        ON CONFLICT (user_id, brand_id, product_id, is_hay)
        DO UPDATE SET
            quantity = NEW.quantity,
            unit = NEW.unit,
            last_used_at = NOW(),
            updated_at = NOW();
    END IF;
    
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Trigger to update recent feeds
CREATE TRIGGER update_recent_feeds_on_journal_insert
    AFTER INSERT ON journal_feed_items
    FOR EACH ROW
    EXECUTE FUNCTION update_user_recent_feeds();

-- =============================================
-- SECTION 5: SEED DATA - BRANDS
-- =============================================

-- Insert feed brands (idempotent using ON CONFLICT)
INSERT INTO feed_brands (name, is_active) VALUES
    ('Purina', true),
    ('Jacoby', true),
    ('Sunglo', true),
    ('Lindner', true),
    ('ADM/MoorMan''s ShowTec', true),
    ('Nutrena', true),
    ('Bluebonnet', true),
    ('Kalmbach', true),
    ('Umbarger', true),
    ('Show Rite', true)
ON CONFLICT (name) DO NOTHING;

-- =============================================
-- SECTION 6: SEED DATA - PRODUCTS
-- =============================================

-- Create temporary function for idempotent product insertion
CREATE OR REPLACE FUNCTION insert_feed_product(
    p_brand_name TEXT,
    p_product_name TEXT,
    p_species TEXT[],
    p_type TEXT
) RETURNS VOID AS $$
DECLARE
    v_brand_id UUID;
BEGIN
    -- Get brand ID
    SELECT id INTO v_brand_id FROM feed_brands WHERE name = p_brand_name;
    
    -- Insert product if brand exists
    IF v_brand_id IS NOT NULL THEN
        INSERT INTO feed_products (brand_id, name, species, type, is_active)
        VALUES (v_brand_id, p_product_name, p_species, p_type, true)
        ON CONFLICT (brand_id, name) DO NOTHING;
    END IF;
END;
$$ LANGUAGE plpgsql;

-- Purina Products
SELECT insert_feed_product('Purina', 'Honor Show Chow Fitter''s Edge', ARRAY['cattle', 'goat', 'sheep'], 'feed');
SELECT insert_feed_product('Purina', 'Honor Show Chow Impulse Goat R20', ARRAY['goat'], 'feed');
SELECT insert_feed_product('Purina', 'Honor Show Chow Grand 4-T-Fyer', ARRAY['cattle'], 'feed');
SELECT insert_feed_product('Purina', 'High Octane Champion Drive', ARRAY['cattle', 'swine', 'goat', 'sheep'], 'supplement');
SELECT insert_feed_product('Purina', 'Wind & Rain Storm Cattle Mineral', ARRAY['cattle'], 'mineral');
SELECT insert_feed_product('Purina', 'Honor Show Chow Full Tank', ARRAY['swine'], 'feed');

-- Jacoby Products
SELECT insert_feed_product('Jacoby', 'Supreme Lamb Grower', ARRAY['sheep'], 'feed');
SELECT insert_feed_product('Jacoby', 'Show Goat Developer', ARRAY['goat'], 'feed');
SELECT insert_feed_product('Jacoby', 'Steer Finisher Plus', ARRAY['cattle'], 'feed');
SELECT insert_feed_product('Jacoby', 'Premium Pig Starter', ARRAY['swine'], 'feed');
SELECT insert_feed_product('Jacoby', 'All-Species Show Mineral', ARRAY['cattle', 'goat', 'sheep', 'swine'], 'mineral');

-- Sunglo Products
SELECT insert_feed_product('Sunglo', 'Explode Supplement', ARRAY['swine'], 'supplement');
SELECT insert_feed_product('Sunglo', 'Show Pig Grower', ARRAY['swine'], 'feed');
SELECT insert_feed_product('Sunglo', 'Sunglo 40-20 Finisher', ARRAY['swine'], 'feed');
SELECT insert_feed_product('Sunglo', 'Muscle Max', ARRAY['swine'], 'supplement');
SELECT insert_feed_product('Sunglo', 'Show Pig Starter', ARRAY['swine'], 'feed');

-- Lindner Products
SELECT insert_feed_product('Lindner', '632 Special Delivery', ARRAY['swine'], 'feed');
SELECT insert_feed_product('Lindner', 'Show Pig Edge', ARRAY['swine'], 'feed');
SELECT insert_feed_product('Lindner', 'Alpha 7 Complete', ARRAY['swine'], 'feed');
SELECT insert_feed_product('Lindner', 'Ultra Full', ARRAY['swine'], 'supplement');
SELECT insert_feed_product('Lindner', 'Show Pig Power Pack', ARRAY['swine'], 'mineral');

-- ADM/MoorMan's ShowTec Products
SELECT insert_feed_product('ADM/MoorMan''s ShowTec', 'Lamb Grower', ARRAY['sheep'], 'feed');
SELECT insert_feed_product('ADM/MoorMan''s ShowTec', 'Goat Grower Plus', ARRAY['goat'], 'feed');
SELECT insert_feed_product('ADM/MoorMan''s ShowTec', 'Cattle Complete', ARRAY['cattle'], 'feed');
SELECT insert_feed_product('ADM/MoorMan''s ShowTec', 'EnerG II', ARRAY['cattle', 'goat', 'sheep'], 'supplement');
SELECT insert_feed_product('ADM/MoorMan''s ShowTec', 'ShowTec Pig Starter', ARRAY['swine'], 'feed');
SELECT insert_feed_product('ADM/MoorMan''s ShowTec', 'Amino Gain', ARRAY['cattle', 'goat', 'sheep', 'swine'], 'supplement');

-- Nutrena Products
SELECT insert_feed_product('Nutrena', 'Country Feeds 18% Lamb Grower', ARRAY['sheep'], 'feed');
SELECT insert_feed_product('Nutrena', 'Nature Smart Goat Feed', ARRAY['goat'], 'feed');
SELECT insert_feed_product('Nutrena', 'Country Feeds Cattle Grower', ARRAY['cattle'], 'feed');
SELECT insert_feed_product('Nutrena', 'ProForce Senior', ARRAY['cattle'], 'supplement');
SELECT insert_feed_product('Nutrena', 'Country Feeds Pig & Sow', ARRAY['swine'], 'feed');

-- Bluebonnet Products
SELECT insert_feed_product('Bluebonnet', 'Intense 17% Lamb', ARRAY['sheep'], 'feed');
SELECT insert_feed_product('Bluebonnet', 'Show Goat 17%', ARRAY['goat'], 'feed');
SELECT insert_feed_product('Bluebonnet', 'Calf Creep 16%', ARRAY['cattle'], 'feed');
SELECT insert_feed_product('Bluebonnet', 'Pig Starter 21%', ARRAY['swine'], 'feed');
SELECT insert_feed_product('Bluebonnet', 'Show Supplement', ARRAY['cattle', 'goat', 'sheep'], 'supplement');

-- Kalmbach Products
SELECT insert_feed_product('Kalmbach', 'Show Lamb 18% DX', ARRAY['sheep'], 'feed');
SELECT insert_feed_product('Kalmbach', 'Show Goat 17%', ARRAY['goat'], 'feed');
SELECT insert_feed_product('Kalmbach', 'Start-to-Finish Cattle', ARRAY['cattle'], 'feed');
SELECT insert_feed_product('Kalmbach', 'Start Right Swine', ARRAY['swine'], 'feed');
SELECT insert_feed_product('Kalmbach', 'Show Elite Mineral', ARRAY['cattle', 'goat', 'sheep'], 'mineral');
SELECT insert_feed_product('Kalmbach', 'Muscle Builder Plus', ARRAY['cattle', 'goat', 'sheep', 'swine'], 'supplement');

-- Umbarger Products
SELECT insert_feed_product('Umbarger', 'Show Lamb Supreme', ARRAY['sheep'], 'feed');
SELECT insert_feed_product('Umbarger', 'Show Goat Complete', ARRAY['goat'], 'feed');
SELECT insert_feed_product('Umbarger', 'Beef Finisher', ARRAY['cattle'], 'feed');
SELECT insert_feed_product('Umbarger', 'Show Pig Developer', ARRAY['swine'], 'feed');
SELECT insert_feed_product('Umbarger', 'All Show Mineral', ARRAY['cattle', 'goat', 'sheep', 'swine'], 'mineral');

-- Show Rite Products
SELECT insert_feed_product('Show Rite', 'EXL 709 Lamb', ARRAY['sheep'], 'feed');
SELECT insert_feed_product('Show Rite', 'Rite Tyme Goat', ARRAY['goat'], 'feed');
SELECT insert_feed_product('Show Rite', 'Full Throttle Cattle', ARRAY['cattle'], 'feed');
SELECT insert_feed_product('Show Rite', 'Pig Kicker', ARRAY['swine'], 'feed');
SELECT insert_feed_product('Show Rite', 'Showplex Multi-Species', ARRAY['cattle', 'goat', 'sheep', 'swine'], 'supplement');
SELECT insert_feed_product('Show Rite', 'Mineral Max', ARRAY['cattle', 'goat', 'sheep'], 'mineral');

-- Drop the temporary function
DROP FUNCTION IF EXISTS insert_feed_product;

-- =============================================
-- SECTION 7: HELPER VIEWS
-- =============================================

-- View for commonly used feeds by user
CREATE OR REPLACE VIEW v_user_common_feeds AS
SELECT 
    ufr.user_id,
    fb.name as brand_name,
    fp.name as product_name,
    fp.species,
    fp.type,
    ufr.is_hay,
    ufr.quantity,
    ufr.unit,
    ufr.last_used_at,
    COUNT(*) OVER (PARTITION BY ufr.user_id) as total_recent_feeds
FROM user_feed_recent ufr
LEFT JOIN feed_brands fb ON fb.id = ufr.brand_id
LEFT JOIN feed_products fp ON fp.id = ufr.product_id
WHERE ufr.last_used_at > NOW() - INTERVAL '30 days'
ORDER BY ufr.user_id, ufr.last_used_at DESC;

-- View for feed usage statistics
CREATE OR REPLACE VIEW v_feed_usage_stats AS
SELECT 
    fb.name as brand_name,
    fp.name as product_name,
    fp.species,
    fp.type,
    COUNT(DISTINCT jfi.user_id) as unique_users,
    COUNT(*) as total_uses,
    AVG(jfi.quantity) as avg_quantity,
    MAX(jfi.created_at) as last_used
FROM journal_feed_items jfi
JOIN feed_brands fb ON fb.id = jfi.brand_id
JOIN feed_products fp ON fp.id = jfi.product_id
WHERE jfi.created_at > NOW() - INTERVAL '90 days'
GROUP BY fb.name, fp.name, fp.species, fp.type
ORDER BY total_uses DESC;

-- =============================================
-- SECTION 8: GRANT PERMISSIONS
-- =============================================

-- Grant appropriate permissions to authenticated users
GRANT SELECT ON feed_brands TO authenticated;
GRANT SELECT ON feed_products TO authenticated;
GRANT ALL ON journal_feed_items TO authenticated;
GRANT ALL ON user_feed_recent TO authenticated;
GRANT SELECT ON v_user_common_feeds TO authenticated;
GRANT SELECT ON v_feed_usage_stats TO authenticated;

-- =============================================
-- SECTION 9: DATA VALIDATION
-- =============================================

-- Validate seed data was inserted correctly
DO $$
DECLARE
    brand_count INTEGER;
    product_count INTEGER;
BEGIN
    SELECT COUNT(*) INTO brand_count FROM feed_brands;
    SELECT COUNT(*) INTO product_count FROM feed_products;
    
    IF brand_count < 10 THEN
        RAISE WARNING 'Expected at least 10 brands, found %', brand_count;
    ELSE
        RAISE NOTICE 'Successfully inserted % brands', brand_count;
    END IF;
    
    IF product_count < 50 THEN
        RAISE WARNING 'Expected at least 50 products, found %', product_count;
    ELSE
        RAISE NOTICE 'Successfully inserted % products', product_count;
    END IF;
    
    -- Log summary
    RAISE NOTICE 'Feed feature migration completed successfully!';
    RAISE NOTICE 'Tables created: feed_brands, feed_products, journal_feed_items, user_feed_recent';
    RAISE NOTICE 'RLS policies enabled for all tables';
    RAISE NOTICE 'Indexes created for optimal performance';
END;
$$;

-- =============================================
-- END OF MIGRATION
-- =============================================