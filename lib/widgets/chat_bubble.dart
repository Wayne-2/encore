import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../models/chat_conversation.dart';
import '../theme/app_theme.dart';
import '../theme/app_type.dart';
import '../theme/spotify_colors.dart';
import '../utils/active_time.dart';
import 'chat_media_image.dart';
import 'swipe_to_reply.dart';
import 'voice_note_player.dart';

/// A chat bubble shared by the 1-on-1 and group chat screens.
///
/// Supports reply previews, remote photos, edited/deleted states, swipe to
/// reply and Telegram style sent/seen ticks. Message copy always renders in
/// white; a sender's name — shown in group chats only — keeps its per-member
/// colour.
class ChatBubble extends StatelessWidget {
  const ChatBubble({
    super.key,
    required this.message,
    this.showSender = false,
    this.trailingTime,
    this.onLongPress,
    this.onReply,
    this.onOpenLibrary,
  });

  final ChatMessage message;

  /// Whether to show the sender's coloured name (group chats).
  final bool showSender;

  /// Overrides the displayed timestamp, e.g. "Seen"/"Sent" in a 1-on-1 chat.
  final String? trailingTime;

  /// Opens the message action sheet (reply, copy, edit, delete).
  final VoidCallback? onLongPress;

  /// Starts an inline reply when the bubble is swiped.
  final VoidCallback? onReply;

  /// Opens a document shared from the public library.
  final VoidCallback? onOpenLibrary;

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
            fontSize: 12,
            color: scheme.onSurfaceVariant,
          ),
        ),
      );
    }

    final isMe = message.isMe;
    final isDeleted = message.isDeleted;
    final header = _header(context);
    final hasImage =
        message.imageUrl != null && message.imageUrl!.isNotEmpty && !isDeleted;
    final hasSticker =
        message.stickerUrl != null &&
        message.stickerUrl!.isNotEmpty &&
        !isDeleted;
    final hasVoice =
        message.voiceUrl != null && message.voiceUrl!.isNotEmpty && !isDeleted;
    final hasLibrary =
        message.libraryId != null &&
        message.libraryId!.isNotEmpty &&
        !isDeleted;
    final hasText = message.text.trim().isNotEmpty;
    final showReply = !isDeleted && message.replyToText != null;
    final stickerOnly = hasSticker && !hasText && header == null && !showReply;
    final bubbleColor = stickerOnly
        ? Colors.transparent
        : isDeleted
        ? SpotifyColors.surface
        : (isMe ? SpotifyColors.chatOutgoing : SpotifyColors.surface);
    final bodyColor = isDeleted ? scheme.onSurfaceVariant : Colors.white;
    final metaColor = isDeleted ? scheme.onSurfaceVariant : Colors.white;
    final imageOnly = hasImage && !hasText && header == null && !showReply;

    Widget metaRow() {
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (message.isEdited && !isDeleted) ...[
            Text(
              'edited',
              style: TextStyle(
                fontFamily: AppTheme.fontFamily,
                fontSize: 12,
                fontStyle: FontStyle.italic,
                color: metaColor.withValues(alpha: 0.75),
              ),
            ),
            const SizedBox(width: 6),
          ],
          const SizedBox(width: 8),
          if (trailingTime != null)
            Text(
              trailingTime!,
              style: AppType.timestamp(
                scheme,
              ).copyWith(color: metaColor.withValues(alpha: 0.7)),
            )
          else
            ActiveTimestamp(
              at: message.createdAt,
              fallback: message.time,
              style: AppType.timestamp(
                scheme,
              ).copyWith(color: metaColor.withValues(alpha: 0.7)),
            ),
          if (isMe && !isDeleted) ...[
            const SizedBox(width: 4),
            Icon(
              message.isPending
                  ? LucideIcons.clock
                  : message.isSeen
                  ? LucideIcons.checkCheck
                  : LucideIcons.check,
              size: 16,
              color: message.isPending
                  ? Colors.white.withValues(alpha: 0.6)
                  : message.isSeen
                  ? Colors.lightBlueAccent
                  : Colors.white.withValues(alpha: 0.75),
            ),
          ],
        ],
      );
    }

    final bubble = Padding(
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
                color: bubbleColor,
                border: isDeleted
                    ? Border.all(color: SpotifyColors.borderStrong)
                    : null,
                borderRadius: BorderRadius.only(
                  topLeft: const Radius.circular(12),
                  topRight: const Radius.circular(12),
                  bottomLeft: isMe ? const Radius.circular(12) : Radius.zero,
                  bottomRight: isMe ? Radius.zero : const Radius.circular(12),
                ),
              ),
              clipBehavior: Clip.antiAlias,
              child: stickerOnly
                  ? Stack(
                      children: [
                        _stickerWidget(),
                        Positioned(
                          right: 4,
                          bottom: 2,
                          child: Container(
                            padding: const EdgeInsets.fromLTRB(7, 3, 6, 3),
                            decoration: BoxDecoration(
                              color: Colors.black.withValues(alpha: 0.45),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: metaRow(),
                          ),
                        ),
                      ],
                    )
                  : imageOnly
                  ? Stack(
                      children: [
                        _imageWidget(),
                        Positioned(
                          left: 0,
                          right: 0,
                          bottom: 0,
                          child: Container(
                            padding: const EdgeInsets.fromLTRB(10, 22, 8, 7),
                            decoration: const BoxDecoration(
                              gradient: LinearGradient(
                                begin: Alignment.topCenter,
                                end: Alignment.bottomCenter,
                                colors: [Colors.transparent, Colors.black54],
                              ),
                            ),
                            child: Align(
                              alignment: Alignment.centerRight,
                              child: metaRow(),
                            ),
                          ),
                        ),
                      ],
                    )
                  : Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (header != null || showReply)
                          Padding(
                            padding: EdgeInsets.fromLTRB(
                              12,
                              8,
                              12,
                              hasImage ? 7 : 0,
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                ?header,
                                if (showReply) ...[
                                  if (header != null) const SizedBox(height: 3),
                                  _ReplyPreview(
                                    sender: message.replyToSender ?? 'Message',
                                    text: message.replyToText!,
                                  ),
                                ],
                              ],
                            ),
                          ),
                        if (hasImage)
                          SizedBox(
                            width: double.infinity,
                            child: _imageWidget(),
                          ),
                        if (hasSticker)
                          Padding(
                            padding: EdgeInsets.fromLTRB(
                              8,
                              header == null && !showReply ? 8 : 4,
                              8,
                              0,
                            ),
                            child: _stickerWidget(),
                          ),
                        if (hasVoice)
                          Padding(
                            padding: EdgeInsets.fromLTRB(
                              8,
                              header == null && !showReply ? 8 : 4,
                              8,
                              0,
                            ),
                            child: VoiceNotePlayer(
                              url: message.voiceUrl!,
                              durationMs: message.voiceDurationMs,
                              waveform: message.voiceWaveform,
                              isMe: isMe,
                            ),
                          ),
                        if (hasLibrary)
                          Padding(
                            padding: EdgeInsets.fromLTRB(
                              8,
                              header == null && !showReply ? 8 : 4,
                              8,
                              0,
                            ),
                            child: _libraryWidget(context),
                          ),
                        Padding(
                          padding: EdgeInsets.fromLTRB(
                            12,
                            hasImage || hasSticker ? 7 : (hasVoice ? 2 : 8),
                            12,
                            8,
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              if (hasText)
                                Text(
                                  message.text,
                                  style: TextStyle(
                                    fontFamily: AppTheme.fontFamily,
                                    fontSize: 15,
                                    height: 1.3,
                                    color: bodyColor,
                                    fontStyle: isDeleted
                                        ? FontStyle.italic
                                        : FontStyle.normal,
                                  ),
                                ),
                              if (hasText) const SizedBox(height: 3),
                              metaRow(),
                            ],
                          ),
                        ),
                      ],
                    ),
            ),
          ),
        ),
      ),
    );

    if (onReply == null) return bubble;
    return SwipeToReply(
      fromMe: isMe,
      onReply: onReply!,
      enabled: !isDeleted,
      child: bubble,
    );
  }

  Widget _imageWidget() {
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 260, maxHeight: 260),
      child: ChatMediaImage(
        url: message.imageUrl!,
        heroTag: 'chat-image-${message.id}',
      ),
    );
  }

  Widget _libraryWidget(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final isMe = message.isMe;
    final foreground = isMe ? Colors.white : scheme.onSurface;
    final subject = message.librarySubject?.trim() ?? '';
    return Container(
      constraints: const BoxConstraints(maxWidth: 260),
      decoration: BoxDecoration(
        color: isMe
            ? Colors.black.withValues(alpha: 0.16)
            : SpotifyColors.accent.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(9),
        border: Border.all(
          color: (isMe ? Colors.white : SpotifyColors.accent).withValues(
            alpha: 0.25,
          ),
        ),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        key: ValueKey('chat-library-${message.id}'),
        onTap: onOpenLibrary,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(10, 9, 10, 9),
          child: Row(
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: SpotifyColors.accent.withValues(alpha: 0.18),
                  borderRadius: BorderRadius.circular(7),
                ),
                child: const Icon(
                  LucideIcons.fileText,
                  size: 19,
                  color: SpotifyColors.accent,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      message.libraryTitle?.trim().isNotEmpty == true
                          ? message.libraryTitle!.trim()
                          : 'Library document',
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontFamily: AppTheme.fontFamily,
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        height: 1.25,
                        color: foreground,
                      ),
                    ),
                    if (subject.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(
                        subject,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontFamily: AppTheme.fontFamily,
                          fontSize: 12,
                          color: foreground.withValues(alpha: 0.75),
                        ),
                      ),
                    ],
                    const SizedBox(height: 3),
                    Text(
                      'Encore Library · Tap to open',
                      style: TextStyle(
                        fontFamily: AppTheme.fontFamily,
                        fontSize: 12,
                        color: foreground.withValues(alpha: 0.65),
                      ),
                    ),
                  ],
                ),
              ),
              if (onOpenLibrary != null) ...[
                const SizedBox(width: 6),
                Icon(
                  LucideIcons.chevronRight,
                  size: 16,
                  color: foreground.withValues(alpha: 0.6),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _stickerWidget() {
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 168, maxHeight: 168),
      child: ChatMediaImage(
        url: message.stickerUrl!,
        width: 168,
        fit: BoxFit.contain,
        heroTag: 'chat-sticker-${message.id}',
      ),
    );
  }

  /// The optional identity row above the message copy.
  ///
  /// Group chats show a member's coloured name, or an `Anonymous Sender`
  /// badge when the message was posted anonymously.
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
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: message.isDeleted
                  ? scheme.onSurfaceVariant
                  : (message.senderColor ?? SpotifyColors.accent),
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
                  fontSize: 12,
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
            LucideIcons.eyeOff,
            size: 13,
            color: SpotifyColors.tagUrgent,
          ),
          const SizedBox(width: 4),
          Text(
            'Anonymous Sender',
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
          LucideIcons.eyeOff,
          size: 12,
          color: Colors.white.withValues(alpha: 0.85),
        ),
        const SizedBox(width: 4),
        Text(
          'Anonymous Sender',
          style: TextStyle(
            fontFamily: AppTheme.fontFamily,
            fontSize: 12,
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
              fontSize: 12,
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
              fontSize: 12,
              color: Colors.white.withValues(alpha: 0.9),
            ),
          ),
        ],
      ),
    );
  }
}
