import 'dart:async';

import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../models/chat_conversation.dart';
import '../models/direct_chat.dart';
import '../models/group_chat.dart';
import '../navigation/app_route.dart';
import '../services/auth_service.dart';
import '../services/chat_store.dart';
import '../theme/app_type.dart';
import '../theme/slack_type.dart';
import '../utils/active_time.dart';
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
  ComposeAction(label: 'Add Story', icon: LucideIcons.bookOpen),
  ComposeAction(label: 'New DM', iconAsset: 'assets/icons/messages.svg'),
  ComposeAction(label: 'New Group', icon: LucideIcons.userPlus),
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
              child: CustomScrollView(
                slivers: [
                  const SliverToBoxAdapter(child: SizedBox(height: 12)),
                  const SliverToBoxAdapter(child: _StorySection()),
                  const SliverToBoxAdapter(child: SizedBox(height: 24)),
                  const _ConversationsSection(),
                  const SliverToBoxAdapter(child: SizedBox(height: 24)),
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
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocus = FocusNode();
  final Set<String> _locallyDeleted = {};
  int _filter = 0;
  bool _searching = false;
  String _query = '';

  @override
  void dispose() {
    _searchController.dispose();
    _searchFocus.dispose();
    super.dispose();
  }

  List<ChatConversation> _filtered(List<ChatConversation> all) {
    final filtered = switch (_filter) {
      1 => all.where((c) => !c.isGroup).toList(),
      2 => all.where((c) => c.isGroup).toList(),
      3 => all.where((c) => c.hasUnread).toList(),
      _ => all,
    };
    final query = _query.trim().toLowerCase();
    if (query.isEmpty) return filtered;

    return filtered
        .where((conversation) {
          return conversation.title.toLowerCase().contains(query) ||
              conversation.lastMessage.toLowerCase().contains(query) ||
              (conversation.lastMessageSender ?? '').toLowerCase().contains(
                query,
              ) ||
              conversation.membersDescription.toLowerCase().contains(query);
        })
        .toList(growable: false);
  }

  void _openSearch() {
    setState(() => _searching = true);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _searchFocus.requestFocus();
    });
  }

  void _closeSearch() {
    _searchController.clear();
    _searchFocus.unfocus();
    setState(() {
      _searching = false;
      _query = '';
    });
  }

  void _showSnack(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  void _onMoreSelected(String value) {
    switch (value) {
      case 'archive':
        _showSnack('Archived conversations are coming soon.');
      case 'settings':
        _showSnack('Message settings are coming soon.');
    }
  }

  Future<bool> _confirmDeleteConversation(ChatConversation item) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: SpotifyColors.surface,
        title: const Text('Delete chat?'),
        content: Text(
          'This removes ${item.title} from your conversations. '
          'New messages will still appear in a fresh conversation.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            style: FilledButton.styleFrom(
              backgroundColor: SpotifyColors.danger,
            ),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    return confirmed == true;
  }

  Future<void> _deleteConversation(ChatConversation item) async {
    final cleared = await ChatStore.instance.clearChat(item.id);
    if (!mounted) return;
    if (!cleared) {
      setState(() => _locallyDeleted.remove(item.id));
      _showSnack('Could not delete this chat. Try again.');
      return;
    }
    _showSnack('Chat deleted from your end.');
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

    return SliverMainAxisGroup(
      slivers: [
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 8, 0),
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 240),
              switchInCurve: Curves.easeOutCubic,
              switchOutCurve: Curves.easeInCubic,
              transitionBuilder: (child, animation) {
                return SizeTransition(
                  sizeFactor: animation,
                  axis: Axis.horizontal,
                  alignment: Alignment.centerLeft,
                  child: FadeTransition(opacity: animation, child: child),
                );
              },
              child: _searching
                  ? _buildSearchBar(scheme)
                  : _buildHeaderActions(scheme),
            ),
          ),
        ),
        const SliverToBoxAdapter(child: SizedBox(height: 12)),
        SliverToBoxAdapter(
          child: FilterPills(
            filters: _filters,
            selected: _filter,
            onSelected: (i) => setState(() => _filter = i),
            fontSize: 12,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SliverToBoxAdapter(child: SizedBox(height: 8)),
        _buildContent(),
      ],
    );
  }

  Widget _buildHeaderActions(ColorScheme scheme) {
    return Row(
      key: const ValueKey('conversations-header'),
      children: [
        SectionHeading(
          'Conversations',
          style: SlackType.sectionTitle(scheme),
          glyphStyle: SlackType.glyph(scheme),
        ),
        const Spacer(),
        IconButton(
          key: const ValueKey('conversations-search-open'),
          onPressed: _openSearch,
          icon: SvgPicture.asset(
            'assets/icons/searching.svg',
            width: 20,
            height: 20,
            colorFilter: ColorFilter.mode(scheme.onSurface, BlendMode.srcIn),
          ),
          tooltip: 'Search conversations',
          padding: EdgeInsets.zero,
          constraints: const BoxConstraints.tightFor(width: 36, height: 36),
          visualDensity: VisualDensity.compact,
        ),
        const SizedBox(width: 6),
        PopupMenuButton<String>(
          key: const ValueKey('conversations-more'),
          tooltip: 'Conversation options',
          padding: EdgeInsets.zero,
          position: PopupMenuPosition.under,
          color: SpotifyColors.surface,
          onSelected: _onMoreSelected,
          itemBuilder: (context) => const [
            PopupMenuItem(
              value: 'archive',
              child: Row(
                children: [
                  Icon(LucideIcons.archive, size: 18),
                  SizedBox(width: 10),
                  Text('Archive'),
                ],
              ),
            ),
            PopupMenuItem(
              value: 'settings',
              child: Row(
                children: [
                  Icon(LucideIcons.slidersHorizontal, size: 18),
                  SizedBox(width: 10),
                  Text('Message settings'),
                ],
              ),
            ),
          ],
          child: SizedBox(
            width: 36,
            height: 36,
            child: Center(
              child: SvgPicture.asset(
                'assets/icons/option.svg',
                width: 20,
                height: 20,
                colorFilter: ColorFilter.mode(
                  scheme.onSurface,
                  BlendMode.srcIn,
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSearchBar(ColorScheme scheme) {
    return Container(
      key: const ValueKey('conversations-search'),
      height: 36,
      decoration: BoxDecoration(
        color: SpotifyColors.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: SpotifyColors.border),
      ),
      child: Row(
        children: [
          const SizedBox(width: 11),
          SvgPicture.asset(
            'assets/icons/searching.svg',
            width: 17,
            height: 17,
            colorFilter: ColorFilter.mode(
              scheme.onSurfaceVariant,
              BlendMode.srcIn,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: TextField(
              key: const ValueKey('conversations-search-field'),
              controller: _searchController,
              focusNode: _searchFocus,
              onChanged: (value) => setState(() => _query = value),
              textInputAction: TextInputAction.search,
              style: TextStyle(
                fontFamily: 'Montserrat',
                fontSize: 13,
                color: scheme.onSurface,
              ),
              decoration: InputDecoration(
                isDense: true,
                hintText: 'Search conversations',
                hintStyle: TextStyle(
                  fontFamily: 'Montserrat',
                  fontSize: 13,
                  color: scheme.onSurfaceVariant,
                ),
                border: InputBorder.none,
                enabledBorder: InputBorder.none,
                focusedBorder: InputBorder.none,
                contentPadding: EdgeInsets.zero,
              ),
            ),
          ),
          IconButton(
            key: const ValueKey('conversations-search-close'),
            onPressed: _closeSearch,
            icon: Icon(LucideIcons.x, size: 18, color: scheme.onSurfaceVariant),
            tooltip: 'Close search',
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints.tightFor(width: 34, height: 34),
            visualDensity: VisualDensity.compact,
          ),
        ],
      ),
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
          return const SliverFillRemaining(
            hasScrollBody: false,
            child: Center(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: Text(
                  'Could not load conversations. Check your connection.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontFamily: 'Montserrat',
                    color: Colors.white70,
                  ),
                ),
              ),
            ),
          );
        }
        if (!snapshot.hasData) {
          return const SliverFillRemaining(
            hasScrollBody: false,
            child: Center(child: AppLoader()),
          );
        }

        final inbox = snapshot.data!;
        final myUid = AuthService.instance.currentUser?.uid ?? '';
        final entries =
            <({ChatConversation item, DateTime? activityAt})>[
              for (final chat in inbox.directChats)
                if (!(_locallyDeleted.contains(chat.id) && chat.isCleared))
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
          onDelete: _confirmDeleteConversation,
          onDismissed: (item) {
            setState(() => _locallyDeleted.add(item.id));
            unawaited(_deleteConversation(item));
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
    Future<bool> Function(ChatConversation)? onDelete,
    ValueChanged<ChatConversation>? onDismissed,
  }) {
    if (conversations.isEmpty) {
      final query = _query.trim();
      final message = query.isEmpty
          ? emptyMessage
          : 'No conversations match “$query”.';
      return SliverFillRemaining(
        hasScrollBody: false,
        child: Center(
          child: FloatingEmptyState(
            key: const ValueKey('messages-empty'),
            iconAsset: 'assets/icons/messages.svg',
            message: message,
          ),
        ),
      );
    }

    return SliverToBoxAdapter(
      child: Column(
        children: [
          for (var i = 0; i < conversations.length; i++) ...[
            if (i > 0)
              const Divider(
                height: 1,
                thickness: 1,
                color: SpotifyColors.border,
              ),
            if (onDelete != null && !conversations[i].isGroup)
              Dismissible(
                key: ValueKey('conversation-swipe-${conversations[i].id}'),
                direction: DismissDirection.endToStart,
                confirmDismiss: (_) => onDelete(conversations[i]),
                onDismissed: (_) => onDismissed?.call(conversations[i]),
                background: Container(
                  color: SpotifyColors.danger,
                  alignment: Alignment.centerRight,
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(LucideIcons.trash2, color: Colors.white),
                      SizedBox(width: 6),
                      Text(
                        'Delete',
                        style: TextStyle(
                          fontFamily: 'Montserrat',
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: Colors.white,
                        ),
                      ),
                    ],
                  ),
                ),
                child: _ConversationTile(
                  item: conversations[i],
                  onTap: () => onTap(conversations[i]),
                ),
              )
            else
              _ConversationTile(
                item: conversations[i],
                onTap: () => onTap(conversations[i]),
              ),
          ],
        ],
      ),
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
                        ActiveTimestamp(
                          at: item.updatedAt,
                          fallback: item.time,
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
