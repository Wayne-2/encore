import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import '../theme/app_type.dart';
import '../theme/spotify_colors.dart';

/// The "Library" destination reached from [MoreScreen].
///
/// Structured after the Medium app's Library (reading list) screen: a large
/// title, an underlined tab row, and a feed of saved items with a trailing
/// thumbnail.
class LibraryScreen extends StatefulWidget {
  const LibraryScreen({super.key});

  @override
  State<LibraryScreen> createState() => _LibraryScreenState();
}

class _LibraryScreenState extends State<LibraryScreen> {
  static const List<String> _tabs = ['Reading list', 'Lists', 'Highlights'];

  int _tab = 0;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Scaffold(
      backgroundColor: SpotifyColors.background,
      body: SafeArea(
        bottom: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              height: 52,
              child: Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.arrow_back_ios_new, size: 20),
                    color: scheme.onSurface,
                    onPressed: () => Navigator.of(context).maybePop(),
                  ),
                  const Spacer(),
                  IconButton(
                    icon: const Icon(Icons.search, size: 22),
                    color: scheme.onSurface,
                    onPressed: () {},
                  ),
                  IconButton(
                    icon: const Icon(Icons.more_horiz, size: 22),
                    color: scheme.onSurface,
                    onPressed: () {},
                  ),
                  const SizedBox(width: 4),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 0),
              child: Text(
                'Library',
                style: TextStyle(
                  fontFamily: AppTheme.fontFamily,
                  fontSize: 30,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.5,
                  color: scheme.onSurface,
                ),
              ),
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                for (var i = 0; i < _tabs.length; i++)
                  _LibraryTab(
                    label: _tabs[i],
                    selected: _tab == i,
                    onTap: () => setState(() => _tab = i),
                  ),
              ],
            ),
            Expanded(child: _content(scheme)),
          ],
        ),
      ),
    );
  }

  Widget _content(ColorScheme scheme) {
    switch (_tab) {
      case 1:
        return const _ListsTab();
      case 2:
        return const _HighlightsTab();
      default:
        return const _ReadingListTab();
    }
  }
}

/// A single underlined tab in the [LibraryScreen] header.
class _LibraryTab extends StatelessWidget {
  const _LibraryTab({
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

    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          border: Border(
            bottom: BorderSide(
              color: selected ? scheme.onSurface : SpotifyColors.border,
              width: selected ? 2 : 1,
            ),
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontFamily: AppTheme.fontFamily,
            fontSize: 14,
            fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
            color: selected ? scheme.onSurface : scheme.onSurfaceVariant,
          ),
        ),
      ),
    );
  }
}

/// A saved item in the reading list.
class _ReadingItem {
  const _ReadingItem({
    required this.title,
    required this.source,
    required this.meta,
    required this.thumb,
  });

  final String title;
  final String source;
  final String meta;
  final String thumb;
}

const List<_ReadingItem> _readingItems = [
  _ReadingItem(
    title: 'Data Structures & Algorithms — Complete Lecture Notes',
    source: 'Dr. A. Mensah',
    meta: '24 min read',
    thumb: 'assets/background.jpeg',
  ),
  _ReadingItem(
    title: 'Database Systems: From Normalization to Transactions',
    source: 'Faculty of Science',
    meta: '18 min read',
    thumb: 'assets/background-2.jpeg',
  ),
  _ReadingItem(
    title: 'CSC 200 Past Questions & Marking Scheme (2019–2024)',
    source: 'Encore Library',
    meta: '6 min read',
    thumb: 'assets/Encore.png',
  ),
  _ReadingItem(
    title: 'Linear Algebra Cheat Sheet for Engineers',
    source: 'Prof. K. Okafor',
    meta: '9 min read',
    thumb: 'assets/background-3.jpeg',
  ),
  _ReadingItem(
    title: 'Operating Systems: Process Scheduling Summary',
    source: 'Dr. A. Mensah',
    meta: '12 min read',
    thumb: 'assets/launch_icon_foreground.png',
  ),
];

class _ReadingListTab extends StatelessWidget {
  const _ReadingListTab();

  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      padding: const EdgeInsets.only(top: 4),
      itemCount: _readingItems.length,
      separatorBuilder: (context, _) =>
          const Divider(height: 1, thickness: 1, color: SpotifyColors.border),
      itemBuilder: (context, i) => _ReadingRow(item: _readingItems[i]),
    );
  }
}

class _ReadingRow extends StatelessWidget {
  const _ReadingRow({required this.item});

  final _ReadingItem item;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return InkWell(
      onTap: () {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Opening “${item.title}”'),
            duration: const Duration(seconds: 1),
          ),
        );
      },
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 18, 16, 18),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: AppType.name(scheme).copyWith(height: 1.25),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Text(
                        item.source,
                        style: AppType.subtitle(scheme).copyWith(
                          fontWeight: FontWeight.w600,
                          color: scheme.onSurface,
                        ),
                      ),
                      Text(' · ', style: AppType.subtitle(scheme)),
                      Text(item.meta, style: AppType.subtitle(scheme)),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(width: 14),
            ClipRRect(
              borderRadius: BorderRadius.circular(3),
              child: Image.asset(
                item.thumb,
                width: 56,
                height: 56,
                fit: BoxFit.cover,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// A saved list (collection) in the library.
class _LibraryList {
  const _LibraryList({
    required this.name,
    required this.count,
    required this.thumb,
  });

  final String name;
  final int count;
  final String thumb;
}

const List<_LibraryList> _lists = [
  _LibraryList(
    name: 'CSC 200 Materials',
    count: 12,
    thumb: 'assets/background-2.jpeg',
  ),
  _LibraryList(name: 'MTH 101', count: 8, thumb: 'assets/background-3.jpeg'),
  _LibraryList(
    name: 'Second Semester',
    count: 20,
    thumb: 'assets/background.jpeg',
  ),
];

class _ListsTab extends StatelessWidget {
  const _ListsTab();

  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      padding: const EdgeInsets.only(top: 4),
      itemCount: _lists.length,
      separatorBuilder: (context, _) =>
          const Divider(height: 1, thickness: 1, color: SpotifyColors.border),
      itemBuilder: (context, i) {
        final list = _lists[i];
        final scheme = Theme.of(context).colorScheme;
        return Padding(
          padding: const EdgeInsets.fromLTRB(16, 18, 16, 18),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      list.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppType.name(scheme),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '${list.count} items',
                      style: AppType.subtitle(scheme),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 14),
              ClipRRect(
                borderRadius: BorderRadius.circular(3),
                child: Image.asset(
                  list.thumb,
                  width: 56,
                  height: 56,
                  fit: BoxFit.cover,
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

/// A highlighted passage in the library.
class _Highlight {
  const _Highlight({required this.quote, required this.source});

  final String quote;
  final String source;
}

const List<_Highlight> _highlights = [
  _Highlight(
    quote:
        'A stack is a linear structure that follows the last in, first out '
        'principle — the most recent element is the first to leave.',
    source: 'CSC 200 Notes',
  ),
  _Highlight(
    quote:
        'Normalization removes redundancy by decomposing a relation into '
        'smaller, well-structured relations.',
    source: 'Database Systems',
  ),
  _Highlight(
    quote:
        'An operating system schedules processes to maximise CPU usage '
        'while keeping response times fair.',
    source: 'Operating Systems',
  ),
];

class _HighlightsTab extends StatelessWidget {
  const _HighlightsTab();

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: _highlights.length,
      separatorBuilder: (context, _) => const SizedBox(height: 14),
      itemBuilder: (context, i) {
        final highlight = _highlights[i];
        return Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: SpotifyColors.surface,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                highlight.quote,
                style: AppType.body(scheme).copyWith(
                  fontStyle: FontStyle.italic,
                  color: scheme.onSurface,
                ),
              ),
              const SizedBox(height: 10),
              Text(highlight.source, style: AppType.subtitle(scheme)),
            ],
          ),
        );
      },
    );
  }
}
