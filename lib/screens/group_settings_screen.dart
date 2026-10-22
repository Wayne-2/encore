import 'dart:async';

import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';

import '../models/direct_chat.dart';
import '../models/group_chat.dart';
import '../navigation/app_route.dart';
import '../services/auth_service.dart';
import '../services/chat_store.dart';
import '../theme/app_theme.dart';
import '../theme/app_type.dart';
import '../theme/spotify_colors.dart';
import '../widgets/app_loader.dart';
import '../widgets/chat_avatar.dart';
import 'image_crop_screen.dart';

/// Admin-controlled group settings: permissions, members, admins and info.
class GroupSettingsScreen extends StatefulWidget {
  const GroupSettingsScreen({
    super.key,
    required this.chatId,
    this.initialGroup,
    this.groupStream,
    this.usersStream,
    this.myUid,
  });

  final String chatId;
  final GroupChat? initialGroup;
  final Stream<GroupChat?>? groupStream;
  final Stream<List<ChatUser>>? usersStream;

  /// Test override; defaults to the signed-in Firebase user.
  final String? myUid;

  @override
  State<GroupSettingsScreen> createState() => _GroupSettingsScreenState();
}

class _GroupSettingsScreenState extends State<GroupSettingsScreen> {
  final TextEditingController _searchController = TextEditingController();
  StreamSubscription<GroupChat?>? _subscription;

  late GroupChat? _group = widget.initialGroup;
  late final Stream<List<ChatUser>> _users =
      widget.usersStream ?? ChatStore.instance.watchUsers();
  bool _busy = false;
  String _query = '';

  String get _myUid =>
      widget.myUid ?? AuthService.instance.currentUser?.uid ?? '';

  bool get _isAdmin => _group?.isAdmin(_myUid) ?? false;

  bool get _canAddMembers =>
      _isAdmin || (_group?.membersCanAddMembers ?? false);

  @override
  void initState() {
    super.initState();
    final source =
        widget.groupStream ??
        (ChatStore.instance.isEnabled
            ? ChatStore.instance.watchGroup(widget.chatId)
            : null);
    _subscription = source?.listen((group) {
      if (mounted) setState(() => _group = group);
    }, onError: (Object _) {});
  }

  @override
  void dispose() {
    _subscription?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  void _showSnack(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _run(
    Future<void> Function() action, {
    String? success,
    bool closeOnSuccess = false,
  }) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      await action();
      if (!mounted) return;
      if (closeOnSuccess) {
        Navigator.pop(context, true);
        return;
      }
      if (success != null) _showSnack(success);
    } on StateError catch (error) {
      _showSnack(error.message);
    } catch (_) {
      _showSnack('Could not update this group. Check your connection.');
    } finally {
      if (mounted && !closeOnSuccess) setState(() => _busy = false);
    }
  }

  Future<void> _saveSetting(
    Future<void> Function() action, {
    required String success,
  }) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      await action();
      if (mounted) _showSnack(success);
    } on StateError catch (error) {
      _showSnack(error.message);
    } catch (_) {
      _showSnack('Could not change that setting.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _editInfo() async {
    final group = _group;
    if (group == null || !_isAdmin) return;
    final title = TextEditingController(text: group.title);
    final description = TextEditingController(text: group.description);
    final result = await showDialog<({String title, String description})>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: SpotifyColors.surface,
        title: const Text('Edit group info'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                key: const ValueKey('group-settings-name-input'),
                controller: title,
                maxLength: 80,
                textCapitalization: TextCapitalization.words,
                decoration: const InputDecoration(
                  labelText: 'Group name',
                  counterText: '',
                ),
              ),
              const SizedBox(height: 8),
              TextField(
                key: const ValueKey('group-settings-description-input'),
                controller: description,
                maxLines: 4,
                maxLength: 500,
                decoration: const InputDecoration(
                  labelText: 'Description',
                  hintText: 'What is this group about?',
                  counterText: '',
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, (
              title: title.text.trim(),
              description: description.text.trim(),
            )),
            child: const Text('Save'),
          ),
        ],
      ),
    );
    title.dispose();
    description.dispose();
    if (result == null) return;
    await _run(
      () => ChatStore.instance.updateGroupSettings(
        chatId: widget.chatId,
        title: result.title,
        description: result.description,
      ),
      success: 'Group info updated',
    );
  }

  Future<ImageSource?> _choosePhotoSource() {
    return showModalBottomSheet<ImageSource>(
      context: context,
      backgroundColor: SpotifyColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
      ),
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(LucideIcons.image),
              title: const Text('Choose from gallery'),
              onTap: () => Navigator.pop(context, ImageSource.gallery),
            ),
            ListTile(
              leading: const Icon(LucideIcons.camera),
              title: const Text('Take a photo'),
              onTap: () => Navigator.pop(context, ImageSource.camera),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _changePhoto() async {
    if (!_isAdmin || _busy) return;
    try {
      final source = await _choosePhotoSource();
      if (source == null || !mounted) return;
      final picked = await ImagePicker().pickImage(
        source: source,
        imageQuality: 85,
        maxWidth: 1080,
      );
      if (picked == null || !mounted) return;
      final bytes = await picked.readAsBytes();
      if (!mounted) return;
      final cropped = await Navigator.of(context).push<Uint8List>(
        sharedAxisRoute<Uint8List>(ImageCropScreen(image: bytes)),
      );
      if (cropped == null || !mounted) return;
      await _run(
        () => ChatStore.instance.updateGroupPhoto(
          chatId: widget.chatId,
          bytes: cropped,
          filename: picked.name,
        ),
        success: 'Group photo updated',
      );
    } on PlatformException {
      _showSnack('Could not open your photos. Check app permissions.');
    } catch (_) {
      _showSnack('Could not update the group photo.');
    }
  }

  Future<void> _addMembers() async {
    final group = _group;
    if (group == null) return;
    final selected = await showModalBottomSheet<List<ChatUser>>(
      context: context,
      isScrollControlled: true,
      backgroundColor: SpotifyColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
      ),
      builder: (context) => AddGroupMembersSheet(
        users: _users,
        existingIds: group.members.toSet(),
      ),
    );
    if (selected == null || selected.isEmpty) return;
    await _run(
      () => ChatStore.instance.addGroupMembers(
        chatId: widget.chatId,
        members: selected,
      ),
      success:
          '${selected.length} ${selected.length == 1 ? 'person' : 'people'} added',
    );
  }

  Future<void> _openMemberActions(ChatUser member) async {
    final group = _group;
    if (group == null) return;
    final isMe = member.id == _myUid;
    if (!_isAdmin && !isMe) return;

    final isAdmin = group.isAdmin(member.id);
    final action = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: SpotifyColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
      ),
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: ChatAvatar(
                avatarUrl: member.photoUrl,
                avatarColor: member.avatarColor,
                avatarInitials: member.initials,
                size: 42,
                borderRadius: BorderRadius.circular(6),
              ),
              title: Text(isMe ? 'You' : member.displayName),
              subtitle: Text(member.handle),
            ),
            const Divider(height: 1, color: SpotifyColors.border),
            if (!isMe && _isAdmin)
              ListTile(
                key: ValueKey(
                  isAdmin
                      ? 'group-member-demote-${member.id}'
                      : 'group-member-promote-${member.id}',
                ),
                leading: Icon(
                  isAdmin ? LucideIcons.shieldOff : LucideIcons.shieldCheck,
                ),
                title: Text(isAdmin ? 'Dismiss as admin' : 'Make group admin'),
                onTap: () =>
                    Navigator.pop(context, isAdmin ? 'demote' : 'promote'),
              ),
            if (!isMe && _isAdmin)
              ListTile(
                key: ValueKey('group-member-remove-${member.id}'),
                leading: const Icon(LucideIcons.userMinus),
                title: const Text('Remove from group'),
                onTap: () => Navigator.pop(context, 'remove'),
              ),
            if (isMe)
              ListTile(
                key: const ValueKey('group-settings-leave-member'),
                leading: const Icon(LucideIcons.logOut),
                title: const Text('Leave group'),
                onTap: () => Navigator.pop(context, 'leave'),
              ),
          ],
        ),
      ),
    );
    if (!mounted || action == null) return;

    switch (action) {
      case 'promote':
        await _saveSetting(
          () => ChatStore.instance.setGroupAdmin(
            chatId: widget.chatId,
            memberId: member.id,
            admin: true,
          ),
          success: '${member.displayName} is now an admin',
        );
      case 'demote':
        await _saveSetting(
          () => ChatStore.instance.setGroupAdmin(
            chatId: widget.chatId,
            memberId: member.id,
            admin: false,
          ),
          success: '${member.displayName} is no longer an admin',
        );
      case 'remove':
        final confirmed = await _confirm(
          title: 'Remove ${member.displayName}?',
          body:
              'They will lose access to this group. Their previous messages '
              'remain visible.',
          confirmLabel: 'Remove',
        );
        if (!confirmed) return;
        await _saveSetting(
          () => ChatStore.instance.removeGroupMember(widget.chatId, member.id),
          success: '${member.displayName} was removed',
        );
      case 'leave':
        await _leaveGroup();
    }
  }

  Future<bool> _confirm({
    required String title,
    required String body,
    String confirmLabel = 'Continue',
  }) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: SpotifyColors.surface,
        title: Text(title),
        content: Text(body),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(confirmLabel),
          ),
        ],
      ),
    );
    return result == true;
  }

  Future<void> _leaveGroup() async {
    final group = _group;
    if (group == null) return;
    final confirmed = await _confirm(
      title: 'Leave ${group.title}?',
      body: _isAdmin && group.adminIds.length == 1 && group.memberCount > 1
          ? 'You are the last admin. Another member will be promoted '
                'automatically. You can only rejoin if someone adds you back.'
          : 'You will stop receiving messages from this group.',
      confirmLabel: 'Leave',
    );
    if (!confirmed) return;
    await _run(
      () => ChatStore.instance.leaveGroup(widget.chatId),
      closeOnSuccess: true,
    );
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final group = _group;

    return Scaffold(
      key: const ValueKey('group-settings-screen'),
      backgroundColor: SpotifyColors.background,
      appBar: AppBar(
        backgroundColor: SpotifyColors.background,
        elevation: 0,
        title: Text(
          'Group settings',
          style: TextStyle(
            fontFamily: AppTheme.fontFamily,
            fontSize: 18,
            fontWeight: FontWeight.w700,
            color: scheme.onSurface,
          ),
        ),
        actions: [
          if (_busy)
            const Padding(
              padding: EdgeInsets.only(right: 18),
              child: Center(
                child: SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: SpotifyColors.accent,
                  ),
                ),
              ),
            ),
        ],
      ),
      body: group == null
          ? const Center(child: AppLoader())
          : ListView(
              padding: const EdgeInsets.only(bottom: 32),
              children: [
                _buildHeader(group),
                const SizedBox(height: 8),
                _sectionLabel('GROUP INFO'),
                _buildInfoCard(group),
                const SizedBox(height: 18),
                _sectionLabel('PERMISSIONS'),
                _buildPermissions(group),
                const SizedBox(height: 18),
                _sectionLabel('MEMBERS · ${group.memberCount}'),
                _buildMembers(group),
                const SizedBox(height: 26),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: OutlinedButton.icon(
                    key: const ValueKey('group-settings-leave'),
                    onPressed: _busy ? null : _leaveGroup,
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                    icon: const Icon(LucideIcons.logOut, size: 18),
                    label: const Text('Leave group'),
                  ),
                ),
              ],
            ),
    );
  }

  Widget _sectionLabel(String label) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 8),
      child: Text(
        label,
        style: const TextStyle(
          fontFamily: AppTheme.fontFamily,
          fontSize: 12,
          fontWeight: FontWeight.w700,
          letterSpacing: 1.2,
          color: SpotifyColors.accent,
        ),
      ),
    );
  }

  Widget _buildHeader(GroupChat group) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 18, 16, 8),
      child: Column(
        children: [
          Stack(
            clipBehavior: Clip.none,
            children: [
              ChatAvatar(
                avatarUrl: group.photoUrl,
                avatarColor: group.avatarColor,
                avatarInitials: group.initials,
                size: 92,
              ),
              if (_isAdmin)
                Positioned(
                  right: -3,
                  bottom: -3,
                  child: Material(
                    color: SpotifyColors.accent,
                    shape: const CircleBorder(),
                    child: InkWell(
                      key: const ValueKey('group-settings-photo'),
                      customBorder: const CircleBorder(),
                      onTap: _busy ? null : _changePhoto,
                      child: const Padding(
                        padding: EdgeInsets.all(7),
                        child: Icon(
                          LucideIcons.camera,
                          size: 16,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            group.title,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontFamily: AppTheme.fontFamily,
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            '${group.memberCount} members · ${group.adminIds.length} '
            '${group.adminIds.length == 1 ? 'admin' : 'admins'}',
            style: TextStyle(
              fontFamily: AppTheme.fontFamily,
              fontSize: 12,
              color: Colors.white.withValues(alpha: 0.58),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoCard(GroupChat group) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.fromLTRB(14, 12, 10, 12),
      decoration: BoxDecoration(
        color: SpotifyColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: SpotifyColors.border),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  group.description.isEmpty
                      ? 'No group description yet.'
                      : group.description,
                  style: TextStyle(
                    fontFamily: AppTheme.fontFamily,
                    fontSize: 12,
                    height: 1.4,
                    fontStyle: group.description.isEmpty
                        ? FontStyle.italic
                        : FontStyle.normal,
                    color: Colors.white.withValues(alpha: 0.72),
                  ),
                ),
                if (group.createdAt != null) ...[
                  const SizedBox(height: 6),
                  Text(
                    'Created ${formatShortDate(group.createdAt!)}',
                    style: AppType.timestamp(
                      Theme.of(context).colorScheme,
                    ).copyWith(color: Colors.white.withValues(alpha: 0.7)),
                  ),
                ],
              ],
            ),
          ),
          if (_isAdmin)
            IconButton(
              key: const ValueKey('group-settings-edit-info'),
              onPressed: _busy ? null : _editInfo,
              icon: const Icon(LucideIcons.pencil, size: 18),
              color: SpotifyColors.accent,
              tooltip: 'Edit group info',
            ),
        ],
      ),
    );
  }

  Widget _buildPermissions(GroupChat group) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Material(
        color: SpotifyColors.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: const BorderSide(color: SpotifyColors.border),
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          children: [
            _permissionSwitch(
              key: const ValueKey('group-settings-anonymous'),
              icon: LucideIcons.eyeOff,
              title: 'Anonymous messages',
              subtitle:
                  'Let members hide their name and send as Anonymous Sender.',
              value: group.anonymousMessagesEnabled,
              onChanged: _busy
                  ? null
                  : (value) => _saveSetting(
                      () => ChatStore.instance.updateGroupSettings(
                        chatId: widget.chatId,
                        anonymousMessagesEnabled: value,
                      ),
                      success: value
                          ? 'Anonymous messages enabled'
                          : 'Anonymous messages disabled',
                    ),
            ),
            const Divider(height: 1, indent: 54, color: SpotifyColors.border),
            _permissionSwitch(
              key: const ValueKey('group-settings-post'),
              icon: LucideIcons.messagesSquare,
              title: 'Members can send messages',
              subtitle: group.membersCanPost
                  ? 'Everyone can post. Admins can still send messages.'
                  : 'Announcement mode: only admins can post.',
              value: group.membersCanPost,
              onChanged: _busy
                  ? null
                  : (value) => _saveSetting(
                      () => ChatStore.instance.updateGroupSettings(
                        chatId: widget.chatId,
                        membersCanPost: value,
                      ),
                      success: value
                          ? 'Members can send messages'
                          : 'Only admins can send messages now',
                    ),
            ),
            const Divider(height: 1, indent: 54, color: SpotifyColors.border),
            _permissionSwitch(
              key: const ValueKey('group-settings-add-members-toggle'),
              icon: LucideIcons.userPlus,
              title: 'Members can add people',
              subtitle: group.membersCanAddMembers
                  ? 'Anyone in the group can add new members.'
                  : 'Only admins can add new members.',
              value: group.membersCanAddMembers,
              onChanged: _busy
                  ? null
                  : (value) => _saveSetting(
                      () => ChatStore.instance.updateGroupSettings(
                        chatId: widget.chatId,
                        membersCanAddMembers: value,
                      ),
                      success: value
                          ? 'Members can add people'
                          : 'Only admins can add people',
                    ),
            ),
            if (!_isAdmin)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
                child: Row(
                  children: [
                    Icon(
                      LucideIcons.lock,
                      size: 13,
                      color: Colors.white.withValues(alpha: 0.45),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      'Only admins can change these settings',
                      style: TextStyle(
                        fontFamily: AppTheme.fontFamily,
                        fontSize: 12,
                        color: Colors.white.withValues(alpha: 0.45),
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _permissionSwitch({
    required Key key,
    required IconData icon,
    required String title,
    required String subtitle,
    required bool value,
    required ValueChanged<bool>? onChanged,
  }) {
    final enabled = _isAdmin && !_busy;
    return SwitchListTile(
      key: key,
      value: value,
      onChanged: enabled ? onChanged : null,
      activeThumbColor: SpotifyColors.accent,
      secondary: Icon(
        icon,
        size: 20,
        color: enabled
            ? SpotifyColors.accent
            : Colors.white.withValues(alpha: 0.35),
      ),
      title: Text(
        title,
        style: TextStyle(
          fontFamily: AppTheme.fontFamily,
          fontSize: 15,
          fontWeight: FontWeight.w600,
          color: Colors.white.withValues(alpha: enabled ? 0.92 : 0.6),
        ),
      ),
      subtitle: Text(
        subtitle,
        style: TextStyle(
          fontFamily: AppTheme.fontFamily,
          fontSize: 12,
          height: 1.3,
          color: Colors.white.withValues(alpha: 0.45),
        ),
      ),
      contentPadding: const EdgeInsets.fromLTRB(14, 2, 10, 2),
    );
  }

  Widget _buildMembers(GroupChat group) {
    final query = _query.trim().toLowerCase();
    final members = group.members
        .map(
          (uid) =>
              group.profileFor(uid) ??
              ChatUser(id: uid, name: 'Member', username: ''),
        )
        .where((member) {
          if (query.isEmpty) return true;
          return member.displayName.toLowerCase().contains(query) ||
              member.username.toLowerCase().contains(query) ||
              member.handle.toLowerCase().contains(query);
        })
        .toList(growable: false);

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  key: const ValueKey('group-settings-search'),
                  controller: _searchController,
                  onChanged: (value) => setState(() => _query = value),
                  style: const TextStyle(
                    fontFamily: AppTheme.fontFamily,
                    fontSize: 12,
                    color: Colors.white,
                  ),
                  decoration: InputDecoration(
                    hintText: 'Search members',
                    hintStyle: TextStyle(
                      fontFamily: AppTheme.fontFamily,
                      fontSize: 12,
                      color: Colors.white.withValues(alpha: 0.4),
                    ),
                    prefixIcon: Icon(
                      LucideIcons.search,
                      size: 19,
                      color: Colors.white.withValues(alpha: 0.45),
                    ),
                    filled: true,
                    fillColor: SpotifyColors.surface,
                    contentPadding: const EdgeInsets.symmetric(vertical: 10),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(22),
                      borderSide: const BorderSide(color: SpotifyColors.border),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(22),
                      borderSide: const BorderSide(color: SpotifyColors.border),
                    ),
                  ),
                ),
              ),
              if (_canAddMembers) ...[
                const SizedBox(width: 8),
                IconButton.filledTonal(
                  key: const ValueKey('group-settings-add-members'),
                  onPressed: _busy ? null : _addMembers,
                  tooltip: 'Add members',
                  style: IconButton.styleFrom(
                    backgroundColor: SpotifyColors.accent.withValues(
                      alpha: 0.15,
                    ),
                    foregroundColor: SpotifyColors.accent,
                  ),
                  icon: const Icon(LucideIcons.userPlus, size: 20),
                ),
              ],
            ],
          ),
        ),
        if (members.isEmpty)
          Padding(
            padding: const EdgeInsets.all(24),
            child: Text(
              'No members match “${_query.trim()}”.',
              style: TextStyle(
                fontFamily: AppTheme.fontFamily,
                color: Colors.white.withValues(alpha: 0.5),
              ),
            ),
          )
        else
          for (final member in members) _buildMemberTile(group, member),
      ],
    );
  }

  Widget _buildMemberTile(GroupChat group, ChatUser member) {
    final isMe = member.id == _myUid;
    final isAdmin = group.isAdmin(member.id);
    final canTap = _isAdmin || isMe;
    return ListTile(
      key: ValueKey('group-setting-member-${member.id}'),
      onTap: canTap ? () => _openMemberActions(member) : null,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 1),
      leading: ChatAvatar(
        avatarUrl: member.photoUrl,
        avatarColor: member.avatarColor,
        avatarInitials: member.initials,
        size: 42,
        borderRadius: BorderRadius.circular(6),
      ),
      title: Row(
        children: [
          Flexible(
            child: Text(
              isMe ? 'You' : member.displayName,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontFamily: AppTheme.fontFamily,
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: isMe ? SpotifyColors.accent : Colors.white,
              ),
            ),
          ),
          if (isAdmin) ...[
            const SizedBox(width: 7),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: SpotifyColors.accent.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(5),
              ),
              child: const Text(
                'Admin',
                style: TextStyle(
                  fontFamily: AppTheme.fontFamily,
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: SpotifyColors.accent,
                ),
              ),
            ),
          ],
        ],
      ),
      subtitle: Text(
        member.handle,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          fontFamily: AppTheme.fontFamily,
          fontSize: 12,
          color: Colors.white.withValues(alpha: 0.48),
        ),
      ),
      trailing: canTap
          ? Icon(
              LucideIcons.chevronRight,
              size: 19,
              color: Colors.white.withValues(alpha: 0.3),
            )
          : null,
    );
  }
}

/// Searchable people picker used to add members to an existing group.
class AddGroupMembersSheet extends StatefulWidget {
  const AddGroupMembersSheet({
    super.key,
    required this.users,
    this.existingIds = const {},
  });

  final Stream<List<ChatUser>> users;
  final Set<String> existingIds;

  @override
  State<AddGroupMembersSheet> createState() => _AddGroupMembersSheetState();
}

class _AddGroupMembersSheetState extends State<AddGroupMembersSheet> {
  final TextEditingController _searchController = TextEditingController();
  final Map<String, ChatUser> _selected = {};
  String _query = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return SafeArea(
      child: SizedBox(
        height: MediaQuery.of(context).size.height * 0.82,
        child: Column(
          children: [
            const SizedBox(height: 10),
            Container(
              width: 38,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.22),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 12, 6),
              child: Row(
                children: [
                  const Expanded(
                    child: Text(
                      'Add members',
                      style: TextStyle(
                        fontFamily: AppTheme.fontFamily,
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                      ),
                    ),
                  ),
                  TextButton(
                    key: const ValueKey('add-group-members-confirm'),
                    onPressed: _selected.isEmpty
                        ? null
                        : () => Navigator.pop(
                            context,
                            _selected.values.toList(growable: false),
                          ),
                    child: Text(
                      _selected.isEmpty ? 'Add' : 'Add ${_selected.length}',
                      style: TextStyle(
                        fontFamily: AppTheme.fontFamily,
                        fontWeight: FontWeight.w700,
                        color: _selected.isEmpty
                            ? SpotifyColors.accent.withValues(alpha: 0.35)
                            : SpotifyColors.accent,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
              child: TextField(
                key: const ValueKey('add-group-members-search'),
                controller: _searchController,
                onChanged: (value) => setState(() => _query = value),
                style: const TextStyle(
                  fontFamily: AppTheme.fontFamily,
                  color: Colors.white,
                  fontSize: 15,
                ),
                decoration: InputDecoration(
                  hintText: 'Search people',
                  hintStyle: TextStyle(
                    fontFamily: AppTheme.fontFamily,
                    color: Colors.white.withValues(alpha: 0.4),
                  ),
                  prefixIcon: const Icon(LucideIcons.search, size: 20),
                  filled: true,
                  fillColor: SpotifyColors.background.withValues(alpha: 0.55),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(22),
                    borderSide: const BorderSide(color: SpotifyColors.border),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(22),
                    borderSide: const BorderSide(color: SpotifyColors.border),
                  ),
                ),
              ),
            ),
            Expanded(
              child: StreamBuilder<List<ChatUser>>(
                stream: widget.users,
                builder: (context, snapshot) {
                  if (snapshot.hasError) {
                    return const Center(
                      child: Text(
                        'Could not load people.',
                        style: TextStyle(
                          fontFamily: AppTheme.fontFamily,
                          color: Colors.white70,
                        ),
                      ),
                    );
                  }
                  if (!snapshot.hasData) {
                    return const Center(child: AppLoader());
                  }
                  final query = _query.trim().toLowerCase();
                  final users = snapshot.data!
                      .where((user) => !widget.existingIds.contains(user.id))
                      .where((user) {
                        if (query.isEmpty) return true;
                        return user.displayName.toLowerCase().contains(query) ||
                            user.username.toLowerCase().contains(query);
                      })
                      .toList(growable: false);
                  if (users.isEmpty) {
                    return Center(
                      child: Text(
                        'No people available to add.',
                        style: TextStyle(
                          fontFamily: AppTheme.fontFamily,
                          color: Colors.white.withValues(alpha: 0.5),
                        ),
                      ),
                    );
                  }
                  return ListView.builder(
                    padding: const EdgeInsets.only(bottom: 24),
                    itemCount: users.length,
                    itemBuilder: (context, index) {
                      final user = users[index];
                      final selected = _selected.containsKey(user.id);
                      return CheckboxListTile(
                        key: ValueKey('add-group-member-${user.id}'),
                        value: selected,
                        onChanged: (_) => setState(() {
                          if (selected) {
                            _selected.remove(user.id);
                          } else {
                            _selected[user.id] = user;
                          }
                        }),
                        activeColor: SpotifyColors.accent,
                        checkColor: Colors.white,
                        secondary: ChatAvatar(
                          avatarUrl: user.photoUrl,
                          avatarColor: user.avatarColor,
                          avatarInitials: user.initials,
                          size: 40,
                          borderRadius: BorderRadius.circular(5),
                        ),
                        title: Text(
                          user.displayName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontFamily: AppTheme.fontFamily,
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                            color: scheme.onSurface,
                          ),
                        ),
                        subtitle: Text(
                          user.handle,
                          style: const TextStyle(
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
      ),
    );
  }
}
