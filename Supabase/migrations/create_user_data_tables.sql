-- =========================================
-- Yumo User Data Tables Migration
-- =========================================
-- This migration creates tables for syncing user data to Supabase
-- All tables use user_id as foreign key to auth.users

-- Enable UUID extension if not already enabled
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

-- =========================================
-- 1. PROFILES TABLE (User Onboarding Data)
-- =========================================
CREATE TABLE IF NOT EXISTS public.profiles (
    user_id UUID PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,

    -- User info
    name TEXT NOT NULL DEFAULT 'User',

    -- Onboarding/profile data
    birthdate TEXT NOT NULL,
    gender TEXT NOT NULL,
    height_cm INTEGER NOT NULL,
    weight_kg DOUBLE PRECISION NOT NULL,
    activity_level TEXT NOT NULL,
    weight_goal INTEGER NOT NULL,  -- 0=lose, 1=maintain, 2=gain
    target_weight DOUBLE PRECISION NOT NULL,

    -- Calculated nutrition goals
    daily_calories INTEGER NOT NULL,
    daily_protein INTEGER NOT NULL,
    daily_carbs INTEGER NOT NULL,
    daily_fat INTEGER NOT NULL,

    -- New onboarding fields
    blockers TEXT[],
    diet_type TEXT,
    goals_to_accomplish TEXT[],
    referral_code TEXT,
    healthkit_enabled BOOLEAN DEFAULT false,

    -- Sync metadata
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_profiles_user_id ON public.profiles(user_id);

ALTER TABLE public.profiles ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Users can view their own profile"
    ON public.profiles FOR SELECT
    USING (auth.uid() = user_id);

CREATE POLICY "Users can insert their own profile"
    ON public.profiles FOR INSERT
    WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Users can update their own profile"
    ON public.profiles FOR UPDATE
    USING (auth.uid() = user_id);

CREATE POLICY "Users can delete their own profile"
    ON public.profiles FOR DELETE
    USING (auth.uid() = user_id);

-- =========================================
-- 2. USER FOOD LOGS TABLE
-- =========================================
CREATE TABLE IF NOT EXISTS public.user_food_logs (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,

    -- Food details
    name TEXT NOT NULL,
    timestamp TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    serving_size_description TEXT NOT NULL,
    serving_amount DOUBLE PRECISION NOT NULL,

    -- Nutrition per serving
    calories_per_serving DOUBLE PRECISION NOT NULL DEFAULT 0,
    protein_per_serving DOUBLE PRECISION NOT NULL DEFAULT 0,
    carbs_per_serving DOUBLE PRECISION NOT NULL DEFAULT 0,
    fat_per_serving DOUBLE PRECISION NOT NULL DEFAULT 0,
    fiber_per_serving DOUBLE PRECISION NOT NULL DEFAULT 0,
    sugar_per_serving DOUBLE PRECISION NOT NULL DEFAULT 0,
    salt_per_serving DOUBLE PRECISION NOT NULL DEFAULT 0,
    potassium_per_serving DOUBLE PRECISION NOT NULL DEFAULT 0,

    -- Optional fields
    barcode TEXT,
    brand TEXT,
    is_halal BOOLEAN DEFAULT false,

    -- Recipe relationship (nullable)
    recipe_id UUID,

    -- Sync metadata
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- Index for faster queries
CREATE INDEX IF NOT EXISTS idx_user_food_logs_user_id ON public.user_food_logs(user_id);
CREATE INDEX IF NOT EXISTS idx_user_food_logs_timestamp ON public.user_food_logs(timestamp);
CREATE INDEX IF NOT EXISTS idx_user_food_logs_recipe_id ON public.user_food_logs(recipe_id);

-- RLS Policies for user_food_logs
ALTER TABLE public.user_food_logs ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Users can view their own food logs"
    ON public.user_food_logs FOR SELECT
    USING (auth.uid() = user_id);

CREATE POLICY "Users can insert their own food logs"
    ON public.user_food_logs FOR INSERT
    WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Users can update their own food logs"
    ON public.user_food_logs FOR UPDATE
    USING (auth.uid() = user_id);

CREATE POLICY "Users can delete their own food logs"
    ON public.user_food_logs FOR DELETE
    USING (auth.uid() = user_id);

-- =========================================
-- 3. USER WATER LOGS TABLE
-- =========================================
CREATE TABLE IF NOT EXISTS public.user_water_logs (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,

    amount_ml DOUBLE PRECISION NOT NULL,
    timestamp TIMESTAMPTZ NOT NULL DEFAULT NOW(),

    -- Sync metadata
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_user_water_logs_user_id ON public.user_water_logs(user_id);
CREATE INDEX IF NOT EXISTS idx_user_water_logs_timestamp ON public.user_water_logs(timestamp);

ALTER TABLE public.user_water_logs ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Users can view their own water logs"
    ON public.user_water_logs FOR SELECT
    USING (auth.uid() = user_id);

CREATE POLICY "Users can insert their own water logs"
    ON public.user_water_logs FOR INSERT
    WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Users can update their own water logs"
    ON public.user_water_logs FOR UPDATE
    USING (auth.uid() = user_id);

CREATE POLICY "Users can delete their own water logs"
    ON public.user_water_logs FOR DELETE
    USING (auth.uid() = user_id);

-- =========================================
-- 4. USER FASTING LOGS TABLE
-- =========================================
CREATE TABLE IF NOT EXISTS public.user_fasting_logs (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,

    start_time TIMESTAMPTZ NOT NULL,
    end_time TIMESTAMPTZ,  -- NULL if fast is currently active
    goal_hours DOUBLE PRECISION NOT NULL,

    -- Sync metadata
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_user_fasting_logs_user_id ON public.user_fasting_logs(user_id);
CREATE INDEX IF NOT EXISTS idx_user_fasting_logs_start_time ON public.user_fasting_logs(start_time);

ALTER TABLE public.user_fasting_logs ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Users can view their own fasting logs"
    ON public.user_fasting_logs FOR SELECT
    USING (auth.uid() = user_id);

CREATE POLICY "Users can insert their own fasting logs"
    ON public.user_fasting_logs FOR INSERT
    WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Users can update their own fasting logs"
    ON public.user_fasting_logs FOR UPDATE
    USING (auth.uid() = user_id);

CREATE POLICY "Users can delete their own fasting logs"
    ON public.user_fasting_logs FOR DELETE
    USING (auth.uid() = user_id);

-- =========================================
-- 5. USER RECIPES TABLE
-- =========================================
CREATE TABLE IF NOT EXISTS public.user_recipes (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,

    name TEXT NOT NULL,
    servings DOUBLE PRECISION NOT NULL DEFAULT 1.0,

    -- Sync metadata
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_user_recipes_user_id ON public.user_recipes(user_id);

ALTER TABLE public.user_recipes ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Users can view their own recipes"
    ON public.user_recipes FOR SELECT
    USING (auth.uid() = user_id);

CREATE POLICY "Users can insert their own recipes"
    ON public.user_recipes FOR INSERT
    WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Users can update their own recipes"
    ON public.user_recipes FOR UPDATE
    USING (auth.uid() = user_id);

CREATE POLICY "Users can delete their own recipes"
    ON public.user_recipes FOR DELETE
    USING (auth.uid() = user_id);

-- Note: Recipe ingredients are stored in user_food_logs with recipe_id foreign key

-- =========================================
-- 6. USER REMINDERS TABLE
-- =========================================
CREATE TABLE IF NOT EXISTS public.user_reminders (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,

    title TEXT NOT NULL,
    notes TEXT NOT NULL DEFAULT '',
    time TIMESTAMPTZ NOT NULL,
    is_enabled BOOLEAN NOT NULL DEFAULT true,
    weekdays INTEGER[] NOT NULL DEFAULT '{1,2,3,4,5,6,7}',  -- Array of weekday numbers
    notification_id TEXT NOT NULL,

    -- Sync metadata
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_user_reminders_user_id ON public.user_reminders(user_id);

ALTER TABLE public.user_reminders ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Users can view their own reminders"
    ON public.user_reminders FOR SELECT
    USING (auth.uid() = user_id);

CREATE POLICY "Users can insert their own reminders"
    ON public.user_reminders FOR INSERT
    WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Users can update their own reminders"
    ON public.user_reminders FOR UPDATE
    USING (auth.uid() = user_id);

CREATE POLICY "Users can delete their own reminders"
    ON public.user_reminders FOR DELETE
    USING (auth.uid() = user_id);

-- =========================================
-- 7. TRIGGERS FOR UPDATED_AT
-- =========================================
-- Function to update updated_at timestamp
CREATE OR REPLACE FUNCTION update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$ language 'plpgsql';

-- Apply to all tables
CREATE TRIGGER update_profiles_updated_at BEFORE UPDATE ON public.profiles
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER update_user_food_logs_updated_at BEFORE UPDATE ON public.user_food_logs
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER update_user_water_logs_updated_at BEFORE UPDATE ON public.user_water_logs
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER update_user_fasting_logs_updated_at BEFORE UPDATE ON public.user_fasting_logs
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER update_user_recipes_updated_at BEFORE UPDATE ON public.user_recipes
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER update_user_reminders_updated_at BEFORE UPDATE ON public.user_reminders
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

-- =========================================
-- 8. COMMENTS FOR DOCUMENTATION
-- =========================================
COMMENT ON TABLE public.profiles IS 'Stores user profile and onboarding data';
COMMENT ON TABLE public.user_food_logs IS 'Stores user food diary entries with nutrition information';
COMMENT ON TABLE public.user_water_logs IS 'Stores user water intake logs';
COMMENT ON TABLE public.user_fasting_logs IS 'Stores user intermittent fasting sessions';
COMMENT ON TABLE public.user_recipes IS 'Stores user custom recipes';
COMMENT ON TABLE public.user_reminders IS 'Stores user notification reminders';

-- Comments for new onboarding fields
COMMENT ON COLUMN public.profiles.blockers IS 'Array of blockers preventing user from reaching goals';
COMMENT ON COLUMN public.profiles.diet_type IS 'User diet preference: Regular, Pescatarian, Vegetarian, Vegan';
COMMENT ON COLUMN public.profiles.goals_to_accomplish IS 'Array of goals user wants to accomplish';
COMMENT ON COLUMN public.profiles.referral_code IS 'Optional referral code entered during onboarding';
COMMENT ON COLUMN public.profiles.healthkit_enabled IS 'Whether user granted HealthKit permission';

-- =========================================
-- MIGRATION COMPLETE
-- =========================================
-- To apply this migration:
-- 1. Go to Supabase Dashboard > SQL Editor
-- 2. Paste this entire file
-- 3. Click "Run"
-- 4. Verify tables are created in Database > Tables
