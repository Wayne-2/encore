import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../theme/app_type.dart';
import '../theme/spotify_colors.dart';

/// The values collected by the add-expenditure sheet.
class ExpenditureDraft {
  const ExpenditureDraft({required this.title, required this.amount});

  final String title;
  final String amount;
}

/// Opens the themed sheet for adding a new expenditure item.
Future<ExpenditureDraft?> showAddExpenditureSheet(BuildContext context) {
  return showModalBottomSheet<ExpenditureDraft>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: SpotifyColors.surface,
    barrierColor: Colors.black.withValues(alpha: 0.6),
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(14)),
    ),
    builder: (_) => const AddExpenditureSheet(),
  );
}

/// Composer with an expenditure name and amount.
class AddExpenditureSheet extends StatefulWidget {
  const AddExpenditureSheet({super.key});

  @override
  State<AddExpenditureSheet> createState() => _AddExpenditureSheetState();
}

class _AddExpenditureSheetState extends State<AddExpenditureSheet> {
  final _title = TextEditingController();
  final _amount = TextEditingController();

  @override
  void dispose() {
    _title.dispose();
    _amount.dispose();
    super.dispose();
  }

  double? get _amountValue {
    final cleaned = _amount.text.replaceAll(RegExp(r'[^0-9.]'), '');
    final value = double.tryParse(cleaned);
    return value == null || value <= 0 ? null : value;
  }

  void _submit() {
    final title = _title.text.trim();
    final amount = _amountValue;
    if (title.isEmpty || amount == null) return;

    Navigator.of(
      context,
    ).pop(ExpenditureDraft(title: title, amount: _formatNaira(amount)));
  }

  static String _formatNaira(double value) {
    final parts = value.toStringAsFixed(2).split('.');
    final whole = parts.first.replaceAllMapped(
      RegExp(r'(\d)(?=(\d{3})+(?!\d))'),
      (match) => '${match[1]},',
    );
    return '₦$whole.${parts.last}';
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
              Text('Add Expenditure', style: AppType.name(scheme)),
              const SizedBox(height: 18),
              TextField(
                key: const ValueKey('expenditure-title'),
                controller: _title,
                textCapitalization: TextCapitalization.sentences,
                textInputAction: TextInputAction.next,
                style: AppType.body(scheme).copyWith(color: scheme.onSurface),
                decoration: const InputDecoration(
                  labelText: 'Expenditure',
                  hintText: 'e.g. Course materials',
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                key: const ValueKey('expenditure-amount'),
                controller: _amount,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                inputFormatters: [
                  FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]')),
                ],
                textInputAction: TextInputAction.done,
                onSubmitted: (_) => _submit(),
                style: AppType.body(scheme).copyWith(color: scheme.onSurface),
                decoration: const InputDecoration(
                  labelText: 'Amount',
                  hintText: '0.00',
                  prefixText: '₦ ',
                ),
              ),
              const SizedBox(height: 18),
              Text(
                'This item will be added to your semester expenditure list.',
                style: AppType.meta(scheme),
              ),
              const SizedBox(height: 18),
              ValueListenableBuilder<TextEditingValue>(
                valueListenable: _title,
                builder: (context, titleValue, _) {
                  return ValueListenableBuilder<TextEditingValue>(
                    valueListenable: _amount,
                    builder: (context, amountValue, _) {
                      final ready =
                          titleValue.text.trim().isNotEmpty &&
                          _amountValue != null;
                      return SizedBox(
                        width: double.infinity,
                        height: 48,
                        child: FilledButton(
                          key: const ValueKey('add-expenditure-button'),
                          onPressed: ready ? _submit : null,
                          child: const Text('Add expenditure'),
                        ),
                      );
                    },
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
