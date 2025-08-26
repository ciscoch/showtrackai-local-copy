import { serve } from "https://deno.land/std@0.168.0/http/server.ts"
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2'

// Create Supabase client
const supabaseUrl = Deno.env.get('SUPABASE_URL') ?? ''
const supabaseServiceKey = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY') ?? ''
const supabase = createClient(supabaseUrl, supabaseServiceKey)

// Shared secret for authentication (set in environment variables)
const CALLBACK_SECRET = Deno.env.get('SPAR_CALLBACK_SECRET') ?? 'default-secret-change-me'

serve(async (req) => {
  // Handle CORS
  if (req.method === 'OPTIONS') {
    return new Response('ok', {
      headers: {
        'Access-Control-Allow-Origin': '*',
        'Access-Control-Allow-Methods': 'POST, OPTIONS',
        'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type, x-spar-auth',
      },
    })
  }

  try {
    // Validate method
    if (req.method !== 'POST') {
      throw new Error(`Method ${req.method} not allowed`)
    }

    // Validate authentication
    const authHeader = req.headers.get('x-spar-auth')
    if (authHeader !== CALLBACK_SECRET) {
      console.error('Invalid authentication token')
      throw new Error('Unauthorized')
    }

    // Parse request body
    const body = await req.json()
    console.log('SPAR Callback received:', { 
      runId: body.runId,
      status: body.status,
      timestamp: new Date().toISOString()
    })

    // Validate required fields
    if (!body.runId || !body.status) {
      throw new Error('Missing required fields: runId and status')
    }

    // Get the existing SPAR run
    const { data: existingRun, error: fetchError } = await supabase
      .from('spar_runs')
      .select('*')
      .eq('run_id', body.runId)
      .single()

    if (fetchError || !existingRun) {
      console.error('SPAR run not found:', body.runId)
      throw new Error(`SPAR run not found: ${body.runId}`)
    }

    // Prepare update based on status
    let updateData: any = {
      status: body.status,
      updated_at: new Date().toISOString(),
    }

    switch (body.status.toLowerCase()) {
      case 'processing':
        updateData.processing_started_at = updateData.processing_started_at || new Date().toISOString()
        if (body.plan) {
          updateData.plan = body.plan
        }
        break

      case 'completed':
      case 'success':
        updateData.status = 'completed'
        updateData.processing_completed_at = new Date().toISOString()
        
        // Calculate duration if processing_started_at exists
        if (existingRun.processing_started_at) {
          const startTime = new Date(existingRun.processing_started_at).getTime()
          const endTime = new Date().getTime()
          updateData.processing_duration_ms = endTime - startTime
        }
        
        // Add results
        if (body.plan) updateData.plan = body.plan
        if (body.results) updateData.step_results = body.results
        if (body.stepResults) updateData.step_results = body.stepResults
        if (body.reflections) updateData.reflections = body.reflections
        
        // If no reflections provided but we have results, create basic reflections
        if (!updateData.reflections && body.results) {
          updateData.reflections = {
            summary: body.results.summary || 'Processing completed successfully',
            insights: body.results.insights || [],
            recommendations: body.results.recommendations || [],
            quality_score: body.results.quality_score,
            competencies: body.results.competencies,
            timestamp: new Date().toISOString()
          }
        }
        break

      case 'failed':
      case 'error':
        updateData.status = 'failed'
        updateData.failed_at = new Date().toISOString()
        updateData.error = body.error || 'Unknown error occurred'
        updateData.error_details = body.errorDetails || { message: body.error }
        break

      case 'timeout':
        updateData.status = 'timeout'
        updateData.error = `Processing timeout after ${body.timeoutSeconds || 60} seconds`
        updateData.error_details = {
          timeout_seconds: body.timeoutSeconds || 60,
          timeout_at: new Date().toISOString(),
        }
        break

      default:
        throw new Error(`Invalid status: ${body.status}`)
    }

    // Update the SPAR run
    const { data: updatedRun, error: updateError } = await supabase
      .from('spar_runs')
      .update(updateData)
      .eq('run_id', body.runId)
      .select()
      .single()

    if (updateError) {
      console.error('Error updating SPAR run:', updateError)
      throw updateError
    }

    // If completed and has journal_entry_id, store AI assessment in normalized table
    if (body.status === 'completed' && existingRun.journal_entry_id && body.results) {
      try {
        // Prepare normalized assessment data
        const assessmentData = {
          assessment_type: 'journal_analysis',
          assessment_version: '1.0',
          processed_by: 'n8n_financial_agent',
          
          // Core scores (normalize to 0-10 scale if needed)
          quality_score: body.results.quality_score ? parseFloat(body.results.quality_score) : null,
          engagement_score: body.results.engagement_score ? parseFloat(body.results.engagement_score) : null,
          learning_depth_score: body.results.learning_depth_score ? parseFloat(body.results.learning_depth_score) : null,
          
          // Competency and standards arrays
          competencies_identified: Array.isArray(body.results.competencies) ? body.results.competencies : [],
          ffa_standards_matched: Array.isArray(body.results.ffa_standards) ? body.results.ffa_standards : [],
          learning_objectives_achieved: Array.isArray(body.results.objectives_achieved) ? body.results.objectives_achieved : [],
          
          // Assessment insights arrays
          strengths_identified: Array.isArray(body.results.strengths) ? body.results.strengths : [],
          growth_areas: Array.isArray(body.results.improvements) || Array.isArray(body.results.growth_areas) ? 
                       (body.results.growth_areas || body.results.improvements) : [],
          recommendations: Array.isArray(body.results.recommendations) ? body.results.recommendations : [],
          
          // Additional analysis
          key_concepts: Array.isArray(body.results.key_concepts) ? body.results.key_concepts : [],
          vocabulary_used: Array.isArray(body.results.vocabulary_used) ? body.results.vocabulary_used : [],
          technical_accuracy_notes: body.results.technical_notes || body.results.accuracy_notes || null,
          
          // Assessment metadata
          confidence_score: body.results.confidence_score ? parseFloat(body.results.confidence_score) : null,
          processing_duration_ms: updateData.processing_duration_ms || null,
          model_used: body.results.model_used || body.model || 'gpt-4'
        }

        // Store AI assessment in dedicated table using the database function
        const { data: assessmentResult, error: assessmentError } = await supabase
          .rpc('upsert_ai_assessment', {
            p_journal_entry_id: existingRun.journal_entry_id,
            p_assessment_data: assessmentData,
            p_n8n_run_id: body.runId,
            p_trace_id: existingRun.trace_id || null
          })

        if (assessmentError) {
          console.error('Error storing AI assessment:', assessmentError)
          // Don't fail the whole operation if assessment storage fails
        } else {
          console.log('AI assessment stored successfully:', assessmentResult)
        }

        // Also update journal entry sync status and basic analysis for backward compatibility
        const legacyAnalysis = {
          spar_run_id: body.runId,
          processed_at: new Date().toISOString(),
          quality_score: assessmentData.quality_score,
          competencies_count: assessmentData.competencies_identified.length,
          has_detailed_assessment: true,
          assessment_id: assessmentResult
        }

        const { error: journalUpdateError } = await supabase
          .from('journal_entries')
          .update({
            ai_analysis: legacyAnalysis,
            sync_status: 'synced',
            updated_at: new Date().toISOString(),
          })
          .eq('id', existingRun.journal_entry_id)

        if (journalUpdateError) {
          console.error('Error updating journal entry sync status:', journalUpdateError)
        } else {
          console.log('Journal entry sync status updated')
        }

      } catch (error) {
        console.error('Error in AI assessment processing:', error)
        // Continue execution even if AI assessment fails
      }
    }

    // Return success response
    const response = {
      success: true,
      message: 'SPAR run updated successfully',
      runId: body.runId,
      status: updateData.status,
      timestamp: new Date().toISOString(),
      processingDuration: updateData.processing_duration_ms,
    }

    console.log('SPAR Callback processed successfully:', response)

    return new Response(
      JSON.stringify(response),
      {
        headers: {
          'Content-Type': 'application/json',
          'Access-Control-Allow-Origin': '*',
        },
        status: 200,
      }
    )

  } catch (error) {
    console.error('SPAR Callback error:', error)
    
    const errorResponse = {
      success: false,
      error: error.message || 'Internal server error',
      timestamp: new Date().toISOString(),
    }

    return new Response(
      JSON.stringify(errorResponse),
      {
        headers: {
          'Content-Type': 'application/json',
          'Access-Control-Allow-Origin': '*',
        },
        status: error.message === 'Unauthorized' ? 401 : 400,
      }
    )
  }
})