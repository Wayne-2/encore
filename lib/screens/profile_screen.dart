import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import '../theme/app_type.dart';
import '../theme/slack_colors.dart';
import '../widgets/section_heading.dart';
import '../widgets/workspace_app_bar.dart';

/// The Profile section — the fourth tab of [HomeShell].
///
/// Reuses the workspace bar with a "Profile" heading (no subheading) and the
/// Encore logo on the right, matching the Updates section.
class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  int _scheduleFilter = 0;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Column(
      children: [
        const WorkspaceAppBar(heading: 'Profile'),
        Expanded(
          child: ListView(
            padding: EdgeInsets.zero,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                child: Row(
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: Image.asset(
                        'assets/launch_icon_foreground.png',
                        width: 64,
                        height: 64,
                        fit: BoxFit.cover,
                        filterQuality: FilterQuality.medium,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Flexible(
                                child: Text(
                                  'Odeh Solomon',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: AppType.name(scheme),
                                ),
                              ),
                              const SizedBox(width: 6),
                              Container(
                                width: 3,
                                height: 3,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: scheme.onSurfaceVariant,
                                ),
                              ),
                              const SizedBox(width: 6),
                              Text(
                                '_wayne',
                                style: AppType.tag(scheme.primary),
                              ),
                            ],
                          ),
                          const SizedBox(height: 6),
                          Text(
                            'sodeh138@gmail.com',
                            style: AppType.meta(scheme),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const Divider(
                height: 32,
                thickness: 1,
                indent: 16,
                endIndent: 16,
                color: SlackColors.darkBorder,
              ),
              const _ProfileBanner(),
              const Padding(
                padding: EdgeInsets.fromLTRB(16, 28, 16, 0),
                child: SectionHeading('My Academic Schedules'),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                child: _ScheduleFilter(
                  selected: _scheduleFilter,
                  onSelected: (v) => setState(() => _scheduleFilter = v),
                ),
              ),
              const SizedBox(height: 8),
              ...(() {
                final items = _scheduleItems;
                final filtered = switch (_scheduleFilter) {
                  1 => items.where((e) => e.status == 'in-progress').toList(),
                  2 => items.where((e) => e.status == 'done').toList(),
                  _ => List.of(items),
                };
                return filtered.map((e) => _ScheduleTile(item: e));
              }()),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ],
    );
  }
}

/// The profile hero banner: a clipped card holding a slowly pulsing white
/// accent circle that overflows the top-right edge.
class _ProfileBanner extends StatelessWidget {
  const _ProfileBanner();

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
      child: Container(
        width: double.infinity,
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          color: SlackColors.darkSurface,
          borderRadius: BorderRadius.circular(4),
          border: Border.all(color: SlackColors.darkBorder),
        ),
        child: Stack(
          clipBehavior: Clip.hardEdge,
          children: [
            const Positioned(
              left: 288,
              top: -46,
              child: _PulsingCircle(size: 119),
            ),
            Padding(
              padding: const EdgeInsets.all(15),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text('Student', style: AppType.meta(scheme)),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Text(
                        '20241426282',
                        style: AppType.body(
                          scheme,
                        ).copyWith(color: scheme.onSurface),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        width: 4,
                        height: 4,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: scheme.primary,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        '300 level',
                        style: AppType.body(
                          scheme,
                        ).copyWith(color: scheme.onSurface),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      Text('Computer Science', style: AppType.subtitle(scheme)),
                      const SizedBox(width: 6),
                      Container(
                        width: 3,
                        height: 3,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: scheme.onSurfaceVariant,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Text('SICT', style: AppType.subtitle(scheme)),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Student Health bar',
                    style: AppType.body(scheme).copyWith(
                      color: scheme.onSurface,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(2),
                          child: LinearProgressIndicator(
                            value: 0.7,
                            minHeight: 2,
                            color: scheme.primary,
                            backgroundColor: SlackColors.darkBorder,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text('70%', style: AppType.subtitle(scheme)),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Performance is good so far',
                    style: AppType.subtitle(scheme),
                  ),
                  const SizedBox(height: 12),
                  FilledButton(
                    onPressed: () {},
                    child: const Text(
                      'Manage Health',
                      style: TextStyle(
                        fontFamily: AppTheme.fontFamily,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
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

/// A soft white circle that gently grows and shrinks in place.
class _PulsingCircle extends StatefulWidget {
  const _PulsingCircle({required this.size});

  final double size;

  @override
  State<_PulsingCircle> createState() => _PulsingCircleState();
}

class _PulsingCircleState extends State<_PulsingCircle>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1600),
  )..repeat(reverse: true);

  late final Animation<double> _scale = Tween<double>(
    begin: 1.0,
    end: 1.25,
  ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeInOut));

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ScaleTransition(
      scale: _scale,
      child: Container(
        width: widget.size,
        height: widget.size,
        decoration: const BoxDecoration(
          shape: BoxShape.circle,
          color: Color(0x33FFFFFF),
        ),
      ),
    );
  }
}

class _SchedulePill extends StatelessWidget {
  const _SchedulePill({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final color = selected ? SlackColors.accentGreen : scheme.onSurfaceVariant;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        alignment: Alignment.center,
        padding: const EdgeInsets.symmetric(horizontal: 18),
        decoration: BoxDecoration(
          color: selected
              ? SlackColors.accentGreen.withValues(alpha: 0.16)
              : Colors.transparent,
          border: Border.all(
            color: selected ? SlackColors.accentGreen : scheme.outline,
          ),
          borderRadius: BorderRadius.circular(4),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontFamily: AppTheme.fontFamily,
            fontSize: 12,
            fontWeight: FontWeight.w500,
            color: color,
          ),
        ),
      ),
    );
  }
}

/// The "All / In Progress / Done" filter for the academic schedules list.
class _ScheduleFilter extends StatelessWidget {
  const _ScheduleFilter({required this.selected, required this.onSelected});

  final int selected;
  final ValueChanged<int> onSelected;

  static const List<String> _filters = ['All', 'In Progress', 'Done'];

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 32,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: _filters.length,
        separatorBuilder: (_, _) => const SizedBox(width: 8),
        itemBuilder: (context, i) => _SchedulePill(
          label: _filters[i],
          selected: i == selected,
          onTap: () => onSelected(i),
        ),
      ),
    );
  }
}

/// A single academic-schedule entry.
class _ScheduleItem {
  const _ScheduleItem({
    required this.title,
    required this.when,
    required this.status,
  });

  final String title;
  final String when;
  final String status; // 'all' | 'in-progress' | 'done'
}

const List<_ScheduleItem> _scheduleItems = [
  _ScheduleItem(
    title: 'Submit the GET course Manual',
    when: '11 Oct, 11:00 AM',
    status: 'in-progress',
  ),
  _ScheduleItem(
    title: 'Go to Bookshop for Textbooks',
    when: '12 Oct, 1:30 PM',
    status: 'in-progress',
  ),
  _ScheduleItem(
    title: 'Submit Assignment for MATH 202',
    when: '13 Oct, 10:15 AM',
    status: 'in-progress',
  ),
  _ScheduleItem(
    title: 'Prepare for project defense',
    when: '15 Oct, 2:45 PM',
    status: 'in-progress',
  ),
  _ScheduleItem(
    title: 'Submit the GET course Manual',
    when: '18 Oct, 4:00 PM',
    status: 'done',
  ),
];

/// A schedule row: a completion checkbox, the task + its time, and a bookmark.
class _ScheduleTile extends StatefulWidget {
  const _ScheduleTile({required this.item});

  final _ScheduleItem item;

  @override
  State<_ScheduleTile> createState() => _ScheduleTileState();
}

class _ScheduleTileState extends State<_ScheduleTile> {
  bool _done = false;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.item.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppType.cardTitle(scheme),
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Icon(
                      Icons.timer_outlined,
                      size: 13,
                      color: scheme.onSurfaceVariant,
                    ),
                    const SizedBox(width: 6),
                    Text(widget.item.when, style: AppType.meta(scheme)),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Checkbox(
            value: _done,
            onChanged: (value) => setState(() => _done = value ?? false),
            visualDensity: VisualDensity.compact,
            materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
            shape: const CircleBorder(),
          ),
        ],
      ),
    );
  }
}
