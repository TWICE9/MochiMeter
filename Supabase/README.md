# Supabase Setup for Yumo

This directory contains SQL migrations and documentation for setting up Supabase cloud sync.

## Prerequisites

1. **Supabase Project**: You should already have a Supabase project set up (based on existing auth code)
2. **Supabase URL & Key**: Located in your project settings

## Database Migration

### Step 1: Apply User Data Tables Migration

1. Open your **Supabase Dashboard**
2. Navigate to **SQL Editor**
3. Copy the contents of `migrations/create_user_data_tables.sql`
4. Paste into the SQL Editor
5. Click **"Run"**

This will create the following tables:
- `user_food_logs` - Food diary entries
- `user_water_logs` - Water intake logs
- `user_fasting_logs` - Fasting sessions
- `user_recipes` - Custom recipes
- `user_reminders` - Notification reminders

### Step 2: Verify Tables

1. Navigate to **Database → Tables** in Supabase Dashboard
2. Confirm all 5 tables are created
3. Check that Row Level Security (RLS) is enabled for each table

## Security

All tables have Row Level Security (RLS) enabled with the following policies:

- Users can only **view, insert, update, and delete their own data**
- Uses `auth.uid()` to match `user_id` foreign key
- Data is automatically deleted when user account is deleted (`ON DELETE CASCADE`)

## Table Schema Overview

### user_food_logs
- Stores food diary entries with nutrition info
- Links to `user_recipes` via `recipe_id` (for recipe ingredients)
- Tracks: calories, protein, carbs, fat, fiber, sugar, salt, potassium
- Includes: barcode, brand, halal certification flag

### user_water_logs
- Simple water intake tracking
- Fields: `amount_ml`, `timestamp`

### user_fasting_logs
- Intermittent fasting session tracking
- Fields: `start_time`, `end_time` (nullable for active fasts), `goal_hours`

### user_recipes
- Custom recipe metadata
- Fields: `name`, `servings`
- Ingredients stored in `user_food_logs` with `recipe_id` foreign key

### user_reminders
- Notification reminder settings
- Fields: `title`, `notes`, `time`, `is_enabled`, `weekdays` (array), `notification_id`

## Sync Strategy

The app uses a **hybrid local-first approach**:

1. **Local SwiftData** is the primary data store
2. **Cloud sync** happens in the background when user is signed in
3. **Last-write-wins** conflict resolution (simple, works for single-user-per-device)
4. **Bidirectional sync**:
   - Local → Cloud: After creating/updating records
   - Cloud → Local: On app launch and periodic refresh

## Next Steps

After applying the migration, implement `CloudSyncManager` in the iOS app to handle:
- Uploading local changes to Supabase
- Downloading cloud data to local SwiftData
- Handling sync conflicts
- Background sync scheduling

## Notes

- The existing `profiles` table (already in your Supabase project) handles `UserGoals` data
- `CommonFood` is NOT synced (it's a shared local database of foods, not user-specific)
- All timestamps use `TIMESTAMPTZ` (timezone-aware) for accurate cross-device sync
