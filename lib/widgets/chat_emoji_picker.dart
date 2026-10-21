import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../theme/app_theme.dart';
import '../theme/spotify_colors.dart';

const Map<String, List<String>> _emojiCategories = {
  'Smileys': [
    '😀',
    '😃',
    '😄',
    '😁',
    '😆',
    '😅',
    '😂',
    '🙂',
    '🙃',
    '😉',
    '😊',
    '😍',
    '🥰',
    '😘',
    '😎',
    '🤓',
    '🤔',
    '🤭',
    '😴',
    '😌',
    '😜',
    '🤩',
    '🥳',
    '😭',
    '😤',
    '😡',
    '😱',
    '🫠',
  ],
  'Gestures': [
    '👍',
    '👎',
    '👏',
    '🙌',
    '🙏',
    '🤝',
    '💪',
    '✌️',
    '🤞',
    '🤟',
    '👋',
    '🫡',
    '☝️',
    '👌',
    '🤌',
    '🫶',
    '👀',
    '🧠',
  ],
  'Hearts': [
    '❤️',
    '🧡',
    '💛',
    '💚',
    '💙',
    '💜',
    '🖤',
    '🤍',
    '💔',
    '❤️‍🔥',
    '💕',
    '💞',
    '💓',
    '💗',
    '💖',
    '💘',
    '💝',
    '💟',
  ],
  'Fun': [
    '🔥',
    '✨',
    '🎉',
    '🎊',
    '🎁',
    '🏆',
    '🥇',
    '⚡',
    '💯',
    '💥',
    '🚀',
    '🌈',
    '☀️',
    '🌙',
    '⭐',
    '🍕',
    '🍔',
    '☕',
    '🎵',
    '🎮',
    '⚽',
    '🏀',
    '📚',
    '💻',
    '📱',
    '💡',
    '✅',
    '❌',
  ],
  'Symbols': [
    '😇',
    '💀',
    '👻',
    '🤖',
    '👑',
    '💎',
    '📌',
    '📎',
    '🔔',
    '🔕',
    '🔒',
    '🔓',
    '⚠️',
    '❓',
    '❗',
    '💬',
    '🕐',
    '🆗',
    '🆒',
    '🔞',
  ],
};

/// Opens a compact, tabbed emoji picker and inserts tapped emoji into
/// [controller] at the current cursor position.
Future<void> showChatEmojiPicker({
  required BuildContext context,
  required TextEditingController controller,
}) {
  return showModalBottomSheet<void>(
    context: context,
    backgroundColor: SpotifyColors.surface,
    isScrollControlled: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
    ),
    builder: (sheetContext) {
      return DefaultTabController(
        length: _emojiCategories.length,
        child: SafeArea(
          child: SizedBox(
            key: const ValueKey('chat-emoji-picker'),
            height: 360,
            child: Column(
              children: [
                const SizedBox(height: 10),
                Container(
                  width: 38,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.22),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                TabBar(
                  isScrollable: true,
                  tabAlignment: TabAlignment.start,
                  dividerColor: SpotifyColors.border,
                  indicatorColor: SpotifyColors.accent,
                  labelColor: SpotifyColors.accent,
                  unselectedLabelColor: Colors.white.withValues(alpha: 0.5),
                  labelStyle: const TextStyle(
                    fontFamily: AppTheme.fontFamily,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                  tabs: [
                    for (final category in _emojiCategories.keys)
                      Tab(height: 40, text: category),
                  ],
                ),
                Expanded(
                  child: TabBarView(
                    children: [
                      for (final emojis in _emojiCategories.values)
                        GridView.builder(
                          padding: const EdgeInsets.fromLTRB(12, 10, 12, 16),
                          gridDelegate:
                              const SliverGridDelegateWithFixedCrossAxisCount(
                                crossAxisCount: 7,
                                mainAxisSpacing: 4,
                                crossAxisSpacing: 4,
                              ),
                          itemCount: emojis.length,
                          itemBuilder: (context, index) {
                            final emoji = emojis[index];
                            return InkWell(
                              key: ValueKey('emoji-$emoji'),
                              borderRadius: BorderRadius.circular(8),
                              onTap: () {
                                HapticFeedback.selectionClick();
                                _insertEmoji(controller, emoji);
                              },
                              child: Center(
                                child: Text(
                                  emoji,
                                  style: const TextStyle(fontSize: 25),
                                ),
                              ),
                            );
                          },
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    },
  );
}

void _insertEmoji(TextEditingController controller, String emoji) {
  final value = controller.value;
  final text = value.text;
  var start = value.selection.isValid ? value.selection.start : text.length;
  var end = value.selection.isValid ? value.selection.end : text.length;
  if (start < 0 || start > text.length) start = text.length;
  if (end < start || end > text.length) end = start;
  final next = text.replaceRange(start, end, emoji);
  controller.value = TextEditingValue(
    text: next,
    selection: TextSelection.collapsed(offset: start + emoji.length),
  );
}
