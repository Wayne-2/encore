import 'package:flutter/material.dart';

import '../data/announcements.dart';
import '../models/announcement.dart';
import '../models/trend.dart';
import '../navigation/app_route.dart';
import '../theme/app_theme.dart';
import '../theme/app_type.dart';
import '../theme/slack_colors.dart';
import '../widgets/announcement_tile.dart';
import '../widgets/compose_fab.dart';
import '../widgets/section_heading.dart';
import '../widgets/workspace_app_bar.dart';
import 'announcement_detail_screen.dart';
import 'announcements_screen.dart';
import 'trending_detail_screen.dart';
import 'trending_more_screen.dart';

/// Vertical gap between the Updates page sections.
const double _sectionGap = 18;

/// Quick actions revealed by the Updates compose button.
const List<ComposeAction> _updatesComposeActions = [
  (label: 'New Announcement', icon: Icons.campaign_outlined),
  (label: 'Post Trends', icon: Icons.trending_up),
  (label: 'Add Activity', icon: Icons.event_available_outlined),
];

/// The Updates section — the first tab of [HomeShell].
///
/// Opens with a Slack-style workspace bar, an Announcement feed, a Trending
/// row, and an Upcoming Activities grid.
class UpdatesScreen extends StatelessWidget {
  const UpdatesScreen({super.key});

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
                  _AnnouncementHeader(
                    onMore: () => _openAnnouncements(context),
                  ),
                  _AnnouncementList(
                    onTap: (a) => _openAnnouncement(context, a),
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
        const Positioned.fill(
          child: ComposeFab(actions: _updatesComposeActions),
        ),
      ],
    );
  }

  void _openAnnouncements(BuildContext context) {
    Navigator.of(context).push(fadeRoute(const AnnouncementsScreen()));
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

/// Section header: `# Announcement` with a trailing "Show more" action.
class _AnnouncementHeader extends StatelessWidget {
  const _AnnouncementHeader({required this.onMore});

  final VoidCallback onMore;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 8, 0),
      child: Row(
        children: [
          const SectionHeading('Announcement'),
          const Spacer(),
          GestureDetector(
            key: const ValueKey('announcement-show-more'),
            onTap: onMore,
            child: const Padding(
              padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
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
    );
  }
}

class _AnnouncementList extends StatelessWidget {
  const _AnnouncementList({required this.onTap});

  final ValueChanged<Announcement> onTap;

  static final List<Announcement> _items = kAnnouncements.take(3).toList();

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
          AnnouncementTile(
            key: ValueKey('announcement-$i'),
            announcement: _items[i],
            onTap: () => onTap(_items[i]),
          ),
        ],
      ],
    );
  }
}

class _TrendingSection extends StatelessWidget {
  const _TrendingSection({required this.onShowMore});

  final VoidCallback onShowMore;

  static const List<Trend> _items = [
    Trend(
      image: 'assets/background.jpeg',
      title: 'Matriculation',
      subtitle: 'Campus · Main hall',
      author: 'Campus Desk',
      time: '2h',
      body:
          'Matriculation ceremony holds at the Main Hall this Saturday. '
          'Graduands should be seated by 8:00 AM in full academic dress.',
    ),
    Trend(
      image: 'assets/background-2.jpeg',
      title: 'Library hours',
      subtitle: 'Extended to 10 PM',
      author: 'Library Admin',
      time: '5h',
      body:
          'The main library will now stay open until 10:00 PM on weekdays '
          'through the exam period. Bring your student ID for after-hours '
          'access.',
    ),
    Trend(
      image: 'assets/background-3.jpeg',
      title: 'Sports week',
      subtitle: 'Kicks off Monday',
      author: 'Sports Council',
      time: '1d',
      body:
          'Inter-faculty sports week begins Monday with track events at the '
          'stadium. Registration closes Friday — sign up at the sports office.',
    ),
    Trend(
      image: 'assets/background.jpeg',
      title: 'Hostel ballot',
      subtitle: 'Closes Friday',
      author: 'Housing Office',
      time: '1d',
      body:
          'The hostel room ballot closes this Friday at 6:00 PM. Log in to the '
          'portal to rank your preferred halls before the deadline.',
    ),
    Trend(
      image: 'assets/background-2.jpeg',
      title: 'Career fair',
      subtitle: 'Alumni networks',
      author: 'Career Services',
      time: '2d',
      body:
          'Meet alumni and recruiters at the annual career fair. Bring copies '
          'of your CV and dress smart. Doors open at 9:00 AM.',
    ),
    Trend(
      image: 'assets/background-3.jpeg',
      title: 'Exam timetable',
      subtitle: 'Now published',
      author: 'Exams Office',
      time: '3d',
      body:
          'The end-of-semester examination timetable is now live on the '
          'portal. Cross-check your course codes and report clashes promptly.',
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
            itemBuilder: (context, i) => _TrendingCard(
              key: ValueKey('trending-$i'),
              item: _items[i],
              onTap: () => Navigator.of(
                context,
              ).push(fadeRoute(TrendingDetailScreen(trend: _items[i]))),
            ),
          ),
        ),
      ],
    );
  }
}

/// A single trending card: cover art over a title and short descriptor.
class _TrendingCard extends StatelessWidget {
  const _TrendingCard({super.key, required this.item, required this.onTap});

  final Trend item;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: SizedBox(
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
                style: AppType.cardTitle(scheme),
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
        ),
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
                  style: AppType.cardTitle(scheme),
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
