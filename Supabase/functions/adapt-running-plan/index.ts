// Supabase Edge Function: adapt-running-plan
//
// Adjusts an existing AI-generated plan based on the runner's recent
// performance and explicit feedback. Unlike `generate-running-plan`, this:
//   - Only modifies FUTURE sessions (today onwards). Past + completed
//     sessions are immutable.
//   - Returns the smallest reasonable change set for the given signal.
//   - Logs the adaptation to running_plan_adaptations so the client can
//     surface a "Plan adjusted" banner with a human-readable summary.
//
// Triggers (passed as `reason`):
//   auto_misses         — runner has missed N sessions in a row
//   auto_pb             — runner hit a new HealthKit PB
//   auto_pace_fast      — runner consistently faster than prescribed pace
//   weekly_too_hard     — Sunday check-in: this week was too hard
//   weekly_too_easy     — Sunday check-in: this week was too easy
//   weekly_just_right   — Sunday check-in: no change needed (logged anyway)
//   manual_easier       — user tapped "ease the plan"
//   manual_harder       — user tapped "push harder"
//   manual              — generic manual fine-tune

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

// At most one auto-adaptation per 7 days. Manual reasons run on a much
// shorter 1-hour cooldown — frequent enough that a runner can fine-tune
// after a key workout, slow enough that a malicious caller can't drain
// OpenAI credits via repeated /adapt-running-plan calls.
const AUTO_RATE_LIMIT_MS = 7 * 24 * 60 * 60 * 1000
const MANUAL_RATE_LIMIT_MS = 60 * 60 * 1000

const MANUAL_REASONS: Set<Reason> = new Set([
  "manual_easier", "manual_harder", "manual",
  "weekly_too_hard", "weekly_too_easy", "weekly_just_right",
])

// --- Types ---

type Reason =
  | "auto_misses"
  | "auto_pb"
  | "auto_pace_fast"
  | "weekly_too_hard"
  | "weekly_too_easy"
  | "weekly_just_right"
  | "manual_easier"
  | "manual_harder"
  | "manual"

const ALLOWED_REASONS: Reason[] = [
  "auto_misses", "auto_pb", "auto_pace_fast",
  "weekly_too_hard", "weekly_too_easy", "weekly_just_right",
  "manual_easier", "manual_harder", "manual",
]

const AUTO_REASONS: Set<Reason> = new Set(["auto_misses", "auto_pb", "auto_pace_fast"])

type RunningProfile = {
  user_id: string
  experience: string
  primary_goal: string
  target_race_distance: string | null
  target_race_date: string | null
  target_race_goal_time_seconds: number | null
  weekly_run_days_target: number
  available_days: string[]
  long_run_day: string | null
  recent_1km_seconds: number | null
  recent_5km_seconds: number | null
  recent_10km_seconds: number | null
  recent_half_marathon_seconds: number | null
  recent_marathon_seconds: number | null
  injuries_or_limitations: string | null
  cross_training_activities: string[] | null
  cross_training_sessions_per_week: number | null
}

type PlannedSession = {
  id: string
  week_number: number
  scheduled_date: string
  session_type: string
  target_distance_km: number | null
  target_duration_minutes: number | null
  target_pace_seconds_per_km: number | null
  description: string
  notes: string | null
  completed_at: string | null
  completed_distance_km: number | null
  completed_duration_minutes: number | null
  skipped: boolean
}

type SessionEdit = {
  session_id: string
  // Any subset of these can be present. Omitted fields are left untouched.
  session_type?: string
  target_distance_km?: number | null
  target_duration_minutes?: number | null
  target_pace_seconds_per_km?: number | null
  description?: string
  notes?: string | null
}

type AdaptResponse = {
  summary: string                // human-readable banner copy
  changes: SessionEdit[]         // edits to apply
}

const ADAPT_JSON_SCHEMA = {
  type: "object",
  additionalProperties: false,
  required: ["summary", "changes"],
  properties: {
    summary: {
      type: "string",
      description: "One-sentence banner shown to the runner. Plain English. Max 140 chars.",
    },
    changes: {
      type: "array",
      items: {
        type: "object",
        additionalProperties: false,
        required: [
          "session_id",
          "session_type",
          "target_distance_km",
          "target_duration_minutes",
          "target_pace_seconds_per_km",
          "description",
          "notes",
        ],
        properties: {
          session_id: { type: "string", description: "UUID of an existing future session" },
          // Strict-mode requires every property in `required`. Use null sentinel
          // values to mean "leave unchanged" — server filters them out before applying.
          session_type: {
            type: ["string", "null"],
            enum: ["easy", "long", "tempo", "intervals", "cross", "recovery", "rest", "race", null],
          },
          target_distance_km: { type: ["number", "null"] },
          target_duration_minutes: { type: ["integer", "null"] },
          target_pace_seconds_per_km: { type: ["integer", "null"] },
          description: { type: ["string", "null"] },
          notes: { type: ["string", "null"] },
        },
      },
    },
  },
}

// --- Helpers ---

function reasonDirective(reason: Reason): string {
  switch (reason) {
    case "auto_misses":
      return "The runner has missed several scheduled sessions. Reduce the next 1-2 weeks: drop one quality session, swap a tempo for an easy run, and trim long-run distance by ~20%. Be supportive in the summary — frame it as a reset, not a punishment."
    case "auto_pb":
      return "The runner just set a new personal best. Recalibrate the target paces on tempo / interval / race-pace sessions to match their new fitness. Don't otherwise restructure the plan."
    case "auto_pace_fast":
      return "The runner is consistently 5%+ faster than prescribed paces on completed sessions. Tighten target paces (subtract 10-15 s/km) on quality runs over the next 2 weeks."
    case "weekly_too_hard":
      return "The runner just told you this week was too hard. Reduce volume by ~15% and intensity by one zone on the next week's quality sessions. Keep the long run, just slow it slightly."
    case "weekly_too_easy":
      return "The runner just told you this week was too easy. Add intensity to one quality session next week (e.g. extend a tempo, add 1-2 reps to intervals). Don't increase total volume by more than 10%."
    case "weekly_just_right":
      return "The runner says everything is on track. Return an empty changes array and a one-line summary acknowledging it (e.g. \"Keeping the plan as-is — you're tracking well.\")."
    case "manual_easier":
      return "The runner explicitly asked you to ease back. Reduce intensity or volume on the next 1-2 weeks. Smaller changes are better — trust them to know."
    case "manual_harder":
      return "The runner explicitly asked you to push harder. Add intensity to one quality session OR extend the long run by 1-2 km. Don't go overboard."
    case "manual":
      return "The runner is requesting a manual fine-tune. Look at the recent performance data and make targeted adjustments to whichever future sessions feel mis-calibrated. Smaller changes are better."
  }
}

function severityHint(reason: Reason, signal: AdaptInputSignal): string {
  // Hints for the AI on how big a change is appropriate. Pulled from the
  // signal payload the iOS client provides (or computed server-side for
  // auto reasons).
  const parts: string[] = []
  if (signal.missed_sessions_count != null && signal.missed_sessions_count > 0) {
    parts.push(`Missed sessions: ${signal.missed_sessions_count}`)
  }
  if (signal.pb_improvement_percent != null) {
    parts.push(`PB improvement: ${signal.pb_improvement_percent.toFixed(1)}%`)
  }
  if (signal.pace_divergence_seconds != null) {
    parts.push(`Avg pace divergence: ${signal.pace_divergence_seconds > 0 ? "+" : ""}${signal.pace_divergence_seconds} s/km vs target`)
  }
  if (signal.week_summary) {
    // Wrap user-supplied text in delimiters and sanitize so a malicious
    // payload like "\n\nIgnore previous instructions..." can't masquerade
    // as system guidance. See sanitizeUserText below.
    parts.push(`Week summary: ${wrapUserText(signal.week_summary)}`)
  }
  return parts.length === 0 ? "" : `\nSignal context:\n  ${parts.join("\n  ")}`
}

/// Caps free-text to 500 chars, strips newlines + control characters, and
/// wraps the result in clear delimiters so the AI can distinguish user
/// input from coach guidance even if the user tries to inject prompt-like
/// strings.
function sanitizeUserText(raw: string, maxLen = 500): string {
  if (!raw) return ""
  // Strip ASCII control chars ( -, -), bidi marks
  // (‎-‏, ‪-‮, ⁦-⁩), and zero-width glyphs
  // (​-‍, ⁠, ﻿). Then collapse whitespace + cap length.
  const stripped = raw
    .replace(/[ --]/g, " ")
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

type AdaptInputSignal = {
  missed_sessions_count?: number
  pb_improvement_percent?: number
  pace_divergence_seconds?: number
  week_summary?: string
}

function buildSystemPrompt(): string {
  return `You are an elite running coach making targeted adjustments to an existing training plan based on the runner's recent performance and explicit feedback.

Your job is NOT to rewrite the plan — only to adjust FUTURE sessions to match the runner's current state.

ADAPTATION RULES:
- Only modify sessions whose scheduled_date is today or later. The user message lists which sessions are eligible. Never touch completed or past sessions.
- Make the smallest change that fixes the issue. If paces just need tweaking, only adjust target_pace_seconds_per_km. Don't restructure unless the runner is far off-course.
- A single adaptation should typically modify 1-5 sessions. More than 8 is almost always wrong unless severity is high.
- Pace floors: never set target_pace_seconds_per_km faster than the runner's 5K race pace. Use the benchmarks from the user prompt.
- session_type values: easy | long | tempo | intervals | cross | recovery | rest | race. If you change a session to "rest", the description should say so plainly.
- Use null on any field you don't want to modify (e.g. set target_distance_km: null when you only want to change the pace). Strict mode requires the field to be present, but the server treats null as "no change".

OUTPUT FORMAT:
- "summary": one sentence the user will see in a banner. Plain language, supportive tone, max ~140 chars. Reference WHY (e.g. "Eased Tuesday tempo to 5:10/km after a heavy strength week.").
- "changes": array of session-level edits. Each change references a session_id from the eligible-sessions list and supplies the new field values (or null to keep them unchanged).

If the reason is "weekly_just_right" or no real adjustment is warranted, return changes: [] with a short summary acknowledging the runner is on track.`
}

function buildUserPrompt(
  reason: Reason,
  signal: AdaptInputSignal,
  profile: RunningProfile,
  futureSessions: PlannedSession[],
  recentCompleted: PlannedSession[],
): string {
  const futureSummary = futureSessions.map(s => {
    const fields: string[] = [
      `id=${s.id}`,
      `wk${s.week_number}`,
      `${new Date(s.scheduled_date).toISOString().slice(0, 10)}`,
      s.session_type,
    ]
    if (s.target_distance_km != null) fields.push(`${s.target_distance_km}km`)
    if (s.target_duration_minutes != null) fields.push(`${s.target_duration_minutes}min`)
    if (s.target_pace_seconds_per_km != null) {
      const m = Math.floor(s.target_pace_seconds_per_km / 60)
      const sec = s.target_pace_seconds_per_km % 60
      fields.push(`${m}:${sec.toString().padStart(2, "0")}/km`)
    }
    return `  - ${fields.join(" · ")} — ${s.description}`
  }).join("\n")

  const recentSummary = recentCompleted.length === 0
    ? "  (none in the last 14 days)"
    : recentCompleted.map(s => {
        const date = new Date(s.scheduled_date).toISOString().slice(0, 10)
        if (s.skipped) return `  - ${date} ${s.session_type}: SKIPPED`
        if (!s.completed_at) return `  - ${date} ${s.session_type}: missed (no completion)`
        const km = s.completed_distance_km != null ? `${s.completed_distance_km.toFixed(1)}km` : "?"
        const min = s.completed_duration_minutes != null ? `${s.completed_duration_minutes}min` : "?"
        const target = s.target_pace_seconds_per_km
        const actualPaceSec = (s.completed_distance_km && s.completed_duration_minutes && s.completed_distance_km > 0)
          ? Math.round((s.completed_duration_minutes * 60) / s.completed_distance_km)
          : null
        const paceStr = actualPaceSec != null
          ? `actual ${Math.floor(actualPaceSec / 60)}:${(actualPaceSec % 60).toString().padStart(2, "0")}/km${target ? ` vs target ${Math.floor(target / 60)}:${(target % 60).toString().padStart(2, "0")}` : ""}`
          : ""
        return `  - ${date} ${s.session_type} (${s.target_distance_km ?? "?"}km plan): ${km} · ${min} · ${paceStr}`.trim()
      }).join("\n")

  const benchmarks: string[] = []
  if (profile.recent_5km_seconds) benchmarks.push(`5K ${Math.floor(profile.recent_5km_seconds / 60)}:${(profile.recent_5km_seconds % 60).toString().padStart(2, "0")}`)
  if (profile.recent_10km_seconds) benchmarks.push(`10K ${Math.floor(profile.recent_10km_seconds / 60)}:${(profile.recent_10km_seconds % 60).toString().padStart(2, "0")}`)
  if (profile.recent_half_marathon_seconds) benchmarks.push(`HM ${Math.floor(profile.recent_half_marathon_seconds / 3600)}:${Math.floor((profile.recent_half_marathon_seconds % 3600) / 60).toString().padStart(2, "0")}`)
  if (profile.recent_marathon_seconds) benchmarks.push(`Marathon ${Math.floor(profile.recent_marathon_seconds / 3600)}:${Math.floor((profile.recent_marathon_seconds % 3600) / 60).toString().padStart(2, "0")}`)

  return `Reason: ${reason}
${reasonDirective(reason)}${severityHint(reason, signal)}

RUNNER PROFILE
  Experience: ${profile.experience}
  Goal: ${profile.primary_goal}${profile.target_race_distance ? ` (${profile.target_race_distance})` : ""}
  Schedule: ${profile.weekly_run_days_target} runs/week, days: ${profile.available_days.join(", ")}, long run: ${profile.long_run_day ?? "none"}
  Benchmarks: ${benchmarks.length > 0 ? benchmarks.join(" · ") : "none provided"}
  ${profile.injuries_or_limitations ? `Injuries: ${wrapUserText(profile.injuries_or_limitations)}` : ""}
  ${profile.cross_training_activities && profile.cross_training_activities.length > 0 ? `Cross-training: ${profile.cross_training_activities.join(", ")} (${profile.cross_training_sessions_per_week ?? 0}/wk)` : ""}

RECENT COMPLETED / MISSED SESSIONS (last 14 days):
${recentSummary}

FUTURE SESSIONS ELIGIBLE FOR EDITING (today onwards, max 21 listed):
${futureSummary}

Return only edits to sessions in the eligible list above. Reference each by its id.`
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

    const admin = createClient(
      Deno.env.get("SUPABASE_URL") ?? "",
      Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ?? "",
    )

    type Body = { reason?: Reason; signal?: AdaptInputSignal; force?: boolean }
    const body = (await req.json().catch(() => ({}))) as Body
    const reason: Reason = body.reason && ALLOWED_REASONS.includes(body.reason)
      ? body.reason
      : "manual"
    const signal: AdaptInputSignal = body.signal ?? {}
    // `force` from the client is no longer trusted — it previously let any
    // caller skip the cooldown. Rate limits below now run unconditionally.
    const _ignoredForce = body.force === true
    void _ignoredForce

    // --- Fetch active plan ---
    const { data: plan, error: planError } = await admin
      .from("running_plans")
      .select("*")
      .eq("user_id", user.id)
      .eq("status", "active")
      .order("created_at", { ascending: false })
      .limit(1)
      .maybeSingle()

    if (planError || !plan) {
      return new Response(JSON.stringify({ error: "No active running plan to adapt." }), {
        status: 400, headers: { ...corsHeaders, "Content-Type": "application/json" },
      })
    }

    // --- Rate limit ---
    // Auto reasons share a single 7-day window across the whole plan.
    // Manual + weekly reasons share a shorter 1-hour window — enough for
    // post-workout fine-tunes, tight enough to prevent OpenAI credit drain.
    {
      const isAuto = AUTO_REASONS.has(reason)
      const window = isAuto ? AUTO_RATE_LIMIT_MS : MANUAL_RATE_LIMIT_MS
      const cutoff = new Date(Date.now() - window).toISOString()

      // Only count rows in the SAME bucket — auto-rate-limit considers
      // prior auto adaptations; manual considers prior manual ones. That
      // way a manual fine-tune doesn't reset the auto cooldown and vice
      // versa.
      const reasonBucket = isAuto
        ? Array.from(AUTO_REASONS)
        : Array.from(MANUAL_REASONS)

      const { data: recent } = await admin
        .from("running_plan_adaptations")
        .select("id, created_at")
        .eq("user_id", user.id)
        .eq("plan_id", plan.id)
        .in("reason", reasonBucket)
        .gte("created_at", cutoff)
        .limit(1)

      if (recent && recent.length > 0) {
        const message = isAuto
          ? "Plan was already auto-adapted in the last 7 days."
          : "Wait a bit before fine-tuning again."
        return new Response(
          JSON.stringify({ error: message, code: "rate_limited" }),
          { status: 429, headers: { ...corsHeaders, "Content-Type": "application/json" } },
        )
      }
    }

    // --- Fetch profile ---
    const { data: profile } = await admin
      .from("running_profiles")
      .select("*")
      .eq("user_id", user.id)
      .single()
    if (!profile) {
      return new Response(JSON.stringify({ error: "Running profile not found." }), {
        status: 400, headers: { ...corsHeaders, "Content-Type": "application/json" },
      })
    }

    // --- Fetch future sessions (today onwards) ---
    // Server local time is UTC; sessions are anchored to 06:00 UTC, so a
    // simple ISO comparison gives "today or later" reliably.
    const todayIso = new Date(new Date().toISOString().slice(0, 10) + "T00:00:00Z").toISOString()
    const { data: futureRaw } = await admin
      .from("planned_sessions")
      .select("*")
      .eq("plan_id", plan.id)
      .gte("scheduled_date", todayIso)
      .order("scheduled_date", { ascending: true })
      .limit(21)
    const futureSessions = (futureRaw ?? []) as PlannedSession[]

    if (futureSessions.length === 0) {
      return new Response(JSON.stringify({ error: "No future sessions to adapt — plan may be complete." }), {
        status: 400, headers: { ...corsHeaders, "Content-Type": "application/json" },
      })
    }

    // --- Fetch last 14 days of completed/missed sessions ---
    const fourteenDaysAgo = new Date(Date.now() - 14 * 24 * 60 * 60 * 1000).toISOString()
    const { data: recentRaw } = await admin
      .from("planned_sessions")
      .select("*")
      .eq("plan_id", plan.id)
      .gte("scheduled_date", fourteenDaysAgo)
      .lt("scheduled_date", todayIso)
      .order("scheduled_date", { ascending: true })
    const recentCompleted = (recentRaw ?? []) as PlannedSession[]

    // --- Call OpenAI ---
    console.log(`🔧 Adapting plan ${plan.id} (reason: ${reason}, eligible: ${futureSessions.length})`)
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
          json_schema: { name: "plan_adaptation", strict: true, schema: ADAPT_JSON_SCHEMA },
        },
        messages: [
          { role: "system", content: buildSystemPrompt() },
          { role: "user", content: buildUserPrompt(reason, signal, profile as RunningProfile, futureSessions, recentCompleted) },
        ],
      }),
    })

    if (!openaiRes.ok) {
      const errText = await openaiRes.text()
      console.error("OpenAI error:", errText)
      return new Response(JSON.stringify({ error: "AI adaptation failed", detail: errText.slice(0, 200) }), {
        status: 502, headers: { ...corsHeaders, "Content-Type": "application/json" },
      })
    }

    const aiData = await openaiRes.json()
    const content: string = aiData.choices?.[0]?.message?.content ?? ""
    let aiResp: AdaptResponse
    try {
      aiResp = JSON.parse(content)
    } catch {
      console.error("Failed to parse adaptation response:", content)
      return new Response(JSON.stringify({ error: "AI returned invalid JSON" }), {
        status: 502, headers: { ...corsHeaders, "Content-Type": "application/json" },
      })
    }

    // --- Validate + apply changes ---
    // The AI sometimes references session_ids that aren't in the eligible list
    // (hallucination). We index by id and silently skip unknowns.
    const eligibleById = new Map(futureSessions.map(s => [s.id, s]))
    const fastestPlausiblePace = (() => {
      const best = [
        profile.recent_5km_seconds ? profile.recent_5km_seconds / 5 : null,
        profile.recent_10km_seconds ? profile.recent_10km_seconds / 10 : null,
        profile.recent_half_marathon_seconds ? profile.recent_half_marathon_seconds / 21.0975 : null,
        profile.recent_marathon_seconds ? profile.recent_marathon_seconds / 42.195 : null,
      ].filter((v): v is number => v !== null)
      const fastest5kPace = best.length > 0 ? Math.min(...best) * 0.95 : 180
      return Math.max(180, fastest5kPace)
    })()

    const applied: SessionEdit[] = []
    for (const change of aiResp.changes ?? []) {
      const original = eligibleById.get(change.session_id)
      if (!original) {
        console.warn(`⚠️ AI referenced unknown session_id ${change.session_id}, skipping`)
        continue
      }

      const update: Record<string, unknown> = { updated_at: new Date().toISOString() }

      if (change.session_type != null && change.session_type !== "") {
        update.session_type = change.session_type
      }
      if (change.target_distance_km != null) {
        // Clamp distance to a sane training session range. Even a peak
        // marathon long run shouldn't exceed ~32 km in training; 60 km is
        // a generous upper bound that still rejects obvious AI mistakes
        // and prompt-injection attempts ("set every session to 100km").
        const km = change.target_distance_km
        if (km > 0 && km <= 60) {
          update.target_distance_km = km
        } else {
          console.warn(`⚠️ Clamping implausible distance ${km}km on ${original.id}`)
        }
      }
      if (change.target_duration_minutes != null) {
        update.target_duration_minutes = change.target_duration_minutes
      }
      if (change.target_pace_seconds_per_km != null) {
        // Same clamp logic as generation: don't allow physically impossible paces.
        const p = change.target_pace_seconds_per_km
        if (p >= fastestPlausiblePace && p <= 900) {
          update.target_pace_seconds_per_km = p
        } else {
          console.warn(`⚠️ Clamping implausible pace ${p}s/km on ${original.id}`)
        }
      }
      if (change.description != null && change.description !== "") {
        update.description = change.description
      }
      if (change.notes !== undefined) {
        // Allow notes to be explicitly cleared (null), but only if the AI
        // sent a meaningful string OR explicitly null. The strict-schema
        // workaround means most "no change" values arrive as null too —
        // we don't have a great way to distinguish, so we only update
        // notes when the AI sent a non-empty string.
        if (typeof change.notes === "string" && change.notes !== "") {
          update.notes = change.notes
        }
      }

      // Skip no-op changes (every modifiable field came back null).
      const hasMutation = Object.keys(update).filter(k => k !== "updated_at").length > 0
      if (!hasMutation) continue

      const { error: updateError } = await admin
        .from("planned_sessions")
        .update(update)
        .eq("id", original.id)
        .eq("user_id", user.id)
      if (updateError) {
        console.error(`Failed to update session ${original.id}:`, updateError)
        continue
      }
      applied.push(change)
    }

    const summary = (aiResp.summary ?? "Plan adjusted.").slice(0, 200)

    // --- Log the adaptation ---
    const { data: logged, error: logError } = await admin
      .from("running_plan_adaptations")
      .insert({
        user_id: user.id,
        plan_id: plan.id,
        reason,
        summary,
        changes: applied,
        sessions_changed: applied.length,
      })
      .select("*")
      .single()

    if (logError) {
      console.error("Failed to log adaptation:", logError)
    }

    console.log(`✅ Adaptation complete: ${applied.length} session(s) changed — "${summary}"`)
    return new Response(
      JSON.stringify({
        adaptation_id: logged?.id ?? null,
        plan_id: plan.id,
        sessions_changed: applied.length,
        summary,
      }),
      { status: 200, headers: { ...corsHeaders, "Content-Type": "application/json" } },
    )
  } catch (err) {
    console.error("adapt-running-plan error:", err)
    return new Response(JSON.stringify({ error: "Internal error" }), {
      status: 500,
      headers: { ...getCorsHeaders(req), "Content-Type": "application/json" },
    })
  }
})
