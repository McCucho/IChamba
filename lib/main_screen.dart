import 'package:flutter/material.dart';
import 'dart:typed_data';
import 'dart:async';
import 'services/supabase_service.dart';
import 'services/selected_image_store.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'profile_page.dart';
import 'publish_page.dart';
import 'messages_page.dart';
import 'settings_page.dart';
import 'public_profile_page.dart';
import 'post_detail_page.dart';
import 'widgets/search_providers_widget.dart';

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
  int _unreadMessages = 0;
  dynamic _messagesChannel;
  Timer? _pollTimer;
  Widget?
  _publicProfilePage; // holds a PublicProfilePage when navigating to one

  @override
  void initState() {
    super.initState();
    _loadPosts();
    _postsListener = _onPostsChanged;
    SelectedImageStore.instance.postsVersion.addListener(_postsListener!);
    _loadAppVersion();
    _loadUnreadMessages();
    _subscribeUnreadMessages();
    // Poll every 1 minute as a fallback in case Realtime isn't available.
    _pollTimer = Timer.periodic(const Duration(minutes: 1), (_) {
      _loadUnreadMessages();
    });
  }

  void _subscribeUnreadMessages() {
    try {
      final client = SupabaseService.client;
      _messagesChannel = client.channel('public:messages');
      try {
        // subscribe without static type references to avoid analyzer issues
        (_messagesChannel as dynamic).subscribe();
      } catch (_) {
        // ignore if subscribe fails at runtime
      }
    } catch (_) {
      // ignore if realtime not available
    }
  }

  Future<void> _loadUnreadMessages() async {
    try {
      final convos = await SupabaseService.fetchConversationsList();
      var total = 0;
      for (final c in convos) {
        total += (c['unread'] as int?) ?? 0;
      }
      if (!mounted) return;
      setState(() => _unreadMessages = total);
    } catch (_) {
      // ignore
    }
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
            p['author_avatar_url'] = userMap[uid]?['avatar_url'];
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
      // Parse to UTC instant, treating no-offset timestamps as Uruguay local (UTC-3)
      DateTime _parseIsoToUtc(String isoStr) {
        final tzOffsetPattern = RegExp(r'Z|[+-]\d{2}:?\d{2}\$');
        if (tzOffsetPattern.hasMatch(isoStr))
          return DateTime.parse(isoStr).toUtc();
        final m = RegExp(
          r"^(\d{4})-(\d{2})-(\d{2})[T ](\d{2}):(\d{2})(?::(\d{2})(?:\.(\d+))?)?\$",
        ).firstMatch(isoStr);
        if (m != null) {
          final y = int.parse(m.group(1)!);
          final mo = int.parse(m.group(2)!);
          final d = int.parse(m.group(3)!);
          final h = int.parse(m.group(4)!);
          final mi = int.parse(m.group(5)!);
          final s = m.group(6) != null ? int.parse(m.group(6)!) : 0;
          final ms = m.group(7) != null
              ? int.parse((m.group(7)!.padRight(3, '0')).substring(0, 3))
              : 0;
          return DateTime.utc(y, mo, d, h + 3, mi, s, ms);
        }
        return DateTime.parse(isoStr).toUtc();
      }

      final createdUtc = _parseIsoToUtc(iso);
      final uy = createdUtc.subtract(const Duration(hours: 3));
      final nowUy = DateTime.now().toUtc().subtract(const Duration(hours: 3));
      if (uy.year == nowUy.year &&
          uy.month == nowUy.month &&
          uy.day == nowUy.day) {
        return '${uy.hour.toString().padLeft(2, '0')}:${uy.minute.toString().padLeft(2, '0')}';
      }
      return '${uy.day}/${uy.month} ${uy.hour.toString().padLeft(2, '0')}:${uy.minute.toString().padLeft(2, '0')}';
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
      DateTime _parseIsoToUtc(String isoStr) {
        final tzOffsetPattern = RegExp(r'Z|[+-]\d{2}:?\d{2}\$');
        if (tzOffsetPattern.hasMatch(isoStr))
          return DateTime.parse(isoStr).toUtc();
        final m = RegExp(
          r"^(\d{4})-(\d{2})-(\d{2})[T ](\d{2}):(\d{2})(?::(\d{2})(?:\.(\d+))?)?\$",
        ).firstMatch(isoStr);
        if (m != null) {
          final y = int.parse(m.group(1)!);
          final mo = int.parse(m.group(2)!);
          final d = int.parse(m.group(3)!);
          final h = int.parse(m.group(4)!);
          final mi = int.parse(m.group(5)!);
          final s = m.group(6) != null ? int.parse(m.group(6)!) : 0;
          final ms = m.group(7) != null
              ? int.parse((m.group(7)!.padRight(3, '0')).substring(0, 3))
              : 0;
          return DateTime.utc(y, mo, d, h + 3, mi, s, ms);
        }
        return DateTime.parse(isoStr).toUtc();
      }

      final createdUtc = _parseIsoToUtc(iso);

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
                        color: Theme.of(
                          context,
                        ).colorScheme.surfaceContainerHighest,
                        child: SafeArea(
                          top: false,
                          child: SingleChildScrollView(
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.start,
                              children: [
                                const SizedBox(height: 6),
                                ..._buildSidebarButtons(context),
                                const SizedBox(height: 12),
                                const Divider(indent: 8, endIndent: 8),
                                SearchProvidersWidget(
                                  onProviderSelected: (page) {
                                    setState(() {
                                      _publicProfilePage = page;
                                      _selectedIndex = 6; // public profile
                                    });
                                  },
                                ),
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
                                  color: Theme.of(context).colorScheme.surface,
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
                              color: Theme.of(context).colorScheme.primary
                                  .withAlpha((0.15 * 255).round()),
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

  Widget _buildContentForIndex() {
    switch (_selectedIndex) {
      case 0:
        return const ProfilePage();
      case 3:
        return const PublishPage();
      case 4:
        return MessagesPage(onNavigateToProfile: _navigateToPublicProfile);
      case 5:
        return const SettingsPage();
      case 6:
        return _publicProfilePage ??
            const Center(child: Text('Perfil no encontrado'));
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
                  final postUserId = post['user_id']?.toString();
                  final time = _formatPostTime(post['created_at'] as String?);
                  return Card(
                    margin: EdgeInsets.zero,
                    elevation: 2,
                    clipBehavior: Clip.antiAlias,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: InkWell(
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => PostDetailPage(
                            post: post,
                            authorName: author,
                            authorAvatarUrl:
                                post['author_avatar_url'] as String?,
                          ),
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (post['image_url'] != null)
                            Expanded(
                              child: Stack(
                                fit: StackFit.expand,
                                children: [
                                  Image.network(
                                    post['image_url'] as String,
                                    width: double.infinity,
                                    fit: BoxFit.cover,
                                  ),
                                  Positioned(
                                    top: 8,
                                    right: 8,
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 8,
                                        vertical: 4,
                                      ),
                                      decoration: BoxDecoration(
                                        color: Colors.black54,
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: const Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Icon(
                                            Icons.open_in_full,
                                            size: 13,
                                            color: Colors.white,
                                          ),
                                          SizedBox(width: 4),
                                          Text(
                                            'Ver detalle',
                                            style: TextStyle(
                                              color: Colors.white,
                                              fontSize: 11,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ],
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
                                    GestureDetector(
                                      onTap: postUserId != null
                                          ? () => _navigateToPublicProfile(
                                              postUserId,
                                            )
                                          : null,
                                      child: Text(
                                        author,
                                        style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 13,
                                          color: postUserId != null
                                              ? Theme.of(
                                                  context,
                                                ).colorScheme.primary
                                              : null,
                                          decoration: postUserId != null
                                              ? TextDecoration.underline
                                              : null,
                                        ),
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
                                Text(
                                  post['description'] ?? '',
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
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
                  final postUserId = post['user_id']?.toString();
                  final time = _formatPostTime(post['created_at'] as String?);
                  return Card(
                    margin: const EdgeInsets.symmetric(vertical: 8),
                    elevation: 2,
                    clipBehavior: Clip.antiAlias,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: InkWell(
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => PostDetailPage(
                            post: post,
                            authorName: author,
                            authorAvatarUrl:
                                post['author_avatar_url'] as String?,
                          ),
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (post['image_url'] != null)
                            Stack(
                              children: [
                                Image.network(
                                  post['image_url'] as String,
                                  width: double.infinity,
                                  height: 220,
                                  fit: BoxFit.cover,
                                ),
                                Positioned(
                                  top: 8,
                                  right: 8,
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 8,
                                      vertical: 4,
                                    ),
                                    decoration: BoxDecoration(
                                      color: Colors.black54,
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: const Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(
                                          Icons.open_in_full,
                                          size: 13,
                                          color: Colors.white,
                                        ),
                                        SizedBox(width: 4),
                                        Text(
                                          'Ver detalle',
                                          style: TextStyle(
                                            color: Colors.white,
                                            fontSize: 11,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ],
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
                                    GestureDetector(
                                      onTap: postUserId != null
                                          ? () => _navigateToPublicProfile(
                                              postUserId,
                                            )
                                          : null,
                                      child: Text(
                                        author,
                                        style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 13,
                                          color: postUserId != null
                                              ? Theme.of(
                                                  context,
                                                ).colorScheme.primary
                                              : null,
                                          decoration: postUserId != null
                                              ? TextDecoration.underline
                                              : null,
                                        ),
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
                                Text(
                                  post['description'] ?? '',
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                const SizedBox(height: 4),
                                Builder(
                                  builder: (ctx) {
                                    final cs = Theme.of(ctx).colorScheme;
                                    return Text(
                                      _timeAgoUruguay(
                                        post['created_at'] as String?,
                                      ),
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

  void _navigateToPublicProfile(String userId) {
    setState(() {
      _publicProfilePage = PublicProfilePage(userId: userId);
      _selectedIndex = 6;
    });
  }

  List<Widget> _buildSidebarButtons(BuildContext context) {
    final items = [
      {
        'icon': Icons.person,
        'tooltip': 'Mi perfil público',
        'action': () {
          final uid = SupabaseService.currentUser()?.id;
          if (uid != null) {
            _navigateToPublicProfile(uid);
          }
        },
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
                  ? Theme.of(
                      context,
                    ).colorScheme.primary.withAlpha((0.08 * 255).round())
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
                else if (idx == 4)
                  // Messages icon with unread badge
                  Stack(
                    clipBehavior: Clip.none,
                    children: [
                      Icon(
                        it['icon'] as IconData,
                        size: 28,
                        color: active
                            ? Theme.of(context).colorScheme.primary
                            : Theme.of(context).colorScheme.onSurface,
                      ),
                      if (_unreadMessages > 0)
                        Positioned(
                          right: -6,
                          top: -6,
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: Theme.of(context).colorScheme.primary,
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Text(
                              _unreadMessages > 99 ? '99+' : '$_unreadMessages',
                              style: TextStyle(
                                color: Theme.of(context).colorScheme.onPrimary,
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ),
                    ],
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

  void _onPostsChanged() {
    _loadPosts();
  }

  @override
  void dispose() {
    if (_postsListener != null) {
      SelectedImageStore.instance.postsVersion.removeListener(_postsListener!);
    }
    try {
      // cancel polling timer
      try {
        _pollTimer?.cancel();
        _pollTimer = null;
      } catch (_) {}

      if (_messagesChannel != null) {
        SupabaseService.client.removeChannel(_messagesChannel!);
        _messagesChannel = null;
      }
    } catch (_) {}
    super.dispose();
  }
}
