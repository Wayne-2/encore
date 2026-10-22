import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart' show SelectedContent;
import 'package:flutter/services.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../models/library_material.dart';
import '../services/library_store.dart';
import '../services/local_cache.dart';
import '../theme/app_type.dart';
import '../theme/spotify_colors.dart';

class LibraryPreviewScreen extends StatefulWidget {
  const LibraryPreviewScreen({super.key, required this.material});

  final LibraryMaterial material;

  @override
  State<LibraryPreviewScreen> createState() => _LibraryPreviewScreenState();
}

class _LibraryPreviewScreenState extends State<LibraryPreviewScreen> {
  static const String _textScaleKey = 'library:textScale';

  final ScrollController _scrollController = ScrollController();
  SelectedContent? _selection;
  double _textScale = 1;
  double _progress = 0;
  bool _restored = false;

  LibraryMaterial get _material => widget.material;
  LibraryStore get _store => LibraryStore.instance;

  @override
  void initState() {
    super.initState();
    _progress = _store.progressFor(_material.id);
    _scrollController.addListener(_onScroll);
    unawaited(_loadTextScale());
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _restorePosition();
      _store.recordRead(_material);
    });
  }

  @override
  void dispose() {
    _persistProgress();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _loadTextScale() async {
    final value = await LocalCache.instance.read(_textScaleKey);
    if (!mounted || value is! num) return;
    setState(() => _textScale = value.toDouble().clamp(0.85, 1.35));
  }

  void _restorePosition() {
    if (_restored || !_scrollController.hasClients) return;
    _restored = true;
    final max = _scrollController.position.maxScrollExtent;
    if (_progress > 0 && max > 0) {
      _scrollController.jumpTo(max * _progress);
    }
  }

  void _onScroll() {
    if (!_scrollController.hasClients) return;
    final max = _scrollController.position.maxScrollExtent;
    final value = max <= 0
        ? 1.0
        : (_scrollController.offset / max).clamp(0.0, 1.0);
    if ((value - _progress).abs() < 0.005) return;
    setState(() => _progress = value);
  }

  void _persistProgress() {
    if (!_scrollController.hasClients) return;
    final max = _scrollController.position.maxScrollExtent;
    final value = max <= 0
        ? 1.0
        : (_scrollController.offset / max).clamp(0.0, 1.0);
    _store.saveProgress(_material, value);
  }

  Future<void> _toggleSaved() async {
    try {
      await _store.toggleSaved(_material.id);
    } catch (_) {
      _showSnack("Couldn't update your saved list.");
    }
  }

  Future<void> _highlightSelection() async {
    final quote = _selection?.plainText.trim() ?? '';
    if (quote.isEmpty) return;
    try {
      await _store.addHighlight(
        materialId: _material.id,
        materialTitle: _material.title,
        text: quote,
      );
      _showSnack('Highlight saved.');
    } catch (_) {
      _showSnack("Couldn't save that highlight.");
    }
  }

  Future<void> _copyDocument() async {
    await Clipboard.setData(ClipboardData(text: _material.extractedText));
    _showSnack('Document copied.');
  }

  Future<void> _showReadingSettings() async {
    final scale = await showModalBottomSheet<double>(
      context: context,
      backgroundColor: SpotifyColors.surface,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (context) => _ReadingSettingsSheet(initialScale: _textScale),
    );
    if (scale == null || !mounted) return;
    setState(() => _textScale = scale);
    unawaited(LocalCache.instance.write(_textScaleKey, scale));
  }

  void _showSnack(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  Widget _contextMenu(
    BuildContext context,
    SelectableRegionState selectableRegionState,
  ) {
    final hasSelection = _selection?.plainText.trim().isNotEmpty == true;
    return AdaptiveTextSelectionToolbar.buttonItems(
      anchors: selectableRegionState.contextMenuAnchors,
      buttonItems: [
        if (hasSelection)
          ContextMenuButtonItem(
            label: 'Highlight',
            onPressed: () {
              selectableRegionState.hideToolbar();
              unawaited(_highlightSelection());
            },
          ),
        ...selectableRegionState.contextMenuButtonItems,
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return ListenableBuilder(
      listenable: _store,
      builder: (context, _) {
        final saved = _store.isSaved(_material.id);
        return Scaffold(
          backgroundColor: SpotifyColors.background,
          appBar: AppBar(
            title: Text(
              _material.title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            actions: [
              IconButton(
                key: const ValueKey('library-preview-save'),
                onPressed: _toggleSaved,
                tooltip: saved ? 'Remove from Saved list' : 'Save document',
                icon: Icon(
                  saved ? LucideIcons.bookmarkCheck : LucideIcons.bookmark,
                  size: 21,
                  color: saved ? SpotifyColors.accent : scheme.onSurface,
                ),
              ),
              PopupMenuButton<String>(
                key: const ValueKey('library-reader-menu'),
                color: SpotifyColors.surface,
                position: PopupMenuPosition.under,
                icon: Icon(
                  LucideIcons.moreVertical,
                  size: 21,
                  color: scheme.onSurface,
                ),
                onSelected: (value) {
                  switch (value) {
                    case 'settings':
                      unawaited(_showReadingSettings());
                    case 'copy':
                      unawaited(_copyDocument());
                  }
                },
                itemBuilder: (context) => const [
                  PopupMenuItem(value: 'settings', child: Text('Reading size')),
                  PopupMenuItem(value: 'copy', child: Text('Copy document')),
                ],
              ),
              const SizedBox(width: 4),
            ],
            bottom: PreferredSize(
              preferredSize: const Size.fromHeight(2),
              child: LinearProgressIndicator(
                key: const ValueKey('library-reading-progress'),
                value: _progress,
                minHeight: 2,
                backgroundColor: SpotifyColors.border,
                color: SpotifyColors.accent,
              ),
            ),
          ),
          body: Scrollbar(
            controller: _scrollController,
            child: NotificationListener<ScrollEndNotification>(
              onNotification: (notification) {
                _persistProgress();
                return false;
              },
              child: SingleChildScrollView(
                key: const ValueKey('library-reader'),
                controller: _scrollController,
                padding: const EdgeInsets.fromLTRB(20, 18, 20, 52),
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 720),
                    child: _ReaderBody(
                      material: _material,
                      textScale: _textScale,
                      progress: _progress,
                      highlights: _store.highlightsFor(_material.id),
                      onSelectionChanged: (content) => _selection = content,
                      contextMenuBuilder: _contextMenu,
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

class _ReaderBody extends StatelessWidget {
  const _ReaderBody({
    required this.material,
    required this.textScale,
    required this.progress,
    required this.highlights,
    required this.onSelectionChanged,
    required this.contextMenuBuilder,
  });

  final LibraryMaterial material;
  final double textScale;
  final double progress;
  final List<LibraryHighlight> highlights;
  final ValueChanged<SelectedContent?> onSelectionChanged;
  final SelectableRegionContextMenuBuilder contextMenuBuilder;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final readingStyle = AppType.reading(scheme);
    final percent = (progress * 100).round();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          spacing: 6,
          runSpacing: 6,
          children: [
            if (material.subjectLabel.isNotEmpty)
              _Pill(label: material.subjectLabel, emphasized: true),
            _Pill(label: material.sourceLabel),
          ],
        ),
        const SizedBox(height: 14),
        Text(
          material.title,
          style: AppType.sectionTitle(
            scheme,
          ).copyWith(fontSize: 18, height: 1.2, letterSpacing: -0.3),
        ),
        const SizedBox(height: 10),
        Wrap(
          spacing: 8,
          runSpacing: 4,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            Text(material.wordLabel, style: AppType.subtitle(scheme)),
            _Dot(scheme: scheme),
            Text(material.readTimeLabel, style: AppType.subtitle(scheme)),
            _Dot(scheme: scheme),
            Text('$percent% read', style: AppType.subtitle(scheme)),
          ],
        ),
        if (material.uploaderName.isNotEmpty) ...[
          const SizedBox(height: 4),
          Text(
            'Shared by ${material.uploaderName}',
            style: AppType.meta(scheme),
          ),
        ],
        const SizedBox(height: 18),
        const Divider(),
        const SizedBox(height: 18),
        Container(
          key: const ValueKey('library-preview-text'),
          width: double.infinity,
          padding: const EdgeInsets.fromLTRB(18, 20, 18, 22),
          decoration: BoxDecoration(
            color: SpotifyColors.surface,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: SpotifyColors.border),
          ),
          child: SelectionArea(
            onSelectionChanged: onSelectionChanged,
            contextMenuBuilder: contextMenuBuilder,
            child: Text(
              material.extractedText,
              style: readingStyle.copyWith(
                fontSize: readingStyle.fontSize! * textScale,
              ),
            ),
          ),
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Icon(
              LucideIcons.highlighter,
              size: 14,
              color: scheme.onSurfaceVariant,
            ),
            const SizedBox(width: 6),
            Expanded(
              child: Text(
                'Select text to save a highlight.',
                style: AppType.meta(scheme),
              ),
            ),
          ],
        ),
        if (highlights.isNotEmpty) ...[
          const SizedBox(height: 28),
          Text('Your highlights', style: AppType.sectionTitle(scheme)),
          const SizedBox(height: 12),
          for (final highlight in highlights) ...[
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: SpotifyColors.surface,
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: SpotifyColors.border),
              ),
              child: Text(
                highlight.text,
                style: AppType.body(
                  scheme,
                ).copyWith(fontStyle: FontStyle.italic, height: 1.5),
              ),
            ),
            const SizedBox(height: 10),
          ],
        ],
      ],
    );
  }
}

class _Pill extends StatelessWidget {
  const _Pill({required this.label, this.emphasized = false});

  final String label;
  final bool emphasized;

  @override
  Widget build(BuildContext context) {
    final color = emphasized ? SpotifyColors.accent : Colors.white;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.09),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: color.withValues(alpha: 0.22)),
      ),
      child: Text(label, style: AppType.tag(color)),
    );
  }
}

class _Dot extends StatelessWidget {
  const _Dot({required this.scheme});

  final ColorScheme scheme;

  @override
  Widget build(BuildContext context) {
    return Text('·', style: AppType.subtitle(scheme));
  }
}

class _ReadingSettingsSheet extends StatefulWidget {
  const _ReadingSettingsSheet({required this.initialScale});

  final double initialScale;

  @override
  State<_ReadingSettingsSheet> createState() => _ReadingSettingsSheetState();
}

class _ReadingSettingsSheetState extends State<_ReadingSettingsSheet> {
  late double _scale = widget.initialScale;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final readingStyle = AppType.reading(scheme);

    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Reading size', style: AppType.sectionTitle(scheme)),
            const SizedBox(height: 4),
            Text(
              'Adjust the text to suit how you read.',
              style: AppType.subtitle(scheme),
            ),
            const SizedBox(height: 14),
            Slider(
              key: const ValueKey('library-text-scale'),
              value: _scale,
              min: 0.85,
              max: 1.35,
              divisions: 10,
              label: '${(_scale * 100).round()}%',
              activeColor: SpotifyColors.accent,
              onChanged: (value) => setState(() => _scale = value),
            ),
            Container(
              width: double.infinity,
              margin: const EdgeInsets.only(top: 6, bottom: 18),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: SpotifyColors.background,
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: SpotifyColors.border),
              ),
              child: Text(
                'A comfortable reading size makes longer documents easier '
                'to follow.',
                style: readingStyle.copyWith(
                  fontSize: readingStyle.fontSize! * _scale,
                ),
              ),
            ),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: () => Navigator.of(context).pop(_scale),
                child: const Text('Done'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
