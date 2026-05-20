import 'package:flutter/material.dart';
import '../../../../services/auth_service.dart';

class CreateWorkerSheet extends StatefulWidget {
  final String storeId;
  final String ownerUid;

  const CreateWorkerSheet({
    super.key,
    required this.storeId,
    required this.ownerUid,
  });

  @override
  State<CreateWorkerSheet> createState() => _CreateWorkerSheetState();
}

class _CreateWorkerSheetState extends State<CreateWorkerSheet> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _authService = AuthService();

  bool _showPassword = false;
  bool _isLoading = false;

  // Permission toggles — all off by default (owner must explicitly grant access)
  final Map<String, bool> _permissions = {
    'canUpdateOrderStatus': false,
    'canConfirmPayments': false,
    'canViewInventory': false,
    'canUsePOS': false,
  };

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _createWorker() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isLoading = true);
    try {
      await _authService.createWorkerAccount(
        name: _nameController.text,
        email: _emailController.text,
        tempPassword: _passwordController.text,
        storeId: widget.storeId,
        ownerUid: widget.ownerUid,
        permissions: _permissions,
      );
      if (!mounted) return;
      Navigator.pop(context, true); // true = success, refresh the list
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Worker account for ${_nameController.text} created successfully.',
          ),
          backgroundColor: Colors.green[700],
        ),
      );
    } on Exception catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(e.toString().replaceAll('Exception: ', '')),
          backgroundColor: Colors.red[700],
        ),
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Widget _buildPermissionTile({
    required String label,
    required String subtitle,
    required String key,
    required IconData icon,
  }) {
    return SwitchListTile(
      value: _permissions[key]!,
      onChanged: (val) => setState(() => _permissions[key] = val),
      title: Text(
        label,
        style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 14),
      ),
      subtitle: Text(
        subtitle,
        style: TextStyle(fontSize: 12, color: Colors.grey[600]),
      ),
      secondary: Icon(icon, color: Colors.blue[700], size: 22),
      activeThumbColor: Colors.blue[700],
      contentPadding: EdgeInsets.zero,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        left: 24,
        right: 24,
        top: 24,
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      child: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Header
              Row(
                children: [
                  Icon(Icons.person_add_rounded, color: Colors.blue[700]),
                  const SizedBox(width: 10),
                  Text(
                    'Add New Worker',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.grey[800],
                    ),
                  ),
                  const Spacer(),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
              const Divider(height: 24),

              // Full name
              TextFormField(
                controller: _nameController,
                textCapitalization: TextCapitalization.words,
                decoration: InputDecoration(
                  labelText: 'Full Name',
                  hintText: 'e.g. Juan Dela Cruz',
                  prefixIcon: const Icon(Icons.person_outline),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  filled: true,
                  fillColor: Colors.grey[50],
                ),
                validator: (v) => (v == null || v.trim().isEmpty)
                    ? 'Name is required.'
                    : null,
              ),
              const SizedBox(height: 14),

              // Email
              TextFormField(
                controller: _emailController,
                keyboardType: TextInputType.emailAddress,
                decoration: InputDecoration(
                  labelText: 'Email Address',
                  hintText: 'worker@example.com',
                  prefixIcon: const Icon(Icons.email_outlined),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  filled: true,
                  fillColor: Colors.grey[50],
                ),
                validator: (v) {
                  if (v == null || v.trim().isEmpty) {
                    return 'Email is required.';
                  }
                  if (!v.contains('@')) return 'Enter a valid email.';
                  return null;
                },
              ),
              const SizedBox(height: 14),

              // Temporary password
              TextFormField(
                controller: _passwordController,
                obscureText: !_showPassword,
                decoration: InputDecoration(
                  labelText: 'Temporary Password',
                  hintText: 'Worker must change this on first login',
                  prefixIcon: const Icon(Icons.lock_outline),
                  suffixIcon: IconButton(
                    icon: Icon(
                      _showPassword ? Icons.visibility_off : Icons.visibility,
                    ),
                    onPressed: () =>
                        setState(() => _showPassword = !_showPassword),
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  filled: true,
                  fillColor: Colors.grey[50],
                  helperText:
                      'Worker will be asked to set a new password on first login.',
                  helperStyle: TextStyle(
                    color: Colors.orange[700],
                    fontSize: 11,
                  ),
                ),
                validator: (v) {
                  if (v == null || v.isEmpty) {
                    return 'Temporary password is required.';
                  }
                  if (v.length < 6) return 'Must be at least 6 characters.';
                  return null;
                },
              ),
              const SizedBox(height: 24),

              // Permissions section
              Text(
                'Permissions',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                  color: Colors.grey[800],
                ),
              ),
              Text(
                'You can change these anytime from worker settings.',
                style: TextStyle(fontSize: 12, color: Colors.grey[500]),
              ),
              const SizedBox(height: 8),

              _buildPermissionTile(
                label: 'Update Order Status',
                subtitle: 'Can mark orders as Processing, Ready, Completed',
                key: 'canUpdateOrderStatus',
                icon: Icons.assignment_turned_in_outlined,
              ),
              _buildPermissionTile(
                label: 'Confirm In-Person Payments',
                subtitle: 'Can mark cash payments as received',
                key: 'canConfirmPayments',
                icon: Icons.payments_outlined,
              ),
              _buildPermissionTile(
                label: 'View Inventory',
                subtitle: 'Can view product stock and availability',
                key: 'canViewInventory',
                icon: Icons.inventory_2_outlined,
              ),
              _buildPermissionTile(
                label: 'Point of Sale',
                subtitle: 'Can process walk-in sales and record cash payments',
                key: 'canUsePOS',
                icon: Icons.point_of_sale_outlined,
              ),

              const SizedBox(height: 24),

              // Submit button
              SizedBox(
                height: 52,
                child: ElevatedButton.icon(
                  onPressed: _isLoading ? null : _createWorker,
                  icon: _isLoading
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            color: Colors.white,
                            strokeWidth: 2,
                          ),
                        )
                      : const Icon(Icons.check_rounded),
                  label: Text(
                    _isLoading
                        ? 'Creating Account...'
                        : 'Create Worker Account',
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue[700],
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    textStyle: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
