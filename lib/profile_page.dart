import 'package:flutter/material.dart';
import 'services/supabase_service.dart';
import 'services/credentials_store.dart';
import 'route_observer.dart'; // <--- added

class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key});

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> with RouteAware { // <--- changed
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _lastNameController = TextEditingController();
  final _emailController = TextEditingController();
  final _phoneController = TextEditingController();
  final _cityController = TextEditingController();
  final _neighborhoodController = TextEditingController();
  bool _loading = false;

  String _role = 'usuario';
  String? _roleRequest;

  @override
  void initState() {
    super.initState();
    _loadProfile(); // <--- use centralized loader
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // subscribe to route changes
    final modal = ModalRoute.of(context);
    if (modal != null) routeObserver.subscribe(this, modal);
  }

  @override
  void dispose() {
    routeObserver.unsubscribe(this); // <--- unsubscribe
    _nameController.dispose();
    _lastNameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _cityController.dispose();
    _neighborhoodController.dispose();
    super.dispose();
  }

  // Called when page is pushed onto the navigator.
  @override
  void didPush() {
    _loadProfile();
  }

  // Called when coming back to this route (e.g. after pushing another route and popping it).
  @override
  void didPopNext() {
    _loadProfile();
  }

  Future<void> _loadProfile() async {
    if (!mounted) return;
    setState(() => _loading = true);
    try {
      await SupabaseService.waitForInitialAuth().catchError((_) => null);

      final current = SupabaseService.currentUser();
      
      if (current == null) {
        debugPrint('⚠️ No hay usuario autenticado');
        return;
      }

      debugPrint('✅ Usuario encontrado: ${current.id}');

      // Fetch profile directly from users table
      final row = await SupabaseService.fetchUserProfile();
      
      if (!mounted) return;
      
      if (row != null) {
        debugPrint('✅ Datos cargados desde tabla users');
        debugPrint('📋 Datos completos: $row');
        setState(() {
          _nameController.text = row['first_name'] ?? '';
          _lastNameController.text = row['last_name'] ?? '';
          _emailController.text = row['email'] ?? current.email ?? '';
          _phoneController.text = row['phone'] ?? '';
          _cityController.text = row['city'] ?? '';
          _neighborhoodController.text = row['neighborhood'] ?? '';
          _role = row['role'] ?? 'usuario';
          _roleRequest = row['role_request'];
        });
      } else {
        debugPrint('⚠️ No existe perfil en tabla users, creando uno nuevo...');
        // Create initial profile
        await SupabaseService.upsertUser({
          'auth_id': current.id,
          'email': current.email ?? '',
          'first_name': '',
          'last_name': '',
          'phone': '',
          'city': '',
          'neighborhood': '',
          'role': 'usuario',
          'role_request': null,
        });
        
        if (!mounted) return;
        setState(() {
          _emailController.text = current.email ?? '';
          _role = 'usuario';
        });
        
        debugPrint('✅ Perfil inicial creado');
      }
    } catch (e, stack) {
      debugPrint('❌ Error en _loadProfile: $e');
      debugPrint('Stack: $stack');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error al cargar perfil: $e')),
      );
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _loading = true);
    try {
      final current = SupabaseService.currentUser();
      final data = <String, dynamic>{
        'first_name': _nameController.text.trim(),
        'last_name': _lastNameController.text.trim(),
        'email': _emailController.text.trim(),
        'phone': _phoneController.text.trim(),
        'city': _cityController.text.trim(),
        'neighborhood': _neighborhoodController.text.trim(),
      };
      if (current?.id != null) data['auth_id'] = current!.id;

      await SupabaseService.upsertUser(data);
      if (current?.email != null) {
        await CredentialsStore.saveLastEmail(current!.email!);
      }
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Perfil guardado')));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error: $e')));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _requestRole(String requestedRole) async {
    setState(() => _loading = true);
    try {
      final current = SupabaseService.currentUser();
      final data = <String, dynamic>{
        'role_request': requestedRole,
      };
      if (current?.id != null) data['auth_id'] = current!.id;
      await SupabaseService.upsertUser(data);
      setState(() {
        _roleRequest = requestedRole;
      });
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Solicitud enviada para ser "$requestedRole"')));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error: $e')));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final roleDisplay = {
      'usuario': 'Usuario',
      'autenticado': 'Autenticado',
      'ofrecedor': 'Ofrecedor',
      'admin': 'Administrador',
    }[_role] ?? _role;

    return Scaffold(
      appBar: AppBar(title: const Text('Perfil')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              if (_loading)
                const Padding(
                  padding: EdgeInsets.only(bottom: 12.0),
                  child: LinearProgressIndicator(),
                ),
              TextFormField(
                controller: _nameController,
                decoration: const InputDecoration(labelText: 'Nombre'),
                validator: (v) =>
                    v != null && v.trim().isNotEmpty ? null : 'Ingrese nombre',
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _lastNameController,
                decoration: const InputDecoration(labelText: 'Apellido'),
                validator: (v) =>
                    v != null && v.trim().isNotEmpty ? null : 'Ingrese apellido',
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _emailController,
                decoration: const InputDecoration(labelText: 'Mail'),
                validator: (v) =>
                    v != null && v.contains('@') ? null : 'Email inválido',
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _phoneController,
                decoration: const InputDecoration(labelText: 'Celular'),
                validator: (v) =>
                    v != null && v.trim().isNotEmpty ? null : 'Ingrese celular',
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _cityController,
                decoration: const InputDecoration(labelText: 'Ciudad'),
                validator: (v) =>
                    v != null && v.trim().isNotEmpty ? null : 'Ingrese ciudad',
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _neighborhoodController,
                decoration: const InputDecoration(labelText: 'Barrio'),
                validator: (v) =>
                    v != null && v.trim().isNotEmpty ? null : 'Ingrese barrio',
              ),
              const SizedBox(height: 20),
              Row(
                children: [
                  const Text('Rol: ', style: TextStyle(fontWeight: FontWeight.bold)),
                  Text(roleDisplay, style: const TextStyle(color: Colors.grey)),
                ],
              ),
              if (_roleRequest != null)
                Padding(
                  padding: const EdgeInsets.only(top: 8.0),
                  child: Text(
                    'Solicitud pendiente para ser "${_roleRequest!}"',
                    style: const TextStyle(color: Colors.orange),
                  ),
                ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton(
                      onPressed: (_loading || _role == 'autenticado' || _roleRequest == 'autenticado')
                          ? null
                          : () => _requestRole('autenticado'),
                      child: const Text('Solicitar ser Autenticado'),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: (_loading || _role == 'ofrecedor' || _roleRequest == 'ofrecedor')
                          ? null
                          : () => _requestRole('ofrecedor'),
                      child: const Text('Solicitar ser Ofrecedor'),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              ElevatedButton(
                onPressed: _loading ? null : _save,
                child: _loading
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                      )
                    : const Text('Guardar'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}