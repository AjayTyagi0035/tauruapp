import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

class ImagePickerWidget extends StatelessWidget {
  final File? image;
  final String? imageUrl;
  final ValueChanged<File?> onImageChanged;
  final VoidCallback? onRemoveImageUrl;

  const ImagePickerWidget({
    super.key,
    required this.image,
    this.imageUrl,
    required this.onImageChanged,
    this.onRemoveImageUrl,
  });

  Future<void> _pick(BuildContext context, ImageSource source) async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(
      source: source,
      imageQuality: 85,
      maxWidth: 1200,
    );
    if (picked != null) {
      onImageChanged(File(picked.path));
    }
  }

  void _showOptions(BuildContext context) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.only(top: 12, bottom: 8),
              decoration: BoxDecoration(
                color: Colors.black12,
                borderRadius: BorderRadius.circular(4),
              ),
            ),
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 8),
              child: Text(
                'Add Survey Photo',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
            ),
            ListTile(
              leading: const CircleAvatar(
                backgroundColor: Color(0xFFEEF2FF),
                child: Icon(Icons.camera_alt, color: Color(0xFF3B5BDB)),
              ),
              title: const Text('Take Photo'),
              onTap: () {
                Navigator.pop(context);
                _pick(context, ImageSource.camera);
              },
            ),
            ListTile(
              leading: const CircleAvatar(
                backgroundColor: Color(0xFFEEF2FF),
                child: Icon(Icons.photo_library, color: Color(0xFF3B5BDB)),
              ),
              title: const Text('Choose from Gallery'),
              onTap: () {
                Navigator.pop(context);
                _pick(context, ImageSource.gallery);
              },
            ),
            if (image != null || (imageUrl != null && imageUrl!.trim().isNotEmpty))
              ListTile(
                leading: const CircleAvatar(
                  backgroundColor: Color(0xFFFFEEEE),
                  child: Icon(Icons.delete_outline, color: Colors.redAccent),
                ),
                title: const Text(
                  'Remove Photo',
                  style: TextStyle(color: Colors.redAccent),
                ),
                onTap: () {
                  Navigator.pop(context);
                  onImageChanged(null);
                  if (onRemoveImageUrl != null) {
                    onRemoveImageUrl!();
                  }
                },
              ),
            const SizedBox(height: 12),
          ],
        ),
      ),
    );
  }

  String _buildFullUrl(String url) {
    if (url.startsWith('http://') || url.startsWith('https://')) {
      return url;
    }
    final cleanPath = url.startsWith('/') ? url.substring(1) : url;
    return 'https://cdn.omgauamrit.in/$cleanPath';
  }

  @override
  Widget build(BuildContext context) {
    final hasImage = image != null || (imageUrl != null && imageUrl!.trim().isNotEmpty);
    return GestureDetector(
      onTap: () => _showOptions(context),
      child: Container(
        height: 160,
        decoration: BoxDecoration(
          color: const Color(0xFFF8F9FF),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: const Color(0xFFCDD5F3),
            width: 1.5,
          ),
        ),
        child: !hasImage
            ? Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    width: 56,
                    height: 56,
                    decoration: BoxDecoration(
                      color: const Color(0xFFEEF2FF),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: const Icon(
                      Icons.add_a_photo_outlined,
                      size: 28,
                      color: Color(0xFF3B5BDB),
                    ),
                  ),
                  const SizedBox(height: 10),
                  const Text(
                    'Add Survey Photo',
                    style: TextStyle(
                      color: Color(0xFF3B5BDB),
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    'Tap to take or choose image',
                    style: TextStyle(color: Colors.black38, fontSize: 12),
                  ),
                ],
              )
            : ClipRRect(
                borderRadius: BorderRadius.circular(13),
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    if (image != null)
                      Image.file(image!, fit: BoxFit.cover)
                    else if (imageUrl != null && imageUrl!.trim().isNotEmpty)
                      Image.network(
                        _buildFullUrl(imageUrl!),
                        fit: BoxFit.cover,
                        loadingBuilder: (context, child, loadingProgress) {
                          if (loadingProgress == null) return child;
                          return const Center(
                            child: CircularProgressIndicator(),
                          );
                        },
                        errorBuilder: (context, error, stackTrace) {
                          return const Center(
                            child: Icon(
                              Icons.broken_image_outlined,
                              size: 40,
                              color: Colors.redAccent,
                            ),
                          );
                        },
                      ),
                    Positioned(
                      top: 8,
                      right: 8,
                      child: GestureDetector(
                        onTap: () => _showOptions(context),
                        child: Container(
                          padding: const EdgeInsets.all(6),
                          decoration: BoxDecoration(
                            color: Colors.black54,
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: const Icon(
                            Icons.edit,
                            size: 16,
                            color: Colors.white,
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
