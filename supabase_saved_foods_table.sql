-- Create saved_foods table for MochiMeter
-- Run this in Supabase SQL Editor

-- Create the table
CREATE TABLE saved_foods (
    id UUID PRIMARY KEY,
    user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    food_name TEXT NOT NULL,
    brand TEXT,
    barcode TEXT,
    calories_per_serving DOUBLE PRECISION NOT NULL,
    protein_per_serving DOUBLE PRECISION NOT NULL,
    carbs_per_serving DOUBLE PRECISION NOT NULL,
    fat_per_serving DOUBLE PRECISION NOT NULL,
    fiber_per_serving DOUBLE PRECISION NOT NULL,
    sugar_per_serving DOUBLE PRECISION NOT NULL,
    serving_size_description TEXT NOT NULL,
    salt_per_serving DOUBLE PRECISION,
    potassium_per_serving DOUBLE PRECISION,
    saved_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- Create indexes for better query performance
CREATE INDEX idx_saved_foods_user_id ON saved_foods(user_id);
CREATE INDEX idx_saved_foods_saved_at ON saved_foods(user_id, saved_at DESC);

-- Enable Row Level Security
ALTER TABLE saved_foods ENABLE ROW LEVEL SECURITY;

-- RLS Policy: Users can view their own saved foods
CREATE POLICY "Users can view their own saved foods"
    ON saved_foods FOR SELECT
    USING (auth.uid() = user_id);

-- RLS Policy: Users can insert their own saved foods
CREATE POLICY "Users can insert their own saved foods"
    ON saved_foods FOR INSERT
    WITH CHECK (auth.uid() = user_id);

-- RLS Policy: Users can update their own saved foods
CREATE POLICY "Users can update their own saved foods"
    ON saved_foods FOR UPDATE
    USING (auth.uid() = user_id);

-- RLS Policy: Users can delete their own saved foods
CREATE POLICY "Users can delete their own saved foods"
    ON saved_foods FOR DELETE
    USING (auth.uid() = user_id);

-- Add comment to table
COMMENT ON TABLE saved_foods IS 'Stores users favorite/saved foods for quick logging';
