// Supabase Edge Function to analyze a typed meal description using OpenAI GPT-4o Mini
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

    const {
      data: { user },
      error: userError,
    } = await supabase.auth.getUser()
    if (userError || !user) {
      throw new Error("Unauthorized")
    }

    console.log(`📝 Meal text analysis request from user: ${user.id}`)

    const { description } = await req.json()
    const trimmedDescription = (description ?? "").trim()
    if (!trimmedDescription) {
      throw new Error("No description provided")
    }

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

    const cleanContent = content
      .replace(/```json\n?/g, "")
      .replace(/```\n?/g, "")
      .trim()

    const nutritionData = JSON.parse(cleanContent)

    console.log(`📊 Meal analysis complete: ${nutritionData.name} - ${nutritionData.calories} cal`)

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
