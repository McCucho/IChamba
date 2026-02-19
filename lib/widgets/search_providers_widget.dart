import 'dart:async';
import 'package:flutter/material.dart';
import '../services/supabase_service.dart';
import '../public_profile_page.dart';

/// A search widget that displays in the sidebar, allowing users
/// to search for ofrecedores and navigate to their public profile.
class SearchProvidersWidget extends StatefulWidget {
  /// Callback invoked when a provider is selected, passing the widget
  /// that should be displayed in the main content area.
  final void Function(Widget page) onProviderSelected;

  const SearchProvidersWidget({super.key, required this.onProviderSelected});

  @override
  State<SearchProvidersWidget> createState() => _SearchProvidersWidgetState();
}

class _SearchProvidersWidgetState extends State<SearchProvidersWidget> {
  final _searchController = TextEditingController();
  List<Map<String, dynamic>> _results = [];
  bool _loading = false;
  bool _expanded = false;
  Timer? _debounce;

  @override
  void dispose() {
    _searchController.dispose();
    _debounce?.cancel();
    super.dispose();
  }

  void _onSearchChanged(String query) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 400), () {
      _performSearch(query);
    });
  }

  Future<void> _performSearch(String query) async {
    setState(() => _loading = true);
    try {
      final results = await SupabaseService.searchOfrecedores(query);
      if (!mounted) return;
      setState(() => _results = results);
    } catch (e) {
      debugPrint('Search error: $e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Search header/toggle
        InkWell(
          onTap: () {
            setState(() {
              _expanded = !_expanded;
              if (_expanded && _results.isEmpty) {
                _performSearch('');
              }
            });
          },
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
            child: Row(
              children: [
                Icon(Icons.search, size: 20, color: cs.onSurface),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    'Buscar ofrecedores',
                    style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                Icon(
                  _expanded ? Icons.expand_less : Icons.expand_more,
                  size: 18,
                  color: cs.onSurfaceVariant,
                ),
              ],
            ),
          ),
        ),

        if (_expanded) ...[
          // Search input
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: SizedBox(
              height: 36,
              child: TextField(
                controller: _searchController,
                onChanged: _onSearchChanged,
                style: const TextStyle(fontSize: 13),
                decoration: InputDecoration(
                  hintText: 'Nombre...',
                  hintStyle: const TextStyle(fontSize: 12),
                  isDense: true,
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 8,
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide(color: cs.outline),
                  ),
                  suffixIcon: _searchController.text.isNotEmpty
                      ? GestureDetector(
                          onTap: () {
                            _searchController.clear();
                            _performSearch('');
                          },
                          child: const Icon(Icons.clear, size: 16),
                        )
                      : null,
                ),
              ),
            ),
          ),
          const SizedBox(height: 4),

          // Results
          if (_loading)
            const Padding(
              padding: EdgeInsets.all(12),
              child: SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            )
          else if (_results.isEmpty)
            Padding(
              padding: const EdgeInsets.all(12),
              child: Text(
                'Sin resultados',
                style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant),
              ),
            )
          else
            ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 200),
              child: ListView.builder(
                shrinkWrap: true,
                padding: EdgeInsets.zero,
                itemCount: _results.length,
                itemBuilder: (context, index) {
                  final user = _results[index];
                  final name =
                      '${user['first_name'] ?? ''} ${user['last_name'] ?? ''}'
                          .trim();
                  final avatarUrl = user['avatar_url'] as String?;
                  final authId = user['auth_id']?.toString() ?? '';

                  return ListTile(
                    dense: true,
                    visualDensity: VisualDensity.compact,
                    leading: CircleAvatar(
                      radius: 14,
                      backgroundColor: cs.primaryContainer,
                      backgroundImage: avatarUrl != null && avatarUrl.isNotEmpty
                          ? NetworkImage(avatarUrl)
                          : null,
                      child: avatarUrl == null || avatarUrl.isEmpty
                          ? Icon(
                              Icons.person,
                              size: 14,
                              color: cs.onPrimaryContainer,
                            )
                          : null,
                    ),
                    title: Text(
                      name.isNotEmpty ? name : 'Sin nombre',
                      style: const TextStyle(fontSize: 12),
                      overflow: TextOverflow.ellipsis,
                    ),
                    onTap: () {
                      if (authId.isNotEmpty) {
                        widget.onProviderSelected(
                          PublicProfilePage(userId: authId),
                        );
                      }
                    },
                  );
                },
              ),
            ),
        ],
      ],
    );
  }
}
