import 'package:flutter/material.dart';

import '../models/chat_conversation.dart';
import '../theme/app_theme.dart';
import '../theme/spotify_colors.dart';

/// A chat bubble shared by the 1-on-1 and group chat screens.
///
/// Supports reply previews, remote photos, edited/deleted states and Telegram
/// style sent/seen ticks. Message copy always renders in white; a sender's
/// name — shown in group chats only — keeps its per-member colour.
class ChatBubble extends StatelessWidget {
  const ChatBubble({
    super.key,
    required this.message,
    this.showSender = false,
    this.trailingTime,
    this.onLongPress,
  });

  final ChatMessage message;

  /// Whether to show the sender's coloured name (group chats).
  final bool showSender;

  /// Overrides the displayed timestamp, e.g. "Seen"/"Sent" in a 1-on-1 chat.
  final String? trailingTime;

  /// Opens the message action sheet (reply, copy, edit, delete).
  final VoidCallback? onLongPress;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    if (message.isNotice) {
      return Container(
        margin: const EdgeInsets.symmetric(horizontal: 24, vertical: 6),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: SpotifyColors.surface,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text(
          message.text,
          textAlign: TextAlign.center,
          style: TextStyle(
            fontFamily: AppTheme.fontFamily,
            fontSize: 11.5,
            color: scheme.onSurfaceVariant,
          ),
        ),
      );
    }

    final isMe = message.isMe;
    final header = _header(context);
    final hasImage =
        message.imageUrl != null &&
        message.imageUrl!.isNotEmpty &&
        !message.isDeleted;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Align(
        alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
        child: GestureDetector(
          onLongPress: onLongPress,
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxWidth: MediaQuery.of(context).size.width * 0.78,
            ),
            child: Container(
              decoration: BoxDecoration(
                color: isMe ? SpotifyColors.accent : SpotifyColors.surface,
                borderRadius: BorderRadius.only(
                  topLeft: const Radius.circular(12),
                  topRight: const Radius.circular(12),
                  bottomLeft: isMe ? const Radius.circular(12) : Radius.zero,
                  bottomRight: isMe ? Radius.zero : const Radius.circular(12),
                ),
              ),
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
              clipBehavior: Clip.antiAlias,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (header != null) ...[header, const SizedBox(height: 3)],
                  if (message.replyToText != null) ...[
                    _ReplyPreview(
                      sender: message.replyToSender ?? 'Message',
                      text: message.replyToText!,
                    ),
                    const SizedBox(height: 6),
                  ],
                  if (hasImage) ...[
                    ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(
                          maxWidth: 260,
                          maxHeight: 260,
                        ),
                        child: Image.network(
                          message.imageUrl!,
                          fit: BoxFit.cover,
                          loadingBuilder: (context, child, progress) {
                            if (progress == null) return child;
                            return const SizedBox(
                              width: 220,
                              height: 150,
                              child: Center(
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white70,
                                ),
                              ),
                            );
                          },
                          errorBuilder: (_, _, _) => Container(
                            width: 220,
                            height: 150,
                            color: Colors.black26,
                            child: const Icon(
                              Icons.broken_image_outlined,
                              color: Colors.white70,
                            ),
                          ),
                        ),
                      ),
                    ),
                    if (message.text.trim().isNotEmpty)
                      const SizedBox(height: 6),
                  ],
                  if (message.text.trim().isNotEmpty)
                    Text(
                      message.text,
                      style: TextStyle(
                        fontFamily: AppTheme.fontFamily,
                        fontSize: 14.5,
                        height: 1.3,
                        color: Colors.white,
                        fontStyle: message.isDeleted
                            ? FontStyle.italic
                            : FontStyle.normal,
                      ),
                    ),
                  const SizedBox(height: 3),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (message.isEdited) ...[
                        Text(
                          'edited',
                          style: TextStyle(
                            fontFamily: AppTheme.fontFamily,
                            fontSize: 10,
                            fontStyle: FontStyle.italic,
                            color: Colors.white.withValues(alpha: 0.75),
                          ),
                        ),
                        const SizedBox(width: 6),
                      ],
                      const SizedBox(width: 12),
                      Text(
                        trailingTime ?? message.time,
                        style: const TextStyle(
                          fontFamily: AppTheme.fontFamily,
                          fontSize: 10.5,
                          color: Colors.white,
                        ),
                      ),
                      if (isMe && !message.isDeleted) ...[
                        const SizedBox(width: 4),
                        Icon(
                          message.isSeen
                              ? Icons.done_all_rounded
                              : Icons.done_rounded,
                          size: 16,
                          color: message.isSeen
                              ? Colors.lightBlueAccent
                              : Colors.white.withValues(alpha: 0.75),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// The optional identity row above the message copy.
  ///
  /// - Group chats show a member's coloured name (or an `Anonymous Member`
  ///   badge when they posted anonymously).
  /// - Anonymous messages from anyone else show the concealment notice.
  Widget? _header(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final isMe = message.isMe;

    if (!message.isAnonymous &&
        showSender &&
        !isMe &&
        message.senderName != null) {
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            message.senderName!,
            style: TextStyle(
              fontFamily: AppTheme.fontFamily,
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: message.senderColor ?? SpotifyColors.accent,
            ),
          ),
          if (message.isAdmin) ...[
            const SizedBox(width: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
              decoration: BoxDecoration(
                color: scheme.onSurface.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(3),
              ),
              child: Text(
                'Admin',
                style: TextStyle(
                  fontFamily: AppTheme.fontFamily,
                  fontSize: 9,
                  fontWeight: FontWeight.w600,
                  color: scheme.onSurfaceVariant,
                ),
              ),
            ),
          ],
        ],
      );
    }

    if (!message.isAnonymous) return null;

    if (showSender && !isMe) {
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(
            Icons.visibility_off_rounded,
            size: 13,
            color: SpotifyColors.tagUrgent,
          ),
          const SizedBox(width: 4),
          Text(
            'Anonymous Member',
            style: TextStyle(
              fontFamily: AppTheme.fontFamily,
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: SpotifyColors.tagUrgent.withValues(alpha: 0.95),
            ),
          ),
        ],
      );
    }

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          Icons.visibility_off_rounded,
          size: 12,
          color: Colors.white.withValues(alpha: 0.85),
        ),
        const SizedBox(width: 4),
        Text(
          'Sent anonymously (No sender ID)',
          style: TextStyle(
            fontFamily: AppTheme.fontFamily,
            fontSize: 10,
            fontWeight: FontWeight.w600,
            color: Colors.white.withValues(alpha: 0.85),
          ),
        ),
      ],
    );
  }
}

class _ReplyPreview extends StatelessWidget {
  const _ReplyPreview({required this.sender, required this.text});

  final String sender;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(maxWidth: 240),
      padding: const EdgeInsets.fromLTRB(8, 5, 8, 5),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.16),
        borderRadius: BorderRadius.circular(7),
        border: const Border(left: BorderSide(color: Colors.white, width: 2.5)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            sender,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontFamily: AppTheme.fontFamily,
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 1),
          Text(
            text,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontFamily: AppTheme.fontFamily,
              fontSize: 11.5,
              color: Colors.white.withValues(alpha: 0.9),
            ),
          ),
        ],
      ),
    );
  }
}
