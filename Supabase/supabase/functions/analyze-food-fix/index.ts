// Supabase Edge Function to correct an AI food analysis using OpenAI GPT-4o Mini
import { serve } from "https://deno.land/std@0.168.0/http/server.ts"
import { createClient } from "https://esm.sh/@supabase/supabase-js@2"

const openAIKey = Deno.env.get("OPENAI_API_KEY")
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

    console.log("🤖 Calling OpenAI GPT-4o Mini to correct analysis...")

    const systemPrompt = `You are a nutrition expert correcting food estimates. You have comprehensive knowledge of restaurant menus, fast food nutritional data, and USDA databases.

CRITICAL RULES:
1. For BRANDED/RESTAURANT items: Use ACTUAL published nutritional data (e.g., McDonald's Big Mac = 590 cal).
2. For generic foods: Use USDA database averages.
3. Trust the user's correction - they likely looked up the actual values.
4. Return ONLY valid JSON, no markdown.`

    const userPrompt = `Current values:
- name: ${current.name}
- servingSize: ${current.servingSize}
- calories: ${current.calories}
- protein: ${current.protein}g, carbs: ${current.carbs}g, fat: ${current.fat}g
- fiber: ${current.fiber}g, sugar: ${current.sugar}g
- ingredients: ${Array.isArray(current.ingredients) ? current.ingredients.join(", ") : ""}

User correction: "${correction}"

Apply the correction using real nutritional data if this is a branded item. Return JSON:
{"name":"<name>","servingSize":"<size>","calories":<num>,"protein":<g>,"carbs":<g>,"fat":<g>,"fiber":<g>,"sugar":<g>,"confidence":"high/medium/low","ingredients":["<i1>","<i2>"]}`

    const response = await fetch("https://api.openai.com/v1/chat/completions", {
      method: "POST",
      headers: {
        Authorization: `Bearer ${openAIKey}`,
        "Content-Type": "application/json",
      },
      body: JSON.stringify({
        model: "gpt-4o-mini",
        messages: [
          { role: "system", content: systemPrompt },
          { role: "user", content: userPrompt }
        ],
        max_tokens: 320,
        temperature: 0.2,
      }),
    })

    if (!response.ok) {
      const errorData = await response.json()
      console.error("OpenAI API error:", errorData)
      throw new Error(`OpenAI API error: ${response.status}`)
    }

    const data = await response.json()
    console.log("✅ OpenAI response received")

    const content: string = data.choices[0].message.content
    const clean = content.replace(/```json\n?/g, "").replace(/```\n?/g, "").trim()
    const nutritionData = JSON.parse(clean)

    console.log(`📊 Correction complete: ${nutritionData.name} - ${nutritionData.calories} cal`)

    return new Response(JSON.stringify(nutritionData), {
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
