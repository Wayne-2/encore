import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import 'chat_conversation.dart';

/// A person available to chat with in Encore.
class ChatUser {
  const ChatUser({
    required this.id,
    required this.name,
    required this.username,
    this.photoUrl,
    this.level,
    this.department,
    this.faculty,
    this.privacyMode = false,
    this.lastSeen,
  });

  final String id;
  final String name;
  final String username;
  final String? photoUrl;
  final String? level;
  final String? department;
  final String? faculty;
  final bool privacyMode;
  final DateTime? lastSeen;

  String get displayName {
    final trimmed = name.trim();
    if (trimmed.isNotEmpty) return trimmed;
    if (username.trim().isNotEmpty) return username.trim();
    return 'Encore user';
  }

  String get handle {
    final value = username.trim();
    if (value.isEmpty) return '@user';
    if (value.startsWith('@') || value.startsWith('_')) return value;
    return '@$value';
  }

  String get initials {
    final parts = displayName
        .split(RegExp(r'\s+'))
        .where((part) => part.isNotEmpty)
        .toList();
    if (parts.isEmpty) return '?';
    if (parts.length == 1) return parts.first.substring(0, 1).toUpperCase();
    return '${parts[0].substring(0, 1)}${parts[1].substring(0, 1)}'
        .toUpperCase();
  }

  /// A stable colour for the initials avatar.
  Color get avatarColor {
    const palette = [
      Color(0xFF1F7A4D),
      Color(0xFF1F5F8B),
      Color(0xFF7A4D9E),
      Color(0xFF9E4D5B),
      Color(0xFF8B6A1F),
      Color(0xFF3D6B8B),
    ];
    final sum = id.codeUnits.fold<int>(0, (total, unit) => total + unit);
    return palette[sum % palette.length];
  }

  bool isOnlineAt(DateTime now) {
    final seen = lastSeen;
    if (seen == null) return false;
    return now.difference(seen).inMinutes < 2;
  }

  String presenceLabel(DateTime now) {
    if (isOnlineAt(now)) return 'online';
    return formatLastSeen(lastSeen, now);
  }

  factory ChatUser.fromMap(String id, Map<String, dynamic> data) {
    final name =
        (data['fullName'] as String?)?.trim() ??
        (data['name'] as String?)?.trim() ??
        '';
    final username = (data['username'] as String?)?.trim() ?? '';
    return ChatUser(
      id: id,
      name: name,
      username: username,
      photoUrl: (data['photoUrl'] as String?)?.trim(),
      level: (data['level'] as String?)?.trim(),
      department: (data['department'] as String?)?.trim(),
      faculty: (data['faculty'] as String?)?.trim(),
      privacyMode: data['privacyMode'] == true,
      lastSeen: parseTimestamp(data['lastSeen']),
    );
  }

  factory ChatUser.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    return ChatUser.fromMap(doc.id, doc.data() ?? const {});
  }

  Map<String, dynamic> toMap() {
    return {
      'fullName': name,
      'username': username,
      'photoUrl': photoUrl,
      'level': level,
      'department': department,
      'faculty': faculty,
      'privacyMode': privacyMode,
    };
  }
}

/// A Firestore-backed 1:1 conversation.
class DirectChat {
  const DirectChat({
    required this.id,
    required this.peer,
    required this.members,
    required this.lastMessage,
    required this.lastMessageAt,
    required this.lastSenderId,
    this.lastMessageId,
    this.lastMessageType = 'text',
    this.unreadCount = 0,
    this.peerLastReadAt,
    this.peerTypingAt,
    this.clearedAt,
    this.createdAt,
  });

  final String id;
  final ChatUser peer;
  final List<String> members;
  final String lastMessage;
  final String? lastMessageId;
  final String lastMessageType;
  final String? lastSenderId;
  final DateTime? lastMessageAt;
  final int unreadCount;
  final DateTime? peerLastReadAt;
  final DateTime? peerTypingAt;
  final DateTime? clearedAt;
  final DateTime? createdAt;

  factory DirectChat.empty({
    required String id,
    required ChatUser peer,
    required String myUid,
    DateTime? createdAt,
  }) {
    return DirectChat(
      id: id,
      peer: peer,
      members: [myUid, peer.id],
      lastMessage: '',
      lastMessageAt: null,
      lastSenderId: null,
      createdAt: createdAt,
    );
  }

  bool get hasUnread => unreadCount > 0;

  bool get isCleared {
    final cleared = clearedAt;
    final last = lastMessageAt;
    if (cleared == null) return false;
    return last == null || !cleared.isBefore(last);
  }

  int get visibleUnread => isCleared ? 0 : unreadCount;

  bool isTypingAt(DateTime now) {
    final typing = peerTypingAt;
    if (typing == null) return false;
    final difference = now.difference(typing);
    return !difference.isNegative && difference.inSeconds < 5;
  }

  DirectChat copyWith({ChatUser? peer}) {
    return DirectChat(
      id: id,
      peer: peer ?? this.peer,
      members: members,
      lastMessage: lastMessage,
      lastMessageId: lastMessageId,
      lastMessageType: lastMessageType,
      lastSenderId: lastSenderId,
      lastMessageAt: lastMessageAt,
      unreadCount: unreadCount,
      peerLastReadAt: peerLastReadAt,
      peerTypingAt: peerTypingAt,
      clearedAt: clearedAt,
      createdAt: createdAt,
    );
  }

  String preview({required String myUid}) {
    if (isCleared) return 'No messages yet';
    final text = switch (lastMessageType) {
      'image' => 'Photo',
      'sticker' => 'Sticker',
      'voice' => 'Voice note',
      'library' => lastMessage.trim().isEmpty
          ? 'Document'
          : 'Document: ${lastMessage.trim()}',
      'deleted' => 'This message was deleted',
      _ => lastMessage.trim().isEmpty ? 'No messages yet' : lastMessage,
    };
    return lastSenderId == myUid ? 'You: $text' : text;
  }

  ChatConversation toConversation({required String myUid}) {
    final now = DateTime.now();
    return ChatConversation(
      id: id,
      title: peer.displayName,
      avatarUrl: peer.photoUrl,
      avatarColor: peer.avatarColor,
      avatarInitials: peer.initials,
      lastMessage: preview(myUid: myUid),
      time: isCleared ? '' : formatChatListTime(lastMessageAt ?? createdAt),
      hasUnread: visibleUnread > 0,
      unreadCount: visibleUnread,
      membersDescription: peer.presenceLabel(now),
      peerUid: peer.id,
      isOnline: peer.isOnlineAt(now),
      isTyping: isTypingAt(now),
      joinedDate: createdAt == null
          ? null
          : 'Started ${formatShortDate(createdAt!)}',
      updatedAt: lastMessageAt ?? createdAt,
    );
  }
}

/// A reply preview attached to a message.
class ReplyPreview {
  const ReplyPreview({
    required this.id,
    required this.senderId,
    required this.senderName,
    required this.text,
    required this.type,
    this.imageUrl,
  });

  final String id;
  final String senderId;
  final String senderName;
  final String text;
  final String type;
  final String? imageUrl;

  String get preview => switch (type) {
    'image' => 'Photo',
    'sticker' => 'Sticker',
    'voice' => 'Voice note',
    'library' => 'Document',
    'deleted' => 'This message was deleted',
    _ => text,
  };

  factory ReplyPreview.fromMap(Map<String, dynamic> data) {
    return ReplyPreview(
      id: data['id'] as String? ?? '',
      senderId: data['senderId'] as String? ?? '',
      senderName: data['senderName'] as String? ?? '',
      text: data['text'] as String? ?? '',
      type: data['type'] as String? ?? 'text',
      imageUrl: data['imageUrl'] as String?,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'senderId': senderId,
      'senderName': senderName,
      'text': text,
      'type': type,
      'imageUrl': imageUrl,
    };
  }
}

/// A Firestore-backed message in a direct conversation.
class DirectMessage {
  const DirectMessage({
    required this.id,
    required this.senderId,
    required this.senderName,
    required this.senderUsername,
    required this.text,
    required this.createdAt,
    required this.type,
    this.imageUrl,
    this.stickerUrl,
    this.voiceUrl,
    this.voiceDurationMs = 0,
    this.voiceWaveform = const [],
    this.libraryId,
    this.libraryTitle,
    this.librarySubject,
    this.editedAt,
    this.deleted = false,
    this.anonymous = false,
    this.pending = false,
    this.replyTo,
  });

  final String id;
  final String senderId;
  final String senderName;
  final String senderUsername;
  final String text;
  final DateTime? createdAt;
  final String type;
  final String? imageUrl;
  final String? stickerUrl;
  final String? voiceUrl;
  final int voiceDurationMs;
  final List<int> voiceWaveform;
  final String? libraryId;
  final String? libraryTitle;
  final String? librarySubject;
  final DateTime? editedAt;
  final bool deleted;
  final bool anonymous;

  /// True while a locally queued write is waiting for the server.
  final bool pending;
  final ReplyPreview? replyTo;

  bool isMine(String uid) => senderId == uid;

  bool get isEdited => editedAt != null;

  DirectMessage copyWith({
    String? text,
    DateTime? editedAt,
    bool? deleted,
    bool? anonymous,
    bool? pending,
    String? imageUrl,
    String? stickerUrl,
    String? voiceUrl,
    int? voiceDurationMs,
    List<int>? voiceWaveform,
  }) {
    return DirectMessage(
      id: id,
      senderId: senderId,
      senderName: senderName,
      senderUsername: senderUsername,
      text: text ?? this.text,
      createdAt: createdAt,
      type: deleted == true ? 'deleted' : type,
      imageUrl: imageUrl ?? this.imageUrl,
      stickerUrl: stickerUrl ?? this.stickerUrl,
      voiceUrl: voiceUrl ?? this.voiceUrl,
      voiceDurationMs: voiceDurationMs ?? this.voiceDurationMs,
      voiceWaveform: voiceWaveform ?? this.voiceWaveform,
      libraryId: libraryId,
      libraryTitle: libraryTitle,
      librarySubject: librarySubject,
      editedAt: editedAt ?? this.editedAt,
      deleted: deleted ?? this.deleted,
      anonymous: anonymous ?? this.anonymous,
      pending: pending ?? this.pending,
      replyTo: replyTo,
    );
  }

  factory DirectMessage.fromDoc(
    QueryDocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    return DirectMessage.fromMap(
      doc.id,
      doc.data(),
      pending: doc.metadata.hasPendingWrites,
    );
  }

  factory DirectMessage.fromMap(
    String id,
    Map<String, dynamic> data, {
    bool pending = false,
  }) {
    final replyData = data['replyTo'];
    final deleted = data['deleted'] == true || data['type'] == 'deleted';
    return DirectMessage(
      id: id,
      senderId: data['senderId'] as String? ?? '',
      senderName: data['senderName'] as String? ?? 'User',
      senderUsername: data['senderUsername'] as String? ?? '',
      text: data['text'] as String? ?? '',
      createdAt:
          parseTimestamp(data['createdAt']) ??
          parseTimestamp(data['localCreatedAt']),
      type: data['type'] as String? ?? 'text',
      imageUrl: (data['imageUrl'] as String?)?.trim(),
      stickerUrl: (data['stickerUrl'] as String?)?.trim(),
      voiceUrl: (data['voiceUrl'] as String?)?.trim(),
      voiceDurationMs: _asInt(data['voiceDurationMs']),
      voiceWaveform: _asIntList(data['voiceWaveform']),
      libraryId: (data['libraryId'] as String?)?.trim(),
      libraryTitle: (data['libraryTitle'] as String?)?.trim(),
      librarySubject: (data['librarySubject'] as String?)?.trim(),
      editedAt: parseTimestamp(data['editedAt']),
      deleted: deleted,
      anonymous: data['anonymous'] == true,
      pending: pending,
      replyTo: !deleted && replyData is Map
          ? ReplyPreview.fromMap(Map<String, dynamic>.from(replyData))
          : null,
    );
  }

  String get senderLabel => anonymous ? 'Anonymous Sender' : senderName;

  ReplyPreview toReplyPreview() {
    return ReplyPreview(
      id: id,
      senderId: senderId,
      senderName: senderLabel,
      text: text,
      type: type,
      imageUrl: imageUrl,
    );
  }

  ChatMessage toUiMessage({
    required String myUid,
    required bool isSeen,
    bool showUsername = false,
    bool senderIsAdmin = false,
    ChatUser? sender,
  }) {
    final mine = senderId == myUid;
    final username = (sender?.username ?? senderUsername).trim();
    final groupLabel = username.isNotEmpty
        ? username
        : (sender?.displayName.trim().isNotEmpty == true
              ? sender!.displayName
              : senderName);
    return ChatMessage(
      id: id,
      senderId: senderId,
      senderName: anonymous
          ? 'Anonymous Sender'
          : (mine ? 'You' : (showUsername ? groupLabel : senderName)),
      senderColor: anonymous || !showUsername ? null : sender?.avatarColor,
      text: deleted ? 'This message was deleted' : text,
      time: formatMessageTime(createdAt),
      createdAt: createdAt,
      isMe: mine,
      isAnonymous: anonymous,
      isAdmin: senderIsAdmin && !anonymous,
      isSeen: isSeen,
      isPending: pending,
      isDeleted: deleted,
      isEdited: editedAt != null,
      imageUrl: imageUrl,
      stickerUrl: stickerUrl,
      voiceUrl: voiceUrl,
      voiceDurationMs: voiceDurationMs,
      voiceWaveform: voiceWaveform,
      libraryId: libraryId,
      libraryTitle: libraryTitle,
      librarySubject: librarySubject,
      replyToSender: deleted
          ? null
          : (replyTo?.senderId == myUid ? 'You' : replyTo?.senderName),
      replyToText: deleted ? null : replyTo?.preview,
    );
  }
}

int _asInt(Object? value) {
  if (value is int) return value;
  if (value is num) return value.toInt();
  return 0;
}

List<int> _asIntList(Object? value) {
  if (value is! List) return const [];
  return value
      .whereType<num>()
      .map((item) => item.toInt())
      .toList(growable: false);
}

DateTime? parseTimestamp(Object? value) {
  return switch (value) {
    Timestamp timestamp => timestamp.toDate(),
    DateTime time => time,
    int milliseconds => DateTime.fromMillisecondsSinceEpoch(milliseconds),
    _ => null,
  };
}

String formatMessageTime(DateTime? time) {
  if (time == null) return '';
  final local = time.toLocal();
  final hour = local.hour % 12 == 0 ? 12 : local.hour % 12;
  final minute = local.minute.toString().padLeft(2, '0');
  return '$hour:$minute ${local.hour >= 12 ? 'pm' : 'am'}';
}

String formatChatListTime(DateTime? time) {
  if (time == null) return '';
  final local = time.toLocal();
  final now = DateTime.now();
  if (isSameDay(local, now)) return formatMessageTime(local);
  final yesterday = DateTime(now.year, now.month, now.day - 1);
  if (isSameDay(local, yesterday)) return 'Yesterday';
  if (now.difference(local).inDays < 7) {
    const weekdays = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    return weekdays[local.weekday - 1];
  }
  return '${local.day.toString().padLeft(2, '0')}/'
      '${local.month.toString().padLeft(2, '0')}/'
      '${local.year.toString().substring(2)}';
}

String formatLastSeen(DateTime? time, DateTime now) {
  if (time == null) return 'last seen recently';
  final local = time.toLocal();
  if (now.difference(local).inMinutes < 2) return 'online';
  if (isSameDay(local, now)) {
    return 'last seen today at ${formatMessageTime(local)}';
  }
  final yesterday = DateTime(now.year, now.month, now.day - 1);
  if (isSameDay(local, yesterday)) return 'last seen yesterday';
  return 'last seen ${formatShortDate(local)}';
}

String formatShortDate(DateTime time) {
  final local = time.toLocal();
  const months = [
    'Jan',
    'Feb',
    'Mar',
    'Apr',
    'May',
    'Jun',
    'Jul',
    'Aug',
    'Sep',
    'Oct',
    'Nov',
    'Dec',
  ];
  return '${local.day} ${months[local.month - 1]} ${local.year}';
}

String formatDateSeparator(DateTime? time) {
  if (time == null) return '';
  final local = time.toLocal();
  final now = DateTime.now();
  if (isSameDay(local, now)) return 'Today';
  final yesterday = DateTime(now.year, now.month, now.day - 1);
  if (isSameDay(local, yesterday)) return 'Yesterday';
  return formatShortDate(local);
}

bool isSameDay(DateTime? a, DateTime? b) {
  if (a == null || b == null) return false;
  final first = a.toLocal();
  final second = b.toLocal();
  return first.year == second.year &&
      first.month == second.month &&
      first.day == second.day;
}
