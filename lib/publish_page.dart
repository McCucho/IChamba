import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'services/supabase_service.dart';
import 'services/selected_image_store.dart';
import 'widgets/desktop_responsive.dart';
import 'post_detail_page.dart';
import 'dart:async';

class PublishPage extends StatefulWidget {
  const PublishPage({super.key});

  @override
  State<PublishPage> createState() => _PublishPageState();
}

class _PublishPageState extends State<PublishPage> {
  Uint8List? _imageData;
  String? _imageName;
  final _descController = TextEditingController();
  bool _loading = false;
  List<Map<String, dynamic>> _myPosts = [];
  bool _loadingPosts = false;

  Future<void> _pickImage() async {
    final res = await FilePicker.platform.pickFiles(
      type: FileType.image,
      withData: true,
    );
    if (res == null) return;
    final file = res.files.first;
    setState(() {
      _imageData = file.bytes;
      _imageName = file.name;
      SelectedImageStore.instance.setImage(_imageData, _imageName);
    });
  }

  @override
  void initState() {
    super.initState();
    _loadMyPosts();
  }

  Future<void> _publish() async {
    if (_imageData == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Seleccione una imagen')));
      return;
    }
    if (_descController.text.trim().isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Ingrese descripción')));
      return;
    }
    setState(() => _loading = true);
    try {
      await SupabaseService.uploadPostImageAndCreate(
        bytes: _imageData!,
        filename: _imageName ?? 'post.jpg',
        description: _descController.text.trim(),
      );
      // debug: upload completed
      await _loadMyPosts();
      SelectedImageStore.instance.notifyPostsChanged();
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Publicación creada')));
      setState(() {
        _imageData = null;
        _imageName = null;
        _descController.clear();
      });
      // debug: posts reloaded
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error: $e')));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _loadMyPosts() async {
    setState(() => _loadingPosts = true);
    try {
      final userId = SupabaseService.currentUser()?.id;
      final posts = await SupabaseService.fetchUserPosts(userId);
      if (!mounted) return;
      setState(() {
        _myPosts = posts;
      });
    } catch (e) {
      // ignore
    } finally {
      if (mounted) setState(() => _loadingPosts = false);
    }
  }

  Future<void> _deletePost(dynamic id) async {
    setState(() => _loadingPosts = true);
    try {
      await SupabaseService.deletePost(id);
      await _loadMyPosts();
      SelectedImageStore.instance.notifyPostsChanged();
    } finally {
      if (mounted) setState(() => _loadingPosts = false);
    }
  }

  String _formatDate(String? iso) {
    if (iso == null) return '';
    try {
      final dt = DateTime.parse(iso).toLocal();
      return '${dt.day.toString().padLeft(2, '0')}/${dt.month.toString().padLeft(2, '0')}/${dt.year}';
    } catch (_) {
      return '';
    }
  }

  @override
  void dispose() {
    _descController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Publicar')),
      body: DesktopResponsive(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ElevatedButton.icon(
                  onPressed: _pickImage,
                  icon: const Icon(Icons.photo_library),
                  label: const Text('Seleccionar imagen'),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _descController,
                  decoration: const InputDecoration(labelText: 'Descripción'),
                  maxLines: 3,
                ),
                const SizedBox(height: 12),
                // Preview displayed below description as requested
                Container(
                  height: 180,
                  width: double.infinity,
                  color: Colors.grey[200],
                  child: _imageData == null
                      ? const Center(child: Text('No hay imagen seleccionada'))
                      : Image.memory(_imageData!, fit: BoxFit.cover),
                ),
                const SizedBox(height: 12),
                ElevatedButton(
                  onPressed: _loading ? null : _publish,
                  child: _loading
                      ? const CircularProgressIndicator(color: Colors.white)
                      : const Text('Publicar'),
                ),

                const Divider(height: 32),
                const Text(
                  'Mis publicaciones',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 8),
                if (_loadingPosts)
                  const Center(child: CircularProgressIndicator()),
                if (!_loadingPosts && _myPosts.isEmpty)
                  const Text('No tienes publicaciones aún.'),
                if (!_loadingPosts && _myPosts.isNotEmpty)
                  for (final post in _myPosts)
                    Card(
                      margin: const EdgeInsets.symmetric(vertical: 8),
                      clipBehavior: Clip.antiAlias,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: InkWell(
                        onTap: () async {
                          await Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => PostDetailPage(
                                post: post,
                                isEditable: true,
                                onPostChanged: () {
                                  _loadMyPosts();
                                  SelectedImageStore.instance
                                      .notifyPostsChanged();
                                },
                              ),
                            ),
                          );
                        },
                        child: Row(
                          children: [
                            // Thumbnail
                            if (post['image_url'] != null)
                              Image.network(
                                post['image_url'] as String,
                                width: 80,
                                height: 80,
                                fit: BoxFit.cover,
                              )
                            else
                              Container(
                                width: 80,
                                height: 80,
                                color: Colors.grey[200],
                                child: const Icon(
                                  Icons.image,
                                  color: Colors.grey,
                                ),
                              ),
                            const SizedBox(width: 12),
                            // Text info
                            Expanded(
                              child: Padding(
                                padding: const EdgeInsets.symmetric(
                                  vertical: 10,
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      post['description'] ?? '',
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(fontSize: 14),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      _formatDate(
                                        post['created_at'] as String?,
                                      ),
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: Theme.of(
                                          context,
                                        ).colorScheme.onSurfaceVariant,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                            // Delete button (quick delete without opening detail)
                            IconButton(
                              icon: const Icon(Icons.delete_outline),
                              color: Colors.red,
                              tooltip: 'Eliminar',
                              onPressed: () async {
                                final confirm = await showDialog<bool>(
                                  context: context,
                                  builder: (ctx) => AlertDialog(
                                    title: const Text('Eliminar publicación'),
                                    content: const Text(
                                      '¿Seguro que deseas eliminar esta publicación?',
                                    ),
                                    actions: [
                                      TextButton(
                                        onPressed: () =>
                                            Navigator.pop(ctx, false),
                                        child: const Text('Cancelar'),
                                      ),
                                      ElevatedButton(
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: Colors.red,
                                          foregroundColor: Colors.white,
                                        ),
                                        onPressed: () =>
                                            Navigator.pop(ctx, true),
                                        child: const Text('Eliminar'),
                                      ),
                                    ],
                                  ),
                                );
                                if (confirm == true) {
                                  await _deletePost(post['auth_id']);
                                }
                              },
                            ),
                          ],
                        ),
                      ),
                    ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
