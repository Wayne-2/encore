import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import '../theme/spotify_colors.dart';

/// A native-iOS-style alert, restyled with Encore's dark theme tokens.
///
/// A centred, 14-radius card on `SpotifyColors.surface` with a
/// `SpotifyColors.border` hairline, a centred title/message and hairline-
/// separated actions — the layout of `UIAlertController`, in app colours.
class AuthDialog extends StatelessWidget {
  const AuthDialog({
    super.key,
    required this.title,
    required this.message,
    this.actionLabel = 'OK',
    this.onAction,
    this.secondaryLabel,
    this.onSecondary,
  });

  final String title;
  final String message;
  final String actionLabel;
  final VoidCallback? onAction;
  final String? secondaryLabel;
  final VoidCallback? onSecondary;

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 52),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: SpotifyColors.surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: SpotifyColors.border),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.4),
              blurRadius: 24,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(14),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 20, 16, 16),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      title,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontFamily: AppTheme.fontFamily,
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                        height: 1.25,
                        color: SpotifyColors.textPrimary,
                      ),
                    ),
                    if (message.isNotEmpty) ...[
                      const SizedBox(height: 6),
                      Text(
                        message,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontFamily: AppTheme.fontFamily,
                          fontSize: 12,
                          fontWeight: FontWeight.w400,
                          height: 1.35,
                          color: SpotifyColors.textSubdued,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const _Hairline(),
              IntrinsicHeight(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (secondaryLabel != null) ...[
                      Expanded(
                        child: _DialogAction(
                          label: secondaryLabel!,
                          onTap: onSecondary,
                        ),
                      ),
                      const _Hairline(vertical: true),
                    ],
                    Expanded(
                      child: _DialogAction(
                        label: actionLabel,
                        onTap: onAction,
                        emphasized: true,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Shows an [AuthDialog] for an authentication message.
///
/// The dialog pops itself before running [onAction]/[onSecondary], so callers
/// can navigate or continue without worrying about the dialog staying on top.
Future<void> showAuthDialog(
  BuildContext context, {
  required String title,
  required String message,
  String actionLabel = 'OK',
  VoidCallback? onAction,
  String? secondaryLabel,
  VoidCallback? onSecondary,
}) {
  return showDialog<void>(
    context: context,
    barrierColor: Colors.black.withValues(alpha: 0.5),
    builder: (dialogContext) => AuthDialog(
      title: title,
      message: message,
      actionLabel: actionLabel,
      onAction: () {
        Navigator.of(dialogContext).pop();
        onAction?.call();
      },
      secondaryLabel: secondaryLabel,
      onSecondary: secondaryLabel == null
          ? null
          : () {
              Navigator.of(dialogContext).pop();
              onSecondary?.call();
            },
    ),
  );
}

class _DialogAction extends StatelessWidget {
  const _DialogAction({
    required this.label,
    this.onTap,
    this.emphasized = false,
  });

  final String label;
  final VoidCallback? onTap;
  final bool emphasized;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Container(
        height: 44,
        alignment: Alignment.center,
        child: Text(
          label,
          style: TextStyle(
            fontFamily: AppTheme.fontFamily,
            fontSize: 18,
            fontWeight: emphasized ? FontWeight.w600 : FontWeight.w400,
            color: emphasized
                ? SpotifyColors.accent
                : SpotifyColors.textPrimary,
          ),
        ),
      ),
    );
  }
}

/// A single hairline, either horizontal or vertical, in the border colour.
class _Hairline extends StatelessWidget {
  const _Hairline({this.vertical = false});

  final bool vertical;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: vertical ? 0.5 : null,
      height: vertical ? null : 0.5,
      color: SpotifyColors.border,
    );
  }
}
