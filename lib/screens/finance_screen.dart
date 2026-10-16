import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../theme/app_theme.dart';
import '../theme/app_type.dart';
import '../theme/slack_colors.dart';
import '../widgets/section_heading.dart';
import '../widgets/workspace_app_bar.dart';

/// The Finance section — the third tab of [HomeShell].
///
/// Shares the Slack-style workspace bar with the Updates section, but shows a
/// "Finances" heading (no subheading) and a notification glyph on the right.
class FinanceScreen extends StatelessWidget {
  const FinanceScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Column(
      children: [
        WorkspaceAppBar(
          heading: 'Finances',
          trailing: SvgPicture.asset(
            'assets/icons/notification.svg',
            width: 20,
            height: 20,
            colorFilter: ColorFilter.mode(scheme.onSurface, BlendMode.srcIn),
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
                      style: AppType.name(scheme),
                    ),
                    Text('History', style: AppType.subtitle(scheme)),
                  ],
                ),
              ),
              const Padding(
                padding: EdgeInsets.fromLTRB(16, 12, 16, 0),
                child: _BankBanner(),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                child: Row(
                  children: [
                    Text(
                      '3/10 Dues completed',
                      style: AppType.subtitle(scheme),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: LinearProgressIndicator(
                        value: 0.33,
                        minHeight: 5,
                        color: scheme.primary,
                        backgroundColor: Colors.white.withValues(alpha: 0.7),
                        borderRadius: BorderRadius.circular(2.5),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Text('33%', style: AppType.subtitle(scheme)),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 24, 16, 16),
                child: FractionallySizedBox(
                  widthFactor: 0.8,
                  child: FilledButton(
                    onPressed: () {},
                    child: Text('Pay All (7 unpaid)'),
                  ),
                ),
              ),
              const Padding(
                padding: EdgeInsets.fromLTRB(16, 28, 16, 0),
                child: SectionHeading('Budgeted Semester Expenditure'),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 0),
                child: Text(
                  'Assigned for computer science - 200lvl',
                  style: AppType.subtitle(scheme),
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
                          color: SlackColors.darkSurface,
                          borderRadius: BorderRadius.circular(4),
                          border: Border.all(color: SlackColors.darkBorder),
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
                                style: AppType.subtitle(scheme),
                                cursorColor: scheme.primary,
                                cursorHeight: 14,
                                decoration: InputDecoration(
                                  isDense: true,
                                  border: InputBorder.none,
                                  enabledBorder: InputBorder.none,
                                  focusedBorder: InputBorder.none,
                                  disabledBorder: InputBorder.none,
                                  errorBorder: InputBorder.none,
                                  focusedErrorBorder: InputBorder.none,
                                  hintText: 'Search',
                                  hintStyle: AppType.meta(scheme),
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
            ],
          ),
        ),
      ],
    );
  }
}

/// The account banner shown under the semester row.
class _BankBanner extends StatelessWidget {
  const _BankBanner();

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final lineColor = Colors.white.withValues(alpha: 0.7);

    return Container(
      constraints: const BoxConstraints(minHeight: 125),
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: SlackColors.darkSurface,
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: SlackColors.darkBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: Image.asset(
                  'assets/launch_icon_foreground.png',
                  width: 44,
                  height: 44,
                  fit: BoxFit.cover,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Row(
                      children: [
                        Text('Odeh Solomon', style: AppType.name(scheme)),
                        const SizedBox(width: 6),
                        Icon(
                          Icons.copy,
                          size: 14,
                          color: scheme.onSurfaceVariant,
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        Text('4267438338', style: AppType.meta(scheme)),
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
                        Text('Kuda Bank', style: AppType.tag(scheme.primary)),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              const _FundButton(),
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
              Text('Available Points', style: AppType.meta(scheme)),
              const SizedBox(width: 6),
              Text('0.00', style: AppType.tag(scheme.primary)),
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
  const _FundButton();

  @override
  Widget build(BuildContext context) {
    final buttonColor = Theme.of(context).colorScheme.primary;

    return Material(
      color: buttonColor,
      borderRadius: BorderRadius.circular(6),
      child: InkWell(
        borderRadius: BorderRadius.circular(6),
        onTap: () {},
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.add, size: 14, color: Colors.white),
              const SizedBox(width: 4),
              Text(
                'Fund',
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
        backgroundColor: const WidgetStatePropertyAll(SlackColors.darkSurface),
        surfaceTintColor: const WidgetStatePropertyAll(Colors.transparent),
        elevation: const WidgetStatePropertyAll(8),
        padding: const WidgetStatePropertyAll(
          EdgeInsets.symmetric(vertical: 6),
        ),
        shape: WidgetStatePropertyAll(
          RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: const BorderSide(color: SlackColors.darkBorder),
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
              textStyle: WidgetStatePropertyAll(AppType.subtitle(scheme)),
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
            color: SlackColors.darkSurface,
            borderRadius: BorderRadius.circular(4),
            border: Border.all(color: SlackColors.darkBorder),
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
              Text(_selected, style: AppType.subtitle(scheme)),
              const SizedBox(width: 2),
              AnimatedRotation(
                turns: controller.isOpen ? 0.5 : 0,
                duration: const Duration(milliseconds: 200),
                curve: Curves.easeOut,
                child: Icon(Icons.arrow_drop_down, size: 18, color: labelColor),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
