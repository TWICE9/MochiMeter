-- Row-level-security policies for `device_tokens`.
--
-- The iOS client upserts into this table from `DeviceTokenManager.uploadToken`
-- using the user's JWT (not the service role), so RLS must allow each
-- authenticated user to INSERT / UPDATE / SELECT / DELETE rows where
-- `user_id = auth.uid()`. UPSERT triggers both the INSERT and UPDATE paths,
-- so both policies are required — having only INSERT was the cause of error
-- 42501 ("new row violates row-level security policy").
--
-- Edge functions (e.g. analyze-food) use the service-role key, which
-- bypasses RLS, so server-side reads/writes are unaffected.
--
-- Run idempotently: drop-then-create so re-running this migration is safe.

ALTER TABLE public.device_tokens ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Users can view their own device tokens" ON public.device_tokens;
CREATE POLICY "Users can view their own device tokens"
    ON public.device_tokens FOR SELECT
    USING (auth.uid() = user_id);

DROP POLICY IF EXISTS "Users can insert their own device tokens" ON public.device_tokens;
CREATE POLICY "Users can insert their own device tokens"
    ON public.device_tokens FOR INSERT
    WITH CHECK (auth.uid() = user_id);

DROP POLICY IF EXISTS "Users can update their own device tokens" ON public.device_tokens;
CREATE POLICY "Users can update their own device tokens"
    ON public.device_tokens FOR UPDATE
    USING (auth.uid() = user_id)
    WITH CHECK (auth.uid() = user_id);

DROP POLICY IF EXISTS "Users can delete their own device tokens" ON public.device_tokens;
CREATE POLICY "Users can delete their own device tokens"
    ON public.device_tokens FOR DELETE
    USING (auth.uid() = user_id);
