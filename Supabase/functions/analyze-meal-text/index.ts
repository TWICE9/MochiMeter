// Supabase Edge Function to analyze a typed meal description
import { serve } from "https://deno.land/std@0.168.0/http/server.ts"
import { createClient } from "https://esm.sh/@supabase/supabase-js@2"

// API Keys
const perplexityKey = Deno.env.get("PERPLEXITY_API_KEY")

// CORS headers - restricted to Supabase and app origins
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

// Custom error classes for better debugging
class AIApiError extends Error {
  statusCode = 502  // Bad Gateway - upstream AI failed
  constructor(message: string, public provider: string) {
    super(`[${provider}] ${message}`)
    this.name = "AIApiError"
  }
}

class RateLimitError extends Error {
  statusCode = 429  // Too Many Requests
  constructor(message: string) {
    super(message)
    this.name = "RateLimitError"
  }
}

class ParseError extends Error {
  statusCode = 422  // Unprocessable Entity - couldn't parse response
  constructor(message: string, public rawContent: string) {
    super(message)
    this.name = "ParseError"
  }
}

class ValidationError extends Error {
  statusCode = 400  // Bad Request
  constructor(message: string) {
    super(message)
    this.name = "ValidationError"
  }
}

// Simple in-memory rate limiting (per user, resets on function cold start)
const rateLimitMap = new Map<string, { count: number; resetTime: number }>()
const RATE_LIMIT = 30 // requests per window
const RATE_WINDOW_MS = 60 * 1000 // 1 minute

function checkRateLimit(userId: string): boolean {
  const now = Date.now()
  const userLimit = rateLimitMap.get(userId)

  if (!userLimit || now > userLimit.resetTime) {
    rateLimitMap.set(userId, { count: 1, resetTime: now + RATE_WINDOW_MS })
    return true
  }

  if (userLimit.count >= RATE_LIMIT) {
    return false
  }

  userLimit.count++
  return true
}

// Common food slang/aliases to expand for better recognition
const foodSlangMap: Record<string, string> = {
  // McDonald's slang (various regions)
  "maccas": "McDonald's",
  "maccies": "McDonald's",
  "maccy d's": "McDonald's",
  "maccy ds": "McDonald's",
  "mickey d's": "McDonald's",
  "mickey ds": "McDonald's",
  "mcds": "McDonald's",
  // Burger King
  "bk": "Burger King",
  "hungry jacks": "Burger King", // Australian name
  // KFC
  "kfc": "KFC (Kentucky Fried Chicken)",
  "dirty bird": "KFC",
  // Starbucks
  "starbies": "Starbucks",
  "sbux": "Starbucks",
  // Subway
  "subways": "Subway",
  // Taco Bell
  "t-bell": "Taco Bell",
  "tbell": "Taco Bell",
  // Dunkin
  "dunkin": "Dunkin' Donuts",
  "dunkies": "Dunkin' Donuts",
  // Chipotle
  "chipotles": "Chipotle",
  // Chick-fil-A
  "chick fil a": "Chick-fil-A",
  "cfa": "Chick-fil-A",
  // Tim Hortons
  "timmies": "Tim Hortons",
  "tim hortons": "Tim Hortons",
  // In-N-Out
  "in n out": "In-N-Out Burger",
  "innout": "In-N-Out Burger",
  // Wendy's
  "wendys": "Wendy's",
  // Five Guys
  "5 guys": "Five Guys",
}

// Expand slang terms in the description
function expandFoodSlang(description: string): string {
  let expanded = description.toLowerCase()

  for (const [slang, fullName] of Object.entries(foodSlangMap)) {
    // Use word boundary matching to avoid partial replacements
    const regex = new RegExp(`\\b${slang}\\b`, "gi")
    if (regex.test(expanded)) {
      expanded = expanded.replace(regex, fullName)
    }
  }

  return expanded
}

serve(async (req) => {
  const corsHeaders = getCorsHeaders(req)

  // Handle CORS preflight
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders })
  }

  try {
    // Verify user is authenticated
    const supabase = createClient(
      Deno.env.get("SUPABASE_URL") ?? "",
      Deno.env.get("SUPABASE_ANON_KEY") ?? "",
      {
        global: { headers: { Authorization: req.headers.get("Authorization")! } },
      },
    )

    const {
      data: { user },
      error: userError,
    } = await supabase.auth.getUser()
    if (userError || !user) {
      throw new Error("Unauthorized")
    }

    // Check rate limit
    if (!checkRateLimit(user.id)) {
      return new Response(
        JSON.stringify({ error: "Rate limit exceeded. Please try again later." }),
        { status: 429, headers: { ...corsHeaders, "Content-Type": "application/json" } }
      )
    }

    console.log("Meal text analysis request received")

    const { description } = await req.json()
    const trimmedDescription = (description ?? "").trim()
    if (!trimmedDescription) {
      throw new Error("No description provided")
    }

    // Expand any food slang (e.g., "maccas" -> "McDonald's")
    const expandedDescription = expandFoodSlang(trimmedDescription)

    // ============================================
    // AI ORCHESTRATOR
    // ============================================
    // Strategy: Try Perplexity (live data) first. If it fails/errors, fallback to GPT-5 Mini (fast/stable).

    let content = ""
    let usedModel = "perplexity"

    try {
      console.log("🤖 [Primary] Calling Perplexity Sonar...")
      const perplexityResponse = await fetch("https://api.perplexity.ai/chat/completions", {
        method: "POST",
        headers: {
          Authorization: `Bearer ${perplexityKey}`,
          "Content-Type": "application/json",
        },
        body: JSON.stringify({
          model: "sonar",
          messages: [
            {
              role: "system",
              content: `You are a nutrition expert. Search for accurate nutritional data for the food item provided.

CRITICAL RULES:
1. GENERIC vs BRANDED: If the user does NOT mention a specific brand/store/restaurant name, return GENERIC food data (e.g., "caesar salad" should be generic caesar salad, NOT "Woolworths Caesar Salad" or "McDonald's Caesar Salad").
2. BRANDED ITEMS: ONLY use brand-specific data if the user explicitly mentions a brand (McDonald's, Burger King, Starbucks, Subway, Woolworths, Coles, etc.).
3. For generic foods: Use USDA database standard values.
4. For branded foods: Search for and use ACTUAL published nutritional data from their official menus.
5. If checking a "Meal" or "Bundle" (e.g., "McSmart Meal", "Box Meal") and exact data isn't found, SEARCH for the standard components and SUM their values. Do NOT return nulls; give your best estimate.
6. Recognize brand indicators: "mcmuffin", "big mac", "whopper", "frappuccino" are branded items with known values.
7. NUMBERS ONLY for nutritional values. Do NOT return null or strings with units. If uncertain, provide a conservative estimate.
8. For ingredientBreakdown, list each main component of the dish with its estimated calorie contribution.
9. The "name" field should match what the user searched for, NOT add store names they didn't mention.

Return ONLY valid JSON, no markdown or explanation.`,
            },
            {
              role: "user",
              content: `Search for the exact nutritional information for: "${expandedDescription}"

Find the real nutritional values from official sources or nutrition databases.

Return JSON format (NUMBERS ONLY for values, NO strings with units):
{"name":"<full item name>","servingSize":"<1 item or portion>","calories":<total>,"protein":<g>,"carbs":<g>,"fat":<g>,"fiber":<g>,"sugar":<g>,"salt":<g>,"potassium":<mg>,"confidence":"high/medium/low","ingredientBreakdown":[{"name":"<component1>","calories":<num>},{"name":"<component2>","calories":<num>}]}`,
            },
          ],
          max_tokens: 500,
          temperature: 0.1,
        }),
      })

      if (!perplexityResponse.ok) {
        throw new Error(`Perplexity returned status ${perplexityResponse.status}`)
      }

      const perplexityData = await perplexityResponse.json()
      content = perplexityData.choices[0].message.content as string

      // Basic validation - if empty content, throw to trigger fallback
      if (!content || content.length < 10) {
        throw new Error("Perplexity returned empty content")
      }

    } catch (primaryError: any) {
      console.error(`⚠️ Primary AI (Perplexity) failed: ${primaryError.message}. Switching to Fallback...`)

      // ============================================
      // FALLBACK: GPT-5 Mini
      // ============================================
      console.log("🤖 [Fallback] Calling OpenAI GPT-5 Mini...")

      const openAIKey = Deno.env.get("OPENAI_API_KEY")
      if (!openAIKey) {
        throw new Error("OpenAI API key not configured for fallback")
      }

      const openAIResponse = await fetch("https://api.openai.com/v1/chat/completions", {
        method: "POST",
        headers: {
          Authorization: `Bearer ${openAIKey}`,
          "Content-Type": "application/json",
        },
        body: JSON.stringify({
          model: "gpt-5-mini",
          response_format: { type: "json_object" },
          reasoning_effort: "minimal",
          messages: [
            {
              role: "system",
              content: `You are a nutrition expert with comprehensive knowledge of restaurant menus (McDonald's, KFC, etc) and generic foods.
RULES:
1. GENERIC vs BRANDED: If no brand/store/restaurant is mentioned, return GENERIC food data. Do NOT add brand names the user didn't specify.
2. For BRANDED items (only if user explicitly mentions a brand): Use known official nutrition data.
3. For GENERIC items: Use USDA standard values.
4. For BUNDLES/MEALS: Sum the components (e.g. Burger + Fries + Drink).
5. Be CONSERVATIVE with estimates.
6. Return PURE JSON with numeric values only.
7. Include ingredientBreakdown listing each main component with its calorie contribution.
8. The "name" field should match what the user searched for, not add store names.`,
            },
            {
              role: "user",
              content: `Analyze: "${expandedDescription}"
              
Return JSON structure:
{"name":"string","servingSize":"string","calories":number,"protein":number,"carbs":number,"fat":number,"fiber":number,"sugar":number,"salt":number,"potassium":number,"confidence":"high|medium|low","ingredientBreakdown":[{"name":"component","calories":number}]}`,
            },
          ],
          max_completion_tokens: 800,
        }),
      })

      if (!openAIResponse.ok) {
        const errData = await openAIResponse.json()
        throw new AIApiError(`${errData.error?.message || openAIResponse.status}`, "GPT-5-Mini")
      }

      const openAIData = await openAIResponse.json()
      content = openAIData.choices[0].message.content as string
      usedModel = "gpt-5-mini"
    }

    const cleanContent = content
      .replace(/```json\n?/g, "")
      .replace(/```\n?/g, "")
      .trim()

    console.log("Cleaned AI Content:", cleanContent)

    let nutritionData
    try {
      nutritionData = JSON.parse(cleanContent)

      // Sanitize numeric fields - ensure they are numbers, not strings with units
      const numericFields = ['calories', 'protein', 'carbs', 'fat', 'fiber', 'sugar', 'salt', 'potassium']
      for (const field of numericFields) {
        if (nutritionData[field]) {
          if (typeof nutritionData[field] === 'string') {
            // Extract number from string (e.g., "12g" -> 12, "approx 500" -> 500)
            const match = nutritionData[field].match(/[\d.]+/)
            if (match) {
              nutritionData[field] = parseFloat(match[0])
            } else {
              nutritionData[field] = 0
            }
          } else if (typeof nutritionData[field] !== 'number') {
            nutritionData[field] = 0
          }
        } else {
          // Default to 0 if missing
          nutritionData[field] = 0
        }
      }

      console.log("Sanitized Data:", JSON.stringify(nutritionData))

    } catch (parseError) {
      console.error("Failed to parse AI response as JSON:", cleanContent)
      throw new ParseError("Failed to parse nutrition data from AI response", cleanContent)
    }

    console.log("Meal analysis complete")

    return new Response(JSON.stringify(nutritionData), {
      headers: { ...corsHeaders, "Content-Type": "application/json" },
      status: 200,
    })
  } catch (error: unknown) {
    // Determine status code based on error type
    let statusCode = 400
    let errorMessage = "Unknown error"
    let errorName = "Error"
    let details = ""

    if (error instanceof AIApiError) {
      statusCode = error.statusCode
      errorMessage = error.message
      errorName = error.name
      details = `Provider: ${error.provider}`
    } else if (error instanceof RateLimitError) {
      statusCode = error.statusCode
      errorMessage = error.message
      errorName = error.name
    } else if (error instanceof ParseError) {
      statusCode = error.statusCode
      errorMessage = error.message
      errorName = error.name
      details = `Raw content (first 200 chars): ${error.rawContent.substring(0, 200)}`
    } else if (error instanceof ValidationError) {
      statusCode = error.statusCode
      errorMessage = error.message
      errorName = error.name
    } else if (error instanceof Error) {
      errorMessage = error.message
      errorName = error.name
      details = error.stack ?? ""
    }

    console.error(`❌ [${errorName}] Status ${statusCode}: ${errorMessage}`)
    if (details) console.error(`   Details: ${details}`)

    return new Response(
      JSON.stringify({
        error: errorMessage,
        errorType: errorName,
        statusCode: statusCode,
        details: details,
      }),
      {
        status: statusCode,
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      },
    )
  }
})
