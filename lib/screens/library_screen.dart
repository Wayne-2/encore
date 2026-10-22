import 'dart:async';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../models/direct_chat.dart';
import '../models/group_chat.dart';
import '../models/library_material.dart';
import '../navigation/app_route.dart';
import '../services/auth_service.dart';
import '../services/chat_store.dart';
import '../services/library_import_service.dart';
import '../services/library_store.dart';
import '../theme/app_type.dart';
import '../theme/spotify_colors.dart';
import '../widgets/chat_avatar.dart';
import 'library_preview_screen.dart';

class LibraryScreen extends StatefulWidget {
  const LibraryScreen({super.key});

  @override
  State<LibraryScreen> createState() => _LibraryScreenState();
}

class _LibraryScreenState extends State<LibraryScreen> {
  static const List<String> _tabs = [
    'Public library',
    'Your lists',
    'Highlights',
    'Reading history',
  ];

  int _tab = 0;
  bool _uploading = false;
  final TextEditingController _search = TextEditingController();
  String _query = '';

  LibraryStore get _store => LibraryStore.instance;

  @override
  void initState() {
    super.initState();
    unawaited(_store.listen());
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  void _showSnack(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _pickAndUpload() async {
    if (_uploading) return;
    if (!AuthService.isAvailable || AuthService.instance.currentUser == null) {
      _showSnack('Sign in to publish a document.');
      return;
    }

    PlatformFile? file;
    try {
      file = await FilePicker.pickFile(
        dialogTitle: 'Choose a PDF or image',
        type: FileType.custom,
        allowedExtensions: const ['pdf', 'png', 'jpg', 'jpeg'],
      );
    } catch (_) {
      _showSnack('Could not open the file picker.');
      return;
    }
    if (file == null || !mounted) return;

    final details = await showModalBottomSheet<_PublishDetails>(
      context: context,
      backgroundColor: SpotifyColors.surface,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (context) => _PublishDetailsSheet(fileName: file!.name),
    );
    if (details == null || !mounted) return;

    final user = AuthService.instance.currentUser;
    final uploaderName = user?.displayName?.trim().isNotEmpty == true
        ? user!.displayName!.trim()
        : user?.email?.split('@').first ?? 'Encore student';

    setState(() => _uploading = true);
    try {
      final material = await LibraryImportService.instance.import(
        file: file,
        id: _store.newMaterialId(),
        uploaderId: user?.uid ?? '',
        uploaderName: uploaderName,
        title: details.title,
        subject: details.subject,
      );
      await _store.publish(material);
      if (!mounted) return;
      _search.clear();
      setState(() {
        _tab = 0;
        _query = '';
      });
      _showSnack('Published to the Public library.');
    } on LibraryImportException catch (error) {
      _showSnack(error.message);
    } catch (_) {
      _showSnack('Upload failed. Check your connection and try again.');
    } finally {
      if (mounted) setState(() => _uploading = false);
    }
  }

  void _openMaterial(LibraryMaterial material) {
    Navigator.of(
      context,
    ).push(sharedAxisRoute(LibraryPreviewScreen(material: material)));
  }

  LibraryMaterial? _materialById(String id) {
    for (final material in _store.materials) {
      if (material.id == id) return material;
    }
    return null;
  }

  void _showSavedList() {
    final scheme = Theme.of(context).colorScheme;
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: SpotifyColors.surface,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (sheetContext) {
        return FractionallySizedBox(
          heightFactor: 0.72,
          child: ListenableBuilder(
            listenable: _store,
            builder: (context, _) {
              final saved = _store.savedMaterials;
              return Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Saved list', style: AppType.sectionTitle(scheme)),
                    const SizedBox(height: 4),
                    Text(
                      saved.isEmpty
                          ? 'Save materials to find them here.'
                          : '${saved.length} saved '
                                '${saved.length == 1 ? 'material' : 'materials'}',
                      style: AppType.subtitle(scheme),
                    ),
                    const SizedBox(height: 16),
                    if (saved.isEmpty)
                      const Expanded(child: _SavedEmpty())
                    else
                      Expanded(
                        child: ListView.separated(
                          itemCount: saved.length,
                          separatorBuilder: (_, _) =>
                              const SizedBox(height: 10),
                          itemBuilder: (context, index) {
                            final material = saved[index];
                            return _MaterialTile(
                              material: material,
                              saved: true,
                              onTap: () {
                                Navigator.of(sheetContext).pop();
                                _openMaterial(material);
                              },
                              onToggleSaved: () => _toggleSaved(material.id),
                            );
                          },
                        ),
                      ),
                  ],
                ),
              );
            },
          ),
        );
      },
    );
  }

  Future<void> _toggleSaved(String materialId) async {
    try {
      await _store.toggleSaved(materialId);
      final saved = _store.isSaved(materialId);
      _showSnack(saved ? 'Saved to your list.' : 'Removed from Saved list.');
    } catch (_) {
      _showSnack("Couldn't update your saved list.");
    }
  }

  Future<void> _showMaterialActions(LibraryMaterial material) async {
    final scheme = Theme.of(context).colorScheme;
    final action = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: SpotifyColors.surface,
      showDragHandle: true,
      builder: (sheetContext) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(8, 0, 8, 10),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
                child: Text(
                  material.title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: AppType.name(scheme),
                ),
              ),
              const Divider(height: 1, color: SpotifyColors.border),
              ListTile(
                key: ValueKey('library-send-${material.id}'),
                leading: Icon(LucideIcons.send, color: scheme.onSurface),
                title: Text(
                  'Send in a chat',
                  style: AppType.body(
                    scheme,
                  ).copyWith(fontWeight: FontWeight.w600),
                ),
                subtitle: Text(
                  'Share this document in a direct or group chat.',
                  style: AppType.meta(scheme),
                ),
                onTap: () => Navigator.pop(sheetContext, 'send'),
              ),
              if (_store.canDelete(material))
                ListTile(
                  key: ValueKey('library-delete-${material.id}'),
                  leading: Icon(LucideIcons.trash2, color: scheme.onSurface),
                  title: Text(
                    'Delete document',
                    style: AppType.body(
                      scheme,
                    ).copyWith(fontWeight: FontWeight.w600),
                  ),
                  subtitle: Text(
                    'Removes it from the public library for everyone.',
                    style: AppType.meta(scheme),
                  ),
                  onTap: () => Navigator.pop(sheetContext, 'delete'),
                ),
              ListTile(
                leading: Icon(LucideIcons.x, color: scheme.onSurfaceVariant),
                title: Text('Cancel', style: AppType.body(scheme)),
                onTap: () => Navigator.pop(sheetContext),
              ),
            ],
          ),
        ),
      ),
    );
    if (!mounted || action == null) return;
    if (action == 'send') {
      await _showSharePicker(material);
    } else if (action == 'delete') {
      await _confirmDelete(material);
    }
  }

  Future<void> _showSharePicker(LibraryMaterial material) async {
    final target = await showModalBottomSheet<_LibraryShareTarget>(
      context: context,
      backgroundColor: SpotifyColors.surface,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (sheetContext) => _LibraryShareSheet(
        material: material,
        inbox: ChatStore.instance.watchInbox(),
      ),
    );
    if (target == null || !mounted) return;

    try {
      final direct = target.direct;
      if (direct != null) {
        await ChatStore.instance.sendLibraryMaterial(
          peer: direct.peer,
          materialId: material.id,
          title: material.title,
          subject: material.subject,
        );
      } else {
        final group = target.group;
        if (group == null) return;
        await ChatStore.instance.sendGroupLibraryMaterial(
          chatId: group.id,
          materialId: material.id,
          title: material.title,
          subject: material.subject,
        );
      }
      _showSnack('Sent to ${target.title}.');
    } catch (_) {
      _showSnack("Couldn't send that document. Try again.");
    }
  }

  Future<void> _confirmDelete(LibraryMaterial material) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: SpotifyColors.surface,
        title: const Text('Delete document?'),
        content: Text(
          '"${material.title}" will be removed from the public library.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            key: const ValueKey('library-delete-confirm'),
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    try {
      await _store.delete(material);
      _showSnack('Document deleted.');
    } on LibraryStoreException catch (error) {
      _showSnack(error.message);
    } catch (_) {
      _showSnack("Couldn't delete that document.");
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final canPop = Navigator.of(context).canPop();

    return ListenableBuilder(
      listenable: _store,
      builder: (context, _) {
        return Scaffold(
          backgroundColor: SpotifyColors.background,
          floatingActionButtonLocation: FloatingActionButtonLocation.startFloat,
          floatingActionButton: _uploading
              ? null
              : FloatingActionButton(
                  key: const ValueKey('library-upload'),
                  onPressed: _pickAndUpload,
                  tooltip: 'Publish a document',
                  backgroundColor: SpotifyColors.accent,
                  foregroundColor: Colors.white,
                  elevation: 2,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: const Icon(LucideIcons.upload, size: 22),
                ),
          body: Stack(
            children: [
              SafeArea(
                bottom: false,
                child: Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(4, 12, 20, 0),
                      child: Row(
                        children: [
                          if (canPop)
                            IconButton(
                              key: const ValueKey('library-back'),
                              onPressed: () => Navigator.of(context).maybePop(),
                              icon: const Icon(LucideIcons.chevronLeft),
                              iconSize: 17,
                              color: scheme.onSurface,
                              padding: EdgeInsets.zero,
                              constraints: const BoxConstraints.tightFor(
                                width: 28,
                                height: 40,
                              ),
                            )
                          else
                            const SizedBox(width: 16),
                          Expanded(
                            child: Text(
                              'Library',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: AppType.sectionTitle(
                                scheme,
                              ).copyWith(height: 1.1, letterSpacing: -0.2),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 14),
                    _LibraryTabs(
                      tabs: _tabs,
                      selected: _tab,
                      onSelected: (index) => setState(() => _tab = index),
                    ),
                    Expanded(child: _content(scheme)),
                  ],
                ),
              ),
              if (_uploading)
                Positioned.fill(
                  child: ColoredBox(
                    color: Colors.black.withValues(alpha: 0.55),
                    child: Center(
                      child: Container(
                        padding: const EdgeInsets.all(22),
                        decoration: BoxDecoration(
                          color: SpotifyColors.surface,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: SpotifyColors.border),
                        ),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const SizedBox(
                              width: 24,
                              height: 24,
                              child: CircularProgressIndicator(
                                strokeWidth: 2.5,
                                color: SpotifyColors.accent,
                              ),
                            ),
                            const SizedBox(height: 14),
                            Text(
                              'Building your document…',
                              style: AppType.body(scheme),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Extracting text, then publishing the doc. '
                              'The original file is not uploaded.',
                              textAlign: TextAlign.center,
                              style: AppType.meta(scheme),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }

  Widget _content(ColorScheme scheme) {
    return switch (_tab) {
      2 => _HighlightsTab(
        scheme: scheme,
        highlights: _store.highlights,
        onOpen: (highlight) {
          final material = _materialById(highlight.materialId);
          if (material == null) {
            _showSnack('That document is no longer in the public library.');
            return;
          }
          _openMaterial(material);
        },
      ),
      3 => _ReadingHistoryTab(
        scheme: scheme,
        entries: _store.history,
        onOpen: (entry) {
          final material = _materialById(entry.materialId);
          if (material == null) {
            _showSnack('That document is no longer in the public library.');
            return;
          }
          _openMaterial(material);
        },
      ),
      1 => _YourListsTab(
        scheme: scheme,
        savedMaterials: _store.savedMaterials,
        continueReading: _store.continueReading,
        onOpenSavedList: _showSavedList,
        onOpenMaterial: _openMaterial,
        onToggleSaved: _toggleSaved,
        onContinue: (entry) {
          final material = _materialById(entry.materialId);
          if (material == null) {
            _showSnack('That document is no longer in the public library.');
            return;
          }
          _openMaterial(material);
        },
      ),
      _ => _PublicLibraryTab(
        scheme: scheme,
        materials: _store.materials,
        query: _query,
        searchController: _search,
        onQueryChanged: (value) => setState(() => _query = value),
        onClearQuery: () {
          _search.clear();
          setState(() => _query = '');
        },
        isSaved: _store.isSaved,
        onOpenMaterial: _openMaterial,
        onToggleSaved: _toggleSaved,
        onLongPressMaterial: _showMaterialActions,
      ),
    };
  }
}

class _LibraryTabs extends StatelessWidget {
  const _LibraryTabs({
    required this.tabs,
    required this.selected,
    required this.onSelected,
  });

  final List<String> tabs;
  final int selected;
  final ValueChanged<int> onSelected;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Container(
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: SpotifyColors.border)),
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 20),
        child: Row(
          children: [
            for (var i = 0; i < tabs.length; i++)
              InkWell(
                key: ValueKey('library-tab-$i'),
                onTap: () => onSelected(i),
                child: Container(
                  padding: const EdgeInsets.fromLTRB(0, 12, 28, 12),
                  decoration: BoxDecoration(
                    border: Border(
                      bottom: BorderSide(
                        color: selected == i
                            ? scheme.onSurface
                            : Colors.transparent,
                        width: 2,
                      ),
                    ),
                  ),
                  child: Text(
                    tabs[i],
                    style: selected == i
                        ? AppType.cardTitle(
                            scheme,
                          ).copyWith(fontSize: 15, color: scheme.onSurface)
                        : AppType.subtitle(scheme).copyWith(
                            fontSize: 15,
                            color: scheme.onSurfaceVariant,
                          ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _PublicLibraryTab extends StatelessWidget {
  const _PublicLibraryTab({
    required this.scheme,
    required this.materials,
    required this.query,
    required this.searchController,
    required this.onQueryChanged,
    required this.onClearQuery,
    required this.isSaved,
    required this.onOpenMaterial,
    required this.onToggleSaved,
    required this.onLongPressMaterial,
  });

  final ColorScheme scheme;
  final List<LibraryMaterial> materials;
  final String query;
  final TextEditingController searchController;
  final ValueChanged<String> onQueryChanged;
  final VoidCallback onClearQuery;
  final bool Function(String id) isSaved;
  final ValueChanged<LibraryMaterial> onOpenMaterial;
  final ValueChanged<String> onToggleSaved;
  final ValueChanged<LibraryMaterial> onLongPressMaterial;

  @override
  Widget build(BuildContext context) {
    final query = this.query.trim().toLowerCase();
    final visible = query.isEmpty
        ? materials
        : [
            for (final material in materials)
              if (material.title.toLowerCase().contains(query) ||
                  material.subject.toLowerCase().contains(query) ||
                  material.uploaderName.toLowerCase().contains(query))
                material,
          ];

    return ListView(
      key: const ValueKey('library-public-list'),
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 96),
      children: [
        Text('Public library', style: AppType.sectionTitle(scheme)),
        const SizedBox(height: 4),
        Text(
          'Document uploads from the Encore community. Original files stay '
          'on the uploader’s device.',
          style: AppType.subtitle(scheme),
        ),
        const SizedBox(height: 14),
        _SearchField(
          scheme: scheme,
          controller: searchController,
          query: query,
          onChanged: onQueryChanged,
          onClear: onClearQuery,
        ),
        const SizedBox(height: 14),
        if (query.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Text(
              '${visible.length} ${visible.length == 1 ? 'result' : 'results'}',
              style: AppType.meta(scheme),
            ),
          ),
        if (materials.isEmpty)
          Text('No documents published yet.', style: AppType.subtitle(scheme))
        else if (visible.isEmpty)
          const _NoSearchResults()
        else
          for (var i = 0; i < visible.length; i++) ...[
            if (i > 0) const SizedBox(height: 10),
            _MaterialTile(
              material: visible[i],
              saved: isSaved(visible[i].id),
              onTap: () => onOpenMaterial(visible[i]),
              onToggleSaved: () => onToggleSaved(visible[i].id),
              onLongPress: () => onLongPressMaterial(visible[i]),
            ),
          ],
      ],
    );
  }
}

class _YourListsTab extends StatelessWidget {
  const _YourListsTab({
    required this.scheme,
    required this.savedMaterials,
    required this.continueReading,
    required this.onOpenSavedList,
    required this.onOpenMaterial,
    required this.onToggleSaved,
    required this.onContinue,
  });

  final ColorScheme scheme;
  final List<LibraryMaterial> savedMaterials;
  final LibraryHistoryEntry? continueReading;
  final VoidCallback onOpenSavedList;
  final ValueChanged<LibraryMaterial> onOpenMaterial;
  final ValueChanged<String> onToggleSaved;
  final ValueChanged<LibraryHistoryEntry> onContinue;

  @override
  Widget build(BuildContext context) {
    return ListView(
      key: const ValueKey('library-your-lists'),
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 96),
      children: [
        _SavedListCard(
          scheme: scheme,
          count: savedMaterials.length,
          recent: savedMaterials.take(3).toList(growable: false),
          onTap: onOpenSavedList,
        ),
        if (continueReading != null) ...[
          const SizedBox(height: 12),
          _ContinueCard(
            scheme: scheme,
            entry: continueReading!,
            onTap: () => onContinue(continueReading!),
          ),
        ],
        const SizedBox(height: 28),
        Text('Saved documents', style: AppType.sectionTitle(scheme)),
        const SizedBox(height: 4),
        Text(
          savedMaterials.isEmpty
              ? 'Save anything from the public library to keep it here.'
              : 'The documents you bookmarked from the public library.',
          style: AppType.subtitle(scheme),
        ),
        const SizedBox(height: 14),
        if (savedMaterials.isEmpty)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 28),
            child: _SavedEmpty(),
          )
        else
          for (var i = 0; i < savedMaterials.length; i++) ...[
            if (i > 0) const SizedBox(height: 10),
            _MaterialTile(
              material: savedMaterials[i],
              saved: true,
              onTap: () => onOpenMaterial(savedMaterials[i]),
              onToggleSaved: () => onToggleSaved(savedMaterials[i].id),
            ),
          ],
      ],
    );
  }
}

class _ContinueCard extends StatelessWidget {
  const _ContinueCard({
    required this.scheme,
    required this.entry,
    required this.onTap,
  });

  final ColorScheme scheme;
  final LibraryHistoryEntry entry;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final percent = (entry.progress * 100).round();
    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: SpotifyColors.surface,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: SpotifyColors.accent.withValues(alpha: 0.35)),
      ),
      child: InkWell(
        key: const ValueKey('library-continue'),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(
                    LucideIcons.bookOpen,
                    size: 15,
                    color: SpotifyColors.accent,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    'Continue reading',
                    style: AppType.tag(SpotifyColors.accent),
                  ),
                  const Spacer(),
                  Text('$percent%', style: AppType.meta(scheme)),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                entry.title,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: AppType.cardTitle(scheme).copyWith(height: 1.3),
              ),
              const SizedBox(height: 10),
              ClipRRect(
                borderRadius: BorderRadius.circular(2),
                child: LinearProgressIndicator(
                  value: entry.progress,
                  minHeight: 3,
                  backgroundColor: SpotifyColors.border,
                  color: SpotifyColors.accent,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SearchField extends StatelessWidget {
  const _SearchField({
    required this.scheme,
    required this.controller,
    required this.query,
    required this.onChanged,
    required this.onClear,
  });

  final ColorScheme scheme;
  final TextEditingController controller;
  final String query;
  final ValueChanged<String> onChanged;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    return TextField(
      key: const ValueKey('library-search'),
      controller: controller,
      onChanged: onChanged,
      cursorColor: SpotifyColors.accent,
      style: AppType.body(scheme).copyWith(color: scheme.onSurface),
      textInputAction: TextInputAction.search,
      decoration: InputDecoration(
        isDense: true,
        hintText: 'Search title, subject or uploader',
        hintStyle: AppType.subtitle(scheme),
        prefixIcon: Icon(
          LucideIcons.search,
          size: 17,
          color: scheme.onSurfaceVariant,
        ),
        suffixIcon: query.isEmpty
            ? null
            : IconButton(
                onPressed: onClear,
                icon: const Icon(LucideIcons.x, size: 16),
                color: scheme.onSurfaceVariant,
                tooltip: 'Clear search',
              ),
        filled: true,
        fillColor: SpotifyColors.surface,
        contentPadding: const EdgeInsets.symmetric(vertical: 12),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(6),
          borderSide: const BorderSide(color: SpotifyColors.border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(6),
          borderSide: const BorderSide(color: SpotifyColors.border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(6),
          borderSide: const BorderSide(color: SpotifyColors.borderStrong),
        ),
      ),
    );
  }
}

class _NoSearchResults extends StatelessWidget {
  const _NoSearchResults();

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(28),
      decoration: BoxDecoration(
        color: SpotifyColors.surface,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: SpotifyColors.border),
      ),
      child: Column(
        children: [
          Icon(LucideIcons.searchX, size: 24, color: scheme.onSurfaceVariant),
          const SizedBox(height: 10),
          Text('No matching documents', style: AppType.name(scheme)),
          const SizedBox(height: 4),
          Text(
            'Try a different title, subject or uploader.',
            textAlign: TextAlign.center,
            style: AppType.subtitle(scheme),
          ),
        ],
      ),
    );
  }
}

class _SavedListCard extends StatelessWidget {
  const _SavedListCard({
    required this.scheme,
    required this.count,
    required this.recent,
    required this.onTap,
  });

  final ColorScheme scheme;
  final int count;
  final List<LibraryMaterial> recent;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: SpotifyColors.surface,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: SpotifyColors.border),
      ),
      child: InkWell(
        key: const ValueKey('library-saved-banner'),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 14, 12, 14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: SpotifyColors.accent.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(
                      LucideIcons.bookmark,
                      size: 21,
                      color: SpotifyColors.accent,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Saved list', style: AppType.name(scheme)),
                        const SizedBox(height: 3),
                        Row(
                          children: [
                            Text(
                              count == 1 ? '1 material' : '$count materials',
                              style: AppType.subtitle(scheme),
                            ),
                            const SizedBox(width: 6),
                            Icon(
                              LucideIcons.lock,
                              size: 12,
                              color: scheme.onSurfaceVariant,
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  Icon(
                    LucideIcons.chevronRight,
                    size: 18,
                    color: scheme.onSurfaceVariant,
                  ),
                ],
              ),
              if (recent.isNotEmpty) ...[
                const SizedBox(height: 14),
                Text(
                  'RECENTLY SAVED',
                  style: AppType.tag(scheme.onSurfaceVariant),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final material in recent)
                      Container(
                        key: ValueKey('library-saved-preview-${material.id}'),
                        constraints: const BoxConstraints(maxWidth: 190),
                        padding: const EdgeInsets.fromLTRB(8, 6, 10, 6),
                        decoration: BoxDecoration(
                          color: SpotifyColors.accent.withValues(alpha: 0.08),
                          borderRadius: BorderRadius.circular(4),
                          border: Border.all(
                            color: SpotifyColors.accent.withValues(alpha: 0.22),
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              material.isPdf
                                  ? LucideIcons.fileText
                                  : LucideIcons.image,
                              size: 13,
                              color: SpotifyColors.accent,
                            ),
                            const SizedBox(width: 6),
                            Flexible(
                              child: Text(
                                material.title,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: AppType.meta(
                                  scheme,
                                ).copyWith(color: scheme.onSurface),
                              ),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _MaterialTile extends StatelessWidget {
  const _MaterialTile({
    required this.material,
    required this.saved,
    required this.onTap,
    required this.onToggleSaved,
    this.onLongPress,
  });

  final LibraryMaterial material;
  final bool saved;
  final VoidCallback onTap;
  final VoidCallback onToggleSaved;
  final VoidCallback? onLongPress;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final meta = [
      if (material.subjectLabel.isNotEmpty) material.subjectLabel,
      material.metaLabel,
    ].join(' · ');

    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: SpotifyColors.surface,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: SpotifyColors.border),
      ),
      child: InkWell(
        key: ValueKey('library-material-${material.id}'),
        onTap: onTap,
        onLongPress: onLongPress,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 12, 4, 12),
          child: Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: SpotifyColors.accent.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Icon(
                  material.isPdf ? LucideIcons.fileText : LucideIcons.image,
                  size: 20,
                  color: SpotifyColors.accent,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      material.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: AppType.cardTitle(scheme).copyWith(height: 1.25),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      meta,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppType.subtitle(scheme),
                    ),
                    if (material.uploaderName.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(
                        'Published by ${material.uploaderName}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppType.meta(scheme),
                      ),
                    ],
                  ],
                ),
              ),
              IconButton(
                key: ValueKey('library-material-save-${material.id}'),
                onPressed: onToggleSaved,
                icon: Icon(
                  saved ? LucideIcons.bookmarkCheck : LucideIcons.bookmark,
                ),
                iconSize: 19,
                color: saved ? SpotifyColors.accent : scheme.onSurfaceVariant,
                tooltip: saved ? 'Remove from Saved list' : 'Save material',
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints.tightFor(
                  width: 40,
                  height: 40,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _HighlightsTab extends StatelessWidget {
  const _HighlightsTab({
    required this.scheme,
    required this.highlights,
    required this.onOpen,
  });

  final ColorScheme scheme;
  final List<LibraryHighlight> highlights;
  final ValueChanged<LibraryHighlight> onOpen;

  @override
  Widget build(BuildContext context) {
    if (highlights.isEmpty) {
      return const _EmptyTab(
        icon: LucideIcons.highlighter,
        title: 'No highlights yet',
        body: 'Open a document, select a passage, then tap Highlight.',
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 96),
      itemCount: highlights.length,
      separatorBuilder: (_, _) => const SizedBox(height: 12),
      itemBuilder: (context, index) {
        final highlight = highlights[index];
        return InkWell(
          onTap: () => onOpen(highlight),
          borderRadius: BorderRadius.circular(6),
          child: Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: SpotifyColors.surface,
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: SpotifyColors.border),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  highlight.text,
                  style: AppType.body(scheme).copyWith(
                    color: scheme.onSurface,
                    fontStyle: FontStyle.italic,
                    height: 1.45,
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        highlight.materialTitle,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppType.subtitle(
                          scheme,
                        ).copyWith(fontWeight: FontWeight.w600),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      _relativeTime(highlight.createdAt),
                      style: AppType.timestamp(scheme),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _ReadingHistoryTab extends StatelessWidget {
  const _ReadingHistoryTab({
    required this.scheme,
    required this.entries,
    required this.onOpen,
  });

  final ColorScheme scheme;
  final List<LibraryHistoryEntry> entries;
  final ValueChanged<LibraryHistoryEntry> onOpen;

  @override
  Widget build(BuildContext context) {
    if (entries.isEmpty) {
      return const _EmptyTab(
        icon: LucideIcons.history,
        title: 'Nothing read yet',
        body: 'Documents you open will appear here.',
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 96),
      itemCount: entries.length,
      separatorBuilder: (_, _) => const SizedBox(height: 12),
      itemBuilder: (context, index) {
        final entry = entries[index];
        return InkWell(
          onTap: () => onOpen(entry),
          borderRadius: BorderRadius.circular(6),
          child: Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: SpotifyColors.surface,
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: SpotifyColors.border),
            ),
            child: Row(
              children: [
                Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    color: SpotifyColors.accent.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Icon(
                    entry.kind == LibraryMaterialKind.pdf
                        ? LucideIcons.fileText
                        : LucideIcons.image,
                    size: 20,
                    color: SpotifyColors.accent,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        entry.title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: AppType.name(scheme).copyWith(height: 1.3),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        entry.progress >= 0.98
                            ? 'Finished · ${_relativeTime(entry.lastReadAt)}'
                            : '${(entry.progress * 100).round()}% read · '
                                  '${_relativeTime(entry.lastReadAt)}',
                        style: AppType.timestamp(scheme),
                      ),
                      const SizedBox(height: 8),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(2),
                        child: LinearProgressIndicator(
                          value: entry.progress,
                          minHeight: 3,
                          backgroundColor: SpotifyColors.border,
                          color: entry.progress >= 0.98
                              ? SpotifyColors.textSubdued
                              : SpotifyColors.accent,
                        ),
                      ),
                    ],
                  ),
                ),
                Icon(
                  LucideIcons.chevronRight,
                  size: 18,
                  color: scheme.onSurfaceVariant,
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _EmptyTab extends StatelessWidget {
  const _EmptyTab({
    required this.icon,
    required this.title,
    required this.body,
  });

  final IconData icon;
  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 30, color: scheme.onSurfaceVariant),
            const SizedBox(height: 14),
            Text(title, style: AppType.name(scheme)),
            const SizedBox(height: 6),
            Text(
              body,
              textAlign: TextAlign.center,
              style: AppType.subtitle(scheme),
            ),
          ],
        ),
      ),
    );
  }
}

class _SavedEmpty extends StatelessWidget {
  const _SavedEmpty();

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(LucideIcons.bookmark, size: 28, color: scheme.onSurfaceVariant),
          const SizedBox(height: 12),
          Text('Your Saved list is empty', style: AppType.name(scheme)),
          const SizedBox(height: 6),
          Text(
            'Tap the bookmark on any public document.',
            textAlign: TextAlign.center,
            style: AppType.subtitle(scheme),
          ),
        ],
      ),
    );
  }
}

class _PublishDetails {
  const _PublishDetails({required this.title, required this.subject});

  final String title;
  final String subject;
}

class _PublishDetailsSheet extends StatefulWidget {
  const _PublishDetailsSheet({required this.fileName});

  final String fileName;

  @override
  State<_PublishDetailsSheet> createState() => _PublishDetailsSheetState();
}

class _PublishDetailsSheetState extends State<_PublishDetailsSheet> {
  late final TextEditingController _title = TextEditingController(
    text: _titleFromFile(widget.fileName),
  );
  final TextEditingController _subject = TextEditingController();

  @override
  void dispose() {
    _title.dispose();
    _subject.dispose();
    super.dispose();
  }

  void _publish() {
    final title = _title.text.trim();
    if (title.isEmpty) return;
    Navigator.of(
      context,
    ).pop(_PublishDetails(title: title, subject: _subject.text.trim()));
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final canPublish = _title.text.trim().isNotEmpty;

    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: SafeArea(
        top: false,
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Publish document', style: AppType.sectionTitle(scheme)),
              const SizedBox(height: 4),
              Text(
                'We extract the text and publish it as a readable document. '
                'Your original file is never uploaded or stored.',
                style: AppType.subtitle(scheme),
              ),
              const SizedBox(height: 18),
              _FieldLabel(label: 'Title', scheme: scheme),
              const SizedBox(height: 6),
              TextField(
                key: const ValueKey('library-publish-title'),
                controller: _title,
                onChanged: (_) => setState(() {}),
                maxLength: 200,
                cursorColor: SpotifyColors.accent,
                style: AppType.body(scheme).copyWith(color: scheme.onSurface),
                decoration: _inputDecoration(
                  scheme,
                  hint: 'e.g. CSC 200 Data Structures Notes',
                ),
              ),
              const SizedBox(height: 10),
              _FieldLabel(label: 'Subject (optional)', scheme: scheme),
              const SizedBox(height: 6),
              TextField(
                key: const ValueKey('library-publish-subject'),
                controller: _subject,
                maxLength: 40,
                cursorColor: SpotifyColors.accent,
                style: AppType.body(scheme).copyWith(color: scheme.onSurface),
                decoration: _inputDecoration(scheme, hint: 'e.g. CSC 200'),
              ),
              const SizedBox(height: 12),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: SpotifyColors.accent.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(
                    color: SpotifyColors.accent.withValues(alpha: 0.2),
                  ),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(
                      LucideIcons.shieldCheck,
                      size: 16,
                      color: SpotifyColors.accent,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Only the extracted text is published. The source '
                        '${widget.fileName} stays on your device.',
                        style: AppType.meta(scheme),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 18),
              Row(
                children: [
                  Expanded(
                    child: TextButton(
                      onPressed: () => Navigator.of(context).pop(),
                      child: const Text('Cancel'),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: FilledButton(
                      key: const ValueKey('library-publish-confirm'),
                      onPressed: canPublish ? _publish : null,
                      child: const Text('Publish'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _FieldLabel extends StatelessWidget {
  const _FieldLabel({required this.label, required this.scheme});

  final String label;
  final ColorScheme scheme;

  @override
  Widget build(BuildContext context) {
    return Text(label, style: AppType.subtitle(scheme));
  }
}

InputDecoration _inputDecoration(ColorScheme scheme, {required String hint}) {
  return InputDecoration(
    isDense: true,
    hintText: hint,
    hintStyle: AppType.subtitle(scheme),
    counterStyle: AppType.meta(scheme),
    filled: true,
    fillColor: SpotifyColors.surface,
    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(6),
      borderSide: const BorderSide(color: SpotifyColors.border),
    ),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(6),
      borderSide: const BorderSide(color: SpotifyColors.border),
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(6),
      borderSide: const BorderSide(color: SpotifyColors.borderStrong),
    ),
  );
}

String _titleFromFile(String fileName) {
  final withoutExtension = fileName.replaceFirst(RegExp(r'\.[^.]+$'), '');
  final spaced = withoutExtension.replaceAll(RegExp(r'[_-]+'), ' ').trim();
  return spaced.isEmpty ? 'Untitled document' : spaced;
}

String _relativeTime(DateTime? date) {
  if (date == null) return '';
  final diff = DateTime.now().difference(date);
  if (diff.inMinutes < 1) return 'Just now';
  if (diff.inMinutes < 60) return '${diff.inMinutes} min ago';
  if (diff.inHours < 24) return '${diff.inHours} hr ago';
  if (diff.inDays < 7) {
    return '${diff.inDays} ${diff.inDays == 1 ? 'day' : 'days'} ago';
  }
  const months = [
    'Jan',
    'Feb',
    'Mar',
    'Apr',
    'May',
    'Jun',
    'Jul',
    'Aug',
    'Sep',
    'Oct',
    'Nov',
    'Dec',
  ];
  return '${months[date.month - 1]} ${date.day}, ${date.year}';
}

/// A direct chat or group selected from the library share sheet.
class _LibraryShareTarget {
  const _LibraryShareTarget.direct(DirectChat this.direct) : group = null;

  const _LibraryShareTarget.group(GroupChat this.group) : direct = null;

  final DirectChat? direct;
  final GroupChat? group;

  String get title => direct?.peer.displayName ?? group?.title ?? 'chat';
}

/// Bottom sheet listing the signed-in user's direct chats and groups.
class _LibraryShareSheet extends StatelessWidget {
  const _LibraryShareSheet({required this.material, required this.inbox});

  final LibraryMaterial material;
  final Stream<ChatInbox> inbox;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final height = MediaQuery.sizeOf(context).height * 0.68;

    return SafeArea(
      top: false,
      child: SizedBox(
        height: height,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Send to a chat', style: AppType.sectionTitle(scheme)),
                  const SizedBox(height: 3),
                  Text(
                    material.title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: AppType.meta(scheme),
                  ),
                ],
              ),
            ),
            const Divider(height: 1, color: SpotifyColors.border),
            Expanded(
              child: StreamBuilder<ChatInbox>(
                stream: inbox,
                builder: (context, snapshot) {
                  final data = snapshot.data ?? ChatInbox.empty;
                  final direct = data.directChats;
                  final groups = data.groups;
                  if (direct.isEmpty && groups.isEmpty) {
                    return Center(
                      child: Padding(
                        padding: const EdgeInsets.all(24),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              LucideIcons.messagesSquare,
                              size: 26,
                              color: scheme.onSurfaceVariant,
                            ),
                            const SizedBox(height: 10),
                            Text('No chats yet', style: AppType.name(scheme)),
                            const SizedBox(height: 4),
                            Text(
                              'Start a conversation from Messages, then share '
                              'documents from here.',
                              textAlign: TextAlign.center,
                              style: AppType.meta(scheme),
                            ),
                          ],
                        ),
                      ),
                    );
                  }

                  return ListView(
                    padding: const EdgeInsets.fromLTRB(8, 8, 8, 12),
                    children: [
                      if (direct.isNotEmpty) ...[
                        _sectionLabel('Direct messages', scheme),
                        for (final chat in direct)
                          _tile(
                            context,
                            key: ValueKey('library-share-dm-${chat.id}'),
                            title: chat.peer.displayName,
                            subtitle: chat.peer.handle,
                            avatar: ChatAvatar(
                              avatarUrl: chat.peer.photoUrl,
                              avatarColor: chat.peer.avatarColor,
                              avatarInitials: chat.peer.initials,
                              size: 38,
                              borderRadius: BorderRadius.circular(6),
                            ),
                            onTap: () => Navigator.pop(
                              context,
                              _LibraryShareTarget.direct(chat),
                            ),
                          ),
                      ],
                      if (groups.isNotEmpty) ...[
                        _sectionLabel('Group chats', scheme),
                        for (final group in groups)
                          _tile(
                            context,
                            key: ValueKey('library-share-group-${group.id}'),
                            title: group.title,
                            subtitle:
                                '${group.memberCount} '
                                '${group.memberCount == 1 ? 'member' : 'members'}',
                            avatar: ChatAvatar(
                              avatarUrl: group.photoUrl,
                              avatarColor: group.avatarColor,
                              avatarInitials: group.initials,
                              size: 38,
                              borderRadius: BorderRadius.circular(6),
                            ),
                            onTap: () => Navigator.pop(
                              context,
                              _LibraryShareTarget.group(group),
                            ),
                          ),
                      ],
                    ],
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _sectionLabel(String label, ColorScheme scheme) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 4),
      child: Text(label, style: AppType.meta(scheme)),
    );
  }

  Widget _tile(
    BuildContext context, {
    required Key key,
    required String title,
    required String subtitle,
    required Widget avatar,
    required VoidCallback onTap,
  }) {
    final scheme = Theme.of(context).colorScheme;
    return ListTile(
      key: key,
      leading: avatar,
      title: Text(
        title,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: AppType.body(scheme).copyWith(fontWeight: FontWeight.w600),
      ),
      subtitle: Text(
        subtitle,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: AppType.meta(scheme),
      ),
      trailing: Icon(LucideIcons.send, size: 18, color: SpotifyColors.accent),
      onTap: onTap,
    );
  }
}
