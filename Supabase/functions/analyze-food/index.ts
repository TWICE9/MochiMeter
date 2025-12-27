// Supabase Edge Function to analyze food images using OpenAI GPT-4o Mini
import { serve } from "https://deno.land/std@0.168.0/http/server.ts"
import { createClient } from "https://esm.sh/@supabase/supabase-js@2"

const openAIKey = Deno.env.get('OPENAI_API_KEY')

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
const RATE_LIMIT = 20 // requests per window (lower for image analysis)
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
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders })
  }

  try {
    // Verify user is authenticated
    const supabase = createClient(
      Deno.env.get('SUPABASE_URL') ?? '',
      Deno.env.get('SUPABASE_ANON_KEY') ?? '',
      {
        global: {
          headers: { Authorization: req.headers.get('Authorization')! }
        }
      }
    )

    const { data: { user }, error: userError } = await supabase.auth.getUser()
    if (userError || !user) {
      throw new Error('Unauthorized')
    }

    // Check rate limit
    if (!checkRateLimit(user.id)) {
      return new Response(
        JSON.stringify({ error: "Rate limit exceeded. Please try again later." }),
        { status: 429, headers: { ...corsHeaders, "Content-Type": "application/json" } }
      )
    }

    console.log("Food scan request received")

    // Get image from request
    const { imageBase64 } = await req.json()

    if (!imageBase64) {
      throw new Error('No image provided')
    }

    console.log('🤖 Calling OpenAI GPT-4o Mini...')

    // Call OpenAI GPT-4o Mini with Vision
    const response = await fetch('https://api.openai.com/v1/chat/completions', {
      method: 'POST',
      headers: {
        'Authorization': `Bearer ${openAIKey}`,
        'Content-Type': 'application/json',
      },
      body: JSON.stringify({
        model: 'gpt-4o-mini',
        messages: [
          {
            role: 'system',
            content: `You are a nutrition expert with comprehensive knowledge of restaurant menus, fast food nutritional data, and packaged food labels.

CRITICAL RULES:
1. If you recognize BRANDED packaging (McDonald's, Starbucks, etc.) or restaurant-style food: Use ACTUAL published nutritional data.
2. For home-cooked/generic foods: Use USDA database averages for the visible portions.
3. Be CONSERVATIVE - when uncertain, estimate on the LOWER end.
4. Carefully assess ACTUAL visible portion size - don't overestimate.

Return ONLY valid JSON, no markdown.`
          },
          {
            role: 'user',
            content: [
              {
                type: 'text',
                text: `Analyze this food image. Identify if it's branded/restaurant food (use actual nutrition data) or generic (estimate conservatively).

INSTRUCTIONS:
- Look for brand logos, packaging, or restaurant presentation
- Assess actual visible portion size carefully
- Use REAL nutritional data for known items
- Be conservative with estimates for unknown items

Return JSON:
{"name":"<specific name>","servingSize":"<portion>","calories":<num>,"protein":<g>,"carbs":<g>,"fat":<g>,"fiber":<g>,"sugar":<g>,"confidence":"high/medium/low","ingredients":["<i1>","<i2>"]}`
              },
              {
                type: 'image_url',
                image_url: {
                  url: `data:image/jpeg;base64,${imageBase64}`,
                  detail: 'low'
                }
              }
            ]
          }
        ],
        max_tokens: 300,
        temperature: 0.2
      })
    })

    if (!response.ok) {
      const errorData = await response.json()
      console.error('OpenAI API error:', errorData)
      throw new Error(`OpenAI API error: ${response.status}`)
    }

    const data = await response.json()
    console.log('✅ OpenAI response received')

    // Extract and parse the nutrition data
    const content = data.choices[0].message.content

    // Remove markdown code blocks if present
    const cleanContent = content
      .replace(/```json\n?/g, '')
      .replace(/```\n?/g, '')
      .trim()

    let nutritionData
    try {
      nutritionData = JSON.parse(cleanContent)
    } catch (parseError) {
      console.error("Failed to parse AI response as JSON")
      throw new Error("Failed to parse nutrition data from AI response")
    }

    console.log("Food analysis complete")

    return new Response(
      JSON.stringify(nutritionData),
      {
        headers: { ...corsHeaders, 'Content-Type': 'application/json' },
        status: 200
      }
    )

  } catch (error) {
    console.error('❌ Error:', error.message)
    return new Response(
      JSON.stringify({
        error: error.message,
        details: error.toString()
      }),
      {
        status: 400,
        headers: { ...corsHeaders, 'Content-Type': 'application/json' }
      }
    )
  }
})
