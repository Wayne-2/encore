import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';

import '../config/app_config.dart';
import '../navigation/app_route.dart';
import '../screens/image_crop_screen.dart';
import '../services/auth_service.dart';
import '../services/media_storage.dart';
import '../services/notification_service.dart';
import '../theme/app_type.dart';
import '../theme/spotify_colors.dart';
import 'shimmer.dart';

/// Opens the edit-profile sheet over the profile page.
///
/// Returns `true` when changes were saved so the caller can refresh.
Future<bool?> showEditProfileSheet(
  BuildContext context, {
  required String username,
  required String bio,
  String? photoUrl,
}) {
  return showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: SpotifyColors.surface,
    barrierColor: Colors.black.withValues(alpha: 0.6),
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(14)),
    ),
    builder: (context) =>
        EditProfileSheet(username: username, bio: bio, photoUrl: photoUrl),
  );
}

/// Bottom sheet for changing the avatar, username and bio.
class EditProfileSheet extends StatefulWidget {
  const EditProfileSheet({
    super.key,
    required this.username,
    required this.bio,
    this.photoUrl,
  });

  final String username;
  final String bio;
  final String? photoUrl;

  @override
  State<EditProfileSheet> createState() => _EditProfileSheetState();
}

class _EditProfileSheetState extends State<EditProfileSheet> {
  late final TextEditingController _username = TextEditingController(
    text: widget.username.replaceFirst(RegExp(r'^_+'), ''),
  );
  late final TextEditingController _bio = TextEditingController(
    text: widget.bio,
  );

  late String? _photoUrl = widget.photoUrl;
  Uint8List? _photoBytes;
  bool _uploading = false;
  bool _saving = false;
  String? _error;

  @override
  void dispose() {
    _username.dispose();
    _bio.dispose();
    super.dispose();
  }

  Future<void> _pickPhoto() async {
    final source = await _chooseSource();
    if (source == null) return;

    final picked = await ImagePicker().pickImage(
      source: source,
      imageQuality: 85,
      maxWidth: 1080,
    );
    if (picked == null) return;

    final bytes = await picked.readAsBytes();
    if (!mounted) return;

    final cropped = await Navigator.of(context).push<Uint8List>(
      sharedAxisRoute<Uint8List>(ImageCropScreen(image: bytes)),
    );
    if (cropped == null || !mounted) return;

    final contentType = _contentTypeFor(cropped);
    setState(() {
      _photoBytes = cropped;
      _uploading = true;
      _error = null;
    });

    final media = MediaStorage(workerUrl: AppConfig.r2WorkerUrl);
    try {
      final url = await media.upload(
        bytes: cropped,
        filename:
            'avatar-${DateTime.now().millisecondsSinceEpoch}'
            '.${contentType == 'image/png' ? 'png' : 'jpg'}',
        contentType: contentType,
      );
      if (!mounted) return;
      setState(() {
        _photoUrl = url;
        _uploading = false;
      });
    } catch (error) {
      debugPrint('Profile photo upload failed: $error');
      if (!mounted) return;
      setState(() {
        _photoBytes = null;
        _uploading = false;
        _error = 'Couldn’t upload that photo. Try again.';
      });
    } finally {
      media.dispose();
    }
  }

  Future<ImageSource?> _chooseSource() {
    return showModalBottomSheet<ImageSource>(
      context: context,
      backgroundColor: SpotifyColors.surfaceHover,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(14)),
      ),
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.photo_library_outlined),
              title: const Text('Choose from gallery'),
              onTap: () => Navigator.pop(context, ImageSource.gallery),
            ),
            ListTile(
              leading: const Icon(Icons.photo_camera_outlined),
              title: const Text('Take a photo'),
              onTap: () => Navigator.pop(context, ImageSource.camera),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _save() async {
    final handle = _username.text.trim().toLowerCase().replaceFirst(
      RegExp(r'^_+'),
      '',
    );

    if (handle.length < 3) {
      setState(() => _error = 'Your username needs at least 3 characters.');
      return;
    }
    if (_uploading) return;

    setState(() {
      _saving = true;
      _error = null;
    });

    try {
      final updated = await AuthService.instance.updateProfile(
        username: '_$handle',
        bio: _bio.text.trim(),
        photoUrl: _photoUrl,
      );
      if (updated) {
        try {
          await NotificationService.instance.showProfileUpdated();
        } catch (_) {
          // A blocked/failed notification must not stop the save.
        }
      }
      if (!mounted) return;
      Navigator.of(context).pop(true);
    } catch (error) {
      debugPrint('Profile save failed: $error');
      if (!mounted) return;
      setState(() {
        _saving = false;
        _error = 'Couldn’t save your changes. Try again.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: SafeArea(
        top: false,
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 10, 20, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 36,
                  height: 4,
                  decoration: BoxDecoration(
                    color: SpotifyColors.borderStrong,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              Text(
                'Edit profile',
                style: AppType.sectionTitle(scheme).copyWith(fontSize: 20),
              ),
              const SizedBox(height: 20),
              Center(child: _buildAvatar()),
              const SizedBox(height: 24),
              Text(
                'Username',
                style: AppType.meta(scheme).copyWith(
                  color: scheme.onSurface,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _username,
                autocorrect: false,
                textCapitalization: TextCapitalization.none,
                inputFormatters: [
                  FilteringTextInputFormatter.allow(RegExp('[a-zA-Z0-9_]')),
                  LengthLimitingTextInputFormatter(24),
                ],
                decoration: const InputDecoration(
                  prefixText: '_',
                  hintText: 'username',
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'Bio',
                style: AppType.meta(scheme).copyWith(
                  color: scheme.onSurface,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _bio,
                maxLines: 4,
                maxLength: 160,
                textCapitalization: TextCapitalization.sentences,
                decoration: const InputDecoration(
                  hintText: 'Tell people a little about yourself',
                ),
              ),
              if (_error != null) ...[
                const SizedBox(height: 4),
                Text(
                  _error!,
                  style: AppType.subtitle(
                    scheme,
                  ).copyWith(color: SpotifyColors.danger),
                ),
              ],
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                height: 48,
                child: FilledButton(
                  onPressed: _saving || _uploading ? null : _save,
                  child: _saving
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.black,
                          ),
                        )
                      : const Text('Save changes'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAvatar() {
    final Widget image;
    if (_photoBytes != null) {
      image = Image.memory(_photoBytes!, fit: BoxFit.cover);
    } else if (_photoUrl != null) {
      image = Image.network(
        _photoUrl!,
        fit: BoxFit.cover,
        errorBuilder: (_, _, _) => _placeholder(),
      );
    } else {
      image = _placeholder();
    }

    return SizedBox(
      width: 104,
      height: 104,
      child: Stack(
        fit: StackFit.expand,
        children: [
          ClipRRect(borderRadius: BorderRadius.circular(4), child: image),
          if (_uploading)
            const ClipRRect(
              borderRadius: BorderRadius.all(Radius.circular(4)),
              child: ShimmerBox(borderRadius: 4),
            ),
          Positioned(
            right: 0,
            bottom: 0,
            child: Material(
              color: SpotifyColors.accent,
              shape: const CircleBorder(),
              child: InkWell(
                onTap: _uploading ? null : _pickPhoto,
                customBorder: const CircleBorder(),
                child: const Padding(
                  padding: EdgeInsets.all(8),
                  child: Icon(
                    Icons.camera_alt_outlined,
                    size: 18,
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

  Widget _placeholder() {
    return Container(
      color: SpotifyColors.surfaceHover,
      alignment: Alignment.center,
      child: const Icon(
        Icons.person_outline,
        size: 52,
        color: SpotifyColors.textSubdued,
      ),
    );
  }

  /// The cropper re-encodes to JPEG or PNG (or BMP/ICO for those inputs), so
  /// sniff the bytes rather than trusting the picked file's extension.
  String _contentTypeFor(Uint8List bytes) {
    if (bytes.length >= 3 &&
        bytes[0] == 0xFF &&
        bytes[1] == 0xD8 &&
        bytes[2] == 0xFF) {
      return 'image/jpeg';
    }
    if (bytes.length >= 8 &&
        bytes[0] == 0x89 &&
        bytes[1] == 0x50 &&
        bytes[2] == 0x4E &&
        bytes[3] == 0x47) {
      return 'image/png';
    }
    if (bytes.length >= 2 && bytes[0] == 0x42 && bytes[1] == 0x4D) {
      return 'image/bmp';
    }
    return 'image/png';
  }
}
