// Supabase Edge Function to correct an AI food analysis using Perplexity API (web search)
import { serve } from "https://deno.land/std@0.168.0/http/server.ts"
import { createClient } from "https://esm.sh/@supabase/supabase-js@2"

const perplexityKey = Deno.env.get("PERPLEXITY_API_KEY")
const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
}

serve(async (req) => {
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

    console.log(`🔧 Food correction request from user: ${user.id}`)

    const { current, correction } = await req.json()
    if (!current || !correction) {
      throw new Error("Missing current analysis or correction text")
    }

    console.log("🌐 Calling Perplexity API to search for accurate nutrition data...")

    const systemPrompt = `You are a nutrition expert with real-time web search capabilities. Your task is to find ACTUAL, VERIFIED nutritional information from official sources.

CRITICAL INSTRUCTIONS:
1. Search the web for the EXACT nutritional data from official restaurant websites, nutrition databases, or food manufacturer sites.
2. For restaurant items (McDonald's, Burger King, Starbucks, etc.): Find their official published nutrition facts.
3. For packaged foods: Search for the actual nutrition label data.
4. For generic foods: Use USDA FoodData Central values.
5. ALWAYS cite the source in your response.
6. Return ONLY valid JSON, no markdown or explanation.`

    const userPrompt = `I need accurate nutritional information for this food item.

Current (possibly incorrect) values:
- Name: ${current.name}
- Serving Size: ${current.servingSize}
- Calories: ${current.calories}
- Protein: ${current.protein}g, Carbs: ${current.carbs}g, Fat: ${current.fat}g
- Fiber: ${current.fiber}g, Sugar: ${current.sugar}g

User says this is wrong: "${correction}"

Please search online for the REAL nutritional values for "${correction}" or "${current.name}". Look at official restaurant nutrition pages, USDA database, or food manufacturer websites.

Return JSON format:
{"name":"<accurate name>","servingSize":"<actual serving>","calories":<verified_num>,"protein":<g>,"carbs":<g>,"fat":<g>,"fiber":<g>,"sugar":<g>,"confidence":"high","ingredients":["<i1>","<i2>"],"source":"<where you found this data>"}`

    const response = await fetch("https://api.perplexity.ai/chat/completions", {
      method: "POST",
      headers: {
        Authorization: `Bearer ${perplexityKey}`,
        "Content-Type": "application/json",
      },
      body: JSON.stringify({
        model: "sonar",
        messages: [
          { role: "system", content: systemPrompt },
          { role: "user", content: userPrompt }
        ],
        max_tokens: 500,
        temperature: 0.1,
      }),
    })

    if (!response.ok) {
      const errorData = await response.json()
      console.error("Perplexity API error:", errorData)
      throw new Error(`Perplexity API error: ${response.status}`)
    }

    const data = await response.json()
    console.log("✅ Perplexity response received")

    const content: string = data.choices[0].message.content

    // Extract JSON from the response (Perplexity may include explanation text)
    const jsonMatch = content.match(/\{[\s\S]*\}/)
    if (!jsonMatch) {
      throw new Error("Could not parse nutrition data from response")
    }

    const clean = jsonMatch[0].replace(/```json\n?/g, "").replace(/```\n?/g, "").trim()
    const nutritionData = JSON.parse(clean)

    // Remove source field before returning (internal use only)
    const { source, ...responseData } = nutritionData
    console.log(`📊 Correction complete: ${nutritionData.name} - ${nutritionData.calories} cal (source: ${source || 'web search'})`)

    return new Response(JSON.stringify(responseData), {
      headers: { ...corsHeaders, "Content-Type": "application/json" },
      status: 200,
    })
  } catch (error) {
    console.error("❌ Error:", error.message)
    return new Response(
      JSON.stringify({ error: error.message, details: error.toString() }),
      { status: 400, headers: { ...corsHeaders, "Content-Type": "application/json" } },
    )
  }
})
