-- =====================================================================
-- Weight Tracker Post-Deployment Testing Script
-- =====================================================================
-- Run this AFTER successful migration to test functionality
-- Note: Requires actual animal_id and user_id from your database
-- Author: ShowTrackAI Database Team
-- Date: 2025-01-28
-- =====================================================================

-- IMPORTANT: Replace these variables with actual IDs from your database
DO $$
DECLARE
    test_animal_id UUID;
    test_user_id UUID;
    test_weight_id UUID;
    test_goal_id UUID;
    v_result RECORD;
BEGIN
    -- =================================================================
    -- SETUP: Get test data (modify this section with your actual IDs)
    -- =================================================================
    
    -- Option 1: Use existing animal (recommended)
    SELECT id, user_id INTO test_animal_id, test_user_id
    FROM animals
    WHERE user_id = auth.uid()
    LIMIT 1;
    
    -- Option 2: If no animals exist, you'll need to create one first
    IF test_animal_id IS NULL THEN
        RAISE NOTICE 'No animals found for current user. Please create an animal first.';
        RETURN;
    END IF;
    
    RAISE NOTICE 'Testing with Animal ID: %, User ID: %', test_animal_id, test_user_id;
    
    -- =================================================================
    -- TEST 1: Insert Weight Records
    -- =================================================================
    RAISE NOTICE '';
    RAISE NOTICE '=== TEST 1: Weight Record Creation ===';
    
    -- Insert first weight (baseline)
    INSERT INTO weights (
        animal_id,
        user_id,
        recorded_by,
        weight_value,
        weight_unit,
        measurement_date,
        measurement_method,
        notes
    ) VALUES (
        test_animal_id,
        test_user_id,
        test_user_id,
        100.0,
        'lb',
        CURRENT_DATE - INTERVAL '30 days',
        'digital_scale',
        'Initial test weight'
    ) RETURNING id INTO test_weight_id;
    
    RAISE NOTICE '✓ First weight created: %', test_weight_id;
    
    -- Insert second weight (to test ADG calculation)
    INSERT INTO weights (
        animal_id,
        user_id,
        recorded_by,
        weight_value,
        weight_unit,
        measurement_date,
        measurement_method,
        notes
    ) VALUES (
        test_animal_id,
        test_user_id,
        test_user_id,
        115.5,
        'lb',
        CURRENT_DATE - INTERVAL '20 days',
        'digital_scale',
        'Second test weight - ADG should calculate'
    );
    
    -- Insert third weight (current)
    INSERT INTO weights (
        animal_id,
        user_id,
        recorded_by,
        weight_value,
        weight_unit,
        measurement_date,
        measurement_method,
        notes,
        is_show_weight,
        show_name
    ) VALUES (
        test_animal_id,
        test_user_id,
        test_user_id,
        145.0,
        'lb',
        CURRENT_DATE,
        'show_official',
        'Current weight at show',
        true,
        'County Fair 2025'
    );
    
    RAISE NOTICE '✓ Multiple weights created successfully';
    
    -- =================================================================
    -- TEST 2: Verify ADG Calculations
    -- =================================================================
    RAISE NOTICE '';
    RAISE NOTICE '=== TEST 2: ADG Calculation Verification ===';
    
    SELECT 
        weight_value,
        measurement_date,
        days_since_last_weight,
        weight_change,
        adg
    INTO v_result
    FROM weights
    WHERE animal_id = test_animal_id
        AND adg IS NOT NULL
    ORDER BY measurement_date DESC
    LIMIT 1;
    
    IF v_result.adg IS NOT NULL THEN
        RAISE NOTICE '✓ ADG calculated successfully: % lbs/day', v_result.adg;
        RAISE NOTICE '  Weight: % lbs on %', v_result.weight_value, v_result.measurement_date;
        RAISE NOTICE '  Days since last: %', v_result.days_since_last_weight;
        RAISE NOTICE '  Weight change: % lbs', v_result.weight_change;
    ELSE
        RAISE NOTICE '✗ ADG calculation failed';
    END IF;
    
    -- =================================================================
    -- TEST 3: Create and Test Weight Goal
    -- =================================================================
    RAISE NOTICE '';
    RAISE NOTICE '=== TEST 3: Weight Goal Management ===';
    
    INSERT INTO weight_goals (
        animal_id,
        user_id,
        goal_name,
        target_weight,
        weight_unit,
        target_date,
        starting_weight,
        starting_date,
        target_adg,
        show_name,
        show_date
    ) VALUES (
        test_animal_id,
        test_user_id,
        'County Fair Target Weight',
        180.0,
        'lb',
        CURRENT_DATE + INTERVAL '60 days',
        145.0,
        CURRENT_DATE,
        0.58, -- 35 lbs in 60 days
        'County Fair 2025',
        CURRENT_DATE + INTERVAL '60 days'
    ) RETURNING id INTO test_goal_id;
    
    RAISE NOTICE '✓ Weight goal created: %', test_goal_id;
    
    -- Check goal progress calculation
    SELECT 
        goal_name,
        target_weight,
        current_weight,
        progress_percentage,
        days_remaining
    INTO v_result
    FROM weight_goals
    WHERE id = test_goal_id;
    
    RAISE NOTICE '✓ Goal progress tracked:';
    RAISE NOTICE '  Goal: %', v_result.goal_name;
    RAISE NOTICE '  Target: % lbs', v_result.target_weight;
    RAISE NOTICE '  Current: % lbs', v_result.current_weight;
    RAISE NOTICE '  Progress: %%%', COALESCE(v_result.progress_percentage, 0);
    RAISE NOTICE '  Days remaining: %', v_result.days_remaining;
    
    -- =================================================================
    -- TEST 4: Verify Audit Logging
    -- =================================================================
    RAISE NOTICE '';
    RAISE NOTICE '=== TEST 4: Audit Trail Verification ===';
    
    SELECT COUNT(*) INTO v_result
    FROM weight_audit_log
    WHERE animal_id = test_animal_id;
    
    IF v_result.count > 0 THEN
        RAISE NOTICE '✓ Audit logging working: % entries created', v_result.count;
        
        -- Show recent audit entries
        FOR v_result IN 
            SELECT action, performed_at
            FROM weight_audit_log
            WHERE animal_id = test_animal_id
            ORDER BY performed_at DESC
            LIMIT 3
        LOOP
            RAISE NOTICE '  - % at %', v_result.action, v_result.performed_at;
        END LOOP;
    ELSE
        RAISE NOTICE '✗ No audit log entries found';
    END IF;
    
    -- =================================================================
    -- TEST 5: Test Views
    -- =================================================================
    RAISE NOTICE '';
    RAISE NOTICE '=== TEST 5: View Functionality ===';
    
    -- Test latest weights view
    SELECT COUNT(*) INTO v_result
    FROM v_latest_weights
    WHERE animal_id = test_animal_id;
    
    IF v_result.count > 0 THEN
        RAISE NOTICE '✓ v_latest_weights working';
    ELSE
        RAISE NOTICE '✗ v_latest_weights not returning data';
    END IF;
    
    -- Test ADG calculations view
    SELECT COUNT(*) INTO v_result
    FROM v_adg_calculations
    WHERE animal_id = test_animal_id;
    
    IF v_result.count > 0 THEN
        RAISE NOTICE '✓ v_adg_calculations working';
    ELSE
        RAISE NOTICE '✗ v_adg_calculations not returning data';
    END IF;
    
    -- Test weight history view
    SELECT COUNT(*) INTO v_result
    FROM v_weight_history
    WHERE animal_id = test_animal_id;
    
    IF v_result.count > 0 THEN
        RAISE NOTICE '✓ v_weight_history working';
    ELSE
        RAISE NOTICE '✗ v_weight_history not returning data';
    END IF;
    
    -- Test active goals view
    SELECT COUNT(*) INTO v_result
    FROM v_active_weight_goals
    WHERE animal_id = test_animal_id;
    
    IF v_result.count > 0 THEN
        RAISE NOTICE '✓ v_active_weight_goals working';
    ELSE
        RAISE NOTICE '✗ v_active_weight_goals not returning data';
    END IF;
    
    -- =================================================================
    -- TEST 6: Test Statistics Cache
    -- =================================================================
    RAISE NOTICE '';
    RAISE NOTICE '=== TEST 6: Statistics Cache ===';
    
    -- Trigger statistics calculation
    PERFORM recalculate_weight_statistics(test_animal_id);
    
    SELECT 
        total_weights,
        current_weight,
        average_adg,
        highest_weight,
        lowest_weight
    INTO v_result
    FROM weight_statistics_cache
    WHERE animal_id = test_animal_id;
    
    IF v_result.total_weights IS NOT NULL THEN
        RAISE NOTICE '✓ Statistics cache working:';
        RAISE NOTICE '  Total weights: %', v_result.total_weights;
        RAISE NOTICE '  Current weight: % lbs', v_result.current_weight;
        RAISE NOTICE '  Average ADG: % lbs/day', v_result.average_adg;
        RAISE NOTICE '  Highest: % lbs', v_result.highest_weight;
        RAISE NOTICE '  Lowest: % lbs', v_result.lowest_weight;
    ELSE
        RAISE NOTICE '✗ Statistics cache not populated';
    END IF;
    
    -- =================================================================
    -- TEST 7: Test Trend Analysis
    -- =================================================================
    RAISE NOTICE '';
    RAISE NOTICE '=== TEST 7: Trend Analysis Functions ===';
    
    -- Test weight trend function
    SELECT * INTO v_result
    FROM get_weight_trend(test_animal_id, 30);
    
    IF v_result.trend IS NOT NULL THEN
        RAISE NOTICE '✓ Weight trend analysis working:';
        RAISE NOTICE '  Trend: %', v_result.trend;
        RAISE NOTICE '  Trend strength: %%%', v_result.trend_percentage;
        RAISE NOTICE '  Daily change: % lbs/day', v_result.average_change;
    ELSE
        RAISE NOTICE '✗ Trend analysis function not working';
    END IF;
    
    -- =================================================================
    -- TEST 8: Test RLS Policies
    -- =================================================================
    RAISE NOTICE '';
    RAISE NOTICE '=== TEST 8: Row Level Security ===';
    
    -- This should only return current user's weights
    SELECT COUNT(*) INTO v_result
    FROM weights
    WHERE user_id = test_user_id;
    
    RAISE NOTICE '✓ RLS Test: User can see % weight records', v_result.count;
    
    -- =================================================================
    -- CLEANUP: Option to remove test data
    -- =================================================================
    RAISE NOTICE '';
    RAISE NOTICE '=== TEST COMPLETE ===';
    RAISE NOTICE 'Test data has been created and remains in database.';
    RAISE NOTICE 'To remove test data, uncomment the cleanup section below.';
    
    /* UNCOMMENT TO CLEANUP TEST DATA
    DELETE FROM weight_goals WHERE id = test_goal_id;
    DELETE FROM weights WHERE animal_id = test_animal_id 
        AND notes LIKE '%test%';
    DELETE FROM weight_statistics_cache WHERE animal_id = test_animal_id;
    RAISE NOTICE 'Test data cleaned up successfully';
    */
    
EXCEPTION
    WHEN OTHERS THEN
        RAISE NOTICE '✗ Test failed with error: %', SQLERRM;
        RAISE NOTICE 'Error detail: %', SQLSTATE;
        -- Attempt to rollback test data on error
        DELETE FROM weight_goals WHERE animal_id = test_animal_id 
            AND goal_name = 'County Fair Target Weight';
        DELETE FROM weights WHERE animal_id = test_animal_id 
            AND notes LIKE '%test%';
END $$;

-- =================================================================
-- SUMMARY QUERIES (Run these manually after test)
-- =================================================================

-- View all test weights created
SELECT 
    w.measurement_date,
    w.weight_value,
    w.weight_unit,
    w.adg,
    w.weight_change,
    w.notes
FROM weights w
WHERE w.animal_id IN (SELECT id FROM animals WHERE user_id = auth.uid())
ORDER BY w.measurement_date DESC
LIMIT 10;

-- View goal progress
SELECT 
    goal_name,
    target_weight,
    current_weight,
    progress_percentage,
    days_remaining,
    status
FROM v_active_weight_goals
WHERE user_id = auth.uid();

-- Check statistics summary
SELECT 
    a.name as animal_name,
    s.total_weights,
    s.current_weight,
    s.average_adg,
    s.current_week_adg,
    s.weight_trend
FROM weight_statistics_cache s
JOIN animals a ON a.id = s.animal_id
WHERE a.user_id = auth.uid();