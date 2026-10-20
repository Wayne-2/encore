import 'package:flutter/material.dart';

import '../models/contact_request.dart';
import '../models/direct_chat.dart';
import '../navigation/app_route.dart';
import '../services/chat_store.dart';
import '../services/contact_store.dart';
import '../theme/app_theme.dart';
import '../theme/app_type.dart';
import '../theme/slack_type.dart';
import '../theme/spotify_colors.dart';
import '../widgets/app_loader.dart';
import '../widgets/chat_avatar.dart';
import '../widgets/floating_empty_state.dart';
import '../widgets/section_heading.dart';
import '../widgets/workspace_app_bar.dart';
import 'persistent_direct_chat_screen.dart';

/// Contact discovery built around consent: people can only be messaged after
/// an incoming contact request is accepted.
class AvailableContactsScreen extends StatefulWidget {
  const AvailableContactsScreen({super.key, this.directory});

  /// Injectable directory used by widget tests.
  final Stream<ContactDirectory>? directory;

  @override
  State<AvailableContactsScreen> createState() =>
      _AvailableContactsScreenState();
}

class _AvailableContactsScreenState extends State<AvailableContactsScreen> {
  final TextEditingController _searchController = TextEditingController();
  late final Stream<ContactDirectory> _directory =
      widget.directory ?? ContactStore.instance.watchDirectory();
  final Set<String> _busy = {};
  String _query = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  bool _matches(ContactEntry entry) {
    final query = _query.trim().toLowerCase();
    if (query.isEmpty) return true;
    return entry.user.displayName.toLowerCase().contains(query) ||
        entry.user.username.toLowerCase().contains(query) ||
        (entry.user.level ?? '').toLowerCase().contains(query);
  }

  Future<void> _openChat(ChatUser user, {String? chatId}) async {
    if (!mounted) return;
    final uid = ContactStore.instance.currentUid;
    if (uid == null || uid.isEmpty) return;
    await Navigator.of(context).push(
      sharedAxisRoute(
        PersistentDirectChatScreen(
          chatId: chatId ?? ChatStore.directChatId(uid, user.id),
          peer: user,
        ),
      ),
    );
  }

  Future<void> _sendRequest(ChatUser user) async {
    if (_busy.contains(user.id)) return;
    setState(() => _busy.add(user.id));
    try {
      await ContactStore.instance.sendRequest(user);
      if (!mounted) return;
      _showSnack('Request sent to ${user.displayName}.');
    } catch (_) {
      if (!mounted) return;
      _showSnack('Couldn’t send the request. Try again.');
    } finally {
      if (mounted) setState(() => _busy.remove(user.id));
    }
  }

  Future<void> _accept(ContactRequest request) async {
    final peer = request.fromUser;
    if (_busy.contains(peer.id)) return;
    setState(() => _busy.add(peer.id));
    try {
      final chatId = await ContactStore.instance.acceptRequest(request);
      if (!mounted) return;
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            content: Text('${peer.displayName} is now in your DMs.'),
            action: SnackBarAction(
              label: 'Open',
              onPressed: () => _openChat(peer, chatId: chatId),
            ),
          ),
        );
    } catch (_) {
      if (!mounted) return;
      _showSnack('Couldn’t accept the request. Try again.');
    } finally {
      if (mounted) setState(() => _busy.remove(peer.id));
    }
  }

  Future<void> _decline(ContactRequest request) async {
    final peer = request.fromUser;
    if (_busy.contains(peer.id)) return;
    setState(() => _busy.add(peer.id));
    try {
      await ContactStore.instance.declineRequest(request);
      if (!mounted) return;
      _showSnack('Request declined.');
    } catch (_) {
      if (!mounted) return;
      _showSnack('Couldn’t decline the request. Try again.');
    } finally {
      if (mounted) setState(() => _busy.remove(peer.id));
    }
  }

  Future<void> _cancel(ContactRequest request) async {
    final peer = request.toUser;
    if (_busy.contains(peer.id)) return;
    setState(() => _busy.add(peer.id));
    try {
      await ContactStore.instance.cancelRequest(request);
      if (!mounted) return;
      _showSnack('Request withdrawn.');
    } catch (_) {
      if (!mounted) return;
      _showSnack('Couldn’t withdraw the request. Try again.');
    } finally {
      if (mounted) setState(() => _busy.remove(peer.id));
    }
  }

  void _showSnack(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Scaffold(
      backgroundColor: SpotifyColors.background,
      body: Column(
        children: [
          WorkspaceAppBar(
            heading: 'Available contacts',
            title: 'Send a request before you message',
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
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 10),
            child: TextField(
              key: const ValueKey('contacts-search'),
              controller: _searchController,
              onChanged: (value) => setState(() => _query = value),
              textInputAction: TextInputAction.search,
              style: TextStyle(
                fontFamily: AppTheme.fontFamily,
                color: scheme.onSurface,
                fontSize: 14,
              ),
              decoration: InputDecoration(
                hintText: 'Search name, handle or level',
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
                suffixIcon: _query.isEmpty
                    ? null
                    : IconButton(
                        onPressed: () {
                          _searchController.clear();
                          setState(() => _query = '');
                        },
                        icon: Icon(
                          Icons.close_rounded,
                          color: scheme.onSurfaceVariant,
                          size: 18,
                        ),
                        tooltip: 'Clear search',
                      ),
                filled: true,
                fillColor: SpotifyColors.surface,
                contentPadding: const EdgeInsets.symmetric(vertical: 12),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
          ),
          Expanded(
            child: StreamBuilder<ContactDirectory>(
              stream: _directory,
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return const Center(
                    child: Padding(
                      padding: EdgeInsets.all(24),
                      child: Text(
                        'Could not load contacts. Check your connection.',
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

                final directory = snapshot.data!;
                final incoming = directory.incoming.where(_matches).toList();
                final contacts = directory.entries
                    .where(
                      (entry) =>
                          entry.relation != ContactRelation.incoming &&
                          _matches(entry),
                    )
                    .toList(growable: false);

                if (incoming.isEmpty && contacts.isEmpty) {
                  return Center(
                    child: FloatingEmptyState(
                      key: const ValueKey('contacts-empty'),
                      icon: Icons.people_outline_rounded,
                      message: _query.trim().isEmpty
                          ? 'No other members yet.'
                          : 'No contacts match “${_query.trim()}”.',
                    ),
                  );
                }

                return ListView(
                  padding: const EdgeInsets.only(bottom: 28),
                  children: [
                    if (incoming.isNotEmpty) ...[
                      _SectionLabel(
                        title: 'Requests',
                        count: incoming.length,
                        emphasized: true,
                      ),
                      for (final entry in incoming)
                        _IncomingRequestCard(
                          key: ValueKey(
                            'contact-request-card-${entry.user.id}',
                          ),
                          entry: entry,
                          busy: _busy.contains(entry.user.id),
                          onAccept: entry.request == null
                              ? null
                              : () => _accept(entry.request!),
                          onDecline: entry.request == null
                              ? null
                              : () => _decline(entry.request!),
                        ),
                    ],
                    if (contacts.isEmpty && incoming.isEmpty) ...[
                      _SectionLabel(
                        title: 'Contacts',
                        count: 0,
                        emphasized: false,
                      ),
                      Padding(
                        padding: const EdgeInsets.only(top: 12),
                        child: FloatingEmptyState(
                          key: const ValueKey('contacts-list-empty'),
                          icon: Icons.person_search_outlined,
                          message: 'No contacts match “${_query.trim()}”.',
                        ),
                      ),
                    ] else if (contacts.isNotEmpty) ...[
                      _SectionLabel(
                        title: 'Contacts',
                        count: contacts.length,
                        emphasized: false,
                      ),
                      for (var i = 0; i < contacts.length; i++) ...[
                        if (i > 0)
                          const Divider(
                            height: 1,
                            thickness: 1,
                            indent: 72,
                            color: SpotifyColors.border,
                          ),
                        _ContactRow(
                          key: ValueKey('contact-row-${contacts[i].user.id}'),
                          entry: contacts[i],
                          busy: _busy.contains(contacts[i].user.id),
                          onOpen: () => _openChat(contacts[i].user),
                          onRequest: () => _sendRequest(contacts[i].user),
                          onAccept: contacts[i].request == null
                              ? null
                              : () => _accept(contacts[i].request!),
                          onCancel: contacts[i].request == null
                              ? null
                              : () => _cancel(contacts[i].request!),
                        ),
                      ],
                    ],
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel({
    required this.title,
    required this.count,
    required this.emphasized,
  });

  final String title;
  final int count;
  final bool emphasized;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 10),
      child: Row(
        children: [
          SectionHeading(
            title,
            style: SlackType.sectionTitle(scheme),
            glyphStyle: SlackType.glyph(scheme),
          ),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
            decoration: BoxDecoration(
              color: emphasized
                  ? SpotifyColors.accent.withValues(alpha: 0.16)
                  : Colors.white.withValues(alpha: 0.06),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(
              '$count',
              style: AppType.tag(
                emphasized ? SpotifyColors.accent : scheme.onSurfaceVariant,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _IncomingRequestCard extends StatelessWidget {
  const _IncomingRequestCard({
    super.key,
    required this.entry,
    required this.busy,
    required this.onAccept,
    required this.onDecline,
  });

  final ContactEntry entry;
  final bool busy;
  final VoidCallback? onAccept;
  final VoidCallback? onDecline;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final user = entry.user;

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 10),
      padding: const EdgeInsets.fromLTRB(12, 12, 8, 12),
      decoration: BoxDecoration(
        color: SpotifyColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: SpotifyColors.accent.withValues(alpha: 0.24)),
      ),
      child: Row(
        children: [
          ChatAvatar(
            avatarUrl: user.photoUrl,
            avatarColor: user.avatarColor,
            avatarInitials: user.initials,
            size: 44,
            showOnlineDot: user.isOnlineAt(DateTime.now()),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  user.displayName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppType.cardTitle(scheme),
                ),
                const SizedBox(height: 3),
                Text(
                  _contactMeta(user),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppType.subtitle(scheme),
                ),
              ],
            ),
          ),
          const SizedBox(width: 6),
          _PillAction(
            key: ValueKey('contact-accept-${user.id}'),
            label: 'Accept',
            icon: Icons.check_rounded,
            filled: true,
            busy: busy,
            onTap: onAccept,
          ),
          IconButton(
            key: ValueKey('contact-decline-${user.id}'),
            onPressed: busy ? null : onDecline,
            icon: const Icon(Icons.close_rounded, size: 18),
            color: scheme.onSurfaceVariant,
            tooltip: 'Decline request',
            visualDensity: VisualDensity.compact,
            constraints: const BoxConstraints.tightFor(width: 32, height: 32),
            padding: EdgeInsets.zero,
          ),
        ],
      ),
    );
  }
}

class _ContactRow extends StatelessWidget {
  const _ContactRow({
    super.key,
    required this.entry,
    required this.busy,
    required this.onOpen,
    required this.onRequest,
    required this.onAccept,
    required this.onCancel,
  });

  final ContactEntry entry;
  final bool busy;
  final VoidCallback onOpen;
  final VoidCallback onRequest;
  final VoidCallback? onAccept;
  final VoidCallback? onCancel;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final user = entry.user;
    final connected = entry.relation == ContactRelation.connected;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: connected ? onOpen : null,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          child: Row(
            children: [
              ChatAvatar(
                avatarUrl: user.photoUrl,
                avatarColor: user.avatarColor,
                avatarInitials: user.initials,
                size: 44,
                showOnlineDot: user.isOnlineAt(DateTime.now()),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      user.displayName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppType.cardTitle(scheme),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      _contactMeta(user),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppType.subtitle(scheme),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              switch (entry.relation) {
                ContactRelation.connected => _PillAction(
                  key: ValueKey('contact-message-${user.id}'),
                  label: 'Message',
                  icon: Icons.chat_bubble_outline_rounded,
                  filled: true,
                  onTap: onOpen,
                ),
                ContactRelation.outgoing => _PillAction(
                  key: ValueKey('contact-cancel-${user.id}'),
                  label: 'Requested',
                  icon: Icons.schedule_rounded,
                  filled: false,
                  busy: busy,
                  onTap: onCancel,
                  tooltip: 'Withdraw request',
                ),
                ContactRelation.incoming => _PillAction(
                  key: ValueKey('contact-accept-${user.id}'),
                  label: 'Accept',
                  icon: Icons.check_rounded,
                  filled: true,
                  busy: busy,
                  onTap: onAccept,
                ),
                ContactRelation.available => _PillAction(
                  key: ValueKey('contact-request-${user.id}'),
                  label: 'Request',
                  icon: Icons.person_add_alt_1_rounded,
                  filled: false,
                  busy: busy,
                  onTap: onRequest,
                ),
              },
            ],
          ),
        ),
      ),
    );
  }
}

class _PillAction extends StatelessWidget {
  const _PillAction({
    super.key,
    required this.label,
    required this.icon,
    required this.filled,
    this.busy = false,
    this.onTap,
    this.tooltip,
  });

  final String label;
  final IconData icon;
  final bool filled;
  final bool busy;
  final VoidCallback? onTap;
  final String? tooltip;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final foreground = filled ? Colors.white : scheme.onSurfaceVariant;
    final widget = Opacity(
      opacity: busy ? 0.6 : 1,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: busy ? null : onTap,
          borderRadius: BorderRadius.circular(18),
          child: Container(
            height: 32,
            padding: const EdgeInsets.symmetric(horizontal: 11),
            decoration: BoxDecoration(
              color: filled ? SpotifyColors.accent : Colors.transparent,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(
                color: filled
                    ? SpotifyColors.accent
                    : SpotifyColors.borderStrong,
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (busy)
                  SizedBox(
                    width: 13,
                    height: 13,
                    child: CircularProgressIndicator(
                      strokeWidth: 1.6,
                      color: foreground,
                    ),
                  )
                else
                  Icon(icon, size: 14, color: foreground),
                const SizedBox(width: 5),
                Text(
                  label,
                  style: TextStyle(
                    fontFamily: AppTheme.fontFamily,
                    fontSize: 11.5,
                    fontWeight: FontWeight.w700,
                    color: foreground,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );

    final tip = tooltip;
    return tip == null ? widget : Tooltip(message: tip, child: widget);
  }
}

String _contactMeta(ChatUser user) {
  final level = user.level?.trim() ?? '';
  return level.isEmpty ? user.handle : '${user.handle} · $level';
}
