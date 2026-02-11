import 'package:supabase_flutter/supabase_flutter.dart';

class SupabaseService {
  static SupabaseClient? _client;

  static Future<void> init({
    required String url,
    required String anonKey,
  }) async {
    if (_client != null) return;
    await Supabase.initialize(url: url, anonKey: anonKey);
    _client = Supabase.instance.client;
  }

  static SupabaseClient get client => _client ?? Supabase.instance.client;

  // Auth helpers
  static Future<AuthResponse> signUp(String email, String password) async {
    return await client.auth.signUp(email: email, password: password);
  }

  static Future<AuthResponse> signIn(String email, String password) async {
    return await client.auth.signInWithPassword(
      email: email,
      password: password,
    );
  }

  static Session? currentSession() => client.auth.currentSession;

  static User? currentUser() => client.auth.currentUser;

  /// Waits briefly for Supabase to restore auth state on web.
  /// Returns true if a session or user is available within the timeout.
  static Future<bool> waitForInitialAuth({
    Duration timeout = const Duration(seconds: 2),
  }) async {
    final end = DateTime.now().add(timeout);
    while (DateTime.now().isBefore(end)) {
      try {
        if (currentSession() != null || currentUser() != null) return true;
      } catch (_) {}
      await Future.delayed(const Duration(milliseconds: 100));
    }
    return currentSession() != null || currentUser() != null;
  }

  static Future<void> signOut() async {
    await client.auth.signOut();
  }

  // Simple user table helpers (Postgres)
  static Future<List<Map<String, dynamic>>> fetchUsers() async {
    final resp = await client.from('users').select();
    return List<Map<String, dynamic>>.from(resp);
  }

  static Future<void> createUser(Map<String, dynamic> user) async {
    await client.from('users').insert(user).select().single();
  }
}
