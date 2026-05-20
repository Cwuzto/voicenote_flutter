class AppEnv {
  AppEnv._();

  // Paste your local dev values here (do not commit real secrets to public repos).
  static const String _localSupabaseUrl = 'https://cyfdjpqbsuslifvczhaz.supabase.co';
  static const String _localSupabaseAnonKey = 'sb_publishable_4DmPcmv61gl0kfEalrxgLA_4wcQ6yIv';

  // Priority: --dart-define value > local fallback above.
  static const String supabaseUrl = String.fromEnvironment(
    'SUPABASE_URL',
    defaultValue: _localSupabaseUrl,
  );
  static const String supabaseAnonKey = String.fromEnvironment(
    'SUPABASE_ANON_KEY',
    defaultValue: _localSupabaseAnonKey,
  );

  static bool get hasSupabaseConfig =>
      supabaseUrl.isNotEmpty && supabaseAnonKey.isNotEmpty;
}
