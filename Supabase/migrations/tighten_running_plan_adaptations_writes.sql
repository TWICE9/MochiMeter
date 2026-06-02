-- =========================================
-- Tighten running_plan_adaptations write access (security audit H-1)
-- =========================================
-- The original migration granted clients INSERT and full UPDATE on the
-- adaptation log. That let an authenticated user POST forged rows directly
-- to /rest/v1/running_plan_adaptations or rewrite the AI-authored summary
-- on existing rows — tampering with their own audit trail and faking
-- "Plan adjusted" banners.
--
-- This migration:
--   1. Drops the client INSERT policy. Only the service-role edge function
--      (which bypasses RLS) creates new rows.
--   2. Replaces the broad UPDATE policy with a column-restriction trigger
--      so users can only flip `acknowledged_at` (banner dismissal). All
--      other content fields are immutable for the user role.

-- 1. Drop client insert.
DROP POLICY IF EXISTS "Users can insert their own adaptations"
    ON public.running_plan_adaptations;

-- 2. Keep the basic row-level UPDATE policy so users can still address their
--    own rows. Field-level restriction is enforced via the trigger below
--    (Postgres RLS doesn't have column-level WITH CHECK).
DROP POLICY IF EXISTS "Users can update their own adaptations"
    ON public.running_plan_adaptations;
CREATE POLICY "Users can update only their own adaptations"
    ON public.running_plan_adaptations FOR UPDATE
    USING (auth.uid() = user_id)
    WITH CHECK (auth.uid() = user_id);

-- 3. Trigger: any UPDATE that mutates a content column (anything other than
--    `acknowledged_at` or the auto-bumped `updated_at`) gets rejected.
--    The service-role edge function only INSERTs — it never UPDATEs this
--    table — so this trigger only sees user-driven traffic in practice.
CREATE OR REPLACE FUNCTION public.guard_running_plan_adaptation_updates()
RETURNS TRIGGER AS $$
BEGIN
    IF NEW.user_id IS DISTINCT FROM OLD.user_id THEN
        RAISE EXCEPTION 'running_plan_adaptations: user_id is immutable';
    END IF;
    IF NEW.plan_id IS DISTINCT FROM OLD.plan_id THEN
        RAISE EXCEPTION 'running_plan_adaptations: plan_id is immutable';
    END IF;
    IF NEW.reason IS DISTINCT FROM OLD.reason THEN
        RAISE EXCEPTION 'running_plan_adaptations: reason is immutable';
    END IF;
    IF NEW.summary IS DISTINCT FROM OLD.summary THEN
        RAISE EXCEPTION 'running_plan_adaptations: summary is immutable';
    END IF;
    IF NEW.changes IS DISTINCT FROM OLD.changes THEN
        RAISE EXCEPTION 'running_plan_adaptations: changes is immutable';
    END IF;
    IF NEW.sessions_changed IS DISTINCT FROM OLD.sessions_changed THEN
        RAISE EXCEPTION 'running_plan_adaptations: sessions_changed is immutable';
    END IF;
    IF NEW.created_at IS DISTINCT FROM OLD.created_at THEN
        RAISE EXCEPTION 'running_plan_adaptations: created_at is immutable';
    END IF;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trg_guard_running_plan_adaptation_updates
    ON public.running_plan_adaptations;
CREATE TRIGGER trg_guard_running_plan_adaptation_updates
    BEFORE UPDATE ON public.running_plan_adaptations
    FOR EACH ROW
    EXECUTE FUNCTION public.guard_running_plan_adaptation_updates();
