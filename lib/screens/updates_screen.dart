import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

import '../data/departments.dart';
import '../models/activity.dart';
import '../models/announcement.dart';
import '../models/trend.dart';
import '../navigation/app_route.dart';
import '../services/activity_store.dart';
import '../services/announcement_store.dart';
import '../services/auth_service.dart';
import '../services/notification_service.dart';
import '../services/trend_store.dart';
import '../theme/app_spacing.dart';
import '../theme/app_theme.dart';
import '../theme/app_type.dart';
import '../theme/slack_type.dart';
import '../theme/spotify_colors.dart';
import '../widgets/add_activity_sheet.dart';
import '../widgets/announcement_tile.dart';
import '../widgets/compose_announcement_sheet.dart';
import '../widgets/compose_fab.dart';
import '../widgets/compose_trend_sheet.dart';
import '../widgets/floating_empty_state.dart';
import '../widgets/section_heading.dart';
import '../widgets/shimmer.dart';
import '../widgets/trend_cover.dart';
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
  const _UpdatesWorkspaceBar({
    required this.onRefresh,
    required this.refreshing,
  });

  final VoidCallback onRefresh;
  final bool refreshing;

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
      return WorkspaceAppBar(
        heading: 'Update',
        title: 'Csc 200 level',
        trailing: _barActions(
          const Image(
            image: AssetImage('assets/Encore.png'),
            width: 38,
            height: 38,
            filterQuality: FilterQuality.medium,
          ),
        ),
      );
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
          trailing: _barActions(
            (photoUrl == null || photoUrl.isEmpty)
                ? const Image(
                    image: AssetImage('assets/Encore.png'),
                    width: 38,
                    height: 38,
                    filterQuality: FilterQuality.medium,
                  )
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
          ),
        );
      },
    );
  }

  Widget _barActions(Widget avatar) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        IconButton(
          key: const ValueKey('updates-refresh'),
          tooltip: 'Refresh updates',
          onPressed: widget.refreshing ? null : widget.onRefresh,
          color: SpotifyColors.textSubdued,
          padding: EdgeInsets.zero,
          visualDensity: VisualDensity.compact,
          constraints: const BoxConstraints.tightFor(width: 36, height: 36),
          icon: widget.refreshing
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: SpotifyColors.accent,
                  ),
                )
              : const Icon(Icons.refresh_rounded, size: 21),
        ),
        const SizedBox(width: 8),
        avatar,
      ],
    );
  }
}

/// The Updates section — the first tab of [HomeShell].
///
/// Opens with a workspace bar, a Slack-style Announcement feed, then
/// Spotify-style Trending and Upcoming Activities carousels.
class UpdatesScreen extends StatefulWidget {
  const UpdatesScreen({super.key, this.viewerId});

  /// Overrides the signed-in user when resolving delete permission.
  final String? viewerId;

  @override
  State<UpdatesScreen> createState() => _UpdatesScreenState();
}

class _UpdatesScreenState extends State<UpdatesScreen> {
  /// How long the skeleton state is shown on first open. Replace this with the
  /// real Firestore load when the feeds are wired up.
  static const _skeletonDuration = Duration(milliseconds: 900);

  final _scrollController = ScrollController();
  final _trendingKey = GlobalKey();
  final _activitiesKey = GlobalKey();

  bool _loading = AuthService.isAvailable;
  bool _refreshing = false;

  String? get _viewerId =>
      widget.viewerId ??
      (AuthService.isAvailable ? AuthService.instance.currentUser?.uid : null);

  @override
  void initState() {
    super.initState();
    AnnouncementStore.instance.listen();
    TrendStore.instance.listen();
    ActivityStore.instance.listen();
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
            _UpdatesWorkspaceBar(onRefresh: _refresh, refreshing: _refreshing),
            Expanded(
              child: RefreshIndicator(
                key: const ValueKey('updates-refresh-indicator'),
                onRefresh: _refresh,
                color: SpotifyColors.accent,
                backgroundColor: SpotifyColors.surface,
                child: ListView(
                  key: const ValueKey('updates-scroll'),
                  controller: _scrollController,
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: EdgeInsets.zero,
                  children: [
                    _AnnouncementHeader(
                      onMore: () => _openAnnouncements(context),
                    ),
                    if (_loading)
                      const _AnnouncementSkeletonList()
                    else
                      _AnnouncementList(
                        viewerId: _viewerId,
                        onDelete: AnnouncementStore.instance.delete,
                        onTap: (a) => _openAnnouncement(context, a),
                      ),
                    const SizedBox(height: AppSpacing.section),
                    _TrendingSection(
                      key: _trendingKey,
                      loading: _loading,
                      onShowMore: () => _openTrending(context),
                    ),
                    const SizedBox(height: AppSpacing.section),
                    _UpcomingActivitiesSection(
                      key: _activitiesKey,
                      loading: _loading,
                      viewerId: _viewerId,
                      onDelete: ActivityStore.instance.delete,
                    ),
                    const SizedBox(height: AppSpacing.section),
                  ],
                ),
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
              } else if (action.label == 'Post Trends') {
                _composeTrend(context);
              } else if (action.label == 'Add Activity') {
                _addActivity(context);
              }
            },
          ),
        ),
      ],
    );
  }

  Future<void> _refresh() async {
    if (_refreshing) return;
    setState(() => _refreshing = true);
    await Future.wait([
      AnnouncementStore.instance.refresh(),
      TrendStore.instance.refresh(),
      ActivityStore.instance.refresh(),
    ]);
    if (mounted) setState(() => _refreshing = false);
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

  Future<void> _composeTrend(BuildContext context) async {
    final draft = await showComposeTrendSheet(context);
    if (draft == null) return;

    var author = AuthService.isAvailable
        ? AuthService.instance.currentUser?.displayName
        : null;
    if (AuthService.isAvailable) {
      try {
        final profile = await AuthService.instance.currentUserProfile();
        final fullName = (profile?['fullName'] as String?)?.trim();
        if (fullName != null && fullName.isNotEmpty) author = fullName;
      } catch (_) {
        // Fall back to the Firebase Auth display name.
      }
    }

    TrendStore.instance.post(
      title: draft.title,
      body: draft.body,
      author: author ?? 'You',
      media: draft.media,
    );

    // Bring the new card into view if the user was scrolled elsewhere.
    if (!mounted) return;
    final trendingContext = _trendingKey.currentContext;
    if (trendingContext != null && trendingContext.mounted) {
      await Scrollable.ensureVisible(
        trendingContext,
        duration: const Duration(milliseconds: 380),
        curve: Curves.easeOutCubic,
        alignment: 0.1,
      );
    }
  }

  Future<void> _addActivity(BuildContext context) async {
    final draft = await showAddActivitySheet(context);
    if (draft == null) return;

    ActivityStore.instance.add(title: draft.title, date: draft.date);

    // Bring the activities grid into view after adding.
    if (!mounted) return;
    final activitiesContext = _activitiesKey.currentContext;
    if (activitiesContext != null && activitiesContext.mounted) {
      await Scrollable.ensureVisible(
        activitiesContext,
        duration: const Duration(milliseconds: 380),
        curve: Curves.easeOutCubic,
        alignment: 0.4,
      );
    }
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
  const _AnnouncementList({
    required this.onTap,
    required this.onDelete,
    this.viewerId,
  });

  final ValueChanged<Announcement> onTap;
  final ValueChanged<Announcement> onDelete;
  final String? viewerId;

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
                viewerId: widget.viewerId,
                onDelete: widget.onDelete,
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
    return const Center(
      child: FloatingEmptyState(
        key: ValueKey('announcement-empty'),
        icon: Icons.campaign_outlined,
        message: 'No announcement posted yet',
      ),
    );
  }
}

class _TrendingSection extends StatelessWidget {
  const _TrendingSection({
    super.key,
    required this.onShowMore,
    required this.loading,
  });

  final VoidCallback onShowMore;
  final bool loading;

  /// Height reserved for the row, kept even when there are no trends.
  static const double _height = 200;

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
        SizedBox(
          key: const ValueKey('trending-section'),
          height: _height,
          child: AnimatedBuilder(
            animation: TrendStore.instance,
            builder: (context, _) {
              if (loading) return const _TrendingSkeletonRow();

              final items = TrendStore.instance.items;
              if (items.isEmpty) return const _TrendingEmptyState();

              return ListView.separated(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.page,
                ),
                itemCount: items.length,
                separatorBuilder: (_, _) =>
                    const SizedBox(width: AppSpacing.card),
                itemBuilder: (context, i) => _TrendingCard(
                  key: ValueKey('trending-$i'),
                  item: items[i],
                  onTap: () => Navigator.of(
                    context,
                  ).push(fadeRoute(TrendingDetailScreen(trend: items[i]))),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}

/// Shown in place of the row when nothing has been posted yet.
class _TrendingEmptyState extends StatelessWidget {
  const _TrendingEmptyState();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: FloatingEmptyState(
        key: ValueKey('trending-empty'),
        icon: Icons.trending_up,
        message: 'No Trending news available',
      ),
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
      art: TrendCover(media: item.media, width: 150, height: 150),
      title: item.title,
      subtitle: item.subtitle,
      onTap: onTap,
    );
  }
}

/// The Upcoming Activities section: a heading over a two-column grid of
/// compact activity cards.
class _UpcomingActivitiesSection extends StatelessWidget {
  const _UpcomingActivitiesSection({
    super.key,
    required this.loading,
    required this.viewerId,
    required this.onDelete,
  });

  final bool loading;
  final String? viewerId;
  final ValueChanged<Activity> onDelete;

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
        AnimatedBuilder(
          animation: ActivityStore.instance,
          builder: (context, _) {
            if (loading) {
              return GridView.builder(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: 6,
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  crossAxisSpacing: 10,
                  mainAxisSpacing: 10,
                  mainAxisExtent: 56,
                ),
                itemBuilder: (context, i) => _ActivitySkeletonCard(
                  key: ValueKey('activity-skeleton-$i'),
                ),
              );
            }

            final items = ActivityStore.instance.items;
            if (items.isEmpty) {
              return const SizedBox(
                height: 150,
                child: Center(
                  child: FloatingEmptyState(
                    key: ValueKey('activity-empty'),
                    icon: Icons.event_available_outlined,
                    message: 'No upcoming activities yet',
                  ),
                ),
              );
            }

            return GridView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: items.length,
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                crossAxisSpacing: 10,
                mainAxisSpacing: 10,
                mainAxisExtent: 56,
              ),
              itemBuilder: (context, i) => _ActivityCard(
                key: ValueKey('activity-$i'),
                item: items[i],
                viewerId: viewerId,
                onDelete: onDelete,
              ),
            );
          },
        ),
      ],
    );
  }
}

/// Compact activity card with a leading theme-coloured sidebar, mirroring the
/// colour of the workspace app bar. Past activities use a grey bar.
///
/// The author can hold the card for 1.5 seconds to highlight it and confirm
/// deletion.
class _ActivityCard extends StatefulWidget {
  const _ActivityCard({
    super.key,
    required this.item,
    required this.viewerId,
    required this.onDelete,
  });

  final Activity item;
  final String? viewerId;
  final ValueChanged<Activity> onDelete;

  @override
  State<_ActivityCard> createState() => _ActivityCardState();
}

class _ActivityCardState extends State<_ActivityCard> {
  static const _holdDuration = Duration(milliseconds: 1500);
  static const _highlightDelay = Duration(milliseconds: 300);

  bool _highlighted = false;
  bool _dialogOpen = false;

  bool get _canDelete => widget.item.canBeDeletedBy(widget.viewerId);

  Future<void> _handleHold() async {
    if (!mounted || _dialogOpen) return;

    setState(() => _highlighted = true);
    await Future<void>.delayed(_highlightDelay);
    if (!mounted) return;

    _dialogOpen = true;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: SpotifyColors.surface,
        title: const Text('Delete activity?'),
        content: Text(
          '"${widget.item.title}" will be removed from Upcoming Activities.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            key: const ValueKey('delete-activity-confirm'),
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    _dialogOpen = false;
    if (!mounted) return;

    if (confirmed == true) {
      widget.onDelete(widget.item);
      if (mounted) setState(() => _highlighted = false);
      return;
    }
    setState(() => _highlighted = false);
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    final card = AnimatedScale(
      scale: _highlighted ? 1.02 : 1,
      duration: const Duration(milliseconds: 180),
      curve: Curves.easeOut,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeOut,
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          color: _highlighted
              ? SpotifyColors.danger.withValues(alpha: 0.12)
              : SpotifyColors.surface,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: _highlighted
                ? SpotifyColors.danger.withValues(alpha: 0.8)
                : Colors.transparent,
          ),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SizedBox(
              width: 2,
              child: ColoredBox(
                key: ValueKey('activity-bar-${widget.item.id}'),
                color: widget.item.isPast
                    ? SpotifyColors.tagMuted
                    : SpotifyColors.accent,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.item.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppType.cardTitle(scheme),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    widget.item.dateLabel,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppType.subtitle(scheme),
                  ),
                ],
              ),
            ),
            if (_canDelete) ...[
              AnimatedOpacity(
                opacity: _highlighted ? 1 : 0,
                duration: const Duration(milliseconds: 180),
                child: const Icon(
                  Icons.delete_outline,
                  size: 18,
                  color: SpotifyColors.danger,
                ),
              ),
              const SizedBox(width: 8),
            ] else
              const SizedBox(width: 8),
          ],
        ),
      ),
    );

    if (!_canDelete) return card;

    return RawGestureDetector(
      behavior: HitTestBehavior.opaque,
      gestures: {
        LongPressGestureRecognizer:
            GestureRecognizerFactoryWithHandlers<LongPressGestureRecognizer>(
              () => LongPressGestureRecognizer(duration: _holdDuration),
              (recognizer) => recognizer.onLongPress = _handleHold,
            ),
      },
      child: card,
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
