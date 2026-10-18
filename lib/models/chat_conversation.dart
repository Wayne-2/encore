import 'package:flutter/material.dart';

import '../theme/spotify_colors.dart';

/// A single story / status item shown in the horizontal `# Story` reel.
class StoryItem {
  const StoryItem({
    required this.id,
    required this.username,
    this.avatarAsset,
    this.avatarColor,
    this.avatarText,
    this.hasUnread = true,
    required this.storyImage,
    required this.time,
    this.caption,
  });

  final String id;
  final String username;
  final String? avatarAsset;
  final Color? avatarColor;
  final String? avatarText;
  final bool hasUnread;
  final String storyImage;
  final String time;
  final String? caption;
}

/// A chat bubble message within a group or 1-on-1 direct conversation.
class ChatMessage {
  const ChatMessage({
    required this.id,
    this.senderName,
    this.senderColor,
    this.senderAvatar,
    required this.text,
    required this.time,
    this.isMe = false,
    this.isAnonymous = false,
    this.isNotice = false,
    this.isAdmin = false,
  });

  final String id;
  final String? senderName;
  final Color? senderColor;
  final String? senderAvatar;
  final String text;
  final String time;
  final bool isMe;

  /// In anonymous mode, messages do not carry the sender's real ID.
  final bool isAnonymous;

  /// System notices (e.g. "Messages are end-to-end encrypted").
  final bool isNotice;

  /// Admin tag shown on member messages.
  final bool isAdmin;

  ChatMessage copyWith({
    String? id,
    String? senderName,
    Color? senderColor,
    String? senderAvatar,
    String? text,
    String? time,
    bool? isMe,
    bool? isAnonymous,
    bool? isNotice,
    bool? isAdmin,
  }) {
    return ChatMessage(
      id: id ?? this.id,
      senderName: senderName ?? this.senderName,
      senderColor: senderColor ?? this.senderColor,
      senderAvatar: senderAvatar ?? this.senderAvatar,
      text: text ?? this.text,
      time: time ?? this.time,
      isMe: isMe ?? this.isMe,
      isAnonymous: isAnonymous ?? this.isAnonymous,
      isNotice: isNotice ?? this.isNotice,
      isAdmin: isAdmin ?? this.isAdmin,
    );
  }
}

/// A conversation entry in the `# Conversations` list.
class ChatConversation {
  const ChatConversation({
    required this.id,
    required this.title,
    this.isGroup = false,
    this.avatarAsset,
    this.avatarColor,
    this.avatarInitials,
    required this.lastMessage,
    this.lastMessageSender,
    required this.time,
    this.hasUnread = true,
    this.unreadCount = 1,
    this.membersDescription = '',
    this.initialMessages = const [],
    this.followersCount,
    this.joinedDate,
  });

  final String id;
  final String title;
  final bool isGroup;
  final String? avatarAsset;
  final Color? avatarColor;
  final String? avatarInitials;
  final String lastMessage;

  /// If this is a group, the sender of the last message (shown in green).
  final String? lastMessageSender;
  final String time;
  final bool hasUnread;
  final int unreadCount;
  final String membersDescription;
  final List<ChatMessage> initialMessages;
  final int? followersCount;
  final String? joinedDate;
}

/// Mock data replicating the exact items shown in the user's design screenshot.
abstract final class MockChatData {
  static const List<StoryItem> stories = [
    StoryItem(
      id: 'story-cypher',
      username: '_cypher',
      avatarAsset: 'assets/background-2.jpeg',
      storyImage: 'assets/background-2.jpeg',
      time: '45m ago',
      caption: 'Late night coding marathon with CSC 200 study group ⚡',
    ),
    StoryItem(
      id: 'story-divine',
      username: '_divine',
      avatarAsset: 'assets/background.jpeg',
      storyImage: 'assets/background.jpeg',
      time: '1h ago',
      caption: 'Algorithm assignment done and dusted! 🎉',
    ),
    StoryItem(
      id: 'story-wayne',
      username: '_wayne',
      avatarAsset: 'assets/background-3.jpeg',
      storyImage: 'assets/background-3.jpeg',
      time: '2h ago',
      caption: 'Cafeteria rice after 4 hours of lectures hits different.',
    ),
    StoryItem(
      id: 'story-encore',
      username: '_encore',
      avatarAsset: 'assets/Encore.png',
      storyImage: 'assets/background-2.jpeg',
      time: '3h ago',
      caption: 'Welcome to Encore! Discover updates, chat, and finances.',
    ),
    StoryItem(
      id: 'story-chris',
      username: '_chris',
      avatarAsset: 'assets/launch_icon_foreground.png',
      storyImage: 'assets/background.jpeg',
      time: '5h ago',
      caption: 'Database schema review tomorrow 10am at the lab.',
    ),
  ];

  static final List<ChatConversation> conversations = [
    ChatConversation(
      id: 'chat-socahtoa',
      title: 'SOCAHTOA',
      isGroup: true,
      avatarAsset: 'assets/background-2.jpeg',
      lastMessage:
          'Make una come collect una assignment, i don finish am and carry una money ooo. i don tire',
      time: '23mins',
      hasUnread: true,
      unreadCount: 3,
      membersDescription: '_cypher, _divine, _wayne, _chris, You',
      initialMessages: [
        const ChatMessage(
          id: 'soc-1',
          senderName: '_divine',
          senderColor: Color(0xFF00A884),
          text: 'Who has solved question 4 of the calculus assignment?',
          time: '11:15 AM',
        ),
        const ChatMessage(
          id: 'soc-2',
          senderName: '_wayne',
          senderColor: Color(0xFFFFA500),
          text: 'Check the class drive, Cyrus uploaded his working steps.',
          time: '11:18 AM',
        ),
        const ChatMessage(
          id: 'soc-3',
          senderName: '_cypher',
          senderColor: SpotifyColors.accent,
          isAdmin: true,
          text:
              'Make una come collect una assignment, i don finish am and carry una money ooo. i don tire',
          time: '11:22 AM',
        ),
      ],
    ),
    ChatConversation(
      id: 'chat-official-group',
      title: 'OFFICIAL GROUP CSC 200 LVL',
      isGroup: true,
      avatarAsset: 'assets/Encore.png',
      lastMessageSender: '_cypher',
      lastMessage:
          'Make una come collect una assignment, i don finish am and carry una money ooo. i don tire',
      time: '23mins',
      hasUnread: true,
      unreadCount: 5,
      membersDescription: '_cypher, _divine, _wayne, _daniel, You',
      initialMessages: [
        const ChatMessage(
          id: 'grp-0',
          isNotice: true,
          text:
              '🔒 Messages and calls are end-to-end encrypted. No one outside of this chat can read or listen to them.',
          time: '',
        ),
        const ChatMessage(
          id: 'grp-1',
          senderName: '_daniel',
          senderColor: Color(0xFF34B7F1),
          text: 'Good morning coursemates, please when is Dr. Mensah’s test?',
          time: '10:04 AM',
        ),
        const ChatMessage(
          id: 'grp-2',
          senderName: '_divine',
          senderColor: Color(0xFF00A884),
          text: 'It is scheduled for Friday morning by 9:00 AM in Lab 3.',
          time: '10:07 AM',
        ),
        const ChatMessage(
          id: 'grp-3',
          senderName: '_wayne',
          senderColor: Color(0xFFFFA500),
          text: 'Make sure everybody submits their lab manuals before then.',
          time: '10:14 AM',
        ),
        const ChatMessage(
          id: 'grp-4',
          isAnonymous: true,
          text:
              'Anonymous notice: The past questions for the last 3 years have been compiled and sent to the class drive.',
          time: '10:20 AM',
        ),
        const ChatMessage(
          id: 'grp-5',
          senderName: '_cypher',
          senderColor: SpotifyColors.accent,
          isAdmin: true,
          text:
              'Make una come collect una assignment, i don finish am and carry una money ooo. i don tire',
          time: '10:23 AM',
        ),
      ],
    ),
    ChatConversation(
      id: 'chat-cypher',
      title: '_cypher',
      isGroup: false,
      avatarAsset: 'assets/background-2.jpeg',
      lastMessage: 'I go send you that one million naira, i dey owe you...',
      time: '23mins',
      hasUnread: true,
      membersDescription: 'Online',
      initialMessages: [
        const ChatMessage(
          id: 'cyp-1',
          senderName: '_cypher',
          text: 'Guy how far? You review that PR for the mobile UI?',
          time: '10:15 AM',
        ),
        const ChatMessage(
          id: 'cyp-2',
          isMe: true,
          text: 'Yeah bro, the components and layout look super clean now.',
          time: '10:18 AM',
        ),
        const ChatMessage(
          id: 'cyp-3',
          senderName: '_cypher',
          text: 'I go send you that one million naira, i dey owe you...',
          time: '10:23 AM',
        ),
      ],
    ),
    ChatConversation(
      id: 'chat-daniel',
      title: '_daniel',
      isGroup: false,
      avatarAsset: 'assets/background-3.jpeg',
      lastMessage:
          'Paste your aza let me do some transfer for you, you don too try for us...',
      time: '23mins',
      hasUnread: true,
      membersDescription: 'last seen today at 10:45 AM',
      initialMessages: [
        const ChatMessage(
          id: 'dan-1',
          senderName: '_daniel',
          text: 'Thanks a lot for the tutorial note on data structures!',
          time: '9:50 AM',
        ),
        const ChatMessage(
          id: 'dan-2',
          isMe: true,
          text: 'Anytime bro, we all have to pass this semester together.',
          time: '9:55 AM',
        ),
        const ChatMessage(
          id: 'dan-3',
          senderName: '_daniel',
          text:
              'Paste your aza let me do some transfer for you, you don too try for us...',
          time: '10:23 AM',
        ),
      ],
    ),
    ChatConversation(
      id: 'chat-james',
      title: '_james',
      isGroup: false,
      avatarAsset: 'assets/background.jpeg',
      lastMessage:
          'Make una come collect una assignment, i don finish am and carry una money ooo. i don tire',
      time: '23mins',
      hasUnread: true,
      membersDescription: 'Online',
      initialMessages: [
        const ChatMessage(
          id: 'jam-1',
          senderName: '_james',
          text: 'Are you coming to school today?',
          time: '10:12 AM',
        ),
        const ChatMessage(
          id: 'jam-2',
          senderName: '_james',
          text:
              'Make una come collect una assignment, i don finish am and carry una money ooo. i don tire',
          time: '10:23 AM',
        ),
      ],
    ),
    ChatConversation(
      id: 'chat-wayne',
      title: '_wayne',
      isGroup: false,
      avatarAsset: 'assets/launch_icon_foreground.png',
      lastMessage: 'Yes sir 🫡',
      time: '5:47 pm',
      hasUnread: false,
      unreadCount: 0,
      membersDescription: 'Online',
      followersCount: 16,
      joinedDate: 'Joined 11 August 2023',
      initialMessages: [
        const ChatMessage(
          id: 'way-1',
          isMe: true,
          text: 'Good evening chief',
          time: '5:43 pm',
        ),
        const ChatMessage(
          id: 'way-2',
          senderName: '_wayne',
          text: 'Nice one 😀',
          time: '5:44 pm',
        ),
        const ChatMessage(
          id: 'way-3',
          senderName: '_wayne',
          text:
              'The wey the add option dey for left, then the send but8just dey minimal... Exactly',
          time: '5:45 pm',
        ),
        const ChatMessage(
          id: 'way-4',
          senderName: '_wayne',
          text:
              'In fact, if you wan copy and paste exactly.. 😂 do so, but use theme',
          time: '5:46 pm',
        ),
        const ChatMessage(
          id: 'way-5',
          isMe: true,
          text: 'Yes sir 🫡',
          time: '5:47 pm',
        ),
      ],
    ),
    ChatConversation(
      id: 'chat-lfx',
      title: '_lfx',
      isGroup: false,
      avatarColor: Color(0xFF3B0764),
      avatarInitials: 'LFX',
      lastMessage:
          'The LFX student plan is available, come and make your payments and gain acess...',
      time: '23mins',
      hasUnread: true,
      membersDescription: 'Verified Organization Channel',
      initialMessages: [
        const ChatMessage(
          id: 'lfx-1',
          senderName: '_lfx',
          text: 'Special announcement for all enrolled undergraduates:',
          time: '10:00 AM',
        ),
        const ChatMessage(
          id: 'lfx-2',
          senderName: '_lfx',
          text:
              'The LFX student plan is available, come and make your payments and gain acess...',
          time: '10:23 AM',
        ),
      ],
    ),
  ];
}
