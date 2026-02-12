import 'dart:convert';
import 'dart:io';

/// Creates a test user for messaging testing using Supabase REST API directly.
Future<void> main() async {
  const supabaseUrl = 'https://qfrwfsinwfnufnxtixsf.supabase.co';
  const anonKey =
      'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InFmcndmc2lud2ZudWZueHRpeHNmIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzAzOTUxNDUsImV4cCI6MjA4NTk3MTE0NX0.F2ZIBxO_x9CqXpcYHtAuMigicaeXk_DE5tMd7CgPmrs';

  const email = 'testuser@ichamba.com';
  const password = 'Test1234!';

  final httpClient = HttpClient();

  print('Registrando usuario de prueba: $email ...');

  try {
    // 1. Sign up via Supabase Auth REST API
    final signUpReq = await httpClient.postUrl(
      Uri.parse('$supabaseUrl/auth/v1/signup'),
    );
    signUpReq.headers.set('Content-Type', 'application/json');
    signUpReq.headers.set('apikey', anonKey);
    signUpReq.write(jsonEncode({'email': email, 'password': password}));
    final signUpResp = await signUpReq.close();
    final signUpBody = await signUpResp.transform(utf8.decoder).join();
    final signUpData = jsonDecode(signUpBody) as Map<String, dynamic>;

    if (signUpResp.statusCode >= 400) {
      print('Error en signup: ${signUpResp.statusCode}');
      print(signUpBody);
      return;
    }

    final userId = signUpData['user']?['id'] ?? signUpData['id'];
    final accessToken = signUpData['access_token'] ?? '';
    print('Auth user creado con ID: $userId');

    // 2. Insert into users table via REST API
    final token = accessToken.toString().isNotEmpty ? accessToken : anonKey;
    final insertReq = await httpClient.postUrl(
      Uri.parse('$supabaseUrl/rest/v1/users'),
    );
    insertReq.headers.set('Content-Type', 'application/json');
    insertReq.headers.set('apikey', anonKey);
    insertReq.headers.set('Authorization', 'Bearer $token');
    insertReq.headers.set('Prefer', 'return=minimal');
    insertReq.write(
      jsonEncode({
        'auth_id': userId,
        'email': email,
        'first_name': 'Usuario',
        'last_name': 'Prueba',
      }),
    );
    final insertResp = await insertReq.close();
    final insertBody = await insertResp.transform(utf8.decoder).join();

    if (insertResp.statusCode >= 400) {
      print('Error al insertar en users: ${insertResp.statusCode}');
      print(insertBody);
    } else {
      print('Usuario insertado en tabla users.');
    }

    print('');
    print('=== Usuario de prueba creado ===');
    print('Email: $email');
    print('Password: $password');
    print('Auth ID: $userId');
  } catch (e) {
    print('Error: $e');
  } finally {
    httpClient.close();
  }
}
