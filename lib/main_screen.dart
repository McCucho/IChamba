import 'package:flutter/material.dart';
import 'package:ichamba/services/supabase_service.dart';

class MainScreen extends StatelessWidget {
  const MainScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Ichamba v20260206-3'),
        actions: [
          IconButton(
            tooltip: 'Salir',
            onPressed: () async {
              await SupabaseService.signOut();
              if (!context.mounted) return;
              Navigator.pushNamedAndRemoveUntil(context, '/', (route) => false);
            },
            icon: const Icon(Icons.logout),
          ),
        ],
      ),
      body: LayoutBuilder(
        builder: (context, constraints) {
          final sidebarWidth = constraints.maxWidth * 0.25;
          return Row(
            children: [
              SizedBox(
                width: sidebarWidth,
                child: Container(
                  color: const Color(0xFFEFF2F5),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: _buildSidebarButtons(context),
                  ),
                ),
              ),
              Expanded(
                child: Container(
                  color: Colors.white,
                  child: ListView(
                    padding: const EdgeInsets.all(16),
                    children: _buildMenuItems(),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  List<Widget> _buildSidebarButtons(BuildContext context) {
    const icons = [
      Icons.home,
      Icons.search,
      Icons.notifications,
      Icons.calendar_month,
      Icons.chat_bubble_outline,
      Icons.settings,
    ];

    return icons
        .map(
          (icon) => Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: IconButton(iconSize: 28, onPressed: () {}, icon: Icon(icon)),
          ),
        )
        .toList();
  }

  List<Widget> _buildMenuItems() {
    final items = List.generate(12, (index) => 'Opcion ${index + 1}');

    return items
        .map(
          (label) => Card(
            margin: const EdgeInsets.only(bottom: 12),
            child: ListTile(
              title: Text(label),
              subtitle: const Text('Descripcion breve de la seccion.'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () {},
            ),
          ),
        )
        .toList();
  }
}
