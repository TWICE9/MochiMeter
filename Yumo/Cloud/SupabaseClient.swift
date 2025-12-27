//
//  SupabaseClient.swift
//  Yumo
//

import Foundation
import Supabase

// Global Supabase client instance configured with keys from Secrets.xcconfig
nonisolated let supabase: SupabaseClient = {
    SupabaseClient(
        supabaseURL: Secrets.supabaseURL,
        supabaseKey: Secrets.supabaseAnonKey
    )
}()
