import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../theme/app_theme.dart';
import '../theme/spotify_colors.dart';

/// A horizontal pill filter.
class FilterPill extends StatelessWidget {
  const FilterPill({
    super.key,
    required this.label,
    required this.selected,
    required this.onTap,
    this.icon,
    this.fontSize = 13,
    this.fontWeight = FontWeight.w700,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;
  final String? icon;
  final double fontSize;
  final FontWeight fontWeight;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final color = selected ? SpotifyColors.accent : scheme.onSurfaceVariant;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        alignment: Alignment.center,
        padding: const EdgeInsets.symmetric(horizontal: 14),
        decoration: BoxDecoration(
          color: selected
              ? SpotifyColors.accent.withValues(alpha: 0.16)
              : Colors.transparent,
          border: Border.all(
            color: selected ? SpotifyColors.accent : scheme.outline,
          ),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null) ...[
              SvgPicture.asset(
                'assets/icons/$icon.svg',
                width: 16,
                height: 16,
                colorFilter: ColorFilter.mode(color, BlendMode.srcIn),
              ),
              const SizedBox(width: 6),
            ],
            Text(
              label,
              style: TextStyle(
                fontFamily: AppTheme.fontFamily,
                fontSize: fontSize,
                fontWeight: fontWeight,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// A row of [FilterPill]s that behave like tabs.
class FilterPills extends StatelessWidget {
  const FilterPills({
    super.key,
    required this.filters,
    required this.selected,
    required this.onSelected,
    this.fontSize = 13,
    this.fontWeight = FontWeight.w700,
  });

  final List<String> filters;
  final int selected;
  final ValueChanged<int> onSelected;
  final double fontSize;
  final FontWeight fontWeight;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 40,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
        itemCount: filters.length,
        separatorBuilder: (_, _) => const SizedBox(width: 8),
        itemBuilder: (context, i) => FilterPill(
          key: ValueKey('filter-${filters[i]}'),
          label: filters[i],
          selected: i == selected,
          onTap: () => onSelected(i),
          fontSize: fontSize,
          fontWeight: fontWeight,
        ),
      ),
    );
  }
}
