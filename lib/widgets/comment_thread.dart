import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../models/comment.dart';
import '../theme/app_theme.dart';
import '../theme/app_type.dart';
import '../theme/spotify_colors.dart';
import '../utils/active_time.dart';
import 'user_avatar.dart';
import 'reaction_bar.dart';
import 'section_heading.dart';

typedef CommentSubmit = Future<void> Function(String text, {Comment? replyTo});

/// Twitter-style comment thread with a pinned reply bar, shared by the
/// announcement and trending detail pages.
///
/// [header] is the post itself (author, media and body), rendered at the top of
/// the scroll view. Each comment and the post support emoji reactions via
/// [ReactionBar]. The parent owns the list and refreshes it when its store
/// changes; [onSubmit] posts a new comment.
class CommentThread extends StatefulWidget {
  const CommentThread({
    super.key,
    required this.header,
    required this.onSubmit,
    this.comments = const [],
    this.loading = false,
    this.reactionsBasePath,
  });

  final Widget header;
  final List<Comment> comments;
  final bool loading;
  final CommentSubmit onSubmit;

  /// Parent document path for persisted reactions, e.g. `trends/<id>`.
  /// Comments react under `<path>/comments/<commentId>` when this is set.
  final String? reactionsBasePath;

  @override
  State<CommentThread> createState() => _CommentThreadState();
}

class _CommentThreadState extends State<CommentThread> {
  final _commentController = TextEditingController();
  final _scrollController = ScrollController();
  final _inputFocus = FocusNode();

  bool _sending = false;
  Comment? _replyingTo;

  @override
  void dispose() {
    _commentController.dispose();
    _scrollController.dispose();
    _inputFocus.dispose();
    super.dispose();
  }

  Future<void> _addComment() async {
    final text = _commentController.text.trim();
    if (text.isEmpty || _sending) return;

    final replyTo = _replyingTo;
    FocusScope.of(context).unfocus();
    _commentController.clear();
    setState(() {
      _sending = true;
      _replyingTo = null;
    });

    try {
      await widget.onSubmit(text, replyTo: replyTo);
    } catch (_) {
      if (!mounted) return;
      if (_commentController.text.trim().isEmpty) {
        _commentController.text = text;
      }
      setState(() => _replyingTo = replyTo);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not post your comment.')),
      );
    } finally {
      if (mounted) setState(() => _sending = false);
    }

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scrollController.hasClients) return;
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOut,
      );
    });
  }

  void _startReply(Comment comment) {
    setState(() => _replyingTo = comment);
    _inputFocus.requestFocus();
  }

  void _cancelReply() {
    setState(() => _replyingTo = null);
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Column(
      children: [
        Expanded(
          child: ListView(
            controller: _scrollController,
            padding: EdgeInsets.zero,
            children: [
              widget.header,
              const Divider(
                height: 1,
                thickness: 1,
                color: SpotifyColors.border,
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 14, 16, 10),
                child: Row(
                  children: [
                    const SectionHeading('Comments'),
                    const Spacer(),
                    Text(
                      '${widget.comments.length}',
                      style: AppType.meta(scheme),
                    ),
                  ],
                ),
              ),
              if (widget.loading && widget.comments.isEmpty)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 24),
                  child: Center(
                    child: SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  ),
                )
              else if (widget.comments.isEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 24),
                  child: Center(
                    child: Text(
                      'No comments yet',
                      style: AppType.subtitle(scheme),
                    ),
                  ),
                )
              else
                for (var i = 0; i < widget.comments.length; i++) ...[
                  if (i > 0)
                    const Divider(
                      height: 1,
                      thickness: 1,
                      indent: 68,
                      color: SpotifyColors.border,
                    ),
                  _CommentTile(
                    key: ValueKey(widget.comments[i].id),
                    comment: widget.comments[i],
                    reactionsBasePath: widget.reactionsBasePath,
                    onReply: () => _startReply(widget.comments[i]),
                  ),
                ],
              const SizedBox(height: 12),
            ],
          ),
        ),
        _buildInputBar(scheme),
      ],
    );
  }

  /// Reply bar mirroring the direct chat input: a rounded surface pill holding
  /// the field and a trailing send button.
  Widget _buildInputBar(ColorScheme scheme) {
    final canSend = _commentController.text.trim().isNotEmpty && !_sending;
    final replyTo = _replyingTo;

    return Container(
      color: SpotifyColors.background,
      padding: EdgeInsets.only(
        left: 12,
        right: 12,
        top: 8,
        bottom: 8 + MediaQuery.of(context).padding.bottom,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (replyTo != null)
            Container(
              key: const ValueKey('comment-reply-preview'),
              width: double.infinity,
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.fromLTRB(12, 8, 6, 8),
              decoration: BoxDecoration(
                color: SpotifyColors.surface,
                borderRadius: BorderRadius.circular(12),
                border: const Border(
                  left: BorderSide(color: SpotifyColors.accent, width: 3),
                ),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          'Replying to ${replyTo.name}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: AppType.meta(
                            scheme,
                          ).copyWith(fontSize: 12, color: SpotifyColors.accent),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          replyTo.text,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: AppType.meta(scheme).copyWith(fontSize: 12),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    key: const ValueKey('comment-reply-cancel'),
                    tooltip: 'Cancel reply',
                    icon: const Icon(LucideIcons.x, size: 18),
                    color: scheme.onSurfaceVariant,
                    onPressed: _cancelReply,
                  ),
                ],
              ),
            ),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Expanded(
                child: Container(
                  constraints: const BoxConstraints(minHeight: 44),
                  decoration: BoxDecoration(
                    color: SpotifyColors.surface,
                    borderRadius: BorderRadius.circular(24),
                  ),
                  padding: const EdgeInsets.only(left: 16, right: 6),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _commentController,
                          focusNode: _inputFocus,
                          maxLines: 4,
                          minLines: 1,
                          style: TextStyle(
                            fontFamily: AppTheme.fontFamily,
                            color: scheme.onSurface,
                            fontSize: 15,
                          ),
                          onChanged: (_) => setState(() {}),
                          onSubmitted: (_) => _addComment(),
                          textInputAction: TextInputAction.send,
                          decoration: InputDecoration(
                            filled: false,
                            fillColor: Colors.transparent,
                            hintText: replyTo == null
                                ? 'Write a comment'
                                : 'Write a reply',
                            hintStyle: TextStyle(
                              fontFamily: AppTheme.fontFamily,
                              color: scheme.onSurfaceVariant,
                              fontSize: 15,
                            ),
                            border: InputBorder.none,
                            enabledBorder: InputBorder.none,
                            focusedBorder: InputBorder.none,
                            disabledBorder: InputBorder.none,
                            errorBorder: InputBorder.none,
                            focusedErrorBorder: InputBorder.none,
                            contentPadding: const EdgeInsets.symmetric(
                              vertical: 10,
                            ),
                          ),
                        ),
                      ),
                      IconButton(
                        key: const ValueKey('comment-send-button'),
                        icon: _sending
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            : Icon(
                                LucideIcons.arrowUp,
                                color: canSend
                                    ? SpotifyColors.accent
                                    : scheme.onSurfaceVariant,
                                size: 22,
                              ),
                        tooltip: 'Post comment',
                        onPressed: canSend ? _addComment : null,
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// A Twitter-style comment row: avatar, author line, body and reactions.
class _CommentTile extends StatelessWidget {
  const _CommentTile({
    super.key,
    required this.comment,
    required this.onReply,
    this.reactionsBasePath,
  });

  final Comment comment;
  final VoidCallback onReply;
  final String? reactionsBasePath;

  String? get _reactionsPath {
    final base = reactionsBasePath;
    if (base == null || comment.id.isEmpty || comment.id.startsWith('local-')) {
      return null;
    }
    return '$base/comments/${comment.id}';
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return InkWell(
      onLongPress: onReply,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            UserAvatar(
              name: comment.name,
              userId: comment.authorId,
              photoUrl: comment.photoUrl,
              initials: comment.initials,
              size: 40,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          comment.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: AppType.name(scheme).copyWith(fontSize: 12),
                        ),
                      ),
                      const SizedBox(width: 6),
                      Flexible(
                        child: Text(
                          comment.handle,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: AppType.timestamp(scheme),
                        ),
                      ),
                      Text(' · ', style: AppType.timestamp(scheme)),
                      Flexible(
                        child: ActiveTimestamp(
                          at: comment.createdAt,
                          fallback: comment.time,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: AppType.timestamp(scheme),
                        ),
                      ),
                    ],
                  ),
                  if (comment.replyToText.isNotEmpty ||
                      comment.replyToName.isNotEmpty) ...[
                    const SizedBox(height: 6),
                    _QuotedComment(comment: comment),
                  ],
                  const SizedBox(height: 4),
                  Text(
                    comment.text,
                    style: AppType.body(scheme).copyWith(fontSize: 12),
                  ),
                  const SizedBox(height: 8),
                  ReactionBar(
                    initial: comment.reactions,
                    reactionsPath: _reactionsPath,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// The quoted comment shown above a reply in the thread.
class _QuotedComment extends StatelessWidget {
  const _QuotedComment({required this.comment});

  final Comment comment;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final name = comment.replyToName.trim().isEmpty
        ? 'a comment'
        : comment.replyToName.trim();

    return Container(
      key: ValueKey('comment-reply-quote-${comment.id}'),
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(10, 7, 10, 7),
      decoration: BoxDecoration(
        color: SpotifyColors.surfaceHover,
        borderRadius: BorderRadius.circular(8),
        border: const Border(
          left: BorderSide(color: SpotifyColors.accent, width: 2),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            'Replying to $name',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: AppType.meta(
              scheme,
            ).copyWith(fontSize: 12, color: scheme.primary),
          ),
          if (comment.replyToText.trim().isNotEmpty) ...[
            const SizedBox(height: 2),
            Text(
              comment.replyToText,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: AppType.meta(scheme).copyWith(fontSize: 12),
            ),
          ],
        ],
      ),
    );
  }
}
