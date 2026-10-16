import 'package:flutter/material.dart';

import '../models/chat_conversation.dart';
import '../navigation/app_route.dart';
import '../theme/app_theme.dart';
import '../theme/slack_colors.dart';
import '../widgets/chat_avatar.dart';
import '../widgets/section_heading.dart';
import '../widgets/workspace_app_bar.dart';
import 'direct_chat_screen.dart';
import 'group_chat_screen.dart';
import 'story_viewer_screen.dart';

/// The Messages section — the second tab of [HomeShell].
///
/// Features:
/// - Top bar: Workspace anchor icon, "Messages" heading, and Encore logo.
/// - `# Story` reel: Horizontal status list with squircle avatars, active online
///   presence dots, and usernames. Tapping opens a WhatsApp/Instagram style
///   StoryViewer with progress and replies.
/// - `# Conversations`: List of 1-on-1 direct chats and WhatsApp-style groups.
///   - Group items highlight the sender's username in brand green.
///   - Tapping a group opens the WhatsApp-style [GroupChatScreen] with the
///     Admin Anonymous Mode feature accessible via the paperclip icon.
///   - Tapping a direct chat opens the 1-on-1 [DirectChatScreen].
class MessagesScreen extends StatelessWidget {
  const MessagesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        const WorkspaceAppBar(
          heading: 'Messages',
          headingSize: 20,
          headingWeight: FontWeight.w700,
        ),
        Expanded(
          child: ListView(
            padding: EdgeInsets.zero,
            children: [
              const SizedBox(height: 12),
              const _StorySection(),
              const SizedBox(height: 18),
              const _ConversationsSection(),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ],
    );
  }
}

/// Horizontal story/status row under `# Story`.
class _StorySection extends StatelessWidget {
  const _StorySection();

  @override
  Widget build(BuildContext context) {
    final stories = MockChatData.stories;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 16),
          child: SectionHeading('Story'),
        ),
        const SizedBox(height: 10),
        SizedBox(
          height: 94,
          child: ListView.separated(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            scrollDirection: Axis.horizontal,
            itemCount: stories.length,
            separatorBuilder: (_, _) => const SizedBox(width: 14),
            itemBuilder: (context, index) {
              final story = stories[index];
              return _StoryTile(
                story: story,
                onTap: () {
                  Navigator.of(context).push(
                    fadeRoute(StoryViewerScreen(story: story)),
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }
}

class _StoryTile extends StatelessWidget {
  const _StoryTile({required this.story, required this.onTap});

  final StoryItem story;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ChatAvatar(
            avatarAsset: story.avatarAsset,
            avatarColor: story.avatarColor,
            avatarInitials: story.avatarText,
            size: 60,
            showOnlineDot: true,
          ),
          const SizedBox(height: 6),
          Text(
            story.username,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontFamily: AppTheme.fontFamily,
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: SlackColors.darkTextPrimary,
            ),
          ),
        ],
      ),
    );
  }
}

/// Vertical conversations list under `# Conversations`.
class _ConversationsSection extends StatelessWidget {
  const _ConversationsSection();

  @override
  Widget build(BuildContext context) {
    final conversations = MockChatData.conversations;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 16),
          child: SectionHeading('Conversations'),
        ),
        const SizedBox(height: 4),
        ListView.separated(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          padding: EdgeInsets.zero,
          itemCount: conversations.length,
          separatorBuilder: (_, _) => Divider(
            color: SlackColors.darkBorder.withValues(alpha: 0.35),
            height: 1,
            indent: 80,
            endIndent: 16,
          ),
          itemBuilder: (context, index) {
            final item = conversations[index];
            return _ConversationTile(
              item: item,
              onTap: () {
                if (item.isGroup) {
                  Navigator.of(context).push(
                    sharedAxisRoute(GroupChatScreen(conversation: item)),
                  );
                } else {
                  Navigator.of(context).push(
                    sharedAxisRoute(DirectChatScreen(conversation: item)),
                  );
                }
              },
            );
          },
        ),
      ],
    );
  }
}

class _ConversationTile extends StatelessWidget {
  const _ConversationTile({required this.item, required this.onTap});

  final ChatConversation item;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 11),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Squircle avatar matching screenshot
            ChatAvatar(
              avatarAsset: item.avatarAsset,
              avatarColor: item.avatarColor,
              avatarInitials: item.avatarInitials,
              size: 52,
            ),
            const SizedBox(width: 12),

            // Middle: Name, timestamp, and message preview
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Title + Timestamp + Unread dot
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          item.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontFamily: AppTheme.fontFamily,
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                            color: Colors.white,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        item.time,
                        style: const TextStyle(
                          fontFamily: AppTheme.fontFamily,
                          fontSize: 12,
                          color: SlackColors.darkTextSecondary,
                        ),
                      ),
                      if (item.hasUnread) ...[
                        const SizedBox(width: 6),
                        Container(
                          width: 8,
                          height: 8,
                          decoration: const BoxDecoration(
                            color: SlackColors.accentGreen,
                            shape: BoxShape.circle,
                          ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 4),

                  // Message snippet
                  if (item.isGroup && item.lastMessageSender != null)
                    Text.rich(
                      TextSpan(
                        style: TextStyle(
                          fontFamily: AppTheme.fontFamily,
                          fontSize: 13,
                          height: 1.3,
                          color: scheme.onSurfaceVariant,
                        ),
                        children: [
                          TextSpan(
                            text: '${item.lastMessageSender}: ',
                            style: const TextStyle(
                              color: SlackColors.accentGreen,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          TextSpan(text: item.lastMessage),
                        ],
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    )
                  else
                    Text(
                      item.lastMessage,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontFamily: AppTheme.fontFamily,
                        fontSize: 13,
                        height: 1.3,
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
