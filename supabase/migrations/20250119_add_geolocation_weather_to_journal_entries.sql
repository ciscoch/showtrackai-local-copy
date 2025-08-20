-- Migration: Add geolocation and weather fields to journal_entries table
-- Created: 2025-01-19
-- Description: Adds location tracking and weather data fields to enhance journal entries
--              with contextual environmental information for agricultural tracking

-- Add geolocation columns
ALTER TABLE journal_entries 
ADD COLUMN IF NOT EXISTS location_latitude DECIMAL(10, 8) NULL,
ADD COLUMN IF NOT EXISTS location_longitude DECIMAL(11, 8) NULL,
ADD COLUMN IF NOT EXISTS location_address TEXT NULL,
ADD COLUMN IF NOT EXISTS location_name VARCHAR(255) NULL,
ADD COLUMN IF NOT EXISTS location_accuracy DECIMAL(10, 2) NULL,
ADD COLUMN IF NOT EXISTS location_captured_at TIMESTAMP WITH TIME ZONE NULL;

-- Add weather columns
ALTER TABLE journal_entries
ADD COLUMN IF NOT EXISTS weather_temperature DECIMAL(5, 2) NULL,
ADD COLUMN IF NOT EXISTS weather_condition VARCHAR(100) NULL,
ADD COLUMN IF NOT EXISTS weather_humidity INTEGER NULL,
ADD COLUMN IF NOT EXISTS weather_wind_speed DECIMAL(6, 2) NULL,
ADD COLUMN IF NOT EXISTS weather_description TEXT NULL;

-- Add comments for documentation
COMMENT ON COLUMN journal_entries.location_latitude IS 'Latitude coordinate where the journal entry was created';
COMMENT ON COLUMN journal_entries.location_longitude IS 'Longitude coordinate where the journal entry was created';
COMMENT ON COLUMN journal_entries.location_address IS 'Human-readable address of the location';
COMMENT ON COLUMN journal_entries.location_name IS 'Name of the location (e.g., barn name, field name)';
COMMENT ON COLUMN journal_entries.location_accuracy IS 'GPS accuracy in meters';
COMMENT ON COLUMN journal_entries.location_captured_at IS 'Timestamp when the location was captured';

COMMENT ON COLUMN journal_entries.weather_temperature IS 'Temperature in Fahrenheit at the time of entry';
COMMENT ON COLUMN journal_entries.weather_condition IS 'Main weather condition (e.g., Clear, Cloudy, Rain)';
COMMENT ON COLUMN journal_entries.weather_humidity IS 'Humidity percentage (0-100)';
COMMENT ON COLUMN journal_entries.weather_wind_speed IS 'Wind speed in miles per hour';
COMMENT ON COLUMN journal_entries.weather_description IS 'Detailed weather description';

-- Create indexes for efficient querying
CREATE INDEX IF NOT EXISTS idx_journal_entries_location_coords 
ON journal_entries(location_latitude, location_longitude) 
WHERE location_latitude IS NOT NULL AND location_longitude IS NOT NULL;

CREATE INDEX IF NOT EXISTS idx_journal_entries_location_captured_at 
ON journal_entries(location_captured_at) 
WHERE location_captured_at IS NOT NULL;

CREATE INDEX IF NOT EXISTS idx_journal_entries_weather_condition 
ON journal_entries(weather_condition) 
WHERE weather_condition IS NOT NULL;

-- Create a spatial index for geographic queries (if PostGIS extension is available)
-- Uncomment the following lines if PostGIS is enabled in your Supabase instance:
/*
-- Enable PostGIS if not already enabled
CREATE EXTENSION IF NOT EXISTS postgis;

-- Add a geography column for spatial queries
ALTER TABLE journal_entries 
ADD COLUMN IF NOT EXISTS location_point GEOGRAPHY(POINT, 4326) 
GENERATED ALWAYS AS (
    CASE 
        WHEN location_latitude IS NOT NULL AND location_longitude IS NOT NULL 
        THEN ST_SetSRID(ST_MakePoint(location_longitude, location_latitude), 4326)::geography
        ELSE NULL
    END
) STORED;

-- Create spatial index
CREATE INDEX IF NOT EXISTS idx_journal_entries_location_point 
ON journal_entries USING GIST(location_point);

COMMENT ON COLUMN journal_entries.location_point IS 'PostGIS geography point for spatial queries';
*/

-- Add check constraints for data validation
ALTER TABLE journal_entries
ADD CONSTRAINT chk_location_latitude CHECK (
    location_latitude IS NULL OR (location_latitude >= -90 AND location_latitude <= 90)
),
ADD CONSTRAINT chk_location_longitude CHECK (
    location_longitude IS NULL OR (location_longitude >= -180 AND location_longitude <= 180)
),
ADD CONSTRAINT chk_weather_humidity CHECK (
    weather_humidity IS NULL OR (weather_humidity >= 0 AND weather_humidity <= 100)
),
ADD CONSTRAINT chk_weather_wind_speed CHECK (
    weather_wind_speed IS NULL OR weather_wind_speed >= 0
),
ADD CONSTRAINT chk_location_accuracy CHECK (
    location_accuracy IS NULL OR location_accuracy >= 0
);

-- Create a function to automatically set location_captured_at if location is provided
CREATE OR REPLACE FUNCTION set_location_captured_at()
RETURNS TRIGGER AS $$
BEGIN
    -- If location coordinates are being set and location_captured_at is not set, set it to now
    IF (NEW.location_latitude IS NOT NULL OR NEW.location_longitude IS NOT NULL) 
       AND NEW.location_captured_at IS NULL THEN
        NEW.location_captured_at = CURRENT_TIMESTAMP;
    END IF;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Create trigger to automatically set location_captured_at
DROP TRIGGER IF EXISTS trigger_set_location_captured_at ON journal_entries;
CREATE TRIGGER trigger_set_location_captured_at
    BEFORE INSERT OR UPDATE ON journal_entries
    FOR EACH ROW
    EXECUTE FUNCTION set_location_captured_at();

-- Add RLS (Row Level Security) policies if RLS is enabled
-- These ensure users can only see and modify their own location/weather data
/*
-- Uncomment if RLS is enabled on journal_entries table:
ALTER TABLE journal_entries ENABLE ROW LEVEL SECURITY;

-- Policy for viewing own journal entries with location/weather data
CREATE POLICY "Users can view own journal entries with location data" 
ON journal_entries FOR SELECT 
USING (auth.uid() = user_id);

-- Policy for inserting journal entries with location/weather data
CREATE POLICY "Users can insert own journal entries with location data" 
ON journal_entries FOR INSERT 
WITH CHECK (auth.uid() = user_id);

-- Policy for updating own journal entries with location/weather data
CREATE POLICY "Users can update own journal entries with location data" 
ON journal_entries FOR UPDATE 
USING (auth.uid() = user_id)
WITH CHECK (auth.uid() = user_id);
*/

-- Grant necessary permissions (adjust based on your user roles)
-- GRANT SELECT, INSERT, UPDATE ON journal_entries TO authenticated;
-- GRANT USAGE ON SCHEMA public TO authenticated;

-- Add migration completion message
DO $$
BEGIN
    RAISE NOTICE 'Migration completed: Added geolocation and weather fields to journal_entries table';
    RAISE NOTICE 'New columns added:';
    RAISE NOTICE '  - Location: latitude, longitude, address, name, accuracy, captured_at';
    RAISE NOTICE '  - Weather: temperature, condition, humidity, wind_speed, description';
    RAISE NOTICE 'Indexes created for efficient querying';
    RAISE NOTICE 'Check constraints added for data validation';
    RAISE NOTICE 'Trigger added to auto-set location_captured_at timestamp';
END $$;