# Yumo Supabase Data Guidelines

> **Purpose**: This document provides a complete reference of all Supabase tables, data structures, authentication flows, and sync mechanisms used in the Yumo iOS app. Use this as the foundation for building the Android version to ensure cross-platform data consistency.

---

## Table of Contents

1. [Overview](#overview)
2. [Authentication](#authentication)
3. [Database Tables](#database-tables)
   - [User Tables](#user-tables)
   - [Global Tables](#global-tables)
4. [Storage Buckets](#storage-buckets)
5. [Edge Functions](#edge-functions)
6. [Data Sync Strategy](#data-sync-strategy)
7. [Row Level Security (RLS)](#row-level-security-rls)
8. [Data Models Reference](#data-models-reference)
9. [API Usage Examples](#api-usage-examples)
10. [Important Implementation Notes](#important-implementation-notes)

---

## Overview

Yumo uses **Supabase** as the backend-as-a-service platform providing:
- **Authentication**: Email/password, Apple Sign-In, Google Sign-In
- **PostgreSQL Database**: User data, food logs, recipes, and more
- **Object Storage**: Food images
- **Edge Functions**: AI food analysis using OpenAI/Perplexity

### Supabase Configuration

```
URL: (stored in Secrets.xcconfig as SUPABASE_URL)
Anon Key: (stored in Secrets.xcconfig as SUPABASE_ANON_KEY)
```

The iOS app uses the official [Supabase Swift SDK](https://github.com/supabase/supabase-swift).

For Android, use the official [Supabase Kotlin SDK](https://github.com/supabase-community/supabase-kt).

---

## Authentication

### Supported Auth Methods

| Method | Provider | Notes |
|--------|----------|-------|
| Email/Password | Supabase Auth | Standard email signup/login |
| Sign in with Apple | Apple OAuth | Required for iOS App Store |
| Sign in with Google | Google OAuth | Optional |

### User Identification

- Each authenticated user has a unique `user_id` (UUID) provided by `auth.users.id`
- All user-specific data tables reference this `user_id` as a foreign key
- Row Level Security (RLS) ensures users can only access their own data

### Session Management

- Supabase handles JWT tokens automatically
- Access tokens expire and are refreshed by the SDK
- The Android app should persist the session and handle token refresh

---

## Database Tables

### User Tables

These tables contain user-specific data. All have RLS enabled and reference `auth.users(id)`.

---

#### 1. `profiles` — User Profile & Onboarding Data

**Purpose**: Stores user profile information collected during onboarding and settings.

| Column | Type | Nullable | Default | Description |
|--------|------|----------|---------|-------------|
| `user_id` | UUID | NO | — | **PRIMARY KEY**, references `auth.users(id)` |
| `name` | TEXT | NO | 'User' | User's display name |
| `birthdate` | TEXT | NO | — | ISO8601 date string |
| `gender` | TEXT | NO | — | 'Male', 'Female', 'Prefer Not to Say' |
| `height_cm` | INTEGER | NO | — | Height in centimeters |
| `weight_kg` | DOUBLE PRECISION | NO | — | Current weight in kg |
| `activity_level` | TEXT | NO | — | '0-2 workouts a week', '3-5 workouts a week', '6+ workouts a week' |
| `weight_goal` | INTEGER | NO | — | 0=Lose, 1=Maintain, 2=Gain |
| `target_weight` | DOUBLE PRECISION | NO | — | Goal weight in kg |
| `daily_calories` | INTEGER | NO | — | Daily calorie target |
| `daily_protein` | INTEGER | NO | — | Daily protein target (g) |
| `daily_carbs` | INTEGER | NO | — | Daily carbs target (g) |
| `daily_fat` | INTEGER | NO | — | Daily fat target (g) |
| `blockers` | TEXT[] | YES | — | Array of blockers (onboarding) |
| `diet_type` | TEXT | YES | — | 'Regular', 'Pescatarian', 'Vegetarian', 'Vegan' |
| `goals_to_accomplish` | TEXT[] | YES | — | Array of user goals (onboarding) |
| `referral_code` | TEXT | YES | — | Optional referral code |
| `healthkit_enabled` | BOOLEAN | YES | false | HealthKit permission status |
| `created_at` | TIMESTAMPTZ | NO | NOW() | — |
| `updated_at` | TIMESTAMPTZ | NO | NOW() | Auto-updated on changes |

**Relationships**: One-to-one with `auth.users`

---

#### 2. `user_food_logs` — Food Diary Entries

**Purpose**: Stores all food items logged by the user with full nutrition data.

| Column | Type | Nullable | Default | Description |
|--------|------|----------|---------|-------------|
| `id` | UUID | NO | uuid_generate_v4() | **PRIMARY KEY** |
| `user_id` | UUID | NO | — | References `auth.users(id)` |
| `name` | TEXT | NO | — | Food name |
| `timestamp` | TIMESTAMPTZ | NO | NOW() | When the food was logged |
| `serving_size_description` | TEXT | NO | — | e.g., "1 cup", "100g" |
| `serving_amount` | DOUBLE PRECISION | NO | — | Number of servings consumed |
| `calories_per_serving` | DOUBLE PRECISION | NO | 0 | Calories per one serving |
| `protein_per_serving` | DOUBLE PRECISION | NO | 0 | Protein in grams |
| `carbs_per_serving` | DOUBLE PRECISION | NO | 0 | Carbs in grams |
| `fat_per_serving` | DOUBLE PRECISION | NO | 0 | Fat in grams |
| `fiber_per_serving` | DOUBLE PRECISION | NO | 0 | Fiber in grams |
| `sugar_per_serving` | DOUBLE PRECISION | NO | 0 | Sugar in grams |
| `salt_per_serving` | DOUBLE PRECISION | NO | 0 | Salt in grams |
| `potassium_per_serving` | DOUBLE PRECISION | NO | 0 | Potassium in mg |
| `barcode` | TEXT | YES | — | Product barcode if scanned |
| `brand` | TEXT | YES | — | Brand name |
| `is_halal` | BOOLEAN | YES | false | Halal certification flag |
| `recipe_id` | UUID | YES | — | If this is a recipe ingredient |
| `image_path` | TEXT | YES | — | Path in `food-images` storage bucket |
| `created_at` | TIMESTAMPTZ | NO | NOW() | — |
| `updated_at` | TIMESTAMPTZ | NO | NOW() | Auto-updated on changes |

**Indexes**:
- `idx_user_food_logs_user_id` on `user_id`
- `idx_user_food_logs_timestamp` on `timestamp`
- `idx_user_food_logs_recipe_id` on `recipe_id`

**Computed Values** (calculate in app):
- `totalCalories = calories_per_serving × serving_amount`
- Same pattern for protein, carbs, fat, etc.

---

#### 3. `user_water_logs` — Water Intake Tracking

**Purpose**: Stores water intake entries.

| Column | Type | Nullable | Default | Description |
|--------|------|----------|---------|-------------|
| `id` | UUID | NO | uuid_generate_v4() | **PRIMARY KEY** |
| `user_id` | UUID | NO | — | References `auth.users(id)` |
| `amount_ml` | DOUBLE PRECISION | NO | — | Water amount in milliliters |
| `timestamp` | TIMESTAMPTZ | NO | NOW() | When logged |
| `created_at` | TIMESTAMPTZ | NO | NOW() | — |
| `updated_at` | TIMESTAMPTZ | NO | NOW() | — |

---

#### 4. `user_weight_logs` — Weight Tracking History

**Purpose**: Stores weight entries for progress tracking.

| Column | Type | Nullable | Default | Description |
|--------|------|----------|---------|-------------|
| `id` | UUID | NO | uuid_generate_v4() | **PRIMARY KEY** |
| `user_id` | UUID | NO | — | References `auth.users(id)` |
| `weight_kg` | DOUBLE PRECISION | NO | — | Weight in kilograms |
| `note` | TEXT | YES | — | Optional note (e.g., "morning") |
| `timestamp` | TIMESTAMPTZ | NO | NOW() | When logged |
| `created_at` | TIMESTAMPTZ | NO | NOW() | — |
| `updated_at` | TIMESTAMPTZ | NO | NOW() | — |

---

#### 5. `user_fasting_logs` — Intermittent Fasting Sessions

**Purpose**: Stores fasting session data.

| Column | Type | Nullable | Default | Description |
|--------|------|----------|---------|-------------|
| `id` | UUID | NO | uuid_generate_v4() | **PRIMARY KEY** |
| `user_id` | UUID | NO | — | References `auth.users(id)` |
| `start_time` | TIMESTAMPTZ | NO | — | When fast started |
| `end_time` | TIMESTAMPTZ | YES | — | When fast ended (NULL if active) |
| `goal_hours` | DOUBLE PRECISION | NO | — | Target fasting duration (e.g., 16) |
| `created_at` | TIMESTAMPTZ | NO | NOW() | — |
| `updated_at` | TIMESTAMPTZ | NO | NOW() | — |

**Computed Values** (calculate in app):
- `duration = end_time - start_time` (in seconds)
- `isActive = end_time IS NULL`

---

#### 6. `user_recipes` — Custom Recipes

**Purpose**: Stores user-created recipes. Recipe ingredients are stored as food logs with a `recipe_id` reference.

| Column | Type | Nullable | Default | Description |
|--------|------|----------|---------|-------------|
| `id` | UUID | NO | uuid_generate_v4() | **PRIMARY KEY** |
| `user_id` | UUID | NO | — | References `auth.users(id)` |
| `name` | TEXT | NO | — | Recipe name |
| `servings` | DOUBLE PRECISION | NO | 1.0 | Number of servings recipe makes |
| `created_at` | TIMESTAMPTZ | NO | NOW() | — |
| `updated_at` | TIMESTAMPTZ | NO | NOW() | — |

**Important**: Recipe ingredients are `user_food_logs` entries where `recipe_id = this recipe's id`. The iOS app uses a cascade delete relationship locally.

---

#### 7. `user_reminders` — Notification Reminders

**Purpose**: Stores user-configured reminder notifications.

| Column | Type | Nullable | Default | Description |
|--------|------|----------|---------|-------------|
| `id` | UUID | NO | uuid_generate_v4() | **PRIMARY KEY** |
| `user_id` | UUID | NO | — | References `auth.users(id)` |
| `title` | TEXT | NO | — | Reminder title |
| `notes` | TEXT | NO | '' | Additional notes |
| `time` | TIMESTAMPTZ | NO | — | Time to trigger reminder |
| `is_enabled` | BOOLEAN | NO | true | Whether reminder is active |
| `weekdays` | INTEGER[] | NO | {1,2,3,4,5,6,7} | Days to repeat (1=Sun, 7=Sat) |
| `notification_id` | TEXT | NO | — | Local notification identifier |
| `created_at` | TIMESTAMPTZ | NO | NOW() | — |
| `updated_at` | TIMESTAMPTZ | NO | NOW() | — |

---

#### 8. `shopping_items` — Shopping List

**Purpose**: Simple shopping list functionality.

| Column | Type | Nullable | Default | Description |
|--------|------|----------|---------|-------------|
| `id` | UUID | NO | gen_random_uuid() | **PRIMARY KEY** |
| `user_id` | UUID | NO | — | References `auth.users` |
| `name` | TEXT | NO | — | Item name |
| `is_completed` | BOOLEAN | YES | false | Checked off status |
| `created_at` | TIMESTAMPTZ | YES | NOW() | — |

---

#### 9. `saved_foods` — Favorite/Saved Foods

**Purpose**: Stores foods users save for quick re-logging.

| Column | Type | Nullable | Default | Description |
|--------|------|----------|---------|-------------|
| `id` | UUID | NO | — | **PRIMARY KEY** |
| `user_id` | UUID | NO | — | References `auth.users(id)` |
| `food_name` | TEXT | NO | — | Food name |
| `brand` | TEXT | YES | — | Brand name |
| `barcode` | TEXT | YES | — | Product barcode |
| `calories_per_serving` | DOUBLE PRECISION | NO | — | — |
| `protein_per_serving` | DOUBLE PRECISION | NO | — | — |
| `carbs_per_serving` | DOUBLE PRECISION | NO | — | — |
| `fat_per_serving` | DOUBLE PRECISION | NO | — | — |
| `fiber_per_serving` | DOUBLE PRECISION | NO | — | — |
| `sugar_per_serving` | DOUBLE PRECISION | NO | — | — |
| `serving_size_description` | TEXT | NO | — | — |
| `salt_per_serving` | DOUBLE PRECISION | YES | — | — |
| `potassium_per_serving` | DOUBLE PRECISION | YES | — | — |
| `saved_at` | TIMESTAMPTZ | NO | NOW() | — |
| `created_at` | TIMESTAMPTZ | NO | NOW() | — |
| `updated_at` | TIMESTAMPTZ | NO | NOW() | — |

---

#### 10. `pending_analyses` — Background AI Analysis Queue

**Purpose**: Stores pending/in-progress AI food analysis requests for background processing.

| Column | Type | Nullable | Default | Description |
|--------|------|----------|---------|-------------|
| `id` | UUID | NO | gen_random_uuid() | **PRIMARY KEY** |
| `user_id` | UUID | NO | — | Requesting user |
| `image_path` | TEXT | NO | — | Path in `food-images` bucket |
| `status` | TEXT | NO | 'pending' | 'pending', 'processing', 'completed', 'failed' |
| `local_food_id` | TEXT | YES | — | Local database ID for matching |
| `result` | JSONB | YES | — | Analysis result when complete |
| `error_message` | TEXT | YES | — | Error details if failed |
| `retry_count` | INTEGER | YES | 0 | Retry attempts |
| `device_info` | TEXT | YES | — | iOS version, device model |
| `created_at` | TIMESTAMPTZ | NO | NOW() | — |
| `started_at` | TIMESTAMPTZ | YES | — | When processing began |
| `completed_at` | TIMESTAMPTZ | YES | — | When finished |

**Service Role Access**: The Edge Function uses service role to update any analysis.

---

### Global Tables

These tables are NOT user-specific and are shared across all users.

---

#### `master_foods` — Shared Food Database

**Purpose**: A crowdsourced database of food items with nutrition data. Any user can read, only AI can write.

| Column | Type | Nullable | Default | Description |
|--------|------|----------|---------|-------------|
| `barcode` | TEXT | NO | — | **PRIMARY KEY** |
| `food_name` | TEXT | NO | — | Food name |
| `brand` | TEXT | YES | — | Brand name |
| `calories` | DOUBLE PRECISION | NO | — | Per serving |
| `protein` | DOUBLE PRECISION | NO | — | Per serving (g) |
| `carbs` | DOUBLE PRECISION | NO | — | Per serving (g) |
| `fat` | DOUBLE PRECISION | NO | — | Per serving (g) |
| `fiber` | DOUBLE PRECISION | NO | — | Per serving (g) |
| `sugar` | DOUBLE PRECISION | NO | — | Per serving (g) |
| `salt` | DOUBLE PRECISION | NO | — | Per serving (g) |
| `potassium` | DOUBLE PRECISION | NO | — | Per serving (mg) |
| `scan_count` | INTEGER | NO | 1 | Popularity counter |
| `updated_at` | TEXT | NO | — | ISO8601 timestamp |

**Search**: Use `ilike` for fuzzy name/brand matching, order by `scan_count DESC` for popularity.

---

#### `usda_foods` — USDA Database Reference

**Purpose**: Pre-loaded USDA food database for generic foods.

| Column | Type | Description |
|--------|------|-------------|
| `id` | — | Primary key |
| `food_name` | TEXT | Food name |
| (nutrition columns) | DOUBLE PRECISION | Same pattern as master_foods |

---

## Storage Buckets

### `food-images`

**Purpose**: Stores food photos from AI scan feature.

**Path Structure**: `{user_id}/{log_id}_{random_suffix}.jpg`

**Access**:
- Users can upload/download their own images only
- Images are JPEG, compressed to max 1024px dimension, 0.7 quality

**Example Operations**:
```kotlin
// Upload
val path = "${userId}/${logId}_${randomSuffix}.jpg"
supabase.storage.from("food-images").upload(path, imageBytes)

// Download
val bytes = supabase.storage.from("food-images").download(path)

// Delete
supabase.storage.from("food-images").remove(listOf(path))
```

---

## Edge Functions

### 1. `analyze-food` — AI Food Image Analysis

**Endpoint**: `POST /functions/v1/analyze-food`

**Authentication**: Required (Bearer token)

**Request Body**:
```json
{
  "imageBase64": "base64_encoded_image",
  // OR for background mode:
  "imagePath": "storage/path/to/image.jpg",
  "analysisId": "uuid-of-pending-analysis",
  "mode": "background"  // or "immediate"
}
```

**Response** (200):
```json
{
  "name": "Grilled Chicken Salad",
  "servingSize": "1 bowl",
  "calories": 350,
  "protein": 35,
  "carbs": 15,
  "fat": 18,
  "fiber": 5,
  "sugar": 3,
  "salt": 1.2,
  "potassium": 450,
  "confidence": "high",
  "ingredientBreakdown": [
    {"name": "chicken breast", "calories": 165},
    {"name": "mixed greens", "calories": 25}
  ]
}
```

**Rate Limit**: 20 requests/minute per user

---

### 2. `analyze-food-fix` — AI Analysis Correction

**Endpoint**: `POST /functions/v1/analyze-food-fix`

**Purpose**: Corrects an existing AI analysis based on user feedback.

**Request Body**:
```json
{
  "current": {
    "name": "Hamburger",
    "calories": 300,
    "protein": 15,
    "carbs": 30,
    "fat": 12,
    "fiber": 2,
    "sugar": 5
  },
  "correction": "there is bacon in it"
}
```

**Rate Limit**: 15 requests/minute per user

---

### 3. `analyze-meal-text` — Text-Based Food Search

**Endpoint**: `POST /functions/v1/analyze-meal-text`

**Purpose**: Analyzes a text description of food to get nutrition data.

**Request Body**:
```json
{
  "description": "Big Mac from McDonald's"
}
```

**Features**:
- Expands slang (e.g., "maccas" → "McDonald's")
- Uses Perplexity AI for live product data
- Falls back to GPT-5 Mini if needed

**Rate Limit**: 30 requests/minute per user

---

### 4. `delete-account` — Account Deletion

**Endpoint**: `POST /functions/v1/delete-account`

**Purpose**: Deletes user account and all associated data via CASCADE.

**Request Body**: None (uses auth token)

**Response** (200):
```json
{
  "message": "Account deleted successfully"
}
```

---

## Data Sync Strategy

The iOS app uses a **bidirectional sync** strategy with **last-write-wins** conflict resolution.

### Sync Flow

```
┌─────────────────────┐         ┌─────────────────────┐
│   Local Database    │ ←─────→ │   Supabase Cloud    │
│   (SwiftData/Room)  │         │   (PostgreSQL)      │
└─────────────────────┘         └─────────────────────┘
```

### Sync Order (IMPORTANT!)

1. **Recipes FIRST** — Because food logs may reference recipes
2. **Then parallel**:
   - Food logs
   - Water logs
   - Weight logs
   - Fasting logs
   - Reminders
   - User goals/profile

### Sync Algorithm per Table

```pseudocode
function syncTable(userId, localItems, cloudTable):
    // 1. Fetch cloud items
    cloudItems = supabase.from(cloudTable).select().eq("user_id", userId)
    
    // 2. Merge cloud → local (update if cloud is newer)
    for cloudItem in cloudItems:
        localItem = findByIdInLocal(cloudItem.id)
        if localItem exists:
            if cloudItem.updated_at > localItem.updated_at:
                updateLocal(localItem, cloudItem)
        else:
            insertLocal(cloudItem)
    
    // 3. Upload local → cloud (items not in cloud)
    for localItem in localItems:
        if not existsInCloud(localItem.id):
            supabase.from(cloudTable).upsert(localItem)
    
    // 4. Save local database
    saveLocalContext()
```

### Real-Time Sync

For immediate sync after user actions:
- `uploadFoodLogImmediately()` — Called right after logging food
- `uploadWaterLogImmediately()` — Called after logging water
- etc.

### Deletion Sync

When user deletes an item locally:
1. Delete from local database
2. Call `delete{Type}FromCloud(id, userId)` to remove from Supabase

---

## Row Level Security (RLS)

All user tables have RLS enabled with these standard policies:

```sql
-- SELECT: Users can only see their own data
CREATE POLICY "Users can view own {table}"
    ON public.{table} FOR SELECT
    USING (auth.uid() = user_id);

-- INSERT: Users can only insert their own data
CREATE POLICY "Users can insert own {table}"
    ON public.{table} FOR INSERT
    WITH CHECK (auth.uid() = user_id);

-- UPDATE: Users can only update their own data
CREATE POLICY "Users can update own {table}"
    ON public.{table} FOR UPDATE
    USING (auth.uid() = user_id);

-- DELETE: Users can only delete their own data
CREATE POLICY "Users can delete own {table}"
    ON public.{table} FOR DELETE
    USING (auth.uid() = user_id);
```

### Special Cases

- `pending_analyses`: Service role can update any row (for Edge Function)
- `master_foods`: Read-only for authenticated users, write by service role

---

## Data Models Reference

### Enum Values

#### Gender
- `"Male"`
- `"Female"`
- `"Prefer Not to Say"`

#### Activity Level
- `"0-2 workouts a week"`
- `"3-5 workouts a week"`
- `"6+ workouts a week"`

#### Weight Goal (stored as integer)
- `0` = Lose Weight
- `1` = Maintain Weight
- `2` = Gain Muscle

#### Diet Type
- `"Regular"`
- `"Pescatarian"`
- `"Vegetarian"`
- `"Vegan"`

#### Appearance Mode
- `"System"`
- `"Light"`
- `"Dark"`

#### Energy Unit
- `"Calories (kcal)"`
- `"Kilojoules (kJ)"`

#### Analysis Status
- `"pending"`
- `"processing"`
- `"completed"`
- `"failed"`

---

## API Usage Examples

### Kotlin/Android Examples

#### Initialize Supabase Client

```kotlin
val supabase = createSupabaseClient(
    supabaseUrl = BuildConfig.SUPABASE_URL,
    supabaseKey = BuildConfig.SUPABASE_ANON_KEY
) {
    install(Auth)
    install(Postgrest)
    install(Storage)
    install(Functions)
}
```

#### Sign In

```kotlin
// Email/Password
supabase.auth.signInWith(Email) {
    email = "user@example.com"
    password = "password123"
}

// Get current user
val user = supabase.auth.currentUserOrNull()
```

#### Fetch User Profile

```kotlin
val profile = supabase.postgrest
    .from("profiles")
    .select()
    .eq("user_id", userId)
    .decodeSingle<Profile>()
```

#### Log Food

```kotlin
@Serializable
data class CloudFoodLog(
    val id: String,
    val user_id: String,
    val name: String,
    val timestamp: String,  // ISO8601
    val serving_size_description: String,
    val serving_amount: Double,
    val calories_per_serving: Double,
    val protein_per_serving: Double,
    val carbs_per_serving: Double,
    val fat_per_serving: Double,
    val fiber_per_serving: Double,
    val sugar_per_serving: Double,
    val salt_per_serving: Double,
    val potassium_per_serving: Double,
    val barcode: String? = null,
    val brand: String? = null,
    val is_halal: Boolean = false,
    val recipe_id: String? = null,
    val image_path: String? = null,
    val updated_at: String
)

// Insert/Upsert
supabase.postgrest
    .from("user_food_logs")
    .upsert(foodLog)
```

#### Upload Food Image

```kotlin
val path = "${userId}/${logId}_${UUID.randomUUID().toString().take(8)}.jpg"

supabase.storage
    .from("food-images")
    .upload(path, imageBytes) {
        contentType = ContentType.Image.JPEG
        upsert = true
    }
```

#### Call Edge Function (AI Analysis)

```kotlin
val result = supabase.functions.invoke<AnalysisResult>("analyze-food") {
    body = buildJsonObject {
        put("imageBase64", base64Image)
    }
}
```

---

## Important Implementation Notes

### 1. User ID Handling

- All local data should store `userId` to support multi-account scenarios
- When user logs out, local data should be filtered by `userId`
- Consider offline-first: allow data entry without network, sync later

### 2. Date/Time Format

- All timestamps use ISO8601 format with timezone: `TIMESTAMPTZ`
- Store in UTC, convert to local time for display

### 3. Unit Storage

- **Weight**: Always store in kilograms (kg)
- **Height**: Always store in centimeters (cm)
- **Water**: Always store in milliliters (ml)
- **Potassium**: Store in milligrams (mg)
- Convert units for display based on user's `unit_system` preference

### 4. Nutrition Value Validation

```kotlin
// Cap values to prevent unreasonable input
fun capServingAmount(value: Double) = value.coerceIn(0.01, 100.0)
fun capCalories(value: Double) = value.coerceIn(0.0, 10000.0)
fun capMacro(value: Double) = value.coerceIn(0.0, 5000.0)
fun capDailyCalories(value: Double) = value.coerceIn(500.0, 20000.0)
fun capWeight(value: Double) = value.coerceIn(20.0, 500.0)
```

### 5. Cascade Delete

All user tables have `ON DELETE CASCADE` on the `user_id` foreign key. When a user account is deleted via the `delete-account` Edge Function, all their data is automatically removed.

### 6. Offline Support

Design the Android app to work offline:
1. Store all data locally (Room database recommended)
2. Queue sync operations when offline
3. Sync automatically when connectivity returns
4. Handle conflict resolution (last-write-wins)

### 7. Recipe-Ingredient Relationship

Recipes have ingredients that are stored as `user_food_logs` entries with a non-null `recipe_id`. When displaying a recipe, query:

```kotlin
val ingredients = supabase.postgrest
    .from("user_food_logs")
    .select()
    .eq("recipe_id", recipeId)
    .decodeList<CloudFoodLog>()
```

### 8. Image Handling

- Compress images before upload (max 1024px dimension)
- Use JPEG format with 70% quality
- Generate random suffix in filename to prevent enumeration attacks
- Download images on-demand and cache locally

---

## Quick Reference: Table Summary

| Table | Primary Key | User Scope | CASCADE Delete |
|-------|-------------|------------|----------------|
| `profiles` | `user_id` | Yes | Yes |
| `user_food_logs` | `id` (UUID) | Yes | Yes |
| `user_water_logs` | `id` (UUID) | Yes | Yes |
| `user_weight_logs` | `id` (UUID) | Yes | Yes |
| `user_fasting_logs` | `id` (UUID) | Yes | Yes |
| `user_recipes` | `id` (UUID) | Yes | Yes |
| `user_reminders` | `id` (UUID) | Yes | Yes |
| `shopping_items` | `id` (UUID) | Yes | Yes |
| `saved_foods` | `id` (UUID) | Yes | Yes |
| `pending_analyses` | `id` (UUID) | Yes | Yes |
| `master_foods` | `barcode` | No (Global) | N/A |
| `usda_foods` | `id` | No (Global) | N/A |

---

## Migration Notes for Android

1. **Start Simple**: Begin with auth, profile, and food logs
2. **Local Database**: Use Room with the same schema structure
3. **Sync Manager**: Port the `CloudSyncManager` logic
4. **Edge Functions**: Same endpoints, just use Kotlin client
5. **Feature Parity**: Add features incrementally in this order:
   - Authentication (Email, Google, Apple if needed)
   - User profile sync
   - Food logging + sync
   - Water tracking + sync
   - Weight tracking + sync
   - Fasting tracker + sync
   - Recipes + sync
   - AI food scanning
   - Reminders + sync
   - Shopping list + sync
   - Saved foods + sync

---

*Last Updated: January 2026*
*iOS Version: Yumo 10*
