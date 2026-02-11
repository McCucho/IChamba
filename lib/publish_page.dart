import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'services/supabase_service.dart';
import 'services/selected_image_store.dart';
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
      print("LLEGA1");
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
      print("LLEGA2");
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error: $e')));
    } finally {
      print("LLEGA3");
      if (mounted) setState(() => _loading = false);
      print("LLEGA4");
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

  Future<void> _editPost(Map<String, dynamic> post) async {
    final descController = TextEditingController(
      text: post['description'] as String?,
    );
    Uint8List? newImageBytes;
    String? newImageName;

    final res = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Editar publicación'),
        content: SingleChildScrollView(
          child: Column(
            children: [
              TextField(controller: descController, maxLines: 3),
              const SizedBox(height: 8),
              ElevatedButton.icon(
                onPressed: () async {
                  final r = await FilePicker.platform.pickFiles(
                    type: FileType.image,
                    withData: true,
                  );
                  if (r == null) return;
                  final f = r.files.first;
                  newImageBytes = f.bytes;
                  newImageName = f.name;
                },
                icon: const Icon(Icons.photo_library),
                label: const Text('Reemplazar imagen (opcional)'),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () async {
              // perform update
              await SupabaseService.updatePost(
                postId: post['auth_id'],
                description: descController.text.trim(),
                bytes: newImageBytes,
                filename: newImageName,
              );
              Navigator.pop(context, true);
            },
            child: const Text('Guardar'),
          ),
        ],
      ),
    );

    if (res == true) await _loadMyPosts();
    SelectedImageStore.instance.notifyPostsChanged();
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
      body: Padding(
        padding: const EdgeInsets.all(16.0),
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
            if (_loadingPosts) const Center(child: CircularProgressIndicator()),
            if (!_loadingPosts && _myPosts.isEmpty)
              const Text('No tienes publicaciones aún.'),
            if (!_loadingPosts && _myPosts.isNotEmpty)
              ..._myPosts.map((post) {
                return Card(
                  margin: const EdgeInsets.symmetric(vertical: 8),
                  child: ListTile(
                    leading: post['image_url'] != null
                        ? Image.network(
                            post['image_url'] as String,
                            width: 56,
                            height: 56,
                            fit: BoxFit.cover,
                          )
                        : const SizedBox(width: 56, height: 56),
                    title: Text(post['description'] ?? ''),
                    subtitle: Text(post['created_at'] ?? ''),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          icon: const Icon(Icons.edit),
                          onPressed: () => _editPost(post),
                        ),
                        IconButton(
                          icon: const Icon(Icons.delete),
                          onPressed: () async {
                            final confirm = await showDialog<bool>(
                              context: context,
                              builder: (context) => AlertDialog(
                                title: const Text('Eliminar publicación'),
                                content: const Text(
                                  '¿Seguro que deseas eliminar esta publicación?',
                                ),
                                actions: [
                                  TextButton(
                                    onPressed: () =>
                                        Navigator.pop(context, false),
                                    child: const Text('Cancelar'),
                                  ),
                                  ElevatedButton(
                                    onPressed: () =>
                                        Navigator.pop(context, true),
                                    child: const Text('Eliminar'),
                                  ),
                                ],
                              ),
                            );
                            if (confirm == true) await _deletePost(post['auth_id']);
                          },
                        ),
                      ],
                    ),
                  ),
                );
              }),
          ],
        ),
      ),
    );
  }
}
