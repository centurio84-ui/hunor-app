class AppConfig {
  static const String version = '1.0.11';
  static const String buildNumber = '10013';
  static const String displayVersion = 'v$version ($buildNumber)';
}

class SupabaseConfig {
  static const url = String.fromEnvironment(
    'SUPABASE_URL',
    defaultValue: 'https://embicteneumubwlqqfik.supabase.co',
  );

  static const publishableKey = String.fromEnvironment(
    'SUPABASE_PUBLISHABLE_KEY',
    defaultValue: 'sb_publishable_Vt7KtNGznwvPrDRr5VEn0Q_r-Z6sas1',
  );
}
