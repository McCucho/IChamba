import 'package:flutter/material.dart';
import 'dart:typed_data';
import 'package:file_picker/file_picker.dart';
import 'services/supabase_service.dart';
import 'services/selected_image_store.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'profile_page.dart';
import 'publish_page.dart';
import 'messages_page.dart';

class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  int _selectedIndex = 1; // 0=profile,1=main (menu) - default to menu
  List<Map<String, dynamic>> _posts = [];
  bool _loadingPosts = false;
  String? _appVersion;
  VoidCallback? _postsListener;

  @override
  void initState() {
    super.initState();
    // Sidebar stays visible at all times; load public posts for feed.
    _loadPosts();
    _loadAvatarUrl();
    // Listen for posts changes and refresh feed
    _postsListener = _onPostsChanged;
    SelectedImageStore.instance.postsVersion.addListener(_postsListener!);
    _loadAppVersion();
  }

  Future<void> _loadAvatarUrl() async {
    try {
      final profile = await SupabaseService.fetchUserProfile();
      final url = profile?['avatar_url'] as String?;
      if (url != null && url.isNotEmpty) {
        SelectedImageStore.instance.setAvatarUrl(url);
      }
    } catch (_) {
      // ignore
    }
  }

  // profile loader removed because top avatar was removed from UI

  Future<void> _loadAppVersion() async {
    try {
      final info = await PackageInfo.fromPlatform();
      if (!mounted) return;
      setState(() {
        _appVersion = '${info.version}+${info.buildNumber}';
      });
    } catch (_) {
      // ignore
    }
  }

  void _onPostsChanged() {
    _loadPosts();
  }

  @override
  void dispose() {
    if (_postsListener != null) {
      SelectedImageStore.instance.postsVersion.removeListener(_postsListener!);
    }
    super.dispose();
  }

  Future<void> _pickProfileImage() async {
    try {
      final res = await FilePicker.platform.pickFiles(
        type: FileType.image,
        withData: true,
      );
      if (res == null) return;
      final file = res.files.first;

      if (file.bytes != null) {
        try {
          final url = await SupabaseService.uploadProfileImageAndSave(
            bytes: file.bytes!,
            filename: file.name,
          );
          SelectedImageStore.instance.setImage(file.bytes, file.name);
          SelectedImageStore.instance.setAvatarUrl(url);
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Imagen de perfil subida y guardada')),
          );
        } catch (e) {
          if (!mounted) return;
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text('Error al subir imagen: $e')));
        }
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error al seleccionar imagen: $e')),
      );
    }
  }

  Future<void> _loadPosts() async {
    setState(() => _loadingPosts = true);
    try {
      final posts = await SupabaseService.fetchPosts();
      if (!mounted) return;
      setState(() => _posts = posts);
    } catch (e) {
      // ignore
    } finally {
      if (mounted) setState(() => _loadingPosts = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Column(
        children: [
          // Top thin translucent banner with stylized app name and logout
          Container(
            width: double.infinity,
            height: 56,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            decoration: BoxDecoration(
              color: Theme.of(
                context,
              ).colorScheme.primaryContainer.withOpacity(0.12),
            ),
            child: Stack(
              alignment: Alignment.center,
              children: [
                Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'Ichamba',
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.primary,
                          fontStyle: FontStyle.italic,
                          fontSize: 22,
                          fontWeight: FontWeight.w600,
                          shadows: [
                            Shadow(
                              blurRadius: 2,
                              color: Theme.of(
                                context,
                              ).colorScheme.primary.withOpacity(0.15),
                            ),
                          ],
                        ),
                      ),
                      if (_appVersion != null)
                        Padding(
                          padding: const EdgeInsets.only(top: 2.0),
                          child: Text(
                            'v${_appVersion}',
                            style: TextStyle(
                              color: Theme.of(
                                context,
                              ).colorScheme.onSurfaceVariant,
                              fontSize: 11,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
                Positioned(
                  right: 0,
                  child: IconButton(
                    tooltip: 'Salir',
                    onPressed: () async {
                      await SupabaseService.signOut();
                      if (!context.mounted) return;
                      Navigator.pushNamedAndRemoveUntil(
                        context,
                        '/login',
                        (r) => false,
                      );
                    },
                    icon: const Icon(Icons.logout),
                  ),
                ),
              ],
            ),
          ),

          // Main content: sidebar + content area
          Expanded(
            child: LayoutBuilder(
              builder: (context, constraints) {
                final sidebarWidth = constraints.maxWidth < 720
                    ? (constraints.maxWidth * 0.26).clamp(72.0, 220.0)
                    : (constraints.maxWidth * 0.22).clamp(120.0, 320.0);

                return Row(
                  children: [
                    Container(
                      width: sidebarWidth,
                      color: Theme.of(context).colorScheme.surfaceVariant,
                      child: SafeArea(
                        child: SingleChildScrollView(
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.start,
                            children: [
                              // Top avatar/logo removed as requested
                              const SizedBox(height: 6),
                              ..._buildSidebarButtons(context),
                            ],
                          ),
                        ),
                      ),
                    ),
                    Expanded(
                      child: Container(
                        color: Theme.of(context).colorScheme.background,
                        padding: const EdgeInsets.all(16),
                        child: _buildContentForIndex(),
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildIconGrid() {
    final items = List.generate(24, (index) => 'Opción ${index + 1}');

    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        // aim ~200-240px per item; compute columns accordingly
        int crossAxisCount = (width / 220).floor();
        if (crossAxisCount < 1) crossAxisCount = 1;
        if (crossAxisCount > 6) crossAxisCount = 6;

        return GridView.builder(
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: crossAxisCount,
            mainAxisSpacing: 12,
            crossAxisSpacing: 12,
            childAspectRatio: 0.9,
          ),
          itemCount: items.length,
          itemBuilder: (context, index) {
            final label = items[index];
            return Card(
              elevation: 2,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              child: InkWell(
                onTap: () {},
                child: Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.apps,
                        size: 36,
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        label,
                        textAlign: TextAlign.center,
                        style: const TextStyle(fontSize: 14),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildContentForIndex() {
    switch (_selectedIndex) {
      case 0:
        return const ProfilePage();
      case 3:
        return const PublishPage();
      case 4:
        return const MessagesPage();
      case 1:
      default:
        return RefreshIndicator(
          onRefresh: _loadPosts,
          child: _loadingPosts
              ? const Center(child: CircularProgressIndicator())
              : _posts.isEmpty
              ? ListView(
                  children: const [
                    Padding(
                      padding: EdgeInsets.all(16),
                      child: Text('No hay publicaciones aún.'),
                    ),
                  ],
                )
              : ListView.builder(
                  itemCount: _posts.length,
                  itemBuilder: (context, index) {
                    final post = _posts[index];
                    return Card(
                      margin: const EdgeInsets.symmetric(vertical: 8),
                      elevation: 2,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (post['image_url'] != null)
                            Image.network(
                              post['image_url'] as String,
                              width: double.infinity,
                              height: 220,
                              fit: BoxFit.cover,
                            ),
                          Padding(
                            padding: const EdgeInsets.all(12.0),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(post['description'] ?? ''),
                                const SizedBox(height: 8),
                                Text(
                                  post['created_at'] ?? '',
                                  style: const TextStyle(
                                    fontSize: 12,
                                    color: Colors.black54,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
        );
    }
  }

  List<Widget> _buildSidebarButtons(BuildContext context) {
    // Left menu: 6 icons. 1=Main menu, 2=Profile (edit user data), then others.
    final items = [
      {
        'icon': Icons.person,
        'tooltip': 'Perfil',
        'action': () => _showProfileOptions(),
      },
      {
        'icon': Icons.menu,
        'tooltip': 'Menú principal',
        'action': () {
          setState(() {
            _selectedIndex = 1;
          });
        },
      },
      {
        'icon': Icons.notifications,
        'tooltip': 'Notificaciones',
        'action': () {},
      },
      {
        'icon': Icons.cloud_upload,
        'tooltip': 'PUBLICAR',
        'action': () {
          setState(() {
            _selectedIndex = 3;
          });
        },
      },
      {
        'icon': Icons.chat_bubble_outline,
        'tooltip': 'Mensajes',
        'action': () {
          setState(() {
            _selectedIndex = 4;
          });
        },
      },
      {'icon': Icons.settings, 'tooltip': 'Ajustes', 'action': () {}},
    ];

    // Render icon with label beneath and active highlight
    return items.asMap().entries.map((entry) {
      final idx = entry.key;
      final it = entry.value;
      final active = _selectedIndex == idx;
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: GestureDetector(
          onTap: it['action'] as void Function()?,
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 8),
            decoration: BoxDecoration(
              color: active
                  ? Theme.of(context).colorScheme.primary.withOpacity(0.08)
                  : Colors.transparent,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // For the first item (profile) show mini-avatar if available
                if (idx == 0)
                  ValueListenableBuilder<Uint8List?>(
                    valueListenable: SelectedImageStore.instance.imageNotifier,
                    builder: (context, bytes, _) {
                      if (bytes != null) {
                        return CircleAvatar(
                          radius: 16,
                          backgroundImage: MemoryImage(bytes),
                        );
                      }
                      return ValueListenableBuilder<String?>(
                        valueListenable:
                            SelectedImageStore.instance.avatarUrlNotifier,
                        builder: (context, url, __) {
                          if (url != null && url.isNotEmpty) {
                            return CircleAvatar(
                              radius: 16,
                              backgroundImage: NetworkImage(url),
                            );
                          }
                          return Icon(
                            it['icon'] as IconData,
                            size: 28,
                            color: active
                                ? Theme.of(context).colorScheme.primary
                                : Theme.of(context).colorScheme.onSurface,
                          );
                        },
                      );
                    },
                  )
                else
                  Icon(
                    it['icon'] as IconData,
                    size: 28,
                    color: active
                        ? Theme.of(context).colorScheme.primary
                        : Theme.of(context).colorScheme.onSurface,
                  ),
                const SizedBox(height: 6),
                Text(
                  it['tooltip'] as String,
                  style: TextStyle(
                    fontSize: 12,
                    color: active
                        ? Theme.of(context).colorScheme.primary
                        : Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }).toList();
  }

  void _showProfileOptions() {
    showModalBottomSheet<void>(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.person),
              title: const Text('Ver perfil'),
              onTap: () {
                Navigator.pop(context);
                setState(() => _selectedIndex = 0);
              },
            ),
            ListTile(
              leading: const Icon(Icons.photo_library),
              title: const Text('Seleccionar foto'),
              onTap: () {
                Navigator.pop(context);
                _pickProfileImage();
              },
            ),
            ListTile(
              leading: const Icon(Icons.delete_forever),
              title: const Text('Quitar foto'),
              onTap: () {
                Navigator.pop(context);
                SelectedImageStore.instance.clear();
              },
            ),
          ],
        ),
      ),
    );
  }
}
