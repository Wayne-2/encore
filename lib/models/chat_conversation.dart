import 'package:flutter/material.dart';

import '../theme/spotify_colors.dart';
import 'story.dart';

/// A chat bubble message within a group or 1-on-1 direct conversation.
class ChatMessage {
  const ChatMessage({
    required this.id,
    this.senderId,
    this.senderName,
    this.senderColor,
    this.senderAvatar,
    required this.text,
    required this.time,
    this.createdAt,
    this.isMe = false,
    this.isAnonymous = false,
    this.isNotice = false,
    this.isAdmin = false,
    this.isSeen = true,
    this.isPending = false,
    this.isEdited = false,
    this.isDeleted = false,
    this.imageUrl,
    this.stickerUrl,
    this.voiceUrl,
    this.voiceDurationMs = 0,
    this.voiceWaveform = const [],
    this.libraryId,
    this.libraryTitle,
    this.librarySubject,
    this.replyToSender,
    this.replyToText,
  });

  final String id;
  final String? senderId;
  final String? senderName;
  final Color? senderColor;
  final String? senderAvatar;
  final String text;
  final String time;
  final DateTime? createdAt;
  final bool isMe;

  /// In anonymous mode, messages do not carry the sender's real ID.
  final bool isAnonymous;

  /// System notices (e.g. "Messages are end-to-end encrypted").
  final bool isNotice;

  /// Admin tag shown on member messages.
  final bool isAdmin;

  /// Whether the other participant has read this message.
  final bool isSeen;

  /// True while the message is queued locally and not yet sent.
  final bool isPending;

  /// Whether the message copy was changed after sending.
  final bool isEdited;

  /// Deleted messages render a placeholder instead of their old copy.
  final bool isDeleted;

  /// Remote photo attached to the message.
  final String? imageUrl;

  /// Remote sticker attached to the message.
  final String? stickerUrl;

  /// Remote audio attachment and its recorded duration.
  final String? voiceUrl;
  final int voiceDurationMs;
  final List<int> voiceWaveform;

  /// Public library document shared in this message.
  final String? libraryId;
  final String? libraryTitle;
  final String? librarySubject;

  /// Reply preview shown above the message copy.
  final String? replyToSender;
  final String? replyToText;

  ChatMessage copyWith({
    String? id,
    String? senderId,
    String? senderName,
    Color? senderColor,
    String? senderAvatar,
    String? text,
    String? time,
    DateTime? createdAt,
    bool? isMe,
    bool? isAnonymous,
    bool? isNotice,
    bool? isAdmin,
    bool? isSeen,
    bool? isPending,
    bool? isEdited,
    bool? isDeleted,
    String? imageUrl,
    String? stickerUrl,
    String? voiceUrl,
    int? voiceDurationMs,
    List<int>? voiceWaveform,
    String? libraryId,
    String? libraryTitle,
    String? librarySubject,
    String? replyToSender,
    String? replyToText,
  }) {
    return ChatMessage(
      id: id ?? this.id,
      senderId: senderId ?? this.senderId,
      senderName: senderName ?? this.senderName,
      senderColor: senderColor ?? this.senderColor,
      senderAvatar: senderAvatar ?? this.senderAvatar,
      text: text ?? this.text,
      time: time ?? this.time,
      createdAt: createdAt ?? this.createdAt,
      isMe: isMe ?? this.isMe,
      isAnonymous: isAnonymous ?? this.isAnonymous,
      isNotice: isNotice ?? this.isNotice,
      isAdmin: isAdmin ?? this.isAdmin,
      isSeen: isSeen ?? this.isSeen,
      isPending: isPending ?? this.isPending,
      isEdited: isEdited ?? this.isEdited,
      isDeleted: isDeleted ?? this.isDeleted,
      imageUrl: imageUrl ?? this.imageUrl,
      stickerUrl: stickerUrl ?? this.stickerUrl,
      voiceUrl: voiceUrl ?? this.voiceUrl,
      voiceDurationMs: voiceDurationMs ?? this.voiceDurationMs,
      voiceWaveform: voiceWaveform ?? this.voiceWaveform,
      libraryId: libraryId ?? this.libraryId,
      libraryTitle: libraryTitle ?? this.libraryTitle,
      librarySubject: librarySubject ?? this.librarySubject,
      replyToSender: replyToSender ?? this.replyToSender,
      replyToText: replyToText ?? this.replyToText,
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
    this.avatarUrl,
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
    this.peerUid,
    this.isOnline = false,
    this.isTyping = false,
    this.updatedAt,
  });

  final String id;
  final String title;
  final bool isGroup;
  final String? avatarAsset;
  final String? avatarUrl;
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

  /// Set for Firestore-backed direct chats.
  final String? peerUid;
  final bool isOnline;
  final bool isTyping;

  /// The last activity time, used for live relative timestamps.
  final DateTime? updatedAt;
}

/// Mock data replicating the exact items shown in the user's design screenshot.
abstract final class MockChatData {
  static final DateTime _seedTime = DateTime.now();
  static final List<StoryItem> stories = [
    StoryItem(
      id: 'story-cypher',
      authorId: 'mock-cypher',
      username: '_cypher',
      avatarAsset: 'assets/background-2.jpeg',
      storyImage: 'assets/background-2.jpeg',
      time: '45m ago',
      createdAt: _seedTime.subtract(const Duration(minutes: 45)),
      caption: 'Late night coding marathon with CSC 200 study group ⚡',
    ),
    StoryItem(
      id: 'story-divine',
      authorId: 'mock-divine',
      username: '_divine',
      avatarAsset: 'assets/background.jpeg',
      storyImage: 'assets/background.jpeg',
      time: '1h ago',
      createdAt: _seedTime.subtract(const Duration(minutes: 60)),
      caption: 'Algorithm assignment done and dusted! 🎉',
    ),
    StoryItem(
      id: 'story-wayne',
      authorId: 'mock-wayne',
      username: '_wayne',
      avatarAsset: 'assets/background-3.jpeg',
      storyImage: 'assets/background-3.jpeg',
      time: '2h ago',
      createdAt: _seedTime.subtract(const Duration(minutes: 120)),
      caption: 'Cafeteria rice after 4 hours of lectures hits different.',
    ),
    StoryItem(
      id: 'story-encore',
      authorId: 'mock-encore',
      username: '_encore',
      avatarAsset: 'assets/Encore.png',
      storyImage: 'assets/background-2.jpeg',
      time: '3h ago',
      createdAt: _seedTime.subtract(const Duration(minutes: 180)),
      caption: 'Welcome to Encore! Discover updates, chat, and finances.',
    ),
    StoryItem(
      id: 'story-chris',
      authorId: 'mock-chris',
      username: '_chris',
      avatarAsset: 'assets/launch_icon_foreground.png',
      storyImage: 'assets/background.jpeg',
      time: '5h ago',
      createdAt: _seedTime.subtract(const Duration(minutes: 300)),
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
      updatedAt: _seedTime.subtract(const Duration(minutes: 23)),
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
      updatedAt: _seedTime.subtract(const Duration(minutes: 23)),
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
      updatedAt: _seedTime.subtract(const Duration(minutes: 23)),
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
      updatedAt: _seedTime.subtract(const Duration(minutes: 23)),
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
      updatedAt: _seedTime.subtract(const Duration(minutes: 23)),
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
      updatedAt: _seedTime.subtract(const Duration(hours: 5)),
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
      updatedAt: _seedTime.subtract(const Duration(minutes: 23)),
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
