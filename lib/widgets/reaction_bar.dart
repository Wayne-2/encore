import 'package:flutter/material.dart';

import '../theme/app_type.dart';
import '../theme/spotify_colors.dart';

/// Emoji offered by the reaction picker.
const List<String> _emojiPalette = [
  '👍',
  '❤️',
  '😂',
  '🎉',
  '👏',
  '🙌',
  '🔥',
  '😮',
  '😢',
];

/// A reaction tally for one emoji.
class _ReactionEntry {
  _ReactionEntry(this.count, {this.mine = false});

  int count;
  bool mine;
}

/// Emoji reaction row: tappable tallies plus a picker to add more.
class ReactionBar extends StatefulWidget {
  const ReactionBar({super.key, this.initial = const {}});

  final Map<String, int> initial;

  @override
  State<ReactionBar> createState() => _ReactionBarState();
}

class _ReactionBarState extends State<ReactionBar> {
  late final Map<String, _ReactionEntry> _reactions = {
    for (final entry in widget.initial.entries)
      entry.key: _ReactionEntry(entry.value),
  };

  void _toggle(String emoji) {
    setState(() {
      final existing = _reactions[emoji];
      if (existing != null && existing.mine) {
        existing.mine = false;
        existing.count -= 1;
        if (existing.count <= 0) _reactions.remove(emoji);
      } else if (existing != null) {
        existing.mine = true;
        existing.count += 1;
      } else {
        _reactions[emoji] = _ReactionEntry(1, mine: true);
      }
    });
  }

  Future<void> _openPicker() async {
    final emoji = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: SpotifyColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          child: Wrap(
            spacing: 4,
            runSpacing: 4,
            children: [
              for (final emoji in _emojiPalette)
                IconButton(
                  onPressed: () => Navigator.pop(context, emoji),
                  icon: Text(emoji, style: const TextStyle(fontSize: 22)),
                ),
            ],
          ),
        ),
      ),
    );
    if (emoji == null || !mounted) return;
    _toggle(emoji);
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Wrap(
      spacing: 6,
      runSpacing: 6,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        for (final entry in _reactions.entries)
          _ReactionChip(
            emoji: entry.key,
            count: entry.value.count,
            active: entry.value.mine,
            onTap: () => _toggle(entry.key),
          ),
        Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(12),
            onTap: _openPicker,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: SpotifyColors.surfaceHover,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: SpotifyColors.border),
              ),
              child: Icon(
                Icons.add_reaction_outlined,
                size: 16,
                color: scheme.onSurfaceVariant,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// A single emoji tally pill.
class _ReactionChip extends StatelessWidget {
  const _ReactionChip({
    required this.emoji,
    required this.count,
    required this.active,
    required this.onTap,
  });

  final String emoji;
  final int count;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
          decoration: BoxDecoration(
            color: active
                ? SpotifyColors.accent.withValues(alpha: 0.16)
                : SpotifyColors.surfaceHover,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: active ? SpotifyColors.accent : SpotifyColors.border,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(emoji, style: const TextStyle(fontSize: 14)),
              const SizedBox(width: 4),
              Text(
                '$count',
                style: AppType.meta(scheme).copyWith(
                  fontSize: 11,
                  color: active
                      ? SpotifyColors.accent
                      : scheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
