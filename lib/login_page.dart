import 'package:flutter/material.dart';
import 'services/credentials_store.dart';
import 'services/supabase_service.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _loading = false;
  String? _error;
  String _lastAction = '';

  @override
  void initState() {
    super.initState();
    _loadLastEmail();
  }

  Future<void> _loadLastEmail() async {
    final lastEmail = await CredentialsStore.readLastEmail();
    if (lastEmail != null && lastEmail.isNotEmpty) {
      _emailController.text = lastEmail;
    }
  }

  Future<void> _login() async {
    // Debug: handler invoked
    debugPrint('login: handler invoked');

    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final response = await SupabaseService.signIn(
        _emailController.text.trim(),
        _passwordController.text.trim(),
      );
      // Debugging info
      debugPrint(
        'login signIn response: user=${response.user}, session=${response.session}',
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'login signIn: user=${response.user != null}, session=${response.session != null}',
            ),
          ),
        );
      }

      if (response.user != null) {
        await CredentialsStore.saveLastEmail(_emailController.text.trim());
        if (!mounted) return;
        Navigator.of(
          context,
        ).pushNamedAndRemoveUntil('/main', (route) => false);
        return;
      } else {
        setState(() {
          _error = 'No se pudo iniciar sesión.';
        });
      }
    } catch (e, st) {
      debugPrint('login: exception: $e');
      debugPrint('$st');
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('login exception: $e')));
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
      appBar: AppBar(title: const Text('Iniciar sesión')),
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
                          _lastAction = 'Entrar pressed';
                        });
                        if (_formKey.currentState!.validate()) {
                          _login();
                        } else {
                          setState(() {
                            _lastAction = 'Validación fallida';
                          });
                        }
                      },
                child: _loading
                    ? const CircularProgressIndicator(color: Colors.white)
                    : const Text('Entrar'),
              ),
              const SizedBox(height: 12),
              TextButton(
                onPressed: _loading
                    ? null
                    : () => Navigator.pushNamed(context, '/register'),
                child: const Text('Crear cuenta'),
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
