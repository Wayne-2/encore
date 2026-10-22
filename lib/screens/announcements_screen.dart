import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../models/announcement.dart';
import '../navigation/app_route.dart';
import '../services/announcement_store.dart';
import '../services/auth_service.dart';
import '../theme/app_theme.dart';
import '../theme/spotify_colors.dart';
import '../widgets/announcement_tile.dart';
import '../widgets/filter_pills.dart';
import '../widgets/floating_empty_state.dart';
import 'announcement_detail_screen.dart';

/// Full list of announcements, opened from the Updates "Show more" action.
/// Shows filter pills: Latest / Unread / Urgent.
class AnnouncementsScreen extends StatefulWidget {
  const AnnouncementsScreen({super.key, this.viewerId});

  /// Overrides the signed-in user when resolving delete permission.
  final String? viewerId;

  @override
  State<AnnouncementsScreen> createState() => _AnnouncementsScreenState();
}

class _AnnouncementsScreenState extends State<AnnouncementsScreen> {
  static const List<String> _filters = ['Latest', 'Unread', 'Urgent'];
  int _filter = 0;

  String? get _viewerId =>
      widget.viewerId ??
      (AuthService.isAvailable ? AuthService.instance.currentUser?.uid : null);

  @override
  void initState() {
    super.initState();
    AnnouncementStore.instance.listen();
  }

  List<Announcement> get _items {
    final all = AnnouncementStore.instance.items;
    return switch (_filter) {
      1 => all.where((a) => a.unread).toList(),
      2 => all.where((a) => a.tag.toLowerCase().contains('high')).toList(),
      _ => List.of(all),
    };
  }

  void _open(Announcement announcement) {
    AnnouncementStore.instance.markRead(announcement);
    Navigator.of(
      context,
    ).push(fadeRoute(AnnouncementDetailScreen(announcement: announcement)));
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Scaffold(
      backgroundColor: SpotifyColors.background,
      appBar: AppBar(
        backgroundColor: SpotifyColors.background,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(LucideIcons.chevronLeft),
          color: scheme.onSurface,
          onPressed: () => Navigator.of(context).maybePop(),
        ),
        title: Text(
          'Announcements',
          style: TextStyle(
            fontFamily: AppTheme.fontFamily,
            fontSize: 15,
            fontWeight: FontWeight.w700,
            color: scheme.onSurface,
          ),
        ),
      ),
      body: Column(
        children: [
          const SizedBox(height: 4),
          FilterPills(
            filters: _filters,
            selected: _filter,
            onSelected: (i) => setState(() => _filter = i),
          ),
          const SizedBox(height: 4),
          Expanded(
            child: AnimatedBuilder(
              animation: AnnouncementStore.instance,
              builder: (context, _) {
                final items = _items;
                if (items.isEmpty) {
                  return Center(child: _EmptyState(filter: _filter));
                }

                return ListView.separated(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  itemCount: items.length,
                  separatorBuilder: (_, _) => const Divider(
                    height: 1,
                    thickness: 1,
                    color: SpotifyColors.border,
                  ),
                  itemBuilder: (context, i) => AnnouncementTile(
                    key: ValueKey('all-announcement-$i'),
                    announcement: items[i],
                    viewerId: _viewerId,
                    onDelete: AnnouncementStore.instance.delete,
                    onTap: () => _open(items[i]),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.filter});

  final int filter;

  @override
  Widget build(BuildContext context) {
    final message = switch (filter) {
      1 => 'No unread announcements',
      2 => 'No urgent announcements',
      _ => 'No announcement posted yet',
    };

    return FloatingEmptyState(
      key: const ValueKey('announcements-empty'),
      icon: LucideIcons.megaphone,
      message: message,
    );
  }
}
