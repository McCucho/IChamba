import 'package:flutter/material.dart';
import 'dart:typed_data';
import 'package:file_picker/file_picker.dart';
import 'services/supabase_service.dart';
import 'services/selected_image_store.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'profile_page.dart';
import 'publish_page.dart';
import 'messages_page.dart';
import 'settings_page.dart';

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
    _loadPosts();
    _postsListener = _onPostsChanged;
    SelectedImageStore.instance.postsVersion.addListener(_postsListener!);
    _loadAppVersion();
  }

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

  Future<void> _loadPosts() async {
    setState(() => _loadingPosts = true);
    try {
      final posts = await SupabaseService.fetchPosts();
      try {
        final users = await SupabaseService.fetchUsers();
        final Map<String, Map<String, dynamic>> userMap = {};
        for (final u in users) {
          final key = (u['auth_id'] ?? u['id'])?.toString();
          if (key != null) userMap[key] = u;
        }
        for (final p in posts) {
          final uid = p['user_id']?.toString();
          if (uid != null && userMap.containsKey(uid)) {
            p['author_name'] =
                userMap[uid]?['first_name'] ?? userMap[uid]?['email'] ?? uid;
          } else if (uid != null) {
            p['author_name'] = uid;
          }
        }
      } catch (_) {
        // ignore
      }
      if (!mounted) return;
      setState(() => _posts = posts);
    } catch (e) {
      // ignore
    } finally {
      if (mounted) setState(() => _loadingPosts = false);
    }
  }

  String _formatPostTime(String? iso) {
    if (iso == null) return '';
    try {
      final dt = DateTime.parse(iso).toLocal();
      final now = DateTime.now();
      if (dt.year == now.year && dt.month == now.month && dt.day == now.day) {
        return '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
      }
      return '${dt.day}/${dt.month} ${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
    } catch (_) {
      return '';
    }
  }

  String _postAuthor(Map<String, dynamic> post) {
    final keys = [
      'author_name',
      'author',
      'first_name',
      'user_name',
      'user_email',
      'email',
      'user_id',
      'creator',
    ];
    for (final k in keys) {
      final v = post[k];
      if (v != null && v.toString().trim().isNotEmpty) return v.toString();
    }
    return 'Anon';
  }

  String _timeAgoUruguay(String? iso) {
    if (iso == null) return '';
    try {
      // Determine the created instant in UTC.
      // If the string contains a timezone offset (Z or +hh:mm/-hh:mm), parse normally.
      // Otherwise treat the timestamp as Uruguay local time (UTC-3) and convert to UTC.
      DateTime createdUtc;
      final tzOffsetPattern = RegExp(r'Z|[+-]\d{2}:?\d{2}\$');
      if (tzOffsetPattern.hasMatch(iso)) {
        createdUtc = DateTime.parse(iso).toUtc();
      } else {
        final dt = DateTime.parse(iso);
        // Build a UTC instant from the components, then add 3 hours to convert
        // Uruguay-local (UTC-3) -> UTC instant = local + 3h.
        createdUtc = DateTime.utc(
          dt.year,
          dt.month,
          dt.day,
          dt.hour + 3,
          dt.minute,
          dt.second,
          dt.millisecond,
          dt.microsecond,
        );
      }

      final nowUtc = DateTime.now().toUtc();
      final diff = nowUtc.difference(createdUtc);

      // If the post is in the future or less than a minute old, show at least 1 minute.
      if (diff.isNegative || diff.inSeconds < 60) return 'hace 1m';
      if (diff.inMinutes < 60) return 'hace ${diff.inMinutes}m';
      if (diff.inHours < 24) return 'hace ${diff.inHours}h';
      if (diff.inDays < 7) return 'hace ${diff.inDays}d';

      // Older: show date in Uruguay local (dd/MM/yyyy)
      final createdUy = createdUtc.subtract(const Duration(hours: 3));
      return '${createdUy.day.toString().padLeft(2, '0')}/${createdUy.month.toString().padLeft(2, '0')}/${createdUy.year}';
    } catch (_) {
      return '';
    }
  }

  @override
  Widget build(BuildContext context) {
    const bannerHeight = 56.0;
    return Scaffold(
      body: Stack(
        children: [
          Positioned.fill(
            child: Padding(
              padding: const EdgeInsets.only(top: bannerHeight),
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
                          top: false,
                          child: SingleChildScrollView(
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.start,
                              children: [
                                const SizedBox(height: 6),
                                ..._buildSidebarButtons(context),
                              ],
                            ),
                          ),
                        ),
                      ),

                      Expanded(
                        child: Stack(
                          children: [
                            Positioned.fill(
                              child: DecoratedBox(
                                decoration: BoxDecoration(
                                  image: const DecorationImage(
                                    image: AssetImage('assets/images/bg.jpg'),
                                    fit: BoxFit.none,
                                    alignment: Alignment.topCenter,
                                  ),
                                  color: Theme.of(
                                    context,
                                  ).colorScheme.background,
                                ),
                              ),
                            ),
                            SafeArea(
                              top: false,
                              child: Container(
                                padding: const EdgeInsets.all(16),
                                child: _buildContentForIndex(),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  );
                },
              ),
            ),
          ),

          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: Material(
              elevation: 4,
              color: Theme.of(context).colorScheme.surface,
              child: Container(
                height: bannerHeight,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Stack(
                  children: [
                    Center(
                      child: Text(
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
                    ),
                    Align(
                      alignment: Alignment.centerRight,
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (_appVersion != null)
                            Padding(
                              padding: const EdgeInsets.only(right: 8.0),
                              child: Text(
                                'v${_appVersion}',
                                style: TextStyle(
                                  color: Theme.of(
                                    context,
                                  ).colorScheme.onSurface,
                                  fontSize: 11,
                                ),
                              ),
                            ),
                          IconButton(
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
                        ],
                      ),
                    ),
                  ],
                ),
              ),
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
      case 5:
        return const SettingsPage();
      case 1:
      default:
        return LayoutBuilder(
          builder: (context, constraints) {
            final width = constraints.maxWidth;
            final isDesktop = width >= 900;

            int columns = (width / 420).floor();
            if (columns < 1) columns = 1;
            if (columns > 3) columns = 3;

            Widget content;
            if (_loadingPosts) {
              content = ListView(
                children: const [
                  SizedBox(height: 24),
                  Center(child: CircularProgressIndicator()),
                  SizedBox(height: 24),
                ],
              );
            } else if (_posts.isEmpty) {
              content = ListView(
                children: const [
                  Padding(
                    padding: EdgeInsets.all(16),
                    child: Text('No hay publicaciones aún.'),
                  ),
                ],
              );
            } else if (isDesktop) {
              content = GridView.builder(
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: columns,
                  mainAxisSpacing: 12,
                  crossAxisSpacing: 12,
                  childAspectRatio: 0.95,
                ),
                itemCount: _posts.length,
                itemBuilder: (context, index) {
                  final post = _posts[index];
                  final author = _postAuthor(post);
                  final time = _formatPostTime(post['created_at'] as String?);
                  return Card(
                    margin: EdgeInsets.zero,
                    elevation: 2,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (post['image_url'] != null)
                          Expanded(
                            child: ClipRRect(
                              borderRadius: const BorderRadius.vertical(
                                top: Radius.circular(12),
                              ),
                              child: Image.network(
                                post['image_url'] as String,
                                width: double.infinity,
                                fit: BoxFit.cover,
                              ),
                            ),
                          ),
                        Padding(
                          padding: const EdgeInsets.all(12.0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    author,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 13,
                                    ),
                                  ),
                                  Text(
                                    time,
                                    style: const TextStyle(
                                      fontSize: 11,
                                      color: Colors.black54,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              Text(post['description'] ?? ''),
                              const SizedBox(height: 8),
                              Builder(
                                builder: (ctx) {
                                  final cs = Theme.of(ctx).colorScheme;
                                  return Text(
                                    '${author} · ${_timeAgoUruguay(post['created_at'] as String?)}',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: cs.onSurfaceVariant,
                                    ),
                                  );
                                },
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  );
                },
              );
            } else {
              content = ListView.builder(
                itemCount: _posts.length,
                itemBuilder: (context, index) {
                  final post = _posts[index];
                  final author = _postAuthor(post);
                  final time = _formatPostTime(post['created_at'] as String?);
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
                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    author,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 13,
                                    ),
                                  ),
                                  Text(
                                    time,
                                    style: const TextStyle(
                                      fontSize: 11,
                                      color: Colors.black54,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              Text(post['description'] ?? ''),
                              const SizedBox(height: 8),
                              Builder(
                                builder: (ctx) {
                                  final cs = Theme.of(ctx).colorScheme;
                                  return Text(
                                    '${author} · ${_timeAgoUruguay(post['created_at'] as String?)}',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: cs.onSurfaceVariant,
                                    ),
                                  );
                                },
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  );
                },
              );
            }

            return RefreshIndicator(onRefresh: _loadPosts, child: content);
          },
        );
    }
  }

  List<Widget> _buildSidebarButtons(BuildContext context) {
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
      {
        'icon': Icons.settings,
        'tooltip': 'Ajustes',
        'action': () {
          setState(() {
            _selectedIndex = 5;
          });
        },
      },
    ];

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
                      return Icon(
                        it['icon'] as IconData,
                        size: 28,
                        color: active
                            ? Theme.of(context).colorScheme.primary
                            : Theme.of(context).colorScheme.onSurface,
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

  void _onPostsChanged() {
    _loadPosts();
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
        SelectedImageStore.instance.setImage(file.bytes!, file.name);
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Imagen seleccionada (no se guarda en el servidor)'),
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error al seleccionar imagen: $e')),
      );
    }
  }

  @override
  void dispose() {
    if (_postsListener != null) {
      SelectedImageStore.instance.postsVersion.removeListener(_postsListener!);
    }
    super.dispose();
  }
}
