-- =========================================
-- Add recent race/distance finish times to running_profiles
-- =========================================
-- Replaces the single "typical_pace_seconds_per_km" input (too abstract for
-- most runners) with concrete finish times at common distances. The AI plan
-- generator uses these to calibrate training paces accurately.

ALTER TABLE public.running_profiles
  ADD COLUMN IF NOT EXISTS recent_1km_seconds INTEGER,
  ADD COLUMN IF NOT EXISTS recent_5km_seconds INTEGER,
  ADD COLUMN IF NOT EXISTS recent_10km_seconds INTEGER,
  ADD COLUMN IF NOT EXISTS recent_half_marathon_seconds INTEGER,
  ADD COLUMN IF NOT EXISTS recent_marathon_seconds INTEGER;
