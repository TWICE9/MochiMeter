// Supabase Edge Function: generate-running-plan
//
// Given an authenticated user, generates an AI running plan from their
// running_profile row. Writes the plan + planned_sessions into the DB
// using the service role, and returns the new plan_id.
//
// Model: gpt-4.1-mini — fast, cheap, strong at structured JSON output.
// Non-reasoning model: no chain-of-thought overhead, generates plans in ~10-20s.

import { serve } from "https://deno.land/std@0.168.0/http/server.ts"
import { createClient } from "https://esm.sh/@supabase/supabase-js@2"

const openAIKey = Deno.env.get("OPENAI_API_KEY")
const OPENAI_MODEL = "gpt-4.1-mini"

// --- CORS ---
const allowedOrigins = [
  Deno.env.get("SUPABASE_URL") ?? "",
  "capacitor://localhost",
  "ionic://localhost",
  "http://localhost",
]

function getCorsHeaders(req: Request) {
  const origin = req.headers.get("Origin") ?? ""
  const isAllowed = allowedOrigins.some((allowed) => origin.startsWith(allowed)) || origin === ""
  return {
    "Access-Control-Allow-Origin": isAllowed ? origin || "*" : allowedOrigins[0],
    "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
    "Access-Control-Allow-Methods": "POST, OPTIONS",
  }
}

// --- Rate limiting ---
// Up to 3 plan generations per 24h per user. The cap leaves room for the
// natural "fix a mistake" iteration cycle (wrong race date, wrong distance,
// wrong start day, etc.) without unbounded OpenAI spend from automation
// abuse. The previous "1 per 24h" was too punishing — users with a typo
// were locked out for a day.
const RATE_LIMIT_WINDOW_MS = 24 * 60 * 60 * 1000
const RATE_LIMIT_MAX_PLANS = 3

// --- Types ---
type RunningProfile = {
  user_id: string
  has_completed_onboarding: boolean
  experience: string
  has_run_before: boolean
  primary_goal: string
  weekly_run_days_target: number
  available_days: string[]           // ["mon","tue",...]
  long_run_day: string | null
  current_longest_run_km: number | null
  current_weekly_km: number | null
  typical_pace_seconds_per_km: number | null
  recent_1km_seconds: number | null
  recent_5km_seconds: number | null
  recent_10km_seconds: number | null
  recent_half_marathon_seconds: number | null
  recent_marathon_seconds: number | null
  target_race_date: string | null    // ISO
  target_race_distance: string | null
  target_race_name: string | null
  target_race_goal_time_seconds: number | null
  injuries_or_limitations: string | null
  // Other activities the user does — informs how aggressively we can stack
  // running on top of existing strength/yoga/cycling load.
  cross_training_activities: string[] | null
  cross_training_sessions_per_week: number | null
  /// Per-activity day commitments. Each entry is `"Activity:day"`
  /// (e.g. `"Strength:mon"`) so the user's existing schedule lands in the
  /// AI prompt and the plan can stay clear of conflicting hard days.
  cross_training_schedule: string[] | null
}

type PlanSession = {
  week_number: number
  day_of_week: number                // 0=Mon ... 6=Sun
  // AI only emits training sessions; rest days are filled in server-side.
  session_type: "easy" | "long" | "tempo" | "intervals" | "cross" | "recovery" | "race"
  target_distance_km: number | null
  target_duration_minutes: number | null
  target_pace_seconds_per_km: number | null
  description: string
  notes: string | null
}

type AIPlanResponse = {
  name: string
  total_weeks: number
  sessions: PlanSession[]
}

// --- JSON schema for OpenAI structured output ---
// strict:true requires every property to be in `required` — nullable fields use
// type: ["X", "null"].
const PLAN_JSON_SCHEMA = {
  type: "object",
  additionalProperties: false,
  required: ["name", "total_weeks", "sessions"],
  properties: {
    name: { type: "string", description: "Short display name, e.g. '10K in 12 weeks'" },
    total_weeks: { type: "integer", description: "Number of weeks in the plan" },
    sessions: {
      type: "array",
      items: {
        type: "object",
        additionalProperties: false,
        required: [
          "week_number",
          "day_of_week",
          "session_type",
          "target_distance_km",
          "target_duration_minutes",
          "target_pace_seconds_per_km",
          "description",
          "notes",
        ],
        properties: {
          week_number: { type: "integer", description: "1-indexed" },
          day_of_week: { type: "integer", description: "0=Mon, 6=Sun" },
          session_type: {
            type: "string",
            enum: ["easy", "long", "tempo", "intervals", "cross", "recovery", "race"],
          },
          target_distance_km: { type: ["number", "null"] },
          target_duration_minutes: { type: ["integer", "null"] },
          target_pace_seconds_per_km: { type: ["integer", "null"] },
          description: { type: "string" },
          notes: { type: ["string", "null"] },
        },
      },
    },
  },
}

// --- Helpers ---

/** Monday of the current week, anchored to noon UTC.
 *
 *  Why noon UTC: clients render in local time. If we anchor at 06:00 UTC,
 *  users in UTC-minus zones (e.g. PST = UTC-8) see "Monday 06:00 UTC" as
 *  "Sunday 22:00 PST", which makes the week strip read S-M-T-W-T-F-S instead
 *  of M-T-W-T-F-S-S. Noon UTC is "the same calendar day" in every populated
 *  timezone (UTC-12 to UTC+14), so day-of-week is stable everywhere.
 */
function nextPlanStartDate(): Date {
  const now = new Date()
  const dayOfWeek = now.getUTCDay() // 0=Sun..6=Sat
  // Convert to Mon=0..Sun=6
  const mondayOffset = (dayOfWeek + 6) % 7
  const monday = new Date(Date.UTC(
    now.getUTCFullYear(), now.getUTCMonth(), now.getUTCDate() - mondayOffset
  ))
  monday.setUTCHours(12, 0, 0, 0)
  return monday
}

function scheduledDate(start: Date, weekNumber: number, dayOfWeek: number): Date {
  const d = new Date(start)
  d.setUTCDate(d.getUTCDate() + (weekNumber - 1) * 7 + dayOfWeek)
  return d
}

/** Canonical race distance in km from the string stored in the profile. */
function raceDistanceKm(dist: string | null): number | null {
  if (!dist) return null
  const d = dist.toLowerCase()
  if (d.includes("5k") || d === "5 km") return 5.0
  if (d.includes("10k") || d === "10 km") return 10.0
  if (d.includes("half") || d.includes("21")) return 21.0975
  if (d.includes("marathon") || d.includes("42")) return 42.195
  return null
}

/** Maximum long-run distance — capped by both race goal *and* experience.
 *  A "Never" runner training for a marathon still can't safely do 32 km
 *  long runs, so experience caps override the goal-driven peaks. */
function peakLongRunKm(profile: RunningProfile): number {
  const dist = profile.target_race_distance?.toLowerCase() ?? ""
  const experience = (profile.experience ?? "").toLowerCase()

  // "Never" runners — cap aggressively. The whole first plan is about
  // building the habit and base aerobic capacity. A 5 km long run after
  // 12 weeks of consistent training is a real achievement for someone
  // who's never run before.
  if (experience === "never") {
    if (dist.includes("marathon") || dist.includes("42")) return 10
    if (dist.includes("half") || dist.includes("21")) return 8
    if (dist.includes("10k")) return 7
    if (dist.includes("5k")) return 6
    return 5
  }

  // "Beginner" — has run a bit, can stretch further than Never but well
  // short of the goal-implied peak. Roughly 60-70% of the standard peak.
  if (experience === "beginner") {
    if (dist.includes("marathon") || dist.includes("42")) return 22
    if (dist.includes("half") || dist.includes("21")) return 14
    if (dist.includes("10k")) return 11
    if (dist.includes("5k")) return 8
    switch (profile.primary_goal) {
      case "Build Distance": return 14
      case "Train for Race":  return 12
      default:                return 10
    }
  }

  // Intermediate / advanced / unspecified — use the original peaks.
  if (dist.includes("5k")) return 12
  if (dist.includes("10k")) return 15
  if (dist.includes("half") || dist.includes("21")) return 19
  if (dist.includes("marathon") || dist.includes("42")) return 32
  switch (profile.primary_goal) {
    case "Build Distance": return 24
    case "Train for Race":  return 19
    default:                return 18
  }
}

/**
 * Picks exactly `target` days out of the available set, anchored on the
 * long-run day (when set) and spaced as evenly as possible across the rest
 * to avoid back-to-back runs. Returned in Mon→Sun order.
 *
 * Mirror of `RunningPlanPreviewBuilder.chooseRunDays(...)` on the Swift
 * client — keep them in sync so the preview the user sees during onboarding
 * matches the days the generated plan actually trains on.
 *
 * `crossTrainingDays` is a soft constraint: prefer days the user isn't
 * already training on. Falls back to the full available set if dodging
 * cross days would leave us short of `target`. The long-run anchor is also
 * dropped if it collides with a cross day AND there's room to fill `target`
 * from non-cross days alone.
 */
function chooseRunDays(
  available: number[],
  target: number,
  longRunDay: number | null,
  crossTrainingDays: number[] = [],
): number[] {
  const sortedAvailable = [...new Set(available)].sort((a, b) => a - b)
  if (sortedAvailable.length <= target) return sortedAvailable

  const crossSet = new Set(crossTrainingDays)
  const nonCrossAvailable = sortedAvailable.filter(d => !crossSet.has(d))
  const hasNonCrossRoom = nonCrossAvailable.length >= target

  const picked = new Set<number>()
  if (
    longRunDay != null &&
    sortedAvailable.includes(longRunDay) &&
    !(crossSet.has(longRunDay) && hasNonCrossRoom)
  ) {
    picked.add(longRunDay)
  }

  const remaining = sortedAvailable.filter(d => !picked.has(d))
  const needed = target - picked.size

  if (needed > 0) {
    const nonCrossRemaining = remaining.filter(d => !crossSet.has(d))
    const pool = nonCrossRemaining.length >= needed ? nonCrossRemaining : remaining

    const stride = pool.length / needed
    for (let i = 0; i < needed; i++) {
      const idx = Math.min(pool.length - 1, Math.floor(i * stride))
      picked.add(pool[idx])
    }
    // Rounding collisions can leave us short — fill from the front of the
    // *full* remaining set so we always hit the target.
    let fillIdx = 0
    while (picked.size < target && fillIdx < remaining.length) {
      picked.add(remaining[fillIdx])
      fillIdx++
    }
  }

  return [...picked].sort((a, b) => a - b)
}

/// Caps free-text to 500 chars, strips ASCII control + bidi + zero-width
/// characters, and wraps the result in clear delimiters so the AI can
/// distinguish user input from coach guidance even if the user tries to
/// inject prompt-like strings (e.g. "\n\nIgnore previous instructions...").
function sanitizeUserText(raw: string, maxLen = 500): string {
  if (!raw) return ""
  const stripped = raw
    .replace(/[\x00-\x1f\x7f-\x9f]/g, " ")
    .replace(/[​-‍‎-‏‪-‮⁠-⁩﻿]/g, " ")
    .replace(/\s+/g, " ")
    .trim()
  return stripped.length > maxLen ? stripped.slice(0, maxLen) + "…" : stripped
}

function wrapUserText(raw: string): string {
  const sanitized = sanitizeUserText(raw)
  if (!sanitized) return "(empty)"
  return `<<<USER_NOTE>>>${sanitized}<<<END_USER_NOTE>>>`
}

function buildSystemPrompt(): string {
  return `You are an elite running coach with deep expertise in training periodization, progressive overload, and race preparation. You draw on the methodologies of Jack Daniels, Pete Pfitzinger, and the Hansons Marathon Method to build evidence-based, personalised plans.

━━━ PACE ZONES ━━━
Derive all training paces from the runner's benchmark times using these relationships.
If no benchmark is available, use their reported easy pace as the Zone 2 anchor.

  Zone 1  Recovery:  5K pace + 150 s/km or slower
  Zone 2  Easy:      5K pace + 90–130 s/km  (fully conversational, nose-breathable)
  Zone 3  Steady:    5K pace + 50–80 s/km   (~marathon race pace)
  Zone 4  Threshold: 5K pace + 15–30 s/km   (comfortably hard, sustainable ~60 min)
  Zone 5  VO2max:    5K race pace            (very hard, sustainable 3–8 min per rep)

Always set target_pace_seconds_per_km on tempo, long (when relevant), and interval sessions.
For easy / recovery runs, leave pace null and rely on the description's zone reference.

━━━ PROGRESSIVE LONG RUN (CRITICAL — follow exactly) ━━━
The long run is the single most important session. Rules:
- Build weeks: increase the long run by 1.5–2.5 km vs the previous build week.
- Deload weeks (every 4th week): long run is ~80% of the previous build-week long run.
- Start from current_longest_run_km (default 8 km if unknown).
- Never jump more than 3 km in a single week's long run.
- Peak long run is scheduled 3 weeks before race day (race plans).
- Vary long run sessions — don't make every long run identical:
    • Plain long run: steady Zone 2 throughout.
    • Progression long: first 70% at Zone 2, final 30% building to Zone 3.
    • Race-pace long: middle third at goal race pace, sandwiched by easy km. (weeks 6+ of race plans)
    • Tired-leg long: preceded the day before by a moderate easy run to simulate fatigue.
- Peak distances by race goal:
    5K:            10–12 km peak long run
    10K:           13–15 km
    Half Marathon: 17–19 km  (you do NOT need to run the race distance in training)
    Marathon:      29–32 km  (Hansons-style plans cap at 26 km; most plans peak at 29–32 km)

━━━ INTERVAL SESSION TEMPLATES ━━━
Choose the most appropriate template for the runner's goal and week number.
Vary the session type across the plan — don't repeat the same workout every week.

  5K goal:
    • 6 × 800 m at Zone 5 (5K pace), 90 s jog recovery
    • 5 × 1 km at 5K pace, 2 min jog recovery
    • 10 × 400 m at mile pace, 60 s recovery  (speed sharpener — use weeks 7+)
    • Fartlek: 20–25 min with 6 × (2 min Zone 5 / 2 min Zone 2)
    • Hill repeats: 8 × 45 s uphill hard, jog back down  (use in base phase)

  10K goal:
    • 5 × 1 km at 10K pace, 90 s recovery
    • 3 × 2 km at 10K pace, 2 min recovery
    • 8 × 600 m at 5K pace, 90 s recovery
    • Yasso 800s: 6–8 × 800 m (recovery jog = same duration as work interval)
    • Fartlek: 30 min with 5 × (3 min Zone 4 / 2 min Zone 2)

  Half Marathon goal:
    • 4 × 2 km at HM goal pace, 90 s recovery
    • 2 × 4 km at HM pace, 3 min recovery
    • Threshold cruise: 6–8 km continuous at Zone 4
    • 8 × 800 m at 10K pace, 90 s recovery
    • Progressive 10 km (Zone 2 → Zone 3 → Zone 4 in thirds)

  Marathon goal:
    • 3 × 3 km at MP, 3 min recovery
    • Yasso 800s: 8–10 × 800 m
    • 5 × 1 km at MP – 10 s/km, 90 s recovery
    • Long tempo: 10–12 km at Zone 3–4 (mid-plan weeks)
    • Marathon-pace segments embedded in long run

  General fitness / weight loss / no race:
    • Fartlek: 30 min with 5 × (3 min harder / 2 min easy)
    • 6 × 400 m strides at 5K effort, 90 s walk recovery
    • Hill circuit: 8 × 30 s uphill sprint, walk back recovery
    • Tempo: 20 min easy + 15 min Zone 4 + 5 min easy

━━━ TEMPO / THRESHOLD SESSIONS ━━━
Use session_type "tempo" for:
  • Steady threshold runs: 4–8 km continuous at Zone 4.
  • Cruise intervals: 3 × (2–3 km) at Zone 4, 60–90 s passive recovery.
  • Progressive tempo: start Zone 3, finish Zone 4 (label clearly in description).
Tempo sessions increase in duration / distance across the plan as fitness builds.

━━━ DELOAD WEEKS (every 4th week — non-negotiable) ━━━
  • Cut total weekly distance by 20–25%.
  • No interval sessions — replace with easy or recovery runs.
  • Long run = ~80% of the previous build-week long run.
  • Keep one tempo if the runner is mid-plan or advanced (halve the usual distance).
  • Description should reflect reduced effort: "Easy recovery week — flush the legs."

━━━ TAPER (race plans only) ━━━
  • 3 weeks before race: 80% of peak volume, maintain one quality session.
  • 2 weeks before race: 65% of peak volume, shorter intervals (keep sharpness).
  • Race week: 50% of peak volume — 2–3 short easy runs only, NO long run, race session on race day.
  • Last long run at peak distance is always 3 weeks before the race.

━━━ BEGINNER RUN/WALK PROTOCOLS ━━━
For experience = "beginner" or "never":
  Weeks 1–2: "30 min run/walk — 1 min run / 2 min walk × 10"
  Weeks 3–4: "30 min run/walk — 2 min run / 1 min walk × 10"
  Weeks 5–6: "30 min — 5 min run / 1 min walk × 5"
  Weeks 7–8: "30 min continuous easy run (Zone 2)" — graduation from run/walk
  Adjust cadence based on weekly_run_days_target (fewer days = slower progression is fine).

━━━ ABSOLUTE RULE FOR experience = "Never" (HARD CONSTRAINT) ━━━
A "Never" runner has literally never run before. They are NOT in shape to do continuous Zone 2 km. Override anything else in this prompt that conflicts with the rules below:
  - target_duration_minutes is the PRIMARY metric for weeks 1–6. Use ~20–30 min sessions.
  - target_distance_km MUST stay below the per-week peak in the SUGGESTED LONG RUN PROGRESSION (provided in the user prompt). NEVER exceed the LONG RUN PEAK CAP, no matter what zone you're prescribing.
  - Long-run sessions for a Never runner are themselves run/walks until at least week 6. A "10 km Zone 2 long run" in week 4 of a Never plan is a serious mistake and will injure the runner.
  - DO NOT include intervals, tempo, threshold, or any Zone 4/5 work in the first 8 weeks. The runner's aerobic base does not yet exist.
  - For weekly_run_days_target ≤ 2, progression is even more conservative — extend the run/walk protocol into weeks 9–10 if needed.
  - Descriptions should explicitly say "run/walk" with the run-interval / walk-interval ratio, e.g. "Run 1 min / walk 2 min × 10".
  - Easy / recovery / non-long sessions in any week should be ~60–70% of that week's projected long-run distance. Never identical to the long run.

━━━ ABSOLUTE RULE FOR experience = "Beginner" (HARD CONSTRAINT) ━━━
A "Beginner" has run a few times but has no real base. Apply these alongside the standard rules:
  - DO NOT include intervals or tempo in the first 4 weeks. Use easy + long only while the aerobic base develops.
  - Easy / recovery / non-long sessions should be ~65–75% of that week's projected long-run distance.
  - For weekly_run_days_target ≥ 4, the FOURTH and FIFTH days are recovery jogs, not additional quality work.
  - Pace prescriptions: only on tempo + intervals once those start (week 5+). Easy and long stay effort-based (Zone 2 description, pace null).

━━━ PLAN PERIODIZATION STRUCTURE ━━━
  Weeks 1–3:   Base building — easy runs, introduce 1 quality session/week.
  Week 4:      Deload.
  Weeks 5–7:   Development — add a second quality session, extend long run.
  Week 8:      Deload.
  Weeks 9–11:  Sharpening — race-specific sessions, peak long run (week 10 or 11).
  Week 12:     Deload/race taper.
  Longer plans extend the development and sharpening phases proportionally.

━━━ CROSS-TRAINING CONTEXT ━━━
The runner profile may include "Other activities" (e.g. strength, yoga, cycling) and a weekly frequency. The user manages their own cross-training calendar — do NOT schedule "cross" session_type entries for them. Instead, treat the existing load as constraint:
  • 0–1 cross sessions/week: no adjustment.
  • 2–3 cross sessions/week: cap a single hard running session per week to ONE for the first 2 weeks, then progress normally. Slightly reduce easy-run volume (≈10%).
  • 4+ cross sessions/week: keep ONE quality run per week throughout the plan. Reduce easy-run volume by 15–20%. Skip recovery jogs — assume their cross-training day fills that slot.
Activity-specific tweaks:
  • Heavy strength training listed: avoid placing intervals or tempo on Mondays (assume legs day is over the weekend).
  • Cycling listed: easier to absorb a higher running load; relax the easy-volume reduction by 5%.
  • Yoga / pilates only: no aerobic conflict — train running normally.
Acknowledge cross-training in the description's notes occasionally (e.g. "Easy day — pair with your strength session if scheduled.").

━━━ RACE DAY SESSION (read carefully) ━━━
For the final race week, include exactly one session with session_type = "race".
- target_distance_km: exact race distance (5.0 / 10.0 / 21.0975 / 42.195)
- target_pace_seconds_per_km: use EXACTLY the pre-computed "Target race pace" provided in the runner profile — do NOT invent a different number.
- If no goal time is provided, derive the race pace from the runner's most relevant benchmark (e.g. half marathon PB) and set it accordingly.
- NEVER set a pace faster than the runner's 5K race pace — that is physiologically impossible.
- description: "Race day — run the first half at goal pace, build effort in the second half."

━━━ DAY ASSIGNMENT (HARD CONSTRAINTS) ━━━
The runner profile lists available_days (e.g. ["mon","wed","fri"]) and optionally a long_run_day. These are NOT suggestions:
- EVERY session's day_of_week MUST correspond to a day in available_days. Mapping: mon=0, tue=1, wed=2, thu=3, fri=4, sat=5, sun=6.
- If you emit a session on a day NOT in available_days, the server REASSIGNS it (or drops it) — wasted output.
- If long_run_day is set, place the long run there. Other quality sessions (tempo / intervals) go on the most-spaced midweek days available, never adjacent to the long run if avoidable.
- Sessions per week must equal weekly_run_days_target exactly. Do not exceed this even if available_days has more days.
- Week 1 starts on day_of_week=0 (the plan's start date, always a Monday). If "mon" is in available_days, place a session on day_of_week=0 in week 1. Skipping the start day makes the runner feel like the plan begins a day late.

Beginner-spacing rule: when experience = "Never" or "Beginner" AND weekly_run_days_target ≤ 3, prefer non-adjacent placements within the week. If the runner's available_days are all bunched (e.g. Sat+Sun only), still respect their choice but make the second day a recovery jog rather than a quality run. Also avoid back-to-back across the week boundary (don't pair Sun + Mon as the two run days for a beginner — propose Sat + Tue or similar instead, picking from available_days).

Cross-training rule: when the profile lists a "Cross-training schedule", treat those days as occupied by another workout. Schedule the runner's hardest sessions (intervals, tempo, long run) on days WITHOUT a cross-training conflict. Easy/recovery runs MAY share a day with light cross-training (e.g. yoga). Never schedule a hard run the day after a heavy strength day if you can avoid it — leg-day fatigue ruins quality work.

━━━ OUTPUT RULES ━━━
- Output ONLY training sessions. Rest days are auto-filled on unscheduled days.
- Expected count: weekly_run_days_target × total_weeks sessions, no more, no less.
- session_type: easy | long | tempo | intervals | cross | recovery | race.
- Use "race" ONLY for the actual race-day session.
- description: one specific, actionable sentence (e.g. "6 × 800 m at 5K pace (Zone 5), 90 s jog recovery").
- notes: one short coaching cue — pacing strategy, form focus, fueling tip. Use sparingly.
- target_distance_km: provide for easy / long / recovery / race. Round to 0.5 km. Cap at 60 km/session.
- target_duration_minutes: provide for intervals / cross. Null otherwise.
- target_pace_seconds_per_km: provide for tempo / interval / race-pace long sessions. Null for easy.`
}

function buildUserPrompt(profile: RunningProfile, totalWeeks: number): string {
  const parts: string[] = []
  parts.push(`RUNNER PROFILE:`)
  parts.push(`- Experience: ${profile.experience}`)
  parts.push(`- Has run before: ${profile.has_run_before}`)
  parts.push(`- Primary goal: ${profile.primary_goal}`)
  parts.push(`- Wants to run ${profile.weekly_run_days_target} days per week`)
  parts.push(`- Available days: ${profile.available_days.join(", ") || "not specified"}`)
  if (profile.long_run_day) parts.push(`- Preferred long-run day: ${profile.long_run_day}`)
  if (profile.current_longest_run_km != null)
    parts.push(`- Current longest run: ${profile.current_longest_run_km.toFixed(1)} km`)
  if (profile.current_weekly_km != null)
    parts.push(`- Typical weekly volume: ${profile.current_weekly_km.toFixed(0)} km`)
  if (profile.typical_pace_seconds_per_km != null) {
    const m = Math.floor(profile.typical_pace_seconds_per_km / 60)
    const s = profile.typical_pace_seconds_per_km % 60
    parts.push(`- Typical easy pace: ${m}:${s.toString().padStart(2, "0")} /km`)
  }

  // Recent benchmark times — use these to derive actual training paces (easy,
  // tempo, threshold) via standard race-pace equivalence tables. They are far
  // more reliable than a self-reported "typical pace".
  function fmtTime(sec: number): string {
    const h = Math.floor(sec / 3600)
    const m = Math.floor((sec % 3600) / 60)
    const s = sec % 60
    if (h > 0) return `${h}:${m.toString().padStart(2, "0")}:${s.toString().padStart(2, "0")}`
    return `${m}:${s.toString().padStart(2, "0")}`
  }
  const recentTimes: string[] = []
  if (profile.recent_1km_seconds != null)
    recentTimes.push(`1K in ${fmtTime(profile.recent_1km_seconds)}`)
  if (profile.recent_5km_seconds != null)
    recentTimes.push(`5K in ${fmtTime(profile.recent_5km_seconds)}`)
  if (profile.recent_10km_seconds != null)
    recentTimes.push(`10K in ${fmtTime(profile.recent_10km_seconds)}`)
  if (profile.recent_half_marathon_seconds != null)
    recentTimes.push(`Half Marathon in ${fmtTime(profile.recent_half_marathon_seconds)}`)
  if (profile.recent_marathon_seconds != null)
    recentTimes.push(`Marathon in ${fmtTime(profile.recent_marathon_seconds)}`)
  if (recentTimes.length > 0)
    parts.push(`- Recent benchmark times: ${recentTimes.join(", ")} — use these to calibrate all training paces`)

  if (profile.target_race_distance) {
    parts.push(`- Target race: ${profile.target_race_distance}${profile.target_race_name ? ` (${wrapUserText(profile.target_race_name)})` : ""}`)
    if (profile.target_race_date) parts.push(`- Race date: ${profile.target_race_date}`)
    if (profile.target_race_goal_time_seconds != null) {
      parts.push(`- Goal race time: ${fmtTime(profile.target_race_goal_time_seconds)} — build the plan around achieving this target`)
      // Pre-compute the exact race pace so the AI doesn't have to guess.
      const distKm = raceDistanceKm(profile.target_race_distance)
      if (distKm) {
        const racePaceSec = Math.round(profile.target_race_goal_time_seconds / distKm)
        const rpm = Math.floor(racePaceSec / 60)
        const rps = racePaceSec % 60
        parts.push(`- Target race pace: ${rpm}:${rps.toString().padStart(2, "0")} /km (${profile.target_race_goal_time_seconds}s ÷ ${distKm} km = ${racePaceSec} s/km) — use EXACTLY this value for target_pace_seconds_per_km on the race session and race-pace long run segments`)
      }
    }
  }
  if (profile.injuries_or_limitations)
    parts.push(`- Injuries / limitations: ${wrapUserText(profile.injuries_or_limitations)}`)

  // Cross-training context. The user's existing non-running workload affects
  // how aggressively we can stack hard runs without inviting overuse injury.
  const xActivities = profile.cross_training_activities ?? []
  const xFreq = profile.cross_training_sessions_per_week ?? 0
  if (xActivities.length > 0 || xFreq > 0) {
    const list = xActivities.length > 0 ? xActivities.join(", ") : "unspecified"
    parts.push(
      `- Other activities: ${list}${xFreq > 0 ? ` (~${xFreq} session${xFreq === 1 ? "" : "s"}/week)` : ""}`
    )
  }

  // Per-day cross-training commitments. Group by day so the AI sees a clean
  // weekly picture ("Mon: Strength + Yoga, Wed: Strength, …") and can place
  // the hardest run sessions on the runner's freshest days.
  const schedule = profile.cross_training_schedule ?? []
  if (schedule.length > 0) {
    const dayOrder: { key: string; label: string }[] = [
      { key: "mon", label: "Mon" },
      { key: "tue", label: "Tue" },
      { key: "wed", label: "Wed" },
      { key: "thu", label: "Thu" },
      { key: "fri", label: "Fri" },
      { key: "sat", label: "Sat" },
      { key: "sun", label: "Sun" },
    ]
    const byDay: Record<string, string[]> = {}
    for (const entry of schedule) {
      const [activity, day] = entry.split(":")
      if (!activity || !day) continue
      const key = day.toLowerCase()
      if (!byDay[key]) byDay[key] = []
      byDay[key].push(activity)
    }
    const formatted = dayOrder
      .filter(d => byDay[d.key]?.length)
      .map(d => `${d.label}: ${byDay[d.key].join(" + ")}`)
    if (formatted.length > 0) {
      parts.push(`- Cross-training schedule: ${formatted.join(" | ")}`)
      parts.push(
        `  (Place hard runs — intervals, tempo, long — on days WITHOUT cross-training when possible. ` +
        `If the runner trains the same day as a hard cross-session, keep the run easy or move the long run elsewhere. ` +
        `Avoid hard run + heavy strength back-to-back across consecutive days.)`
      )
    }
  }

  // Compute a suggested long run progression capped at the goal-appropriate
  // peak. Starting distance and weekly increment scale with experience so a
  // never-runner doesn't get prescribed an 8 km Zone 2 long run on week 1.
  const peak = peakLongRunKm(profile)
  const experience = (profile.experience ?? "").toLowerCase()
  const isNever = experience === "never"
  const isBeginner = experience === "beginner"
  // Default starting long-run distance when the user hasn't told us their
  // current longest run. 8 km is fine for an intermediate; for a never-runner
  // their actual longest run is *zero*, so start on a 2 km run/walk.
  const defaultStartKm: number = isNever ? 2 : (isBeginner ? 4 : 8)
  const startLongKm = Math.min(profile.current_longest_run_km ?? defaultStartKm, peak)
  // Per-build-week increment. Aggressive jumps cause injuries; the 10%
  // rule says no more than ~10% weekly volume increase. For never-runners
  // even half a km per week is meaningful early on.
  const minStep: number = isNever ? 0.5 : (isBeginner ? 1.0 : 1.5)
  const maxStep: number = isNever ? 1.0 : (isBeginner ? 1.5 : 2.5)
  const longRunProgression: string[] = []
  let currentLong = startLongKm
  let peakReached = false
  for (let w = 1; w <= totalWeeks; w++) {
    const isDeload = w % 4 === 0
    const isTaper3 = profile.target_race_date && w === totalWeeks - 2
    const isTaper2 = profile.target_race_date && w === totalWeeks - 1
    const isRaceWeek = profile.target_race_date && w === totalWeeks
    if (isRaceWeek) {
      longRunProgression.push(`Wk${w}: race day (no long run)`)
    } else if (isTaper2) {
      longRunProgression.push(`Wk${w}: ${Math.round(currentLong * 0.6)} km (taper)`)
    } else if (isTaper3) {
      longRunProgression.push(`Wk${w}: ${Math.round(currentLong * 0.8)} km (taper)`)
    } else if (isDeload) {
      const deload = Math.round(currentLong * 0.8 * 2) / 2
      longRunProgression.push(`Wk${w}: ${deload} km (deload)`)
    } else {
      if (!peakReached) {
        const increase = Math.round((minStep + Math.random() * (maxStep - minStep)) * 2) / 2
        currentLong = Math.min(Math.round((currentLong + increase) * 2) / 2, peak)
        if (currentLong >= peak) peakReached = true
      }
      longRunProgression.push(`Wk${w}: ${currentLong} km`)
    }
  }
  parts.push(``)
  parts.push(`LONG RUN PEAK CAP: The long run must NEVER exceed ${peak} km for this runner's goal. This is non-negotiable.`)

  parts.push(``)
  parts.push(`SUGGESTED LONG RUN PROGRESSION (follow this closely, adjust ±1 km as needed):`)
  parts.push(longRunProgression.join(", "))
  parts.push(``)
  parts.push(`Generate a ${totalWeeks}-week plan for this runner.`)
  parts.push(`Output only training sessions (exactly ${profile.weekly_run_days_target} per week × ${totalWeeks} weeks = ~${profile.weekly_run_days_target * totalWeeks} sessions total).`)
  parts.push(`Rest days are filled in automatically on days you don't schedule.`)
  parts.push(`Week 1 starts on a Monday. day_of_week: 0=Mon, 1=Tue, ... 6=Sun.`)
  return parts.join("\n")
}

/** Decide plan length from goal + race date.
 *  - Race plans honour the actual countdown (clamped to 4–24 weeks).
 *  - Never runners get 16 weeks — there's no safe path from "haven't run" to
 *    a meaningful base in 12 weeks. The extra month lets the run/walk
 *    protocol play out properly.
 *  - Beginners with a "Build Distance" goal get 14 weeks for the same reason.
 *  - Everyone else defaults to 12. */
function decidePlanWeeks(profile: RunningProfile): number {
  if (profile.target_race_date) {
    const now = Date.now()
    const race = new Date(profile.target_race_date).getTime()
    const weeks = Math.ceil((race - now) / (7 * 24 * 60 * 60 * 1000))
    // Clamp: need at least 4 weeks to build anything meaningful; cap at 24 to
    // keep token cost bounded. Anything further out is truncated and we can
    // re-extend later with adaptive re-generation.
    return Math.max(4, Math.min(24, weeks))
  }
  const experience = (profile.experience ?? "").toLowerCase()
  if (experience === "never") return 16
  if (experience === "beginner" && profile.primary_goal === "Build Distance") return 14
  return 12
}

function planName(profile: RunningProfile, weeks: number): string {
  if (profile.target_race_distance) {
    return `${profile.target_race_distance} in ${weeks} weeks`
  }
  switch (profile.primary_goal) {
    case "Lose Weight": return `${weeks}-week running for weight loss`
    case "Build Distance": return `${weeks}-week distance build`
    case "Improve Pace": return `${weeks}-week pace development`
    default: return `${weeks}-week running base`
  }
}

// --- Main handler ---

serve(async (req) => {
  const corsHeaders = getCorsHeaders(req)
  if (req.method === "OPTIONS") return new Response("ok", { headers: corsHeaders })

  if (!openAIKey) {
    return new Response(JSON.stringify({ error: "Server missing OPENAI_API_KEY" }), {
      status: 500,
      headers: { ...corsHeaders, "Content-Type": "application/json" },
    })
  }

  try {
    // --- Auth ---
    const userClient = createClient(
      Deno.env.get("SUPABASE_URL") ?? "",
      Deno.env.get("SUPABASE_ANON_KEY") ?? "",
      { global: { headers: { Authorization: req.headers.get("Authorization")! } } },
    )
    const { data: { user }, error: authError } = await userClient.auth.getUser()
    if (authError || !user) {
      return new Response(JSON.stringify({ error: "Unauthorized" }), {
        status: 401, headers: { ...corsHeaders, "Content-Type": "application/json" },
      })
    }

    // --- Admin client for DB writes (bypasses RLS, safe because we verified user above) ---
    const admin = createClient(
      Deno.env.get("SUPABASE_URL") ?? "",
      Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ?? "",
    )

    const body = (await req.json().catch(() => ({}))) as {
      force?: boolean
      plan_start_date?: string  // ISO; client-chosen start, falls back to next Monday
      run_days?: number[]       // Canonical day list from the client (Mon=0..Sun=6)
      long_run_day_index?: number | null  // Long-run day in the same convention
    }
    // `force` from the client is no longer trusted — a rogue caller could set
    // it to bypass the 24h rate limit and burn OpenAI credits in a loop.
    // The rate-limit check below now runs unconditionally. Legitimate
    // re-onboarding still works as long as 24h have passed since the last
    // plan; tighter regenerations need a server-derived signal we don't have
    // yet (e.g. premium tier from a subscriptions table).
    const _ignoredForce = body.force === true
    void _ignoredForce

    // --- Fetch profile ---
    const { data: profile, error: profileError } = await admin
      .from("running_profiles")
      .select("*")
      .eq("user_id", user.id)
      .single()
    if (profileError || !profile) {
      return new Response(JSON.stringify({ error: "Running profile not found. Complete onboarding first." }), {
        status: 400, headers: { ...corsHeaders, "Content-Type": "application/json" },
      })
    }

    const typedProfile = profile as RunningProfile
    if (!typedProfile.has_completed_onboarding) {
      return new Response(JSON.stringify({ error: "Finish running onboarding first." }), {
        status: 400, headers: { ...corsHeaders, "Content-Type": "application/json" },
      })
    }

    // --- Rate limit (DB check) ---
    // TEMPORARILY DISABLED for development — we're iterating on plan generation
    // quality and need to regenerate frequently. Re-enable before production
    // launch by un-commenting the block below.
    //
    // {
    //   const cutoff = new Date(Date.now() - RATE_LIMIT_WINDOW_MS).toISOString()
    //   const { data: recentPlans } = await admin
    //     .from("running_plans")
    //     .select("id, created_at")
    //     .eq("user_id", user.id)
    //     .gte("created_at", cutoff)
    //     .order("created_at", { ascending: true })
    //
    //   const count = recentPlans?.length ?? 0
    //   if (count >= RATE_LIMIT_MAX_PLANS) {
    //     const oldestCreatedAt = recentPlans![0].created_at
    //     return new Response(
    //       JSON.stringify({
    //         error: `You've generated ${count} plans in the last 24 hours. Try again later.`,
    //         code: "rate_limited",
    //         next_allowed_at: new Date(new Date(oldestCreatedAt).getTime() + RATE_LIMIT_WINDOW_MS).toISOString(),
    //       }),
    //       { status: 429, headers: { ...corsHeaders, "Content-Type": "application/json" } },
    //     )
    //   }
    // }

    // --- Fast-path checks passed → kick off async generation ---
    //
    // Why async: gpt-5-mini at reasoning_effort:"high" on a 91-session plan
    // can take 60-120s. Holding the HTTP connection open through that exceeds
    // iOS URLSession's default 60s request timeout. We return 202 immediately
    // and let the client poll for the new `running_plans` row.
    const totalWeeks = decidePlanWeeks(typedProfile)
    const requestStartedAt = new Date().toISOString()

    const doGeneration = async () => {
      try {
        const systemPrompt = buildSystemPrompt()
        const userPrompt = buildUserPrompt(typedProfile, totalWeeks)

        console.log(`🏃 Generating ${totalWeeks}-week plan for user ${user.id}`)

        const openaiRes = await fetch("https://api.openai.com/v1/chat/completions", {
          method: "POST",
          headers: {
            "Authorization": `Bearer ${openAIKey}`,
            "Content-Type": "application/json",
          },
          body: JSON.stringify({
            model: OPENAI_MODEL,
            response_format: {
              type: "json_schema",
              json_schema: { name: "running_plan", strict: true, schema: PLAN_JSON_SCHEMA },
            },
            messages: [
              { role: "system", content: systemPrompt },
              { role: "user", content: userPrompt },
            ],
          }),
        })

        if (!openaiRes.ok) {
          const errText = await openaiRes.text()
          console.error("OpenAI error:", errText)
          return
        }

        const aiData = await openaiRes.json()
        const content: string = aiData.choices?.[0]?.message?.content ?? ""
        let aiPlan: AIPlanResponse
        try {
          aiPlan = JSON.parse(content)
        } catch {
          console.error("Failed to parse AI response:", content)
          return
        }

        if (!Array.isArray(aiPlan.sessions) || aiPlan.sessions.length === 0) {
          console.error("AI returned no sessions")
          return
        }

        // Mark any existing active plan as replaced.
        await admin
          .from("running_plans")
          .update({ status: "replaced" })
          .eq("user_id", user.id)
          .eq("status", "active")

        // Honor a client-chosen start date when provided, otherwise fall back
        // to the upcoming Monday. Two things we enforce on whatever they sent:
        //   1. Not in the past — racey clocks shouldn't backdate sessions.
        //   2. Snapped FORWARD to a Monday — plans assume Monday-anchored weeks
        //      (deload cycles, taper, etc.), and the iOS week strip orders
        //      days within a week starting Monday. A Wednesday-anchored plan
        //      would render as W-T-F-S-S-M-T which is jarring.
        // Sessions are anchored at noon UTC so the calendar day matches in
        // every timezone (see `nextPlanStartDate` for context).
        const startDate = (() => {
          const fallback = nextPlanStartDate()
          if (!body.plan_start_date) return fallback
          const parsed = new Date(body.plan_start_date)
          if (isNaN(parsed.getTime())) return fallback
          const now = new Date()
          const startOfToday = new Date(Date.UTC(
            now.getUTCFullYear(), now.getUTCMonth(), now.getUTCDate(), 0, 0, 0
          ))
          const validBase = parsed < startOfToday ? fallback : parsed
          // Snap forward to the next Monday in UTC. If validBase is already
          // a Monday this is a no-op.
          const dayOfWeek = validBase.getUTCDay()  // 0=Sun..6=Sat
          const daysUntilMonday = (8 - dayOfWeek) % 7  // Mon→0, Sun→1, Tue→6, ...
          const target = new Date(Date.UTC(
            validBase.getUTCFullYear(), validBase.getUTCMonth(),
            validBase.getUTCDate() + daysUntilMonday, 0, 0, 0
          ))
          target.setUTCHours(12, 0, 0, 0)
          return target
        })()
        const generationContext = {
          profile: typedProfile,
          generated_at: new Date().toISOString(),
          total_weeks_requested: totalWeeks,
        }

        const { data: insertedPlan, error: planError } = await admin
          .from("running_plans")
          .insert({
            user_id: user.id,
            name: aiPlan.name ?? planName(typedProfile, totalWeeks),
            goal_type: typedProfile.primary_goal,
            status: "active",
            start_date: startDate.toISOString(),
            total_weeks: Math.max(1, aiPlan.total_weeks || totalWeeks),
            target_race_date: typedProfile.target_race_date,
            target_race_distance: typedProfile.target_race_distance,
            target_race_name: typedProfile.target_race_name,
            target_race_goal_time_seconds: typedProfile.target_race_goal_time_seconds,
            generation_source: "ai",
            generation_context: generationContext,
            model_version: OPENAI_MODEL,
          })
          .select("id")
          .single()

        if (planError || !insertedPlan) {
          console.error("Plan insert failed:", planError)
          return
        }

        // Force AI session placement onto a deterministic set of days that
        // matches the on-boarding preview exactly. The AI is unreliable at
        // picking *which* of the available days to use — it stays inside the
        // allowed set but its specific choices vary run to run. To guarantee
        // preview ≡ generated, we compute the canonical slot list with the
        // same algorithm the Swift preview uses (`chooseRunDays`), then slot
        // the AI's sessions into those days in order:
        //   • The long run (if present) goes on `long_run_day` when available.
        //   • Remaining sessions are sorted by the AI's emitted day_of_week
        //     so the AI's intended ordering ("intervals before long run") is
        //     preserved, then placed on the remaining canonical days.
        //   • Extras beyond the canonical-slot count are dropped.
        const dayStringToInt: Record<string, number> = {
          mon: 0, tue: 1, wed: 2, thu: 3, fri: 4, sat: 5, sun: 6,
        }
        const availableDayInts: number[] = (typedProfile.available_days ?? [])
          .map(d => dayStringToInt[(d ?? "").toLowerCase()])
          .filter((d): d is number => d !== undefined)
        const profileLongRunDayInt: number | null =
          typedProfile.long_run_day != null
            ? (dayStringToInt[typedProfile.long_run_day.toLowerCase()] ?? null)
            : null

        // Parse the per-activity cross-training schedule into a flat day set
        // so the canonical-days picker can dodge them.
        const crossDayInts: number[] = (() => {
          const set = new Set<number>()
          for (const entry of typedProfile.cross_training_schedule ?? []) {
            const [, day] = entry.split(":")
            const idx = day != null ? dayStringToInt[day.toLowerCase()] : undefined
            if (idx !== undefined) set.add(idx)
          }
          return [...set].sort((a, b) => a - b)
        })()

        console.log(`🚀 GENERATOR v4 — cross-training-aware days`)
        console.log(`📥 Raw profile: available_days=${JSON.stringify(typedProfile.available_days)} long_run_day=${JSON.stringify(typedProfile.long_run_day)} target=${typedProfile.weekly_run_days_target}`)
        console.log(`📥 Parsed: availableDayInts=[${availableDayInts.join(", ")}] profileLongRunDayInt=${profileLongRunDayInt} crossDayInts=[${crossDayInts.join(", ")}]`)
        console.log(`📥 Body run_days=${JSON.stringify(body.run_days)} long_run_day_index=${JSON.stringify(body.long_run_day_index)}`)

        // Prefer the client-supplied run_days (the days the on-screen preview
        // showed) over server-side recomputation. The client's preview and the
        // generated plan must agree, and the cleanest way to guarantee that
        // is to let one side be the source of truth for day placement.
        // Validate the supplied days are a subset of available_days as a
        // safety check against malformed clients.
        const clientRunDays: number[] | null = (() => {
          if (!Array.isArray(body.run_days) || body.run_days.length === 0) return null
          const filtered = body.run_days.filter(
            d => Number.isInteger(d) && d >= 0 && d <= 6 && availableDayInts.includes(d),
          )
          // De-dupe + sort Mon→Sun.
          return [...new Set(filtered)].sort((a, b) => a - b)
        })()

        const canonicalDays = clientRunDays && clientRunDays.length > 0
          ? clientRunDays
          : chooseRunDays(
              availableDayInts,
              Math.max(1, typedProfile.weekly_run_days_target),
              profileLongRunDayInt,
              crossDayInts,
            )

        // Long-run day: prefer the explicit body value (user's selection at
        // submit time), then the stored profile value, finally the last
        // canonical day (matches the preview's `longSlot` fallback).
        const longRunDayInt: number | null = (() => {
          if (
            typeof body.long_run_day_index === "number" &&
            canonicalDays.includes(body.long_run_day_index)
          ) {
            return body.long_run_day_index
          }
          if (profileLongRunDayInt != null && canonicalDays.includes(profileLongRunDayInt)) {
            return profileLongRunDayInt
          }
          return canonicalDays.length > 0
            ? canonicalDays[canonicalDays.length - 1]
            : null
        })()

        console.log(`🎯 Canonical run days: [${canonicalDays.join(", ")}] (source=${clientRunDays ? "client" : "server"})`)
        console.log(`🎯 Effective long-run day: ${longRunDayInt}`)

        // Bucket AI sessions by week so we can validate week-by-week.
        const aiByWeek = new Map<number, PlanSession[]>()
        for (const s of aiPlan.sessions) {
          if (!aiByWeek.has(s.week_number)) aiByWeek.set(s.week_number, [])
          aiByWeek.get(s.week_number)!.push(s)
        }

        const validatedSessions: PlanSession[] = []
        for (const [weekNum, sessions] of aiByWeek) {
          const valid: PlanSession[] = []

          if (weekNum === 1) {
            console.log(`🤖 AI wk1 emitted: ${sessions.map(s => `${s.session_type}@${s.day_of_week}`).join(", ")}`)
          }

          // 1) Long-run slot — long_run_day if it's in canonical, else last
          //    canonical day (which mirrors preview's `longSlot` fallback).
          const longSession = sessions.find(s => s.session_type === "long")
          let longSlot: number | null = null
          if (longSession != null && canonicalDays.length > 0) {
            if (longRunDayInt != null && canonicalDays.includes(longRunDayInt)) {
              longSlot = longRunDayInt
            } else {
              longSlot = canonicalDays[canonicalDays.length - 1]
            }
          }
          if (longSession != null && longSlot != null) {
            valid.push({ ...longSession, day_of_week: longSlot })
          }

          // 2) Remaining canonical slots filled by the rest of the AI's
          //    sessions, ordered by the AI's emitted day so its intent
          //    ("intervals before long run") survives the remap.
          const otherSlots = canonicalDays.filter(d => d !== longSlot)
          const others = sessions
            .filter(s => s !== longSession)
            .sort((a, b) => a.day_of_week - b.day_of_week)

          if (others.length > otherSlots.length) {
            console.warn(`⚠️ Wk${weekNum}: AI emitted ${others.length} non-long sessions but only ${otherSlots.length} canonical slots — dropping extras`)
          } else if (others.length < otherSlots.length) {
            console.warn(`⚠️ Wk${weekNum}: AI emitted ${others.length} non-long sessions but ${otherSlots.length} canonical slots are open — leaving extra rest days`)
          }

          for (let i = 0; i < others.length && i < otherSlots.length; i++) {
            const s = others[i]
            const slot = otherSlots[i]
            if (s.day_of_week !== slot) {
              console.log(`↪︎ Wk${weekNum} ${s.session_type}: day ${s.day_of_week} → ${slot}`)
            }
            valid.push({ ...s, day_of_week: slot })
          }

          if (weekNum === 1) {
            console.log(`✅ Wk1 final placements: ${valid.map(s => `${s.session_type}@${s.day_of_week}`).join(", ")}`)
          }

          validatedSessions.push(...valid)
        }

        // Build a complete session grid: validated training sessions +
        // auto-filled rest days for everything else.
        const trainingBySlot = new Map<string, PlanSession>()
        for (const s of validatedSessions) {
          // If the AI produced duplicates for the same slot, last write wins.
          trainingBySlot.set(`${s.week_number}:${s.day_of_week}`, s)
        }

        // Derive a floor pace from benchmark times so we can clamp AI hallucinations.
        // The fastest any session should be is the runner's 5K race pace (Zone 5).
        // Anything faster than that is physically impossible for this runner.
        const fastestPlausiblePace = (() => {
          const best = [
            typedProfile.recent_5km_seconds ? typedProfile.recent_5km_seconds / 5 : null,
            typedProfile.recent_10km_seconds ? typedProfile.recent_10km_seconds / 10 : null,
            typedProfile.recent_half_marathon_seconds ? typedProfile.recent_half_marathon_seconds / 21.0975 : null,
            typedProfile.recent_marathon_seconds ? typedProfile.recent_marathon_seconds / 42.195 : null,
          ].filter((v): v is number => v !== null)
          // 5K pace is the fastest training pace (VO2max). Give a 5% buffer for AI rounding.
          const fastest5kPace = best.length > 0 ? Math.min(...best) * 0.95 : 180
          // Absolute floor: nobody in amateur training runs faster than 3:00/km (180 s/km).
          return Math.max(180, fastest5kPace)
        })()

        // ?? only catches null/undefined — not 0. Use || so a zero AI response
        // falls back to the pre-computed value, then clamp to at least 1.
        const effectiveTotalWeeks = Math.max(1, aiPlan.total_weeks || totalWeeks)

        // Per-week distance ceiling for safety. The AI sometimes ignores the
        // suggested progression and emits "10 km Zone 2 long run" for a Never
        // runner in week 4 — physically dangerous. We compute an experience-
        // aware ceiling using the same progression rules used to build the
        // suggested-progression prompt. Any AI distance above this ceiling
        // for that week gets clamped down.
        //
        // Returns a 2-tuple keyed by session type because easy/recovery runs
        // should be meaningfully shorter than the long run — e.g. for a Never
        // runner with a 5 km projected long run, the easy days shouldn't be
        // 5 km too. Closer to 60-70% of long-run is the right target.
        const experienceLower = (typedProfile.experience ?? "").toLowerCase()
        const isNeverRunner = experienceLower === "never"
        const isBeginnerRunner = experienceLower === "beginner"
        const planPeak = peakLongRunKm(typedProfile)
        const beginnerWeekCeiling = (
          week: number,
          sessionType: string,
        ): number | null => {
          if (!isNeverRunner && !isBeginnerRunner) return null
          // Approximate the same progression: defaultStart + step × (week - deload-skips)
          const startKm = isNeverRunner ? 2 : 4
          const stepMid = isNeverRunner ? 0.75 : 1.25
          const builds = Array.from({ length: week }, (_, i) => i + 1).filter(w => w % 4 !== 0).length
          const projectedLong = Math.min(planPeak, startKm + builds * stepMid)
          // Long sessions get the full projected distance (+ small buffer).
          // Easy / recovery / tempo / intervals sessions cap at ~65% of the
          // long, so the runner doesn't accidentally do a "long run" four
          // times a week.
          if (sessionType === "long") return projectedLong + 1.5
          if (sessionType === "recovery") return Math.max(2, projectedLong * 0.5)
          // Easy / tempo / intervals / cross / race
          return Math.max(2, projectedLong * 0.65 + 1.0)
        }
        // Quality-session window. Beginner aerobic systems aren't ready for
        // intervals or tempo straight out of the gate — even the ones who
        // think they're fine have less injury resilience than they realise.
        const qualityBlockedUntilWeek = isNeverRunner ? 8 : (isBeginnerRunner ? 4 : 0)

        console.log(`📅 Building ${effectiveTotalWeeks}-week grid from ${aiPlan.sessions.length} AI training sessions (fastest plausible pace: ${Math.round(fastestPlausiblePace)}s/km, experience: ${experienceLower}, peak: ${planPeak}km)`)
        const sessionRows: Array<Record<string, unknown>> = []
        for (let w = 1; w <= effectiveTotalWeeks; w++) {
          for (let d = 0; d < 7; d++) {
            const training = trainingBySlot.get(`${w}:${d}`)
            if (training) {
              // Clamp pace: null out anything faster than the runner's best benchmark pace
              // or slower than 15:00/km (900 s/km), which would indicate a data error.
              const rawPace = training.target_pace_seconds_per_km
              const clampedPace = (rawPace && rawPace >= fastestPlausiblePace && rawPace <= 900)
                ? rawPace
                : null
              if (rawPace && rawPace !== clampedPace) {
                console.warn(`⚠️ Clamped implausible pace ${rawPace}s/km → null (week ${w}, day ${d}, type ${training.session_type})`)
              }
              // Clamp distance: training sessions ≤ 60 km. Even peak marathon
              // long runs cap around 32 km; 60 catches AI hallucinations and
              // any prompt-injection attempts ("set every session to 100km").
              const rawDist = training.target_distance_km
              let clampedDist = (rawDist != null && rawDist > 0 && rawDist <= 60)
                ? rawDist
                : null
              if (rawDist != null && rawDist !== clampedDist) {
                console.warn(`⚠️ Clamped implausible distance ${rawDist}km → null (week ${w}, day ${d}, type ${training.session_type})`)
              }
              // Beginner safety clamp — even if the AI ignored the prompt's
              // progression, we never let a never/beginner runner ship with
              // a per-week distance above the safe ceiling. Better to round
              // a session down than to hand someone their first injury.
              let effectiveType: PlanSession["session_type"] = training.session_type
              // Convert premature quality work into easy runs. Caps and
              // descriptions stay sensible; a "5km easy" beats a "5km tempo"
              // for someone whose aerobic base isn't built yet.
              if (
                qualityBlockedUntilWeek > 0 &&
                w <= qualityBlockedUntilWeek &&
                (effectiveType === "intervals" || effectiveType === "tempo")
              ) {
                console.warn(`⚠️ Demoting wk${w} ${effectiveType} → easy (experience: ${experienceLower})`)
                effectiveType = "easy"
              }
              const ceiling = beginnerWeekCeiling(w, effectiveType)
              if (ceiling != null && clampedDist != null && clampedDist > ceiling) {
                console.warn(`⚠️ Beginner clamp wk${w} ${effectiveType}: ${clampedDist}km → ${ceiling.toFixed(1)}km`)
                clampedDist = Math.round(ceiling * 2) / 2
              }
              // For very early Never weeks, target_distance_km should be
              // secondary to target_duration_minutes — these sessions are
              // run/walks, not measured runs. Backfill duration if missing.
              let effectiveDuration = training.target_duration_minutes
              if (
                isNeverRunner &&
                w <= 6 &&
                effectiveDuration == null &&
                clampedDist != null &&
                clampedDist > 0
              ) {
                // Conservative 8 min/km estimate (mostly walking with run intervals).
                effectiveDuration = Math.max(15, Math.round(clampedDist * 8))
              }
              sessionRows.push({
                user_id: user.id,
                plan_id: insertedPlan.id,
                week_number: training.week_number,
                scheduled_date: scheduledDate(startDate, training.week_number, training.day_of_week).toISOString(),
                session_type: effectiveType,
                target_distance_km: clampedDist,
                target_duration_minutes: effectiveDuration,
                // Drop pace targets for demoted sessions and for early Never
                // weeks — pace prescriptions on run/walk sessions are
                // meaningless and discouraging.
                target_pace_seconds_per_km:
                  (effectiveType !== training.session_type) ||
                  (isNeverRunner && w <= 6)
                    ? null
                    : clampedPace,
                description: training.description,
                notes: training.notes,
              })
            } else {
              sessionRows.push({
                user_id: user.id,
                plan_id: insertedPlan.id,
                week_number: w,
                scheduled_date: scheduledDate(startDate, w, d).toISOString(),
                session_type: "rest",
                target_distance_km: null,
                target_duration_minutes: null,
                target_pace_seconds_per_km: null,
                description: "Rest day",
                notes: null,
              })
            }
          }
        }

        const { error: sessionsError } = await admin.from("planned_sessions").insert(sessionRows)
        if (sessionsError) {
          console.error("Sessions insert failed:", sessionsError)
          await admin.from("running_plans").delete().eq("id", insertedPlan.id)
          return
        }

        console.log(`✅ Plan ${insertedPlan.id} inserted with ${sessionRows.length} sessions`)
      } catch (err) {
        console.error("Async generation unhandled error:", err)
      }
    }

    // Kick off without awaiting.
    // deno-lint-ignore no-explicit-any
    const edgeRuntime = (globalThis as any).EdgeRuntime
    if (edgeRuntime?.waitUntil) {
      edgeRuntime.waitUntil(doGeneration())
    } else {
      doGeneration().catch(console.error)
    }

    return new Response(
      JSON.stringify({
        status: "accepted",
        started_at: requestStartedAt,
        total_weeks: totalWeeks,
      }),
      { status: 202, headers: { ...corsHeaders, "Content-Type": "application/json" } },
    )
  } catch (err) {
    console.error("Unhandled error:", err)
    return new Response(JSON.stringify({ error: String(err) }), {
      status: 500, headers: { ...corsHeaders, "Content-Type": "application/json" },
    })
  }
})
