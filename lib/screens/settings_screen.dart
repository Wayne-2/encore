import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../theme/app_type.dart';
import '../theme/spotify_colors.dart';

/// The "Settings" destination reached from [MoreScreen].
///
/// Structured after X's (Twitter) "Settings and privacy" screen: a centered
/// title bar, a rounded "Search settings" field, then a divided list of
/// categories each led by an outline icon, a bold title and a muted subtitle.
/// Rendered in the app's own dark theme.
class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Scaffold(
      backgroundColor: SpotifyColors.background,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            SizedBox(
              height: 52,
              child: Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.arrow_back_ios_new, size: 20),
                    color: scheme.onSurface,
                    onPressed: () => Navigator.of(context).maybePop(),
                  ),
                  Expanded(
                    child: Center(
                      child: Text(
                        'Settings and privacy',
                        style: AppType.name(scheme),
                      ),
                    ),
                  ),
                  const SizedBox(width: 48),
                ],
              ),
            ),
            _SearchField(scheme: scheme),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.only(top: 4, bottom: 24),
                children: [
                  for (var i = 0; i < _settings.length; i++) ...[
                    if (i > 0)
                      const Divider(
                        height: 1,
                        thickness: 1,
                        color: SpotifyColors.border,
                      ),
                    _SettingTile(item: _settings[i]),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// The rounded "Search settings" field mirroring X's settings search.
class _SearchField extends StatelessWidget {
  const _SearchField({required this.scheme});

  final ColorScheme scheme;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
        decoration: BoxDecoration(
          color: SpotifyColors.surface,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: SpotifyColors.border),
        ),
        child: Row(
          children: [
            Icon(Icons.search, size: 18, color: scheme.onSurfaceVariant),
            const SizedBox(width: 10),
            Text('Search settings', style: AppType.subtitle(scheme)),
          ],
        ),
      ),
    );
  }
}

/// A single settings category.
class _Setting {
  const _Setting({
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  /// SVG file name in `assets/icons` (without extension).
  final String icon;
  final String title;
  final String subtitle;
}

const List<_Setting> _settings = [
  _Setting(
    icon: 'profile',
    title: 'Your account',
    subtitle:
        'See information about your account, download an archive of your '
        'data, or learn about your account deactivation options',
  ),
  _Setting(
    icon: 'password',
    title: 'Privacy and safety',
    subtitle: 'Manage what information you see and share',
  ),
  _Setting(
    icon: 'notification',
    title: 'Notifications',
    subtitle:
        'Select the kinds of notifications you get about your activities, '
        'interests, and recommendations',
  ),
  _Setting(
    icon: 'show',
    title: 'Accessibility, display, and languages',
    subtitle: 'Manage how Encore content is displayed to you',
  ),
  _Setting(
    icon: 'transactions',
    title: 'Finance and payments',
    subtitle: 'Manage your points, fees and transaction history',
  ),
  _Setting(
    icon: 'more',
    title: 'Additional resources',
    subtitle: 'Check out other Encore resources and services',
  ),
  _Setting(
    icon: 'manual',
    title: 'Help Center',
    subtitle: 'Get help with using Encore',
  ),
];

/// A divided list row: leading icon, bold title and a muted subtitle.
class _SettingTile extends StatelessWidget {
  const _SettingTile({required this.item});

  final _Setting item;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return InkWell(
      onTap: () {},
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SvgPicture.asset(
              'assets/icons/${item.icon}.svg',
              width: 22,
              height: 22,
              colorFilter: ColorFilter.mode(
                scheme.onSurfaceVariant,
                BlendMode.srcIn,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(item.title, style: AppType.name(scheme)),
                  const SizedBox(height: 3),
                  Text(item.subtitle, style: AppType.subtitle(scheme)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
