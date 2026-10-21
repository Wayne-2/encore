import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:flutter/services.dart';

import '../theme/app_type.dart';
import '../theme/spotify_colors.dart';

/// Opens the bank-transfer details sheet used by the Finance "Add Funds"
/// action.
Future<void> showAddFundsSheet(
  BuildContext context, {
  required String fullName,
  required String accountNumber,
  required String bankName,
  required String availablePoints,
  String? registrationNumber,
  String? department,
  String? level,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: SpotifyColors.surface,
    barrierColor: Colors.black.withValues(alpha: 0.6),
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(14)),
    ),
    builder: (_) => AddFundsSheet(
      fullName: fullName,
      accountNumber: accountNumber,
      bankName: bankName,
      availablePoints: availablePoints,
      registrationNumber: registrationNumber,
      department: department,
      level: level,
    ),
  );
}

/// Shows the signed-in user's funding account details plus a copy action.
class AddFundsSheet extends StatefulWidget {
  const AddFundsSheet({
    super.key,
    required this.fullName,
    required this.accountNumber,
    required this.bankName,
    required this.availablePoints,
    this.registrationNumber,
    this.department,
    this.level,
  });

  final String fullName;
  final String accountNumber;
  final String bankName;
  final String availablePoints;
  final String? registrationNumber;
  final String? department;
  final String? level;

  @override
  State<AddFundsSheet> createState() => _AddFundsSheetState();
}

class _AddFundsSheetState extends State<AddFundsSheet> {
  bool _copied = false;

  Future<void> _copyAccountNumber() async {
    await Clipboard.setData(ClipboardData(text: widget.accountNumber));
    if (!mounted) return;
    setState(() => _copied = true);
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final studentDetails = <({String label, String value})>[
      if (widget.registrationNumber?.trim().isNotEmpty == true)
        (label: 'Matric number', value: widget.registrationNumber!.trim()),
      if (widget.department?.trim().isNotEmpty == true)
        (label: 'Department', value: widget.department!.trim()),
      if (widget.level?.trim().isNotEmpty == true)
        (label: 'Level', value: widget.level!.trim()),
    ];

    return SafeArea(
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
            const SizedBox(height: 18),
            Row(
              children: [
                Expanded(child: Text('Add Funds', style: AppType.name(scheme))),
                IconButton(
                  key: const ValueKey('close-add-funds-sheet'),
                  tooltip: 'Close',
                  onPressed: () => Navigator.of(context).maybePop(),
                  icon: const Icon(LucideIcons.x, size: 20),
                  color: scheme.onSurfaceVariant,
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              'Transfer to your Encore account using the details below.',
              style: AppType.timestamp(scheme),
            ),
            const SizedBox(height: 18),
            _DetailsPanel(
              children: [
                _DetailRow(label: 'Account name', value: widget.fullName),
                _DetailRow(
                  label: 'Account number',
                  value: widget.accountNumber,
                  trailing: IconButton(
                    key: const ValueKey('copy-funds-account'),
                    tooltip: 'Copy account number',
                    onPressed: _copyAccountNumber,
                    icon: Icon(
                      _copied ? LucideIcons.check : LucideIcons.copy,
                      size: 17,
                      color: _copied
                          ? SpotifyColors.accent
                          : scheme.onSurfaceVariant,
                    ),
                    visualDensity: VisualDensity.compact,
                  ),
                ),
                _DetailRow(label: 'Bank', value: widget.bankName),
                const Divider(height: 20, color: SpotifyColors.border),
                _DetailRow(
                  label: 'Available points',
                  value: widget.availablePoints,
                  valueColor: scheme.primary,
                ),
              ],
            ),
            if (studentDetails.isNotEmpty) ...[
              const SizedBox(height: 20),
              Text('Student details', style: AppType.cardTitle(scheme)),
              const SizedBox(height: 8),
              _DetailsPanel(
                children: [
                  for (final detail in studentDetails)
                    _DetailRow(label: detail.label, value: detail.value),
                ],
              ),
            ],
            const SizedBox(height: 18),
            Text(
              'Use your full name as the transfer description so the payment '
              'can be matched to your account.',
              style: AppType.timestamp(scheme),
            ),
            const SizedBox(height: 14),
            SizedBox(
              width: double.infinity,
              height: 46,
              child: FilledButton.icon(
                key: const ValueKey('copy-funds-details'),
                onPressed: _copyAccountNumber,
                icon: Icon(
                  _copied ? LucideIcons.check : LucideIcons.copy,
                  size: 18,
                ),
                label: Text(
                  _copied ? 'Account number copied' : 'Copy account number',
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DetailsPanel extends StatelessWidget {
  const _DetailsPanel({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: SpotifyColors.background,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: SpotifyColors.border),
      ),
      child: Column(children: children),
    );
  }
}

class _DetailRow extends StatelessWidget {
  const _DetailRow({
    required this.label,
    required this.value,
    this.trailing,
    this.valueColor,
  });

  final String label;
  final String value;
  final Widget? trailing;
  final Color? valueColor;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        children: [
          Expanded(child: Text(label, style: AppType.timestamp(scheme))),
          const SizedBox(width: 12),
          Flexible(
            child: Text(
              value,
              textAlign: TextAlign.end,
              style: AppType.cardTitle(scheme).copyWith(
                fontWeight: FontWeight.w600,
                color: valueColor ?? scheme.onSurface,
              ),
            ),
          ),
          if (trailing != null) ...[const SizedBox(width: 4), trailing!],
        ],
      ),
    );
  }
}
