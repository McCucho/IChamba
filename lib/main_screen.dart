import 'package:flutter/material.dart';
import 'services/supabase_service.dart';

class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  // Sidebar is permanently visible; no state fields required.

  @override
  void initState() {
    super.initState();
    // Sidebar stays visible at all times; nothing to initialize here.
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Ichamba v20260206-4'),
        actions: [
          IconButton(
            tooltip: 'Salir',
            onPressed: () async {
              await SupabaseService.signOut();
              if (!context.mounted) return;
              Navigator.pushNamedAndRemoveUntil(
                context,
                '/login',
                (route) => false,
              );
            },
            icon: const Icon(Icons.logout),
          ),
        ],
      ),
      body: LayoutBuilder(
        builder: (context, constraints) {
          final sidebarWidth = constraints.maxWidth * 0.22;

          return Row(
            children: [
              Container(
                width: sidebarWidth,
                color: const Color(0xFFEFF2F5),
                child: SafeArea(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.start,
                      children: _buildSidebarButtons(context),
                    ),
                  ),
                ),
              ),
              Expanded(
                child: Container(
                  color: Colors.white,
                  padding: const EdgeInsets.all(16),
                  child: _buildIconGrid(),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildIconGrid() {
    final items = List.generate(24, (index) => 'Opción ${index + 1}');

    return GridView.builder(
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        mainAxisSpacing: 12,
        crossAxisSpacing: 12,
        childAspectRatio: 0.9,
      ),
      itemCount: items.length,
      itemBuilder: (context, index) {
        final label = items[index];
        return Card(
          elevation: 1,
          child: InkWell(
            onTap: () {},
            child: Padding(
              padding: const EdgeInsets.all(8.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.apps, size: 36, color: Colors.blueGrey[700]),
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
  }

  List<Widget> _buildSidebarButtons(BuildContext context) {
    // Left menu: 6 icons. 1=Main menu, 2=Profile (edit user data), then others.
    final items = [
      {
        'icon': Icons.menu,
        'tooltip': 'Menú principal',
        'action': () {
          // Scroll to top / go to main section (no-op for now)
          // Could implement navigation or state change here.
        },
      },
      {
        'icon': Icons.person,
        'tooltip': 'Perfil',
        'action': () {
          Navigator.pushNamed(context, '/profile');
        },
      },
      {
        'icon': Icons.notifications,
        'tooltip': 'Notificaciones',
        'action': () {},
      },
      {'icon': Icons.calendar_month, 'tooltip': 'Calendario', 'action': () {}},
      {
        'icon': Icons.chat_bubble_outline,
        'tooltip': 'Mensajes',
        'action': () {},
      },
      {'icon': Icons.settings, 'tooltip': 'Ajustes', 'action': () {}},
    ];

    return items.map((it) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Tooltip(
          message: it['tooltip'] as String,
          child: IconButton(
            iconSize: 28,
            onPressed: it['action'] as void Function()?,
            icon: Icon(it['icon'] as IconData),
          ),
        ),
      );
    }).toList();
  }
}
