import 'package:flutter/material.dart';
import '../services/auth_service.dart';
import '../models/user_model.dart';

class ForcePasswordChangeScreen extends StatefulWidget {
  final UserModel user;

  const ForcePasswordChangeScreen(this.user, {super.key}); // use super.key

  @override
  State<ForcePasswordChangeScreen> createState() =>
      _ForcePasswordChangeScreenState();
}

class _ForcePasswordChangeScreenState extends State<ForcePasswordChangeScreen> {
  final _formKey = GlobalKey<FormState>();
  final _currentPasswordController =
      TextEditingController(); // temp/current password
  final _passwordController = TextEditingController();
  final _authService = AuthService();
  bool _loading = false;

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _loading = true);

    try {
      // Re-authenticate with the current (temporary) password before updating.
      // This prevents the [requires-recent-login] Firebase error.
      await _authService.setNewPassword(
        _passwordController.text,
        currentPassword: _currentPasswordController.text,
      );

      // Use ! to assert non-null values
      await _authService.completeFirstLogin(
        widget.user.uid,
        widget.user.storeId!,
      );

      if (!mounted) return; // guard against async context use
      Navigator.pushReplacementNamed(context, '/worker-home');
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
    return Scaffold(
      appBar: AppBar(title: const Text('Set New Password')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              const Text(
                'For security, please set a new password before continuing.',
                style: TextStyle(fontSize: 16),
              ),
              const SizedBox(height: 20),
              TextFormField(
                controller: _currentPasswordController,
                obscureText: true,
                decoration: const InputDecoration(
                  labelText: 'Current (Temporary) Password',
                ),
                validator: (val) =>
                    val != null && val.isNotEmpty ? null : 'Required',
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _passwordController,
                obscureText: true,
                decoration: const InputDecoration(labelText: 'New Password'),
                validator: (val) =>
                    val != null && val.length >= 6 ? null : 'Min 6 characters',
              ),
              const SizedBox(height: 20),
              ElevatedButton(
                onPressed: _loading ? null : _submit,
                child: _loading
                    ? const CircularProgressIndicator()
                    : const Text('Confirm'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _currentPasswordController.dispose();
    _passwordController.dispose();
    super.dispose();
  }
}
