-- Pending Analyses Table for Background-Safe AI Analysis
-- This table stores analysis requests that can complete even if the app closes

CREATE TABLE IF NOT EXISTS pending_analyses (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL,
    
    -- Image storage
    image_path TEXT NOT NULL,  -- Path in Supabase Storage (food-images bucket)
    
    -- Status tracking
    status TEXT NOT NULL DEFAULT 'pending',  -- pending, processing, completed, failed
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    started_at TIMESTAMPTZ,
    completed_at TIMESTAMPTZ,
    
    -- Client tracking (to match back to local database)
    local_food_id TEXT,  -- The local LoggedFood UUID string
    
    -- Analysis result (populated when completed)
    result JSONB,  -- Full FoodAnalysisResult as JSON
    
    -- Error info (if failed)
    error_message TEXT,
    retry_count INTEGER DEFAULT 0,
    
    -- Metadata
    device_info TEXT  -- Optional: iOS version, device model
);

-- Indexes for common queries
CREATE INDEX IF NOT EXISTS idx_pending_analyses_user_status 
    ON pending_analyses(user_id, status);

CREATE INDEX IF NOT EXISTS idx_pending_analyses_status_created 
    ON pending_analyses(status, created_at);

-- RLS Policies
ALTER TABLE pending_analyses ENABLE ROW LEVEL SECURITY;

-- Users can only see their own analyses
CREATE POLICY "Users can view own analyses" ON pending_analyses
    FOR SELECT USING (auth.uid() = user_id);

-- Users can insert their own analyses
CREATE POLICY "Users can create analyses" ON pending_analyses
    FOR INSERT WITH CHECK (auth.uid() = user_id);

-- Service role can update any analysis (for edge function)
CREATE POLICY "Service can update analyses" ON pending_analyses
    FOR UPDATE USING (true);

-- Cleanup old completed/failed analyses (run periodically)
-- DELETE FROM pending_analyses 
-- WHERE status IN ('completed', 'failed') 
-- AND completed_at < NOW() - INTERVAL '7 days';

COMMENT ON TABLE pending_analyses IS 'Stores pending AI food analysis requests for background processing';
