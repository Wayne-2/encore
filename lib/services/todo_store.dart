import 'dart:async';

import 'package:flutter/foundation.dart';

import '../models/todo_item.dart';
import 'auth_service.dart';
import 'local_cache.dart';
import 'notification_service.dart';

/// Local, account-scoped store for the personal todo list.
///
/// Every mutation is persisted to [LocalCache] and keeps the matching alarm
/// notification in sync. The store is intentionally lightweight so the
/// profile badge and the todo page can share one live instance.
class TodoStore extends ChangeNotifier {
  TodoStore._();

  static final TodoStore instance = TodoStore._();

  final List<TodoItem> _items = [];
  String? _scope;
  bool _loaded = false;
  bool _loading = false;
  Future<void>? _pendingLoad;

  bool get isLoading => _loading;
  bool get isLoaded => _loaded;
  List<TodoItem> get items => List.unmodifiable(_items);

  static String get _currentScope {
    if (!AuthService.isAvailable) return 'local';
    return AuthService.instance.currentUser?.uid ?? 'local';
  }

  List<TodoItem> get pending =>
      _items.where((item) => !item.completed).toList()
        ..sort((a, b) => a.dueAt.compareTo(b.dueAt));

  List<TodoItem> get completed =>
      _items.where((item) => item.completed).toList()..sort(
        (a, b) =>
            (b.completedAt ?? b.dueAt).compareTo(a.completedAt ?? a.dueAt),
      );

  List<TodoItem> get overdue {
    final now = DateTime.now();
    return pending
        .where((item) => !item.completed && item.dueAt.isBefore(now))
        .toList();
  }

  List<TodoItem> get dueToday {
    final now = DateTime.now();
    return pending.where((item) => item.isDueToday(now)).toList();
  }

  List<TodoItem> get upcoming {
    final now = DateTime.now();
    return pending
        .where((item) => item.dueAt.isAfter(now) && !item.isDueToday(now))
        .toList();
  }

  /// Pending items that need attention now: overdue or due today.
  int get alertCount => overdue.length + dueToday.length;

  int get todayCompleted => _items
      .where(
        (item) =>
            item.completed &&
            item.completedAt != null &&
            _sameDay(item.completedAt!, DateTime.now()),
      )
      .length;

  int get todayTotal => dueToday.length + todayCompleted;

  TodoItem? get nextReminder {
    final now = DateTime.now();
    TodoItem? next;
    for (final item in pending) {
      if (!item.alarm || !item.dueAt.isAfter(now)) continue;
      if (next == null || item.dueAt.isBefore(next.dueAt)) next = item;
    }
    return next;
  }

  /// Loads the signed-in account's todos once and restores any alarms.
  Future<void> initialize() {
    final scope = _currentScope;
    if (_loaded && _scope == scope) return Future.value();
    if (_loading && _scope == scope) {
      return _pendingLoad ?? Future.value();
    }

    _scope = scope;
    _loading = true;
    _loaded = false;
    notifyListeners();

    final load = _load(scope);
    _pendingLoad = load;
    return load;
  }

  Future<void> _load(String scope) async {
    try {
      final cached = await LocalCache.instance.todos(scope);
      _items
        ..clear()
        ..addAll(
          (cached ?? const <Map<String, dynamic>>[])
              .map(TodoItem.fromJson)
              .whereType<TodoItem>(),
        );
      _sort();
    } finally {
      _loaded = true;
      _loading = false;
      _pendingLoad = null;
      notifyListeners();
    }
    await _rescheduleAll();
  }

  Future<TodoItem> add({
    required String title,
    String note = '',
    required DateTime dueAt,
    bool alarm = true,
  }) async {
    final now = DateTime.now();
    final item = TodoItem(
      id:
          '${now.microsecondsSinceEpoch.toRadixString(36)}'
          '${_items.length.toRadixString(36)}',
      title: title.trim(),
      note: note.trim(),
      dueAt: dueAt,
      createdAt: now,
      alarm: alarm,
    );
    _items.add(item);
    _sort();
    notifyListeners();
    await _persist();
    await _syncAlarm(item);
    return item;
  }

  Future<void> update(TodoItem item) async {
    final index = _items.indexWhere((entry) => entry.id == item.id);
    if (index == -1) return;
    _items[index] = item;
    _sort();
    notifyListeners();
    await _persist();
    await _syncAlarm(item);
  }

  Future<void> toggle(TodoItem item) async {
    final completed = !item.completed;
    final updated = item.copyWith(
      completed: completed,
      completedAt: completed ? DateTime.now() : null,
      clearCompletedAt: !completed,
    );
    await update(updated);
  }

  Future<void> delete(TodoItem item) async {
    _items.removeWhere((entry) => entry.id == item.id);
    notifyListeners();
    await NotificationService.instance.cancelTodo(item.id);
    await _persist();
  }

  Future<void> restore(TodoItem item) async {
    if (_items.any((entry) => entry.id == item.id)) return;
    _items.add(item);
    _sort();
    notifyListeners();
    await _persist();
    await _syncAlarm(item);
  }

  Future<void> clearCompleted() async {
    final done = _items.where((item) => item.completed).toList();
    if (done.isEmpty) return;
    _items.removeWhere((item) => item.completed);
    notifyListeners();
    for (final item in done) {
      await NotificationService.instance.cancelTodo(item.id);
    }
    await _persist();
  }

  Future<void> _syncAlarm(TodoItem item) async {
    final service = NotificationService.instance;
    if (item.completed || !item.alarm || !item.dueAt.isAfter(DateTime.now())) {
      await service.cancelTodo(item.id);
      return;
    }
    await service.scheduleTodo(
      todoId: item.id,
      title: item.title,
      note: item.note,
      at: item.dueAt,
      badgeCount: alertCount,
    );
  }

  Future<void> _rescheduleAll() async {
    for (final item in _items) {
      await _syncAlarm(item);
    }
  }

  Future<void> _persist() {
    final scope = _scope;
    if (scope == null) return Future.value();
    return LocalCache.instance.saveTodos(scope, [
      for (final item in _items) item.toJson(),
    ]);
  }

  void _sort() {
    _items.sort((a, b) {
      if (a.completed != b.completed) return a.completed ? 1 : -1;
      return a.dueAt.compareTo(b.dueAt);
    });
  }

  static bool _sameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  @visibleForTesting
  Future<void> resetForTesting() async {
    _items.clear();
    _scope = null;
    _loaded = false;
    _loading = false;
    _pendingLoad = null;
    notifyListeners();
  }
}
