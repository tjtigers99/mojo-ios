import Foundation
import Supabase

// Configure the Supabase client used throughout the app.
// Replace the placeholder key with your project's anon key.
let supabase = SupabaseClient(
    supabaseURL: URL(string: "https://utlrtdwxjyjmlpzbyfgx.supabase.co")!,
    supabaseKey: "YOUR_SUPABASE_ANON_KEY"
)
