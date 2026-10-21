import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/contact_request.dart';
import '../models/direct_chat.dart';
import 'auth_service.dart';
import 'chat_store.dart';
import 'local_cache.dart';
import 'notification_service.dart';

/// Firestore-backed contact requests.
///
/// A pair has at most one request document. Before it is accepted neither user
/// may open a DM from discovery; accepting it creates the deterministic chat
/// document so the thread appears in both inboxes.
class ContactStore {
  ContactStore._();

  static final ContactStore instance = ContactStore._();

  static const String _requests = 'contactRequests';

  FirebaseFirestore get _firestore => FirebaseFirestore.instance;

  String? get _uid => AuthService.instance.currentUser?.uid;

  String? get currentUid => _uid;

  bool get isEnabled => AuthService.isAvailable && _uid != null;

  static String contactRequestId(String firstUid, String secondUid) {
    final ids = [firstUid, secondUid]..sort();
    return 'contact_${ids[0]}_${ids[1]}';
  }

  /// Hive-first request stream, newest first.
  Stream<List<ContactRequest>> watchRequests() {
    final uid = _uid;
    if (!isEnabled || uid == null) {
      return Stream<List<ContactRequest>>.value(const []);
    }

    late StreamController<List<ContactRequest>> controller;
    StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? sub;

    controller = StreamController<List<ContactRequest>>(
      onListen: () async {
        final cached = await LocalCache.instance.contactRequests(uid);
        if (controller.isClosed) return;
        if (cached != null) controller.add(_requestsFromCache(cached, uid));

        sub = _firestore
            .collection(_requests)
            .where('participants', arrayContains: uid)
            .snapshots()
            .listen((snapshot) {
              final raw = [
                for (final doc in snapshot.docs) {'id': doc.id, ...doc.data()},
              ];
              controller.add(_requestsFromCache(raw, uid));
              unawaited(LocalCache.instance.saveContactRequests(uid, raw));
            }, onError: controller.addError);
      },
      onCancel: () async {
        await sub?.cancel();
      },
    );

    return controller.stream;
  }

  /// Combines the user directory with request state for the discovery page.
  Stream<ContactDirectory> watchDirectory() {
    final uid = _uid;
    if (!isEnabled || uid == null) {
      return Stream<ContactDirectory>.value(ContactDirectory.empty);
    }

    late StreamController<ContactDirectory> controller;
    StreamSubscription<List<ChatUser>>? usersSub;
    StreamSubscription<List<ContactRequest>>? requestsSub;
    List<ChatUser>? users;
    List<ContactRequest>? requests;

    void emit() {
      if (controller.isClosed || users == null || requests == null) return;
      controller.add(_buildDirectory(uid, users!, requests!));
    }

    controller = StreamController<ContactDirectory>(
      onListen: () {
        usersSub = ChatStore.instance.watchUsers().listen((value) {
          users = value;
          emit();
        }, onError: controller.addError);
        requestsSub = watchRequests().listen((value) {
          requests = value;
          emit();
        }, onError: controller.addError);
      },
      onCancel: () async {
        await usersSub?.cancel();
        await requestsSub?.cancel();
      },
    );

    return controller.stream;
  }

  Future<void> sendRequest(ChatUser peer) async {
    final uid = _uid;
    if (!isEnabled || uid == null) {
      throw StateError('Sign in to send contact requests.');
    }
    if (peer.id == uid) return;

    final me = await ChatStore.instance.currentChatUser();
    final ref = _firestore
        .collection(_requests)
        .doc(contactRequestId(uid, peer.id));
    Map<String, dynamic>? existingData;
    try {
      final existing = await ref.get();
      if (existing.exists) existingData = existing.data();
    } on FirebaseException catch (error) {
      // Reading a missing request is denied by older rules because the
      // resource-based read condition cannot resolve a null document. The
      // create below still validates ownership, so treat it as "not found".
      if (error.code != 'permission-denied') rethrow;
    }
    if (existingData != null) {
      if (existingData['status'] == 'accepted' ||
          existingData['fromUid'] == uid) {
        return;
      }
      throw StateError('This person already sent you a request.');
    }

    await ref.set({
      'fromUid': uid,
      'toUid': peer.id,
      'participants': [uid, peer.id],
      'fromUser': me.toMap(),
      'toUser': peer.toMap(),
      'status': 'pending',
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    });
    await NotificationService.instance.notifyContactRequest(ref.id);
  }

  /// Accepts an incoming request and creates the DM for both participants.
  Future<String> acceptRequest(ContactRequest request) async {
    final uid = _uid;
    if (!isEnabled || uid == null) {
      throw StateError('Sign in to accept contact requests.');
    }
    if (request.toUid != uid) {
      throw StateError('Only the recipient can accept this request.');
    }
    if (request.isAccepted) {
      return request.chatId ??
          ChatStore.directChatId(request.fromUid, request.toUid);
    }

    final chatId = ChatStore.directChatId(request.fromUid, request.toUid);
    final chatRef = _firestore.collection('chats').doc(chatId);
    final chat = await chatRef.get();
    final batch = _firestore.batch();

    batch.update(_firestore.collection(_requests).doc(request.id), {
      'status': 'accepted',
      'chatId': chatId,
      'respondedAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    });

    if (!chat.exists) {
      batch.set(chatRef, {
        'type': 'dm',
        'members': [request.fromUid, request.toUid],
        'memberProfiles': {
          request.fromUid: request.fromUser.toMap(),
          request.toUid: request.toUser.toMap(),
        },
        'unread': {request.fromUid: 0, request.toUid: 0},
        'lastReadAt': {},
        'typing': {},
        'clearedAt': {},
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });
    }

    await batch.commit();
    return chatId;
  }

  /// The recipient dismisses an incoming request.
  Future<void> declineRequest(ContactRequest request) async {
    final uid = _uid;
    if (!isEnabled || uid == null || request.toUid != uid) return;
    await _firestore.collection(_requests).doc(request.id).delete();
  }

  /// The sender withdraws a pending request.
  Future<void> cancelRequest(ContactRequest request) async {
    final uid = _uid;
    if (!isEnabled || uid == null || request.fromUid != uid) return;
    await _firestore.collection(_requests).doc(request.id).delete();
  }

  ContactDirectory _buildDirectory(
    String uid,
    List<ChatUser> users,
    List<ContactRequest> requests,
  ) {
    final usersById = {for (final user in users) user.id: user};
    final requestByPeer = <String, ContactRequest>{};

    for (final request in requests) {
      if (!request.participants.contains(uid)) continue;
      final peerId = request.peerIdFor(uid);
      final existing = requestByPeer[peerId];
      if (existing == null || (request.isAccepted && !existing.isAccepted)) {
        requestByPeer[peerId] = request;
      }
      usersById.putIfAbsent(peerId, () => request.peerFor(uid));
    }

    final entries = <ContactEntry>[];
    for (final user in usersById.values) {
      if (user.id == uid) continue;
      final request = requestByPeer[user.id];
      final relation = switch (request?.status) {
        ContactRequestStatus.accepted => ContactRelation.connected,
        ContactRequestStatus.pending when request!.toUid == uid =>
          ContactRelation.incoming,
        ContactRequestStatus.pending => ContactRelation.outgoing,
        null => ContactRelation.available,
      };
      entries.add(
        ContactEntry(user: user, relation: relation, request: request),
      );
    }
    entries.sort(
      (a, b) => a.user.displayName.toLowerCase().compareTo(
        b.user.displayName.toLowerCase(),
      ),
    );

    final incoming =
        entries
            .where((entry) => entry.relation == ContactRelation.incoming)
            .toList(growable: false)
          ..sort(
            (a, b) => (b.request?.createdAt ?? DateTime(0)).compareTo(
              a.request?.createdAt ?? DateTime(0),
            ),
          );

    return ContactDirectory(incoming: incoming, entries: entries);
  }

  List<ContactRequest> _requestsFromCache(
    List<Map<String, dynamic>> items,
    String uid,
  ) {
    final requests = <ContactRequest>[];
    for (final item in items) {
      final id = item['id'];
      if (id is! String) continue;
      final request = ContactRequest.fromMap(id, item);
      if (!request.participants.contains(uid)) continue;
      requests.add(request);
    }
    requests.sort(
      (a, b) =>
          (b.createdAt ?? DateTime(0)).compareTo(a.createdAt ?? DateTime(0)),
    );
    return requests;
  }
}
