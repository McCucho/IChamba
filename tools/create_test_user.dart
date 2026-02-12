import 'package:supabase_flutter/supabase_flutter.dart';

/// Creates a test user for messaging testing.
Future<void> main() async {
  await Supabase.initialize(
    url: 'https://qfrwfsinwfnufnxtixsf.supabase.co',
    anonKey:
        'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InFmcndmc2lud2ZudWZueHRpeHNmIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzAzOTUxNDUsImV4cCI6MjA4NTk3MTE0NX0.F2ZIBxO_x9CqXpcYHtAuMigicaeXk_DE5tMd7CgPmrs',
  );

  final client = Supabase.instance.client;

  const email = 'testuser@ichamba.com';
  const password = 'Test1234!';

  print('Registrando usuario de prueba: $email ...');

  try {
    // 1. Register in Supabase Auth
    final authResp = await client.auth.signUp(email: email, password: password);

    final userId = authResp.user?.id;
    if (userId == null) {
      print('Error: no se pudo obtener el ID del usuario registrado.');
      return;
    }
    print('Auth user creado con ID: $userId');

    // 2. Insert into users table
    await client.from('users').insert({
      'auth_id': userId,
      'email': email,
      'first_name': 'Usuario',
      'last_name': 'Prueba',
    });

    print('Usuario insertado en tabla users.');
    print('');
    print('=== Usuario de prueba creado ===');
    print('Email: $email');
    print('Password: $password');
    print('Auth ID: $userId');
  } catch (e) {
    print('Error: $e');
  }
}
