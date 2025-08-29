#!/bin/bash

# Verification script for financial analysis cache table
echo "Financial Analysis Cache Table Verification"
echo "==========================================="

# Check if table exists
echo " Checking if financial_analysis_cache table exists..."
psql "$DATABASE_URL" -c "SELECT EXISTS (
   SELECT FROM information_schema.tables 
   WHERE table_schema = 'public' 
   AND table_name = 'financial_analysis_cache'
);"

# Check columns
echo ""
echo " Checking table columns..."
psql "$DATABASE_URL" -c "SELECT column_name, data_type, is_nullable, column_default 
FROM information_schema.columns 
WHERE table_name = 'financial_analysis_cache' 
ORDER BY ordinal_position;"

# Check indexes
echo ""
echo " Checking indexes..."
psql "$DATABASE_URL" -c "SELECT indexname, indexdef 
FROM pg_indexes 
WHERE tablename = 'financial_analysis_cache';"

# Check RLS policies
echo ""
echo " Checking RLS policies..."
psql "$DATABASE_URL" -c "SELECT policyname, cmd, permissive, roles 
FROM pg_policies 
WHERE tablename = 'financial_analysis_cache';"

# Check views
echo ""
echo " Checking views..."
psql "$DATABASE_URL" -c "SELECT table_name 
FROM information_schema.views 
WHERE table_schema = 'public' 
AND table_name LIKE '%financial_analysis%';"

echo ""
echo "Verification complete!"