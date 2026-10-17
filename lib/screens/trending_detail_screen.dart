import 'package:flutter/material.dart';

import '../models/comment.dart';
import '../models/trend.dart';
import '../theme/app_theme.dart';
import '../theme/app_type.dart';
import '../theme/slack_colors.dart';
import '../widgets/comment_thread.dart';
import '../widgets/reaction_bar.dart';

/// Full-page view of a single trend: its image, title, author, time and body —
/// followed by the same Twitter-style comment thread as announcements.
class TrendingDetailScreen extends StatelessWidget {
  const TrendingDetailScreen({super.key, required this.trend});

  final Trend trend;

  static const List<Comment> _comments = [
    Comment(
      name: 'Nana Adjei',
      handle: '_nana_a',
      time: '3h',
      text: 'Great to see this on the board — been waiting for it.',
      initials: 'NA',
      reactions: {'🔥': 6, '🎉': 3},
    ),
    Comment(
      name: 'Akosua Frimpong',
      handle: '_akosua',
      time: '1h',
      text: 'Will there be a virtual option for those off campus?',
      initials: 'AF',
      reactions: {'👍': 2},
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
          'Trending',
          style: TextStyle(
            fontFamily: AppTheme.fontFamily,
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: scheme.onSurface,
          ),
        ),
      ),
      body: CommentThread(
        header: _TrendHeader(trend: trend),
        initialComments: _comments,
      ),
    );
  }
}

/// The trend post shown above its comment thread.
class _TrendHeader extends StatelessWidget {
  const _TrendHeader({required this.trend});

  final Trend trend;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: Image.asset(
              trend.image,
              width: double.infinity,
              height: 190,
              fit: BoxFit.cover,
            ),
          ),
          const SizedBox(height: 16),
          Text(trend.title, style: AppType.name(scheme)),
          const SizedBox(height: 6),
          Row(
            children: [
              Text(trend.author, style: AppType.cardTitle(scheme)),
              const SizedBox(width: 6),
              Container(
                width: 3,
                height: 3,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: scheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(width: 6),
              Text(trend.time, style: AppType.meta(scheme)),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            trend.body,
            style: TextStyle(
              fontFamily: AppTheme.fontFamily,
              fontSize: 13,
              height: 1.35,
              color: scheme.onSurface,
            ),
          ),
          const SizedBox(height: 12),
          const ReactionBar(initial: {'🔥': 5, '👏': 2}),
        ],
      ),
    );
  }
}
