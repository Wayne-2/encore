import 'dart:math' as math;
import 'dart:ui' show ImageFilter;

import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../theme/app_type.dart';
import '../theme/spotify_colors.dart';

/// A single quick action rendered by [ComposeFab].
///
/// Uses either a Material [icon] or a bundled [iconAsset] so actions can match
/// the SVG icons used elsewhere in the app.
class ComposeAction {
  const ComposeAction({required this.label, this.icon, this.iconAsset})
    : assert(icon != null || iconAsset != null);

  final String label;
  final IconData? icon;
  final String? iconAsset;
}

/// Twitter-style expandable compose button.
///
/// Tapping the add button rotates it 45° into a close icon while a stack of
/// quick actions — supplied via [actions] — is revealed above it.
class ComposeFab extends StatefulWidget {
  const ComposeFab({
    super.key,
    required this.actions,
    this.onActionSelected,
    this.buttonKey,
  });

  final List<ComposeAction> actions;

  /// Called when a revealed action is tapped. The menu closes first.
  final ValueChanged<ComposeAction>? onActionSelected;

  /// Optional key for the main add button (useful when a page has more than
  /// one add icon).
  final Key? buttonKey;

  @override
  State<ComposeFab> createState() => _ComposeFabState();
}

class _ComposeFabState extends State<ComposeFab>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 280),
  );

  late final List<CurvedAnimation> _reveals = [
    for (var i = 0; i < widget.actions.length; i++)
      CurvedAnimation(
        parent: _controller,
        curve: Interval(
          (widget.actions.length - 1 - i) * 0.12,
          0.7 + (widget.actions.length - 1 - i) * 0.12,
          curve: Curves.easeOutCubic,
        ),
      ),
  ];

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _toggle() {
    if (_controller.isForwardOrCompleted) {
      _controller.reverse();
    } else {
      _controller.forward();
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        final t = _controller.value;
        final showActions = _controller.status != AnimationStatus.dismissed;

        return Stack(
          children: [
            if (t > 0)
              Positioned.fill(
                child: GestureDetector(
                  onTap: _toggle,
                  child: ClipRect(
                    child: BackdropFilter(
                      filter: ImageFilter.blur(sigmaX: 10 * t, sigmaY: 10 * t),
                      child: ColoredBox(
                        color: Colors.black.withValues(alpha: 0.4 * t),
                      ),
                    ),
                  ),
                ),
              ),
            Positioned(
              right: 16,
              bottom: 16,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  if (showActions)
                    for (var i = 0; i < widget.actions.length; i++)
                      _ComposeAction(
                        label: widget.actions[i].label,
                        icon: widget.actions[i].icon,
                        iconAsset: widget.actions[i].iconAsset,
                        animation: _reveals[i],
                        onTap: widget.onActionSelected == null
                            ? null
                            : () {
                                final action = widget.actions[i];
                                _toggle();
                                widget.onActionSelected!(action);
                              },
                      ),
                  GestureDetector(
                    key: widget.buttonKey,
                    onTap: _toggle,
                    child: Container(
                      width: 56,
                      height: 56,
                      decoration: BoxDecoration(
                        color: scheme.primary,
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.3),
                            blurRadius: 12,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Transform.rotate(
                        angle: _controller.value * math.pi / 4,
                        child: const Icon(
                          LucideIcons.plus,
                          color: Colors.white,
                          size: 28,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }
}

/// A single revealed action of [ComposeFab]: a label chip plus a round icon.
class _ComposeAction extends StatelessWidget {
  const _ComposeAction({
    required this.label,
    required this.icon,
    required this.iconAsset,
    required this.animation,
    this.onTap,
  });

  final String label;
  final IconData? icon;
  final String? iconAsset;
  final Animation<double> animation;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return SizeTransition(
      sizeFactor: animation,
      alignment: Alignment.bottomLeft,
      child: FadeTransition(
        opacity: animation,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: SpotifyColors.surface,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(label, style: AppType.subtitle(scheme)),
                ),
                const SizedBox(width: 10),
                Container(
                  width: 44,
                  height: 44,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: SpotifyColors.surface,
                    shape: BoxShape.circle,
                    border: Border.all(color: SpotifyColors.border),
                  ),
                  child: iconAsset != null
                      ? SvgPicture.asset(
                          iconAsset!,
                          key: ValueKey('compose-icon-$label'),
                          width: 20,
                          height: 20,
                          colorFilter: ColorFilter.mode(
                            scheme.onSurfaceVariant,
                            BlendMode.srcIn,
                          ),
                        )
                      : Icon(
                          icon,
                          key: ValueKey('compose-icon-$label'),
                          size: 20,
                          color: scheme.onSurfaceVariant,
                        ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
