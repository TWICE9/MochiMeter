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
    // PERPLEXITY API (Active)
    // ============================================
    console.log("🤖 Calling Perplexity Sonar for text meal analysis...")

    const response = await fetch("https://api.perplexity.ai/chat/completions", {
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
1. For BRANDED/RESTAURANT items (McDonald's, Burger King, Starbucks, Subway, Chipotle, etc.): Search for and use ACTUAL published nutritional data from their official menus.
2. For GENERIC foods: Use USDA database values.
3. Be ACCURATE - use real data from your search results.
4. Recognize brand variations: "mcmuffin", "big mac", "whopper", "frappuccino" are branded items with known values.

Return ONLY valid JSON, no markdown or explanation.`,
          },
          {
            role: "user",
            content: `Search for the exact nutritional information for: "${expandedDescription}"

Find the real nutritional values from official sources or nutrition databases.

Return JSON format:
{"name":"<full item name>","servingSize":"<1 item or portion>","calories":<exact num>,"protein":<g>,"carbs":<g>,"fat":<g>,"fiber":<g>,"sugar":<g>,"confidence":"high/medium/low","ingredients":["<i1>","<i2>"]}`,
          },
        ],
        max_tokens: 300,
        temperature: 0.1,
      }),
    })

    if (!response.ok) {
      const errorData = await response.json()
      console.error("Perplexity API error:", errorData)
      throw new Error(`Perplexity API error: ${response.status}`)
    }

    const data = await response.json()
    const content = data.choices[0].message.content as string

    // ============================================
    // OPENAI GPT-4o Mini (Commented out - fallback)
    // ============================================
    /*
    console.log("🤖 Calling OpenAI GPT-4o Mini for text meal analysis...")

    const response = await fetch("https://api.openai.com/v1/chat/completions", {
      method: "POST",
      headers: {
        Authorization: `Bearer ${openAIKey}`,
        "Content-Type": "application/json",
      },
      body: JSON.stringify({
        model: "gpt-4o-mini",
        messages: [
          {
            role: "system",
            content: `You are a nutrition expert with comprehensive knowledge of restaurant menus and fast food nutritional data.

CRITICAL RULES:
1. For BRANDED/RESTAURANT items (McDonald's, Burger King, Starbucks, Subway, Chipotle, etc.): Use ACTUAL published nutritional data from their official menus. Example: McDonald's Egg McMuffin = 290 cal, Big Mac = 590 cal.
2. For GENERIC foods: Use USDA database averages.
3. Be CONSERVATIVE - when uncertain, estimate on the LOWER end to avoid user frustration.
4. Recognize brand variations: "mcmuffin", "big mac", "whopper", "frappuccino" are branded items with known values.

Return ONLY valid JSON, no markdown or explanation.`,
          },
          {
            role: "user",
            content: `Analyze: "${trimmedDescription}"

If this is a branded restaurant item, use the actual published nutritional values.
If homemade/generic, estimate based on standard portions.

Return JSON format:
{"name":"<full item name>","servingSize":"<1 item or portion>","calories":<exact num>,"protein":<g>,"carbs":<g>,"fat":<g>,"fiber":<g>,"sugar":<g>,"confidence":"high/medium/low","ingredients":["<i1>","<i2>"]}`,
          },
        ],
        max_tokens: 250,
        temperature: 0.2,
      }),
    })

    if (!response.ok) {
      const errorData = await response.json()
      console.error("OpenAI API error:", errorData)
      throw new Error(`OpenAI API error: ${response.status}`)
    }

    const data = await response.json()
    const content = data.choices[0].message.content as string
    */

    const cleanContent = content
      .replace(/```json\n?/g, "")
      .replace(/```\n?/g, "")
      .trim()

    let nutritionData
    try {
      nutritionData = JSON.parse(cleanContent)
    } catch (parseError) {
      console.error("Failed to parse AI response as JSON")
      throw new Error("Failed to parse nutrition data from AI response")
    }

    console.log("Meal analysis complete")

    return new Response(JSON.stringify(nutritionData), {
      headers: { ...corsHeaders, "Content-Type": "application/json" },
      status: 200,
    })
  } catch (error) {
    console.error("❌ Error:", error.message)
    return new Response(
      JSON.stringify({
        error: error.message,
        details: error.toString(),
      }),
      {
        status: 400,
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      },
    )
  }
})
