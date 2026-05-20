import 'package:flutter/material.dart';
import '../../models/store_model.dart';
import '../../services/store_service.dart';

class EditShopScreen extends StatefulWidget {
  final StoreModel store;

  const EditShopScreen({super.key, required this.store});

  @override
  State<EditShopScreen> createState() => _EditShopScreenState();
}

class _EditShopScreenState extends State<EditShopScreen> {
  late final TextEditingController _storeNameController;
  late final TextEditingController _locationController;
  late final TextEditingController _contactController;
  late final TextEditingController _descriptionController;
  late final TextEditingController _facebookController;
  late final TextEditingController _instagramController;
  late final TextEditingController _tiktokController;
  late final TextEditingController _hoursController;
  final _storeService = StoreService();
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _storeNameController = TextEditingController(text: widget.store.storeName);
    _locationController = TextEditingController(text: widget.store.location);
    _contactController = TextEditingController(text: widget.store.contact);
    _descriptionController = TextEditingController(text: widget.store.description);
    _facebookController = TextEditingController(text: widget.store.facebookUrl);
    _instagramController = TextEditingController(text: widget.store.instagramUrl);
    _tiktokController = TextEditingController(text: widget.store.tiktokUrl);
    _hoursController = TextEditingController(text: widget.store.businessHours);
  }

  @override
  void dispose() {
    _storeNameController.dispose();
    _locationController.dispose();
    _contactController.dispose();
    _descriptionController.dispose();
    _facebookController.dispose();
    _instagramController.dispose();
    _tiktokController.dispose();
    _hoursController.dispose();
    super.dispose();
  }

  Future<void> _saveChanges() async {
    if (_storeNameController.text.isEmpty ||
        _locationController.text.isEmpty ||
        _contactController.text.isEmpty ||
        _descriptionController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please fill in all required fields')),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      final updatedData = {
        'storeName': _storeNameController.text.trim(),
        'location': _locationController.text.trim(),
        'contact': _contactController.text.trim(),
        'description': _descriptionController.text.trim(),
        'facebookUrl': _facebookController.text.trim(),
        'instagramUrl': _instagramController.text.trim(),
        'tiktokUrl': _tiktokController.text.trim(),
        'businessHours': _hoursController.text.trim(),
      };

      await _storeService.updateStore(widget.store.storeId, updatedData);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Shop details updated successfully!')),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Failed to update shop: $e')));
      }
    }

    setState(() => _isLoading = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: Colors.blue[700]),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'Edit Shop Details',
          style: TextStyle(
            color: Colors.blue[700],
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildTextField(
              controller: _storeNameController,
              label: 'Store Name',
              hint: 'Enter your store name',
              icon: Icons.store_outlined,
            ),
            const SizedBox(height: 16),
            _buildTextField(
              controller: _locationController,
              label: 'Location',
              hint: 'Enter your store address',
              icon: Icons.location_on_outlined,
            ),
            const SizedBox(height: 16),
            _buildTextField(
              controller: _contactController,
              label: 'Contact Number',
              hint: 'Enter your contact number',
              icon: Icons.phone_outlined,
              keyboardType: TextInputType.phone,
            ),
            const SizedBox(height: 16),
            _buildTextField(
              controller: _descriptionController,
              label: 'Store Description',
              hint: 'Describe your store and services',
              icon: Icons.description_outlined,
              maxLines: 4,
            ),
            const SizedBox(height: 16),
            _buildTextField(
              controller: _hoursController,
              label: 'Business Hours',
              hint: 'e.g. Mon-Fri 9am-6pm',
              icon: Icons.access_time_outlined,
            ),
            const SizedBox(height: 16),
            _buildTextField(
              controller: _facebookController,
              label: 'Facebook Page',
              hint: 'Enter your Facebook link',
              icon: Icons.facebook,
            ),
            const SizedBox(height: 16),
            _buildTextField(
              controller: _instagramController,
              label: 'Instagram Handle',
              hint: 'Enter your Instagram handle',
              icon: Icons.camera_alt_outlined,
            ),
            const SizedBox(height: 16),
            _buildTextField(
              controller: _tiktokController,
              label: 'TikTok Handle',
              hint: 'Enter your TikTok handle',
              icon: Icons.video_collection_outlined,
            ),
            const SizedBox(height: 32),
            SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton(
                onPressed: _isLoading ? null : _saveChanges,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue[700],
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: _isLoading
                    ? const CircularProgressIndicator(color: Colors.white)
                    : const Text(
                        'Save Changes',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required String hint,
    required IconData icon,
    TextInputType keyboardType = TextInputType.text,
    int maxLines = 1,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: Colors.grey[700],
          ),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: controller,
          keyboardType: keyboardType,
          maxLines: maxLines,
          decoration: InputDecoration(
            hintText: hint,
            prefixIcon: Icon(icon),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: Colors.blue[700]!),
            ),
          ),
        ),
      ],
    );
  }
}
