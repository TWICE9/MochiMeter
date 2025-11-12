//
//  SupabaseClient.swift
//  Yumo
//

import Foundation
import Supabase

// FIX: Define the global client as nonisolated without the '(unsafe)' modifier.
// This correctly establishes a thread-safe global context for the client.
nonisolated let supabase: SupabaseClient = {
    SupabaseClient(
        supabaseURL: URL(string: "https://pjlvduapimjeaczfplrr.supabase.co")!,
        supabaseKey: "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InBqbHZkdWFwaW1qZWFjemZwbHJyIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NjMyNjc3ODMsImV4cCI6MjA3ODg0Mzc4M30.Pfoasy6Afe9sEf8AtaSwArgCIqPfFyWs975tRe0Qj4E"
    )
}()
