import 'package:supabase_flutter/supabase_flutter.dart';

import '../config/app_env.dart';

class SupabaseBootstrap {
  SupabaseBootstrap._();

  static bool _initialized = false;

  static bool get isConfigured => AppEnv.hasSupabaseConfig;
  static bool get isInitialized => _initialized;

  static SupabaseClient get client {
    if (!_initialized) {
      throw StateError('Supabase is not initialized.');
    }
    return Supabase.instance.client;
  }

  static Future<void> initialize() async {
    if (_initialized || !isConfigured) {
      return;
    }

    await Supabase.initialize(
      url: AppEnv.supabaseUrl,
      anonKey: AppEnv.supabaseAnonKey,
    );
    _initialized = true;
  }
}
