import 'package:flutter/material.dart';
import '../theme/slack_colors.dart';
import '../theme/app_type.dart';

class StudentAgentScreen extends StatelessWidget {
  const StudentAgentScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Scaffold(
      backgroundColor: SlackColors.darkBackground,
      body: Stack(
        children: [
          Positioned.fill(
            child: CustomPaint(painter: _GridPainter(scheme: scheme)),
          ),
          SafeArea(
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.arrow_back_ios_new),
                        color: scheme.onSurface,
                        onPressed: () => Navigator.of(context).pop(),
                      ),
                      Expanded(
                        child: Center(
                          child: Text(
                            'Student Agency',
                            style: AppType.sectionTitle(scheme),
                          ),
                        ),
                      ),
                      Image.asset(
                        'assets/launch_icon_foreground.png',
                        width: 24,
                        height: 24,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _GridPainter extends CustomPainter {
  _GridPainter({required this.scheme});

  final ColorScheme scheme;

  @override
  void paint(Canvas canvas, Size size) {
    const double gridSize = 20.0;
    const double gap = 1.0;
    final bg = SlackColors.darkBackground;
    final cell = SlackColors.darkHeader;

    final paintBg = Paint()..color = bg;
    canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height), paintBg);

    final paintCell = Paint()..color = cell;

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
