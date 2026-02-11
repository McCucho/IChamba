import 'dart:convert';
import 'dart:io';

Future<void> main(List<String> args) async {
  final url = Platform.environment['SUPABASE_URL'];
  final serviceKey = Platform.environment['SUPABASE_SERVICE_ROLE_KEY'];

  if (url == null || url.isEmpty || serviceKey == null || serviceKey.isEmpty) {
    print(
      'ERROR: Environment variables SUPABASE_URL and SUPABASE_SERVICE_ROLE_KEY must be set.',
    );
    print('Example (PowerShell):');
    print(r'  $env:SUPABASE_URL = "https://your-project.supabase.co"');
    print(r'  $env:SUPABASE_SERVICE_ROLE_KEY = "your-service-role-key"');
    print('Then run: dart run tools/create_bucket.dart');
    exit(1);
  }

  final bucketName = 'publicaciones';
  final endpoint = Uri.parse('$url/storage/v1/buckets');

  final body = jsonEncode({'name': bucketName, 'public': true});

  final httpClient = HttpClient();
  try {
    final req = await httpClient.openUrl('POST', endpoint);
    req.headers.set(HttpHeaders.contentTypeHeader, 'application/json');
    req.headers.set(HttpHeaders.authorizationHeader, 'Bearer $serviceKey');
    req.add(utf8.encode(body));

    final resp = await req.close();
    final respBody = await resp.transform(utf8.decoder).join();

    if (resp.statusCode == 200 || resp.statusCode == 201) {
      print('Bucket "$bucketName" created successfully.');
      print(respBody);
      exit(0);
    } else if (resp.statusCode == 409) {
      print('Bucket "$bucketName" already exists.');
      print(respBody);
      exit(0);
    } else {
      print('Failed to create bucket. HTTP ${resp.statusCode}');
      print(respBody);
      exit(2);
    }
  } catch (e) {
    print('Network or other error: $e');
    exit(3);
  } finally {
    httpClient.close(force: true);
  }
}
