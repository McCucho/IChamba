import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'dart:typed_data';

class SupabaseService {
  static SupabaseClient? _client;
  // Use the 'publicaciones' bucket created in Supabase Storage.
  // Change this value if you prefer a different bucket name.
  static const String _postsBucket = 'publicaciones';
  // Avatars bucket for profile pictures
  static const String _avatarsBucket = 'avatars';

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

  /// Insert or update a user row using upsert. Expects a map with identifying
  /// fields (e.g. 'id' or unique constraint) to perform update when present.
  static Future<void> upsertUser(Map<String, dynamic> user) async {
    final current = client.auth.currentUser;
    final payload = Map<String, dynamic>.from(user);
    // If caller didn't provide an id, set it to the authenticated user's id
    if ((payload['auth_id'] == null || payload['id'].toString().isEmpty) &&
        current != null) {
      payload['auth_id'] = current.id;
    }
    await client.from('users').upsert(payload).select().maybeSingle();
  }

  /// Fetch the current user's row from `users` table (by auth id).
  static Future<Map<String, dynamic>?> fetchUserProfile([
    String? userId,
  ]) async {
    final uid = userId ?? client.auth.currentUser?.id;
    if (uid == null) return null;
    final resp = await client
        .from('users')
        .select()
        .eq('id', uid)
        .maybeSingle();
    if (resp == null) return null;
    return Map<String, dynamic>.from(resp as Map);
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
    final url = client.storage.from(_postsBucket).getPublicUrl(path);

    final post = {
      'description': description,
      'image_url': url,
      'storage_path': path,
      'created_at': DateTime.now().toIso8601String(),
      'user_id': client.auth.currentUser?.id,
    };

    try {
      await client.from('posts').insert(post).select().maybeSingle();
    } catch (e) {
      final msg = e.toString();
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

  /// Upload a profile image to storage and save the public URL to the `users` table
  /// The user's row is identified by `auth_id` equal to the authenticated user's id.
  /// Returns the public URL of the uploaded image.
  static Future<String> uploadProfileImageAndSave({
    required Uint8List bytes,
    required String filename,
  }) async {
    final user = client.auth.currentUser;
    if (user == null) {
      throw Exception('Usuario no autenticado. Inicia sesión primero.');
    }

    final path =
        'avatars/${user.id}_${DateTime.now().millisecondsSinceEpoch}_$filename';

    try {
      await client.storage.from(_avatarsBucket).uploadBinary(path, bytes);
    } catch (e) {
      final msg = e.toString();
      if (msg.contains('Bucket') ||
          msg.contains('not found') ||
          msg.contains('404')) {
        throw Exception(
          "Supabase Storage bucket '$_avatarsBucket' not found (404). Crea el bucket 'avatars' en Supabase Storage o actualiza el nombre en SupabaseService.",
        );
      }
      rethrow;
    }

    final url = client.storage.from(_avatarsBucket).getPublicUrl(path);

    // Save URL into users table (match by auth_id)
    try {
      await client
          .from('users')
          .update({'avatar_url': url})
          .eq('auth_id', user.id);
    } catch (e) {
      // Not fatal: still return the URL, but surface a warning via exception
      throw Exception(
        'Imagen subida pero no se pudo guardar la URL en users: $e',
      );
    }

    return url;
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

  // ── Messaging helpers ──────────────────────────────────────────────

  /// Send a message from the current user to [receiverId].
  static Future<void> sendMessage({
    required String receiverId,
    required String content,
  }) async {
    final user = client.auth.currentUser;
    if (user == null) throw Exception('No autenticado');
    await client.from('messages').insert({
      'sender_id': user.id,
      'receiver_id': receiverId,
      'content': content,
    });
  }

  /// Fetch all messages in a conversation between the current user and [otherId],
  /// ordered oldest‑first so the list scrolls naturally.
  static Future<List<Map<String, dynamic>>> fetchConversation(
    String otherId,
  ) async {
    final uid = client.auth.currentUser?.id;
    if (uid == null) return [];
    final resp = await client
        .from('messages')
        .select()
        .or(
          'and(sender_id.eq.$uid,receiver_id.eq.$otherId),and(sender_id.eq.$otherId,receiver_id.eq.$uid)',
        )
        .order('created_at', ascending: true);
    return List<Map<String, dynamic>>.from(resp);
  }

  /// Return a list of unique conversation partners with the last message preview.
  /// Each entry: { 'partner_id', 'partner_email', 'last_message', 'last_time', 'unread' }
  static Future<List<Map<String, dynamic>>> fetchConversationsList() async {
    final uid = client.auth.currentUser?.id;
    if (uid == null) return [];

    // Fetch all messages involving the user
    final resp = await client
        .from('messages')
        .select()
        .or('sender_id.eq.$uid,receiver_id.eq.$uid')
        .order('created_at', ascending: false);
    final allMsgs = List<Map<String, dynamic>>.from(resp);

    // Group by partner
    final Map<String, Map<String, dynamic>> convos = {};
    for (final m in allMsgs) {
      final partnerId = m['sender_id'] == uid
          ? m['receiver_id']
          : m['sender_id'];
      if (!convos.containsKey(partnerId)) {
        convos[partnerId as String] = {
          'partner_id': partnerId,
          'last_message': m['content'],
          'last_time': m['created_at'],
          'unread': (m['receiver_id'] == uid && m['read'] == false) ? 1 : 0,
        };
      } else {
        if (m['receiver_id'] == uid && m['read'] == false) {
          convos[partnerId]!['unread'] =
              (convos[partnerId]!['unread'] as int) + 1;
        }
      }
    }

    return convos.values.toList();
  }

  /// Mark all messages from [senderId] to the current user as read.
  static Future<void> markConversationRead(String senderId) async {
    final uid = client.auth.currentUser?.id;
    if (uid == null) return;
    await client
        .from('messages')
        .update({'read': true})
        .eq('sender_id', senderId)
        .eq('receiver_id', uid)
        .eq('read', false);
  }

  /// Fetch all users except the current one (for "new message" user picker).
  static Future<List<Map<String, dynamic>>> fetchOtherUsers() async {
    final uid = client.auth.currentUser?.id;
    debugPrint('[fetchOtherUsers] uid=$uid');
    final resp = await client.from('users').select();
    final all = List<Map<String, dynamic>>.from(resp);
    debugPrint('[fetchOtherUsers] total users in table: ${all.length}');
    for (final u in all) {
      debugPrint(
        '[fetchOtherUsers] user: auth_id=${u['auth_id']}, id=${u['id']}, email=${u['email']}',
      );
    }
    if (uid == null) return all;
    final filtered = all.where((u) {
      final authId = u['auth_id']?.toString();
      final id = u['id']?.toString();
      return authId != uid && id != uid;
    }).toList();
    debugPrint(
      '[fetchOtherUsers] filtered (excluding self): ${filtered.length}',
    );
    return filtered;
  }
}
