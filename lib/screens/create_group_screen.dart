import 'package:flutter/material.dart';

import '../models/direct_chat.dart';
import '../navigation/app_route.dart';
import '../services/chat_store.dart';
import '../theme/app_theme.dart';
import '../theme/app_type.dart';
import '../theme/spotify_colors.dart';
import '../widgets/app_loader.dart';
import '../widgets/chat_avatar.dart';
import '../widgets/floating_empty_state.dart';
import '../widgets/workspace_app_bar.dart';
import 'persistent_group_chat_screen.dart';

/// Picks members and creates a Firestore-backed group with the current user
/// as its first admin.
class CreateGroupScreen extends StatefulWidget {
  const CreateGroupScreen({super.key, this.users});

  /// Injectable member list used by widget tests.
  final Stream<List<ChatUser>>? users;

  @override
  State<CreateGroupScreen> createState() => _CreateGroupScreenState();
}

class _CreateGroupScreenState extends State<CreateGroupScreen> {
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _searchController = TextEditingController();
  late final Stream<List<ChatUser>> _users =
      widget.users ?? ChatStore.instance.watchUsers();
  final Map<String, ChatUser> _selected = {};
  bool _creating = false;
  String _query = '';

  @override
  void dispose() {
    _nameController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  bool get _canCreate =>
      !_creating &&
      _nameController.text.trim().isNotEmpty &&
      _selected.isNotEmpty;

  bool _matches(ChatUser user) {
    final query = _query.trim().toLowerCase();
    if (query.isEmpty) return true;
    return user.displayName.toLowerCase().contains(query) ||
        user.username.toLowerCase().contains(query) ||
        (user.level ?? '').toLowerCase().contains(query);
  }

  void _toggle(ChatUser user) {
    setState(() {
      if (_selected.containsKey(user.id)) {
        _selected.remove(user.id);
      } else {
        _selected[user.id] = user;
      }
    });
  }

  Future<void> _create() async {
    if (!_canCreate) return;
    setState(() => _creating = true);
    try {
      final group = await ChatStore.instance.createGroup(
        title: _nameController.text,
        members: _selected.values.toList(growable: false),
      );
      if (!mounted) return;
      await Navigator.of(context).pushReplacement(
        sharedAxisRoute<void>(
          PersistentGroupChatScreen(chatId: group.id, initialGroup: group),
        ),
      );
    } catch (error) {
      if (!mounted) return;
      setState(() => _creating = false);
      final message = error is StateError
          ? error.message
          : 'Could not create the group. Check your connection.';
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text(message)));
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Scaffold(
      backgroundColor: SpotifyColors.background,
      body: Column(
        children: [
          WorkspaceAppBar(
            heading: 'New group',
            title: 'Choose people and give it a name',
            headingSize: 18,
            leading: IconButton(
              onPressed: () => Navigator.maybePop(context),
              icon: const Icon(Icons.arrow_back_rounded, size: 22),
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints.tightFor(width: 28, height: 28),
              visualDensity: VisualDensity.compact,
              color: scheme.onSurface,
              tooltip: 'Back',
            ),
            trailing: TextButton(
              key: const ValueKey('create-group-submit'),
              onPressed: _canCreate ? _create : null,
              child: _creating
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: SpotifyColors.accent,
                      ),
                    )
                  : Text(
                      'Create',
                      style: TextStyle(
                        fontFamily: AppTheme.fontFamily,
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: _canCreate
                            ? SpotifyColors.accent
                            : SpotifyColors.accent.withValues(alpha: 0.4),
                      ),
                    ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
            child: TextField(
              key: const ValueKey('create-group-name'),
              controller: _nameController,
              maxLength: 80,
              textCapitalization: TextCapitalization.words,
              onChanged: (_) => setState(() {}),
              style: TextStyle(
                fontFamily: AppTheme.fontFamily,
                color: scheme.onSurface,
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
              decoration: InputDecoration(
                hintText: 'Group name',
                counterText: '',
                hintStyle: TextStyle(
                  fontFamily: AppTheme.fontFamily,
                  color: scheme.onSurfaceVariant,
                  fontSize: 16,
                ),
                prefixIcon: Icon(
                  Icons.groups_rounded,
                  color: SpotifyColors.accent,
                  size: 22,
                ),
                filled: true,
                fillColor: SpotifyColors.surface,
                contentPadding: const EdgeInsets.symmetric(vertical: 14),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
          ),
          if (_selected.isNotEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final member in _selected.values)
                      InputChip(
                        key: ValueKey('group-selected-${member.id}'),
                        avatar: ChatAvatar(
                          avatarUrl: member.photoUrl,
                          avatarColor: member.avatarColor,
                          avatarInitials: member.initials,
                          size: 24,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        label: Text(
                          member.username.trim().isNotEmpty
                              ? member.username
                              : member.displayName,
                          style: const TextStyle(
                            fontFamily: AppTheme.fontFamily,
                            fontSize: 12.5,
                            color: Colors.white,
                          ),
                        ),
                        backgroundColor: SpotifyColors.surface,
                        side: const BorderSide(color: SpotifyColors.border),
                        onDeleted: () => _toggle(member),
                        deleteIconColor: scheme.onSurfaceVariant,
                      ),
                  ],
                ),
              ),
            ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            child: TextField(
              key: const ValueKey('create-group-search'),
              controller: _searchController,
              onChanged: (value) => setState(() => _query = value),
              textInputAction: TextInputAction.search,
              style: TextStyle(
                fontFamily: AppTheme.fontFamily,
                color: scheme.onSurface,
                fontSize: 14,
              ),
              decoration: InputDecoration(
                hintText: 'Search people',
                hintStyle: TextStyle(
                  fontFamily: AppTheme.fontFamily,
                  color: scheme.onSurfaceVariant,
                  fontSize: 14,
                ),
                prefixIcon: Icon(
                  Icons.search_rounded,
                  color: scheme.onSurfaceVariant,
                  size: 20,
                ),
                filled: true,
                fillColor: SpotifyColors.surface,
                contentPadding: const EdgeInsets.symmetric(vertical: 10),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 6),
            child: Row(
              children: [
                Text(
                  _selected.isEmpty
                      ? 'Members'
                      : '${_selected.length} selected',
                  style: AppType.meta(scheme).copyWith(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.4,
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: StreamBuilder<List<ChatUser>>(
              stream: _users,
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return const Center(
                    child: Padding(
                      padding: EdgeInsets.all(24),
                      child: Text(
                        'Could not load people. Check your connection.',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontFamily: AppTheme.fontFamily,
                          color: Colors.white70,
                        ),
                      ),
                    ),
                  );
                }
                if (!snapshot.hasData) {
                  return const Center(child: AppLoader());
                }

                final users = snapshot.data!
                    .where(_matches)
                    .toList(growable: false);
                if (users.isEmpty) {
                  return Center(
                    child: FloatingEmptyState(
                      key: const ValueKey('create-group-empty'),
                      icon: Icons.person_search_outlined,
                      message: _query.trim().isEmpty
                          ? 'No other members yet.'
                          : 'No people match “${_query.trim()}”.',
                    ),
                  );
                }

                return ListView.separated(
                  padding: const EdgeInsets.only(bottom: 28),
                  itemCount: users.length,
                  separatorBuilder: (_, _) => const Divider(
                    height: 1,
                    thickness: 1,
                    indent: 72,
                    color: SpotifyColors.border,
                  ),
                  itemBuilder: (context, index) {
                    final user = users[index];
                    final selected = _selected.containsKey(user.id);
                    return CheckboxListTile(
                      key: ValueKey('group-member-${user.id}'),
                      value: selected,
                      onChanged: (_) => _toggle(user),
                      controlAffinity: ListTileControlAffinity.trailing,
                      activeColor: SpotifyColors.accent,
                      checkColor: Colors.white,
                      secondary: ChatAvatar(
                        avatarUrl: user.photoUrl,
                        avatarColor: user.avatarColor,
                        avatarInitials: user.initials,
                        size: 40,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      title: Text(
                        user.displayName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontFamily: AppTheme.fontFamily,
                          fontSize: 14.5,
                          fontWeight: FontWeight.w600,
                          color: scheme.onSurface,
                        ),
                      ),
                      subtitle: Text(
                        user.handle,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontFamily: AppTheme.fontFamily,
                          fontSize: 12,
                          color: SpotifyColors.accent,
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
