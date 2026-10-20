import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

import 'auth_service.dart';

/// The tallies and the current user's own picks for one item.
class ReactionSummary {
  const ReactionSummary({this.counts = const {}, this.mine = const {}});

  final Map<String, int> counts;
  final Set<String> mine;
}

/// Persists emoji reactions in a `reactions` subcollection under any document.
///
/// Each user gets one document keyed by their uid containing the emojis they
/// picked, so counts can be rebuilt and "mine" stays in sync across devices.
class ReactionStore extends ChangeNotifier {
  ReactionStore._();

  static final ReactionStore instance = ReactionStore._();

  final Map<String, Map<String, int>> _counts = {};
  final Map<String, Set<String>> _mine = {};
  final Map<String, StreamSubscription<QuerySnapshot<Map<String, dynamic>>>>
  _subscriptions = {};
  final Map<String, int> _references = {};

  /// Registers a listener for [documentPath]'s reactions. Pair every call with
  /// [stopListening].
  void listen(String documentPath) {
    if (documentPath.isEmpty) return;

    final references = _references[documentPath] ?? 0;
    _references[documentPath] = references + 1;
    if (references > 0 || !AuthService.isAvailable) return;

    _subscriptions[documentPath] = FirebaseFirestore.instance
        .doc(documentPath)
        .collection('reactions')
        .snapshots()
        .listen(
          (snapshot) => _onSnapshot(documentPath, snapshot),
          onError: (Object _) {},
        );
  }

  void _onSnapshot(
    String documentPath,
    QuerySnapshot<Map<String, dynamic>> snapshot,
  ) {
    final counts = <String, int>{};
    final mine = <String>{};
    final uid = AuthService.instance.currentUser?.uid;

    for (final doc in snapshot.docs) {
      final emojis = doc.data()['emojis'];
      if (emojis is! List) continue;
      for (final emoji in emojis.whereType<String>()) {
        counts[emoji] = (counts[emoji] ?? 0) + 1;
        if (doc.id == uid) mine.add(emoji);
      }
    }

    _counts[documentPath] = counts;
    _mine[documentPath] = mine;
    notifyListeners();
  }

  void stopListening(String documentPath) {
    final references = (_references[documentPath] ?? 0) - 1;
    if (references > 0) {
      _references[documentPath] = references;
      return;
    }

    _references.remove(documentPath);
    final subscription = _subscriptions.remove(documentPath);
    if (subscription != null) unawaited(subscription.cancel());
  }

  /// The current tallies for [documentPath], falling back to [initial] before
  /// the first snapshot arrives.
  ReactionSummary summaryFor(
    String documentPath, {
    Map<String, int> initial = const {},
  }) {
    final counts = _counts[documentPath];
    if (counts == null) {
      return ReactionSummary(counts: Map.unmodifiable(initial));
    }
    return ReactionSummary(
      counts: Map.unmodifiable(counts),
      mine: Set.unmodifiable(_mine[documentPath] ?? const {}),
    );
  }

  /// Adds or removes [emoji] for the signed-in user.
  Future<void> toggle(String documentPath, String emoji) async {
    if (documentPath.isEmpty) return;

    final counts = Map<String, int>.of(_counts[documentPath] ?? const {});
    final mine = Set<String>.of(_mine[documentPath] ?? const {});
    final wasMine = mine.contains(emoji);

    if (wasMine) {
      mine.remove(emoji);
      final next = (counts[emoji] ?? 1) - 1;
      if (next <= 0) {
        counts.remove(emoji);
      } else {
        counts[emoji] = next;
      }
    } else {
      mine.add(emoji);
      counts[emoji] = (counts[emoji] ?? 0) + 1;
    }

    _counts[documentPath] = counts;
    _mine[documentPath] = mine;
    notifyListeners();

    if (!AuthService.isAvailable || documentPath.startsWith('trends/trend-')) {
      return;
    }
    final uid = AuthService.instance.currentUser?.uid;
    if (uid == null) return;

    final reference = FirebaseFirestore.instance.doc(
      '$documentPath/reactions/$uid',
    );
    try {
      if (mine.isEmpty) {
        await reference.delete();
      } else {
        await reference.set({'emojis': mine.toList()}, SetOptions(merge: true));
      }
    } catch (_) {
      // A follow-up snapshot reconciles the optimistic state.
    }
  }

  /// Cancels listeners and drops all cached tallies (used by tests).
  void clear() {
    for (final subscription in _subscriptions.values) {
      unawaited(subscription.cancel());
    }
    _subscriptions.clear();
    _references.clear();
    _counts.clear();
    _mine.clear();
    notifyListeners();
  }
}
