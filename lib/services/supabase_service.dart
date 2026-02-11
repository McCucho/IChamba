import 'package:supabase_flutter/supabase_flutter.dart';
import 'dart:typed_data';

class SupabaseService {
  static SupabaseClient? _client;
  // Use the 'publicaciones' bucket created in Supabase Storage.
  // Change this value if you prefer a different bucket name.
  static const String _postsBucket = 'publicaciones';

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
  static Future<AuthResponse> signUp({
    required String email,
    required String password,
    Map<String, dynamic>? userMetadata,
  }) async {
    return await client.auth.signUp(
      email: email,
      password: password,
      data: userMetadata,
    );
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

  /// Insert or update a user row using upsert. Expects a map with identifying
  /// fields (e.g. 'id' or unique constraint) to perform update when present.
  static Future<void> upsertUser(Map<String, dynamic> user) async {
    final current = client.auth.currentUser;
    final payload = Map<String, dynamic>.from(user);
    // If caller didn't provide an id, set it to the authenticated user's id
    if ((payload['auth_id'] == null || payload['auth_id'].toString().isEmpty) &&
        current != null) {
      payload['auth_id'] = current.id;
    }

    try {
      await client.from('users').upsert(payload, onConflict: 'auth_id');
    } catch (e) {
      print('❌ Error en upsertUser: $e');
      print('Payload: $payload');
      rethrow;
    }
  }

  /// Fetch the current user's row from `users` table (by auth id).
  static Future<Map<String, dynamic>?> fetchUserProfile() async {
    final userId = client.auth.currentUser?.id;
    if (userId == null) return null;

    try {
      final response = await client
          .from('users')
          .select()
          .eq('auth_id', userId)
          .maybeSingle();

      return response;
    } catch (e) {
      print('Error fetching user profile: $e');
      rethrow;
    }
  }

  // Posts helpers
  static Future<void> uploadPostImageAndCreate({
    required Uint8List bytes,
    required String filename,
    required String description,
  }) async {
    final user = client.auth.currentUser;
    if (user == null) {
      throw Exception(
        'Usuario no autenticado. Inicia sesión antes de publicar.',
      );
    }
    final path = 'posts/${DateTime.now().millisecondsSinceEpoch}_$filename';
    // Upload binary to bucket (ensure bucket exists). Provide clearer error
    try {
      print("LLEGAUBLICAr");
      await client.storage.from(_postsBucket).uploadBinary(path, bytes);
    } catch (e) {
      final msg = e.toString();
      print("LLEGAUBLICAr2");
      if (msg.contains('Bucket') ||
          msg.contains('not found') ||
          msg.contains('404')) {
        throw Exception(
          "Supabase Storage bucket '$_postsBucket' not found (404). Create the bucket in Supabase Storage or update SupabaseService to use an existing bucket.",
        );
      }
      rethrow;
    }
    final url = client.storage.from(_postsBucket).getPublicUrl(path);

    final post = {
      'description': description,
      'image_url': url,
      'storage_path': path,
      'created_at': DateTime.now().toIso8601String(),
      'user_id': client.auth.currentUser?.id,
    };
    print("LLEGAUBLICAr3");

    try {
      print("LLEGAUBLICAr4");
      await client.from('posts').insert(post).select().maybeSingle();
    } catch (e) {
      final msg = e.toString();
      print("LLEGAUBLICAr5");
      if (msg.contains('row level security') ||
          msg.contains('violates row-level security') ||
          msg.contains('RLS')) {
        throw Exception(
          'Insert blocked by Row Level Security (RLS).\n'
          'Ensure your `posts` table has a policy that allows authenticated users to insert their own rows.\n'
          'Example SQL:\n'
          "-- enable RLS\nALTER TABLE public.posts ENABLE ROW LEVEL SECURITY;\n"
          "-- allow authenticated users to insert when auth.uid() == new.user_id\n"
          "CREATE POLICY allow_insert_authenticated ON public.posts FOR INSERT WITH CHECK (auth.uid() = user_id AND auth.role() = 'authenticated');",
        );
      }
      rethrow;
    }
  }

  static Future<List<Map<String, dynamic>>> fetchPosts() async {
    final resp = await client
        .from('posts')
        .select()
        .order('created_at', ascending: false);
    return List<Map<String, dynamic>>.from(resp);
  }

  /// Fetch posts for a specific user. If [userId] is null, uses current user.
  static Future<List<Map<String, dynamic>>> fetchUserPosts([
    String? userId,
  ]) async {
    final uid = userId ?? client.auth.currentUser?.id;
    if (uid == null) return [];
    final resp = await client
        .from('posts')
        .select()
        .eq('user_id', uid)
        .order('created_at', ascending: false);
    return List<Map<String, dynamic>>.from(resp);
  }

  /// Delete a post by id. Removes storage object if `storage_path` exists.
  static Future<void> deletePost(dynamic postId) async {
    final maybe = await client
        .from('posts')
        .select()
        .eq('id', postId)
        .maybeSingle();
    if (maybe == null) return;
    final Map<String, dynamic> post = Map<String, dynamic>.from(maybe as Map);
    final storagePath = post['storage_path'] as String?;
    final currentUser = client.auth.currentUser;
    // enforce owner-only delete from client side to reduce RLS surprises
    if (currentUser == null || post['user_id'] != currentUser.id) {
      throw Exception(
        'No tiene permiso para eliminar esta publicación (solo el autor puede eliminarla).',
      );
    }
    if (storagePath != null && storagePath.isNotEmpty) {
      try {
        await client.storage.from(_postsBucket).remove([storagePath]);
      } catch (_) {
        // ignore storage delete errors
      }
    }
    await client.from('posts').delete().eq('id', postId);
  }

  /// Update a post's description and optionally replace its image.
  /// If [bytes] is provided, uploads new image and removes the old one.
  static Future<void> updatePost({
    required dynamic postId,
    String? description,
    Uint8List? bytes,
    String? filename,
  }) async {
    final maybe = await client
        .from('posts')
        .select()
        .eq('id', postId)
        .maybeSingle();
    if (maybe == null) return;
    final Map<String, dynamic> post = Map<String, dynamic>.from(maybe as Map);
    final currentUser = client.auth.currentUser;
    if (currentUser == null || post['user_id'] != currentUser.id) {
      throw Exception(
        'No tiene permiso para editar esta publicación (solo el autor puede editarla).',
      );
    }
    String? newUrl;
    String? newStoragePath;
    if (bytes != null && filename != null) {
      // upload new image
      final path = 'posts/${DateTime.now().millisecondsSinceEpoch}_$filename';
      try {
        await client.storage.from(_postsBucket).uploadBinary(path, bytes);
      } catch (e) {
        final msg = e.toString();
        if (msg.contains('Bucket') ||
            msg.contains('not found') ||
            msg.contains('404')) {
          throw Exception(
            "Supabase Storage bucket '$_postsBucket' not found (404). Create the bucket in Supabase Storage or update SupabaseService to use an existing bucket.",
          );
        }
        rethrow;
      }
      newUrl = client.storage.from(_postsBucket).getPublicUrl(path);
      newStoragePath = path;
    }

    final updates = <String, dynamic>{};
    if (description != null) updates['description'] = description;
    if (newUrl != null) updates['image_url'] = newUrl;
    if (newStoragePath != null) updates['storage_path'] = newStoragePath;

    if (updates.isNotEmpty) {
      await client
          .from('posts')
          .update(updates)
          .eq('id', postId)
          .select()
          .maybeSingle();
    }

    // remove old storage if replaced
    if (newStoragePath != null) {
      final oldPath = post['storage_path'] as String?;
      if (oldPath != null && oldPath.isNotEmpty) {
        try {
          await client.storage.from(_postsBucket).remove([oldPath]);
        } catch (_) {}
      }
    }
  }
}
