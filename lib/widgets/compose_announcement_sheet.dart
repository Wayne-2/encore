import 'package:flutter/material.dart';

import '../data/departments.dart';
import '../services/auth_service.dart';
import '../theme/app_type.dart';
import '../theme/spotify_colors.dart';
import 'announcement_tile.dart';

/// The values collected by the compose sheet, ready to be published.
class AnnouncementDraft {
  const AnnouncementDraft({
    required this.author,
    required this.authorId,
    required this.tag,
    required this.tagColor,
    required this.body,
    this.photoUrl,
    this.department = '',
    this.level = '',
  });

  final String author;
  final String authorId;
  final String? photoUrl;
  final String department;
  final String level;
  final String tag;
  final Color tagColor;
  final String body;
}

/// A selectable announcement priority and its tag colour.
class AnnouncementPriority {
  const AnnouncementPriority(this.label, this.color);

  final String label;
  final Color color;
}

/// The three priorities shown as selectable pills, matching the feed tags.
const List<AnnouncementPriority> kAnnouncementPriorities = [
  AnnouncementPriority('Highly prior', SpotifyColors.tagUrgent),
  AnnouncementPriority('Less prior', SpotifyColors.tagMuted),
  AnnouncementPriority('General announcement', SpotifyColors.tagInfo),
];

/// Opens the themed compose sheet for a new announcement.
///
/// Completes with the drafted announcement once the sheet closes, or `null`
/// when the user dismisses it.
Future<AnnouncementDraft?> showComposeAnnouncementSheet(
  BuildContext context, {
  String? author,
}) {
  return showModalBottomSheet<AnnouncementDraft>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: SpotifyColors.surface,
    barrierColor: Colors.black.withValues(alpha: 0.6),
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(14)),
    ),
    builder: (_) => ComposeAnnouncementSheet(fallbackAuthor: author),
  );
}

/// Bottom sheet for writing and posting an announcement.
class ComposeAnnouncementSheet extends StatefulWidget {
  const ComposeAnnouncementSheet({super.key, this.fallbackAuthor});

  final String? fallbackAuthor;

  @override
  State<ComposeAnnouncementSheet> createState() =>
      _ComposeAnnouncementSheetState();
}

class _ComposeAnnouncementSheetState extends State<ComposeAnnouncementSheet> {
  final _body = TextEditingController();

  late String _author = widget.fallbackAuthor?.trim().isNotEmpty == true
      ? widget.fallbackAuthor!.trim()
      : 'You';
  final String? _authorId = AuthService.isAvailable
      ? AuthService.instance.currentUser?.uid
      : null;
  String? _photoUrl;
  String _department = '';
  String _level = '';
  AnnouncementPriority _priority = kAnnouncementPriorities[2];

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  @override
  void dispose() {
    _body.dispose();
    super.dispose();
  }

  Future<void> _loadProfile() async {
    if (!AuthService.isAvailable) return;
    try {
      final data = await AuthService.instance.currentUserProfile();
      if (!mounted || data == null) return;

      final name = (data['fullName'] as String?)?.trim();
      final photo = (data['photoUrl'] as String?)?.trim();
      final department = (data['department'] as String?)?.trim();
      final level = (data['level'] as String?)?.trim();

      setState(() {
        if (name != null && name.isNotEmpty) _author = name;
        if (photo != null && photo.isNotEmpty) _photoUrl = photo;
        if (department != null && department.isNotEmpty) {
          _department = normalizeDepartment(department);
        }
        if (level != null && level.isNotEmpty) _level = level;
      });
    } catch (_) {
      // Keep the fallback name.
    }
  }

  void _post() {
    final text = _body.text.trim();
    if (text.isEmpty) return;

    Navigator.of(context).pop(
      AnnouncementDraft(
        author: _author,
        authorId: _authorId ?? '',
        photoUrl: _photoUrl,
        department: _department,
        level: _level,
        tag: _priority.label,
        tagColor: _priority.color,
        body: text,
      ),
    );
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
              Row(
                children: [
                  AnnouncementAvatar(
                    name: _author,
                    photoUrl: _photoUrl,
                    size: 32,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      _author,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppType.name(scheme),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 18),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final priority in kAnnouncementPriorities)
                    _PriorityPill(
                      label: priority.label,
                      color: priority.color,
                      selected: priority == _priority,
                      onTap: () => setState(() => _priority = priority),
                    ),
                ],
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _body,
                minLines: 4,
                maxLines: 8,
                textCapitalization: TextCapitalization.sentences,
                style: AppType.body(scheme).copyWith(color: scheme.onSurface),
                decoration: InputDecoration(
                  hintText: 'Write your announcement…',
                  hintStyle: AppType.body(scheme),
                  border: InputBorder.none,
                  enabledBorder: InputBorder.none,
                  focusedBorder: InputBorder.none,
                  filled: false,
                  isDense: true,
                  contentPadding: EdgeInsets.zero,
                ),
              ),
              const SizedBox(height: 20),
              ValueListenableBuilder<TextEditingValue>(
                valueListenable: _body,
                builder: (context, value, _) {
                  final ready = value.text.trim().isNotEmpty;
                  return SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: FilledButton(
                      onPressed: ready ? _post : null,
                      child: const Text('Post announcement'),
                    ),
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PriorityPill extends StatelessWidget {
  const _PriorityPill({
    required this.label,
    required this.color,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final Color color;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected ? color.withValues(alpha: 0.18) : Colors.transparent,
      borderRadius: BorderRadius.circular(999),
      child: InkWell(
        borderRadius: BorderRadius.circular(999),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(999),
            border: Border.all(
              color: selected ? color : SpotifyColors.borderStrong,
            ),
          ),
          child: Text(
            label,
            style: AppType.tag(selected ? color : SpotifyColors.textSubdued),
          ),
        ),
      ),
    );
  }
}
