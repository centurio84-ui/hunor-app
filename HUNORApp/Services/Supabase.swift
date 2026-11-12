import Foundation
import Supabase

enum SupabaseConfig {
    static let url = URL(string: "https://embicteneumubwlqqfik.supabase.co")!
    static let publishableKey = "sb_publishable_Vt7KtNGznwvPrDRr5VEn0Q_r-Z6sas1"
}

let supabase = SupabaseClient(
    supabaseURL: SupabaseConfig.url,
    supabaseKey: SupabaseConfig.publishableKey
)
