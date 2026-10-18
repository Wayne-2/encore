import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../models/chat_conversation.dart';
import '../navigation/app_route.dart';
import '../theme/app_type.dart';
import '../theme/slack_type.dart';
import '../theme/spotify_colors.dart';
import '../widgets/chat_avatar.dart';
import '../widgets/compose_fab.dart';
import '../widgets/filter_pills.dart';
import '../widgets/section_heading.dart';
import '../widgets/workspace_app_bar.dart';
import 'direct_chat_screen.dart';
import 'group_chat_screen.dart';
import 'story_viewer_screen.dart';

/// Quick actions revealed by the Messages compose button.
const List<ComposeAction> _messagesComposeActions = [
  (label: 'Add Story', icon: Icons.auto_stories_outlined),
  (label: 'New DM', icon: Icons.edit_outlined),
  (label: 'New Group', icon: Icons.group_add_outlined),
];

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
    return Stack(
      children: [
        Column(
          children: [
            const WorkspaceAppBar(heading: 'Messages'),
            Expanded(
              child: ListView(
                padding: EdgeInsets.zero,
                children: [
                  const SizedBox(height: 12),
                  const _StorySection(),
                  const SizedBox(height: 24),
                  const _ConversationsSection(),
                  const SizedBox(height: 24),
                ],
              ),
            ),
          ],
        ),
        const Positioned.fill(
          child: ComposeFab(actions: _messagesComposeActions),
        ),
      ],
    );
  }
}

/// Horizontal story/status row.
class _StorySection extends StatelessWidget {
  const _StorySection();

  @override
  Widget build(BuildContext context) {
    final stories = MockChatData.stories;

    return SizedBox(
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
              Navigator.of(
                context,
              ).push(fadeRoute(StoryViewerScreen(story: story)));
            },
          );
        },
      ),
    );
  }
}

class _StoryTile extends StatelessWidget {
  const _StoryTile({required this.story, required this.onTap});

  final StoryItem story;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

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
            style: AppType.cardTitle(
              scheme,
            ).copyWith(fontWeight: FontWeight.w500, color: scheme.onSurface),
          ),
        ],
      ),
    );
  }
}

/// Vertical conversations list under `# Conversations`, with All / DMs /
/// Groups / Unread filters.
class _ConversationsSection extends StatefulWidget {
  const _ConversationsSection();

  @override
  State<_ConversationsSection> createState() => _ConversationsSectionState();
}

class _ConversationsSectionState extends State<_ConversationsSection> {
  static const List<String> _filters = ['All', 'DMs', 'Groups', 'Unread'];
  int _filter = 0;

  List<ChatConversation> get _items {
    final all = MockChatData.conversations;
    return switch (_filter) {
      1 => all.where((c) => !c.isGroup).toList(),
      2 => all.where((c) => c.isGroup).toList(),
      3 => all.where((c) => c.hasUnread).toList(),
      _ => all,
    };
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final conversations = _items;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 8, 0),
          child: Row(
            children: [
              SectionHeading(
                'Conversations',
                style: SlackType.sectionTitle(scheme),
                glyphStyle: SlackType.glyph(scheme),
              ),
              const Spacer(),
              SvgPicture.asset(
                'assets/icons/searching.svg',
                width: 20,
                height: 20,
                colorFilter: ColorFilter.mode(
                  scheme.onSurface,
                  BlendMode.srcIn,
                ),
              ),
              const SizedBox(width: 16),
              SvgPicture.asset(
                'assets/icons/option.svg',
                width: 20,
                height: 20,
                colorFilter: ColorFilter.mode(
                  scheme.onSurface,
                  BlendMode.srcIn,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        FilterPills(
          filters: _filters,
          selected: _filter,
          onSelected: (i) => setState(() => _filter = i),
          fontSize: 12,
          fontWeight: FontWeight.w500,
        ),
        const SizedBox(height: 8),
        for (var i = 0; i < conversations.length; i++) ...[
          if (i > 0)
            const Divider(height: 1, thickness: 1, color: SpotifyColors.border),
          _ConversationTile(
            item: conversations[i],
            onTap: () {
              final item = conversations[i];
              if (item.isGroup) {
                Navigator.of(
                  context,
                ).push(sharedAxisRoute(GroupChatScreen(conversation: item)));
              } else {
                Navigator.of(
                  context,
                ).push(sharedAxisRoute(DirectChatScreen(conversation: item)));
              }
            },
          ),
        ],
      ],
    );
  }
}

/// A Slack-style DM row: a 36dp rounded-square avatar, a bold 15sp name with a
/// right-aligned 12sp timestamp, and up to two lines of 15sp preview copy over
/// 16/10 padding — matching the announcement feed's dimensions and fonts.
class _ConversationTile extends StatelessWidget {
  const _ConversationTile({required this.item, required this.onTap});

  final ChatConversation item;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ChatAvatar(
                avatarAsset: item.avatarAsset,
                avatarColor: item.avatarColor,
                avatarInitials: item.avatarInitials,
                size: 36,
                borderRadius: BorderRadius.circular(4),
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
                            item.title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: SlackType.sender(scheme),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(item.time, style: SlackType.timestamp(scheme)),
                      ],
                    ),
                    const SizedBox(height: 4),
                    if (item.isGroup && item.lastMessageSender != null)
                      Text.rich(
                        TextSpan(
                          style: SlackType.body(scheme),
                          children: [
                            TextSpan(
                              text: '${item.lastMessageSender}: ',
                              style: const TextStyle(
                                color: SpotifyColors.accent,
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
