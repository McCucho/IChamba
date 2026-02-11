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
  bool _loading = false;
  String? _error;
  String _lastAction = '';

  Future<void> _register() async {
    // Debug: handler invoked
    debugPrint('register: handler invoked');

    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final email = _emailController.text.trim();
      final password = _passwordController.text.trim();

      // 1. Crear usuario
      final response = await SupabaseService.signUp(email, password);
      // Debugging info
      debugPrint(
        'signUp response: user=${response.user}, session=${response.session}',
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('signUp: user=${response.user != null}')),
        );
      }
      if (response.user == null) {
        setState(() {
          _error = 'Error desconocido en el registro.';
        });
        return;
      }

      // 2. Iniciar sesión inmediatamente para obtener sesión válida
      final signInResp = await SupabaseService.signIn(email, password);
      // Debugging info
      debugPrint(
        'signIn response: user=${signInResp.user}, session=${signInResp.session}',
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'signIn: user=${signInResp.user != null}, session=${signInResp.session != null}',
            ),
          ),
        );
      }
      await CredentialsStore.saveLastEmail(email);

      if (!mounted) return;
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(
          builder: (_) => const MainScreen(),
          settings: const RouteSettings(arguments: {'showSidebar': true}),
        ),
        (route) => false,
      );
      return;
    } catch (e, st) {
      debugPrint('register: exception: $e');
      debugPrint('$st');
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('register exception: $e')));
      }
      setState(() {
        _error = e.toString();
      });
    } finally {
      if (mounted) {
        setState(() {
          _loading = false;
        });
      }
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
                controller: _emailController,
                decoration: const InputDecoration(labelText: 'Email'),
                validator: (value) => value != null && value.contains('@')
                    ? null
                    : 'Email inválido',
              ),
              TextFormField(
                controller: _passwordController,
                decoration: const InputDecoration(labelText: 'Contraseña'),
                obscureText: true,
                validator: (value) => value != null && value.length >= 6
                    ? null
                    : 'Mínimo 6 caracteres',
              ),
              const SizedBox(height: 8),
              if (_lastAction.isNotEmpty)
                Text(_lastAction, style: const TextStyle(color: Colors.blue)),
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
    super.dispose();
  }
}
