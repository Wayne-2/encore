import 'direct_chat.dart';

/// Where a person sits in the current user's contact flow.
enum ContactRelation { available, outgoing, incoming, connected }

enum ContactRequestStatus { pending, accepted }

/// A request that must be accepted before two people can DM each other.
///
/// One document exists per pair, keyed by the sorted UIDs, so reciprocal
/// requests cannot create two competing request documents.
class ContactRequest {
  const ContactRequest({
    required this.id,
    required this.fromUid,
    required this.toUid,
    required this.participants,
    required this.fromUser,
    required this.toUser,
    required this.status,
    this.createdAt,
    this.respondedAt,
    this.chatId,
  });

  final String id;
  final String fromUid;
  final String toUid;
  final List<String> participants;
  final ChatUser fromUser;
  final ChatUser toUser;
  final ContactRequestStatus status;
  final DateTime? createdAt;
  final DateTime? respondedAt;
  final String? chatId;

  bool get isPending => status == ContactRequestStatus.pending;

  bool get isAccepted => status == ContactRequestStatus.accepted;

  String peerIdFor(String uid) => fromUid == uid ? toUid : fromUid;

  ChatUser peerFor(String uid) => fromUid == uid ? toUser : fromUser;

  factory ContactRequest.fromMap(String id, Map<String, dynamic> data) {
    final fromUid = data['fromUid'] as String? ?? '';
    final toUid = data['toUid'] as String? ?? '';
    final rawFrom = data['fromUser'];
    final rawTo = data['toUser'];

    ChatUser readUser(Object? value, String uid) {
      if (value is Map) {
        return ChatUser.fromMap(uid, Map<String, dynamic>.from(value));
      }
      return ChatUser(id: uid, name: '', username: '');
    }

    return ContactRequest(
      id: id,
      fromUid: fromUid,
      toUid: toUid,
      participants:
          (data['participants'] as List?)?.whereType<String>().toList(
            growable: false,
          ) ??
          [fromUid, toUid],
      fromUser: readUser(rawFrom, fromUid),
      toUser: readUser(rawTo, toUid),
      status: data['status'] == 'accepted'
          ? ContactRequestStatus.accepted
          : ContactRequestStatus.pending,
      createdAt: parseTimestamp(data['createdAt']),
      respondedAt: parseTimestamp(data['respondedAt']),
      chatId: (data['chatId'] as String?)?.trim(),
    );
  }
}

/// A person plus their current relationship to the signed-in user.
class ContactEntry {
  const ContactEntry({
    required this.user,
    required this.relation,
    this.request,
  });

  final ChatUser user;
  final ContactRelation relation;
  final ContactRequest? request;
}

/// Incoming requests plus everyone the current user can discover.
class ContactDirectory {
  const ContactDirectory({required this.incoming, required this.entries});

  static const ContactDirectory empty = ContactDirectory(
    incoming: [],
    entries: [],
  );

  final List<ContactEntry> incoming;

  /// Every discoverable person, including incoming/outgoing/connected ones.
  final List<ContactEntry> entries;
}
