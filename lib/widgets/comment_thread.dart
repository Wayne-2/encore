import 'package:flutter/material.dart';

import '../models/comment.dart';
import '../theme/app_theme.dart';
import '../theme/app_type.dart';
import '../theme/slack_colors.dart';
import 'chat_avatar.dart';
import 'reaction_bar.dart';
import 'section_heading.dart';

/// Twitter-style comment thread with a pinned reply bar, shared by the
/// announcement and trending detail pages.
///
/// [header] is the post itself (author, media and body), rendered at the top of
/// the scroll view. Each comment and the post support emoji reactions via
/// [ReactionBar].
class CommentThread extends StatefulWidget {
  const CommentThread({
    super.key,
    required this.header,
    this.initialComments = const [],
  });

  final Widget header;
  final List<Comment> initialComments;

  @override
  State<CommentThread> createState() => _CommentThreadState();
}

class _CommentThreadState extends State<CommentThread> {
  final _commentController = TextEditingController();
  final _scrollController = ScrollController();

  late final List<Comment> _comments = List.of(widget.initialComments);

  @override
  void dispose() {
    _commentController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _addComment() {
    final text = _commentController.text.trim();
    if (text.isEmpty) return;
    setState(() {
      _comments.add(
        Comment(
          name: 'Odeh Solomon',
          handle: '@_wayne',
          time: 'now',
          text: text,
          initials: 'OS',
        ),
      );
      _commentController.clear();
    });
    FocusScope.of(context).unfocus();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scrollController.hasClients) return;
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOut,
      );
    });
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
                color: SlackColors.darkBorder,
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 14, 16, 10),
                child: Row(
                  children: [
                    const SectionHeading('Comments'),
                    const Spacer(),
                    Text('${_comments.length}', style: AppType.meta(scheme)),
                  ],
                ),
              ),
              for (var i = 0; i < _comments.length; i++) ...[
                if (i > 0)
                  const Divider(
                    height: 1,
                    thickness: 1,
                    indent: 68,
                    color: SlackColors.darkBorder,
                  ),
                _CommentTile(comment: _comments[i]),
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
    final canSend = _commentController.text.trim().isNotEmpty;

    return Container(
      color: SlackColors.darkBackground,
      padding: EdgeInsets.only(
        left: 12,
        right: 12,
        top: 8,
        bottom: 8 + MediaQuery.of(context).padding.bottom,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Expanded(
            child: Container(
              constraints: const BoxConstraints(minHeight: 44),
              decoration: BoxDecoration(
                color: SlackColors.darkSurface,
                borderRadius: BorderRadius.circular(24),
              ),
              padding: const EdgeInsets.only(left: 16, right: 6),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Expanded(
                    child: TextField(
                      controller: _commentController,
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
                        hintText: 'Write a comment',
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
                    icon: Icon(
                      Icons.arrow_upward_rounded,
                      color: canSend
                          ? SlackColors.accentGreen
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
    );
  }
}

/// A Twitter-style comment row: avatar, author line, body and reactions.
class _CommentTile extends StatelessWidget {
  const _CommentTile({required this.comment});

  final Comment comment;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ChatAvatar(
            avatarInitials: comment.initials,
            avatarColor: SlackColors.darkHeader,
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
                        style: AppType.name(scheme).copyWith(fontSize: 13),
                      ),
                    ),
                    const SizedBox(width: 6),
                    Flexible(
                      child: Text(
                        '${comment.handle} · ${comment.time}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppType.meta(scheme).copyWith(fontSize: 10),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  comment.text,
                  style: AppType.body(scheme).copyWith(fontSize: 13),
                ),
                const SizedBox(height: 8),
                ReactionBar(initial: comment.reactions),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
