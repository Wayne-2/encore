import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../services/sticker_store.dart';
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

/// Inline emoji and sticker tray shown directly below the chat composer.
///
/// Emoji taps insert at the composer cursor. Stickers are sent immediately and
/// can be imported from a WhatsApp sticker folder (or individual `.webp` files).
class ChatEmojiStickerPanel extends StatefulWidget {
  const ChatEmojiStickerPanel({
    super.key,
    required this.controller,
    required this.onStickerSelected,
    this.onMessage,
  });

  final TextEditingController controller;
  final Future<void> Function(StickerItem sticker) onStickerSelected;
  final ValueChanged<String>? onMessage;

  @override
  State<ChatEmojiStickerPanel> createState() => _ChatEmojiStickerPanelState();
}

class _ChatEmojiStickerPanelState extends State<ChatEmojiStickerPanel> {
  List<StickerItem> _stickers = const [];
  bool _loading = true;
  bool _importing = false;

  @override
  void initState() {
    super.initState();
    _loadStickers();
  }

  Future<void> _loadStickers() async {
    try {
      final stickers = await StickerStore.instance.load();
      if (!mounted) return;
      setState(() {
        _stickers = stickers;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _loading = false);
    }
  }

  Future<void> _importFolder() async {
    if (_importing) return;
    setState(() => _importing = true);
    try {
      final path = await FilePicker.getDirectoryPath(
        dialogTitle: 'Select a WhatsApp sticker folder',
      );
      if (path == null) return;
      final result = await StickerStore.instance.importDirectory(path);
      if (!mounted) return;
      _handleImport(result);
    } catch (_) {
      _notify('Could not import that folder.');
    } finally {
      if (mounted) setState(() => _importing = false);
    }
  }

  Future<void> _pickFiles() async {
    if (_importing) return;
    setState(() => _importing = true);
    try {
      final files = await FilePicker.pickFiles(
        dialogTitle: 'Select WhatsApp sticker files',
        type: FileType.custom,
        allowedExtensions: const ['webp'],
      );
      if (files.isEmpty) return;

      final sources = <StickerSource>[];
      for (final file in files) {
        try {
          sources.add(
            StickerSource(
              name: file.name,
              bytes: await file.readAsBytes(),
              pack: 'Imported',
            ),
          );
        } catch (_) {
          // Skip unreadable picks and import the rest.
        }
      }
      final result = await StickerStore.instance.importSources(sources);
      if (!mounted) return;
      _handleImport(result);
    } catch (_) {
      _notify('Could not import those stickers.');
    } finally {
      if (mounted) setState(() => _importing = false);
    }
  }

  void _handleImport(StickerImportResult result) {
    if (result.error != null) {
      _notify(result.error!);
      return;
    }
    setState(() => _stickers = StickerStore.instance.items);
    final skipped = result.skipped > 0 ? ' ${result.skipped} skipped.' : '';
    _notify('Imported ${result.imported} stickers.$skipped');
  }

  Future<void> _send(StickerItem sticker) async {
    HapticFeedback.selectionClick();
    try {
      await widget.onStickerSelected(sticker);
    } catch (_) {
      _notify('Could not send that sticker.');
    }
  }

  Future<void> _remove(StickerItem sticker) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Remove sticker?'),
        content: const Text(
          'This removes it from your sticker tray. The original WhatsApp '
          'folder is not changed.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Remove'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    await StickerStore.instance.remove(sticker);
    if (!mounted) return;
    setState(() => _stickers = StickerStore.instance.items);
  }

  void _notify(String message) {
    final handler = widget.onMessage;
    if (handler != null) {
      handler(message);
      return;
    }
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: _emojiCategories.length + 1,
      child: Container(
        key: const ValueKey('chat-emoji-picker'),
        height: 336,
        decoration: const BoxDecoration(
          color: SpotifyColors.surface,
          border: Border(top: BorderSide(color: SpotifyColors.border)),
        ),
        child: SafeArea(
          top: false,
          child: Column(
            children: [
              const SizedBox(height: 8),
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
                  const Tab(
                    key: ValueKey('chat-sticker-tab'),
                    height: 40,
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(LucideIcons.sticker, size: 17),
                        SizedBox(width: 5),
                        Text('Stickers'),
                      ],
                    ),
                  ),
                ],
              ),
              Expanded(
                child: TabBarView(
                  children: [
                    for (final emojis in _emojiCategories.values)
                      _EmojiGrid(emojis: emojis, controller: widget.controller),
                    _buildStickerTab(),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStickerTab() {
    if (_loading) {
      return const Center(
        child: SizedBox(
          width: 22,
          height: 22,
          child: CircularProgressIndicator(
            strokeWidth: 2,
            color: SpotifyColors.accent,
          ),
        ),
      );
    }

    if (_stickers.isEmpty) {
      return Center(
        key: const ValueKey('chat-sticker-empty'),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                LucideIcons.sticker,
                size: 34,
                color: Colors.white.withValues(alpha: 0.35),
              ),
              const SizedBox(height: 10),
              const Text(
                'No stickers yet',
                style: TextStyle(
                  fontFamily: AppTheme.fontFamily,
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Import a WhatsApp sticker folder from your device to send '
                'stickers in your chats.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontFamily: AppTheme.fontFamily,
                  fontSize: 12.5,
                  height: 1.35,
                  color: Colors.white.withValues(alpha: 0.55),
                ),
              ),
              const SizedBox(height: 14),
              FilledButton.icon(
                key: const ValueKey('chat-sticker-import'),
                onPressed: _importing ? null : _importFolder,
                style: FilledButton.styleFrom(
                  backgroundColor: SpotifyColors.accent,
                  foregroundColor: Colors.black,
                ),
                icon: _importing
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.black,
                        ),
                      )
                    : const Icon(LucideIcons.folderOpen, size: 18),
                label: const Text('Import folder'),
              ),
              TextButton(
                key: const ValueKey('chat-sticker-files'),
                onPressed: _importing ? null : _pickFiles,
                child: const Text('Choose sticker files'),
              ),
            ],
          ),
        ),
      );
    }

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(14, 4, 6, 2),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  '${_stickers.length} sticker'
                  '${_stickers.length == 1 ? '' : 's'}',
                  style: TextStyle(
                    fontFamily: AppTheme.fontFamily,
                    fontSize: 12,
                    color: Colors.white.withValues(alpha: 0.55),
                  ),
                ),
              ),
              IconButton(
                key: const ValueKey('chat-sticker-files'),
                tooltip: 'Choose sticker files',
                onPressed: _importing ? null : _pickFiles,
                icon: const Icon(LucideIcons.files, size: 19),
                color: Colors.white.withValues(alpha: 0.7),
                visualDensity: VisualDensity.compact,
              ),
              IconButton(
                key: const ValueKey('chat-sticker-import'),
                tooltip: 'Import WhatsApp sticker folder',
                onPressed: _importing ? null : _importFolder,
                icon: _importing
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: SpotifyColors.accent,
                        ),
                      )
                    : const Icon(LucideIcons.folderOpen, size: 19),
                color: SpotifyColors.accent,
                visualDensity: VisualDensity.compact,
              ),
            ],
          ),
        ),
        Expanded(
          child: GridView.builder(
            key: const ValueKey('chat-sticker-grid'),
            padding: const EdgeInsets.fromLTRB(8, 2, 8, 12),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 4,
              mainAxisSpacing: 4,
              crossAxisSpacing: 4,
            ),
            itemCount: _stickers.length,
            itemBuilder: (context, index) {
              final sticker = _stickers[index];
              return InkWell(
                key: ValueKey('sticker-${sticker.id}'),
                borderRadius: BorderRadius.circular(10),
                onTap: () => _send(sticker),
                onLongPress: () => _remove(sticker),
                child: Padding(
                  padding: const EdgeInsets.all(5),
                  child: Image.file(
                    File(sticker.path),
                    fit: BoxFit.contain,
                    gaplessPlayback: true,
                    errorBuilder: (_, _, _) => Icon(
                      LucideIcons.imageOff,
                      size: 22,
                      color: Colors.white.withValues(alpha: 0.35),
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}

class _EmojiGrid extends StatelessWidget {
  const _EmojiGrid({required this.emojis, required this.controller});

  final List<String> emojis;
  final TextEditingController controller;

  @override
  Widget build(BuildContext context) {
    return GridView.builder(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 16),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
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
            child: Text(emoji, style: const TextStyle(fontSize: 25)),
          ),
        );
      },
    );
  }
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
