//
//  Secrets.swift
//  Yumo
//
//  Secure configuration reader for API keys.
//  Keys are stored in Secrets.xcconfig and loaded via Info.plist.
//

import Foundation

enum Secrets {

    // MARK: - Supabase

    static var supabaseURL: URL {
        guard let urlString = Bundle.main.infoDictionary?["SUPABASE_URL"] as? String,
              !urlString.isEmpty,
              urlString != "your-project-id" else {
            fatalError("SUPABASE_URL not configured. Please check Secrets.xcconfig and Info.plist.")
        }
        guard let url = URL(string: urlString) else {
            fatalError("SUPABASE_URL is not a valid URL: \(urlString)")
        }
        return url
    }

    static var supabaseAnonKey: String {
        guard let key = Bundle.main.infoDictionary?["SUPABASE_ANON_KEY"] as? String,
              !key.isEmpty,
              key != "your-supabase-anon-key-here" else {
            fatalError("SUPABASE_ANON_KEY not configured. Please check Secrets.xcconfig and Info.plist.")
        }
        return key
    }

    // MARK: - Superwall

    static var superwallAPIKey: String {
        guard let key = Bundle.main.infoDictionary?["SUPERWALL_API_KEY"] as? String,
              !key.isEmpty,
              key != "your-superwall-api-key-here" else {
            fatalError("SUPERWALL_API_KEY not configured. Please check Secrets.xcconfig and Info.plist.")
        }
        return key
    }
}
