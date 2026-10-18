import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../theme/app_type.dart';
import '../theme/spotify_colors.dart';

/// The Student Agents page reached from the More tab.
///
/// Modelled on `assets/agency.jpeg`: a faint grid backdrop, a greeting with a
/// short stats summary, an "Add" pill, Filter/Sort chips and a feed of agent
/// cards with descriptions, last-update meta and status badges.
class StudentAgentScreen extends StatelessWidget {
  const StudentAgentScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Scaffold(
      backgroundColor: SpotifyColors.background,
      body: Stack(
        children: [
          Positioned.fill(child: CustomPaint(painter: const _GridPainter())),
          SafeArea(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 32),
              children: [
                _TopBar(scheme: scheme),
                const SizedBox(height: 24),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Text(
                        'Good afternoon, Solomon.',
                        style: AppType.sectionTitle(scheme).copyWith(
                          fontSize: 28,
                          fontWeight: FontWeight.w800,
                          height: 1.15,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    const _AddButton(),
                  ],
                ),
                const SizedBox(height: 12),
                _Summary(scheme: scheme),
                const SizedBox(height: 20),
                Row(
                  children: [
                    _Chip(
                      label: 'Filter',
                      leading: SvgPicture.asset(
                        'assets/icons/filter.svg',
                        width: 14,
                        height: 14,
                        colorFilter: ColorFilter.mode(
                          scheme.onSurface,
                          BlendMode.srcIn,
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    _Chip(
                      label: 'Sort by',
                      leading: Icon(
                        Icons.swap_vert,
                        size: 16,
                        color: scheme.onSurface,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                for (final agent in _agents) ...[
                  _AgentCard(agent: agent),
                  const SizedBox(height: 12),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// The page's top bar: back button, search and the account avatar.
class _TopBar extends StatelessWidget {
  const _TopBar({required this.scheme});

  final ColorScheme scheme;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        IconButton(
          padding: EdgeInsets.zero,
          constraints: const BoxConstraints(),
          icon: const Icon(Icons.arrow_back_ios_new),
          iconSize: 20,
          color: scheme.onSurface,
          onPressed: () => Navigator.of(context).pop(),
        ),
        const SizedBox(width: 6),
        Text('Student Agents', style: AppType.name(scheme)),
        const Spacer(),
        SvgPicture.asset(
          'assets/icons/searching.svg',
          width: 20,
          height: 20,
          colorFilter: ColorFilter.mode(scheme.onSurface, BlendMode.srcIn),
        ),
        const SizedBox(width: 16),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: Image.asset(
            'assets/Encore.png',
            width: 28,
            height: 28,
            fit: BoxFit.cover,
          ),
        ),
      ],
    );
  }
}

/// The greeting's supporting sentence, with the key figures highlighted.
class _Summary extends StatelessWidget {
  const _Summary({required this.scheme});

  final ColorScheme scheme;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Text(
      'Encore is pleased to provide assistance from student agents who guide '
      'you in your daily school activities',
      style: AppType.body(scheme).copyWith(height: 1.45),
    );
  }
}

/// The translucent "Add" pill shown beside the greeting.
class _AddButton extends StatelessWidget {
  const _AddButton();

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Material(
      color: SpotifyColors.surface,
      borderRadius: BorderRadius.circular(24),
      child: InkWell(
        borderRadius: BorderRadius.circular(24),
        onTap: () {},
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: SpotifyColors.borderStrong),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.add, size: 16, color: scheme.onSurface),
              const SizedBox(width: 6),
              Text(
                'Add',
                style: AppType.subtitle(scheme).copyWith(
                  color: scheme.onSurface,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// A pill-shaped Filter/Sort control with a leading glyph.
class _Chip extends StatelessWidget {
  const _Chip({required this.label, required this.leading});

  final String label;
  final Widget leading;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
      decoration: BoxDecoration(
        color: SpotifyColors.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: SpotifyColors.borderStrong),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          leading,
          const SizedBox(width: 8),
          Text(
            label,
            style: AppType.subtitle(
              scheme,
            ).copyWith(color: scheme.onSurface, fontWeight: FontWeight.w500),
          ),
        ],
      ),
    );
  }
}

/// A student agent rendered as a card in the feed.
class _Agent {
  const _Agent({
    required this.name,
    required this.activity,
    required this.lastUpdate,
    required this.steps,
    required this.duration,
    required this.active,
  });

  final String name;
  final String activity;
  final String lastUpdate;
  final int steps;
  final String duration;
  final bool active;
}

const List<_Agent> _agents = [
  _Agent(
    name: 'David Okafor',
    activity:
        'Helps you register courses and submit assignments before '
        'their deadlines.',
    lastUpdate: '1 hr ago',
    steps: 14,
    duration: '7 days',
    active: true,
  ),
  _Agent(
    name: 'Grace Adeyemi',
    activity:
        'Guides you through exam preparation and past question '
        'practice.',
    lastUpdate: '1 day ago',
    steps: 9,
    duration: '3 days',
    active: true,
  ),
  _Agent(
    name: 'Samuel Johnson',
    activity:
        'Assists with project research, citations and presentation '
        'slides.',
    lastUpdate: '3 hrs ago',
    steps: 6,
    duration: '5 days',
    active: true,
  ),
];

/// A single agent card: title, description, last-update meta and badges.
class _AgentCard extends StatelessWidget {
  const _AgentCard({required this.agent});

  final _Agent agent;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: SpotifyColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: SpotifyColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.person_outline, size: 18, color: scheme.onSurface),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  agent.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppType.name(scheme),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            agent.activity,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: AppType.subtitle(scheme),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Icon(Icons.schedule, size: 13, color: scheme.onSurfaceVariant),
              const SizedBox(width: 6),
              Text(
                'Last update ${agent.lastUpdate}',
                style: AppType.meta(scheme),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              if (agent.active) ...[
                Container(
                  width: 6,
                  height: 6,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: scheme.primary,
                  ),
                ),
                const SizedBox(width: 6),
                Text('Active', style: AppType.tag(scheme.primary)),
                const _BadgeDot(),
              ],
              Icon(Icons.bolt, size: 13, color: scheme.onSurfaceVariant),
              const SizedBox(width: 4),
              Text('${agent.steps} steps', style: AppType.meta(scheme)),
              const _BadgeDot(),
              Icon(Icons.autorenew, size: 13, color: scheme.onSurfaceVariant),
              const SizedBox(width: 4),
              Text(agent.duration, style: AppType.meta(scheme)),
            ],
          ),
        ],
      ),
    );
  }
}

/// A small circular separator used between badge items.
class _BadgeDot extends StatelessWidget {
  const _BadgeDot();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 10),
      child: Container(
        width: 3,
        height: 3,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: Theme.of(context).colorScheme.onSurfaceVariant,
        ),
      ),
    );
  }
}

/// A faint, dotted grid drawn over the page background.
class _GridPainter extends CustomPainter {
  const _GridPainter();

  @override
  void paint(Canvas canvas, Size size) {
    const double gridSize = 18.0;
    const double gap = 2.0;

    final paintCell = Paint()
      ..color = SpotifyColors.surface.withValues(alpha: 0.55);

    for (double x = 0; x < size.width; x += gridSize + gap) {
      for (double y = 0; y < size.height; y += gridSize + gap) {
        final rrect = RRect.fromRectAndRadius(
          Rect.fromLTWH(x, y, gridSize, gridSize),
          const Radius.circular(2),
        );
        canvas.drawRRect(rrect, paintCell);
      }
    }
  }

  @override
  bool shouldRepaint(covariant _GridPainter oldDelegate) => false;
}
