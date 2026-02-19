import 'dart:async';
import 'package:flutter/material.dart';
import 'services/supabase_service.dart';
import 'public_profile_page.dart';

// Parse an ISO-like timestamp and return the corresponding UTC instant.
// If the string contains a timezone (Z or +hh:mm/-hh:mm) we parse it normally.
// If it has no offset, we treat the timestamp as Uruguay local time (UTC-3)
// and return the UTC instant representing that local time.
DateTime _parseIsoToUtc(String iso) {
  final tzOffsetPattern = RegExp(r'Z|[+-]\d{2}:?\d{2}\$');
  if (tzOffsetPattern.hasMatch(iso)) {
    return DateTime.parse(iso).toUtc();
  }

  // Try to extract components without depending on the platform local timezone.
  final m = RegExp(
    r"^(\d{4})-(\d{2})-(\d{2})[T ](\d{2}):(\d{2})(?::(\d{2})(?:\.(\d+))?)?\$",
  ).firstMatch(iso);
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
    // The string represents Uruguay local (UTC-3). Build the UTC instant by
    // adding 3 hours to the local components.
    return DateTime.utc(y, mo, d, h + 3, mi, s, ms);
  }

  // Fallback: let DateTime.parse handle it and normalize to UTC.
  return DateTime.parse(iso).toUtc();
}

/// Full messaging page: conversations list + chat view (WhatsApp-style).
class MessagesPage extends StatefulWidget {
  final void Function(String userId)? onNavigateToProfile;

  const MessagesPage({super.key, this.onNavigateToProfile});

  @override
  State<MessagesPage> createState() => _MessagesPageState();
}

class _MessagesPageState extends State<MessagesPage> {
  List<Map<String, dynamic>> _conversations = [];
  bool _loading = true;

  // When non-null we show the chat view for this partner
  Map<String, dynamic>? _activePartner;

  @override
  void initState() {
    super.initState();
    _loadConversations();
  }

  Future<void> _loadConversations() async {
    setState(() => _loading = true);
    try {
      final convos = await SupabaseService.fetchConversationsList();
      // Enrich with user info
      final users = await SupabaseService.fetchOtherUsers();
      final userMap = <String, Map<String, dynamic>>{};
      for (final u in users) {
        final id = (u['auth_id'] ?? u['id']).toString();
        userMap[id] = u;
      }
      for (final c in convos) {
        final pid = c['partner_id'] as String;
        c['partner_email'] = userMap[pid]?['email'] ?? pid.substring(0, 8);
        c['partner_name'] =
            userMap[pid]?['first_name'] ??
            userMap[pid]?['email'] ??
            pid.substring(0, 8);
        c['partner_avatar_url'] = userMap[pid]?['avatar_url'];
        debugPrint('[Messages] Partner ${c['partner_name']} avatar_url: ${c['partner_avatar_url']}');
        // prefer an explicit "last activity" field from users table if available
        c['partner_last_activity'] =
            userMap[pid]?['last_active'] ??
            userMap[pid]?['last_seen'] ??
            userMap[pid]?['last_connection'] ??
            userMap[pid]?['last_online'] ??
            userMap[pid]?['updated_at'] ??
            c['last_time'];
      }
      if (!mounted) return;
      setState(() {
        _conversations = convos;
      });
    } catch (_) {
      // ignore
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _openChat(Map<String, dynamic> partner) {
    setState(() => _activePartner = partner);
  }

  void _navigateToProfile(String userId) {
    if (widget.onNavigateToProfile != null) {
      widget.onNavigateToProfile!(userId);
    }
  }

  void _closeChat() {
    _loadConversations(); // refresh unread counts
    setState(() => _activePartner = null);
  }

  Future<void> _showNewMessageDialog() async {
    List<Map<String, dynamic>>? users;
    try {
      users = await SupabaseService.fetchOtherUsers();
      debugPrint('[NewMessage] users loaded: ${users.length}');
    } catch (e) {
      debugPrint('[NewMessage] ERROR: $e');
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error al cargar usuarios: $e')));
      return;
    }
    if (!mounted) return;

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) => _UserPickerSheet(
        users: users!,
        onSelect: (user) {
          debugPrint('[NewMessage] users loaded: $users');
          Navigator.pop(ctx);
          final partnerId = (user['auth_id'] ?? user['id']).toString();
          _openChat({
            'partner_id': partnerId,
            'partner_name':
                user['first_name'] ??
                user['email'] ??
                partnerId.substring(0, 8),
            'partner_email': user['email'] ?? '',
            'partner_avatar_url': user['avatar_url'],
          });
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_activePartner != null) {
      final partnerLast = _activePartner!['partner_last_activity'] as String?;
      final partnerAvatar = _activePartner!['partner_avatar_url'] as String?;
      return _ChatView(
        partnerId: _activePartner!['partner_id'] as String,
        partnerName: _activePartner!['partner_name'] as String? ?? '',
        partnerAvatarUrl: partnerAvatar,
        partnerLastActivity: partnerLast,
        onBack: _closeChat,
        onNavigateToProfile: _navigateToProfile,
      );
    }

    return Column(
      children: [
        // Header
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          child: Row(
            children: [
              Text(
                'Mensajes',
                style: Theme.of(
                  context,
                ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
              ),
              const Spacer(),
              IconButton(
                icon: const Icon(Icons.edit_square),
                tooltip: 'Nuevo mensaje',
                onPressed: _showNewMessageDialog,
              ),
              IconButton(
                icon: const Icon(Icons.refresh),
                tooltip: 'Actualizar',
                onPressed: _loadConversations,
              ),
            ],
          ),
        ),
        const Divider(height: 1),
        // Conversations list
        Expanded(
          child: _loading
              ? const Center(child: CircularProgressIndicator())
              : _conversations.isEmpty
              ? Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.chat_bubble_outline,
                        size: 56,
                        color: Theme.of(context).colorScheme.onSurfaceVariant
                            .withAlpha((0.4 * 255).round()),
                      ),
                      const SizedBox(height: 12),
                      const Text('No hay conversaciones aún'),
                      const SizedBox(height: 12),
                      FilledButton.icon(
                        onPressed: _showNewMessageDialog,
                        icon: const Icon(Icons.add),
                        label: const Text('Nuevo mensaje'),
                      ),
                    ],
                  ),
                )
              : ListView.separated(
                  itemCount: _conversations.length,
                  separatorBuilder: (_, __) =>
                      const Divider(height: 1, indent: 72),
                  itemBuilder: (context, index) {
                    final c = _conversations[index];
                    final unread = (c['unread'] as int?) ?? 0;
                    final name = c['partner_name'] as String? ?? '';
                    final initial = name.isNotEmpty
                        ? name[0].toUpperCase()
                        : '';
                    final avatarUrl = c['partner_avatar_url'] as String?;
                    final cs = Theme.of(context).colorScheme;
                    final partnerLast = c['partner_last_activity'] as String?;
                    final partnerOnline = _isPartnerOnline(partnerLast);
                    return Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 6,
                      ),
                      child: Container(
                        decoration: BoxDecoration(
                          color: cs.surface,
                          borderRadius: BorderRadius.circular(24),
                        ),
                        child: ListTile(
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(24),
                          ),
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 8,
                          ),
                          leading: CircleAvatar(
                            radius: 24,
                            backgroundColor: cs.primary.withAlpha(
                              (0.08 * 255).round(),
                            ),
                            backgroundImage: avatarUrl != null && avatarUrl.isNotEmpty
                                ? NetworkImage(avatarUrl)
                                : null,
                            child: avatarUrl == null || avatarUrl.isEmpty
                                ? (initial.isNotEmpty
                                    ? Text(initial)
                                    : Icon(Icons.person, color: cs.onSurface))
                                : null,
                          ),
                          title: InkWell(
                            onTap: () {
                              final partnerId = c['partner_id'] as String?;
                              if (partnerId != null && widget.onNavigateToProfile != null) {
                                widget.onNavigateToProfile!(partnerId);
                              }
                            },
                            child: Text(
                              c['partner_name'] as String? ?? '',
                              style: TextStyle(
                                fontWeight: unread > 0
                                    ? FontWeight.bold
                                    : FontWeight.normal,
                                color: cs.onSurface,
                              ),
                            ),
                          ),
                          subtitle: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                c['last_message'] as String? ?? '',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  color: unread > 0
                                      ? cs.onSurface
                                      : cs.onSurfaceVariant,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                partnerOnline
                                    ? 'En línea'
                                    : 'Últ. actividad: ${_formatUruguayActivity(partnerLast)}',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: partnerOnline
                                      ? cs.primary
                                      : cs.onSurfaceVariant,
                                  fontWeight: partnerOnline
                                      ? FontWeight.bold
                                      : FontWeight.normal,
                                ),
                              ),
                            ],
                          ),
                          trailing: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                _formatUruguayActivity(
                                  c['last_time'] as String?,
                                ),
                                style: TextStyle(
                                  fontSize: 11,
                                  color: unread > 0
                                      ? cs.primary
                                      : cs.onSurfaceVariant,
                                ),
                              ),
                              if (unread > 0) ...[
                                const SizedBox(height: 4),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 6,
                                    vertical: 2,
                                  ),
                                  decoration: BoxDecoration(
                                    color: cs.primary,
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: Text(
                                    '$unread',
                                    style: TextStyle(
                                      color: cs.onPrimary,
                                      fontSize: 11,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                              ],
                            ],
                          ),
                          onTap: () => _openChat(c),
                        ),
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }

  String _formatTime(String? iso) {
    if (iso == null) return '';
    try {
      final dt = DateTime.parse(iso).toLocal();
      final now = DateTime.now();
      if (dt.year == now.year && dt.month == now.month && dt.day == now.day) {
        return '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
      }
      return '${dt.day}/${dt.month}';
    } catch (_) {
      return '';
    }
  }

  String _formatUruguayActivity(String? iso) {
    if (iso == null) return '';
    try {
      final createdUtc = _parseIsoToUtc(iso);
      final uy = createdUtc.subtract(const Duration(hours: 3));
      final nowUy = DateTime.now().toUtc().subtract(const Duration(hours: 3));
      if (uy.year == nowUy.year &&
          uy.month == nowUy.month &&
          uy.day == nowUy.day) {
        return '${uy.hour.toString().padLeft(2, '0')}:${uy.minute.toString().padLeft(2, '0')}';
      }
      return '${uy.day.toString().padLeft(2, '0')}/${uy.month.toString().padLeft(2, '0')} ${uy.hour.toString().padLeft(2, '0')}:${uy.minute.toString().padLeft(2, '0')}';
    } catch (_) {
      return '';
    }
  }

  bool _isPartnerOnline(String? iso, {int minutes = 5}) {
    if (iso == null) return false;
    try {
      final createdUtc = _parseIsoToUtc(iso);
      final nowUtc = DateTime.now().toUtc();
      final diff = nowUtc.difference(createdUtc);
      return !diff.isNegative && diff.inMinutes < minutes;
    } catch (_) {
      return false;
    }
  }
}

// ── User picker bottom sheet ─────────────────────────────────────────

class _UserPickerSheet extends StatefulWidget {
  final List<Map<String, dynamic>> users;
  final void Function(Map<String, dynamic>) onSelect;

  const _UserPickerSheet({required this.users, required this.onSelect});

  @override
  State<_UserPickerSheet> createState() => _UserPickerSheetState();
}

class _UserPickerSheetState extends State<_UserPickerSheet> {
  String _filter = '';

  @override
  Widget build(BuildContext context) {
    final filtered = widget.users.where((u) {
      final name = (u['first_name'] ?? '').toString().toLowerCase();
      final email = (u['email'] ?? '').toString().toLowerCase();
      return name.contains(_filter) || email.contains(_filter);
    }).toList();

    return DraggableScrollableSheet(
      initialChildSize: 0.6,
      minChildSize: 0.3,
      maxChildSize: 0.9,
      expand: false,
      builder: (context, scrollController) => Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(12),
            child: TextField(
              autofocus: true,
              decoration: InputDecoration(
                hintText: 'Buscar usuario...',
                prefixIcon: const Icon(Icons.search),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                isDense: true,
              ),
              onChanged: (v) => setState(() => _filter = v.toLowerCase()),
            ),
          ),
          Expanded(
            child: filtered.isEmpty
                ? Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Text(
                        _filter.isEmpty
                            ? 'No hay otros usuarios registrados'
                            : 'No se encontraron usuarios con "$_filter"',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ),
                  )
                : ListView.builder(
                    controller: scrollController,
                    itemCount: filtered.length,
                    itemBuilder: (context, i) {
                      final u = filtered[i];
                      final name = (u['first_name'] ?? u['email'] ?? '')
                          .toString();
                      final initial = name.isNotEmpty
                          ? name[0].toUpperCase()
                          : '';
                      final avatarUrl = u['avatar_url'] as String?;
                      return ListTile(
                        leading: CircleAvatar(
                          backgroundImage: avatarUrl != null && avatarUrl.isNotEmpty
                              ? NetworkImage(avatarUrl)
                              : null,
                          child: avatarUrl == null || avatarUrl.isEmpty
                              ? (initial.isNotEmpty
                                  ? Text(initial)
                                  : const Icon(Icons.person))
                              : null,
                        ),
                        title: Text(u['first_name'] ?? u['email'] ?? ''),
                        subtitle: Text(u['email'] ?? ''),
                        onTap: () => widget.onSelect(u),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}

// ── Chat view (WhatsApp-style bubbles) ──────────────────────────────

class _ChatView extends StatefulWidget {
  final String partnerId;
  final String partnerName;
  final String? partnerAvatarUrl;
  final String? partnerLastActivity;
  final VoidCallback onBack;
  final void Function(String userId)? onNavigateToProfile;

  const _ChatView({
    required this.partnerId,
    required this.partnerName,
    this.partnerAvatarUrl,
    this.partnerLastActivity,
    required this.onBack,
    this.onNavigateToProfile,
  });

  @override
  State<_ChatView> createState() => _ChatViewState();
}

class _ChatViewState extends State<_ChatView> {
  final _msgController = TextEditingController();
  final _scrollController = ScrollController();
  List<Map<String, dynamic>> _messages = [];
  bool _loading = true;
  bool _sending = false;
  Timer? _pollTimer;

  String get _myId => SupabaseService.currentUser()?.id ?? '';

  @override
  void initState() {
    super.initState();
    _loadMessages();
    // Poll for new messages every 3 seconds
    _pollTimer = Timer.periodic(const Duration(seconds: 3), (_) {
      _loadMessages(silent: true);
    });
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    _msgController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _loadMessages({bool silent = false}) async {
    if (!silent) setState(() => _loading = true);
    try {
      final msgs = await SupabaseService.fetchConversation(widget.partnerId);
      await SupabaseService.markConversationRead(widget.partnerId);
      if (!mounted) return;
      final hadMessages = _messages.length;
      setState(() => _messages = msgs);
      if (msgs.length != hadMessages) {
        _scrollToBottom();
      }
    } catch (_) {
      // ignore
    } finally {
      if (mounted && !silent) setState(() => _loading = false);
    }
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOut,
        );
      }
    });
  }

  Future<void> _send() async {
    final text = _msgController.text.trim();
    if (text.isEmpty) return;
    setState(() => _sending = true);
    try {
      await SupabaseService.sendMessage(
        receiverId: widget.partnerId,
        content: text,
      );
      _msgController.clear();
      await _loadMessages(silent: true);
      _scrollToBottom();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error al enviar: $e')));
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    String _formatUruguayActivityLocal(String? iso) {
      if (iso == null) return '';
      try {
        final tzOffsetPattern = RegExp(r'Z|[+-]\d{2}:?\d{2}\$');
        DateTime createdUtc;
        if (tzOffsetPattern.hasMatch(iso)) {
          createdUtc = DateTime.parse(iso).toUtc();
        } else {
          final dt = DateTime.parse(iso);
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
        final uy = createdUtc.subtract(const Duration(hours: 3));
        return '${uy.hour.toString().padLeft(2, '0')}:${uy.minute.toString().padLeft(2, '0')}';
      } catch (_) {
        return '';
      }
    }

    bool _isOnlineLocal(String? iso, {int minutes = 5}) {
      if (iso == null) return false;
      try {
        final tzOffsetPattern = RegExp(r'Z|[+-]\d{2}:?\d{2}\$');
        DateTime createdUtc;
        if (tzOffsetPattern.hasMatch(iso)) {
          createdUtc = DateTime.parse(iso).toUtc();
        } else {
          final dt = DateTime.parse(iso);
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
        return !diff.isNegative && diff.inMinutes < minutes;
      } catch (_) {
        return false;
      }
    }

    final partnerLast = widget.partnerLastActivity;
    final partnerOnline = _isOnlineLocal(partnerLast);

    return Column(
      children: [
        // Chat header
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
          decoration: BoxDecoration(
            color: cs.surfaceContainerHighest.withAlpha((0.5 * 255).round()),
          ),
          child: Row(
            children: [
              IconButton(
                icon: const Icon(Icons.arrow_back),
                onPressed: widget.onBack,
                tooltip: 'Volver',
              ),
              CircleAvatar(
                radius: 18,
                backgroundImage: widget.partnerAvatarUrl != null && widget.partnerAvatarUrl!.isNotEmpty
                    ? NetworkImage(widget.partnerAvatarUrl!)
                    : null,
                child: widget.partnerAvatarUrl == null || widget.partnerAvatarUrl!.isEmpty
                    ? (widget.partnerName.isNotEmpty
                        ? Text(widget.partnerName[0].toUpperCase())
                        : const Icon(Icons.person, size: 20))
                    : null,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: InkWell(
                  onTap: () {
                    if (widget.onNavigateToProfile != null) {
                      widget.onNavigateToProfile!(widget.partnerId);
                    }
                  },
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.partnerName,
                        style: const TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 16,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        partnerOnline
                            ? 'En línea'
                            : 'Últ. conexión: ${_formatUruguayActivityLocal(partnerLast)}',
                        style: TextStyle(
                          fontSize: 12,
                          color: partnerOnline ? cs.primary : cs.onSurfaceVariant,
                          fontWeight: partnerOnline
                              ? FontWeight.bold
                              : FontWeight.normal,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),

        // Messages area
        Expanded(
          child: _loading
              ? const Center(child: CircularProgressIndicator())
              : _messages.isEmpty
              ? const Center(child: Text('Envía el primer mensaje'))
              : ListView.builder(
                  controller: _scrollController,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                  itemCount: _messages.length,
                  itemBuilder: (context, index) {
                    final m = _messages[index];
                    final isMe = m['sender_id'] == _myId;
                    return _ChatBubble(
                      text: m['content'] as String? ?? '',
                      time: m['created_at'] as String? ?? '',
                      isMe: isMe,
                      isRead: m['read'] == true,
                    );
                  },
                ),
        ),

        // Input bar
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
          decoration: BoxDecoration(
            color: cs.surface,
            boxShadow: [
              BoxShadow(
                color: Colors.black.withAlpha((0.06 * 255).round()),
                blurRadius: 4,
                offset: const Offset(0, -1),
              ),
            ],
          ),
          child: SafeArea(
            top: false,
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _msgController,
                    textInputAction: TextInputAction.send,
                    onSubmitted: (_) => _send(),
                    decoration: InputDecoration(
                      hintText: 'Escribe un mensaje...',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(24),
                        borderSide: BorderSide.none,
                      ),
                      filled: true,
                      fillColor: cs.surfaceContainerHighest.withAlpha(
                        (0.4 * 255).round(),
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 10,
                      ),
                      isDense: true,
                    ),
                    maxLines: null,
                  ),
                ),
                const SizedBox(width: 6),
                _sending
                    ? const SizedBox(
                        width: 40,
                        height: 40,
                        child: Padding(
                          padding: EdgeInsets.all(8),
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                      )
                    : IconButton(
                        icon: Icon(Icons.send, color: cs.primary),
                        onPressed: _send,
                        tooltip: 'Enviar',
                      ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

// ── Chat bubble widget ──────────────────────────────────────────────

class _ChatBubble extends StatelessWidget {
  final String text;
  final String time;
  final bool isMe;
  final bool isRead;

  const _ChatBubble({
    required this.text,
    required this.time,
    required this.isMe,
    this.isRead = false,
  });

  String _fmtTime(String iso) {
    try {
      final createdUtc = _parseIsoToUtc(iso);
      final uy = createdUtc.subtract(const Duration(hours: 3));
      return '${uy.hour.toString().padLeft(2, '0')}:${uy.minute.toString().padLeft(2, '0')}';
    } catch (_) {
      return '';
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final bgColor = isMe ? cs.primary : cs.surface;
    final textColor = isMe ? cs.onPrimary : cs.onSurface;

    return Align(
      alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.75,
        ),
        margin: const EdgeInsets.symmetric(vertical: 6, horizontal: 4),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            if (!isMe)
              BoxShadow(
                color: Colors.black.withAlpha((0.03 * 255).round()),
                blurRadius: 4,
                offset: const Offset(0, 1),
              ),
          ],
        ),
        child: Column(
          crossAxisAlignment: isMe
              ? CrossAxisAlignment.end
              : CrossAxisAlignment.start,
          children: [
            Text(text, style: TextStyle(color: textColor, fontSize: 15)),
            const SizedBox(height: 6),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  _fmtTime(time),
                  style: TextStyle(
                    fontSize: 10,
                    color: textColor.withAlpha((0.6 * 255).round()),
                  ),
                ),
                if (isMe) ...[
                  const SizedBox(width: 6),
                  Icon(
                    isRead ? Icons.done_all : Icons.done,
                    size: 14,
                    color: isRead
                        ? (cs.brightness == Brightness.dark
                              ? Colors.lightBlueAccent
                              : Colors.blue.shade300)
                        : textColor.withAlpha((0.6 * 255).round()),
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }
}
