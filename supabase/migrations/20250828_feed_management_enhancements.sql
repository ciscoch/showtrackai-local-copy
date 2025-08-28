-- =============================================
-- FEED MANAGEMENT ENHANCEMENTS MIGRATION
-- =============================================
-- Description: Enhanced feed management with custom brands, products, inventory, and cost tracking
-- Features: User custom feeds, inventory management, FCR tracking, cost analytics
-- Author: ShowTrackAI Development Team
-- Date: 2025-08-28
-- =============================================

-- =============================================
-- SECTION 1: ADD USER OWNERSHIP TO FEED BRANDS AND PRODUCTS
-- =============================================

-- Add user_id to feed_brands for custom brands
ALTER TABLE feed_brands 
ADD COLUMN IF NOT EXISTS user_id UUID REFERENCES auth.users(id) ON DELETE CASCADE,
ADD COLUMN IF NOT EXISTS is_custom BOOLEAN DEFAULT false,
ADD COLUMN IF NOT EXISTS description TEXT,
ADD COLUMN IF NOT EXISTS manufacturer_website TEXT,
ADD COLUMN IF NOT EXISTS contact_info JSONB;

-- Add user_id and additional fields to feed_products for custom products  
ALTER TABLE feed_products
ADD COLUMN IF NOT EXISTS user_id UUID REFERENCES auth.users(id) ON DELETE CASCADE,
ADD COLUMN IF NOT EXISTS is_custom BOOLEAN DEFAULT false,
ADD COLUMN IF NOT EXISTS description TEXT,
ADD COLUMN IF NOT EXISTS protein_percentage DECIMAL(5,2),
ADD COLUMN IF NOT EXISTS fat_percentage DECIMAL(5,2),
ADD COLUMN IF NOT EXISTS fiber_percentage DECIMAL(5,2),
ADD COLUMN IF NOT EXISTS nutritional_info JSONB,
ADD COLUMN IF NOT EXISTS default_cost_per_unit DECIMAL(10,2),
ADD COLUMN IF NOT EXISTS default_unit TEXT DEFAULT 'lbs',
ADD COLUMN IF NOT EXISTS packaging_size DECIMAL(10,2),
ADD COLUMN IF NOT EXISTS packaging_unit TEXT,
ADD COLUMN IF NOT EXISTS barcode TEXT,
ADD COLUMN IF NOT EXISTS sku TEXT;

-- =============================================
-- SECTION 2: FEED INVENTORY MANAGEMENT
-- =============================================

-- Create feed inventory table
CREATE TABLE IF NOT EXISTS feed_inventory (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    brand_id UUID REFERENCES feed_brands(id) ON DELETE SET NULL,
    product_id UUID REFERENCES feed_products(id) ON DELETE SET NULL,
    
    -- Inventory details
    current_quantity DECIMAL(10,2) NOT NULL DEFAULT 0,
    unit TEXT NOT NULL DEFAULT 'lbs',
    minimum_quantity DECIMAL(10,2),
    maximum_quantity DECIMAL(10,2),
    
    -- Location tracking
    storage_location TEXT,
    bin_number TEXT,
    
    -- Cost tracking
    last_purchase_date DATE,
    last_purchase_price DECIMAL(10,2),
    average_cost DECIMAL(10,2),
    total_value DECIMAL(10,2) GENERATED ALWAYS AS (current_quantity * COALESCE(average_cost, 0)) STORED,
    
    -- Metadata
    notes TEXT,
    created_at TIMESTAMPTZ DEFAULT NOW() NOT NULL,
    updated_at TIMESTAMPTZ DEFAULT NOW() NOT NULL,
    
    -- Ensure unique inventory per user/product
    CONSTRAINT feed_inventory_unique UNIQUE (user_id, brand_id, product_id)
);

-- Create feed purchases table
CREATE TABLE IF NOT EXISTS feed_purchases (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    inventory_id UUID REFERENCES feed_inventory(id) ON DELETE CASCADE,
    brand_id UUID REFERENCES feed_brands(id) ON DELETE SET NULL,
    product_id UUID REFERENCES feed_products(id) ON DELETE SET NULL,
    
    -- Purchase details
    purchase_date DATE NOT NULL DEFAULT CURRENT_DATE,
    quantity DECIMAL(10,2) NOT NULL,
    unit TEXT NOT NULL DEFAULT 'lbs',
    unit_price DECIMAL(10,2) NOT NULL,
    total_cost DECIMAL(10,2) GENERATED ALWAYS AS (quantity * unit_price) STORED,
    
    -- Vendor information
    vendor_name TEXT,
    vendor_contact TEXT,
    invoice_number TEXT,
    
    -- Tracking
    lot_number TEXT,
    expiration_date DATE,
    
    -- Metadata
    notes TEXT,
    receipt_url TEXT,
    created_at TIMESTAMPTZ DEFAULT NOW() NOT NULL,
    updated_at TIMESTAMPTZ DEFAULT NOW() NOT NULL
);

-- =============================================
-- SECTION 3: FEED CONVERSION RATIO (FCR) TRACKING
-- =============================================

-- Create FCR tracking table
CREATE TABLE IF NOT EXISTS feed_conversion_tracking (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    animal_id UUID REFERENCES animals(id) ON DELETE CASCADE,
    
    -- Period tracking
    start_date DATE NOT NULL,
    end_date DATE NOT NULL,
    
    -- Weight tracking
    start_weight DECIMAL(10,2) NOT NULL,
    end_weight DECIMAL(10,2) NOT NULL,
    weight_gain DECIMAL(10,2) GENERATED ALWAYS AS (end_weight - start_weight) STORED,
    
    -- Feed consumption
    total_feed_consumed DECIMAL(10,2) NOT NULL,
    feed_unit TEXT NOT NULL DEFAULT 'lbs',
    
    -- FCR calculation
    feed_conversion_ratio DECIMAL(5,2) GENERATED ALWAYS AS (
        CASE 
            WHEN (end_weight - start_weight) > 0 
            THEN total_feed_consumed / (end_weight - start_weight)
            ELSE NULL
        END
    ) STORED,
    
    -- Cost tracking
    total_feed_cost DECIMAL(10,2),
    cost_per_pound_gain DECIMAL(10,2) GENERATED ALWAYS AS (
        CASE 
            WHEN (end_weight - start_weight) > 0 
            THEN total_feed_cost / (end_weight - start_weight)
            ELSE NULL
        END
    ) STORED,
    
    -- Metadata
    notes TEXT,
    created_at TIMESTAMPTZ DEFAULT NOW() NOT NULL,
    updated_at TIMESTAMPTZ DEFAULT NOW() NOT NULL
);

-- =============================================
-- SECTION 4: FEED ANALYTICS VIEWS
-- =============================================

-- View for feed cost analytics
CREATE OR REPLACE VIEW v_feed_cost_analytics AS
SELECT 
    u.id as user_id,
    DATE_TRUNC('month', fp.purchase_date) as month,
    fb.name as brand_name,
    fprod.name as product_name,
    fprod.type as feed_type,
    SUM(fp.quantity) as total_quantity,
    SUM(fp.total_cost) as total_cost,
    AVG(fp.unit_price) as avg_unit_price,
    COUNT(*) as purchase_count
FROM feed_purchases fp
JOIN auth.users u ON u.id = fp.user_id
LEFT JOIN feed_brands fb ON fb.id = fp.brand_id
LEFT JOIN feed_products fprod ON fprod.id = fp.product_id
GROUP BY u.id, DATE_TRUNC('month', fp.purchase_date), fb.name, fprod.name, fprod.type;

-- View for FCR performance metrics
CREATE OR REPLACE VIEW v_fcr_performance AS
SELECT 
    fct.user_id,
    a.name as animal_name,
    a.species,
    fct.start_date,
    fct.end_date,
    fct.weight_gain,
    fct.total_feed_consumed,
    fct.feed_conversion_ratio,
    fct.cost_per_pound_gain,
    CASE 
        WHEN fct.feed_conversion_ratio < 3.0 THEN 'Excellent'
        WHEN fct.feed_conversion_ratio < 4.0 THEN 'Good'
        WHEN fct.feed_conversion_ratio < 5.0 THEN 'Average'
        ELSE 'Needs Improvement'
    END as fcr_rating
FROM feed_conversion_tracking fct
LEFT JOIN animals a ON a.id = fct.animal_id
ORDER BY fct.end_date DESC;

-- View for inventory status
CREATE OR REPLACE VIEW v_inventory_status AS
SELECT 
    fi.user_id,
    fb.name as brand_name,
    fp.name as product_name,
    fi.current_quantity,
    fi.unit,
    fi.minimum_quantity,
    CASE 
        WHEN fi.current_quantity <= COALESCE(fi.minimum_quantity, 0) THEN 'Low Stock'
        WHEN fi.current_quantity >= COALESCE(fi.maximum_quantity, 999999) THEN 'Overstocked'
        ELSE 'Normal'
    END as stock_status,
    fi.total_value,
    fi.storage_location,
    fi.last_purchase_date,
    fi.average_cost
FROM feed_inventory fi
LEFT JOIN feed_brands fb ON fb.id = fi.brand_id
LEFT JOIN feed_products fp ON fp.id = fi.product_id
WHERE fi.current_quantity > 0;

-- =============================================
-- SECTION 5: ENHANCED JOURNAL FEED TRACKING
-- =============================================

-- Add fields to journal_feed_items for better tracking
ALTER TABLE journal_feed_items
ADD COLUMN IF NOT EXISTS cost_per_unit DECIMAL(10,2),
ADD COLUMN IF NOT EXISTS total_cost DECIMAL(10,2) GENERATED ALWAYS AS (quantity * COALESCE(cost_per_unit, 0)) STORED,
ADD COLUMN IF NOT EXISTS animal_id UUID REFERENCES animals(id) ON DELETE CASCADE,
ADD COLUMN IF NOT EXISTS fed_by TEXT,
ADD COLUMN IF NOT EXISTS feeding_time TIME,
ADD COLUMN IF NOT EXISTS feeding_method TEXT CHECK (feeding_method IN ('hand', 'automatic', 'self-feeder', 'other'));

-- =============================================
-- SECTION 6: ROW LEVEL SECURITY UPDATES
-- =============================================

-- Drop existing policies if they exist
DROP POLICY IF EXISTS "feed_brands_read_all" ON feed_brands;
DROP POLICY IF EXISTS "feed_brands_admin_write" ON feed_brands;
DROP POLICY IF EXISTS "feed_products_read_all" ON feed_products;
DROP POLICY IF EXISTS "feed_products_admin_write" ON feed_products;

-- Updated feed brands policies
CREATE POLICY "feed_brands_read" ON feed_brands
    FOR SELECT TO authenticated
    USING (is_custom = false OR user_id = auth.uid());

CREATE POLICY "feed_brands_insert" ON feed_brands
    FOR INSERT TO authenticated
    WITH CHECK (user_id = auth.uid() AND is_custom = true);

CREATE POLICY "feed_brands_update" ON feed_brands
    FOR UPDATE TO authenticated
    USING (user_id = auth.uid() AND is_custom = true)
    WITH CHECK (user_id = auth.uid() AND is_custom = true);

CREATE POLICY "feed_brands_delete" ON feed_brands
    FOR DELETE TO authenticated
    USING (user_id = auth.uid() AND is_custom = true);

-- Updated feed products policies
CREATE POLICY "feed_products_read" ON feed_products
    FOR SELECT TO authenticated
    USING (is_custom = false OR user_id = auth.uid());

CREATE POLICY "feed_products_insert" ON feed_products
    FOR INSERT TO authenticated
    WITH CHECK (user_id = auth.uid() AND is_custom = true);

CREATE POLICY "feed_products_update" ON feed_products
    FOR UPDATE TO authenticated
    USING (user_id = auth.uid() AND is_custom = true)
    WITH CHECK (user_id = auth.uid() AND is_custom = true);

CREATE POLICY "feed_products_delete" ON feed_products
    FOR DELETE TO authenticated
    USING (user_id = auth.uid() AND is_custom = true);

-- Feed inventory policies
ALTER TABLE feed_inventory ENABLE ROW LEVEL SECURITY;

CREATE POLICY "feed_inventory_own" ON feed_inventory
    FOR ALL TO authenticated
    USING (user_id = auth.uid())
    WITH CHECK (user_id = auth.uid());

-- Feed purchases policies
ALTER TABLE feed_purchases ENABLE ROW LEVEL SECURITY;

CREATE POLICY "feed_purchases_own" ON feed_purchases
    FOR ALL TO authenticated
    USING (user_id = auth.uid())
    WITH CHECK (user_id = auth.uid());

-- FCR tracking policies
ALTER TABLE feed_conversion_tracking ENABLE ROW LEVEL SECURITY;

CREATE POLICY "fcr_tracking_own" ON feed_conversion_tracking
    FOR ALL TO authenticated
    USING (user_id = auth.uid())
    WITH CHECK (user_id = auth.uid());

-- =============================================
-- SECTION 7: INDEXES FOR PERFORMANCE
-- =============================================

-- Inventory indexes
CREATE INDEX IF NOT EXISTS idx_feed_inventory_user_id ON feed_inventory(user_id);
CREATE INDEX IF NOT EXISTS idx_feed_inventory_product ON feed_inventory(brand_id, product_id);
CREATE INDEX IF NOT EXISTS idx_feed_inventory_quantity ON feed_inventory(current_quantity) WHERE current_quantity > 0;

-- Purchase indexes
CREATE INDEX IF NOT EXISTS idx_feed_purchases_user_id ON feed_purchases(user_id);
CREATE INDEX IF NOT EXISTS idx_feed_purchases_date ON feed_purchases(purchase_date DESC);
CREATE INDEX IF NOT EXISTS idx_feed_purchases_inventory ON feed_purchases(inventory_id);

-- FCR tracking indexes
CREATE INDEX IF NOT EXISTS idx_fcr_tracking_user_id ON feed_conversion_tracking(user_id);
CREATE INDEX IF NOT EXISTS idx_fcr_tracking_animal ON feed_conversion_tracking(animal_id);
CREATE INDEX IF NOT EXISTS idx_fcr_tracking_dates ON feed_conversion_tracking(end_date DESC);

-- Enhanced journal feed items indexes
CREATE INDEX IF NOT EXISTS idx_journal_feed_items_animal ON journal_feed_items(animal_id);
CREATE INDEX IF NOT EXISTS idx_journal_feed_items_cost ON journal_feed_items(total_cost) WHERE total_cost > 0;

-- =============================================
-- SECTION 8: HELPER FUNCTIONS
-- =============================================

-- Function to update inventory when feed is used
CREATE OR REPLACE FUNCTION update_feed_inventory_on_use()
RETURNS TRIGGER AS $$
BEGIN
    -- Decrease inventory when feed is used
    UPDATE feed_inventory
    SET current_quantity = current_quantity - NEW.quantity,
        updated_at = NOW()
    WHERE user_id = NEW.user_id
        AND brand_id = NEW.brand_id
        AND product_id = NEW.product_id
        AND current_quantity >= NEW.quantity;
    
    -- If update affected no rows, inventory might be insufficient
    IF NOT FOUND THEN
        RAISE WARNING 'Insufficient inventory for feed item %', NEW.id;
    END IF;
    
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Function to update inventory when purchases are made
CREATE OR REPLACE FUNCTION update_feed_inventory_on_purchase()
RETURNS TRIGGER AS $$
BEGIN
    -- Insert or update inventory
    INSERT INTO feed_inventory (
        user_id,
        brand_id,
        product_id,
        current_quantity,
        unit,
        last_purchase_date,
        last_purchase_price,
        average_cost
    ) VALUES (
        NEW.user_id,
        NEW.brand_id,
        NEW.product_id,
        NEW.quantity,
        NEW.unit,
        NEW.purchase_date,
        NEW.unit_price,
        NEW.unit_price
    )
    ON CONFLICT (user_id, brand_id, product_id)
    DO UPDATE SET
        current_quantity = feed_inventory.current_quantity + NEW.quantity,
        last_purchase_date = NEW.purchase_date,
        last_purchase_price = NEW.unit_price,
        average_cost = (
            (feed_inventory.current_quantity * COALESCE(feed_inventory.average_cost, 0) + NEW.total_cost) /
            (feed_inventory.current_quantity + NEW.quantity)
        ),
        updated_at = NOW();
    
    -- Update inventory_id in the purchase record
    UPDATE feed_purchases
    SET inventory_id = (
        SELECT id FROM feed_inventory
        WHERE user_id = NEW.user_id
            AND brand_id = NEW.brand_id
            AND product_id = NEW.product_id
    )
    WHERE id = NEW.id;
    
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Create triggers
CREATE TRIGGER update_inventory_on_feed_use
    AFTER INSERT ON journal_feed_items
    FOR EACH ROW
    WHEN (NEW.brand_id IS NOT NULL AND NEW.product_id IS NOT NULL)
    EXECUTE FUNCTION update_feed_inventory_on_use();

CREATE TRIGGER update_inventory_on_purchase
    AFTER INSERT ON feed_purchases
    FOR EACH ROW
    EXECUTE FUNCTION update_feed_inventory_on_purchase();

-- =============================================
-- SECTION 9: GRANT PERMISSIONS
-- =============================================

GRANT ALL ON feed_inventory TO authenticated;
GRANT ALL ON feed_purchases TO authenticated;
GRANT ALL ON feed_conversion_tracking TO authenticated;
GRANT SELECT ON v_feed_cost_analytics TO authenticated;
GRANT SELECT ON v_fcr_performance TO authenticated;
GRANT SELECT ON v_inventory_status TO authenticated;

-- =============================================
-- SECTION 10: MIGRATE EXISTING DATA
-- =============================================

-- Mark all existing brands and products as system defaults (not custom)
UPDATE feed_brands SET is_custom = false WHERE is_custom IS NULL;
UPDATE feed_products SET is_custom = false WHERE is_custom IS NULL;

-- =============================================
-- END OF MIGRATION
-- =============================================

-- Validation
DO $$
BEGIN
    RAISE NOTICE 'Feed Management Enhancements Migration Completed Successfully!';
    RAISE NOTICE 'New features added:';
    RAISE NOTICE '- Custom brands and products with user ownership';
    RAISE NOTICE '- Feed inventory management with automatic tracking';
    RAISE NOTICE '- Feed purchase tracking with cost analytics';
    RAISE NOTICE '- Feed Conversion Ratio (FCR) tracking';
    RAISE NOTICE '- Enhanced journal feed items with cost tracking';
    RAISE NOTICE '- Analytics views for cost, FCR, and inventory';
END;
$$;