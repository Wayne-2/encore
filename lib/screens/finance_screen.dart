import 'dart:async';

import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../navigation/app_route.dart';
import '../services/auth_service.dart';
import '../theme/app_theme.dart';
import '../theme/app_type.dart';
import '../theme/slack_type.dart';
import '../theme/spotify_colors.dart';
import '../widgets/add_expenditure_sheet.dart';
import '../widgets/add_funds_sheet.dart';
import '../widgets/checkout_sheet.dart';
import '../widgets/compose_fab.dart';
import '../widgets/section_heading.dart';
import '../widgets/user_avatar.dart';
import '../widgets/workspace_app_bar.dart';
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
        Column(
          children: [
            WorkspaceAppBar(
              heading: 'Finances',
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
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
                  const CurrentUserAvatar(size: 38),
                ],
              ),
            ),
            Expanded(
              child: ListView(
                padding: EdgeInsets.zero,
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          '2025/2026 FIRST SEMESTER',
                          style: AppType.name(
                            scheme,
                          ).copyWith(fontWeight: FontWeight.w500),
                        ),
                        GestureDetector(
                          key: const ValueKey('view-history-button'),
                          onTap: () => Navigator.of(
                            context,
                          ).push(sharedAxisRoute(const ViewHistoryScreen())),
                          child: Text(
                            'View History',
                            style: AppType.timestamp(
                              scheme,
                            ).copyWith(color: scheme.primary),
                          ),
                        ),
                      ],
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                    child: _BankBanner(
                      fullName: _fullName,
                      accountNumber: _accountNumber,
                      bankName: _bankName,
                      availablePoints: _availablePoints.toStringAsFixed(2),
                      onCopy: () => _copyAccountNumber(context),
                      onAddFunds: () => _showAddFunds(context),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                    child: Row(
                      children: [
                        Text(
                          '$completed/$total Dues completed',
                          style: AppType.timestamp(scheme),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: LinearProgressIndicator(
                            value: progress,
                            minHeight: 3,
                            color: scheme.primary,
                            backgroundColor: SpotifyColors.surfaceHover,
                            borderRadius: BorderRadius.circular(1.5),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Text(
                          '${(progress * 100).round()}%',
                          style: AppType.timestamp(scheme),
                        ),
                      ],
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 24, 16, 16),
                    child: FractionallySizedBox(
                      widthFactor: 0.8,
                      child: FilledButton(
                        onPressed: unpaid == 0
                            ? null
                            : () => _showCheckout(context),
                        child: Text('Pay All ($unpaid unpaid)'),
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 24, 16, 0),
                    child: SectionHeading(
                      'Budgeted Semester Expenditure',
                      style: SlackType.sectionTitle(scheme),
                      glyphStyle: SlackType.glyph(scheme),
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
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                    child: Row(
                      children: [
                        const _ExpenditureFilter(),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Container(
                            height: 40,
                            padding: const EdgeInsets.symmetric(horizontal: 12),
                            decoration: BoxDecoration(
                              color: SpotifyColors.surface,
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: SpotifyColors.border),
                            ),
                            child: Row(
                              children: [
                                SvgPicture.asset(
                                  'assets/icons/searching.svg',
                                  width: 16,
                                  height: 16,
                                  colorFilter: ColorFilter.mode(
                                    scheme.onSurfaceVariant.withValues(
                                      alpha: 0.8,
                                    ),
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
                  const SizedBox(height: 88),
                ],
              ),
            ),
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

/// The account banner shown under the semester row.
class _BankBanner extends StatelessWidget {
  const _BankBanner({
    required this.fullName,
    required this.accountNumber,
    required this.bankName,
    required this.availablePoints,
    required this.onCopy,
    required this.onAddFunds,
  });

  final String fullName;
  final String accountNumber;
  final String bankName;
  final String availablePoints;
  final VoidCallback onCopy;
  final VoidCallback onAddFunds;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final lineColor = Colors.white.withValues(alpha: 0.7);

    return Container(
      constraints: const BoxConstraints(minHeight: 125),
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: SpotifyColors.surface,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            fullName,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: AppType.cardTitle(scheme).copyWith(
                              fontSize: 16,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                        const SizedBox(width: 4),
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
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        Text(
                          accountNumber,
                          style: AppType.timestamp(scheme),
                        ),
                        const SizedBox(width: 6),
                        Container(
                          width: 3,
                          height: 3,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: Colors.white.withValues(alpha: 0.4),
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
              ),
              const SizedBox(width: 8),
              _FundButton(onTap: onAddFunds),
            ],
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              _DashLine(width: 108, color: lineColor),
              const SizedBox(width: 4),
              _DashLine(width: 11, color: lineColor),
              const SizedBox(width: 4),
              _DashLine(width: 3, height: 3, color: lineColor),
              const SizedBox(width: 4),
              _DashLine(width: 3, height: 3, color: lineColor),
              const SizedBox(width: 10),
              Text(
                'Available Points',
                style: AppType.timestamp(scheme),
              ),
              const SizedBox(width: 6),
              Text(
                availablePoints,
                style: AppType.tag(scheme.primary).copyWith(fontSize: 16),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// A short decorative bar used in the banner's points row.
class _DashLine extends StatelessWidget {
  const _DashLine({required this.width, this.height = 2, required this.color});

  final double width;
  final double height;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(height / 2),
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
      borderRadius: BorderRadius.circular(6),
      child: InkWell(
        key: const ValueKey('add-funds-button'),
        borderRadius: BorderRadius.circular(6),
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
            borderRadius: BorderRadius.circular(8),
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
            borderRadius: BorderRadius.circular(8),
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
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: SpotifyColors.surface,
              borderRadius: BorderRadius.circular(8),
            ),
            child: SvgPicture.asset(
              due.icon,
              width: 20,
              height: 20,
              colorFilter: ColorFilter.mode(
                scheme.onSurfaceVariant,
                BlendMode.srcIn,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  due.title,
                  style: AppType.cardTitle(
                    scheme,
                  ).copyWith(fontWeight: FontWeight.w500),
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    Text(due.amount, style: AppType.timestamp(scheme)),
                    const SizedBox(width: 8),
                    _PaidBadge(paid: due.paid),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          _TileOptionsMenu(
            key: ValueKey('due-options-${due.title}'),
            paid: due.paid,
          ),
        ],
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
        borderRadius: BorderRadius.circular(8),
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
            borderRadius: BorderRadius.circular(8),
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
