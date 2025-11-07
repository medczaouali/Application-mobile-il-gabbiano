class SupabaseConfig {
  // URL publique de votre projet Supabase (peut être commitée)
  static const String url = 'https://jtjsephljxfpyjkhaqzf.supabase.co';

  // Clé anonyme (publique) injectée via --dart-define pour éviter de la commiter.
  // Définissez SUPABASE_KEY depuis VS Code (launch.json) ou la ligne de commande.
  static const String anonKey = String.fromEnvironment(
    'SUPABASE_KEY',
    defaultValue:
        'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Imp0anNlcGhsanhmcHlqa2hhcXpmIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NjIyODYyNjcsImV4cCI6MjA3Nzg2MjI2N30.sadpQGB1LpRSmZhi2uHrekA-D3qCs8ekj8oBmTK08OM',
  );

  // Schéma d'URL pour le deep link du reset (à configurer côté Android/iOS)
  // Exemple: ilgabbiano://reset
  static const String resetScheme = 'ilgabbiano';
  static const String resetHost = 'reset';
  static String get resetRedirectUri => '$resetScheme://$resetHost';
}
