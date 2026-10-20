import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../theme/spotify_colors.dart';

/// A text input for the auth forms.
///
/// Uses a placeholder only (no floating label). A leading icon is shown from
/// either an SVG in `assets/icons` ([icon], without extension) or a plain
/// [prefixText] glyph such as `@`.
class AuthField extends StatefulWidget {
  const AuthField({
    super.key,
    required this.label,
    this.icon,
    this.controller,
    this.hint,
    this.initialValue,
    this.obscureText = false,
    this.enabled = true,
    this.keyboardType,
    this.textInputAction,
    this.prefixText,
    this.validator,
    this.autofillHints,
    this.textCapitalization = TextCapitalization.none,
    this.inputFormatters,
  });

  final String label;

  /// SVG file name in `assets/icons` (without extension), e.g. `email`.
  final String? icon;

  final TextEditingController? controller;
  final String? hint;
  final String? initialValue;
  final bool obscureText;

  /// When false the field is read-only and uses a subdued palette.
  final bool enabled;

  final TextInputType? keyboardType;
  final TextInputAction? textInputAction;

  /// Glyph shown as the leading icon when [icon] is not set (e.g. `@`).
  final String? prefixText;

  final String? Function(String?)? validator;
  final Iterable<String>? autofillHints;
  final TextCapitalization textCapitalization;
  final List<TextInputFormatter>? inputFormatters;

  @override
  State<AuthField> createState() => _AuthFieldState();
}

class _AuthFieldState extends State<AuthField> {
  late bool _obscured = widget.obscureText;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tint = widget.enabled
        ? theme.colorScheme.onSurfaceVariant
        : SpotifyColors.textSubdued.withValues(alpha: 0.4);

    Widget svgIcon(String name) => SvgPicture.asset(
      'assets/icons/$name.svg',
      width: 20,
      height: 20,
      colorFilter: ColorFilter.mode(tint, BlendMode.srcIn),
    );

    return TextFormField(
      controller: widget.controller,
      initialValue: widget.initialValue,
      enabled: widget.enabled,
      obscureText: _obscured,
      keyboardType: widget.keyboardType,
      textInputAction: widget.textInputAction,
      textCapitalization: widget.textCapitalization,
      autofillHints: widget.autofillHints,
      validator: widget.validator,
      inputFormatters: widget.inputFormatters,
      style: widget.enabled
          ? theme.textTheme.bodyLarge
          : theme.textTheme.bodyLarge?.copyWith(
              color: SpotifyColors.textSubdued.withValues(alpha: 0.5),
            ),
      decoration: InputDecoration(
        hintText: widget.hint ?? widget.label,
        prefixIcon: _leadingIcon(theme, tint, svgIcon),
        prefixIconConstraints: const BoxConstraints(minWidth: 0, minHeight: 0),
        fillColor: widget.enabled
            ? null
            : SpotifyColors.surface.withValues(alpha: 0.5),
        disabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(
            color: SpotifyColors.border.withValues(alpha: 0.5),
          ),
        ),
        suffixIcon: widget.obscureText
            ? IconButton(
                tooltip: _obscured ? 'Show password' : 'Hide password',
                icon: svgIcon('show'),
                onPressed: () => setState(() => _obscured = !_obscured),
              )
            : null,
      ),
    );
  }

  Widget? _leadingIcon(
    ThemeData theme,
    Color tint,
    Widget Function(String) svgIcon,
  ) {
    if (widget.icon != null) {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12),
        child: svgIcon(widget.icon!),
      );
    }
    if (widget.prefixText != null) {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12),
        child: Text(
          widget.prefixText!,
          style: theme.textTheme.bodyLarge?.copyWith(
            fontSize: 16,
            fontWeight: FontWeight.w500,
            color: tint,
            height: 1,
          ),
        ),
      );
    }
    return null;
  }
}
