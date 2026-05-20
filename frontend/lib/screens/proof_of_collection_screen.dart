import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
// import 'dart:io'; // Removed for web compatibility
import '../services/api_service.dart';

class ProofOfCollectionScreen extends StatefulWidget {
  final Map<String, dynamic> houseData;
  final String routeId;
  const ProofOfCollectionScreen({
    super.key,
    required this.houseData,
    required this.routeId,
  });

  @override
  _ProofOfCollectionScreenState createState() =>
      _ProofOfCollectionScreenState();
}

class _ProofOfCollectionScreenState extends State<ProofOfCollectionScreen> {
  final ApiService _apiService = ApiService();
  final ImagePicker _picker = ImagePicker();
  XFile? _pickedImage;
  Uint8List? _imageBytes;
  bool _isSubmitting = false;

  static const _primaryGreen = Color(0xFF1B5E20);
  static const _accentGreen = Color(0xFF2E7D32);
  static const _bgColor = Color(0xFFF8FAFC);

  Future<void> _pickImage(ImageSource source) async {
    try {
      final XFile? image = await _picker.pickImage(
        source: source,
        imageQuality: 70,
        maxWidth: 1024,
      );
      if (image != null) {
        final bytes = await image.readAsBytes();
        setState(() {
          _pickedImage = image;
          _imageBytes = bytes;
        });
      }
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error picking image: $e')));
    }
  }

  void _showPickerOptions() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => Container(
        padding: const EdgeInsets.symmetric(vertical: 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Upload Proof Photo',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: _primaryGreen,
              ),
            ),
            const SizedBox(height: 20),
            ListTile(
              leading: const Icon(
                Icons.camera_alt_rounded,
                color: _accentGreen,
              ),
              title: const Text('Take Photo'),
              onTap: () {
                Navigator.pop(context);
                _pickImage(ImageSource.camera);
              },
            ),
            ListTile(
              leading: const Icon(
                Icons.photo_library_rounded,
                color: _accentGreen,
              ),
              title: const Text('Choose from Gallery'),
              onTap: () {
                Navigator.pop(context);
                _pickImage(ImageSource.gallery);
              },
            ),
          ],
        ),
      ),
    );
  }

  void _submit() async {
    if (_pickedImage == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please upload a JPG photo of the waste first.'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    setState(() => _isSubmitting = true);
    try {
      // In a real app, you would upload _pickedImage to Firebase/Cloudinary first
      // Here we simulate the URL
      final res = await _apiService.markCollection({
        'assignmentId': widget.houseData['assignmentId']?.toString() ?? '',
        'houseId': widget.houseData['_id']?.toString() ?? '',
        'residentId': widget.houseData['residentId']?.toString() ?? '',
        'routeId': widget.routeId,
        'status': 'Collected',
        'wasteTypes':
            widget.houseData['assignedWasteTypes'] as List<dynamic>? ?? [],
        'proofImageUrl':
            'https://haritha.storage.com/proofs/${_pickedImage!.name}',
        'date': widget.houseData['date']?.toString() ?? '',
        'houseNumber': widget.houseData['houseNumber']?.toString() ?? '',
        'collectedAt': DateTime.now().toIso8601String(),
      });

      if (res['message'] != null && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✅ Collection Proof Submitted Successfully!'),
            backgroundColor: _accentGreen,
          ),
        );
        Navigator.pop(context, true);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final houseNo = widget.houseData['houseNumber']?.toString() ?? 'N/A';
    final ownerName = widget.houseData['ownerName']?.toString() ?? 'Resident';
    final address =
        widget.houseData['address']?.toString() ?? 'No address provided';

    return Scaffold(
      backgroundColor: _bgColor,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Proof of Collection',
          style: TextStyle(color: _primaryGreen, fontWeight: FontWeight.w800),
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                children: [
                  // Info Card
                  Container(
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(24),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.04),
                          blurRadius: 20,
                        ),
                      ],
                    ),
                    child: Column(
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'HOUSE NO',
                                  style: TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.w900,
                                    color: _accentGreen,
                                    letterSpacing: 1,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  houseNo,
                                  style: const TextStyle(
                                    fontSize: 28,
                                    fontWeight: FontWeight.w900,
                                    color: Color(0xFF1A1C1E),
                                  ),
                                ),
                              ],
                            ),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                const Text(
                                  'RESIDENT',
                                  style: TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.w900,
                                    color: Colors.black45,
                                    letterSpacing: 1,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  ownerName,
                                  style: const TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.w800,
                                    color: Color(0xFF1565C0),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                        const Divider(
                          height: 32,
                          thickness: 1,
                          color: Color(0xFFF1F5F9),
                        ),
                        _infoRow(Icons.location_on_rounded, 'Address', address),
                      ],
                    ),
                  ),
                  const SizedBox(height: 32),

                  // Image Preview Area
                  GestureDetector(
                    onTap: _showPickerOptions,
                    child: Container(
                      width: double.infinity,
                      height: 300,
                      decoration: BoxDecoration(
                        color: _pickedImage != null
                            ? Colors.black
                            : _primaryGreen.withOpacity(0.05),
                        borderRadius: BorderRadius.circular(32),
                        border: Border.all(
                          color: _pickedImage != null
                              ? _accentGreen
                              : _primaryGreen.withOpacity(0.1),
                          width: _pickedImage != null ? 3 : 2,
                        ),
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(29),
                        child: _pickedImage != null
                            ? Stack(
                                fit: StackFit.expand,
                                children: [
                                  _imageBytes != null
                                      ? Image.memory(
                                          _imageBytes!,
                                          fit: BoxFit.cover,
                                        )
                                      : const Center(
                                          child: CircularProgressIndicator(),
                                        ),
                                  Container(
                                    decoration: BoxDecoration(
                                      gradient: LinearGradient(
                                        begin: Alignment.bottomCenter,
                                        end: Alignment.topCenter,
                                        colors: [
                                          Colors.black.withOpacity(0.6),
                                          Colors.transparent,
                                        ],
                                      ),
                                    ),
                                  ),
                                  const Positioned(
                                    bottom: 20,
                                    right: 20,
                                    child: Icon(
                                      Icons.check_circle_rounded,
                                      color: Colors.white,
                                      size: 40,
                                    ),
                                  ),
                                ],
                              )
                            : Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Container(
                                    padding: const EdgeInsets.all(20),
                                    decoration: BoxDecoration(
                                      color: Colors.white,
                                      borderRadius: BorderRadius.circular(20),
                                      boxShadow: [
                                        BoxShadow(
                                          color: _primaryGreen.withOpacity(0.1),
                                          blurRadius: 10,
                                        ),
                                      ],
                                    ),
                                    child: const Icon(
                                      Icons.add_a_photo_rounded,
                                      size: 48,
                                      color: _accentGreen,
                                    ),
                                  ),
                                  const SizedBox(height: 24),
                                  const Text(
                                    'Upload JPG Proof',
                                    style: TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.w800,
                                      color: Color(0xFF1A1C1E),
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  const Text(
                                    'Tap to capture or select photo',
                                    style: TextStyle(
                                      fontSize: 13,
                                      color: Colors.black45,
                                    ),
                                  ),
                                ],
                              ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),

                  if (_pickedImage != null)
                    TextButton.icon(
                      onPressed: _showPickerOptions,
                      icon: const Icon(
                        Icons.refresh_rounded,
                        color: _primaryGreen,
                      ),
                      label: const Text(
                        'Change JPG Photo',
                        style: TextStyle(
                          color: _primaryGreen,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),

          // Bottom Button
          Container(
            padding: const EdgeInsets.fromLTRB(20, 10, 20, 30),
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
              boxShadow: [
                BoxShadow(
                  color: Colors.black12,
                  blurRadius: 10,
                  offset: Offset(0, -2),
                ),
              ],
            ),
            child: SizedBox(
              width: double.infinity,
              height: 64,
              child: ElevatedButton.icon(
                onPressed: _isSubmitting || _pickedImage == null
                    ? null
                    : _submit,
                style: ElevatedButton.styleFrom(
                  backgroundColor: _accentGreen,
                  foregroundColor: Colors.white,
                  disabledBackgroundColor: Colors.grey[300],
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(18),
                  ),
                  elevation: 4,
                ),
                icon: _isSubmitting
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          color: Colors.white,
                          strokeWidth: 2,
                        ),
                      )
                    : const Icon(Icons.cloud_upload_outlined, size: 22),
                label: Text(
                  _isSubmitting ? 'UPLOADING...' : 'Confirm & Submit JPG Proof',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 0.5,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _infoRow(
    IconData icon,
    String label,
    String value, {
    bool isBold = false,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 16, color: _accentGreen),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label.toUpperCase(),
                style: const TextStyle(
                  fontSize: 9,
                  fontWeight: FontWeight.w900,
                  color: Colors.black45,
                  letterSpacing: 0.5,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                value,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: isBold ? FontWeight.w800 : FontWeight.w600,
                  color: Colors.black87,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
