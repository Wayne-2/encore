import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../models/activity.dart';
import '../theme/app_type.dart';
import '../theme/spotify_colors.dart';

/// The values collected by the add-activity sheet.
class ActivityDraft {
  const ActivityDraft({required this.title, required this.date});

  final String title;
  final DateTime date;
}

/// Opens the themed sheet for adding an upcoming activity.
Future<ActivityDraft?> showAddActivitySheet(BuildContext context) {
  return showModalBottomSheet<ActivityDraft>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: SpotifyColors.surface,
    barrierColor: Colors.black.withValues(alpha: 0.6),
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(14)),
    ),
    builder: (_) => const AddActivitySheet(),
  );
}

/// Composer with an activity name and a calendar date.
class AddActivitySheet extends StatefulWidget {
  const AddActivitySheet({super.key});

  @override
  State<AddActivitySheet> createState() => _AddActivitySheetState();
}

class _AddActivitySheetState extends State<AddActivitySheet> {
  final _title = TextEditingController();
  late final _dateController = TextEditingController(
    text: Activity.formatDate(_date),
  );

  late DateTime _date = _today();

  static DateTime _today() {
    final now = DateTime.now();
    return DateTime(now.year, now.month, now.day);
  }

  @override
  void dispose() {
    _title.dispose();
    _dateController.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime(now.year - 5),
      lastDate: DateTime(now.year + 5, 12, 31),
    );
    if (picked == null || !mounted) return;

    setState(() {
      _date = DateTime(picked.year, picked.month, picked.day);
      _dateController.text = Activity.formatDate(_date);
    });
  }

  void _submit() {
    final title = _title.text.trim();
    if (title.isEmpty) return;
    Navigator.of(context).pop(ActivityDraft(title: title, date: _date));
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: SafeArea(
        top: false,
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 10, 20, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 36,
                  height: 4,
                  decoration: BoxDecoration(
                    color: SpotifyColors.borderStrong,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              Text('New Activity', style: AppType.name(scheme)),
              const SizedBox(height: 18),
              TextField(
                key: const ValueKey('activity-title'),
                controller: _title,
                textCapitalization: TextCapitalization.sentences,
                textInputAction: TextInputAction.next,
                style: AppType.body(scheme).copyWith(color: scheme.onSurface),
                decoration: const InputDecoration(
                  labelText: 'Activity',
                  hintText: 'e.g. Matriculation',
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                key: const ValueKey('activity-date'),
                controller: _dateController,
                readOnly: true,
                onTap: _pickDate,
                style: AppType.body(scheme).copyWith(color: scheme.onSurface),
                decoration: InputDecoration(
                  labelText: 'Date',
                  suffixIcon: Icon(
                    LucideIcons.calendar,
                    size: 18,
                    color: scheme.onSurfaceVariant,
                  ),
                ),
              ),
              const SizedBox(height: 20),
              ValueListenableBuilder<TextEditingValue>(
                valueListenable: _title,
                builder: (context, value, _) {
                  final ready = value.text.trim().isNotEmpty;
                  return SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: FilledButton(
                      key: const ValueKey('add-activity-button'),
                      onPressed: ready ? _submit : null,
                      child: const Text('Add activity'),
                    ),
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}
