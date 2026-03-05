import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'services/supabase_service.dart';

/// Full-screen detail view for a single post/publication.
/// When [isEditable] is true, the owner can edit the description/image
/// and delete the post directly from this screen.
class PostDetailPage extends StatefulWidget {
  final Map<String, dynamic> post;
  final String? authorName;
  final String? authorAvatarUrl;

  /// When true, shows edit / delete controls.
  final bool isEditable;

  /// Called after a successful save or delete so the caller can refresh.
  final VoidCallback? onPostChanged;

  const PostDetailPage({
    super.key,
    required this.post,
    this.authorName,
    this.authorAvatarUrl,
    this.isEditable = false,
    this.onPostChanged,
  });

  @override
  State<PostDetailPage> createState() => _PostDetailPageState();
}

class _PostDetailPageState extends State<PostDetailPage> {
  bool _editing = false;
  bool _saving = false;
  late final TextEditingController _descController;

  // New image chosen by the user (only during edit mode)
  Uint8List? _newImageBytes;
  String? _newImageName;

  // Local mutable copy of post data so we can update the UI after save
  late Map<String, dynamic> _post;

  @override
  void initState() {
    super.initState();
    _post = Map<String, dynamic>.from(widget.post);
    _descController = TextEditingController(
      text: _post['description'] as String? ?? '',
    );
  }

  @override
  void dispose() {
    _descController.dispose();
    super.dispose();
  }

  String _formatDate(String? iso) {
    if (iso == null) return '';
    try {
      final dt = DateTime.parse(iso).toLocal();
      final day = dt.day.toString().padLeft(2, '0');
      final month = dt.month.toString().padLeft(2, '0');
      final year = dt.year;
      final hour = dt.hour.toString().padLeft(2, '0');
      final min = dt.minute.toString().padLeft(2, '0');
      return '$day/$month/$year  $hour:$min';
    } catch (_) {
      return '';
    }
  }

  Future<void> _pickNewImage() async {
    final res = await FilePicker.platform.pickFiles(
      type: FileType.image,
      withData: true,
    );
    if (res == null) return;
    final f = res.files.first;
    setState(() {
      _newImageBytes = f.bytes;
      _newImageName = f.name;
    });
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    try {
      await SupabaseService.updatePost(
        postId: _post['auth_id'],
        description: _descController.text.trim(),
        bytes: _newImageBytes,
        filename: _newImageName,
      );
      // Refresh local state
      setState(() {
        _post['description'] = _descController.text.trim();
        if (_newImageBytes != null) {
          // URL will refresh on next load; clear preview bytes
          _newImageBytes = null;
          _newImageName = null;
        }
        _editing = false;
      });
      widget.onPostChanged?.call();
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Publicación actualizada')));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error al guardar: $e')));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _confirmDelete() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Eliminar publicación'),
        content: const Text('¿Seguro que deseas eliminar esta publicación?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Eliminar'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    setState(() => _saving = true);
    try {
      await SupabaseService.deletePost(_post['auth_id']);
      widget.onPostChanged?.call();
      if (!mounted) return;
      Navigator.pop(context);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error al eliminar: $e')));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final imageUrl = _post['image_url'] as String?;
    final description = _post['description'] as String? ?? '';
    final createdAt = _post['created_at'] as String?;
    final dateStr = _formatDate(createdAt);

    return Scaffold(
      backgroundColor: Colors.black,
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
        title: Text(
          widget.authorName ?? 'Publicación',
          style: const TextStyle(color: Colors.white),
        ),
        actions: [
          if (widget.isEditable && !_editing && !_saving)
            IconButton(
              icon: const Icon(Icons.edit, color: Colors.white),
              tooltip: 'Editar',
              onPressed: () => setState(() => _editing = true),
            ),
          if (widget.isEditable && _editing && !_saving)
            IconButton(
              icon: const Icon(Icons.close, color: Colors.white),
              tooltip: 'Cancelar',
              onPressed: () => setState(() {
                _editing = false;
                _descController.text = _post['description'] as String? ?? '';
                _newImageBytes = null;
                _newImageName = null;
              }),
            ),
          if (widget.isEditable && !_editing && !_saving)
            IconButton(
              icon: const Icon(Icons.delete_outline, color: Colors.white),
              tooltip: 'Eliminar',
              onPressed: _confirmDelete,
            ),
        ],
      ),
      body: SafeArea(
        top: false,
        child: Column(
          children: [
            // ── Hero image ──────────────────────────────────────────────
            Expanded(
              child: _newImageBytes != null
                  ? Image.memory(
                      _newImageBytes!,
                      fit: BoxFit.contain,
                      width: double.infinity,
                    )
                  : imageUrl != null && imageUrl.isNotEmpty
                  ? InteractiveViewer(
                      minScale: 0.8,
                      maxScale: 5.0,
                      child: Image.network(
                        imageUrl,
                        fit: BoxFit.contain,
                        width: double.infinity,
                        loadingBuilder: (context, child, loadingProgress) {
                          if (loadingProgress == null) return child;
                          return Center(
                            child: CircularProgressIndicator(
                              value: loadingProgress.expectedTotalBytes != null
                                  ? loadingProgress.cumulativeBytesLoaded /
                                        loadingProgress.expectedTotalBytes!
                                  : null,
                              color: Colors.white,
                            ),
                          );
                        },
                        errorBuilder: (context, error, stack) => const Center(
                          child: Icon(
                            Icons.broken_image,
                            size: 80,
                            color: Colors.white54,
                          ),
                        ),
                      ),
                    )
                  : const Center(
                      child: Icon(
                        Icons.image_not_supported,
                        size: 80,
                        color: Colors.white54,
                      ),
                    ),
            ),

            // ── Details / edit panel ─────────────────────────────────────
            Container(
              width: double.infinity,
              decoration: BoxDecoration(
                color: cs.surface,
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(20),
                ),
              ),
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Handle bar
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: cs.outlineVariant,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Author row
                  if (widget.authorName != null ||
                      widget.authorAvatarUrl != null)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 14),
                      child: Row(
                        children: [
                          CircleAvatar(
                            radius: 20,
                            backgroundColor: cs.primaryContainer,
                            backgroundImage:
                                widget.authorAvatarUrl != null &&
                                    widget.authorAvatarUrl!.isNotEmpty
                                ? NetworkImage(widget.authorAvatarUrl!)
                                : null,
                            child:
                                widget.authorAvatarUrl == null ||
                                    widget.authorAvatarUrl!.isEmpty
                                ? Icon(
                                    Icons.person,
                                    size: 20,
                                    color: cs.onPrimaryContainer,
                                  )
                                : null,
                          ),
                          const SizedBox(width: 10),
                          Text(
                            widget.authorName ?? '',
                            style: TextStyle(
                              fontWeight: FontWeight.w600,
                              fontSize: 15,
                              color: cs.onSurface,
                            ),
                          ),
                        ],
                      ),
                    ),

                  // ── Edit mode ────────────────────────────────────────
                  if (_editing) ...[
                    // Replace image button
                    OutlinedButton.icon(
                      onPressed: _saving ? null : _pickNewImage,
                      icon: const Icon(Icons.photo_library),
                      label: Text(
                        _newImageName != null
                            ? 'Imagen: $_newImageName'
                            : 'Reemplazar imagen (opcional)',
                      ),
                    ),
                    const SizedBox(height: 12),
                    // Description field
                    TextField(
                      controller: _descController,
                      maxLines: 4,
                      enabled: !_saving,
                      decoration: InputDecoration(
                        labelText: 'Descripción',
                        border: const OutlineInputBorder(),
                        filled: true,
                        fillColor: cs.surfaceContainerHighest.withAlpha(80),
                      ),
                    ),
                    const SizedBox(height: 14),
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton.icon(
                        onPressed: _saving ? null : _save,
                        icon: _saving
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : const Icon(Icons.save),
                        label: const Text('Guardar cambios'),
                      ),
                    ),
                  ] else ...[
                    // ── Read mode ──────────────────────────────────────
                    if (description.isNotEmpty) ...[
                      Text(
                        description,
                        style: TextStyle(
                          fontSize: 15,
                          color: cs.onSurface,
                          height: 1.4,
                        ),
                      ),
                      const SizedBox(height: 12),
                    ],
                    Divider(color: cs.outlineVariant),
                    const SizedBox(height: 8),
                    if (dateStr.isNotEmpty)
                      Row(
                        children: [
                          Icon(
                            Icons.access_time_rounded,
                            size: 15,
                            color: cs.onSurfaceVariant,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            dateStr,
                            style: TextStyle(
                              fontSize: 13,
                              color: cs.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
