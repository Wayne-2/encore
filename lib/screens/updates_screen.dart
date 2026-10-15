import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../models/announcement.dart';
import '../navigation/app_route.dart';
import '../theme/app_theme.dart';
import '../theme/slack_colors.dart';
import 'announcement_detail_screen.dart';
import 'trending_more_screen.dart';

/// The Updates section — the first tab of [HomeShell].
///
/// Opens with a Slack-style workspace bar, an Announcement feed that can be
/// filtered with All / Unread / Urgent / Older pills, and a Trending row.
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
    return Column(
      children: [
        const _UpdatesAppBar(heading: 'Update', title: 'Csc 200 level'),
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
              if (_filter == 0)
                _AnnouncementList(onTap: (a) => _openAnnouncement(context, a))
              else
                const SizedBox(height: 160, child: _EmptyFeed()),
              const SizedBox(height: 4),
              _TrendingSection(onShowMore: () => _openTrending(context)),
              const SizedBox(height: 16),
            ],
          ),
        ),
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

/// Slack-style workspace bar for the Updates section.
class _UpdatesAppBar extends StatelessWidget {
  const _UpdatesAppBar({required this.heading, required this.title});

  final String heading;
  final String title;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Container(
      height: 64 + MediaQuery.of(context).padding.top,
      color: SlackColors.darkHeader,
      padding: EdgeInsets.only(
        top: MediaQuery.of(context).padding.top,
        left: 16,
        right: 16,
      ),
      child: Row(
        children: [
          SvgPicture.asset(
            'assets/icons/anchor.svg',
            width: 22,
            height: 22,
            colorFilter: ColorFilter.mode(scheme.onSurface, BlendMode.srcIn),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  heading,
                  style: TextStyle(
                    fontFamily: AppTheme.fontFamily,
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: scheme.onSurface,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  title,
                  style: TextStyle(
                    fontFamily: AppTheme.fontFamily,
                    fontSize: 13,
                    fontWeight: FontWeight.w400,
                    color: scheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          Image.asset(
            'assets/Encore.png',
            width: 38,
            height: 38,
            filterQuality: FilterQuality.medium,
          ),
        ],
      ),
    );
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
          Text(
            '#',
            style: TextStyle(
              fontFamily: AppTheme.fontFamily,
              fontSize: 20,
              fontWeight: FontWeight.w700,
              height: 1,
              color: scheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(width: 8),
          Text(
            'Announcement',
            style: TextStyle(
              fontFamily: AppTheme.fontFamily,
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: scheme.onSurface,
            ),
          ),
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
        for (var i = 0; i < _items.length; i++)
          _AnnouncementTile(
            key: ValueKey('announcement-$i'),
            announcement: _items[i],
            onTap: () => onTap(_items[i]),
          ),
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
                            style: TextStyle(
                              fontFamily: AppTheme.fontFamily,
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              color: scheme.onSurfaceVariant,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          announcement.time,
                          style: TextStyle(
                            fontFamily: AppTheme.fontFamily,
                            fontSize: 12,
                            fontWeight: FontWeight.w400,
                            color: scheme.onSurfaceVariant,
                          ),
                        ),
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
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontFamily: AppTheme.fontFamily,
                        fontSize: 13,
                        height: 1.35,
                        color: scheme.onSurfaceVariant,
                      ),
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
    return Text(
      label,
      style: TextStyle(
        fontFamily: AppTheme.fontFamily,
        fontSize: 11,
        fontWeight: FontWeight.w600,
        color: color,
      ),
    );
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
    final scheme = Theme.of(context).colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 6, 8, 4),
          child: Row(
            children: [
              Text(
                'Trending',
                style: TextStyle(
                  fontFamily: AppTheme.fontFamily,
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: scheme.onSurface,
                ),
              ),
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
            style: TextStyle(
              fontFamily: AppTheme.fontFamily,
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: scheme.onSurface,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            item.subtitle,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontFamily: AppTheme.fontFamily,
              fontSize: 11,
              fontWeight: FontWeight.w400,
              color: scheme.onSurfaceVariant,
            ),
          ),
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
