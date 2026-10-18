import 'package:flutter/material.dart';

import '../data/announcements.dart';
import '../models/announcement.dart';
import '../navigation/app_route.dart';
import '../theme/app_theme.dart';
import '../theme/spotify_colors.dart';
import '../widgets/announcement_tile.dart';
import '../widgets/filter_pills.dart';
import 'announcement_detail_screen.dart';

/// Full list of announcements, opened from the Updates "Show more" action.
/// Shows filter pills: Latest / Unread / Urgent.
class AnnouncementsScreen extends StatefulWidget {
  const AnnouncementsScreen({super.key});

  @override
  State<AnnouncementsScreen> createState() => _AnnouncementsScreenState();
}

class _AnnouncementsScreenState extends State<AnnouncementsScreen> {
  static const List<String> _filters = ['Latest', 'Unread', 'Urgent'];
  int _filter = 0;

  List<Announcement> get _items {
    final all = kAnnouncements;
    return switch (_filter) {
      1 => all.where((a) => a.unread).toList(),
      2 => all.where((a) => a.tag.toLowerCase().contains('high')).toList(),
      _ => List.of(all),
    };
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
          icon: const Icon(Icons.arrow_back_ios_new),
          color: scheme.onSurface,
          onPressed: () => Navigator.of(context).maybePop(),
        ),
        title: Text(
          'Announcements',
          style: TextStyle(
            fontFamily: AppTheme.fontFamily,
            fontSize: 16,
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
            child: _items.isEmpty
                ? const Center(child: _EmptyState())
                : ListView.separated(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    itemCount: _items.length,
                    separatorBuilder: (_, _) => const Divider(
                      height: 1,
                      thickness: 1,
                      color: SpotifyColors.border,
                    ),
                    itemBuilder: (context, i) => AnnouncementTile(
                      key: ValueKey('all-announcement-$i'),
                      announcement: _items[i],
                      onTap: () => Navigator.of(context).push(
                        fadeRoute(
                          AnnouncementDetailScreen(announcement: _items[i]),
                        ),
                      ),
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Center(
      child: Text(
        'Nothing here yet',
        style: TextStyle(
          fontFamily: AppTheme.fontFamily,
          fontSize: 14,
          color: scheme.onSurfaceVariant,
        ),
      ),
    );
  }
}
