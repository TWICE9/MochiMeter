import { serve } from "https://deno.land/std@0.168.0/http/server.ts"
import { createClient } from "https://esm.sh/@supabase/supabase-js@2"

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

serve(async (req) => {
    const corsHeaders = getCorsHeaders(req)

    if (req.method === 'OPTIONS') {
        return new Response('ok', { headers: corsHeaders })
    }

    try {
        // 1. Create client with user's token to verify identity
        const supabaseClient = createClient(
            Deno.env.get('SUPABASE_URL') ?? '',
            Deno.env.get('SUPABASE_ANON_KEY') ?? '',
            { global: { headers: { Authorization: req.headers.get('Authorization')! } } }
        )

        // 2. Get User from token
        const { data: { user }, error: userError } = await supabaseClient.auth.getUser()
        if (userError || !user) throw new Error('Unauthorized')

        console.log(`Request to delete account for user: ${user.id}`)

        // 3. Create Admin Client to perform deletion
        const supabaseAdmin = createClient(
            Deno.env.get('SUPABASE_URL') ?? '',
            Deno.env.get('SUPABASE_SERVICE_ROLE_KEY') ?? ''
        )

        // 4. Delete the user
        // This will remove the user from auth.users. 
        // Postgres ON DELETE CASCADE will handle removing their data from other tables (profiles, logs, etc.)
        // Master Foods will be SAFE because they have no user_id foreign key.
        const { error: deleteError } = await supabaseAdmin.auth.admin.deleteUser(user.id)

        if (deleteError) {
            console.error("Supabase Admin Delete Error:", deleteError)
            throw new Error(`Failed to delete user: ${deleteError.message}`)
        }

        console.log(`✅ Successfully deleted user: ${user.id}`)

        return new Response(
            JSON.stringify({ message: "Account deleted successfully" }),
            { headers: { ...corsHeaders, 'Content-Type': 'application/json' }, status: 200 }
        )

    } catch (error) {
        console.error('Delete User Error:', error)
        return new Response(
            JSON.stringify({ error: error.message }),
            { headers: { ...corsHeaders, 'Content-Type': 'application/json' }, status: 400 }
        )
    }
})
