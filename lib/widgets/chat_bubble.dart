import 'package:flutter/material.dart';

import '../models/chat_conversation.dart';
import '../theme/app_theme.dart';
import '../theme/spotify_colors.dart';

/// A WhatsApp-style chat bubble shared by the 1-on-1 and group chat screens so
/// both conversations render identical bubbles.
///
/// Message copy and the timestamp always render in white; a sender's name —
/// shown in group chats only — keeps its per-member colour.
class ChatBubble extends StatelessWidget {
  const ChatBubble({
    super.key,
    required this.message,
    this.showSender = false,
    this.trailingTime,
  });

  final ChatMessage message;

  /// Whether to show the sender's coloured name (group chats).
  final bool showSender;

  /// Overrides the displayed timestamp, e.g. "Seen"/"Sent" in a 1-on-1 chat.
  final String? trailingTime;

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

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Align(
        alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
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
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                if (header != null) ...[header, const SizedBox(height: 3)],
                Text(
                  message.text,
                  style: const TextStyle(
                    fontFamily: AppTheme.fontFamily,
                    fontSize: 14.5,
                    height: 1.3,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 3),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Spacer(),
                    Text(
                      trailingTime ?? message.time,
                      style: const TextStyle(
                        fontFamily: AppTheme.fontFamily,
                        fontSize: 10.5,
                        color: Colors.white,
                      ),
                    ),
                    if (isMe) ...[
                      const SizedBox(width: 4),
                      const Icon(
                        Icons.done_all_rounded,
                        size: 16,
                        color: Colors.white,
                      ),
                    ],
                  ],
                ),
              ],
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
