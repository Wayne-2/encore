import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../models/todo_item.dart';
import '../theme/app_type.dart';
import '../theme/spotify_colors.dart';

/// Result of the todo composer sheet.
class TodoDraft {
  const TodoDraft({
    required this.title,
    required this.note,
    required this.dueAt,
    required this.alarm,
  });

  final String title;
  final String note;
  final DateTime dueAt;
  final bool alarm;
}

/// Opens the "New todo" / "Edit todo" sheet.
Future<TodoDraft?> showTodoComposerSheet(
  BuildContext context, {
  TodoItem? initial,
}) {
  return showModalBottomSheet<TodoDraft>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: SpotifyColors.surface,
    barrierColor: Colors.black.withValues(alpha: 0.6),
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(14)),
    ),
    builder: (context) => TodoComposerSheet(initial: initial),
  );
}

/// Bottom sheet for creating or editing a personal todo.
class TodoComposerSheet extends StatefulWidget {
  const TodoComposerSheet({super.key, this.initial});

  final TodoItem? initial;

  @override
  State<TodoComposerSheet> createState() => _TodoComposerSheetState();
}

class _TodoComposerSheetState extends State<TodoComposerSheet> {
  late final TextEditingController _title = TextEditingController(
    text: widget.initial?.title ?? '',
  );
  late final TextEditingController _note = TextEditingController(
    text: widget.initial?.note ?? '',
  );
  late DateTime _dueAt = widget.initial?.dueAt ?? _nextHour(DateTime.now());
  late bool _alarm = widget.initial?.alarm ?? true;
  bool _showTitleError = false;

  static DateTime _nextHour(DateTime now) {
    final next = now.add(const Duration(hours: 1));
    return DateTime(next.year, next.month, next.day, next.hour);
  }

  @override
  void dispose() {
    _title.dispose();
    _note.dispose();
    super.dispose();
  }

  bool get _isEditing => widget.initial != null;

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _dueAt.isBefore(now) ? now : _dueAt,
      firstDate: DateTime(now.year, now.month, now.day),
      lastDate: DateTime(now.year + 3),
    );
    if (picked == null || !mounted) return;
    setState(() {
      _dueAt = DateTime(
        picked.year,
        picked.month,
        picked.day,
        _dueAt.hour,
        _dueAt.minute,
      );
    });
  }

  Future<void> _pickTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(_dueAt),
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context).copyWith(alwaysUse24HourFormat: false),
        child: child!,
      ),
    );
    if (picked == null || !mounted) return;
    setState(() {
      _dueAt = DateTime(
        _dueAt.year,
        _dueAt.month,
        _dueAt.day,
        picked.hour,
        picked.minute,
      );
    });
  }

  void _submit() {
    final title = _title.text.trim();
    if (title.isEmpty) {
      setState(() => _showTitleError = true);
      return;
    }
    Navigator.of(context).pop(
      TodoDraft(
        title: title,
        note: _note.text.trim(),
        dueAt: _dueAt,
        alarm: _alarm,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;
    final alarmInPast = !_dueAt.isAfter(DateTime.now());

    return Padding(
      padding: EdgeInsets.only(bottom: bottomInset),
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: scheme.onSurfaceVariant.withValues(alpha: 0.4),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            Row(
              children: [
                Expanded(
                  child: Text(
                    _isEditing ? 'Edit todo' : 'New todo',
                    style: AppType.heading(scheme),
                  ),
                ),
                IconButton(
                  key: const ValueKey('todo-close'),
                  onPressed: () => Navigator.of(context).maybePop(),
                  icon: const Icon(LucideIcons.x, size: 20),
                  color: scheme.onSurfaceVariant,
                ),
              ],
            ),
            const SizedBox(height: 8),
            TextField(
              key: const ValueKey('todo-title-field'),
              controller: _title,
              autofocus: !_isEditing,
              textCapitalization: TextCapitalization.sentences,
              textInputAction: TextInputAction.next,
              maxLength: 80,
              style: AppType.subtitle(
                scheme,
              ).copyWith(color: scheme.onSurface, fontWeight: FontWeight.w500),
              decoration: _fieldDecoration(
                scheme,
                hint: 'What do you need to do?',
                icon: LucideIcons.checkSquare,
                error: _showTitleError ? 'Add a title first' : null,
                counter: false,
              ),
              onChanged: (_) {
                if (_showTitleError) setState(() => _showTitleError = false);
              },
            ),
            const SizedBox(height: 12),
            TextField(
              key: const ValueKey('todo-note-field'),
              controller: _note,
              textCapitalization: TextCapitalization.sentences,
              maxLines: 3,
              maxLength: 240,
              style: AppType.subtitle(scheme),
              decoration: _fieldDecoration(
                scheme,
                hint: 'Add a note (optional)',
                icon: LucideIcons.alignLeft,
                counter: false,
              ),
            ),
            const SizedBox(height: 16),
            Text('WHEN', style: AppType.tag(scheme.onSurfaceVariant)),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: _PickerButton(
                    key: const ValueKey('todo-date-button'),
                    icon: LucideIcons.calendarDays,
                    label: _formatDate(_dueAt),
                    onTap: _pickDate,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _PickerButton(
                    key: const ValueKey('todo-time-button'),
                    icon: LucideIcons.clock3,
                    label: _formatTime(_dueAt),
                    onTap: _pickTime,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Container(
              decoration: BoxDecoration(
                color: SpotifyColors.background,
                borderRadius: BorderRadius.circular(4),
                border: Border.all(color: SpotifyColors.border),
              ),
              padding: const EdgeInsets.fromLTRB(12, 4, 4, 4),
              child: Row(
                children: [
                  Icon(
                    LucideIcons.bellRing,
                    size: 18,
                    color: _alarm ? scheme.primary : scheme.onSurfaceVariant,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          'Alarm notification',
                          style: AppType.title(scheme).copyWith(
                            color: scheme.onSurface,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        Text(
                          alarmInPast
                              ? 'Choose a future time to sound the alarm'
                              : 'Notify me when this todo is due',
                          style: AppType.meta(scheme).copyWith(
                            color: alarmInPast
                                ? SpotifyColors.danger
                                : scheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Switch(
                    key: const ValueKey('todo-alarm-switch'),
                    value: _alarm,
                    onChanged: (value) => setState(() => _alarm = value),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              height: 46,
              child: FilledButton(
                key: const ValueKey('todo-save'),
                onPressed: _submit,
                style: FilledButton.styleFrom(
                  backgroundColor: SpotifyColors.accent,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(6),
                  ),
                ),
                child: Text(
                  _isEditing ? 'Save changes' : 'Add todo',
                  style: AppType.title(
                    scheme,
                  ).copyWith(color: Colors.white, fontWeight: FontWeight.w700),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  InputDecoration _fieldDecoration(
    ColorScheme scheme, {
    required String hint,
    required IconData icon,
    String? error,
    required bool counter,
  }) {
    return InputDecoration(
      hintText: hint,
      hintStyle: AppType.subtitle(scheme),
      errorText: error,
      errorStyle: AppType.meta(scheme).copyWith(color: SpotifyColors.danger),
      prefixIcon: Icon(icon, size: 18, color: scheme.onSurfaceVariant),
      counterText: counter ? null : '',
      filled: true,
      fillColor: SpotifyColors.background,
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(4),
        borderSide: const BorderSide(color: SpotifyColors.border),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(4),
        borderSide: const BorderSide(color: SpotifyColors.accent),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(4),
        borderSide: const BorderSide(color: SpotifyColors.danger),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(4),
        borderSide: const BorderSide(color: SpotifyColors.danger),
      ),
    );
  }

  static String _formatDate(DateTime value) {
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
    return '${value.day} ${months[value.month - 1]} ${value.year}';
  }

  static String _formatTime(DateTime value) {
    final hour = value.hour % 12 == 0 ? 12 : value.hour % 12;
    final minute = value.minute.toString().padLeft(2, '0');
    final suffix = value.hour >= 12 ? 'PM' : 'AM';
    return '$hour:$minute $suffix';
  }
}

class _PickerButton extends StatelessWidget {
  const _PickerButton({
    super.key,
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Material(
      color: SpotifyColors.background,
      borderRadius: BorderRadius.circular(4),
      child: InkWell(
        borderRadius: BorderRadius.circular(4),
        onTap: onTap,
        child: Container(
          height: 46,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(4),
            border: Border.all(color: SpotifyColors.border),
          ),
          child: Row(
            children: [
              Icon(icon, size: 17, color: scheme.primary),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppType.subtitle(
                    scheme,
                  ).copyWith(color: scheme.onSurface),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Compact date label used by todo tiles.
String todoDateLabel(DateTime due, {DateTime? now}) {
  final current = now ?? DateTime.now();
  final local = due.toLocal();
  final today = DateTime(current.year, current.month, current.day);
  final day = DateTime(local.year, local.month, local.day);
  final difference = day.difference(today).inDays;
  final time = _formatShortTime(local);
  if (difference < 0) return 'Overdue · $time';
  if (difference == 0) return 'Today · $time';
  if (difference == 1) return 'Tomorrow · $time';
  if (difference < 7) {
    const weekdays = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    return '${weekdays[local.weekday - 1]} · $time';
  }
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
  return '${local.day} ${months[local.month - 1]} · $time';
}

String _formatShortTime(DateTime value) {
  final hour = value.hour % 12 == 0 ? 12 : value.hour % 12;
  final minute = value.minute.toString().padLeft(2, '0');
  final suffix = value.hour >= 12 ? 'PM' : 'AM';
  return '$hour:$minute $suffix';
}
