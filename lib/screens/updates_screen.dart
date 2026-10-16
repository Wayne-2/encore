import 'dart:math' as math;
import 'dart:ui' show ImageFilter;

import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../models/announcement.dart';
import '../navigation/app_route.dart';
import '../theme/app_theme.dart';
import '../theme/app_type.dart';
import '../theme/slack_colors.dart';
import '../widgets/section_heading.dart';
import '../widgets/workspace_app_bar.dart';
import 'announcement_detail_screen.dart';
import 'trending_more_screen.dart';

/// Vertical gap between the Updates page sections.
const double _sectionGap = 28;

/// The Updates section — the first tab of [HomeShell].
///
/// Opens with a Slack-style workspace bar, an Announcement feed that can be
/// filtered with All / Unread / Urgent / Older pills, a Trending row, and an
/// Upcoming Activities grid.
class UpdatesScreen extends StatefulWidget {
  const UpdatesScreen({super.key});

  @override
  State<UpdatesScreen> createState() => _UpdatesScreenState();
}

class _UpdatesScreenState extends State<UpdatesScreen> {
  static const List<_FilterOption> _filters = [
    _FilterOption('All'),
    _FilterOption('Unread', 'unread'),
    _FilterOption('Urgent', 'urgent'),
    _FilterOption('Older', 'older'),
  ];
  int _filter = 0;

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Column(
          children: [
            const WorkspaceAppBar(heading: 'Update', title: 'Csc 200 level'),
            Expanded(
              child: ListView(
                key: const ValueKey('updates-scroll'),
                padding: EdgeInsets.zero,
                children: [
                  _AnnouncementHeader(onMore: () => _showOptions(context)),
                  _FilterPills(
                    filters: _filters,
                    selected: _filter,
                    onSelected: (i) => setState(() => _filter = i),
                  ),
                  Stack(
                    key: const ValueKey('announcement-section'),
                    children: [
                      Visibility(
                        visible: _filter == 0,
                        maintainSize: true,
                        maintainAnimation: true,
                        maintainState: true,
                        child: _AnnouncementList(
                          onTap: (a) => _openAnnouncement(context, a),
                        ),
                      ),
                      if (_filter != 0)
                        const Positioned.fill(child: _EmptyFeed()),
                    ],
                  ),
                  const SizedBox(height: _sectionGap),
                  _TrendingSection(onShowMore: () => _openTrending(context)),
                  const SizedBox(height: _sectionGap),
                  const _UpcomingActivitiesSection(),
                  const SizedBox(height: _sectionGap),
                ],
              ),
            ),
          ],
        ),
        const Positioned.fill(child: _ComposeFab()),
      ],
    );
  }

  void _showOptions(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: SlackColors.darkSurface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (final label in [
              'Mark all as read',
              'Mute announcements',
              'Announcement settings',
            ])
              ListTile(
                title: Text(
                  label,
                  style: TextStyle(
                    fontFamily: AppTheme.fontFamily,
                    fontSize: 15,
                    color: Theme.of(context).colorScheme.onSurface,
                  ),
                ),
                onTap: () => Navigator.pop(context),
              ),
          ],
        ),
      ),
    );
  }

  void _openTrending(BuildContext context) {
    Navigator.of(context).push(fadeRoute(const TrendingMoreScreen()));
  }

  void _openAnnouncement(BuildContext context, Announcement announcement) {
    Navigator.of(
      context,
    ).push(fadeRoute(AnnouncementDetailScreen(announcement: announcement)));
  }
}

/// Section header: `# Announcement` with a trailing "more" action.
class _AnnouncementHeader extends StatelessWidget {
  const _AnnouncementHeader({required this.onMore});

  final VoidCallback onMore;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 6, 4, 2),
      child: Row(
        children: [
          const SectionHeading('Announcement'),
          const Spacer(),
          IconButton(
            onPressed: onMore,
            tooltip: 'More options',
            icon: SvgPicture.asset(
              'assets/icons/more.svg',
              width: 20,
              height: 20,
              colorFilter: ColorFilter.mode(
                scheme.onSurfaceVariant,
                BlendMode.srcIn,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Horizontal row of filter pills that behave like tabs.
class _FilterPills extends StatelessWidget {
  const _FilterPills({
    required this.filters,
    required this.selected,
    required this.onSelected,
  });

  final List<_FilterOption> filters;
  final int selected;
  final ValueChanged<int> onSelected;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 44,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        itemCount: filters.length,
        separatorBuilder: (_, _) => const SizedBox(width: 8),
        itemBuilder: (context, i) => _FilterPill(
          key: ValueKey('filter-${filters[i].label}'),
          filter: filters[i],
          selected: i == selected,
          onTap: () => onSelected(i),
        ),
      ),
    );
  }
}

class _FilterPill extends StatelessWidget {
  const _FilterPill({
    super.key,
    required this.filter,
    required this.selected,
    required this.onTap,
  });

  final _FilterOption filter;
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
        padding: const EdgeInsets.symmetric(horizontal: 14),
        decoration: BoxDecoration(
          color: selected
              ? SlackColors.accentGreen.withValues(alpha: 0.16)
              : Colors.transparent,
          border: Border.all(
            color: selected ? SlackColors.accentGreen : scheme.outline,
          ),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (filter.icon != null) ...[
              SvgPicture.asset(
                'assets/icons/${filter.icon}.svg',
                width: 16,
                height: 16,
                colorFilter: ColorFilter.mode(color, BlendMode.srcIn),
              ),
              const SizedBox(width: 6),
            ],
            Text(
              filter.label,
              style: TextStyle(
                fontFamily: AppTheme.fontFamily,
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// A filter pill: a label with an optional leading SVG icon.
class _FilterOption {
  const _FilterOption(this.label, [this.icon]);

  final String label;

  /// SVG file name in `assets/icons` (without extension), if any.
  final String? icon;
}

class _AnnouncementList extends StatelessWidget {
  const _AnnouncementList({required this.onTap});

  final ValueChanged<Announcement> onTap;

  static const List<Announcement> _items = [
    Announcement(
      author: 'Dr. Mensah',
      time: '9:41 AM',
      tag: 'Highly prior',
      tagColor: SlackColors.tagUrgent,
      unread: true,
      body:
          'Good morning. The Csc 200 lab report is due this Friday — please '
          'submit before 5:00 PM. Late submissions will not be graded.',
    ),
    Announcement(
      author: 'Course Rep',
      time: '8:15 AM',
      tag: 'General announcement',
      tagColor: SlackColors.tagInfo,
      unread: true,
      body:
          "Today's lecture has been moved to the main auditorium. We start at "
          '10:00 AM instead, so no need to rush for the 8 o\'clock slot.',
    ),
    Announcement(
      author: 'Prof. Adeyemi',
      time: 'Yesterday',
      tag: 'Less prior',
      tagColor: SlackColors.tagMuted,
      body:
          'Continuous assessment scores are out. Check the department notice '
          'board for your marks and reach out if anything looks off.',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        for (var i = 0; i < _items.length; i++) ...[
          if (i > 0)
            const Divider(
              height: 1,
              thickness: 1,
              color: SlackColors.darkBorder,
            ),
          _AnnouncementTile(
            key: ValueKey('announcement-$i'),
            announcement: _items[i],
            onTap: () => onTap(_items[i]),
          ),
        ],
      ],
    );
  }
}

class _AnnouncementTile extends StatelessWidget {
  const _AnnouncementTile({
    super.key,
    required this.announcement,
    required this.onTap,
  });

  final Announcement announcement;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ClipOval(
                child: Image.asset(
                  'assets/launch_icon_foreground.png',
                  width: 40,
                  height: 40,
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
                        Expanded(
                          child: Text(
                            announcement.author,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: AppType.name(scheme),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(announcement.time, style: AppType.meta(scheme)),
                        if (announcement.unread) ...[
                          const SizedBox(width: 6),
                          Container(
                            width: 8,
                            height: 8,
                            decoration: const BoxDecoration(
                              color: SlackColors.accentGreen,
                              shape: BoxShape.circle,
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 4),
                    _TagBadge(
                      label: announcement.tag,
                      color: announcement.tagColor,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      announcement.body,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppType.body(scheme),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Small coloured priority label shown under the sender's name.
class _TagBadge extends StatelessWidget {
  const _TagBadge({required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Text(label, style: AppType.tag(color));
  }
}

/// The Trending section: a heading with a "Show more" action over a
/// horizontally scrolling row of cards.
class _TrendingSection extends StatelessWidget {
  const _TrendingSection({required this.onShowMore});

  final VoidCallback onShowMore;

  static const List<_TrendingItem> _items = [
    _TrendingItem(
      image: 'assets/background.jpeg',
      title: 'Matriculation',
      subtitle: 'Campus · Main hall',
    ),
    _TrendingItem(
      image: 'assets/background-2.jpeg',
      title: 'Library hours',
      subtitle: 'Extended to 10 PM',
    ),
    _TrendingItem(
      image: 'assets/background-3.jpeg',
      title: 'Sports week',
      subtitle: 'Kicks off Monday',
    ),
    _TrendingItem(
      image: 'assets/background.jpeg',
      title: 'Hostel ballot',
      subtitle: 'Closes Friday',
    ),
    _TrendingItem(
      image: 'assets/background-2.jpeg',
      title: 'Career fair',
      subtitle: 'Alumni networks',
    ),
    _TrendingItem(
      image: 'assets/background-3.jpeg',
      title: 'Exam timetable',
      subtitle: 'Now published',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 6, 8, 4),
          child: Row(
            children: [
              const SectionHeading('Trending'),
              const Spacer(),
              GestureDetector(
                key: const ValueKey('trending-show-more'),
                onTap: onShowMore,
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  child: Text(
                    'Show more',
                    style: TextStyle(
                      fontFamily: AppTheme.fontFamily,
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: SlackColors.accentGreen,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
        SizedBox(
          height: 150,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemCount: _items.length,
            separatorBuilder: (_, _) => const SizedBox(width: 12),
            itemBuilder: (context, i) =>
                _TrendingCard(key: ValueKey('trending-$i'), item: _items[i]),
          ),
        ),
      ],
    );
  }
}

class _TrendingItem {
  const _TrendingItem({
    required this.image,
    required this.title,
    required this.subtitle,
  });

  final String image;
  final String title;
  final String subtitle;
}

class _TrendingCard extends StatelessWidget {
  const _TrendingCard({super.key, required this.item});

  final _TrendingItem item;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return SizedBox(
      width: 150,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: Image.asset(
              item.image,
              width: 150,
              height: 96,
              fit: BoxFit.cover,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            item.title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: AppType.name(scheme),
          ),
          const SizedBox(height: 2),
          Text(
            item.subtitle,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: AppType.subtitle(scheme),
          ),
        ],
      ),
    );
  }
}

/// The Upcoming Activities section: a heading over a Spotify-style two-column
/// grid of compact activity cards.
class _UpcomingActivitiesSection extends StatelessWidget {
  const _UpcomingActivitiesSection();

  static const List<_ActivityItem> _items = [
    _ActivityItem('Matriculation', 'Mon, 20 Oct'),
    _ActivityItem('Sports Week', 'Tue, 21 Oct'),
    _ActivityItem('Career Fair', 'Wed, 22 Oct'),
    _ActivityItem('Hostel Ballot', 'Thu, 23 Oct'),
    _ActivityItem('Library Tour', 'Fri, 24 Oct'),
    _ActivityItem('Exam Timetable', 'Sat, 25 Oct'),
  ];

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.fromLTRB(16, 6, 16, 12),
          child: SectionHeading('Upcoming Activities'),
        ),
        GridView.builder(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: _items.length,
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            crossAxisSpacing: 10,
            mainAxisSpacing: 10,
            mainAxisExtent: 56,
          ),
          itemBuilder: (context, i) =>
              _ActivityCard(key: ValueKey('activity-$i'), item: _items[i]),
        ),
      ],
    );
  }
}

/// A single upcoming activity: a title and its date.
class _ActivityItem {
  const _ActivityItem(this.title, this.date);

  final String title;
  final String date;
}

/// Compact activity card with a leading theme-coloured sidebar, mirroring the
/// colour of the workspace app bar.
class _ActivityCard extends StatelessWidget {
  const _ActivityCard({super.key, required this.item});

  final _ActivityItem item;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: SlackColors.darkHeader,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(
            width: 2,
            child: ColoredBox(color: SlackColors.accentGreen),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppType.name(scheme),
                ),
                const SizedBox(height: 2),
                Text(
                  item.date,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppType.subtitle(scheme),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
        ],
      ),
    );
  }
}

/// Shown for filters that have no announcements yet.
class _EmptyFeed extends StatelessWidget {
  const _EmptyFeed();

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SvgPicture.asset(
            'assets/icons/updates.svg',
            width: 40,
            height: 40,
            colorFilter: ColorFilter.mode(
              scheme.onSurfaceVariant,
              BlendMode.srcIn,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            'Nothing here yet',
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

/// Twitter-style expandable compose button.
///
/// Tapping the add button rotates it 45° into a close icon while a stack of
/// quick actions is revealed above it.
class _ComposeFab extends StatefulWidget {
  const _ComposeFab();

  @override
  State<_ComposeFab> createState() => _ComposeFabState();
}

class _ComposeFabState extends State<_ComposeFab>
    with SingleTickerProviderStateMixin {
  static const List<({String label, IconData icon})> _actions = [
    (label: 'New Announcement', icon: Icons.campaign_outlined),
    (label: 'Post Trends', icon: Icons.trending_up),
    (label: 'Add Activity', icon: Icons.event_available_outlined),
  ];

  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 280),
  );

  late final List<CurvedAnimation> _reveals = [
    for (var i = 0; i < _actions.length; i++)
      CurvedAnimation(
        parent: _controller,
        curve: Interval(
          (_actions.length - 1 - i) * 0.12,
          0.7 + (_actions.length - 1 - i) * 0.12,
          curve: Curves.easeOutCubic,
        ),
      ),
  ];

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _toggle() {
    if (_controller.isForwardOrCompleted) {
      _controller.reverse();
    } else {
      _controller.forward();
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        final t = _controller.value;
        final showActions = _controller.status != AnimationStatus.dismissed;

        return Stack(
          children: [
            if (t > 0)
              Positioned.fill(
                child: GestureDetector(
                  onTap: _toggle,
                  child: ClipRect(
                    child: BackdropFilter(
                      filter: ImageFilter.blur(sigmaX: 10 * t, sigmaY: 10 * t),
                      child: ColoredBox(
                        color: Colors.black.withValues(alpha: 0.4 * t),
                      ),
                    ),
                  ),
                ),
              ),
            Positioned(
              right: 16,
              bottom: 16,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  if (showActions)
                    for (var i = 0; i < _actions.length; i++)
                      _ComposeAction(
                        label: _actions[i].label,
                        icon: _actions[i].icon,
                        animation: _reveals[i],
                      ),
                  GestureDetector(
                    onTap: _toggle,
                    child: Container(
                      width: 56,
                      height: 56,
                      decoration: BoxDecoration(
                        color: scheme.primary,
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.3),
                            blurRadius: 12,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Transform.rotate(
                        angle: _controller.value * math.pi / 4,
                        child: const Icon(
                          Icons.add,
                          color: Colors.white,
                          size: 28,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }
}

/// A single revealed action of [_ComposeFab]: a label chip plus a round icon.
class _ComposeAction extends StatelessWidget {
  const _ComposeAction({
    required this.label,
    required this.icon,
    required this.animation,
  });

  final String label;
  final IconData icon;
  final Animation<double> animation;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return SizeTransition(
      sizeFactor: animation,
      alignment: Alignment.bottomLeft,
      child: FadeTransition(
        opacity: animation,
        child: Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: SlackColors.darkSurface,
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(label, style: AppType.subtitle(scheme)),
              ),
              const SizedBox(width: 10),
              Container(
                width: 44,
                height: 44,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: SlackColors.darkSurface,
                  shape: BoxShape.circle,
                  border: Border.all(color: SlackColors.darkBorder),
                ),
                child: Icon(icon, size: 20, color: scheme.onSurfaceVariant),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
