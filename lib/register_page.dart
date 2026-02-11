import 'package:flutter/material.dart';
import 'services/credentials_store.dart';
import 'services/supabase_service.dart';
import 'main_screen.dart';

class RegisterPage extends StatefulWidget {
  const RegisterPage({super.key});

  @override
  State<RegisterPage> createState() => _RegisterPageState();
}

class _RegisterPageState extends State<RegisterPage> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _nameController = TextEditingController();
  final _lastNameController = TextEditingController();
  bool _loading = false;
  String? _error;
  String _lastAction = '';

  Future<void> _register() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final res = await SupabaseService.signUp(
        email: _emailController.text.trim(),
        password: _passwordController.text.trim(),
        userMetadata: {
          'first_name': _nameController.text.trim(),
          'last_name': _lastNameController.text.trim(),
          'role': 'usuario',
          'role_request': null,
        },
      );
      if (res.user == null) {
        setState(() => _error = 'Error al registrarse');
      } else {
        // Create profile in users table
        await SupabaseService.upsertUser({
          'auth_id': res.user!.id,
          'email': _emailController.text.trim(),
          'first_name': _nameController.text.trim(),
          'last_name': _lastNameController.text.trim(),
          'role': 'usuario',
          'role_request': null,
        });
        
        if (!mounted) return;
        Navigator.of(context).pushReplacementNamed('/login');
      }
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Registro')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
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
                decoration: const InputDecoration(labelText: 'Email'),
                validator: (v) =>
                    v != null && v.contains('@') ? null : 'Email inválido',
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _passwordController,
                decoration: const InputDecoration(labelText: 'Contraseña'),
                obscureText: true,
                validator: (v) =>
                    v != null && v.length >= 6 ? null : 'Mínimo 6 caracteres',
              ),
              const SizedBox(height: 20),
              Row(
                children: [
                  const Text('Rol: ', style: TextStyle(fontWeight: FontWeight.bold)),
                  const Text('usuario (por defecto)', style: TextStyle(color: Colors.grey)),
                ],
              ),
              const SizedBox(height: 20),
              if (_error != null)
                Text(_error!, style: const TextStyle(color: Colors.red)),
              const SizedBox(height: 20),
              ElevatedButton(
                onPressed: _loading
                    ? null
                    : () {
                        setState(() {
                          _lastAction = 'Registrarse pressed';
                        });
                        if (_formKey.currentState!.validate()) {
                          _register();
                        } else {
                          setState(() {
                            _lastAction = 'Validación fallida';
                          });
                        }
                      },
                child: _loading
                    ? const CircularProgressIndicator(color: Colors.white)
                    : const Text('Registrarse'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _nameController.dispose();
    _lastNameController.dispose();
    super.dispose();
  }
}
