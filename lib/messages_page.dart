import 'dart:async';
import 'package:flutter/material.dart';
import 'services/supabase_service.dart';

/// Full messaging page: conversations list + chat view (WhatsApp-style).
class MessagesPage extends StatefulWidget {
  const MessagesPage({super.key});

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
        c['partner_avatar'] = userMap[pid]?['avatar_url'];
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
          Navigator.pop(ctx);
          final partnerId = (user['auth_id'] ?? user['id']).toString();
          _openChat({
            'partner_id': partnerId,
            'partner_name':
                user['first_name'] ??
                user['email'] ??
                partnerId.substring(0, 8),
            'partner_email': user['email'] ?? '',
            'partner_avatar': user['avatar_url'],
          });
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_activePartner != null) {
      return _ChatView(
        partnerId: _activePartner!['partner_id'] as String,
        partnerName: _activePartner!['partner_name'] as String? ?? '',
        partnerAvatar: _activePartner!['partner_avatar'] as String?,
        onBack: _closeChat,
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
                        color: Theme.of(
                          context,
                        ).colorScheme.onSurfaceVariant.withOpacity(0.4),
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
                    final avatar = c['partner_avatar'] as String?;
                    return ListTile(
                      leading: CircleAvatar(
                        radius: 24,
                        backgroundImage: avatar != null && avatar.isNotEmpty
                            ? NetworkImage(avatar)
                            : null,
                        child: avatar == null || avatar.isEmpty
                            ? const Icon(Icons.person)
                            : null,
                      ),
                      title: Text(
                        c['partner_name'] as String? ?? '',
                        style: TextStyle(
                          fontWeight: unread > 0
                              ? FontWeight.bold
                              : FontWeight.normal,
                        ),
                      ),
                      subtitle: Text(
                        c['last_message'] as String? ?? '',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: unread > 0
                              ? Theme.of(context).colorScheme.onSurface
                              : Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                      ),
                      trailing: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            _formatTime(c['last_time'] as String?),
                            style: TextStyle(
                              fontSize: 11,
                              color: unread > 0
                                  ? Theme.of(context).colorScheme.primary
                                  : Theme.of(
                                      context,
                                    ).colorScheme.onSurfaceVariant,
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
                                color: Theme.of(context).colorScheme.primary,
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Text(
                                '$unread',
                                style: TextStyle(
                                  color: Theme.of(
                                    context,
                                  ).colorScheme.onPrimary,
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                      onTap: () => _openChat(c),
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
                      final avatar = u['avatar_url'] as String?;
                      return ListTile(
                        leading: CircleAvatar(
                          backgroundImage: avatar != null && avatar.isNotEmpty
                              ? NetworkImage(avatar)
                              : null,
                          child: avatar == null || avatar.isEmpty
                              ? const Icon(Icons.person)
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
  final String? partnerAvatar;
  final VoidCallback onBack;

  const _ChatView({
    required this.partnerId,
    required this.partnerName,
    this.partnerAvatar,
    required this.onBack,
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

    return Column(
      children: [
        // Chat header
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
          decoration: BoxDecoration(color: cs.surfaceVariant.withOpacity(0.5)),
          child: Row(
            children: [
              IconButton(
                icon: const Icon(Icons.arrow_back),
                onPressed: widget.onBack,
                tooltip: 'Volver',
              ),
              CircleAvatar(
                radius: 18,
                backgroundImage:
                    widget.partnerAvatar != null &&
                        widget.partnerAvatar!.isNotEmpty
                    ? NetworkImage(widget.partnerAvatar!)
                    : null,
                child:
                    widget.partnerAvatar == null ||
                        widget.partnerAvatar!.isEmpty
                    ? const Icon(Icons.person, size: 20)
                    : null,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  widget.partnerName,
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 16,
                  ),
                  overflow: TextOverflow.ellipsis,
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
                color: Colors.black.withOpacity(0.06),
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
                      fillColor: cs.surfaceVariant.withOpacity(0.4),
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
      final dt = DateTime.parse(iso).toLocal();
      return '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
    } catch (_) {
      return '';
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final bgColor = isMe ? cs.primary : cs.surfaceVariant;
    final textColor = isMe ? cs.onPrimary : cs.onSurface;

    return Align(
      alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.65,
        ),
        margin: const EdgeInsets.symmetric(vertical: 3),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(16),
            topRight: const Radius.circular(16),
            bottomLeft: isMe
                ? const Radius.circular(16)
                : const Radius.circular(4),
            bottomRight: isMe
                ? const Radius.circular(4)
                : const Radius.circular(16),
          ),
        ),
        child: Column(
          crossAxisAlignment: isMe
              ? CrossAxisAlignment.end
              : CrossAxisAlignment.start,
          children: [
            Text(text, style: TextStyle(color: textColor, fontSize: 15)),
            const SizedBox(height: 3),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  _fmtTime(time),
                  style: TextStyle(
                    fontSize: 10,
                    color: textColor.withOpacity(0.6),
                  ),
                ),
                if (isMe) ...[
                  const SizedBox(width: 3),
                  Icon(
                    isRead ? Icons.done_all : Icons.done,
                    size: 14,
                    color: isRead
                        ? (cs.brightness == Brightness.dark
                              ? Colors.lightBlueAccent
                              : Colors.blue.shade300)
                        : textColor.withOpacity(0.5),
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
