import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../theme/app_theme.dart';
import '../theme/spotify_colors.dart';
import 'finance_screen.dart';
import 'messages_screen.dart';
import 'more_screen.dart';
import 'profile_screen.dart';
import 'updates_screen.dart';

/// The app shell once the user is signed in: a Slack-style bottom navigation
/// with five sections — Updates, Messages, Finance, Profile and More.
///
/// Sections can be reached by tapping a tab or by swiping the content left and
/// right, the way WhatsApp switches between its top tabs. The tab highlight
/// follows the swipe offset so it slides between sections.
class HomeShell extends StatefulWidget {
  const HomeShell({super.key});

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  static const List<_NavTab> _tabs = [
    _NavTab(label: 'Updates', icon: 'updates'),
    _NavTab(label: 'Messages', icon: 'messages'),
    _NavTab(label: 'Finance', icon: 'transactions'),
    _NavTab(label: 'Profile', icon: 'profile'),
    _NavTab(label: 'More', icon: 'more'),
  ];

  final _controller = PageController();
  int _index = 0;

  /// Light status-bar icons over the dark header colour.
  static const SystemUiOverlayStyle _overlayStyle = SystemUiOverlayStyle(
    statusBarColor: SpotifyColors.background,
    statusBarIconBrightness: Brightness.light,
    statusBarBrightness: Brightness.dark,
  );

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _goTo(int page) {
    _controller.animateToPage(
      page,
      duration: const Duration(milliseconds: 350),
      curve: Curves.easeOutCubic,
    );
  }

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: _overlayStyle,
      child: Scaffold(
        backgroundColor: SpotifyColors.background,
        body: PageView.builder(
          controller: _controller,
          itemCount: _tabs.length,
          onPageChanged: (i) => setState(() => _index = i),
          itemBuilder: (context, i) => switch (i) {
            0 => const UpdatesScreen(),
            1 => const MessagesScreen(),
            2 => const FinanceScreen(),
            3 => const ProfileScreen(),
            4 => const MoreScreen(),
            _ => _TabPlaceholder(tab: _tabs[i]),
          },
        ),
        // Rebuilds as the pages scroll so the highlight tracks the swipe.
        bottomNavigationBar: AnimatedBuilder(
          animation: _controller,
          builder: (context, _) {
            final page = _controller.hasClients
                ? (_controller.page ?? _index.toDouble())
                : _index.toDouble();
            return _BottomNavBar(tabs: _tabs, page: page, onTap: _goTo);
          },
        ),
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

/// Slack-style bottom bar: five labelled SVG tabs that highlight in green as
/// the pages scroll under them.
class _BottomNavBar extends StatelessWidget {
  const _BottomNavBar({
    required this.tabs,
    required this.page,
    required this.onTap,
  });

  final List<_NavTab> tabs;
  final double page;
  final ValueChanged<int> onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Container(
      decoration: BoxDecoration(
        color: SpotifyColors.surface,
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
                  page: page,
                  index: i,
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
    required this.page,
    required this.index,
    required this.onTap,
  });

  final _NavTab tab;
  final double page;
  final int index;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    /// How "selected" this tab is, driven straight from the scroll offset so
    /// it eases between 0 and 1 while the pages swipe.
    final t = (1 - (page - index).abs()).clamp(0.0, 1.0);

    final color = Color.lerp(
      scheme.onSurfaceVariant,
      SpotifyColors.accent,
      t,
    )!;

    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Stack(
              alignment: Alignment.center,
              children: [
                // Material-style indicator that grows in behind the icon.
                Opacity(
                  opacity: t,
                  child: Transform.scale(
                    scale: 0.75 + 0.25 * t,
                    child: Container(
                      width: 44,
                      height: 28,
                      decoration: BoxDecoration(
                        color: SpotifyColors.accent.withValues(alpha: 0.16),
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                  ),
                ),
                SvgPicture.asset(
                  'assets/icons/${tab.icon}.svg',
                  width: 24,
                  height: 24,
                  colorFilter: ColorFilter.mode(color, BlendMode.srcIn),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              tab.label,
              style: TextStyle(
                fontFamily: AppTheme.fontFamily,
                fontSize: 11,
                fontWeight: FontWeight.lerp(
                  FontWeight.w500,
                  FontWeight.w600,
                  t,
                ),
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
