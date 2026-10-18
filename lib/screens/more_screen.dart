import 'library_screen.dart';
import 'settings_screen.dart';
import 'student_agent_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../theme/app_type.dart';
import '../navigation/app_route.dart';
import '../theme/spotify_colors.dart';
import '../widgets/workspace_app_bar.dart';

/// The More section — the fifth tab of [HomeShell].
///
/// Mirrors the Profile app bar (heading + Encore logo) and lists the
/// secondary destinations, Slack's "More" page style.
class MoreScreen extends StatelessWidget {
  const MoreScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        const WorkspaceAppBar(heading: 'More'),
        Expanded(
          child: ListView(
            padding: EdgeInsets.zero,
            children: [
              const SizedBox(height: 8),
              for (var i = 0; i < _items.length; i++) ...[
                if (i > 0)
                  const Divider(
                    height: 1,
                    thickness: 1,
                    color: SpotifyColors.border,
                  ),
                _MoreTile(item: _items[i]),
              ],
              const SizedBox(height: 8),
            ],
          ),
        ),
      ],
    );
  }
}

/// A single destination on the [MoreScreen] list.
class _MoreItem {
  const _MoreItem({
    required this.icon,
    required this.label,
    required this.subtitle,
  });

  /// SVG file name in `assets/icons` (without extension).
  final String icon;
  final String label;
  final String subtitle;
}

const List<_MoreItem> _items = [
  _MoreItem(
    icon: 'library',
    label: 'Library',
    subtitle:
        'Browse through for available course materials, pdf and question papers',
  ),
  _MoreItem(
    icon: 'results',
    label: 'CGPA Tracker',
    subtitle: 'Monitor and manage your performance as a student',
  ),
  _MoreItem(
    icon: 'agents',
    label: 'Student Agents',
    subtitle:
        'Pay for available support and professional assistance in school '
        'activities.',
  ),
  _MoreItem(
    icon: 'settings',
    label: 'Settings',
    subtitle: 'Find setting and customize to preference',
  ),
];

class _MoreTile extends StatelessWidget {
  const _MoreTile({required this.item});

  final _MoreItem item;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return InkWell(
      onTap: () {
        if (item.label == 'Library') {
          Navigator.of(context).push(sharedAxisRoute(const LibraryScreen()));
        } else if (item.label == 'Student Agents') {
          Navigator.of(context).push(fadeRoute(const StudentAgentScreen()));
        } else if (item.label == 'Settings') {
          Navigator.of(context).push(sharedAxisRoute(const SettingsScreen()));
        }
      },
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        child: Row(
          children: [
            SvgPicture.asset(
              'assets/icons/${item.icon}.svg',
              width: 20,
              height: 20,
              colorFilter: ColorFilter.mode(
                scheme.onSurfaceVariant,
                BlendMode.srcIn,
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppType.name(scheme),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    item.subtitle,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: AppType.subtitle(scheme),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
