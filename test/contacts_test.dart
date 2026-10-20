import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:encore/models/contact_request.dart';
import 'package:encore/models/direct_chat.dart';
import 'package:encore/screens/available_contacts_screen.dart';
import 'package:encore/services/contact_store.dart';

void main() {
  test('contact request ids are deterministic regardless of order', () {
    expect(ContactStore.contactRequestId('zoe', 'ama'), 'contact_ama_zoe');
    expect(ContactStore.contactRequestId('ama', 'zoe'), 'contact_ama_zoe');
  });

  test('contact request parses cached profiles and peer state', () {
    final request = ContactRequest.fromMap('contact_ama_zoe', {
      'fromUid': 'ama',
      'toUid': 'zoe',
      'participants': ['ama', 'zoe'],
      'fromUser': {
        'fullName': 'Ama Mensah',
        'username': 'ama',
        'level': 'CSC 200',
      },
      'toUser': {'fullName': 'Zoe Adeyemi', 'username': 'zoe'},
      'status': 'accepted',
      'createdAt': 1700000000000,
      'chatId': 'dm_ama_zoe',
    });

    expect(request.isAccepted, isTrue);
    expect(request.peerFor('ama').displayName, 'Zoe Adeyemi');
    expect(request.peerFor('zoe').handle, '@ama');
    expect(request.peerIdFor('ama'), 'zoe');
    expect(
      request.createdAt,
      DateTime.fromMillisecondsSinceEpoch(1700000000000),
    );
  });

  testWidgets(
    'available contacts renders request, pending and connected rows',
    (WidgetTester tester) async {
      tester.view.physicalSize = const Size(360, 800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);

      const me = ChatUser(id: 'me', name: 'Me', username: 'me');
      const ama = ChatUser(id: 'ama', name: 'Ama Mensah', username: 'ama');
      const bella = ChatUser(
        id: 'bella',
        name: 'Bella Cole',
        username: 'bella',
      );
      const cara = ChatUser(id: 'cara', name: 'Cara West', username: 'cara');
      const dan = ChatUser(id: 'dan', name: 'Dan Okoro', username: 'dan');

      const incomingRequest = ContactRequest(
        id: 'contact_ama_me',
        fromUid: 'ama',
        toUid: 'me',
        participants: ['ama', 'me'],
        fromUser: ama,
        toUser: me,
        status: ContactRequestStatus.pending,
      );
      const outgoingRequest = ContactRequest(
        id: 'contact_cara_me',
        fromUid: 'me',
        toUid: 'cara',
        participants: ['cara', 'me'],
        fromUser: me,
        toUser: cara,
        status: ContactRequestStatus.pending,
      );
      const acceptedRequest = ContactRequest(
        id: 'contact_bella_me',
        fromUid: 'me',
        toUid: 'bella',
        participants: ['bella', 'me'],
        fromUser: me,
        toUser: bella,
        status: ContactRequestStatus.accepted,
        chatId: 'dm_bella_me',
      );

      final directory = ContactDirectory(
        incoming: const [
          ContactEntry(
            user: ama,
            relation: ContactRelation.incoming,
            request: incomingRequest,
          ),
        ],
        entries: const [
          ContactEntry(
            user: ama,
            relation: ContactRelation.incoming,
            request: incomingRequest,
          ),
          ContactEntry(
            user: bella,
            relation: ContactRelation.connected,
            request: acceptedRequest,
          ),
          ContactEntry(
            user: cara,
            relation: ContactRelation.outgoing,
            request: outgoingRequest,
          ),
          ContactEntry(user: dan, relation: ContactRelation.available),
        ],
      );

      await tester.pumpWidget(
        MaterialApp(
          home: AvailableContactsScreen(
            directory: Stream<ContactDirectory>.value(directory),
          ),
        ),
      );
      await tester.pump();
      await tester.pumpAndSettle();

      expect(find.text('Requests'), findsOneWidget);
      expect(find.text('Contacts'), findsOneWidget);
      expect(find.byKey(const ValueKey('contact-accept-ama')), findsOneWidget);
      expect(find.byKey(const ValueKey('contact-decline-ama')), findsOneWidget);
      expect(
        find.byKey(const ValueKey('contact-message-bella')),
        findsOneWidget,
      );
      expect(find.byKey(const ValueKey('contact-cancel-cara')), findsOneWidget);
      expect(find.byKey(const ValueKey('contact-request-dan')), findsOneWidget);
    },
  );

  testWidgets('available contacts shows search and empty discovery state', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const MaterialApp(home: AvailableContactsScreen()));
    await tester.pump();
    await tester.pumpAndSettle();

    expect(find.text('Available contacts'), findsOneWidget);
    expect(find.text('Send a request before you message'), findsOneWidget);
    expect(find.byKey(const ValueKey('contacts-search')), findsOneWidget);
    expect(find.text('No other members yet.'), findsOneWidget);
  });
}
