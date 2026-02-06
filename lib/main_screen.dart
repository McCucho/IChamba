import 'package:flutter/material.dart';
import 'package:ichamba/services/supabase_service.dart';

class MainScreen extends StatelessWidget {
  const MainScreen({super.key, required this.isAuthenticated});

  final bool isAuthenticated;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Ichamba'),
        actions: [
          if (isAuthenticated)
            IconButton(
              tooltip: 'Salir',
              onPressed: () async {
                await SupabaseService.signOut();
                if (!context.mounted) return;
                Navigator.pushNamedAndRemoveUntil(
                  context,
                  '/',
                  (route) => false,
                );
              },
              icon: const Icon(Icons.logout),
            ),
        ],
      ),
      body: LayoutBuilder(
        builder: (context, constraints) {
          final sidebarWidth = constraints.maxWidth * 0.25;
          return Stack(
            children: [
              Row(
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
              ),
              if (!isAuthenticated)
                Positioned.fill(
                  child: Container(
                    color: Colors.white.withOpacity(0.85),
                    alignment: Alignment.center,
                    child: _AuthPrompt(),
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

class _AuthPrompt extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 3,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Inicia sesion para continuar',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () => Navigator.pushNamed(context, '/login'),
              child: const Text('Iniciar sesion'),
            ),
            const SizedBox(height: 8),
            OutlinedButton(
              onPressed: () => Navigator.pushNamed(context, '/register'),
              child: const Text('Registrarse'),
            ),
          ],
        ),
      ),
    );
  }
}
