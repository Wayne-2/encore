import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../models/chat_conversation.dart';
import '../models/direct_chat.dart';
import '../models/group_chat.dart';
import '../navigation/app_route.dart';
import '../services/auth_service.dart';
import '../services/chat_store.dart';
import '../theme/app_type.dart';
import '../theme/slack_type.dart';
import '../theme/spotify_colors.dart';
import '../widgets/app_loader.dart';
import '../widgets/chat_avatar.dart';
import '../widgets/compose_fab.dart';
import '../widgets/filter_pills.dart';
import '../widgets/floating_empty_state.dart';
import '../widgets/section_heading.dart';
import '../widgets/workspace_app_bar.dart';
import 'available_contacts_screen.dart';
import 'create_group_screen.dart';
import 'direct_chat_screen.dart';
import 'group_chat_screen.dart';
import 'persistent_direct_chat_screen.dart';
import 'persistent_group_chat_screen.dart';
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
/// - `New DM` opens [AvailableContactsScreen], where contact requests must be
///   accepted before a chat can be started.
/// - `# Conversations`: List of 1-on-1 direct chats and Firestore-backed
///   groups.
///   - Group items highlight the last sender's username in brand green.
///   - Tapping a group opens [PersistentGroupChatScreen]. The mock
///     [GroupChatScreen] remains for offline/demo use and widget tests.
///   - Tapping a direct chat opens [PersistentDirectChatScreen]. The mock
///     [DirectChatScreen] remains for offline/demo use and widget tests.
class MessagesScreen extends StatefulWidget {
  const MessagesScreen({super.key});

  @override
  State<MessagesScreen> createState() => _MessagesScreenState();
}

class _MessagesScreenState extends State<MessagesScreen> {
  Future<void> _onComposeAction(ComposeAction action) async {
    switch (action.label) {
      case 'New DM':
        await _startNewDm();
      case 'New Group':
        await _startNewGroup();
      case 'Add Story':
        _showSnack('Story creation is coming soon.');
    }
  }

  void _showSnack(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _startNewDm() async {
    if (!ChatStore.instance.isEnabled) {
      _showSnack('Sign in to message other members.');
      return;
    }

    await Navigator.of(
      context,
    ).push(sharedAxisRoute(const AvailableContactsScreen()));
  }

  Future<void> _startNewGroup() async {
    if (!ChatStore.instance.isEnabled) {
      _showSnack('Sign in to create a group.');
      return;
    }

    await Navigator.of(
      context,
    ).push(sharedAxisRoute(const CreateGroupScreen()));
  }

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
        Positioned.fill(
          child: ComposeFab(
            actions: _messagesComposeActions,
            onActionSelected: _onComposeAction,
          ),
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
  late final Stream<ChatInbox> _inbox = ChatStore.instance.watchInbox();
  int _filter = 0;

  List<ChatConversation> _filtered(List<ChatConversation> all) {
    return switch (_filter) {
      1 => all.where((c) => !c.isGroup).toList(),
      2 => all.where((c) => c.isGroup).toList(),
      3 => all.where((c) => c.hasUnread).toList(),
      _ => all,
    };
  }

  void _openMockChat(ChatConversation item) {
    if (item.isGroup) {
      Navigator.of(
        context,
      ).push(sharedAxisRoute(GroupChatScreen(conversation: item)));
    } else {
      Navigator.of(
        context,
      ).push(sharedAxisRoute(DirectChatScreen(conversation: item)));
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

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
        _buildContent(),
      ],
    );
  }

  Widget _buildContent() {
    if (!ChatStore.instance.isEnabled) {
      final conversations = _filtered(MockChatData.conversations);
      return _buildRows(
        List<ChatConversation>.of(conversations),
        onTap: _openMockChat,
        emptyMessage: 'No conversations yet.',
      );
    }

    return StreamBuilder<ChatInbox>(
      stream: _inbox,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return const Padding(
            padding: EdgeInsets.all(24),
            child: Center(
              child: Text(
                'Could not load conversations. Check your connection.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontFamily: 'Montserrat',
                  color: Colors.white70,
                ),
              ),
            ),
          );
        }
        if (!snapshot.hasData) {
          return const Padding(
            padding: EdgeInsets.all(24),
            child: Center(child: AppLoader()),
          );
        }

        final inbox = snapshot.data!;
        final myUid = AuthService.instance.currentUser?.uid ?? '';
        final entries =
            <({ChatConversation item, DateTime? activityAt})>[
              for (final chat in inbox.directChats)
                (
                  item: chat.toConversation(myUid: myUid),
                  activityAt: chat.lastMessageAt ?? chat.createdAt,
                ),
              for (final group in inbox.groups)
                (
                  item: group.toConversation(myUid: myUid),
                  activityAt: group.lastMessageAt ?? group.createdAt,
                ),
            ]..sort((a, b) {
              final aTime = a.activityAt;
              final bTime = b.activityAt;
              if (aTime == null && bTime == null) return 0;
              if (aTime == null) return 1;
              if (bTime == null) return -1;
              return bTime.compareTo(aTime);
            });
        final conversations = _filtered([
          for (final entry in entries) entry.item,
        ]);
        final chatsById = <String, Object>{
          for (final chat in inbox.directChats) chat.id: chat,
          for (final group in inbox.groups) group.id: group,
        };

        return _buildRows(
          conversations,
          onTap: (item) {
            final chat = chatsById[item.id];
            if (chat == null) return;
            Navigator.of(context).push(
              sharedAxisRoute(switch (chat) {
                DirectChat direct => PersistentDirectChatScreen(
                  chatId: direct.id,
                  peer: direct.peer,
                ),
                GroupChat group => PersistentGroupChatScreen(
                  chatId: group.id,
                  initialGroup: group,
                ),
                _ => const SizedBox.shrink(),
              }),
            );
          },
          emptyMessage: _filter == 2
              ? 'No group chats yet.'
              : _filter == 3
              ? 'You are all caught up.'
              : 'No conversations yet. Start a new message.',
        );
      },
    );
  }

  Widget _buildRows(
    List<ChatConversation> conversations, {
    required ValueChanged<ChatConversation> onTap,
    required String emptyMessage,
  }) {
    if (conversations.isEmpty) {
      return Padding(
        padding: const EdgeInsets.only(top: 24),
        child: FloatingEmptyState(
          key: const ValueKey('messages-empty'),
          icon: Icons.forum_outlined,
          message: emptyMessage,
        ),
      );
    }

    return Column(
      children: [
        for (var i = 0; i < conversations.length; i++) ...[
          if (i > 0)
            const Divider(height: 1, thickness: 1, color: SpotifyColors.border),
          _ConversationTile(
            item: conversations[i],
            onTap: () => onTap(conversations[i]),
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
                avatarUrl: item.avatarUrl,
                avatarColor: item.avatarColor,
                avatarInitials: item.avatarInitials,
                size: 36,
                borderRadius: BorderRadius.circular(4),
                showOnlineDot: item.isOnline,
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
                        Text(
                          item.time,
                          style: SlackType.timestamp(scheme).copyWith(
                            color: item.hasUnread ? SpotifyColors.accent : null,
                          ),
                        ),
                        if (item.hasUnread) ...[
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 5,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: SpotifyColors.accent,
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Text(
                              item.unreadCount > 9
                                  ? '9+'
                                  : item.unreadCount.toString(),
                              style: const TextStyle(
                                fontFamily: 'Montserrat',
                                fontSize: 9.5,
                                fontWeight: FontWeight.w700,
                                color: Colors.white,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 4),
                    if (item.isTyping)
                      Text(
                        'typing…',
                        style: SlackType.body(scheme).copyWith(
                          color: SpotifyColors.accent,
                          fontStyle: FontStyle.italic,
                        ),
                      )
                    else if (item.isGroup && item.lastMessageSender != null)
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
