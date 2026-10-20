import 'package:flutter/material.dart';

import '../data/departments.dart';
import '../models/announcement.dart';
import '../models/trend.dart';
import '../navigation/app_route.dart';
import '../services/announcement_store.dart';
import '../services/auth_service.dart';
import '../services/notification_service.dart';
import '../theme/app_spacing.dart';
import '../theme/app_theme.dart';
import '../theme/app_type.dart';
import '../theme/slack_type.dart';
import '../theme/spotify_colors.dart';
import '../widgets/announcement_tile.dart';
import '../widgets/compose_announcement_sheet.dart';
import '../widgets/compose_fab.dart';
import '../widgets/section_heading.dart';
import '../widgets/shimmer.dart';
import '../widgets/workspace_app_bar.dart';
import 'announcement_detail_screen.dart';
import 'announcements_screen.dart';
import 'trending_detail_screen.dart';
import 'trending_more_screen.dart';

/// Quick actions revealed by the Updates compose button.
const List<ComposeAction> _updatesComposeActions = [
  (label: 'New Announcement', icon: Icons.campaign_outlined),
  (label: 'Post Trends', icon: Icons.trending_up),
  (label: 'Add Activity', icon: Icons.event_available_outlined),
];

/// The workspace bar, with the title and avatar sourced from the signed-in
/// user's Firestore profile (falling back to the design defaults).
class _UpdatesWorkspaceBar extends StatefulWidget {
  const _UpdatesWorkspaceBar();

  @override
  State<_UpdatesWorkspaceBar> createState() => _UpdatesWorkspaceBarState();
}

class _UpdatesWorkspaceBarState extends State<_UpdatesWorkspaceBar> {
  Stream<Map<String, dynamic>?>? _profile;

  @override
  void initState() {
    super.initState();
    if (AuthService.isAvailable) {
      _profile = AuthService.instance.currentUserProfileStream();
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_profile == null) {
      return const WorkspaceAppBar(heading: 'Update', title: 'Csc 200 level');
    }

    return StreamBuilder<Map<String, dynamic>?>(
      stream: _profile,
      builder: (context, snapshot) {
        final data = snapshot.data;
        final department = (data?['department'] as String?)?.trim();
        final level = (data?['level'] as String?)?.trim();
        final photoUrl = (data?['photoUrl'] as String?)?.trim();

        final title =
            (department?.isNotEmpty == true && level?.isNotEmpty == true)
            ? '${normalizeDepartment(department!)} $level'
            : 'Csc 200 level';

        return WorkspaceAppBar(
          heading: 'Update',
          title: title,
          trailing: (photoUrl == null || photoUrl.isEmpty)
              ? null
              : ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: Image.network(
                    photoUrl,
                    width: 38,
                    height: 38,
                    fit: BoxFit.cover,
                    filterQuality: FilterQuality.medium,
                    errorBuilder: (_, _, _) => Image.asset(
                      'assets/Encore.png',
                      width: 38,
                      height: 38,
                      filterQuality: FilterQuality.medium,
                    ),
                  ),
                ),
        );
      },
    );
  }
}

/// The Updates section — the first tab of [HomeShell].
///
/// Opens with a workspace bar, a Slack-style Announcement feed, then
/// Spotify-style Trending and Upcoming Activities carousels.
class UpdatesScreen extends StatefulWidget {
  const UpdatesScreen({super.key});

  @override
  State<UpdatesScreen> createState() => _UpdatesScreenState();
}

class _UpdatesScreenState extends State<UpdatesScreen> {
  /// How long the skeleton state is shown on first open. Replace this with the
  /// real Firestore load when the feeds are wired up.
  static const _skeletonDuration = Duration(milliseconds: 900);

  final _scrollController = ScrollController();

  bool _loading = AuthService.isAvailable;

  @override
  void initState() {
    super.initState();
    AnnouncementStore.instance.listen();
    if (_loading) {
      Future<void>.delayed(_skeletonDuration, () {
        if (mounted) setState(() => _loading = false);
      });
    }
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Column(
          children: [
            const _UpdatesWorkspaceBar(),
            Expanded(
              child: ListView(
                key: const ValueKey('updates-scroll'),
                controller: _scrollController,
                padding: EdgeInsets.zero,
                children: [
                  _AnnouncementHeader(
                    onMore: () => _openAnnouncements(context),
                  ),
                  if (_loading)
                    const _AnnouncementSkeletonList()
                  else
                    _AnnouncementList(
                      onTap: (a) => _openAnnouncement(context, a),
                    ),
                  const SizedBox(height: AppSpacing.section),
                  _TrendingSection(
                    loading: _loading,
                    onShowMore: () => _openTrending(context),
                  ),
                  const SizedBox(height: AppSpacing.section),
                  _UpcomingActivitiesSection(loading: _loading),
                  const SizedBox(height: AppSpacing.section),
                ],
              ),
            ),
          ],
        ),
        Positioned.fill(
          child: ComposeFab(
            actions: _updatesComposeActions,
            onActionSelected: (action) {
              if (action.label == 'New Announcement') {
                _composeAnnouncement(context);
              }
            },
          ),
        ),
      ],
    );
  }

  Future<void> _composeAnnouncement(BuildContext context) async {
    final draft = await showComposeAnnouncementSheet(
      context,
      author: AuthService.isAvailable
          ? AuthService.instance.currentUser?.displayName
          : null,
    );
    if (draft == null) return;

    AnnouncementStore.instance.post(
      author: draft.author,
      authorId: draft.authorId,
      photoUrl: draft.photoUrl,
      department: draft.department,
      level: draft.level,
      tag: draft.tag,
      tagColor: draft.tagColor,
      body: draft.body,
    );

    // Reveal the new post at the top of the feed so its entrance animation is
    // visible even when the user had scrolled down.
    if (_scrollController.hasClients) {
      _scrollController.animateTo(
        0,
        duration: const Duration(milliseconds: 380),
        curve: Curves.easeOutCubic,
      );
    }

    NotificationService.instance.showNewAnnouncement(
      author: draft.author,
      priority: draft.tag,
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

/// Section header: `# Announcement` in Slack's list-header style with a
/// trailing "Show more" action.
class _AnnouncementHeader extends StatelessWidget {
  const _AnnouncementHeader({required this.onMore});

  final VoidCallback onMore;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Padding(
      padding: const EdgeInsets.fromLTRB(AppSpacing.page, 16, 8, 0),
      child: Row(
        children: [
          SectionHeading(
            'Announcement',
            style: SlackType.sectionTitle(scheme),
            glyphStyle: SlackType.glyph(scheme),
          ),
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
                  color: SpotifyColors.accent,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _AnnouncementList extends StatefulWidget {
  const _AnnouncementList({required this.onTap});

  final ValueChanged<Announcement> onTap;

  @override
  State<_AnnouncementList> createState() => _AnnouncementListState();
}

class _AnnouncementListState extends State<_AnnouncementList> {
  /// Measured height of an [AnnouncementTile] with a two-line body (the
  /// tallest case) at the default text scale.
  static const double _tileHeight = 103;

  /// Two dividers sit between the three slots.
  static const double _sectionHeight = _tileHeight * 3 + 2;

  final Set<String> _seenIds = {};
  bool _primed = false;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: AnnouncementStore.instance,
      builder: (context, _) {
        final items = AnnouncementStore.instance.items.take(3).toList();

        // Announcements that already exist on the first build appear without
        // animation; only posts created afterwards get the entrance treatment.
        if (!_primed) {
          _seenIds.addAll(items.map((a) => a.id));
          _primed = true;
        }

        if (items.isEmpty) {
          return ConstrainedBox(
            key: const ValueKey('announcement-section'),
            constraints: const BoxConstraints(minHeight: _sectionHeight),
            child: const _AnnouncementEmptyState(),
          );
        }

        final children = <Widget>[];
        for (var i = 0; i < items.length; i++) {
          final item = items[i];
          final isNew = !_seenIds.contains(item.id);

          if (i > 0) {
            children.add(
              const Divider(
                height: 1,
                thickness: 1,
                color: SpotifyColors.border,
              ),
            );
          }

          children.add(
            _AnimatedAnnouncementEntry(
              key: ValueKey(item.id.isEmpty ? item : item.id),
              animate: isNew,
              child: AnnouncementTile(
                key: ValueKey('announcement-$i'),
                announcement: item,
                onTap: () {
                  AnnouncementStore.instance.markRead(item);
                  widget.onTap(item);
                },
              ),
            ),
          );
        }

        _seenIds.addAll(items.map((a) => a.id));

        return ConstrainedBox(
          key: const ValueKey('announcement-section'),
          constraints: const BoxConstraints(minHeight: _sectionHeight),
          child: Column(children: children),
        );
      },
    );
  }
}

/// Slides, fades and expands a freshly posted announcement into the feed,
/// finishing with a brief accent glow.
class _AnimatedAnnouncementEntry extends StatefulWidget {
  const _AnimatedAnnouncementEntry({
    super.key,
    required this.child,
    this.animate = false,
  });

  final Widget child;
  final bool animate;

  @override
  State<_AnimatedAnnouncementEntry> createState() =>
      _AnimatedAnnouncementEntryState();
}

class _AnimatedAnnouncementEntryState extends State<_AnimatedAnnouncementEntry>
    with SingleTickerProviderStateMixin {
  static const _duration = Duration(milliseconds: 560);

  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: _duration,
  );

  late final Animation<double> _size = CurvedAnimation(
    parent: _controller,
    curve: const Interval(0, 0.78, curve: Curves.easeOutCubic),
  );

  late final Animation<double> _fade = CurvedAnimation(
    parent: _controller,
    curve: const Interval(0.08, 0.62, curve: Curves.easeOut),
  );

  late final Animation<Offset> _slide =
      Tween<Offset>(begin: const Offset(0, 0.12), end: Offset.zero).animate(
        CurvedAnimation(
          parent: _controller,
          curve: const Interval(0.12, 0.9, curve: Curves.easeOutCubic),
        ),
      );

  late final Animation<double> _scale = Tween<double>(begin: 0.985, end: 1)
      .animate(
        CurvedAnimation(
          parent: _controller,
          curve: const Interval(0.1, 0.72, curve: Curves.easeOutBack),
        ),
      );

  late final Animation<double> _glow = Tween<double>(begin: 1, end: 0).animate(
    CurvedAnimation(
      parent: _controller,
      curve: const Interval(0.3, 1, curve: Curves.easeOut),
    ),
  );

  @override
  void initState() {
    super.initState();
    if (widget.animate) {
      _controller.forward();
    } else {
      _controller.value = 1;
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizeTransition(
      sizeFactor: _size,
      alignment: Alignment.topCenter,
      child: FadeTransition(
        opacity: _fade,
        child: SlideTransition(
          position: _slide,
          child: ScaleTransition(
            scale: _scale,
            child: AnimatedBuilder(
              animation: _glow,
              child: widget.child,
              builder: (context, child) => DecoratedBox(
                decoration: BoxDecoration(
                  color: SpotifyColors.accent.withValues(
                    alpha: 0.09 * _glow.value,
                  ),
                ),
                child: child,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Shown when the feed has no announcements.
class _AnnouncementEmptyState extends StatelessWidget {
  const _AnnouncementEmptyState();

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.page),
      child: Center(
        child: Text(
          'No announcement posted yet',
          style: AppType.subtitle(scheme),
        ),
      ),
    );
  }
}

class _TrendingSection extends StatelessWidget {
  const _TrendingSection({required this.onShowMore, required this.loading});

  final VoidCallback onShowMore;
  final bool loading;

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
    final scheme = Theme.of(context).colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.page,
            6,
            8,
            AppSpacing.heading,
          ),
          child: Row(
            children: [
              SectionHeading(
                'Trending',
                style: SlackType.sectionTitle(scheme),
                glyphStyle: SlackType.glyph(scheme),
              ),
              const Spacer(),
              GestureDetector(
                key: const ValueKey('trending-show-more'),
                onTap: onShowMore,
                child: const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  child: Text(
                    'Show more',
                    style: TextStyle(
                      fontFamily: AppTheme.fontFamily,
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: SpotifyColors.accent,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
        if (loading)
          const _TrendingSkeletonRow()
        else
          SizedBox(
            height: 200,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.page),
              itemCount: _items.length,
              separatorBuilder: (_, _) =>
                  const SizedBox(width: AppSpacing.card),
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

/// A single trending card: square cover art over a title and descriptor.
class _TrendingCard extends StatelessWidget {
  const _TrendingCard({super.key, required this.item, required this.onTap});

  final Trend item;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return _MediaTile(
      art: ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: Image.asset(
          item.image,
          width: 150,
          height: 150,
          fit: BoxFit.cover,
        ),
      ),
      title: item.title,
      subtitle: item.subtitle,
      onTap: onTap,
    );
  }
}

/// The Upcoming Activities section: a heading over a two-column grid of
/// compact activity cards.
class _UpcomingActivitiesSection extends StatelessWidget {
  const _UpcomingActivitiesSection({required this.loading});

  final bool loading;

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
    final scheme = Theme.of(context).colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 6, 16, 12),
          child: SectionHeading(
            'Upcoming Activities',
            style: SlackType.sectionTitle(scheme),
            glyphStyle: SlackType.glyph(scheme),
          ),
        ),
        GridView.builder(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: loading ? 6 : _items.length,
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            crossAxisSpacing: 10,
            mainAxisSpacing: 10,
            mainAxisExtent: 56,
          ),
          itemBuilder: (context, i) => loading
              ? _ActivitySkeletonCard(key: ValueKey('activity-skeleton-$i'))
              : _ActivityCard(key: ValueKey('activity-$i'), item: _items[i]),
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
        color: SpotifyColors.surface,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(
            width: 2,
            child: ColoredBox(color: SpotifyColors.accent),
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

/// A Spotify-style carousel tile: square art over a bold title and a muted
/// subtitle, shared by the Trending and Upcoming Activities sections.
class _MediaTile extends StatelessWidget {
  const _MediaTile({
    required this.art,
    required this.title,
    required this.subtitle,
    this.onTap,
  });

  final Widget art;
  final String title;
  final String subtitle;
  final VoidCallback? onTap;

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
              art,
              const SizedBox(height: AppSpacing.artText),
              Text(
                title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppType.cardTitle(scheme),
              ),
              const SizedBox(height: AppSpacing.text),
              Text(
                subtitle,
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

// ---------------------------------------------------------------------------
// Loading skeletons
// ---------------------------------------------------------------------------

/// A single shimmering placeholder bar used by the feed skeletons.
Widget _skeletonBar({
  double? width,
  required double height,
  double radius = 4,
}) {
  return Container(
    width: width,
    height: height,
    decoration: BoxDecoration(
      color: SpotifyColors.surfaceHover,
      borderRadius: BorderRadius.circular(radius),
    ),
  );
}

/// Three announcement rows in the loading state.
class _AnnouncementSkeletonList extends StatelessWidget {
  const _AnnouncementSkeletonList();

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        for (var i = 0; i < 3; i++) ...[
          if (i > 0)
            const Divider(height: 1, thickness: 1, color: SpotifyColors.border),
          const _AnnouncementSkeletonTile(),
        ],
      ],
    );
  }
}

/// Mirrors [AnnouncementTile]'s avatar, sender, timestamp, tag and body.
class _AnnouncementSkeletonTile extends StatelessWidget {
  const _AnnouncementSkeletonTile();

  @override
  Widget build(BuildContext context) {
    return Shimmer(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _skeletonBar(width: 36, height: 36),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      _skeletonBar(width: 120, height: 13),
                      const Spacer(),
                      _skeletonBar(width: 32, height: 11),
                    ],
                  ),
                  const SizedBox(height: 8),
                  _skeletonBar(width: 64, height: 11),
                  const SizedBox(height: 8),
                  _skeletonBar(width: double.infinity, height: 12),
                  const SizedBox(height: 6),
                  _skeletonBar(width: 200, height: 12),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// A horizontal row of shimmering trending cards.
class _TrendingSkeletonRow extends StatelessWidget {
  const _TrendingSkeletonRow();

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 200,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        physics: const NeverScrollableScrollPhysics(),
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.page),
        itemCount: 3,
        separatorBuilder: (_, _) => const SizedBox(width: AppSpacing.card),
        itemBuilder: (_, _) => const Shimmer(
          child: SizedBox(
            width: 150,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _SkeletonArt(),
                SizedBox(height: AppSpacing.artText),
                _SkeletonText(width: 110, height: 14),
                SizedBox(height: AppSpacing.text),
                _SkeletonText(width: 80, height: 11),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Mirrors the 56dp activity card in the loading state.
class _ActivitySkeletonCard extends StatelessWidget {
  const _ActivitySkeletonCard({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: SpotifyColors.surface,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(
            width: 2,
            child: ColoredBox(color: SpotifyColors.accent),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Shimmer(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _skeletonBar(width: 92, height: 12),
                  const SizedBox(height: 6),
                  _skeletonBar(width: 60, height: 10),
                ],
              ),
            ),
          ),
          const SizedBox(width: 8),
        ],
      ),
    );
  }
}

/// Const-friendly versions of the shimmer bars for the skeleton widgets.
class _SkeletonArt extends StatelessWidget {
  const _SkeletonArt();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 150,
      height: 150,
      decoration: BoxDecoration(
        color: SpotifyColors.surfaceHover,
        borderRadius: BorderRadius.circular(8),
      ),
    );
  }
}

class _SkeletonText extends StatelessWidget {
  const _SkeletonText({required this.width, required this.height});

  final double width;
  final double height;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: SpotifyColors.surfaceHover,
        borderRadius: BorderRadius.circular(4),
      ),
    );
  }
}
