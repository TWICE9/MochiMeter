-- =========================================
-- Yumo Running Profiles: cross-training + workout reminders
-- =========================================
-- Adds optional fields capturing the user's other workouts (so the AI plan
-- can complement them) and per-user workout-reminder preferences (drives
-- local notifications scheduled by the iOS app).

ALTER TABLE public.running_profiles
    ADD COLUMN IF NOT EXISTS cross_training_activities TEXT[] NOT NULL DEFAULT '{}',
    ADD COLUMN IF NOT EXISTS cross_training_sessions_per_week INTEGER NOT NULL DEFAULT 0,
    ADD COLUMN IF NOT EXISTS workout_reminders_enabled BOOLEAN NOT NULL DEFAULT false,
    ADD COLUMN IF NOT EXISTS workout_reminder_hour INTEGER,
    ADD COLUMN IF NOT EXISTS workout_reminder_minute INTEGER;

-- Sanity bounds. Cross-training frequency is an integer 0..7; reminder time
-- components must be valid HH:MM if present.
ALTER TABLE public.running_profiles
    DROP CONSTRAINT IF EXISTS running_profiles_cross_training_freq_check,
    DROP CONSTRAINT IF EXISTS running_profiles_workout_reminder_hour_check,
    DROP CONSTRAINT IF EXISTS running_profiles_workout_reminder_minute_check;

ALTER TABLE public.running_profiles
    ADD CONSTRAINT running_profiles_cross_training_freq_check
        CHECK (cross_training_sessions_per_week BETWEEN 0 AND 14),
    ADD CONSTRAINT running_profiles_workout_reminder_hour_check
        CHECK (workout_reminder_hour IS NULL OR workout_reminder_hour BETWEEN 0 AND 23),
    ADD CONSTRAINT running_profiles_workout_reminder_minute_check
        CHECK (workout_reminder_minute IS NULL OR workout_reminder_minute BETWEEN 0 AND 59);
