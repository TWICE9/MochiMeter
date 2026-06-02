// Supabase Edge Function to analyze food images using OpenAI GPT-5 Mini
// Supports both immediate mode (returns result) and background mode (returns immediately, processes async)
import { serve } from "https://deno.land/std@0.168.0/http/server.ts"
import { createClient } from "https://esm.sh/@supabase/supabase-js@2"

const openAIKey = Deno.env.get('OPENAI_API_KEY')

// APNs configuration for push notifications
const APNS_KEY_ID = Deno.env.get('APNS_KEY_ID') ?? ''
const APNS_TEAM_ID = Deno.env.get('APNS_TEAM_ID') ?? ''
const APNS_BUNDLE_ID = Deno.env.get('APNS_BUNDLE_ID') ?? 'com.jesseta.yumo'
const APNS_PRIVATE_KEY = Deno.env.get('APNS_PRIVATE_KEY') ?? ''
// Use production APNs by default; set to 'development' for sandbox
const APNS_ENVIRONMENT = Deno.env.get('APNS_ENVIRONMENT') ?? 'production'

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
const RATE_LIMIT = 20
const RATE_WINDOW_MS = 60 * 1000

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

// =========================================
// APNs Push Notification Helper
// =========================================

// Base64url encode
function base64url(data: Uint8Array): string {
  let binary = ''
  for (const byte of data) binary += String.fromCharCode(byte)
  return btoa(binary).replace(/\+/g, '-').replace(/\//g, '_').replace(/=+$/, '')
}

// Cache the APNs JWT token (valid for up to 1 hour)
let cachedApnsToken: { token: string; expiresAt: number } | null = null

async function getApnsJwt(): Promise<string> {
  const now = Math.floor(Date.now() / 1000)

  // Reuse cached token if still valid (refresh 5 min before expiry)
  if (cachedApnsToken && cachedApnsToken.expiresAt > now + 300) {
    return cachedApnsToken.token
  }

  // Build JWT header + claims
  const header = base64url(new TextEncoder().encode(JSON.stringify({
    alg: 'ES256',
    kid: APNS_KEY_ID
  })))

  const claims = base64url(new TextEncoder().encode(JSON.stringify({
    iss: APNS_TEAM_ID,
    iat: now
  })))

  const signingInput = `${header}.${claims}`

  // Import the P8 private key (PEM-encoded ES256)
  const pemBody = APNS_PRIVATE_KEY
    .replace(/-----BEGIN PRIVATE KEY-----/, '')
    .replace(/-----END PRIVATE KEY-----/, '')
    .replace(/\s/g, '')
  const keyData = Uint8Array.from(atob(pemBody), c => c.charCodeAt(0))

  const key = await crypto.subtle.importKey(
    'pkcs8',
    keyData,
    { name: 'ECDSA', namedCurve: 'P-256' },
    false,
    ['sign']
  )

  // Sign
  const signature = new Uint8Array(await crypto.subtle.sign(
    { name: 'ECDSA', hash: 'SHA-256' },
    key,
    new TextEncoder().encode(signingInput)
  ))

  const token = `${signingInput}.${base64url(signature)}`

  cachedApnsToken = { token, expiresAt: now + 3600 }
  return token
}

async function sendPushNotification(
  supabaseAdmin: ReturnType<typeof createClient>,
  userId: string,
  title: string,
  body: string
): Promise<string> {
  if (!APNS_KEY_ID || !APNS_TEAM_ID || !APNS_PRIVATE_KEY) {
    console.log('⚠️ APNs not configured, skipping push notification')
    return 'APNs secrets missing'
  }

  try {
    // Fetch user's device tokens
    const { data: tokens, error } = await supabaseAdmin
      .from('device_tokens')
      .select('token')
      .eq('user_id', userId)
      .eq('platform', 'ios')

    if (error) return `DB error: ${error.message}`
    if (!tokens || tokens.length === 0) {
      console.log('📲 No device tokens found for user, skipping push')
      return 'No device tokens found in DB'
    }

    const jwt = await getApnsJwt()
    const primaryHost = APNS_ENVIRONMENT === 'development'
      ? 'api.sandbox.push.apple.com'
      : 'api.push.apple.com'
    const fallbackHost = primaryHost === 'api.sandbox.push.apple.com' 
      ? 'api.push.apple.com' 
      : 'api.sandbox.push.apple.com'

    let results = []
    // Send to all registered devices
    for (const { token } of tokens) {
      try {
        let response = await fetch(
          `https://${primaryHost}/3/device/${token}`,
          {
            method: 'POST',
            headers: {
              'authorization': `bearer ${jwt}`,
              'apns-topic': APNS_BUNDLE_ID,
              'apns-push-type': 'alert',
              'apns-priority': '10',
              'content-type': 'application/json',
            },
            body: JSON.stringify({
              aps: { alert: { title, body }, sound: 'default' }
            })
          }
        )

        let isFallback = false
        if (!response.ok) {
          const errorBody = await response.text()
          // If we used the wrong environment, try the other one automatically!
          if (response.status === 400 || response.status === 403) {
            if (errorBody.includes('BadEnvironmentKeyInToken') || errorBody.includes('BadDeviceToken') || errorBody.includes('Unregistered')) {
              response = await fetch(
                `https://${fallbackHost}/3/device/${token}`,
                {
                  method: 'POST',
                  headers: {
                    'authorization': `bearer ${jwt}`,
                    'apns-topic': APNS_BUNDLE_ID,
                    'apns-push-type': 'alert',
                    'apns-priority': '10',
                    'content-type': 'application/json',
                  },
                  body: JSON.stringify({
                    aps: { alert: { title, body }, sound: 'default' }
                  })
                }
              )
              isFallback = true
            }
          } else {
             // Let it process as normal error
             results.push(`Error ${response.status}: ${errorBody}`)
             continue
          }
        }

        if (response.ok) {
          results.push(`Success for token ${token.substring(0, 8)}${isFallback ? ' (using fallback host)' : ''}`)
        } else {
          const errorBody = await response.text() // read error from fallback (or original if not retried)
          results.push(`Error ${response.status}: ${errorBody}`)

          // Remove invalid tokens (410 Gone = token expired/invalid)
          if (response.status === 410 || errorBody.includes('Unregistered')) {
            await supabaseAdmin
              .from('device_tokens')
              .delete()
              .eq('token', token)
          }
        }
      } catch (pushError) {
        results.push(`Exception: ${pushError}`)
      }
    }
    return results.join(' | ')
  } catch (error) {
    return `Fatal error: ${error}`
  }
}

// Background processing function - runs after response is sent
async function processBackgroundAnalysis(
  supabaseAdmin: ReturnType<typeof createClient>,
  analysisId: string,
  imagePath: string
) {
  console.log(`🔄 Starting background processing for analysis: ${analysisId}`)

  try {
    // Update status to processing
    await supabaseAdmin
      .from('pending_analyses')
      .update({ status: 'processing', started_at: new Date().toISOString() })
      .eq('id', analysisId)

    // Download image from storage
    console.log(`📥 Fetching image from storage: ${imagePath}`)
    const { data: imageData, error: downloadError } = await supabaseAdmin
      .storage
      .from('food-images')
      .download(imagePath)

    if (downloadError || !imageData) {
      throw new Error(`Failed to download image: ${downloadError?.message}`)
    }

    // Convert to base64
    const arrayBuffer = await imageData.arrayBuffer()
    const bytes = new Uint8Array(arrayBuffer)
    let binary = ''
    for (let i = 0; i < bytes.length; i++) {
      binary += String.fromCharCode(bytes[i])
    }
    const base64Image = btoa(binary)

    console.log(`✅ Image downloaded and converted (${bytes.length} bytes)`)
    console.log('🤖 Calling OpenAI GPT-5 Mini (Low Latency)...')

    // Call OpenAI GPT-5 Mini with Vision
    const response = await fetch('https://api.openai.com/v1/chat/completions', {
      method: 'POST',
      headers: {
        'Authorization': `Bearer ${openAIKey}`,
        'Content-Type': 'application/json',
      },
      body: JSON.stringify({
        model: 'gpt-5-mini',
        response_format: { type: "json_object" },
        reasoning_effort: "minimal",
        messages: [
          {
            role: 'system',
            content: `You are a nutrition expert. If you recognize BRANDED packaging (McDonald's, Starbucks, etc.) or restaurant-style food, use ACTUAL published nutritional data. For home-cooked/generic foods, use USDA averages. Be CONSERVATIVE. Include ingredientBreakdown listing each visible main component with its estimated calorie contribution. Return ONLY valid JSON, no markdown.`
          },
          {
            role: 'user',
            content: [
              {
                type: 'text',
                text: `Analyze this food image and return a JSON object with this structure:
                {"name":"string","servingSize":"string","calories":number,"protein":number,"carbs":number,"fat":number,"fiber":number,"sugar":number,"salt":number,"potassium":number,"confidence":"high|medium|low","ingredientBreakdown":[{"name":"component","calories":number}]}`
              },
              {
                type: 'image_url',
                image_url: {
                  url: `data:image/jpeg;base64,${base64Image}`,
                  detail: 'auto'
                }
              }
            ]
          }
        ],
        max_completion_tokens: 800
      })
    })

    if (!response.ok) {
      const errorData = await response.json()
      console.error('OpenAI API error:', errorData)
      throw new Error(`OpenAI API error: ${errorData.error?.message || response.status}`)
    }

    const data = await response.json()
    console.log('✅ OpenAI response received')

    // Extract and parse the content
    const content = data.choices[0].message.content
    const jsonMatch = content.match(/\{[\s\S]*\}/)
    if (!jsonMatch) {
      throw new Error("No valid JSON found in AI response")
    }

    const nutritionData = JSON.parse(jsonMatch[0])
    console.log("Food analysis complete for:", nutritionData.name)

    let pushResult = 'skipped'
    // Send push notification to user
    const { data: analysisRow } = await supabaseAdmin
      .from('pending_analyses')
      .select('user_id')
      .eq('id', analysisId)
      .single()

    if (analysisRow?.user_id) {
      const cal = Math.round(nutritionData.calories ?? 0)
      const p = Math.round(nutritionData.protein ?? 0)
      const c = Math.round(nutritionData.carbs ?? 0)
      const f = Math.round(nutritionData.fat ?? 0)
      pushResult = await sendPushNotification(
        supabaseAdmin,
        analysisRow.user_id,
        'Meal Logged',
        `${nutritionData.name} — ${cal} kcal · P ${p}g · C ${c}g · F ${f}g`
      )
    }

    // Write result to database
    console.log(`📝 Writing result to database for analysis: ${analysisId}`)
    await supabaseAdmin
      .from('pending_analyses')
      .update({
        status: 'completed',
        result: nutritionData,
        error_message: `Push result: ${pushResult}`, // Inject push result for debugging
        completed_at: new Date().toISOString()
      })
      .eq('id', analysisId)

    console.log(`✅ Analysis ${analysisId} completed and saved to database`)

  } catch (error: unknown) {
    const errorMessage = error instanceof Error ? error.message : String(error)
    console.error(`❌ Background processing failed: ${errorMessage}`)

    // Update status to failed
    await supabaseAdmin
      .from('pending_analyses')
      .update({
        status: 'failed',
        error_message: errorMessage,
        completed_at: new Date().toISOString()
      })
      .eq('id', analysisId)
  }
}

serve(async (req) => {
  const corsHeaders = getCorsHeaders(req)

  // Handle CORS preflight
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders })
  }

  // Create service role client for background mode (writes to DB)
  const supabaseAdmin = createClient(
    Deno.env.get('SUPABASE_URL') ?? '',
    Deno.env.get('SUPABASE_SERVICE_ROLE_KEY') ?? ''
  )

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

    // Parse request body
    const body = await req.json()
    const { imageBase64, imagePath, analysisId, mode } = body
    const isBackgroundMode = mode === "background" && analysisId && imagePath

    console.log(`Food scan request received (mode: ${isBackgroundMode ? 'background' : 'immediate'})`)

    // BACKGROUND MODE: Return immediately, process asynchronously
    if (isBackgroundMode) {
      console.log(`🚀 Background mode: Returning immediately, processing async for ${analysisId}`)

      // deno-lint-ignore no-explicit-any
      const edgeRuntime = (globalThis as any).EdgeRuntime
      if (edgeRuntime?.waitUntil) {
        edgeRuntime.waitUntil(processBackgroundAnalysis(supabaseAdmin, analysisId, imagePath))
      } else {
        processBackgroundAnalysis(supabaseAdmin, analysisId, imagePath).catch(console.error)
      }

      // Return immediately with acknowledgment
      return new Response(
        JSON.stringify({
          status: "accepted",
          analysisId: analysisId,
          message: "Analysis started in background"
        }),
        {
          headers: { ...corsHeaders, 'Content-Type': 'application/json' },
          status: 202 // 202 Accepted
        }
      )
    }

    // IMMEDIATE MODE: Process and return result (existing behavior)
    if (!imageBase64) throw new Error('No image provided')

    console.log('🤖 Calling OpenAI GPT-5 Mini (Low Latency)...')
    const response = await fetch('https://api.openai.com/v1/chat/completions', {
      method: 'POST',
      headers: {
        'Authorization': `Bearer ${openAIKey}`,
        'Content-Type': 'application/json',
      },
      body: JSON.stringify({
        model: 'gpt-5-mini',
        response_format: { type: "json_object" },
        reasoning_effort: "minimal",
        messages: [
          { role: 'system', content: `You are a nutrition expert. If you recognize BRANDED packaging (McDonald's, Starbucks, etc.) or restaurant-style food, use ACTUAL published nutritional data. For home-cooked/generic foods, use USDA averages. Be CONSERVATIVE. Include ingredientBreakdown listing each visible main component with its estimated calorie contribution. Return ONLY valid JSON, no markdown.` },
          { role: 'user', content: [ { type: 'text', text: `Analyze this food image and return a JSON object with this structure: {"name":"string","servingSize":"string","calories":number,"protein":number,"carbs":number,"fat":number,"fiber":number,"sugar":number,"salt":number,"potassium":number,"confidence":"high|medium|low","ingredientBreakdown":[{"name":"component","calories":number}]}` }, { type: 'image_url', image_url: { url: `data:image/jpeg;base64,${imageBase64}`, detail: 'auto' } } ] }
        ],
        max_completion_tokens: 800
      })
    })

    if (!response.ok) {
      const errorData = await response.json()
      throw new Error(`OpenAI API error: ${errorData.error?.message || response.status}`)
    }

    const data = await response.json()
    const content = data.choices[0].message.content
    const jsonMatch = content.match(/\{[\s\S]*\}/)
    if (!jsonMatch) throw new Error("No valid JSON found in AI response")

    let nutritionData
    try {
      nutritionData = JSON.parse(jsonMatch[0])
    } catch (parseError) {
      throw new Error("Failed to parse nutrition data from AI response")
    }

    return new Response(JSON.stringify(nutritionData), { headers: { ...corsHeaders, 'Content-Type': 'application/json' }, status: 200 })

  } catch (error: unknown) {
    const errorMessage = error instanceof Error ? error.message : String(error)
    return new Response(JSON.stringify({ error: errorMessage, details: String(error) }), { status: 400, headers: { ...corsHeaders, 'Content-Type': 'application/json' } })
  }
})
