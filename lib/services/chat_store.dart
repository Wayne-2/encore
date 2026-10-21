import 'dart:async';
import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

import '../config/app_config.dart';
import '../models/direct_chat.dart';
import '../models/group_chat.dart';
import 'auth_service.dart';
import 'local_cache.dart';
import 'media_storage.dart';
import 'notification_service.dart';

/// The signed-in user's chats, split by kind.
class ChatInbox {
  const ChatInbox({required this.directChats, required this.groups});

  static const ChatInbox empty = ChatInbox(directChats: [], groups: []);

  final List<DirectChat> directChats;
  final List<GroupChat> groups;
}

/// Firestore-backed direct and group messages.
///
/// Chats live at `chats/{chatId}` and their messages in the `messages`
/// subcollection. Direct chat IDs are deterministic from the two member UIDs,
/// so starting a chat twice always opens the same thread. Group chats use the
/// same collection with `type: 'group'`.
class ChatStore {
  ChatStore._();

  static final ChatStore instance = ChatStore._();

  static const String _chats = 'chats';

  FirebaseFirestore get _firestore => FirebaseFirestore.instance;

  String? get _uid => AuthService.instance.currentUser?.uid;

  bool get isEnabled => AuthService.isAvailable && _uid != null;

  /// Signing-in users can message everyone in the app except themselves.
  Stream<List<ChatUser>> watchUsers() {
    final uid = _uid;
    if (!isEnabled || uid == null) {
      return Stream<List<ChatUser>>.value(const []);
    }

    late StreamController<List<ChatUser>> controller;
    StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? sub;

    controller = StreamController<List<ChatUser>>(
      onListen: () async {
        final cached = await LocalCache.instance.users();
        if (controller.isClosed) return;
        if (cached != null) controller.add(_usersFromCache(cached, uid));

        sub = _firestore.collection('users').snapshots().listen((snapshot) {
          final raw = [
            for (final doc in snapshot.docs) {'id': doc.id, ...doc.data()},
          ];
          controller.add(_usersFromCache(raw, uid));
          unawaited(LocalCache.instance.saveUsers(raw));
        }, onError: controller.addError);
      },
      onCancel: () async {
        await sub?.cancel();
      },
    );

    return controller.stream;
  }

  /// The signed-in user's inbox, newest conversation first.
  ///
  /// Accepted contact requests create an empty chat document so the connection
  /// appears for both people immediately; those threads are kept and sorted by
  /// their creation time until the first message arrives.
  Stream<List<DirectChat>> watchConversations() {
    final uid = _uid;
    if (!isEnabled || uid == null) {
      return Stream<List<DirectChat>>.value(const []);
    }

    late StreamController<List<DirectChat>> controller;
    StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? sub;

    controller = StreamController<List<DirectChat>>(
      onListen: () async {
        final cached = await LocalCache.instance.chats(uid);
        if (controller.isClosed) return;
        if (cached != null) {
          controller.add(_conversationsFromCache(cached, uid));
        }

        sub = _firestore
            .collection(_chats)
            .where('members', arrayContains: uid)
            .snapshots()
            .listen((snapshot) {
              final raw = [
                for (final doc in snapshot.docs) {'id': doc.id, ...doc.data()},
              ];
              controller.add(_conversationsFromCache(raw, uid));
              unawaited(LocalCache.instance.saveChats(uid, raw));
            }, onError: controller.addError);
      },
      onCancel: () async {
        await sub?.cancel();
      },
    );

    return controller.stream;
  }

  /// Watches every conversation for the inbox in one Firestore query.
  Stream<ChatInbox> watchInbox() {
    final uid = _uid;
    if (!isEnabled || uid == null) {
      return Stream<ChatInbox>.value(ChatInbox.empty);
    }

    late StreamController<ChatInbox> controller;
    StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? sub;

    controller = StreamController<ChatInbox>(
      onListen: () async {
        final cached = await LocalCache.instance.chats(uid);
        if (controller.isClosed) return;
        if (cached != null) {
          controller.add(_inboxFromCache(cached, uid));
        }

        sub = _firestore
            .collection(_chats)
            .where('members', arrayContains: uid)
            .snapshots()
            .listen((snapshot) {
              final raw = [
                for (final doc in snapshot.docs) {'id': doc.id, ...doc.data()},
              ];
              controller.add(_inboxFromRaw(raw, uid));
              unawaited(LocalCache.instance.saveChats(uid, raw));
            }, onError: controller.addError);
      },
      onCancel: () async {
        await sub?.cancel();
      },
    );

    return controller.stream;
  }

  /// Watches a group chat document, falling back to Hive while offline.
  Stream<GroupChat?> watchGroup(String chatId) {
    final uid = _uid;
    if (!isEnabled || uid == null) {
      return Stream<GroupChat?>.value(null);
    }

    late StreamController<GroupChat?> controller;
    StreamSubscription<DocumentSnapshot<Map<String, dynamic>>>? sub;

    controller = StreamController<GroupChat?>(
      onListen: () async {
        final cached = await LocalCache.instance.chat(uid, chatId);
        if (controller.isClosed) return;
        if (cached != null) {
          controller.add(_groupFromData(chatId, uid, cached));
        }

        sub = _firestore.collection(_chats).doc(chatId).snapshots().listen((
          snapshot,
        ) {
          final data = snapshot.data();
          if (data != null) {
            unawaited(LocalCache.instance.saveChat(uid, chatId, data));
          }
          controller.add(
            data == null ? null : _groupFromData(chatId, uid, data),
          );
        }, onError: controller.addError);
      },
      onCancel: () async {
        await sub?.cancel();
      },
    );

    return controller.stream;
  }

  /// Watches a single chat plus the peer's profile (presence and photo).
  Stream<DirectChat> watchChat({
    required String chatId,
    required ChatUser peer,
  }) {
    final uid = _uid;
    if (!isEnabled || uid == null) {
      return Stream<DirectChat>.value(
        DirectChat.empty(id: chatId, peer: peer, myUid: uid ?? ''),
      );
    }

    late StreamController<DirectChat> controller;
    StreamSubscription<DocumentSnapshot<Map<String, dynamic>>>? chatSub;
    StreamSubscription<DocumentSnapshot<Map<String, dynamic>>>? userSub;
    Map<String, dynamic>? chatData;
    var currentPeer = peer;

    void emit() {
      if (controller.isClosed) return;
      final data = chatData;
      if (data == null) {
        controller.add(
          DirectChat.empty(id: chatId, peer: currentPeer, myUid: uid),
        );
        return;
      }
      final chat = _chatFromData(chatId, uid, data, peerOverride: currentPeer);
      if (chat == null) {
        controller.addError(StateError('Invalid direct chat document.'));
        return;
      }
      controller.add(chat);
    }

    controller = StreamController<DirectChat>(
      onListen: () async {
        final cached = await LocalCache.instance.chat(uid, chatId);
        if (controller.isClosed) return;
        if (cached != null) {
          chatData = cached;
          emit();
        }

        chatSub = _firestore.collection(_chats).doc(chatId).snapshots().listen((
          snapshot,
        ) {
          chatData = snapshot.data();
          if (chatData != null) {
            unawaited(LocalCache.instance.saveChat(uid, chatId, chatData!));
          }
          emit();
        }, onError: controller.addError);
        userSub = _firestore
            .collection('users')
            .doc(peer.id)
            .snapshots()
            .listen((snapshot) {
              if (!snapshot.exists) return;
              currentPeer = ChatUser.fromDoc(snapshot);
              emit();
            }, onError: (Object _) {});
      },
      onCancel: () async {
        await chatSub?.cancel();
        await userSub?.cancel();
      },
    );

    return controller.stream;
  }

  /// Newest messages in a chat, returned oldest-first for the chat list.
  Stream<List<DirectMessage>> watchMessages(String chatId) {
    final uid = _uid;
    if (!isEnabled || uid == null) {
      return Stream<List<DirectMessage>>.value(const []);
    }

    late StreamController<List<DirectMessage>> controller;
    StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? sub;

    controller = StreamController<List<DirectMessage>>(
      onListen: () async {
        final cached = await LocalCache.instance.messages(uid, chatId);
        if (controller.isClosed) return;
        if (cached != null) controller.add(_messagesFromCache(cached));

        sub = _firestore
            .collection(_chats)
            .doc(chatId)
            .collection('messages')
            .orderBy('createdAt', descending: true)
            .limit(200)
            .snapshots()
            .listen((snapshot) {
              final raw = [
                for (final doc in snapshot.docs) {'id': doc.id, ...doc.data()},
              ];
              final messages = snapshot.docs
                  .map(DirectMessage.fromDoc)
                  .toList();
              messages.sort(
                (a, b) => (a.createdAt ?? DateTime(0)).compareTo(
                  b.createdAt ?? DateTime(0),
                ),
              );
              controller.add(messages);
              unawaited(LocalCache.instance.saveMessages(uid, chatId, raw));
            }, onError: controller.addError);
      },
      onCancel: () async {
        await sub?.cancel();
      },
    );

    return controller.stream;
  }

  /// Creates the chat document if needed and refreshes the participant
  /// snapshots used by the inbox.
  Future<String> ensureChat(ChatUser peer) async {
    final me = await currentChatUser();
    await _ensureChat(me: me, peer: peer);
    return directChatId(me.id, peer.id);
  }

  Future<DocumentReference<Map<String, dynamic>>> _ensureChat({
    required ChatUser me,
    required ChatUser peer,
  }) async {
    final ref = _firestore.collection(_chats).doc(directChatId(me.id, peer.id));
    final snapshot = await ref.get();

    if (!snapshot.exists) {
      try {
        await ref.set({
          'type': 'dm',
          'members': [me.id, peer.id],
          'memberProfiles': {me.id: me.toMap(), peer.id: peer.toMap()},
          'unread': {me.id: 0, peer.id: 0},
          'lastReadAt': {},
          'typing': {},
          'clearedAt': {},
          'createdAt': FieldValue.serverTimestamp(),
          'updatedAt': FieldValue.serverTimestamp(),
        });
      } on FirebaseException catch (error) {
        // Another device may have created the same deterministic chat first.
        if (error.code != 'already-exists') rethrow;
      }
    } else {
      await ref.set({
        'memberProfiles': {me.id: me.toMap(), peer.id: peer.toMap()},
      }, SetOptions(merge: true));
    }

    return ref;
  }

  Future<void> sendText({
    required ChatUser peer,
    required String text,
    ReplyPreview? replyTo,
  }) async {
    final trimmed = text.trim();
    if (trimmed.isEmpty) return;
    final me = await currentChatUser();
    await _send(
      me: me,
      peer: peer,
      text: trimmed,
      type: 'text',
      replyTo: replyTo,
    );
  }

  Future<void> sendImage({
    required ChatUser peer,
    required Uint8List bytes,
    required String filename,
  }) async {
    final me = await currentChatUser();
    final url = await _uploadImage(bytes, filename);
    await _send(me: me, peer: peer, text: '', type: 'image', imageUrl: url);
  }

  /// Creates a group with the current user as its first admin.
  Future<GroupChat> createGroup({
    required String title,
    required List<ChatUser> members,
    Uint8List? photoBytes,
  }) async {
    final uid = _uid;
    if (!isEnabled || uid == null) {
      throw StateError('Sign in to create groups.');
    }

    final name = title.trim();
    if (name.isEmpty) throw StateError('Give the group a name.');
    if (name.length > 80) throw StateError('That group name is too long.');

    final me = await currentChatUser();
    final everyone = <String, ChatUser>{me.id: me};
    for (final member in members) {
      if (member.id != me.id) everyone[member.id] = member;
    }
    if (everyone.length < 2) {
      throw StateError('Choose at least one other member.');
    }

    String? photoUrl;
    if (photoBytes != null) {
      try {
        photoUrl = await _uploadImage(
          photoBytes,
          'group-${DateTime.now().microsecondsSinceEpoch}',
        );
      } catch (_) {
        throw StateError('Could not upload the group photo.');
      }
    }

    final ref = _firestore.collection(_chats).doc();
    final now = DateTime.now();
    final profiles = {
      for (final entry in everyone.entries) entry.key: entry.value.toMap(),
    };
    final memberIds = everyone.keys.toList(growable: false);

    await ref.set({
      'type': 'group',
      'title': name,
      'members': memberIds,
      'memberProfiles': profiles,
      'admins': [me.id],
      'createdBy': me.id,
      'description': '',
      'anonymousMessagesEnabled': false,
      'membersCanPost': true,
      'membersCanAddMembers': true,
      'unread': {for (final id in memberIds) id: 0},
      'lastReadAt': {},
      'typing': {},
      'clearedAt': {},
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
      'photoUrl': photoUrl,
    });

    return GroupChat(
      id: ref.id,
      title: name,
      members: memberIds,
      memberProfiles: everyone,
      adminIds: [me.id],
      createdBy: me.id,
      createdAt: now,
      photoUrl: photoUrl,
    );
  }

  Future<void> sendGroupText({
    required String chatId,
    required String text,
    ReplyPreview? replyTo,
    bool anonymous = false,
  }) async {
    final trimmed = text.trim();
    if (trimmed.isEmpty) return;

    final me = await currentChatUser();
    final chatRef = _firestore.collection(_chats).doc(chatId);
    final group = await _requireGroup(chatRef, me.id);
    if (!group.canPost(me.id)) {
      throw StateError('Only admins can send messages in this group.');
    }
    if (anonymous && !group.anonymousMessagesEnabled) {
      throw StateError('Anonymous messages are not enabled in this group.');
    }
    await _sendToChat(
      chatRef: chatRef,
      me: me,
      recipientIds: group.members.where((uid) => uid != me.id).toList(),
      text: trimmed,
      type: 'text',
      replyTo: replyTo,
      anonymous: anonymous,
    );
  }

  Future<void> sendGroupImage({
    required String chatId,
    required Uint8List bytes,
    required String filename,
  }) async {
    final me = await currentChatUser();
    final url = await _uploadImage(bytes, filename);
    final chatRef = _firestore.collection(_chats).doc(chatId);
    final group = await _requireGroup(chatRef, me.id);
    if (!group.canPost(me.id)) {
      throw StateError('Only admins can send messages in this group.');
    }
    await _sendToChat(
      chatRef: chatRef,
      me: me,
      recipientIds: group.members.where((uid) => uid != me.id).toList(),
      text: '',
      type: 'image',
      imageUrl: url,
    );
  }

  /// Updates group permissions and basic information. Admins only.
  Future<void> updateGroupSettings({
    required String chatId,
    bool? anonymousMessagesEnabled,
    bool? membersCanPost,
    bool? membersCanAddMembers,
    String? description,
    String? title,
  }) async {
    final uid = _uid;
    if (!isEnabled || uid == null) {
      throw StateError('Sign in to change group settings.');
    }

    final chatRef = _firestore.collection(_chats).doc(chatId);
    final group = await _requireGroup(chatRef, uid);
    if (!group.isAdmin(uid)) {
      throw StateError('Only group admins can change these settings.');
    }

    final updates = <String, dynamic>{
      'updatedAt': FieldValue.serverTimestamp(),
    };
    if (anonymousMessagesEnabled != null) {
      updates['anonymousMessagesEnabled'] = anonymousMessagesEnabled;
    }
    if (membersCanPost != null) updates['membersCanPost'] = membersCanPost;
    if (membersCanAddMembers != null) {
      updates['membersCanAddMembers'] = membersCanAddMembers;
    }
    if (description != null) {
      updates['description'] = description.trim();
    }
    if (title != null) {
      final name = title.trim();
      if (name.isEmpty) throw StateError('Give the group a name.');
      if (name.length > 80) throw StateError('That group name is too long.');
      updates['title'] = name;
    }
    await chatRef.update(updates);
  }

  /// Replaces the group photo. Admins only.
  Future<void> updateGroupPhoto({
    required String chatId,
    required Uint8List bytes,
    required String filename,
  }) async {
    final uid = _uid;
    if (!isEnabled || uid == null) {
      throw StateError('Sign in to change the group photo.');
    }
    final chatRef = _firestore.collection(_chats).doc(chatId);
    final group = await _requireGroup(chatRef, uid);
    if (!group.isAdmin(uid)) {
      throw StateError('Only group admins can change the group photo.');
    }
    final url = await _uploadImage(bytes, filename);
    await chatRef.update({
      'photoUrl': url,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  /// Adds people to a group. Admins can always add; members only when the
  /// admin has allowed it.
  Future<void> addGroupMembers({
    required String chatId,
    required List<ChatUser> members,
  }) async {
    final uid = _uid;
    if (!isEnabled || uid == null) {
      throw StateError('Sign in to add group members.');
    }
    final additions = <String, ChatUser>{
      for (final member in members) member.id: member,
    };
    if (additions.isEmpty) return;

    final chatRef = _firestore.collection(_chats).doc(chatId);
    final group = await _requireGroup(chatRef, uid);
    if (!group.isAdmin(uid) && !group.membersCanAddMembers) {
      throw StateError('Only admins can add people to this group.');
    }

    final nextMembers = [...group.members];
    final nextProfiles = <String, dynamic>{
      for (final entry in group.memberProfiles.entries)
        entry.key: entry.value.toMap(),
    };
    for (final addition in additions.values) {
      if (nextMembers.contains(addition.id)) continue;
      if (nextMembers.length >= 100) {
        throw StateError('This group already has the maximum 100 members.');
      }
      nextMembers.add(addition.id);
      nextProfiles[addition.id] = addition.toMap();
    }
    if (nextMembers.length == group.members.length) return;

    final updates = <String, dynamic>{
      'members': nextMembers,
      'memberProfiles': nextProfiles,
      'updatedAt': FieldValue.serverTimestamp(),
    };
    for (final id in nextMembers.where((id) => !group.members.contains(id))) {
      updates['unread.$id'] = 0;
      updates['typing.$id'] = FieldValue.delete();
      updates['clearedAt.$id'] = FieldValue.delete();
    }
    await chatRef.update(updates);
  }

  /// Promotes or demotes a group member. Admins only.
  Future<void> setGroupAdmin({
    required String chatId,
    required String memberId,
    required bool admin,
  }) async {
    final uid = _uid;
    if (!isEnabled || uid == null) {
      throw StateError('Sign in to manage group admins.');
    }
    final chatRef = _firestore.collection(_chats).doc(chatId);
    final group = await _requireGroup(chatRef, uid);
    if (!group.isAdmin(uid)) {
      throw StateError('Only group admins can manage admins.');
    }
    if (!group.members.contains(memberId)) {
      throw StateError('That person is not in this group.');
    }

    final nextAdmins = [...group.adminIds];
    if (admin) {
      if (!nextAdmins.contains(memberId)) nextAdmins.add(memberId);
    } else {
      nextAdmins.remove(memberId);
      if (nextAdmins.isEmpty) {
        throw StateError('A group needs at least one admin.');
      }
    }
    if (nextAdmins.length == group.adminIds.length &&
        nextAdmins.toSet().containsAll(group.adminIds)) {
      return;
    }
    await chatRef.update({
      'admins': nextAdmins,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  /// Removes someone from the group. Admins only.
  Future<void> removeGroupMember(String chatId, String memberId) async {
    final uid = _uid;
    if (!isEnabled || uid == null) {
      throw StateError('Sign in to remove group members.');
    }
    if (memberId == uid) {
      return leaveGroup(chatId);
    }
    final chatRef = _firestore.collection(_chats).doc(chatId);
    final group = await _requireGroup(chatRef, uid);
    if (!group.isAdmin(uid)) {
      throw StateError('Only group admins can remove members.');
    }
    if (!group.members.contains(memberId)) return;

    await chatRef.update({
      'members': group.members.where((id) => id != memberId).toList(),
      'admins': group.adminIds.where((id) => id != memberId).toList(),
      'memberProfiles.$memberId': FieldValue.delete(),
      'unread.$memberId': FieldValue.delete(),
      'lastReadAt.$memberId': FieldValue.delete(),
      'typing.$memberId': FieldValue.delete(),
      'clearedAt.$memberId': FieldValue.delete(),
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  /// Leaves a group. If the departing member was the last admin, the first
  /// remaining member is promoted so the group stays manageable.
  Future<void> leaveGroup(String chatId) async {
    final uid = _uid;
    if (!isEnabled || uid == null) {
      throw StateError('Sign in to leave a group.');
    }
    final chatRef = _firestore.collection(_chats).doc(chatId);
    final group = await _requireGroup(chatRef, uid);

    final remaining = group.members.where((id) => id != uid).toList();
    final nextAdmins = group.adminIds.where((id) => id != uid).toList();
    if (remaining.isNotEmpty && nextAdmins.isEmpty) {
      nextAdmins.add(remaining.first);
    }

    await chatRef.update({
      'members': remaining,
      'admins': nextAdmins,
      'memberProfiles.$uid': FieldValue.delete(),
      'unread.$uid': FieldValue.delete(),
      'lastReadAt.$uid': FieldValue.delete(),
      'typing.$uid': FieldValue.delete(),
      'clearedAt.$uid': FieldValue.delete(),
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  Future<GroupChat> _requireGroup(
    DocumentReference<Map<String, dynamic>> chatRef,
    String myUid,
  ) async {
    final snapshot = await chatRef.get();
    final data = snapshot.data();
    final group = data == null ? null : _groupFromData(chatRef.id, myUid, data);
    if (group == null) throw StateError('This group is unavailable.');
    return group;
  }

  Future<String> _uploadImage(Uint8List bytes, String filename) async {
    final type = _mediaType(bytes);
    final dot = filename.lastIndexOf('.');
    final base = (dot > 0 ? filename.substring(0, dot) : filename).replaceAll(
      RegExp(r'[^a-zA-Z0-9_-]'),
      '_',
    );
    final storage = MediaStorage(workerUrl: AppConfig.r2WorkerUrl);
    try {
      return await storage.upload(
        bytes: bytes,
        filename: '${base.isEmpty ? 'photo' : base}.${type.extension}',
        contentType: type.contentType,
      );
    } finally {
      storage.dispose();
    }
  }

  Future<void> _send({
    required ChatUser me,
    required ChatUser peer,
    required String text,
    required String type,
    String? imageUrl,
    ReplyPreview? replyTo,
  }) async {
    final chatRef = await _ensureChat(me: me, peer: peer);
    await _sendToChat(
      chatRef: chatRef,
      me: me,
      recipientIds: [peer.id],
      text: text,
      type: type,
      imageUrl: imageUrl,
      replyTo: replyTo,
    );
  }

  Future<void> _sendToChat({
    required DocumentReference<Map<String, dynamic>> chatRef,
    required ChatUser me,
    required List<String> recipientIds,
    required String text,
    required String type,
    String? imageUrl,
    ReplyPreview? replyTo,
    bool anonymous = false,
  }) async {
    final messageRef = chatRef.collection('messages').doc();
    final now = FieldValue.serverTimestamp();

    final message = <String, dynamic>{
      'senderId': me.id,
      'senderName': anonymous ? 'Anonymous Sender' : me.displayName,
      'senderUsername': anonymous ? '' : me.username,
      'anonymous': anonymous,
      'text': text,
      'type': type,
      'createdAt': now,
      'localCreatedAt': DateTime.now(),
    };
    if (imageUrl != null) message['imageUrl'] = imageUrl;
    if (replyTo != null) message['replyTo'] = replyTo.toMap();

    final batch = _firestore.batch();
    batch.set(messageRef, message);
    batch.update(chatRef, {
      'lastMessage': text,
      'lastMessageId': messageRef.id,
      'lastMessageType': type,
      'lastMessageAt': now,
      'lastSenderId': me.id,
      'lastSenderAnonymous': anonymous,
      'updatedAt': now,
      'lastReadAt.${me.id}': now,
      'unread.${me.id}': 0,
      for (final uid in recipientIds.where((uid) => uid != me.id))
        'unread.$uid': FieldValue.increment(1),
      'typing.${me.id}': FieldValue.delete(),
      'memberProfiles.${me.id}': me.toMap(),
    });
    await batch.commit();
    unawaited(
      NotificationService.instance.notifyMessage(
        chatId: chatRef.id,
        messageId: messageRef.id,
      ),
    );
  }

  /// Marks the chat read and clears the unread badge for the current user.
  Future<void> markRead(String chatId) async {
    final uid = _uid;
    if (!isEnabled || uid == null) return;
    try {
      await _firestore.collection(_chats).doc(chatId).update({
        'lastReadAt.$uid': FieldValue.serverTimestamp(),
        'unread.$uid': 0,
        'typing.$uid': FieldValue.delete(),
      });
    } catch (_) {
      // The chat may not exist yet (a picker was opened and closed).
    }
  }

  /// Publishes a short-lived typing flag for the current user.
  Future<void> setTyping(String chatId, bool typing) async {
    final uid = _uid;
    if (!isEnabled || uid == null) return;
    try {
      await _firestore.collection(_chats).doc(chatId).update({
        'typing.$uid': typing
            ? FieldValue.serverTimestamp()
            : FieldValue.delete(),
      });
    } catch (_) {
      // Typing is best effort and must never break sending.
    }
  }

  /// Clears this user's copy of the history. The peer keeps their messages.
  ///
  /// Returns false when the clear could not be persisted, so the caller can
  /// keep the conversation visible instead of hiding it only locally.
  Future<bool> clearChat(String chatId) async {
    final uid = _uid;
    if (!isEnabled || uid == null) return false;
    try {
      await _firestore.collection(_chats).doc(chatId).update({
        'clearedAt.$uid': FieldValue.serverTimestamp(),
        'unread.$uid': 0,
      });
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<void> editMessage({
    required String chatId,
    required String messageId,
    required String text,
  }) async {
    final uid = _uid;
    final trimmed = text.trim();
    if (!isEnabled || uid == null || trimmed.isEmpty) return;

    final chatRef = _firestore.collection(_chats).doc(chatId);
    final messageRef = chatRef.collection('messages').doc(messageId);
    final snapshot = await messageRef.get();
    if (!snapshot.exists ||
        snapshot.data()?['senderId'] != uid ||
        snapshot.data()?['deleted'] == true) {
      return;
    }

    await messageRef.update({
      'text': trimmed,
      'editedAt': FieldValue.serverTimestamp(),
    });

    final chat = await chatRef.get();
    if (chat.data()?['lastMessageId'] == messageId) {
      await chatRef.update({'lastMessage': trimmed, 'lastMessageType': 'text'});
    }
  }

  /// Soft-deletes a message for everyone and updates the inbox preview.
  Future<void> deleteMessage({
    required String chatId,
    required String messageId,
  }) async {
    final uid = _uid;
    if (!isEnabled || uid == null) return;

    final chatRef = _firestore.collection(_chats).doc(chatId);
    final messageRef = chatRef.collection('messages').doc(messageId);
    final snapshot = await messageRef.get();
    if (!snapshot.exists || snapshot.data()?['senderId'] != uid) return;

    await messageRef.update({
      'text': '',
      'imageUrl': FieldValue.delete(),
      'deleted': true,
      'deletedAt': FieldValue.serverTimestamp(),
      'type': 'deleted',
      'replyTo': FieldValue.delete(),
    });

    final chat = await chatRef.get();
    if (chat.data()?['lastMessageId'] == messageId) {
      await chatRef.update({'lastMessage': '', 'lastMessageType': 'deleted'});
    }
  }

  /// Updates the presence timestamp used by the other participant.
  Future<void> markOnline() async {
    final uid = _uid;
    if (!isEnabled || uid == null) return;
    try {
      await _firestore.collection('users').doc(uid).set({
        'lastSeen': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    } catch (_) {
      // Presence is best effort.
    }
  }

  /// Profile used for the signed-in participant in chats.
  Future<ChatUser> currentChatUser() async {
    final user = AuthService.instance.currentUser!;
    Map<String, dynamic>? profile = await AuthService.instance.cachedProfile();
    if (profile == null) {
      try {
        profile = await AuthService.instance.currentUserProfile(
          fallbackToCache: false,
        );
      } catch (_) {
        profile = null;
      }
    }

    final fullName = (profile?['fullName'] as String?)?.trim();
    final username = (profile?['username'] as String?)?.trim();
    final displayName = fullName != null && fullName.isNotEmpty
        ? fullName
        : (user.displayName?.trim().isNotEmpty == true
              ? user.displayName!.trim()
              : 'You');

    return ChatUser(
      id: user.uid,
      name: displayName,
      username: username ?? '',
      photoUrl: (profile?['photoUrl'] as String?)?.trim(),
      level: (profile?['level'] as String?)?.trim(),
      lastSeen: DateTime.now(),
    );
  }

  static DateTime _conversationTime(DirectChat chat) {
    return chat.lastMessageAt ?? chat.createdAt ?? DateTime(0);
  }

  List<ChatUser> _usersFromCache(List<Map<String, dynamic>> items, String uid) {
    final users = <ChatUser>[];
    for (final item in items) {
      final id = item['id'];
      if (id is! String || id == uid) continue;
      final user = ChatUser.fromMap(id, item);
      if (user.name.trim().isEmpty && user.username.trim().isEmpty) continue;
      users.add(user);
    }
    users.sort(
      (a, b) =>
          a.displayName.toLowerCase().compareTo(b.displayName.toLowerCase()),
    );
    return users;
  }

  List<DirectChat> _conversationsFromCache(
    List<Map<String, dynamic>> items,
    String uid,
  ) {
    final chats = <DirectChat>[];
    for (final item in items) {
      final id = item['id'];
      if (id is! String) continue;
      final chat = _chatFromData(id, uid, item);
      if (chat != null && !chat.isCleared) chats.add(chat);
    }
    chats.sort((a, b) => _conversationTime(b).compareTo(_conversationTime(a)));
    return chats;
  }

  ChatInbox _inboxFromCache(List<Map<String, dynamic>> items, String uid) {
    return _inboxFromRaw(items, uid);
  }

  ChatInbox _inboxFromRaw(List<Map<String, dynamic>> items, String uid) {
    final directs = <DirectChat>[];
    final groups = <GroupChat>[];
    for (final item in items) {
      final id = item['id'];
      if (id is! String) continue;
      if (item['type'] == 'group') {
        final group = _groupFromData(id, uid, item);
        if (group != null) groups.add(group);
      } else {
        final chat = _chatFromData(id, uid, item);
        if (chat != null && !chat.isCleared) directs.add(chat);
      }
    }
    directs.sort(
      (a, b) => _conversationTime(b).compareTo(_conversationTime(a)),
    );
    groups.sort((a, b) {
      return _groupTime(b).compareTo(_groupTime(a));
    });
    return ChatInbox(directChats: directs, groups: groups);
  }

  List<DirectMessage> _messagesFromCache(List<Map<String, dynamic>> items) {
    final messages = <DirectMessage>[];
    for (final item in items) {
      final id = item['id'];
      if (id is! String) continue;
      messages.add(
        DirectMessage.fromMap(id, item, pending: item['createdAt'] == null),
      );
    }
    messages.sort(
      (a, b) =>
          (a.createdAt ?? DateTime(0)).compareTo(b.createdAt ?? DateTime(0)),
    );
    return messages;
  }

  DirectChat? _chatFromData(
    String chatId,
    String myUid,
    Map<String, dynamic> data, {
    ChatUser? peerOverride,
  }) {
    if (data['type'] == 'group') return null;
    final members = (data['members'] as List?)?.whereType<String>().toList(
      growable: false,
    );
    if (members == null || members.length != 2 || !members.contains(myUid)) {
      return null;
    }

    final peerId = members.firstWhere(
      (member) => member != myUid,
      orElse: () => myUid,
    );
    final peer = peerOverride ?? _peerFromData(peerId, data);
    final unread = _map(data['unread']);
    final readAt = _map(data['lastReadAt']);
    final typing = _map(data['typing']);
    final cleared = _map(data['clearedAt']);

    return DirectChat(
      id: chatId,
      peer: peer,
      members: members,
      lastMessage: data['lastMessage'] as String? ?? '',
      lastMessageId: data['lastMessageId'] as String?,
      lastMessageType: data['lastMessageType'] as String? ?? 'text',
      lastSenderId: data['lastSenderId'] as String?,
      lastMessageAt: parseTimestamp(data['lastMessageAt']),
      unreadCount: _asInt(unread[myUid]),
      peerLastReadAt: parseTimestamp(readAt[peerId]),
      peerTypingAt: parseTimestamp(typing[peerId]),
      clearedAt: parseTimestamp(cleared[myUid]),
      createdAt: parseTimestamp(data['createdAt']),
    );
  }

  ChatUser _peerFromData(String peerId, Map<String, dynamic> data) {
    final profiles = _map(data['memberProfiles']);
    final raw = profiles[peerId];
    if (raw is Map) {
      return ChatUser.fromMap(peerId, Map<String, dynamic>.from(raw));
    }
    return ChatUser(id: peerId, name: '', username: '');
  }

  GroupChat? _groupFromData(
    String chatId,
    String myUid,
    Map<String, dynamic> data,
  ) {
    if (data['type'] != 'group') return null;
    final members = (data['members'] as List?)?.whereType<String>().toList(
      growable: false,
    );
    if (members == null || members.isEmpty || !members.contains(myUid)) {
      return null;
    }
    return GroupChat.fromMap(chatId, data, myUid: myUid);
  }

  static DateTime _groupTime(GroupChat group) {
    return group.lastMessageAt ?? group.createdAt ?? DateTime(0);
  }

  static String directChatId(String firstUid, String secondUid) {
    final ids = [firstUid, secondUid]..sort();
    return 'dm_${ids[0]}_${ids[1]}';
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

  static ({String extension, String contentType}) _mediaType(Uint8List bytes) {
    if (bytes.length >= 8 &&
        bytes[0] == 0x89 &&
        bytes[1] == 0x50 &&
        bytes[2] == 0x4E &&
        bytes[3] == 0x47) {
      return (extension: 'png', contentType: 'image/png');
    }
    return (extension: 'jpg', contentType: 'image/jpeg');
  }
}
