import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import '../../../services/cloudinary_service.dart';

class DesignSelectionScreen extends StatefulWidget {
  final List<String> presetDesigns;
  final String? currentDesignUrl;
  final bool? currentIsPreset;

  const DesignSelectionScreen({
    super.key,
    required this.presetDesigns,
    this.currentDesignUrl,
    this.currentIsPreset,
  });

  @override
  State<DesignSelectionScreen> createState() => _DesignSelectionScreenState();
}

class _DesignSelectionScreenState extends State<DesignSelectionScreen> {
  bool _isPresetTab = true;
  String? _selectedPreset;
  String? _uploadedFileUrl;
  String? _uploadedFileName;
  bool _isUploading = false;

  @override
  void initState() {
    super.initState();
    if (widget.currentIsPreset == true) {
      _selectedPreset = widget.currentDesignUrl;
    } else if (widget.currentIsPreset == false) {
      _uploadedFileUrl = widget.currentDesignUrl;
      _isPresetTab = false;
    }
  }

  Future<void> _pickAndUploadFile() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['jpg', 'jpeg', 'png', 'pdf'],
        withData: true,
      );

      if (result == null) return;
      setState(() => _isUploading = true);

      final file = result.files.single;
      final fileName = file.name;

      String url;
      if (file.bytes != null && file.bytes!.isNotEmpty) {
        // Bytes path — works on ALL platforms (web, mobile, desktop).
        url = await CloudinaryService.uploadBytes(file.bytes!, fileName);
      } else if (file.path != null && file.path!.isNotEmpty) {
        // Path path — mobile/desktop only. Never reached on web because
        // file_picker on web returns null or empty for path.
        url = await CloudinaryService.uploadFile(file.path!);
      } else {
        throw Exception('Could not read file — no bytes or path available');
      }

      setState(() {
        _uploadedFileUrl = url;
        _uploadedFileName = fileName;
        _isUploading = false;
      });
    } catch (e) {
      setState(() => _isUploading = false);
      debugPrint('[DesignSelection] Upload failed: $e');
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Upload failed: ${e.toString()}')));
      }
    }
  }

  void _confirmDesign() {
    if (_isPresetTab && _selectedPreset != null) {
      Navigator.pop(context, {'designUrl': _selectedPreset, 'isPreset': true});
    } else if (!_isPresetTab && _uploadedFileUrl != null) {
      Navigator.pop(context, {
        'designUrl': _uploadedFileUrl,
        'isPreset': false,
      });
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select or upload a design')),
      );
    }
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
          'Choose Design',
          style: TextStyle(
            color: Colors.blue[700],
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      body: Column(
        children: [
          // Toggle tabs
          Padding(
            padding: const EdgeInsets.all(16),
            child: Container(
              height: 40,
              decoration: BoxDecoration(
                color: Colors.grey[100],
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: GestureDetector(
                      onTap: () => setState(() => _isPresetTab = true),
                      child: Container(
                        decoration: BoxDecoration(
                          color: _isPresetTab
                              ? Colors.white
                              : Colors.transparent,
                          borderRadius: BorderRadius.circular(8),
                          border: _isPresetTab
                              ? Border.all(color: Colors.grey.shade200)
                              : null,
                        ),
                        child: Center(
                          child: Text(
                            'Preset Designs',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: _isPresetTab
                                  ? Colors.blue[700]
                                  : Colors.grey[500],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                  Expanded(
                    child: GestureDetector(
                      onTap: () => setState(() => _isPresetTab = false),
                      child: Container(
                        decoration: BoxDecoration(
                          color: !_isPresetTab
                              ? Colors.white
                              : Colors.transparent,
                          borderRadius: BorderRadius.circular(8),
                          border: !_isPresetTab
                              ? Border.all(color: Colors.grey.shade200)
                              : null,
                        ),
                        child: Center(
                          child: Text(
                            'Upload Design',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: !_isPresetTab
                                  ? Colors.blue[700]
                                  : Colors.grey[500],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

          Expanded(child: _isPresetTab ? _buildPresetTab() : _buildUploadTab()),

          // Confirm button
          Padding(
            padding: const EdgeInsets.all(16),
            child: SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                onPressed: _confirmDesign,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue[700],
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: const Text(
                  'Confirm Design',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPresetTab() {
    if (widget.presetDesigns.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.image_outlined, size: 64, color: Colors.grey[300]),
            const SizedBox(height: 12),
            Text(
              'No preset designs available',
              style: TextStyle(color: Colors.grey[500]),
            ),
            const SizedBox(height: 8),
            Text(
              'Switch to Upload Design tab',
              style: TextStyle(color: Colors.grey[400], fontSize: 13),
            ),
          ],
        ),
      );
    }

    return GridView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        crossAxisSpacing: 10,
        mainAxisSpacing: 10,
        childAspectRatio: 1,
      ),
      itemCount: widget.presetDesigns.length,
      itemBuilder: (context, index) {
        final design = widget.presetDesigns[index];
        final isSelected = _selectedPreset == design;
        return GestureDetector(
          onTap: () => setState(() => _selectedPreset = design),
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: isSelected ? Colors.blue[700]! : Colors.grey.shade200,
                width: isSelected ? 2.5 : 1,
              ),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(9),
              child: Stack(
                children: [
                  Image.network(
                    design,
                    fit: BoxFit.cover,
                    width: double.infinity,
                    height: double.infinity,
                    errorBuilder: (context, error, stackTrace) => Container(
                      color: Colors.blue[50],
                      child: Center(
                        child: Icon(
                          Icons.image,
                          color: Colors.blue[200],
                          size: 32,
                        ),
                      ),
                    ),
                  ),
                  if (isSelected)
                    Positioned(
                      top: 6,
                      right: 6,
                      child: Container(
                        padding: const EdgeInsets.all(2),
                        decoration: BoxDecoration(
                          color: Colors.blue[700],
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.check,
                          color: Colors.white,
                          size: 14,
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildUploadTab() {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          GestureDetector(
            onTap: _isUploading ? null : _pickAndUploadFile,
            child: Container(
              width: double.infinity,
              height: 160,
              decoration: BoxDecoration(
                color: Colors.grey[50],
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.grey.shade300),
              ),
              child: _isUploading
                  ? const Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          CircularProgressIndicator(),
                          SizedBox(height: 12),
                          Text('Uploading...'),
                        ],
                      ),
                    )
                  : Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.cloud_upload_outlined,
                          size: 48,
                          color: Colors.grey[400],
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Tap to upload design',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: Colors.grey[600],
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'PNG, JPG, PDF up to 10MB',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey[400],
                          ),
                        ),
                        const SizedBox(height: 12),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 8,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.blue[700],
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Text(
                            'Browse Files',
                            style: TextStyle(color: Colors.white, fontSize: 13),
                          ),
                        ),
                      ],
                    ),
            ),
          ),
          const SizedBox(height: 16),
          if (_uploadedFileUrl != null)
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.blue[50],
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Colors.blue.shade200),
              ),
              child: Row(
                children: [
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: Colors.blue[100],
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(Icons.image, color: Colors.blue[700], size: 28),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _uploadedFileName ?? 'Uploaded file',
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        Text(
                          'Upload successful ✓',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.green[700],
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, color: Colors.red),
                    onPressed: () => setState(() {
                      _uploadedFileUrl = null;
                      _uploadedFileName = null;
                    }),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
