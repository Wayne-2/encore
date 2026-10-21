import 'package:flutter/material.dart';

import 'chat_conversation.dart';
import 'direct_chat.dart';

/// A Firestore-backed group conversation.
///
/// Groups live in the same `chats` collection as direct messages so messages,
/// read state and push notifications can share the existing pipeline.
class GroupChat {
  const GroupChat({
    required this.id,
    required this.title,
    required this.members,
    required this.memberProfiles,
    required this.adminIds,
    this.createdBy,
    this.description = '',
    this.anonymousMessagesEnabled = false,
    this.membersCanPost = true,
    this.membersCanAddMembers = true,
    this.lastMessage = '',
    this.lastMessageId,
    this.lastMessageType = 'text',
    this.lastSenderId,
    this.lastSenderAnonymous = false,
    this.lastMessageAt,
    this.unreadCount = 0,
    this.lastReadAt = const {},
    this.clearedAt,
    this.createdAt,
    this.photoUrl,
  });

  final String id;
  final String title;
  final List<String> members;
  final Map<String, ChatUser> memberProfiles;
  final List<String> adminIds;
  final String? createdBy;
  final String description;
  final bool anonymousMessagesEnabled;
  final bool membersCanPost;
  final bool membersCanAddMembers;
  final String lastMessage;
  final String? lastMessageId;
  final String lastMessageType;
  final String? lastSenderId;
  final bool lastSenderAnonymous;
  final DateTime? lastMessageAt;
  final int unreadCount;
  final Map<String, DateTime> lastReadAt;
  final DateTime? clearedAt;
  final DateTime? createdAt;
  final String? photoUrl;

  int get memberCount => members.length;

  bool isAdmin(String uid) => adminIds.contains(uid);

  bool canPost(String uid) => membersCanPost || isAdmin(uid);

  ChatUser? profileFor(String uid) => memberProfiles[uid];

  ChatUser get _avatarSeed => ChatUser(id: id, name: title, username: '');

  String get initials => _avatarSeed.initials;

  Color get avatarColor => _avatarSeed.avatarColor;

  bool get hasUnread => unreadCount > 0;

  bool get isCleared {
    final cleared = clearedAt;
    final last = lastMessageAt;
    if (cleared == null) return false;
    return last == null || !cleared.isBefore(last);
  }

  int get visibleUnread => isCleared ? 0 : unreadCount;

  /// Username of the last message's sender, shown before group previews.
  String? get lastMessageSender {
    if (lastSenderId == null) return null;
    if (lastSenderAnonymous) return 'Anonymous Sender';
    final sender = memberProfiles[lastSenderId];
    final username = sender?.username.trim() ?? '';
    if (username.isNotEmpty) return username;
    final name = sender?.displayName.trim() ?? '';
    if (name.isNotEmpty) return name;
    return 'Member';
  }

  String get membersDescription {
    final names = <String>[];
    for (final uid in members) {
      final profile = memberProfiles[uid];
      final username = profile?.username.trim() ?? '';
      final name = profile?.displayName.trim() ?? '';
      final label = username.isNotEmpty ? username : name;
      if (label.isNotEmpty) names.add(label);
    }
    if (names.length <= 3) return names.join(', ');
    return '${names.take(3).join(', ')} +${names.length - 3}';
  }

  String preview() {
    if (isCleared) return 'No messages yet';
    return switch (lastMessageType) {
      'image' => 'Photo',
      'voice' => 'Voice note',
      'deleted' => 'This message was deleted',
      _ => lastMessage.trim().isEmpty ? 'No messages yet' : lastMessage,
    };
  }

  bool isReadByEveryone(DirectMessage message, String myUid) {
    final sentAt = message.createdAt;
    if (sentAt == null) return false;
    final others = members.where((uid) => uid != myUid);
    if (others.isEmpty) return true;
    for (final uid in others) {
      final readAt = lastReadAt[uid];
      if (readAt == null || readAt.isBefore(sentAt)) return false;
    }
    return true;
  }

  ChatConversation toConversation({required String myUid}) {
    return ChatConversation(
      id: id,
      title: title,
      isGroup: true,
      avatarUrl: photoUrl,
      avatarColor: avatarColor,
      avatarInitials: initials,
      lastMessage: preview(),
      lastMessageSender: lastMessageSender,
      time: isCleared ? '' : formatChatListTime(lastMessageAt ?? createdAt),
      hasUnread: visibleUnread > 0,
      unreadCount: visibleUnread,
      membersDescription: '$memberCount members',
      joinedDate: createdAt == null
          ? null
          : 'Created ${formatShortDate(createdAt!)}',
      isTyping: false,
      isOnline: false,
      peerUid: null,
      updatedAt: lastMessageAt ?? createdAt,
      followersCount: null,
    );
  }

  factory GroupChat.empty({required String id, required String myUid}) {
    return GroupChat(
      id: id,
      title: 'Group chat',
      members: [myUid],
      memberProfiles: const {},
      adminIds: const [],
      description: '',
    );
  }

  factory GroupChat.fromMap(
    String id,
    Map<String, dynamic> data, {
    required String myUid,
  }) {
    final members =
        (data['members'] as List?)?.whereType<String>().toList(
          growable: false,
        ) ??
        const <String>[];
    final rawProfiles = _map(data['memberProfiles']);
    final profiles = <String, ChatUser>{
      for (final uid in members)
        uid: rawProfiles[uid] is Map
            ? ChatUser.fromMap(
                uid,
                Map<String, dynamic>.from(rawProfiles[uid] as Map),
              )
            : ChatUser(id: uid, name: '', username: ''),
    };
    final rawReadAt = _map(data['lastReadAt']);
    final rawCleared = _map(data['clearedAt']);
    final rawUnread = _map(data['unread']);
    final photoUrl = (data['photoUrl'] as String?)?.trim();

    return GroupChat(
      id: id,
      title: (data['title'] as String?)?.trim().isNotEmpty == true
          ? (data['title'] as String).trim()
          : 'Group chat',
      members: members,
      memberProfiles: profiles,
      adminIds:
          (data['admins'] as List?)?.whereType<String>().toList(
            growable: false,
          ) ??
          const <String>[],
      createdBy: (data['createdBy'] as String?)?.trim(),
      description: (data['description'] as String?)?.trim() ?? '',
      anonymousMessagesEnabled: data['anonymousMessagesEnabled'] == true,
      membersCanPost: data['membersCanPost'] != false,
      membersCanAddMembers: data['membersCanAddMembers'] != false,
      lastMessage: data['lastMessage'] as String? ?? '',
      lastMessageId: (data['lastMessageId'] as String?)?.trim(),
      lastMessageType: data['lastMessageType'] as String? ?? 'text',
      lastSenderId: (data['lastSenderId'] as String?)?.trim(),
      lastSenderAnonymous: data['lastSenderAnonymous'] == true,
      lastMessageAt: parseTimestamp(data['lastMessageAt']),
      unreadCount: _asInt(rawUnread[myUid]),
      lastReadAt: {
        for (final entry in rawReadAt.entries)
          if (parseTimestamp(entry.value) != null)
            entry.key: parseTimestamp(entry.value)!,
      },
      clearedAt: parseTimestamp(rawCleared[myUid]),
      createdAt: parseTimestamp(data['createdAt']),
      photoUrl: photoUrl == null || photoUrl.isEmpty ? null : photoUrl,
    );
  }

  static Map<String, dynamic> _map(Object? value) {
    if (value is! Map) return const {};
    return {
      for (final entry in value.entries) entry.key.toString(): entry.value,
    };
  }

  static int _asInt(Object? value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    return 0;
  }
}
