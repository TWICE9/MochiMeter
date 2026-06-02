-- =========================================
-- Yumo Running Plan Adaptations
-- =========================================
-- Logs each time the AI re-tunes an existing plan in response to
-- skipped sessions, new PBs, or weekly check-in feedback. We keep the
-- log so the iOS app can:
--   1. Show a "Plan adjusted" banner with the human-readable summary
--   2. Rate-limit auto-adaptations (max one per 7 days unless manual)
--   3. Audit what changed if a user complains "the plan is different"
--
-- Edits to planned_sessions themselves go through the existing
-- planned_sessions table — this is metadata, not the changes.

CREATE TABLE IF NOT EXISTS public.running_plan_adaptations (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    plan_id UUID NOT NULL REFERENCES public.running_plans(id) ON DELETE CASCADE,

    -- Why the adaptation fired. Drives prompt direction + UI copy.
    --   auto_misses        — runner has missed N sessions in a row
    --   auto_pb            — runner hit a new HealthKit PB
    --   auto_pace_fast     — runner is consistently faster than target
    --   weekly_too_hard    — Sunday check-in: "this week was too hard"
    --   weekly_too_easy    — Sunday check-in: "this week was too easy"
    --   weekly_just_right  — Sunday check-in: "no change" (logged for audit)
    --   manual_easier      — user tapped "ease the plan"
    --   manual_harder      — user tapped "push harder"
    --   manual             — generic manual fine-tune
    reason TEXT NOT NULL,

    -- Plain-English banner copy: "Eased Tuesday tempo to 5:10/km after a heavy strength week."
    summary TEXT NOT NULL,

    -- Snapshot of the per-session edits the AI made. Stored as JSON for
    -- portability; the actual session updates are in planned_sessions.
    -- Shape: [{ session_id, fields: { description, target_pace_seconds_per_km, ... } }, ...]
    changes JSONB NOT NULL DEFAULT '[]'::jsonb,

    -- Number of sessions actually modified. Cheap field for filtering
    -- "no-op adaptations" (e.g. "just_right" check-ins).
    sessions_changed INTEGER NOT NULL DEFAULT 0,

    -- Set by the client when the user dismisses the banner. Null = unread.
    acknowledged_at TIMESTAMPTZ,

    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_running_plan_adaptations_user_id
    ON public.running_plan_adaptations(user_id);
CREATE INDEX IF NOT EXISTS idx_running_plan_adaptations_plan_id
    ON public.running_plan_adaptations(plan_id);
CREATE INDEX IF NOT EXISTS idx_running_plan_adaptations_unack
    ON public.running_plan_adaptations(user_id, plan_id, created_at DESC)
    WHERE acknowledged_at IS NULL;

ALTER TABLE public.running_plan_adaptations ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Users can view their own adaptations"
    ON public.running_plan_adaptations FOR SELECT
    USING (auth.uid() = user_id);

CREATE POLICY "Users can insert their own adaptations"
    ON public.running_plan_adaptations FOR INSERT
    WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Users can update their own adaptations"
    ON public.running_plan_adaptations FOR UPDATE
    USING (auth.uid() = user_id);

-- Keep updated_at fresh on any UPDATE (mirrors the running_plans trigger).
CREATE OR REPLACE FUNCTION public.set_running_plan_adaptation_updated_at()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trg_running_plan_adaptations_updated_at
    ON public.running_plan_adaptations;
CREATE TRIGGER trg_running_plan_adaptations_updated_at
    BEFORE UPDATE ON public.running_plan_adaptations
    FOR EACH ROW
    EXECUTE FUNCTION public.set_running_plan_adaptation_updated_at();
