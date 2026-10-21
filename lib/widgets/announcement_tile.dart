import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../models/announcement.dart';
import '../theme/app_type.dart';
import '../theme/slack_type.dart';
import '../theme/spotify_colors.dart';
import '../utils/active_time.dart';
import 'user_avatar.dart';

/// A single announcement row, matching Slack's message-list dimensions:
/// a 36dp rounded-square avatar, a bold 15sp sender, a 12sp timestamp and
/// Slack's 15sp body copy over 16/8 padding.
class AnnouncementTile extends StatelessWidget {
  const AnnouncementTile({
    super.key,
    required this.announcement,
    required this.onTap,
    this.viewerId,
    this.onDelete,
  });

  final Announcement announcement;
  final VoidCallback onTap;

  /// The signed-in user, used to decide whether the post can be swiped away.
  final String? viewerId;

  /// Called after the swipe-away animation completes.
  final ValueChanged<Announcement>? onDelete;

  bool get _canDelete =>
      onDelete != null && announcement.canBeDeletedBy(viewerId);

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    final tile = Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              AnnouncementAvatar(
                name: announcement.author,
                photoUrl: announcement.photoUrl,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            announcement.author,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: SlackType.sender(scheme),
                          ),
                        ),
                        const SizedBox(width: 8),
                        ActiveTimestamp(
                          at: announcement.createdAt,
                          fallback: announcement.time,
                          style: SlackType.timestamp(scheme),
                        ),
                        if (announcement.unread) ...[
                          const SizedBox(width: 6),
                          Container(
                            width: 8,
                            height: 8,
                            decoration: const BoxDecoration(
                              color: SpotifyColors.accent,
                              shape: BoxShape.circle,
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 4),
                    AnnouncementTagBadge(
                      label: announcement.tag,
                      color: announcement.tagColor,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      announcement.body,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: SlackType.body(scheme),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );

    if (!_canDelete) return tile;

    final id = announcement.id.isNotEmpty
        ? announcement.id
        : '${identityHashCode(announcement)}';

    return Dismissible(
      key: ValueKey('announcement-dismissible-$id'),
      direction: DismissDirection.endToStart,
      dismissThresholds: const {DismissDirection.endToStart: 0.35},
      movementDuration: const Duration(milliseconds: 220),
      resizeDuration: const Duration(milliseconds: 260),
      background: _DeleteBackground(id: id),
      onDismissed: (_) => onDelete?.call(announcement),
      child: tile,
    );
  }
}

/// The green, right-aligned panel revealed while an authored announcement is
/// swiped to the left.
class _DeleteBackground extends StatelessWidget {
  const _DeleteBackground({required this.id});

  final String id;

  @override
  Widget build(BuildContext context) {
    return Container(
      key: ValueKey('announcement-delete-bg-$id'),
      color: SpotifyColors.accent,
      alignment: Alignment.centerRight,
      padding: const EdgeInsets.symmetric(horizontal: 22),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(LucideIcons.trash2, size: 20, color: Colors.white),
          const SizedBox(width: 6),
          Text(
            'Delete',
            style: AppType.subtitle(
              Theme.of(context).colorScheme,
            ).copyWith(color: Colors.white, fontWeight: FontWeight.w700),
          ),
        ],
      ),
    );
  }
}

/// The poster's profile picture, or their initials when they do not have one.
class AnnouncementAvatar extends StatelessWidget {
  const AnnouncementAvatar({
    super.key,
    required this.name,
    this.photoUrl,
    this.size = 36,
  });

  final String name;
  final String? photoUrl;
  final double size;

  @override
  Widget build(BuildContext context) {
    return UserAvatar(name: name, photoUrl: photoUrl, size: size);
  }
}

/// Small coloured priority label shown under the sender's name.
class AnnouncementTagBadge extends StatelessWidget {
  const AnnouncementTagBadge({
    super.key,
    required this.label,
    required this.color,
  });

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) => Text(label, style: AppType.tag(color));
}
