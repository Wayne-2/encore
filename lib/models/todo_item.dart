import 'package:flutter/foundation.dart';

/// A single personal todo, stored locally for the signed-in account.
@immutable
class TodoItem {
  const TodoItem({
    required this.id,
    required this.title,
    required this.dueAt,
    required this.createdAt,
    this.note = '',
    this.alarm = true,
    this.completed = false,
    this.completedAt,
  });

  final String id;
  final String title;
  final String note;
  final DateTime dueAt;
  final DateTime createdAt;
  final bool alarm;
  final bool completed;
  final DateTime? completedAt;

  bool get isOverdue => !completed && dueAt.isBefore(DateTime.now());

  bool isDueToday([DateTime? now]) {
    final current = now ?? DateTime.now();
    final due = dueAt.toLocal();
    return !completed &&
        due.year == current.year &&
        due.month == current.month &&
        due.day == current.day;
  }

  bool isUpcoming([DateTime? now]) {
    final current = now ?? DateTime.now();
    return !completed && dueAt.isAfter(current) && !isDueToday(current);
  }

  TodoItem copyWith({
    String? title,
    String? note,
    DateTime? dueAt,
    bool? alarm,
    bool? completed,
    DateTime? completedAt,
    bool clearCompletedAt = false,
  }) {
    return TodoItem(
      id: id,
      title: title ?? this.title,
      note: note ?? this.note,
      dueAt: dueAt ?? this.dueAt,
      createdAt: createdAt,
      alarm: alarm ?? this.alarm,
      completed: completed ?? this.completed,
      completedAt: clearCompletedAt ? null : (completedAt ?? this.completedAt),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'note': note,
      'dueAt': dueAt.millisecondsSinceEpoch,
      'createdAt': createdAt.millisecondsSinceEpoch,
      'alarm': alarm,
      'completed': completed,
      if (completedAt != null)
        'completedAt': completedAt!.millisecondsSinceEpoch,
    };
  }

  static TodoItem? fromJson(Map<String, dynamic> json) {
    final id = json['id'];
    final title = json['title'];
    final due = json['dueAt'];
    if (id is! String || title is! String || due is! num) return null;

    final created = json['createdAt'];
    final completedAt = json['completedAt'];
    return TodoItem(
      id: id,
      title: title,
      note: json['note'] is String ? json['note'] as String : '',
      dueAt: DateTime.fromMillisecondsSinceEpoch(due.toInt()),
      createdAt: created is num
          ? DateTime.fromMillisecondsSinceEpoch(created.toInt())
          : DateTime.fromMillisecondsSinceEpoch(due.toInt()),
      alarm: json['alarm'] != false,
      completed: json['completed'] == true,
      completedAt: completedAt is num
          ? DateTime.fromMillisecondsSinceEpoch(completedAt.toInt())
          : null,
    );
  }
}
