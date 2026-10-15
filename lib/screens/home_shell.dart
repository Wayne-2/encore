import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../theme/app_theme.dart';
import '../theme/slack_colors.dart';

/// The app shell once the user is signed in: a Slack-style bottom navigation
/// with five sections — Updates, Messages, Profile, Transactions and More.
class HomeShell extends StatefulWidget {
  const HomeShell({super.key});

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  static const List<_NavTab> _tabs = [
    _NavTab(label: 'Updates', icon: 'updates'),
    _NavTab(label: 'Messages', icon: 'messages'),
    _NavTab(label: 'Profile', icon: 'profile'),
    _NavTab(label: 'Finance', icon: 'transactions'),
    _NavTab(label: 'More', icon: 'more'),
  ];

  int _index = 0;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: SlackColors.darkBackground,
      body: SafeArea(
        bottom: false,
        child: IndexedStack(
          index: _index,
          children: [for (final tab in _tabs) _TabPlaceholder(tab: tab)],
        ),
      ),
      bottomNavigationBar: _BottomNavBar(
        tabs: _tabs,
        index: _index,
        onTap: (i) => setState(() => _index = i),
      ),
    );
  }
}

/// A single navigation section.
class _NavTab {
  const _NavTab({required this.label, required this.icon});

  final String label;

  /// SVG file name in `assets/icons` (without extension).
  final String icon;
}

/// Slack-style bottom bar: five labelled SVG tabs, the active one tinted green.
class _BottomNavBar extends StatelessWidget {
  const _BottomNavBar({
    required this.tabs,
    required this.index,
    required this.onTap,
  });

  final List<_NavTab> tabs;
  final int index;
  final ValueChanged<int> onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Container(
      decoration: BoxDecoration(
        color: SlackColors.darkSurface,
        border: Border(top: BorderSide(color: scheme.outline)),
      ),
      child: SafeArea(
        top: false,
        child: Row(
          children: [
            for (var i = 0; i < tabs.length; i++)
              Expanded(
                child: _NavButton(
                  key: ValueKey('nav-${tabs[i].label}'),
                  tab: tabs[i],
                  selected: i == index,
                  onTap: () => onTap(i),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _NavButton extends StatelessWidget {
  const _NavButton({
    super.key,
    required this.tab,
    required this.selected,
    required this.onTap,
  });

  final _NavTab tab;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = selected
        ? SlackColors.accentGreen
        : Theme.of(context).colorScheme.onSurfaceVariant;

    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SvgPicture.asset(
              'assets/icons/${tab.icon}.svg',
              width: 24,
              height: 24,
              colorFilter: ColorFilter.mode(color, BlendMode.srcIn),
            ),
            const SizedBox(height: 4),
            Text(
              tab.label,
              style: TextStyle(
                fontFamily: AppTheme.fontFamily,
                fontSize: 11,
                fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Placeholder section body until the real screens land.
class _TabPlaceholder extends StatelessWidget {
  const _TabPlaceholder({required this.tab});

  final _NavTab tab;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SvgPicture.asset(
            'assets/icons/${tab.icon}.svg',
            width: 48,
            height: 48,
            colorFilter: ColorFilter.mode(
              scheme.onSurfaceVariant,
              BlendMode.srcIn,
            ),
          ),
          const SizedBox(height: 12),
          Text(tab.label, style: Theme.of(context).textTheme.headlineSmall),
          const SizedBox(height: 4),
          Text(
            'Coming soon',
            style: TextStyle(
              fontFamily: AppTheme.fontFamily,
              fontSize: 14,
              color: scheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}
