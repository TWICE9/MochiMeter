// Supabase Edge Function to correct an AI food analysis using OpenAI GPT-4o
import { serve } from "https://deno.land/std@0.168.0/http/server.ts"
import { createClient } from "https://esm.sh/@supabase/supabase-js@2"

const openAIKey = Deno.env.get("OPENAI_API_KEY")

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
const RATE_LIMIT = 15 // requests per window
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

    const { data: { user }, error: userError } = await supabase.auth.getUser()
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

    console.log(`🔧 Food correction request from user: ${user.id}`)

    const { current, correction } = await req.json()
    if (!current || !correction) {
      throw new Error("Missing current analysis or correction text")
    }

    if (correction.length > 500) {
      throw new Error("Correction text is too long (max 500 chars)")
    }

    console.log(`📝 Current: ${current.name} (${current.calories} cal)`)
    console.log(`✏️ Correction: "${correction}"`)

    // Use GPT-4o for more accurate food knowledge
    console.log("🤖 Calling OpenAI GPT-4o for food correction...")

    const systemPrompt = `You are a nutrition database expert with comprehensive knowledge of:
- Restaurant menu items (McDonald's, Starbucks, Subway, Chipotle, etc.)
- Fast food nutrition facts
- USDA FoodData Central database
- Common recipes and homemade food

Your task is to correct food analysis based on user feedback.

RULES:
1. For branded/restaurant items: Use the REAL published nutritional data you know.
2. For homemade/generic foods: Use USDA averages or standard recipe calculations.
3. When the user says "there is bacon in it" or similar, ADJUST the existing values by adding the extra ingredient's nutrition.
4. Always return realistic, accurate values - not guesses.
5. Return ONLY valid JSON, no markdown formatting or explanation text.

Example corrections:
- "there is bacon in it" → Add ~45 cal, 3g protein, 3g fat per slice of bacon
- "it's actually a Big Mac" → Use McDonald's Big Mac values (590 cal, 25g protein, 34g fat, 46g carbs)
- "this is from Starbucks" → Use Starbucks menu nutrition data`

    const userPrompt = `Current food analysis:
{
  "name": "${current.name}",
  "servingSize": "${current.servingSize || "1 serving"}",
  "calories": ${current.calories},
  "protein": ${current.protein},
  "carbs": ${current.carbs},
  "fat": ${current.fat},
  "fiber": ${current.fiber || 0},
  "sugar": ${current.sugar || 0}
}

User correction: "${correction}"

Apply the correction and return the updated nutrition data as JSON:
{"name":"<corrected name>","servingSize":"<size>","calories":<number>,"protein":<number>,"carbs":<number>,"fat":<number>,"fiber":<number>,"sugar":<number>,"confidence":"high","ingredients":[<list if known>]}`

    const response = await fetch("https://api.openai.com/v1/chat/completions", {
      method: "POST",
      headers: {
        Authorization: `Bearer ${openAIKey}`,
        "Content-Type": "application/json",
      },
      body: JSON.stringify({
        model: "gpt-4o",  // Using the full GPT-4o model for better accuracy
        messages: [
          { role: "system", content: systemPrompt },
          { role: "user", content: userPrompt }
        ],
        max_tokens: 400,
        temperature: 0.1,  // Low temperature for more consistent/accurate results
      }),
    })

    if (!response.ok) {
      const errorData = await response.json()
      console.error("OpenAI API error:", errorData)
      throw new Error(`OpenAI API error: ${response.status}`)
    }

    const data = await response.json()
    console.log("✅ GPT-4o response received")

    const content: string = data.choices[0].message.content

    // Extract JSON from response (handle potential markdown wrapping)
    let jsonString = content
    const jsonMatch = content.match(/\{[\s\S]*\}/)
    if (jsonMatch) {
      jsonString = jsonMatch[0]
    }
    jsonString = jsonString.replace(/```json\n?/g, "").replace(/```\n?/g, "").trim()

    let nutritionData
    try {
      nutritionData = JSON.parse(jsonString)
    } catch (parseError) {
      console.error("Failed to parse JSON:", jsonString)
      throw new Error("Failed to parse nutrition data from AI response")
    }

    // Validate required fields
    if (!nutritionData.name || typeof nutritionData.calories !== "number") {
      console.error("Invalid nutrition data:", nutritionData)
      throw new Error("AI returned incomplete nutrition data")
    }

    // Ensure all numeric fields are present and valid
    nutritionData.calories = Math.max(0, nutritionData.calories || 0)
    nutritionData.protein = Math.max(0, nutritionData.protein || 0)
    nutritionData.carbs = Math.max(0, nutritionData.carbs || 0)
    nutritionData.fat = Math.max(0, nutritionData.fat || 0)
    nutritionData.fiber = Math.max(0, nutritionData.fiber || 0)
    nutritionData.sugar = Math.max(0, nutritionData.sugar || 0)
    nutritionData.servingSize = nutritionData.servingSize || "1 serving"
    nutritionData.confidence = nutritionData.confidence || "high"
    nutritionData.ingredients = nutritionData.ingredients || []

    console.log(`📊 Correction complete: ${nutritionData.name} - ${nutritionData.calories} cal`)

    return new Response(JSON.stringify(nutritionData), {
      headers: { ...corsHeaders, "Content-Type": "application/json" },
      status: 200,
    })
  } catch (error) {
    const errorMessage = error instanceof Error ? error.message : String(error)
    console.error("❌ Error:", errorMessage)
    return new Response(
      JSON.stringify({ error: errorMessage }),
      { status: 400, headers: { ...corsHeaders, "Content-Type": "application/json" } },
    )
  }
})
