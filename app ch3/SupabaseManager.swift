//
//  SupabaseManager.swift
//  app ch3
//
//  Singleton per gestire il client Supabase
//

import Supabase
import Foundation

final class SupabaseManager {
    static let shared = SupabaseManager()
    let client: SupabaseClient

    private init() {
        let url = URL(string: "https://saexkuvejazyffwtpiih.supabase.co")!
        let key = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InNhZXhrdXZlamF6eWZmd3RwaWloIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NjQ2NTg2MTAsImV4cCI6MjA4MDIzNDYxMH0.DrVUnVN3Mg1F-wADgNlt0Kz3C7745W61Hbjq1Ll9GW4"

        client = SupabaseClient(
            supabaseURL: url,
            supabaseKey: key
        )
    }
}
