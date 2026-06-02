-- =========================================
-- Yumo Running Plans Migration
-- =========================================
-- Creates `running_plans` (one row per plan) and `planned_sessions`
-- (one row per scheduled run). Both tables link to auth.users via user_id
-- and enforce RLS so a user can only read/write their own rows.

CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

-- =========================================
-- 1. RUNNING_PLANS
-- =========================================
CREATE TABLE IF NOT EXISTS public.running_plans (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,

    -- Display / metadata
    name TEXT NOT NULL,                               -- e.g. "10K in 12 weeks"
    goal_type TEXT NOT NULL,                          -- matches RunningGoalType rawValue
    status TEXT NOT NULL DEFAULT 'active',            -- active | completed | abandoned | replaced

    -- Plan shape
    start_date TIMESTAMPTZ NOT NULL,
    total_weeks INTEGER NOT NULL,

    -- Race target snapshot (denormalized from profile at generation time)
    target_race_date TIMESTAMPTZ,
    target_race_distance TEXT,                        -- '5K' | '10K' | 'Half Marathon' | 'Marathon'
    target_race_name TEXT,
    target_race_goal_time_seconds INTEGER,

    -- Generation provenance
    generation_source TEXT NOT NULL DEFAULT 'ai',     -- ai | manual | template
    generation_context JSONB,                         -- snapshot of profile used to generate (for audit + re-adaptation)
    model_version TEXT,                               -- e.g. 'claude-sonnet-4-6'

    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_running_plans_user_id ON public.running_plans(user_id);
CREATE INDEX IF NOT EXISTS idx_running_plans_user_status ON public.running_plans(user_id, status);

ALTER TABLE public.running_plans ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Users can view their own running plans"
    ON public.running_plans FOR SELECT
    USING (auth.uid() = user_id);

CREATE POLICY "Users can insert their own running plans"
    ON public.running_plans FOR INSERT
    WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Users can update their own running plans"
    ON public.running_plans FOR UPDATE
    USING (auth.uid() = user_id);

CREATE POLICY "Users can delete their own running plans"
    ON public.running_plans FOR DELETE
    USING (auth.uid() = user_id);

-- Keep updated_at fresh on UPDATE
CREATE OR REPLACE FUNCTION public.set_running_plan_updated_at()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trg_running_plans_updated_at ON public.running_plans;
CREATE TRIGGER trg_running_plans_updated_at
    BEFORE UPDATE ON public.running_plans
    FOR EACH ROW
    EXECUTE FUNCTION public.set_running_plan_updated_at();


-- =========================================
-- 2. PLANNED_SESSIONS
-- =========================================
CREATE TABLE IF NOT EXISTS public.planned_sessions (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    plan_id UUID NOT NULL REFERENCES public.running_plans(id) ON DELETE CASCADE,

    -- Scheduling
    week_number INTEGER NOT NULL,                     -- 1-indexed
    scheduled_date TIMESTAMPTZ NOT NULL,

    -- Session prescription
    session_type TEXT NOT NULL,                       -- easy | long | tempo | intervals | rest | cross | recovery | race
    target_distance_km DOUBLE PRECISION,
    target_duration_minutes INTEGER,
    target_pace_seconds_per_km INTEGER,
    description TEXT NOT NULL,                        -- e.g. "5km easy pace, conversational effort"
    notes TEXT,

    -- Completion
    completed_at TIMESTAMPTZ,
    completed_distance_km DOUBLE PRECISION,
    completed_duration_minutes INTEGER,
    completed_source TEXT,                            -- healthkit | manual | imported
    skipped BOOLEAN NOT NULL DEFAULT false,

    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_planned_sessions_user_id ON public.planned_sessions(user_id);
CREATE INDEX IF NOT EXISTS idx_planned_sessions_plan_id ON public.planned_sessions(plan_id);
CREATE INDEX IF NOT EXISTS idx_planned_sessions_user_date ON public.planned_sessions(user_id, scheduled_date);

ALTER TABLE public.planned_sessions ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Users can view their own planned sessions"
    ON public.planned_sessions FOR SELECT
    USING (auth.uid() = user_id);

CREATE POLICY "Users can insert their own planned sessions"
    ON public.planned_sessions FOR INSERT
    WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Users can update their own planned sessions"
    ON public.planned_sessions FOR UPDATE
    USING (auth.uid() = user_id);

CREATE POLICY "Users can delete their own planned sessions"
    ON public.planned_sessions FOR DELETE
    USING (auth.uid() = user_id);

CREATE OR REPLACE FUNCTION public.set_planned_session_updated_at()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trg_planned_sessions_updated_at ON public.planned_sessions;
CREATE TRIGGER trg_planned_sessions_updated_at
    BEFORE UPDATE ON public.planned_sessions
    FOR EACH ROW
    EXECUTE FUNCTION public.set_planned_session_updated_at();
