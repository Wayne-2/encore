import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../theme/app_type.dart';
import '../theme/slack_colors.dart';
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
                    color: SlackColors.darkBorder,
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
  const _MoreItem({required this.icon, required this.label});

  /// SVG file name in `assets/icons` (without extension).
  final String icon;
  final String label;
}

const List<_MoreItem> _items = [
  _MoreItem(icon: 'library', label: 'Library'),
  _MoreItem(icon: 'results', label: 'CGPA Tracker'),
  _MoreItem(icon: 'agents', label: 'Student Agents'),
  _MoreItem(icon: 'settings', label: 'Settings'),
];

class _MoreTile extends StatelessWidget {
  const _MoreTile({required this.item});

  final _MoreItem item;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return InkWell(
      onTap: () {},
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
              child: Text(
                item.label,
                style: AppType.body(scheme).copyWith(color: scheme.onSurface),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
