import 'dart:async';

import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../navigation/app_route.dart';
import '../services/auth_service.dart';
import '../theme/app_theme.dart';
import '../theme/app_type.dart';
import '../theme/spotify_colors.dart';
import '../widgets/add_expenditure_sheet.dart';
import '../widgets/add_funds_sheet.dart';
import '../widgets/checkout_sheet.dart';
import '../widgets/compose_fab.dart';
import '../widgets/user_avatar.dart';
import 'view_history_screen.dart';

/// The Finance section — the third tab of [HomeShell].
///
/// Shares the Slack-style workspace bar with the Updates section, but shows a
/// "Finances" heading (no subheading) and a notification glyph on the right.
class FinanceScreen extends StatefulWidget {
  const FinanceScreen({super.key});

  @override
  State<FinanceScreen> createState() => _FinanceScreenState();
}

class _FinanceScreenState extends State<FinanceScreen>
    with AutomaticKeepAliveClientMixin {
  StreamSubscription<Map<String, dynamic>?>? _profileSubscription;

  String _fullName = 'Odeh Solomon';
  String _accountNumber = '4267438338';
  String _bankName = 'Kuda Bank';
  String _registrationNumber = '20241426282';
  String _department = 'Computer Science';
  String _level = '300 Level';
  double _availablePoints = 0;

  late List<_Due> _dues = List.of(_initialDues);

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    if (AuthService.isAvailable) {
      _profileSubscription = AuthService.instance
          .currentUserProfileStream()
          .listen(_applyProfile);
    }
  }

  @override
  void dispose() {
    unawaited(_profileSubscription?.cancel());
    super.dispose();
  }

  void _applyProfile(Map<String, dynamic>? data) {
    if (!mounted || data == null) return;

    final fullName = (data['fullName'] as String?)?.trim();
    final accountNumber = (data['accountNumber'] as String?)?.trim();
    final bankName =
        (data['bankName'] as String?)?.trim() ??
        (data['bank'] as String?)?.trim();
    final registrationNumber = (data['registrationNumber'] as String?)?.trim();
    final department = (data['department'] as String?)?.trim();
    final level = (data['level'] as String?)?.trim();
    final points = data['availablePoints'];

    setState(() {
      if (fullName != null && fullName.isNotEmpty) _fullName = fullName;
      if (accountNumber != null && accountNumber.isNotEmpty) {
        _accountNumber = accountNumber;
      }
      if (bankName != null && bankName.isNotEmpty) _bankName = bankName;
      if (registrationNumber != null && registrationNumber.isNotEmpty) {
        _registrationNumber = registrationNumber;
      }
      if (department != null && department.isNotEmpty) {
        _department = department;
      }
      if (level != null && level.isNotEmpty) _level = level;
      if (points is num) _availablePoints = points.toDouble();
    });
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final scheme = Theme.of(context).colorScheme;
    final completed = _dues.where((due) => due.paid).length;
    final total = _dues.length;
    final unpaid = total - completed;
    final progress = total == 0 ? 0.0 : completed / total;

    return Stack(
      children: [
        ListView(
          padding: EdgeInsets.zero,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
              child: _FinanceHero(
                fullName: _fullName,
                accountNumber: _accountNumber,
                bankName: _bankName,
                availablePoints: _availablePoints.toStringAsFixed(2),
                onCopy: () => _copyAccountNumber(context),
                onAddFunds: () => _showAddFunds(context),
                onViewHistory: () => Navigator.of(
                  context,
                ).push(sharedAxisRoute(const ViewHistoryScreen())),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
              child: _DuesCard(
                completed: completed,
                total: total,
                unpaid: unpaid,
                progress: progress,
                onPayAll: () => _showCheckout(context),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 24, 16, 0),
              child: Text(
                'Budgeted Semester Expenditure',
                style: AppType.sectionTitle(scheme),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 0),
              child: Text(
                'Assigned for computer science - 200lvl',
                style: AppType.timestamp(scheme),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
              child: Row(
                children: [
                  const _ExpenditureFilter(),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Container(
                      height: 42,
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      decoration: BoxDecoration(
                        color: SpotifyColors.surface,
                        borderRadius: BorderRadius.circular(4),
                        border: Border.all(color: SpotifyColors.border),
                      ),
                      child: Row(
                        children: [
                          SvgPicture.asset(
                            'assets/icons/searching.svg',
                            width: 16,
                            height: 16,
                            colorFilter: ColorFilter.mode(
                              scheme.onSurfaceVariant.withValues(alpha: 0.8),
                              BlendMode.srcIn,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: TextField(
                              style: AppType.timestamp(scheme),
                              cursorColor: scheme.primary,
                              cursorHeight: 14,
                              textAlignVertical: TextAlignVertical.center,
                              decoration: InputDecoration(
                                isDense: true,
                                contentPadding: EdgeInsets.zero,
                                border: InputBorder.none,
                                enabledBorder: InputBorder.none,
                                focusedBorder: InputBorder.none,
                                disabledBorder: InputBorder.none,
                                errorBorder: InputBorder.none,
                                focusedErrorBorder: InputBorder.none,
                                hintText: 'Search',
                                hintStyle: AppType.timestamp(scheme),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            for (final due in _dues) _ExpenditureTile(due: due),
            const SizedBox(height: 96),
          ],
        ),
        Positioned.fill(
          child: ComposeFab(
            buttonKey: const ValueKey('finance-add-button'),
            actions: const [
              ComposeAction(
                label: 'Add Expenditure',
                icon: LucideIcons.receipt,
              ),
            ],
            onActionSelected: (_) => _addExpenditure(context),
          ),
        ),
      ],
    );
  }

  Future<void> _copyAccountNumber(BuildContext context) async {
    await Clipboard.setData(ClipboardData(text: _accountNumber));
    if (!context.mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(const SnackBar(content: Text('Account number copied')));
  }

  void _showAddFunds(BuildContext context) {
    showAddFundsSheet(
      context,
      fullName: _fullName,
      accountNumber: _accountNumber,
      bankName: _bankName,
      availablePoints: _availablePoints.toStringAsFixed(2),
      registrationNumber: _registrationNumber,
      department: _department,
      level: _level,
    );
  }

  Future<void> _addExpenditure(BuildContext context) async {
    final draft = await showAddExpenditureSheet(context);
    if (draft == null || !context.mounted) return;

    setState(() {
      _dues = [
        ..._dues,
        _Due(
          title: draft.title,
          amount: draft.amount,
          kind: _DueKind.manual,
          paid: false,
        ),
      ];
    });

    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(content: Text('${draft.title} added to expenditures')),
      );
  }

  void _showCheckout(BuildContext context) {
    final items = _dues
        .where((d) => !d.paid)
        .map(
          (d) =>
              CheckoutItem(title: d.title, amount: d.amount, iconAsset: d.icon),
        )
        .toList();
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => CheckoutSheet(items: items),
    );
  }
}

/// Full-bleed finance header. The Encore mark is used as a muted backdrop.
class _FinanceHero extends StatelessWidget {
  const _FinanceHero({
    required this.fullName,
    required this.accountNumber,
    required this.bankName,
    required this.availablePoints,
    required this.onCopy,
    required this.onAddFunds,
    required this.onViewHistory,
  });

  final String fullName;
  final String accountNumber;
  final String bankName;
  final String availablePoints;
  final VoidCallback onCopy;
  final VoidCallback onAddFunds;
  final VoidCallback onViewHistory;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final topInset = MediaQuery.of(context).padding.top;

    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: SpotifyColors.surface,
        borderRadius: BorderRadius.circular(4),
        image: const DecorationImage(
          image: AssetImage('assets/Encore.png'),
          fit: BoxFit.cover,
          alignment: Alignment.topRight,
          opacity: 0.18,
        ),
      ),
      padding: EdgeInsets.fromLTRB(16, topInset + 12, 16, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                'ENCORE',
                style: AppType.tag(
                  scheme.onSurfaceVariant,
                ).copyWith(letterSpacing: 1.2),
              ),
              const Spacer(),
              SvgPicture.asset(
                'assets/icons/notification.svg',
                width: 20,
                height: 20,
                colorFilter: ColorFilter.mode(
                  scheme.onSurface,
                  BlendMode.srcIn,
                ),
              ),
              const SizedBox(width: 12),
              const CurrentUserAvatar(size: 34),
            ],
          ),
          const SizedBox(height: 18),
          Text(
            'Finances',
            style: TextStyle(
              fontFamily: AppTheme.fontFamily,
              fontSize: 40,
              height: 1,
              fontWeight: FontWeight.w800,
              letterSpacing: -1.2,
              color: scheme.onSurface,
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: Text(
                  '2025/2026 FIRST SEMESTER',
                  style: AppType.tag(
                    scheme.onSurfaceVariant,
                  ).copyWith(letterSpacing: 0.8),
                ),
              ),
              GestureDetector(
                key: const ValueKey('view-history-button'),
                onTap: onViewHistory,
                child: Text(
                  'View History',
                  style: AppType.timestamp(scheme).copyWith(
                    color: scheme.primary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'AVAILABLE POINTS',
                      style: AppType.tag(scheme.onSurfaceVariant),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      availablePoints,
                      style: TextStyle(
                        fontFamily: AppTheme.fontFamily,
                        fontSize: 32,
                        height: 1,
                        fontWeight: FontWeight.w700,
                        color: scheme.primary,
                      ),
                    ),
                  ],
                ),
              ),
              _FundButton(onTap: onAddFunds),
            ],
          ),
          const SizedBox(height: 16),
          Container(height: 1, color: SpotifyColors.border),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: Text(
                  fullName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppType.cardTitle(scheme),
                ),
              ),
              const SizedBox(width: 6),
              IconButton(
                key: const ValueKey('copy-account-number'),
                tooltip: 'Copy account number',
                onPressed: onCopy,
                padding: EdgeInsets.zero,
                visualDensity: VisualDensity.compact,
                constraints: const BoxConstraints.tightFor(
                  width: 24,
                  height: 24,
                ),
                icon: Icon(
                  LucideIcons.copy,
                  size: 14,
                  color: scheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
          const SizedBox(height: 2),
          Row(
            children: [
              Text(accountNumber, style: AppType.timestamp(scheme)),
              const SizedBox(width: 6),
              Container(
                width: 3,
                height: 3,
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  color: SpotifyColors.borderStrong,
                ),
              ),
              const SizedBox(width: 6),
              Flexible(
                child: Text(
                  bankName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppType.tag(scheme.primary),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Dues progress and the primary payment action.
class _DuesCard extends StatelessWidget {
  const _DuesCard({
    required this.completed,
    required this.total,
    required this.unpaid,
    required this.progress,
    required this.onPayAll,
  });

  final int completed;
  final int total;
  final int unpaid;
  final double progress;
  final VoidCallback onPayAll;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
      decoration: BoxDecoration(
        color: SpotifyColors.surface,
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: SpotifyColors.border),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  '$completed/$total Dues completed',
                  style: AppType.cardTitle(scheme),
                ),
              ),
              Text(
                '${(progress * 100).round()}%',
                style: AppType.tag(scheme.primary),
              ),
            ],
          ),
          const SizedBox(height: 10),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 4,
              color: scheme.primary,
              backgroundColor: SpotifyColors.surfaceHover,
            ),
          ),
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            height: 46,
            child: FilledButton(
              onPressed: unpaid == 0 ? null : onPayAll,
              style: FilledButton.styleFrom(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(4),
                ),
                textStyle: TextStyle(
                  fontFamily: AppTheme.fontFamily,
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                ),
              ),
              child: Text('Pay All ($unpaid unpaid)'),
            ),
          ),
        ],
      ),
    );
  }
}

/// The green "Fund" action shown on the account banner.
class _FundButton extends StatelessWidget {
  const _FundButton({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final buttonColor = Theme.of(context).colorScheme.primary;

    return Material(
      color: buttonColor,
      borderRadius: BorderRadius.circular(4),
      child: InkWell(
        key: const ValueKey('add-funds-button'),
        borderRadius: BorderRadius.circular(4),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(LucideIcons.plus, size: 14, color: Colors.white),
              const SizedBox(width: 4),
              Text(
                'Add Funds',
                style: TextStyle(
                  fontFamily: AppTheme.fontFamily,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: Colors.white,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Tappable expenditure filter that opens an animated dropdown.
class _ExpenditureFilter extends StatefulWidget {
  const _ExpenditureFilter();

  @override
  State<_ExpenditureFilter> createState() => _ExpenditureFilterState();
}

class _ExpenditureFilterState extends State<_ExpenditureFilter> {
  static const List<String> _options = [
    'All Expenditures',
    'Manuals',
    'Registration Dues',
    'Other Expenses',
  ];

  String _selected = _options.first;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final labelColor = scheme.onSurfaceVariant.withValues(alpha: 0.8);

    return MenuAnchor(
      style: MenuStyle(
        backgroundColor: const WidgetStatePropertyAll(SpotifyColors.surface),
        surfaceTintColor: const WidgetStatePropertyAll(Colors.transparent),
        elevation: const WidgetStatePropertyAll(8),
        padding: const WidgetStatePropertyAll(
          EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        ),
        shape: WidgetStatePropertyAll(
          RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(4),
            side: const BorderSide(color: SpotifyColors.border),
          ),
        ),
      ),
      menuChildren: [
        for (final option in _options)
          MenuItemButton(
            onPressed: () => setState(() => _selected = option),
            style: ButtonStyle(
              foregroundColor: WidgetStatePropertyAll(labelColor),
              overlayColor: WidgetStatePropertyAll(
                scheme.primary.withValues(alpha: 0.12),
              ),
              textStyle: WidgetStatePropertyAll(AppType.timestamp(scheme)),
            ),
            child: Text(option),
          ),
      ],
      builder: (context, controller, _) => GestureDetector(
        onTap: () => controller.isOpen ? controller.close() : controller.open(),
        child: Container(
          height: 40,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
            color: SpotifyColors.surface,
            borderRadius: BorderRadius.circular(4),
            border: Border.all(color: SpotifyColors.border),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              SvgPicture.asset(
                'assets/icons/filter.svg',
                width: 16,
                height: 16,
                colorFilter: ColorFilter.mode(labelColor, BlendMode.srcIn),
              ),
              const SizedBox(width: 6),
              Text(_selected, style: AppType.timestamp(scheme)),
              const SizedBox(width: 2),
              AnimatedRotation(
                turns: controller.isOpen ? 0.5 : 0,
                duration: const Duration(milliseconds: 200),
                curve: Curves.easeOut,
                child: Icon(
                  LucideIcons.chevronDown,
                  size: 18,
                  color: labelColor,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Kinds of dues shown in the expenditure list.
enum _DueKind { manual, functional, profile }

/// A single expenditure due rendered by [_ExpenditureTile].
class _Due {
  const _Due({
    required this.title,
    required this.amount,
    required this.kind,
    required this.paid,
  });

  final String title;
  final String amount;
  final _DueKind kind;
  final bool paid;

  String get icon => switch (kind) {
    _DueKind.manual => 'assets/icons/manual.svg',
    _DueKind.functional => 'assets/icons/Functional.svg',
    _DueKind.profile => 'assets/icons/Profiledues.svg',
  };
}

const List<_Due> _initialDues = [
  _Due(
    title: 'GST 212 - Philosophy and Logic',
    amount: '₦1,500.00',
    kind: _DueKind.manual,
    paid: true,
  ),
  _Due(
    title: 'MATH 202 - Differential Calculus',
    amount: '₦1,500.00',
    kind: _DueKind.manual,
    paid: false,
  ),
  _Due(
    title: 'Departmental Due',
    amount: '₦5,000.00',
    kind: _DueKind.functional,
    paid: false,
  ),
  _Due(
    title: 'Workshop Levy',
    amount: '₦2,500.00',
    kind: _DueKind.functional,
    paid: true,
  ),
  _Due(
    title: 'Course Rep Dues',
    amount: '₦1,000.00',
    kind: _DueKind.profile,
    paid: false,
  ),
  _Due(
    title: 'Course Advisor Dues',
    amount: '₦2,000.00',
    kind: _DueKind.profile,
    paid: false,
  ),
];

/// A row in the expenditure list.
class _ExpenditureTile extends StatelessWidget {
  const _ExpenditureTile({required this.due});

  final _Due due;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 4),
      child: Container(
        padding: const EdgeInsets.fromLTRB(12, 12, 6, 12),
        decoration: BoxDecoration(
          color: SpotifyColors.surface,
          borderRadius: BorderRadius.circular(4),
          border: Border.all(
            color: due.paid
                ? scheme.primary.withValues(alpha: 0.55)
                : SpotifyColors.border,
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 22,
              height: 22,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: due.paid
                    ? scheme.primary.withValues(alpha: 0.16)
                    : Colors.transparent,
                border: Border.all(
                  color: due.paid ? scheme.primary : SpotifyColors.borderStrong,
                  width: 1.5,
                ),
              ),
              child: due.paid
                  ? Icon(LucideIcons.check, size: 12, color: scheme.primary)
                  : null,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    due.title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: AppType.cardTitle(scheme),
                  ),
                  const SizedBox(height: 5),
                  _PaidBadge(paid: due.paid),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Text(
              due.amount,
              style: AppType.cardTitle(
                scheme,
              ).copyWith(fontWeight: FontWeight.w600),
            ),
            const SizedBox(width: 2),
            _TileOptionsMenu(
              key: ValueKey('due-options-${due.title}'),
              paid: due.paid,
            ),
          ],
        ),
      ),
    );
  }
}

/// Small paid/unpaid pill shown in [_ExpenditureTile].
class _PaidBadge extends StatelessWidget {
  const _PaidBadge({required this.paid});

  final bool paid;

  @override
  Widget build(BuildContext context) {
    final color = paid
        ? Theme.of(context).colorScheme.primary
        : SpotifyColors.tagUrgent;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(paid ? 'Paid' : 'Unpaid', style: AppType.tag(color)),
    );
  }
}

/// Overflow menu opened from a due tile's `option.svg`.
///
/// The actions depend on whether the due has been paid.
class _TileOptionsMenu extends StatelessWidget {
  const _TileOptionsMenu({super.key, required this.paid});

  final bool paid;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final options = paid
        ? const ['Save Details', 'View Receipt']
        : const ['Draft Invoice', 'View Details'];

    return MenuAnchor(
      style: MenuStyle(
        backgroundColor: const WidgetStatePropertyAll(SpotifyColors.surface),
        surfaceTintColor: const WidgetStatePropertyAll(Colors.transparent),
        elevation: const WidgetStatePropertyAll(8),
        padding: const WidgetStatePropertyAll(
          EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        ),
        shape: WidgetStatePropertyAll(
          RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(4),
            side: const BorderSide(color: SpotifyColors.border),
          ),
        ),
      ),
      menuChildren: [
        for (final option in options)
          MenuItemButton(
            onPressed: () {},
            style: ButtonStyle(
              foregroundColor: WidgetStatePropertyAll(
                scheme.onSurfaceVariant.withValues(alpha: 0.8),
              ),
              overlayColor: WidgetStatePropertyAll(
                scheme.primary.withValues(alpha: 0.12),
              ),
              textStyle: WidgetStatePropertyAll(AppType.timestamp(scheme)),
            ),
            child: Text(option),
          ),
      ],
      builder: (context, controller, _) => GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => controller.isOpen ? controller.close() : controller.open(),
        child: Padding(
          padding: const EdgeInsets.all(6),
          child: SvgPicture.asset(
            'assets/icons/option.svg',
            width: 18,
            height: 18,
            colorFilter: ColorFilter.mode(
              scheme.onSurfaceVariant,
              BlendMode.srcIn,
            ),
          ),
        ),
      ),
    );
  }
}
