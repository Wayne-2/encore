import 'package:flutter/material.dart';

import '../models/announcement.dart';
import '../models/comment.dart';
import '../theme/app_theme.dart';
import '../theme/app_type.dart';
import '../theme/slack_colors.dart';
import '../widgets/comment_thread.dart';
import '../widgets/reaction_bar.dart';

/// Full-page view of a single announcement: sender, time, priority and the
/// complete message — followed by a Twitter-style comment thread.
class AnnouncementDetailScreen extends StatelessWidget {
  const AnnouncementDetailScreen({super.key, required this.announcement});

  final Announcement announcement;

  static const List<Comment> _comments = [
    Comment(
      name: 'Ama Boateng',
      handle: '_ama_boateng',
      time: '2h',
      text:
          'Thanks for the heads up! Will the lab report template be shared '
          'too?',
      initials: 'AB',
      reactions: {'👍': 4, '🙌': 1},
    ),
    Comment(
      name: 'Kwame Mensah',
      handle: '_kwame_m',
      time: '1h',
      text: 'Noted, submitting mine tonight.',
      initials: 'KM',
      reactions: {'🎉': 2},
    ),
    Comment(
      name: 'Efua Owusu',
      handle: '_efua.o',
      time: '45m',
      text: 'Could we get a short extension? Some of us have labs that day.',
      initials: 'EO',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Scaffold(
      backgroundColor: SlackColors.darkBackground,
      appBar: AppBar(
        backgroundColor: SlackColors.darkHeader,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new),
          color: scheme.onSurface,
          onPressed: () => Navigator.of(context).maybePop(),
        ),
        title: Text(
          'Announcement',
          style: TextStyle(
            fontFamily: AppTheme.fontFamily,
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: scheme.onSurface,
          ),
        ),
      ),
      body: CommentThread(
        header: _AnnouncementHeader(announcement: announcement),
        initialComments: _comments,
      ),
    );
  }
}

/// The announcement post shown above its comment thread.
class _AnnouncementHeader extends StatelessWidget {
  const _AnnouncementHeader({required this.announcement});

  final Announcement announcement;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              ClipOval(
                child: Image.asset(
                  'assets/launch_icon_foreground.png',
                  width: 56,
                  height: 56,
                  fit: BoxFit.cover,
                  filterQuality: FilterQuality.medium,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(announcement.author, style: AppType.name(scheme)),
                    const SizedBox(height: 2),
                    Text(announcement.time, style: AppType.meta(scheme)),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text(announcement.tag, style: AppType.tag(announcement.tagColor)),
          const SizedBox(height: 12),
          Text(
            announcement.body,
            style: TextStyle(
              fontFamily: AppTheme.fontFamily,
              fontSize: 13,
              height: 1.35,
              color: scheme.onSurface,
            ),
          ),
          const SizedBox(height: 12),
          const ReactionBar(initial: {'👍': 8, '🎉': 2}),
        ],
      ),
    );
  }
}
