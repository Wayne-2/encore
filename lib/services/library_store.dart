import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

import '../models/library_material.dart';
import 'auth_service.dart';

/// Public library uploads plus the signed-in user's saved items, highlights
/// and reading history.
///
/// Public materials live in `libraryMaterials`; everything personal lives in
/// subcollections under `users/{uid}`. Without Firebase (widget tests) the
/// library starts with a small in-memory sample so the UI still renders.
class LibraryStore extends ChangeNotifier {
  LibraryStore._();

  static final LibraryStore instance = LibraryStore._();

  static const String _materialsCollection = 'libraryMaterials';
  static const int _maxMaterials = 100;
  static const int _maxHighlights = 100;
  static const int _maxHistory = 50;

  final List<LibraryMaterial> _materials = [];
  final List<LibraryHighlight> _highlights = [];
  final List<LibraryHistoryEntry> _history = [];
  final Set<String> _savedIds = {};
  final Set<String> _pendingMaterialIds = {};

  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? _materialsSub;
  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? _savedSub;
  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? _highlightsSub;
  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? _historySub;
  bool _listening = false;

  List<LibraryMaterial> get materials => List.unmodifiable(_materials);
  List<LibraryHighlight> get highlights => List.unmodifiable(_highlights);
  List<LibraryHistoryEntry> get history => List.unmodifiable(_history);

  List<LibraryMaterial> get savedMaterials => [
    for (final id in _savedIds)
      ..._materials.where((material) => material.id == id),
  ];

  List<LibraryHighlight> highlightsFor(String materialId) => [
    for (final highlight in _highlights)
      if (highlight.materialId == materialId) highlight,
  ];

  bool isSaved(String materialId) => _savedIds.contains(materialId);

  LibraryHistoryEntry? get continueReading {
    for (final entry in _history) {
      if (entry.progress < 0.98) return entry;
    }
    return null;
  }

  double progressFor(String materialId) {
    for (final entry in _history) {
      if (entry.materialId == materialId) return entry.progress;
    }
    return 0;
  }

  String newMaterialId() => AuthService.isAvailable
      ? FirebaseFirestore.instance.collection(_materialsCollection).doc().id
      : 'material-${DateTime.now().microsecondsSinceEpoch}';

  Future<void> listen() async {
    if (_listening) return;
    _listening = true;

    if (!AuthService.isAvailable) {
      _seedSamples();
      return;
    }

    final firestore = FirebaseFirestore.instance;
    _materialsSub = firestore
        .collection(_materialsCollection)
        .orderBy('createdAt', descending: true)
        .limit(_maxMaterials)
        .snapshots()
        .listen(_onMaterials, onError: (Object _) {});

    final uid = AuthService.instance.currentUser?.uid;
    if (uid == null) return;

    _savedSub = _userCollection(
      uid,
      'savedMaterials',
    ).snapshots().listen(_onSaved, onError: (Object _) {});
    _highlightsSub = _userCollection(
      uid,
      'libraryHighlights',
    ).snapshots().listen(_onHighlights, onError: (Object _) {});
    _historySub = _userCollection(
      uid,
      'libraryHistory',
    ).snapshots().listen(_onHistory, onError: (Object _) {});
  }

  Future<void> publish(LibraryMaterial material) async {
    if (!AuthService.isAvailable) {
      _insertMaterial(material);
      return;
    }
    final user = AuthService.instance.currentUser;
    if (user == null) {
      throw const LibraryStoreException('Sign in to publish to the library.');
    }

    _pendingMaterialIds.add(material.id);
    _insertMaterial(material);
    try {
      await FirebaseFirestore.instance
          .collection(_materialsCollection)
          .doc(material.id)
          .set({
            'title': material.title,
            'fileName': material.fileName,
            'kind': material.kind == LibraryMaterialKind.image
                ? 'image'
                : 'pdf',
            'subject': material.subject,
            'extractedText': material.extractedText,
            'textUrl': material.textUrl,
            'textFileName': material.textFileName,
            'uploaderId': user.uid,
            'uploaderName': material.uploaderName,
            'createdAt': FieldValue.serverTimestamp(),
          });
    } catch (_) {
      _pendingMaterialIds.remove(material.id);
      _materials.removeWhere((item) => item.id == material.id);
      notifyListeners();
      rethrow;
    }
  }

  Future<void> toggleSaved(String materialId) async {
    final wasSaved = _savedIds.contains(materialId);
    if (wasSaved) {
      _savedIds.remove(materialId);
    } else {
      _savedIds.add(materialId);
    }
    notifyListeners();

    final uid = AuthService.instance.currentUser?.uid;
    if (!AuthService.isAvailable || uid == null) return;

    final material = _materials
        .where((item) => item.id == materialId)
        .firstOrNull;
    final ref = _userCollection(uid, 'savedMaterials').doc(materialId);
    try {
      if (wasSaved) {
        await ref.delete();
      } else {
        await ref.set({
          'materialId': materialId,
          'title': material?.title ?? '',
          'kind': material?.kind == LibraryMaterialKind.image ? 'image' : 'pdf',
          'savedAt': FieldValue.serverTimestamp(),
        });
      }
    } catch (_) {
      if (wasSaved) {
        _savedIds.add(materialId);
      } else {
        _savedIds.remove(materialId);
      }
      notifyListeners();
      rethrow;
    }
  }

  Future<void> addHighlight({
    required String materialId,
    required String materialTitle,
    required String text,
  }) async {
    final trimmed = text.trim();
    if (trimmed.isEmpty) return;
    final quote = trimmed.length > 2000 ? trimmed.substring(0, 2000) : trimmed;

    final uid = AuthService.instance.currentUser?.uid;
    final ref = AuthService.isAvailable && uid != null
        ? _userCollection(uid, 'libraryHighlights').doc()
        : null;
    final highlight = LibraryHighlight(
      id: ref?.id ?? 'highlight-${DateTime.now().microsecondsSinceEpoch}',
      materialId: materialId,
      materialTitle: materialTitle,
      text: quote,
      createdAt: DateTime.now(),
    );
    _highlights.insert(0, highlight);
    notifyListeners();

    if (ref == null) return;
    try {
      await ref.set({
        'materialId': materialId,
        'materialTitle': materialTitle,
        'text': quote,
        'createdAt': FieldValue.serverTimestamp(),
      });
    } catch (_) {
      _highlights.removeWhere((item) => item.id == highlight.id);
      notifyListeners();
      rethrow;
    }
  }

  void recordRead(LibraryMaterial material) {
    final index = _history.indexWhere(
      (entry) => entry.materialId == material.id,
    );
    final previous = index == -1 ? null : _history[index];
    final entry = LibraryHistoryEntry(
      materialId: material.id,
      title: material.title,
      kind: material.kind,
      readCount: (previous?.readCount ?? 0) + 1,
      progress: previous?.progress ?? 0,
      lastReadAt: DateTime.now(),
    );
    _history
      ..removeWhere((item) => item.materialId == material.id)
      ..insert(0, entry);
    if (_history.length > _maxHistory) {
      _history.removeRange(_maxHistory, _history.length);
    }
    notifyListeners();

    final uid = AuthService.instance.currentUser?.uid;
    if (!AuthService.isAvailable || uid == null) return;
    unawaited(
      _userCollection(uid, 'libraryHistory')
          .doc(material.id)
          .set({
            'materialId': material.id,
            'title': material.title,
            'kind': material.kind == LibraryMaterialKind.image
                ? 'image'
                : 'pdf',
            'lastReadAt': FieldValue.serverTimestamp(),
            'readCount': FieldValue.increment(1),
            'progress': entry.progress,
          }, SetOptions(merge: true))
          .catchError((Object _) {}),
    );
  }

  void saveProgress(LibraryMaterial material, double progress) {
    final index = _history.indexWhere(
      (entry) => entry.materialId == material.id,
    );
    if (index == -1) return;

    final value = progress.clamp(0.0, 1.0);
    final current = _history[index];
    if ((current.progress - value).abs() < 0.01) return;

    final updated = LibraryHistoryEntry(
      materialId: current.materialId,
      title: current.title,
      kind: current.kind,
      readCount: current.readCount,
      progress: value,
      lastReadAt: current.lastReadAt,
    );
    _history[index] = updated;
    notifyListeners();

    final uid = AuthService.instance.currentUser?.uid;
    if (!AuthService.isAvailable || uid == null) return;
    unawaited(
      _userCollection(uid, 'libraryHistory')
          .doc(material.id)
          .set({'progress': value}, SetOptions(merge: true))
          .catchError((Object _) {}),
    );
  }

  CollectionReference<Map<String, dynamic>> _userCollection(
    String uid,
    String name,
  ) => FirebaseFirestore.instance.collection('users').doc(uid).collection(name);

  void _onMaterials(QuerySnapshot<Map<String, dynamic>> snapshot) {
    final server = snapshot.docs
        .map(LibraryMaterial.fromDoc)
        .toList(growable: false);
    final serverIds = server.map((material) => material.id).toSet();
    _pendingMaterialIds.removeWhere(serverIds.contains);
    final pending = [
      for (final material in _materials)
        if (_pendingMaterialIds.contains(material.id)) material,
    ];
    _materials
      ..clear()
      ..addAll([...pending, ...server]);
    notifyListeners();
  }

  void _onSaved(QuerySnapshot<Map<String, dynamic>> snapshot) {
    _savedIds
      ..clear()
      ..addAll(
        snapshot.docs.map(
          (doc) => doc.data()['materialId'] as String? ?? doc.id,
        ),
      );
    notifyListeners();
  }

  void _onHighlights(QuerySnapshot<Map<String, dynamic>> snapshot) {
    _highlights
      ..clear()
      ..addAll(
        snapshot.docs.map(LibraryHighlight.fromDoc).take(_maxHighlights),
      );
    _highlights.sort(
      (a, b) =>
          (b.createdAt ?? DateTime(0)).compareTo(a.createdAt ?? DateTime(0)),
    );
    notifyListeners();
  }

  void _onHistory(QuerySnapshot<Map<String, dynamic>> snapshot) {
    _history
      ..clear()
      ..addAll(
        snapshot.docs.map(LibraryHistoryEntry.fromDoc).take(_maxHistory),
      );
    _history.sort(
      (a, b) =>
          (b.lastReadAt ?? DateTime(0)).compareTo(a.lastReadAt ?? DateTime(0)),
    );
    notifyListeners();
  }

  void _insertMaterial(LibraryMaterial material) {
    _materials
      ..removeWhere((item) => item.id == material.id)
      ..insert(0, material);
    notifyListeners();
  }

  void _seedSamples() {
    if (_materials.isNotEmpty) return;
    _materials.addAll(_sampleMaterials);
    notifyListeners();
  }

  @visibleForTesting
  void resetForTests() {
    _materialsSub?.cancel();
    _savedSub?.cancel();
    _highlightsSub?.cancel();
    _historySub?.cancel();
    _materialsSub = null;
    _savedSub = null;
    _highlightsSub = null;
    _historySub = null;
    _listening = false;
    _savedIds.clear();
    _pendingMaterialIds.clear();
    _highlights.clear();
    _history.clear();
    _materials.clear();
    _seedSamples();
  }
}

class LibraryStoreException implements Exception {
  const LibraryStoreException(this.message);

  final String message;

  @override
  String toString() => message;
}

final List<LibraryMaterial> _sampleMaterials = [
  LibraryMaterial(
    id: 'demo-csc200-notes',
    title: 'Data Structures & Algorithms Lecture Notes',
    fileName: 'CSC200-lecture-notes.pdf',
    kind: LibraryMaterialKind.pdf,
    subject: 'CSC 200',
    uploaderName: 'Dr. A. Mensah',
    createdAt: DateTime.now().subtract(const Duration(days: 2)),
    isDemo: true,
    extractedText: '''
Data Structures & Algorithms
Lecture Notes — CSC 200

Stacks and queues

A stack is a linear structure that follows the last in, first out principle. The most recent element is the first to leave. Push adds an element to the top, pop removes the top element, and peek reads the top without removing it. Stacks power undo history, expression parsing and depth-first search.

A queue follows first in, first out. Enqueue adds at the back, dequeue removes from the front. Queues appear in scheduling, buffering and breadth-first search.

Linked lists

A linked list stores each value in a node together with a reference to the next node. Insertion and deletion at a known node are constant time, but lookup is linear because nodes are not contiguous in memory.

Trees and graphs

A tree is a connected acyclic graph. Binary search trees keep smaller keys on the left and larger keys on the right, giving logarithmic search when balanced. Graphs model relationships such as roads, friendships and course prerequisites. Breadth-first search finds shortest paths in unweighted graphs, while depth-first search exposes cycles and connected components.

Complexity

Always state the input size when describing complexity. Merge sort runs in O(n log n) time and O(n) extra space. Binary search runs in O(log n) time but requires sorted input. Hash tables offer average O(1) lookup, with collisions handled by chaining or open addressing.
''',
  ),
  LibraryMaterial(
    id: 'demo-mth101-problem-set',
    title: 'MTH 101 Calculus Problem Set',
    fileName: 'MTH101-problem-set.pdf',
    kind: LibraryMaterialKind.pdf,
    subject: 'MTH 101',
    uploaderName: 'Nana A.',
    createdAt: DateTime.now().subtract(const Duration(days: 5)),
    isDemo: true,
    extractedText: '''
MTH 101 — Calculus Problem Set

Limits

1. Evaluate the limit of (sin x) / x as x approaches zero. Explain why the result holds geometrically.

2. Find the limit of (x squared minus 9) / (x minus 3) as x approaches 3. Show the algebraic simplification before substituting.

Derivatives

3. Differentiate f(x) = x cubed minus 4x plus 7. Then find the equation of the tangent line at x = 2.

4. Use the chain rule to differentiate g(x) = (3x squared plus 1) to the fifth power.

Integrals

5. Evaluate the indefinite integral of 6x squared with respect to x.

6. Use substitution to evaluate the integral of 2x cos(x squared) dx.

Applications

7. A particle moves along a line with position s(t) = t cubed minus 6t squared plus 9t. Find when the particle is at rest and describe its motion.

8. Sketch a function with a local maximum, a local minimum and one point of inflection. Label each feature.
''',
  ),
  LibraryMaterial(
    id: 'demo-csc305-slides',
    title: 'Database Systems Revision Slides',
    fileName: 'CSC305-revision-slides.pdf',
    kind: LibraryMaterialKind.pdf,
    subject: 'CSC 305',
    uploaderName: 'Faculty of Science',
    createdAt: DateTime.now().subtract(const Duration(days: 8)),
    isDemo: true,
    extractedText: '''
Database Systems — Revision Slides
CSC 305

Normalization

Normalization removes redundancy by decomposing a relation into smaller, well-structured relations. First normal form requires atomic values. Second normal form removes partial dependencies on a composite key. Third normal form removes transitive dependencies. Boyce-Codd normal form requires every determinant to be a candidate key.

Transactions

A transaction is a unit of work that must be atomic, consistent, isolated and durable. Atomicity means all operations succeed or none do. Consistency preserves declared invariants. Isolation prevents concurrent transactions from observing partial work. Durability keeps committed changes after a crash.

Indexes

An index speeds up reads at the cost of extra storage and slower writes. B-tree indexes support equality and range queries. A covering index includes every column needed by a query so the engine can answer from the index alone.

Query planning

The planner estimates the cost of alternative execution plans using statistics. Selectivity estimates how many rows a predicate keeps. Join order matters: filtering early usually reduces intermediate results.
''',
  ),
  LibraryMaterial(
    id: 'demo-csc200-past-questions',
    title: 'CSC 200 Past Questions & Marking Scheme',
    fileName: 'CSC200-past-questions.pdf',
    kind: LibraryMaterialKind.pdf,
    subject: 'CSC 200',
    uploaderName: 'Encore Library',
    createdAt: DateTime.now().subtract(const Duration(days: 12)),
    isDemo: true,
    extractedText: '''
CSC 200 — Past Questions and Marking Scheme

Question 1

Define a stack and give two applications. Marking scheme: one mark for the LIFO definition, one mark for each valid application. Accept undo history, expression evaluation, backtracking or call stacks.

Question 2

Compare arrays and linked lists for insertion, deletion and random access. A complete answer states that arrays give constant-time random access while linked lists require traversal. Insertion at the front is constant time for linked lists but linear for arrays without extra space.

Question 3

Write pseudocode for breadth-first search on an unweighted graph. The solution must use a queue, mark nodes when they are enqueued, and record the distance from the source. Marks are awarded for correctness, termination and clear variable names.

Question 4

Explain why a balanced binary search tree gives logarithmic search. The answer should connect height to the number of comparisons and mention what happens when the tree becomes unbalanced.
''',
  ),
  LibraryMaterial(
    id: 'demo-mth101-formula-sheet',
    title: 'Linear Algebra Formula Sheet',
    fileName: 'MTH101-formula-sheet.pdf',
    kind: LibraryMaterialKind.pdf,
    subject: 'MTH 101',
    uploaderName: 'Prof. K. Okafor',
    createdAt: DateTime.now().subtract(const Duration(days: 18)),
    isDemo: true,
    extractedText: '''
Linear Algebra Formula Sheet

Vectors

The dot product of u and v is the sum of the products of matching components. It equals the product of their lengths and the cosine of the angle between them. Two nonzero vectors are orthogonal exactly when their dot product is zero.

The cross product produces a vector perpendicular to both inputs and is defined in three dimensions. Its magnitude equals the area of the parallelogram spanned by the vectors.

Matrices

Matrix multiplication is associative but not commutative. The transpose of a product reverses the order: the transpose of AB equals the transpose of B times the transpose of A. A square matrix is invertible exactly when its determinant is nonzero.

Eigenvalues

An eigenvector of a matrix is a nonzero vector that changes only by a scalar factor when multiplied by the matrix. That scalar is the eigenvalue. Eigenvalues are roots of the characteristic polynomial.

Systems of equations

A system can be solved by elimination, by substitution or by matrix inversion when the coefficient matrix is invertible. The rank of the coefficient matrix determines whether a solution exists and whether it is unique.
''',
  ),
];
