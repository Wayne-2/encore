import 'package:flutter/material.dart';

import '../models/announcement.dart';
import '../theme/app_theme.dart';
import '../theme/slack_colors.dart';

/// Full-page view of a single announcement: sender, time, priority and the
/// complete message.
class AnnouncementDetailScreen extends StatelessWidget {
  const AnnouncementDetailScreen({super.key, required this.announcement});

  final Announcement announcement;

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
      body: ListView(
        padding: const EdgeInsets.all(16),
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
                    Text(
                      announcement.author,
                      style: TextStyle(
                        fontFamily: AppTheme.fontFamily,
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: scheme.onSurface,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      announcement.time,
                      style: TextStyle(
                        fontFamily: AppTheme.fontFamily,
                        fontSize: 13,
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            announcement.tag,
            style: TextStyle(
              fontFamily: AppTheme.fontFamily,
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: announcement.tagColor,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            announcement.body,
            style: TextStyle(
              fontFamily: AppTheme.fontFamily,
              fontSize: 15,
              height: 1.5,
              color: scheme.onSurface,
            ),
          ),
        ],
      ),
    );
  }
}
