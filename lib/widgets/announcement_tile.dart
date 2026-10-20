import 'package:flutter/material.dart';

import '../models/announcement.dart';
import '../theme/app_type.dart';
import '../theme/slack_type.dart';
import '../theme/spotify_colors.dart';

/// A single announcement row, matching Slack's message-list dimensions:
/// a 36dp rounded-square avatar, a bold 15sp sender, a 12sp timestamp and
/// Slack's 15sp body copy over 16/8 padding.
class AnnouncementTile extends StatelessWidget {
  const AnnouncementTile({
    super.key,
    required this.announcement,
    required this.onTap,
  });

  final Announcement announcement;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              AnnouncementAvatar(photoUrl: announcement.photoUrl),
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
                        Text(
                          announcement.time,
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
  }
}

/// The poster's profile picture, or a subdued person glyph when they do not
/// have one.
class AnnouncementAvatar extends StatelessWidget {
  const AnnouncementAvatar({super.key, this.photoUrl, this.size = 36});

  final String? photoUrl;
  final double size;

  @override
  Widget build(BuildContext context) {
    final placeholder = Container(
      width: size,
      height: size,
      color: SpotifyColors.surfaceHover,
      alignment: Alignment.center,
      child: Icon(
        Icons.person_outline,
        size: size * 0.55,
        color: SpotifyColors.textSubdued,
      ),
    );

    return ClipRRect(
      borderRadius: BorderRadius.circular(4),
      child: SizedBox(
        width: size,
        height: size,
        child: photoUrl == null
            ? placeholder
            : Image.network(
                photoUrl!,
                fit: BoxFit.cover,
                errorBuilder: (_, _, _) => placeholder,
              ),
      ),
    );
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
