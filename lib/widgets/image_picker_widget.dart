import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../theme/app_theme.dart';

/// Opens a full-screen, zoomable view of a remote photo. The image is only
/// downloaded when this is called.
Future<void> showNetworkImageDialog(BuildContext context, String url, String title) {
  return showDialog<void>(
    context: context,
    builder:
        (dialogContext) => Dialog(
          insetPadding: const EdgeInsets.all(12),
          clipBehavior: Clip.antiAlias,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
                trailing: IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.pop(dialogContext),
                ),
              ),
              Flexible(
                child: InteractiveViewer(
                  maxScale: 5,
                  child: Image.network(
                    url,
                    fit: BoxFit.contain,
                    loadingBuilder:
                        (_, child, progress) =>
                            progress == null
                                ? child
                                : const SizedBox(
                                  height: 240,
                                  child: Center(child: CircularProgressIndicator()),
                                ),
                    errorBuilder:
                        (_, __, ___) => const SizedBox(
                          height: 240,
                          child: Center(
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.broken_image_outlined, size: 40, color: AppColors.textMuted),
                                SizedBox(height: 8),
                                Text('Could not load photo', style: TextStyle(color: AppColors.textMuted)),
                              ],
                            ),
                          ),
                        ),
                  ),
                ),
              ),
            ],
          ),
        ),
  );
}

class ImagePickerWidget extends StatelessWidget {
  final String label;
  final File? image;

  /// Already-uploaded photo, shown when no new [image] has been picked.
  final String? imageUrl;

  /// Called with the new file, or null when the photo is removed.
  final ValueChanged<File?> onImageChanged;
  final double height;

  const ImagePickerWidget({
    super.key,
    required this.label,
    required this.image,
    required this.onImageChanged,
    this.imageUrl,
    this.height = 150,
  });

  bool get _hasPhoto => image != null || (imageUrl?.isNotEmpty ?? false);

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
                if (image == null && (imageUrl?.isNotEmpty ?? false))
                  ListTile(
                    leading: const CircleAvatar(
                      backgroundColor: AppColors.surfaceTint,
                      child: Icon(Icons.visibility_outlined, color: AppColors.primary),
                    ),
                    title: const Text('View Saved Photo'),
                    onTap: () {
                      Navigator.pop(sheetContext);
                      showNetworkImageDialog(context, imageUrl!, label);
                    },
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
                if (_hasPhoto)
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
            if (_hasPhoto)
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
                color: _hasPhoto ? AppColors.primary : AppColors.border,
                width: 1.5,
              ),
            ),
            child:
                !_hasPhoto
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
                          if (image != null)
                            Image.file(image!, fit: BoxFit.cover)
                          else
                            // Saved photos are not downloaded until the user
                            // asks, to avoid blob egress cost on every open.
                            Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const Icon(Icons.cloud_done_outlined, color: AppColors.success, size: 26),
                                const SizedBox(height: 4),
                                const Text(
                                  'Photo saved',
                                  style: TextStyle(color: AppColors.textMuted, fontSize: 12),
                                ),
                                const SizedBox(height: 6),
                                FilledButton.tonalIcon(
                                  onPressed: () => showNetworkImageDialog(context, imageUrl!, label),
                                  icon: const Icon(Icons.visibility_outlined, size: 16),
                                  label: const Text('View'),
                                  style: FilledButton.styleFrom(
                                    visualDensity: VisualDensity.compact,
                                    padding: const EdgeInsets.symmetric(horizontal: 14),
                                  ),
                                ),
                              ],
                            ),
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
