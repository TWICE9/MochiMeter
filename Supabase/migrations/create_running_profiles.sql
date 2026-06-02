-- =========================================
-- Yumo Running Profiles Migration
-- =========================================
-- Creates the running_profiles table for syncing per-user running
-- onboarding, goals, baseline fitness, and target-race info.
-- One row per user; user_id is the primary key.

CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

CREATE TABLE IF NOT EXISTS public.running_profiles (
    user_id UUID PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,

    -- Onboarding state
    has_completed_onboarding BOOLEAN NOT NULL DEFAULT false,

    -- Background
    experience TEXT NOT NULL DEFAULT 'Beginner',      -- Never | Beginner | Intermediate | Advanced
    has_run_before BOOLEAN NOT NULL DEFAULT false,

    -- Goal
    primary_goal TEXT NOT NULL DEFAULT 'General Fitness',

    -- Availability
    weekly_run_days_target INTEGER NOT NULL DEFAULT 3,
    available_days TEXT[] NOT NULL DEFAULT '{}',      -- ['mon','tue',...]
    long_run_day TEXT,                                -- 'sat' | 'sun' | etc.

    -- Current fitness baseline
    current_longest_run_km DOUBLE PRECISION,
    current_weekly_km DOUBLE PRECISION,
    typical_pace_seconds_per_km INTEGER,

    -- Target race
    target_race_date TIMESTAMPTZ,
    target_race_distance TEXT,                        -- '5K' | '10K' | 'Half Marathon' | 'Marathon'
    target_race_name TEXT,
    target_race_goal_time_seconds INTEGER,

    -- Notes
    injuries_or_limitations TEXT,

    -- Sync metadata
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_running_profiles_user_id ON public.running_profiles(user_id);

ALTER TABLE public.running_profiles ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Users can view their own running profile"
    ON public.running_profiles FOR SELECT
    USING (auth.uid() = user_id);

CREATE POLICY "Users can insert their own running profile"
    ON public.running_profiles FOR INSERT
    WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Users can update their own running profile"
    ON public.running_profiles FOR UPDATE
    USING (auth.uid() = user_id);

CREATE POLICY "Users can delete their own running profile"
    ON public.running_profiles FOR DELETE
    USING (auth.uid() = user_id);

-- Keep updated_at fresh on any UPDATE
CREATE OR REPLACE FUNCTION public.set_running_profile_updated_at()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trg_running_profiles_updated_at ON public.running_profiles;
CREATE TRIGGER trg_running_profiles_updated_at
    BEFORE UPDATE ON public.running_profiles
    FOR EACH ROW
    EXECUTE FUNCTION public.set_running_profile_updated_at();
