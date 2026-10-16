import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../theme/app_theme.dart';

class ImagePickerWidget extends StatelessWidget {
  final String label;
  final File? image;
  final ValueChanged<File?> onImageChanged;
  final double height;

  const ImagePickerWidget({
    super.key,
    required this.label,
    required this.image,
    required this.onImageChanged,
    this.height = 150,
  });

  Future<void> _pick(ImageSource source) async {
    final picked = await ImagePicker().pickImage(
      source: source,
      imageQuality: 85,
      maxWidth: 1600,
    );
    if (picked != null) onImageChanged(File(picked.path));
  }

  void _showOptions(BuildContext context) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder:
          (sheetContext) => SafeArea(
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
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: Text(
                    label,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                ListTile(
                  leading: const CircleAvatar(
                    backgroundColor: AppColors.surfaceTint,
                    child: Icon(Icons.camera_alt, color: AppColors.primary),
                  ),
                  title: const Text('Take Photo'),
                  onTap: () {
                    Navigator.pop(sheetContext);
                    _pick(ImageSource.camera);
                  },
                ),
                ListTile(
                  leading: const CircleAvatar(
                    backgroundColor: AppColors.surfaceTint,
                    child: Icon(Icons.photo_library, color: AppColors.primary),
                  ),
                  title: const Text('Choose from Gallery'),
                  onTap: () {
                    Navigator.pop(sheetContext);
                    _pick(ImageSource.gallery);
                  },
                ),
                if (image != null)
                  ListTile(
                    leading: const CircleAvatar(
                      backgroundColor: Color(0xFFFFEEEE),
                      child: Icon(Icons.delete_outline, color: AppColors.error),
                    ),
                    title: const Text(
                      'Remove Photo',
                      style: TextStyle(color: AppColors.error),
                    ),
                    onTap: () {
                      Navigator.pop(sheetContext);
                      onImageChanged(null);
                    },
                  ),
                const SizedBox(height: 12),
              ],
            ),
          ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                label,
                style: const TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 13,
                  color: AppColors.textPrimary,
                ),
              ),
            ),
            if (image != null)
              const Icon(Icons.check_circle, size: 16, color: AppColors.success),
          ],
        ),
        const SizedBox(height: 8),
        GestureDetector(
          onTap: () => _showOptions(context),
          child: Container(
            height: height,
            decoration: BoxDecoration(
              color: AppColors.fieldFill,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: image != null ? AppColors.primary : AppColors.border,
                width: 1.5,
              ),
            ),
            child:
                image == null
                    ? Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          width: 48,
                          height: 48,
                          decoration: BoxDecoration(
                            color: AppColors.surfaceTint,
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: const Icon(
                            Icons.add_a_photo_outlined,
                            color: AppColors.primary,
                          ),
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          'Tap to add',
                          style: TextStyle(
                            color: AppColors.textMuted,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    )
                    : ClipRRect(
                      borderRadius: BorderRadius.circular(13),
                      child: Stack(
                        fit: StackFit.expand,
                        children: [
                          Image.file(image!, fit: BoxFit.cover),
                          Positioned(
                            top: 8,
                            right: 8,
                            child: Container(
                              padding: const EdgeInsets.all(6),
                              decoration: BoxDecoration(
                                color: Colors.black54,
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: const Icon(
                                Icons.edit,
                                size: 14,
                                color: Colors.white,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
          ),
        ),
      ],
    );
  }
}
