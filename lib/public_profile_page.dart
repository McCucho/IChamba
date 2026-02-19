import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'services/supabase_service.dart';

/// Public profile page for ofrecedores.
/// Shows name, last name, profile picture and posts.
/// If the viewed user is the current user, allows editing.
class PublicProfilePage extends StatefulWidget {
  /// The auth_id of the user whose profile is being viewed.
  final String userId;

  const PublicProfilePage({super.key, required this.userId});

  @override
  State<PublicProfilePage> createState() => _PublicProfilePageState();
}

class _PublicProfilePageState extends State<PublicProfilePage> {
  Map<String, dynamic>? _profile;
  List<Map<String, dynamic>> _posts = [];
  bool _loading = true;
  bool _isOwnProfile = false;
  bool _uploading = false;

  // Edit controllers (only used if isOwnProfile)
  final _nameController = TextEditingController();
  final _lastNameController = TextEditingController();
  bool _editing = false;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _lastNameController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    setState(() => _loading = true);
    try {
      final currentUser = SupabaseService.currentUser();
      _isOwnProfile = currentUser?.id == widget.userId;

      final results = await Future.wait([
        SupabaseService.fetchPublicProfile(widget.userId),
        SupabaseService.fetchUserPosts(widget.userId),
      ]);

      if (!mounted) return;
      setState(() {
        _profile = results[0] as Map<String, dynamic>?;
        _posts = List<Map<String, dynamic>>.from(results[1] as List);
        if (_profile != null) {
          _nameController.text = _profile!['first_name'] ?? '';
          _lastNameController.text = _profile!['last_name'] ?? '';
        }
      });
    } catch (e) {
      debugPrint('Error loading public profile: $e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _pickAndUploadAvatar() async {
    try {
      final res = await FilePicker.platform.pickFiles(
        type: FileType.image,
        withData: true,
      );
      if (res == null) return;
      final file = res.files.first;
      if (file.bytes == null) return;

      setState(() => _uploading = true);
      await SupabaseService.uploadAvatar(
        bytes: file.bytes!,
        filename: file.name,
      );
      await _loadData();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Foto de perfil actualizada')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error al subir foto: $e')));
    } finally {
      if (mounted) setState(() => _uploading = false);
    }
  }

  Future<void> _removeAvatar() async {
    setState(() => _uploading = true);
    try {
      await SupabaseService.removeAvatar();
      await _loadData();
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Foto de perfil eliminada')));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error: $e')));
    } finally {
      if (mounted) setState(() => _uploading = false);
    }
  }

  Future<void> _saveProfile() async {
    setState(() => _saving = true);
    try {
      final data = <String, dynamic>{
        'auth_id': widget.userId,
        'first_name': _nameController.text.trim(),
        'last_name': _lastNameController.text.trim(),
      };
      await SupabaseService.upsertUser(data);
      await _loadData();
      if (!mounted) return;
      setState(() => _editing = false);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Perfil actualizado')));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error: $e')));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    if (_loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    if (_profile == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Perfil')),
        body: const Center(child: Text('Perfil no encontrado')),
      );
    }

    final firstName = _profile!['first_name'] ?? '';
    final lastName = _profile!['last_name'] ?? '';
    final fullName = '$firstName $lastName'.trim();
    final avatarUrl = _profile!['avatar_url'] as String?;
    final role = _profile!['role'] ?? 'usuario';
    final city = _profile!['city'] ?? '';
    final neighborhood = _profile!['neighborhood'] ?? '';
    final roleDisplay =
        {
          'usuario': 'Usuario',
          'autenticado': 'Autenticado',
          'ofrecedor': 'Ofrecedor',
          'admin': 'Administrador',
        }[role] ??
        role;

    return Scaffold(
      appBar: AppBar(
        title: Text(fullName.isNotEmpty ? fullName : 'Perfil'),
        actions: [
          if (_isOwnProfile && !_editing)
            IconButton(
              icon: const Icon(Icons.edit),
              tooltip: 'Editar perfil',
              onPressed: () => setState(() => _editing = true),
            ),
          if (_isOwnProfile && _editing)
            IconButton(
              icon: const Icon(Icons.close),
              tooltip: 'Cancelar',
              onPressed: () {
                setState(() {
                  _editing = false;
                  _nameController.text = _profile!['first_name'] ?? '';
                  _lastNameController.text = _profile!['last_name'] ?? '';
                });
              },
            ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _loadData,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              // Avatar section
              Stack(
                alignment: Alignment.bottomRight,
                children: [
                  CircleAvatar(
                    radius: 60,
                    backgroundColor: cs.primaryContainer,
                    backgroundImage: avatarUrl != null && avatarUrl.isNotEmpty
                        ? NetworkImage(avatarUrl)
                        : null,
                    child: avatarUrl == null || avatarUrl.isEmpty
                        ? Icon(
                            Icons.person,
                            size: 60,
                            color: cs.onPrimaryContainer,
                          )
                        : null,
                  ),
                  if (_isOwnProfile)
                    Positioned(
                      bottom: 0,
                      right: 0,
                      child: _uploading
                          ? const SizedBox(
                              width: 36,
                              height: 36,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : PopupMenuButton<String>(
                              icon: CircleAvatar(
                                radius: 18,
                                backgroundColor: cs.primary,
                                child: Icon(
                                  Icons.camera_alt,
                                  size: 18,
                                  color: cs.onPrimary,
                                ),
                              ),
                              onSelected: (val) {
                                if (val == 'upload') _pickAndUploadAvatar();
                                if (val == 'remove') _removeAvatar();
                              },
                              itemBuilder: (ctx) => [
                                const PopupMenuItem(
                                  value: 'upload',
                                  child: ListTile(
                                    leading: Icon(Icons.photo_library),
                                    title: Text('Subir foto'),
                                    dense: true,
                                  ),
                                ),
                                if (avatarUrl != null && avatarUrl.isNotEmpty)
                                  const PopupMenuItem(
                                    value: 'remove',
                                    child: ListTile(
                                      leading: Icon(Icons.delete),
                                      title: Text('Quitar foto'),
                                      dense: true,
                                    ),
                                  ),
                              ],
                            ),
                    ),
                ],
              ),
              const SizedBox(height: 16),

              // Name section
              if (_editing) ...[
                TextField(
                  controller: _nameController,
                  decoration: const InputDecoration(
                    labelText: 'Nombre',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _lastNameController,
                  decoration: const InputDecoration(
                    labelText: 'Apellido',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                ElevatedButton.icon(
                  onPressed: _saving ? null : _saveProfile,
                  icon: _saving
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.save),
                  label: const Text('Guardar'),
                ),
              ] else ...[
                Text(
                  fullName.isNotEmpty ? fullName : 'Sin nombre',
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],

              const SizedBox(height: 8),
              // Role badge
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: role == 'ofrecedor' || role == 'admin'
                      ? cs.primary.withAlpha(30)
                      : cs.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Text(
                  roleDisplay,
                  style: TextStyle(
                    fontSize: 13,
                    color: role == 'ofrecedor' || role == 'admin'
                        ? cs.primary
                        : cs.onSurfaceVariant,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),

              // Location
              if (city.isNotEmpty || neighborhood.isNotEmpty) ...[
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.location_on,
                      size: 16,
                      color: cs.onSurfaceVariant,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      [
                        neighborhood,
                        city,
                      ].where((s) => s.isNotEmpty).join(', '),
                      style: TextStyle(
                        color: cs.onSurfaceVariant,
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
              ],

              const SizedBox(height: 24),
              const Divider(),
              const SizedBox(height: 8),

              // Posts section header
              Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'Publicaciones',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              const SizedBox(height: 12),

              // Posts list
              if (_posts.isEmpty)
                Padding(
                  padding: const EdgeInsets.all(24),
                  child: Text(
                    'No hay publicaciones aún.',
                    style: TextStyle(color: cs.onSurfaceVariant),
                  ),
                )
              else
                ..._posts.map((post) => _buildPostCard(post)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPostCard(Map<String, dynamic> post) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (post['image_url'] != null)
            ClipRRect(
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(12),
              ),
              child: Image.network(
                post['image_url'] as String,
                width: double.infinity,
                height: 220,
                fit: BoxFit.cover,
              ),
            ),
          Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  post['description'] ?? '',
                  style: const TextStyle(fontSize: 14),
                ),
                const SizedBox(height: 8),
                Text(
                  _formatTime(post['created_at'] as String?),
                  style: TextStyle(
                    fontSize: 12,
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _formatTime(String? iso) {
    if (iso == null) return '';
    try {
      final dt = DateTime.parse(iso);
      return '${dt.day}/${dt.month}/${dt.year}';
    } catch (_) {
      return '';
    }
  }
}
