import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../models/todo_item.dart';
import '../services/todo_store.dart';
import '../theme/app_type.dart';
import '../theme/spotify_colors.dart';
import '../widgets/section_heading.dart';
import '../widgets/todo_composer_sheet.dart';
import '../widgets/workspace_app_bar.dart';

enum _TodoFilter { all, today, upcoming, done }

/// Personal task planner reached from the profile page.
///
/// Todos are stored locally per account and each one can schedule a local
/// notification alarm. Alert badges surface overdue and today's tasks.
class PersonalTodoScreen extends StatefulWidget {
  const PersonalTodoScreen({super.key});

  @override
  State<PersonalTodoScreen> createState() => _PersonalTodoScreenState();
}

class _PersonalTodoScreenState extends State<PersonalTodoScreen> {
  final TodoStore _store = TodoStore.instance;
  _TodoFilter _filter = _TodoFilter.all;

  @override
  void initState() {
    super.initState();
    _store.initialize();
  }

  Future<void> _addTodo() async {
    final draft = await showTodoComposerSheet(context);
    if (draft == null || !mounted) return;

    await _store.add(
      title: draft.title,
      note: draft.note,
      dueAt: draft.dueAt,
      alarm: draft.alarm,
    );
    if (!mounted) return;
    _showSnack(
      draft.alarm && draft.dueAt.isAfter(DateTime.now())
          ? 'Todo added · alarm set'
          : 'Todo added',
    );
  }

  Future<void> _editTodo(TodoItem item) async {
    final draft = await showTodoComposerSheet(context, initial: item);
    if (draft == null || !mounted) return;

    await _store.update(
      item.copyWith(
        title: draft.title,
        note: draft.note,
        dueAt: draft.dueAt,
        alarm: draft.alarm,
      ),
    );
    if (!mounted) return;
    _showSnack('Todo updated');
  }

  Future<void> _deleteTodo(TodoItem item) async {
    await _store.delete(item);
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: const Text('Todo deleted'),
          action: SnackBarAction(
            label: 'Undo',
            onPressed: () => _store.restore(item),
          ),
        ),
      );
  }

  void _showSnack(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  List<TodoItem> _visibleItems(TodoStore store) {
    return switch (_filter) {
      _TodoFilter.all => store.pending,
      _TodoFilter.today => [...store.overdue, ...store.dueToday],
      _TodoFilter.upcoming => store.upcoming,
      _TodoFilter.done => store.completed,
    };
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Scaffold(
      backgroundColor: SpotifyColors.background,
      floatingActionButtonLocation: FloatingActionButtonLocation.startFloat,
      floatingActionButton: FloatingActionButton.extended(
        key: const ValueKey('todo-add'),
        onPressed: _addTodo,
        backgroundColor: SpotifyColors.accent,
        foregroundColor: Colors.white,
        elevation: 2,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        icon: const Icon(LucideIcons.plus, size: 20),
        label: Text(
          'New todo',
          style: AppType.title(
            scheme,
          ).copyWith(color: Colors.white, fontWeight: FontWeight.w600),
        ),
      ),
      body: Column(
        children: [
          WorkspaceAppBar(
            heading: 'Personal todo',
            title: 'Plan your day, one task at a time',
            leading: IconButton(
              key: const ValueKey('todo-back'),
              onPressed: () => Navigator.of(context).maybePop(),
              icon: const Icon(LucideIcons.chevronLeft, size: 20),
              color: scheme.onSurface,
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints.tightFor(width: 28),
            ),
            trailing: ListenableBuilder(
              listenable: _store,
              builder: (context, _) =>
                  _TodoAlertBadge(count: _store.alertCount),
            ),
          ),
          Expanded(
            child: ListenableBuilder(
              listenable: _store,
              builder: (context, _) {
                final items = _visibleItems(_store);
                return ListView(
                  key: const ValueKey('todo-list'),
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 120),
                  children: [
                    _TodoSummaryCard(store: _store),
                    const SizedBox(height: 16),
                    _TodoFilterBar(
                      store: _store,
                      selected: _filter,
                      onSelected: (filter) => setState(() => _filter = filter),
                    ),
                    const SizedBox(height: 18),
                    if (_store.isLoading)
                      const Padding(
                        padding: EdgeInsets.only(top: 40),
                        child: Center(
                          child: SizedBox(
                            width: 22,
                            height: 22,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          ),
                        ),
                      )
                    else if (items.isEmpty)
                      _TodoEmptyState(filter: _filter)
                    else
                      _TodoGroup(
                        title: switch (_filter) {
                          _TodoFilter.all => 'All tasks',
                          _TodoFilter.today => 'Today',
                          _TodoFilter.upcoming => 'Upcoming',
                          _TodoFilter.done => 'Completed',
                        },
                        items: items,
                        onToggle: _store.toggle,
                        onEdit: _editTodo,
                        onDelete: _deleteTodo,
                        showOverdueMark: _filter == _TodoFilter.all,
                      ),
                    if (_filter == _TodoFilter.all &&
                        _store.completed.isNotEmpty) ...[
                      const SizedBox(height: 18),
                      _TodoGroup(
                        title: 'Completed',
                        items: _store.completed.take(4).toList(),
                        onToggle: _store.toggle,
                        onEdit: _editTodo,
                        onDelete: _deleteTodo,
                        muted: true,
                      ),
                    ],
                    if (!_store.isLoading && _store.items.isNotEmpty) ...[
                      const SizedBox(height: 18),
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              'Swipe a todo left to delete it.',
                              style: AppType.meta(scheme),
                            ),
                          ),
                          if (_store.completed.isNotEmpty)
                            TextButton(
                              key: const ValueKey('todo-clear-completed'),
                              onPressed: _store.clearCompleted,
                              child: Text(
                                'Clear completed',
                                style: AppType.meta(scheme).copyWith(
                                  color: scheme.primary,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                        ],
                      ),
                    ],
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

/// Bell badge in the page header; turns red when tasks need attention.
class _TodoAlertBadge extends StatelessWidget {
  const _TodoAlertBadge({required this.count});

  final int count;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final urgent = count > 0;
    final color = urgent ? SpotifyColors.danger : scheme.onSurfaceVariant;

    return Container(
      key: const ValueKey('todo-alert-badge'),
      height: 34,
      padding: const EdgeInsets.symmetric(horizontal: 10),
      decoration: BoxDecoration(
        color: urgent
            ? SpotifyColors.danger.withValues(alpha: 0.12)
            : SpotifyColors.surface,
        borderRadius: BorderRadius.circular(17),
        border: Border.all(
          color: urgent
              ? SpotifyColors.danger.withValues(alpha: 0.5)
              : SpotifyColors.border,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            urgent ? LucideIcons.bellRing : LucideIcons.bell,
            size: 15,
            color: color,
          ),
          const SizedBox(width: 6),
          Text(
            urgent ? '$count' : '0',
            style: AppType.functional(
              scheme,
            ).copyWith(color: color, fontWeight: FontWeight.w700),
          ),
        ],
      ),
    );
  }
}

/// Top overview card with today's progress and next alarm.
class _TodoSummaryCard extends StatelessWidget {
  const _TodoSummaryCard({required this.store});

  final TodoStore store;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final total = store.todayTotal;
    final done = store.todayCompleted;
    final left = total - done;
    final progress = total == 0 ? 0.0 : done / total;
    final next = store.nextReminder;
    final overdue = store.overdue.length;

    return Container(
      decoration: BoxDecoration(
        color: SpotifyColors.surface,
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: SpotifyColors.border),
      ),
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                "TODAY'S FOCUS",
                style: AppType.tag(scheme.onSurfaceVariant),
              ),
              const Spacer(),
              if (overdue > 0)
                Container(
                  key: const ValueKey('todo-overdue-badge'),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    color: SpotifyColors.danger.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: SpotifyColors.danger.withValues(alpha: 0.45),
                    ),
                  ),
                  child: Text(
                    '$overdue overdue',
                    style: AppType.functional(scheme).copyWith(
                      color: SpotifyColors.danger,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text('$left', style: AppType.heading(scheme).copyWith(height: 1)),
              const SizedBox(width: 6),
              Padding(
                padding: const EdgeInsets.only(bottom: 1),
                child: Text(
                  left == 1 ? 'task left today' : 'tasks left today',
                  style: AppType.subtitle(scheme),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ClipRRect(
            borderRadius: BorderRadius.circular(2),
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 4,
              backgroundColor: SpotifyColors.border,
              valueColor: const AlwaysStoppedAnimation(SpotifyColors.accent),
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Icon(LucideIcons.checkCheck, size: 14, color: scheme.primary),
              const SizedBox(width: 5),
              Text('$done done', style: AppType.meta(scheme)),
              const SizedBox(width: 12),
              Icon(
                LucideIcons.bellRing,
                size: 13,
                color: next == null ? scheme.onSurfaceVariant : scheme.primary,
              ),
              const SizedBox(width: 5),
              Expanded(
                child: Text(
                  next == null
                      ? 'No alarms scheduled'
                      : 'Next alarm ${_relativeLabel(next.dueAt)}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppType.meta(scheme),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Horizontally scrollable filter chips with live counts.
class _TodoFilterBar extends StatelessWidget {
  const _TodoFilterBar({
    required this.store,
    required this.selected,
    required this.onSelected,
  });

  final TodoStore store;
  final _TodoFilter selected;
  final ValueChanged<_TodoFilter> onSelected;

  @override
  Widget build(BuildContext context) {
    final entries = [
      (_TodoFilter.all, 'All', store.pending.length),
      (
        _TodoFilter.today,
        'Today',
        store.overdue.length + store.dueToday.length,
      ),
      (_TodoFilter.upcoming, 'Upcoming', store.upcoming.length),
      (_TodoFilter.done, 'Done', store.completed.length),
    ];

    return SizedBox(
      height: 34,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: entries.length,
        separatorBuilder: (_, _) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          final (filter, label, count) = entries[index];
          final isSelected = selected == filter;
          return _FilterChip(
            key: ValueKey('todo-filter-${filter.name}'),
            label: label,
            count: count,
            selected: isSelected,
            onTap: () => onSelected(filter),
          );
        },
      ),
    );
  }
}

class _FilterChip extends StatelessWidget {
  const _FilterChip({
    super.key,
    required this.label,
    required this.count,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final int count;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final color = selected ? SpotifyColors.accent : scheme.onSurfaceVariant;

    return Material(
      color: selected
          ? SpotifyColors.accent.withValues(alpha: 0.14)
          : SpotifyColors.surface,
      borderRadius: BorderRadius.circular(17),
      child: InkWell(
        borderRadius: BorderRadius.circular(17),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(17),
            border: Border.all(
              color: selected
                  ? SpotifyColors.accent.withValues(alpha: 0.55)
                  : SpotifyColors.border,
            ),
          ),
          child: Row(
            children: [
              Text(
                label,
                style: AppType.functional(scheme).copyWith(
                  color: color,
                  fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                ),
              ),
              if (count > 0) ...[
                const SizedBox(width: 6),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 5,
                    vertical: 1,
                  ),
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.16),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    '$count',
                    style: AppType.functional(
                      scheme,
                    ).copyWith(color: color, fontWeight: FontWeight.w700),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _TodoGroup extends StatelessWidget {
  const _TodoGroup({
    required this.title,
    required this.items,
    required this.onToggle,
    required this.onEdit,
    required this.onDelete,
    this.muted = false,
    this.showOverdueMark = false,
  });

  final String title;
  final List<TodoItem> items;
  final ValueChanged<TodoItem> onToggle;
  final ValueChanged<TodoItem> onEdit;
  final ValueChanged<TodoItem> onDelete;
  final bool muted;
  final bool showOverdueMark;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            SectionHeading(
              title,
              style: muted
                  ? AppType.sectionTitle(
                      scheme,
                    ).copyWith(color: scheme.onSurfaceVariant)
                  : null,
            ),
            const Spacer(),
            Text('${items.length}', style: AppType.meta(scheme)),
          ],
        ),
        const SizedBox(height: 10),
        for (var i = 0; i < items.length; i++) ...[
          if (i > 0) const SizedBox(height: 8),
          _DismissibleTodo(
            item: items[i],
            onToggle: () => onToggle(items[i]),
            onEdit: () => onEdit(items[i]),
            onDelete: () => onDelete(items[i]),
            overdue: showOverdueMark && items[i].isOverdue,
          ),
        ],
      ],
    );
  }
}

class _DismissibleTodo extends StatelessWidget {
  const _DismissibleTodo({
    required this.item,
    required this.onToggle,
    required this.onEdit,
    required this.onDelete,
    required this.overdue,
  });

  final TodoItem item;
  final VoidCallback onToggle;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final bool overdue;

  @override
  Widget build(BuildContext context) {
    return Dismissible(
      key: ValueKey('todo-dismissible-${item.id}'),
      direction: DismissDirection.endToStart,
      dismissThresholds: const {DismissDirection.endToStart: 0.35},
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.symmetric(horizontal: 18),
        decoration: BoxDecoration(
          color: SpotifyColors.danger.withValues(alpha: 0.9),
          borderRadius: BorderRadius.circular(4),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(LucideIcons.trash2, size: 18, color: Colors.white),
            const SizedBox(width: 6),
            Text(
              'Delete',
              style: AppType.functional(
                Theme.of(context).colorScheme,
              ).copyWith(color: Colors.white, fontWeight: FontWeight.w700),
            ),
          ],
        ),
      ),
      onDismissed: (_) => onDelete(),
      child: _TodoTile(
        item: item,
        overdue: overdue,
        onToggle: onToggle,
        onEdit: onEdit,
        onDelete: onDelete,
      ),
    );
  }
}

class _TodoTile extends StatelessWidget {
  const _TodoTile({
    required this.item,
    required this.overdue,
    required this.onToggle,
    required this.onEdit,
    required this.onDelete,
  });

  final TodoItem item;
  final bool overdue;
  final VoidCallback onToggle;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final dueColor = overdue ? SpotifyColors.danger : scheme.onSurfaceVariant;

    return Material(
      key: ValueKey('todo-${item.id}'),
      color: SpotifyColors.surface,
      borderRadius: BorderRadius.circular(4),
      child: InkWell(
        borderRadius: BorderRadius.circular(4),
        onTap: onEdit,
        child: Container(
          padding: const EdgeInsets.fromLTRB(12, 10, 4, 10),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(4),
            border: Border.all(
              color: overdue
                  ? SpotifyColors.danger.withValues(alpha: 0.35)
                  : SpotifyColors.border,
            ),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.only(top: 1),
                child: Semantics(
                  checked: item.completed,
                  button: true,
                  label: item.completed
                      ? 'Mark ${item.title} as not done'
                      : 'Mark ${item.title} as done',
                  child: InkResponse(
                    key: ValueKey('todo-check-${item.id}'),
                    onTap: onToggle,
                    radius: 18,
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 160),
                      width: 22,
                      height: 22,
                      decoration: BoxDecoration(
                        color: item.completed
                            ? SpotifyColors.accent
                            : Colors.transparent,
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(
                          color: item.completed
                              ? SpotifyColors.accent
                              : scheme.onSurfaceVariant.withValues(alpha: 0.6),
                          width: 1.5,
                        ),
                      ),
                      child: item.completed
                          ? const Icon(
                              LucideIcons.check,
                              size: 14,
                              color: Colors.white,
                            )
                          : null,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: AppType.title(scheme).copyWith(
                        color: item.completed
                            ? scheme.onSurfaceVariant
                            : scheme.onSurface,
                        decoration: item.completed
                            ? TextDecoration.lineThrough
                            : TextDecoration.none,
                        decorationColor: scheme.onSurfaceVariant,
                      ),
                    ),
                    if (item.note.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(
                        item.note,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: AppType.meta(scheme).copyWith(
                          color: scheme.onSurfaceVariant,
                          height: 1.35,
                        ),
                      ),
                    ],
                    const SizedBox(height: 7),
                    Row(
                      children: [
                        if (overdue) ...[
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: SpotifyColors.danger.withValues(
                                alpha: 0.14,
                              ),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              'OVERDUE',
                              style: AppType.functional(scheme).copyWith(
                                color: SpotifyColors.danger,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                        ],
                        Icon(LucideIcons.clock3, size: 12, color: dueColor),
                        const SizedBox(width: 4),
                        Flexible(
                          child: Text(
                            todoDateLabel(item.dueAt),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: AppType.functional(
                              scheme,
                            ).copyWith(color: dueColor),
                          ),
                        ),
                        if (item.alarm) ...[
                          const SizedBox(width: 8),
                          Icon(
                            LucideIcons.bellRing,
                            size: 12,
                            color: item.completed
                                ? scheme.onSurfaceVariant
                                : scheme.primary,
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
              PopupMenuButton<String>(
                key: ValueKey('todo-menu-${item.id}'),
                icon: Icon(
                  LucideIcons.ellipsisVertical,
                  size: 17,
                  color: scheme.onSurfaceVariant,
                ),
                padding: EdgeInsets.zero,
                tooltip: 'Todo options',
                color: SpotifyColors.surfaceHover,
                onSelected: (value) {
                  if (value == 'edit') onEdit();
                  if (value == 'delete') onDelete();
                },
                itemBuilder: (context) => [
                  PopupMenuItem(value: 'edit', child: Text('Edit')),
                  PopupMenuItem(value: 'delete', child: Text('Delete')),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _TodoEmptyState extends StatelessWidget {
  const _TodoEmptyState({required this.filter});

  final _TodoFilter filter;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final copy = switch (filter) {
      _TodoFilter.all => (
        'No todos yet',
        'Tap New todo to plan the first thing on your list.',
        LucideIcons.listChecks,
      ),
      _TodoFilter.today => (
        'Today is clear',
        'Nothing is due today. Enjoy the breathing room.',
        LucideIcons.sun,
      ),
      _TodoFilter.upcoming => (
        'Nothing upcoming',
        'Future todos and their alarms will appear here.',
        LucideIcons.calendarDays,
      ),
      _TodoFilter.done => (
        'No completed todos',
        'Finished tasks collect here so you can look back.',
        LucideIcons.circleCheck,
      ),
    };

    return Padding(
      padding: const EdgeInsets.only(top: 42),
      child: Column(
        children: [
          Container(
            width: 54,
            height: 54,
            decoration: BoxDecoration(
              color: SpotifyColors.surface,
              shape: BoxShape.circle,
              border: Border.all(color: SpotifyColors.border),
            ),
            child: Icon(copy.$3, size: 24, color: scheme.onSurfaceVariant),
          ),
          const SizedBox(height: 14),
          Text(
            copy.$1,
            style: AppType.title(scheme).copyWith(color: scheme.onSurface),
          ),
          const SizedBox(height: 4),
          Text(
            copy.$2,
            textAlign: TextAlign.center,
            style: AppType.meta(scheme),
          ),
        ],
      ),
    );
  }
}

String _relativeLabel(DateTime value) {
  final diff = value.difference(DateTime.now());
  if (diff.inMinutes < 1) return 'now';
  if (diff.inMinutes < 60) return 'in ${diff.inMinutes}m';
  if (diff.inHours < 24) return 'in ${diff.inHours}h';
  if (diff.inDays == 1) return 'tomorrow';
  return 'in ${diff.inDays} days';
}
