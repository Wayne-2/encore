import 'dart:async';
import 'dart:ui';

import 'package:flutter/material.dart';

import '../navigation/app_route.dart';
import '../theme/app_theme.dart';
import '../theme/spotify_colors.dart';
import 'auth/login_screen.dart';

/// First screen after the splash.
///
/// Cycles through the bundled background photos like a carousel. Each slide is
/// shown with a progressive frost — clear at the top so the photo shows
/// through, frosting toward the bottom where the welcome copy and dots sit.
class WelcomeScreen extends StatefulWidget {
  const WelcomeScreen({super.key});

  @override
  State<WelcomeScreen> createState() => _WelcomeScreenState();
}

class _WelcomeScreenState extends State<WelcomeScreen> {
  static const List<String> _backgrounds = [
    'assets/background.jpeg',
    'assets/background-2.jpeg',
    'assets/background-3.jpeg',
  ];

  static const String _title = 'Welcome to Encore';

  static const String _message =
      'Stay connected, access academic resources, and keep track of your academic journey, all in one place.';

  /// Call-to-action green.
  static const Color _buttonColor = Color(0xFF25A10C);

  /// Start far from zero so the carousel can loop endlessly in either
  /// direction; the visible slide is `index % _backgrounds.length`.
  static final int _initialPage = _backgrounds.length * 1000;

  int _index = _initialPage;
  final _controller = PageController(initialPage: _initialPage);
  Timer? _autoPlay;

  @override
  void initState() {
    super.initState();
    _restartAutoPlay();
  }

  @override
  void dispose() {
    _autoPlay?.cancel();
    _controller.dispose();
    super.dispose();
  }

  /// Advances the carousel every four seconds, restarting the countdown after
  /// any change (auto or manual).
  void _restartAutoPlay() {
    _autoPlay?.cancel();
    _autoPlay = Timer.periodic(const Duration(seconds: 4), (_) => _advance());
  }

  void _advance() {
    if (!_controller.hasClients) return;
    _goTo(_index + 1);
  }

  void _goTo(int page) {
    _controller.animateToPage(
      page,
      duration: const Duration(milliseconds: 400),
      curve: Curves.easeOutCubic,
    );
  }

  /// Animates to the slide at [dot], taking the shorter way around the loop.
  void _onDotTap(int dot) {
    final count = _backgrounds.length;
    var page = _index - (_index % count) + dot;
    if ((page - _index).abs() > count / 2) {
      page += page < _index ? count : -count;
    }
    _goTo(page);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: SpotifyColors.background,
      body: Stack(
        fit: StackFit.expand,
        children: [
          // Background carousel.
          PageView.builder(
            controller: _controller,
            onPageChanged: (i) {
              setState(() => _index = i);
              _restartAutoPlay();
            },
            itemBuilder: (context, i) => _FrostedBackground(
              asset: _backgrounds[i % _backgrounds.length],
            ),
          ),

          // Static foreground: welcome copy, page dots, call to action.
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Spacer(),
                  Image.asset(
                    'assets/Encore.png',
                    width: 72,
                    height: 72,
                    filterQuality: FilterQuality.medium,
                  ),
                  const SizedBox(height: 20),
                  Text(_title, style: _titleStyle),
                  const SizedBox(height: 16),
                  Text(_message, style: _messageStyle),
                  const SizedBox(height: 20),
                  _CarouselDots(
                    count: _backgrounds.length,
                    index: _index % _backgrounds.length,
                    onTap: _onDotTap,
                  ),
                  const SizedBox(height: 20),
                  SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: FilledButton(
                      onPressed: () => Navigator.of(context).push(
                        sharedAxisRoute<void>(const LoginScreen()),
                      ),
                      style: FilledButton.styleFrom(
                        backgroundColor: _buttonColor,
                        foregroundColor: Colors.white,
                      ),
                      child: const Text('Get Started'),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  static final TextStyle _titleStyle = TextStyle(
    fontFamily: AppTheme.fontFamily,
    fontSize: 20,
    fontWeight: FontWeight.w600,
    height: 1.2,
    color: Colors.white,
  );

  static final TextStyle _messageStyle = TextStyle(
    fontFamily: AppTheme.fontFamily,
    fontSize: 14,
    fontWeight: FontWeight.w400,
    height: 1.5,
    color: Colors.white.withValues(alpha: 0.85),
  );
}

/// A single carousel slide: the photo with a progressive frost.
class _FrostedBackground extends StatelessWidget {
  const _FrostedBackground({required this.asset});

  final String asset;

  @override
  Widget build(BuildContext context) {
    return ClipRect(
      child: Stack(
        fit: StackFit.expand,
        children: [
          // 1. Sharp photo — this is the layer the blur below samples.
          Image.asset(asset, fit: BoxFit.cover),

          // 2. Full-screen frosted glass over the photo.
          BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
            child: const SizedBox.expand(),
          ),

          // 3. Sharp photo again on top, fading out toward the bottom so the
          //    blur shows through — giving the progressive frost.
          ShaderMask(
            shaderCallback: (rect) => const LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [Colors.white, Colors.transparent],
              stops: [0.5, 0.9],
            ).createShader(rect),
            blendMode: BlendMode.dstIn,
            child: Image.asset(asset, fit: BoxFit.cover),
          ),

          // 4. Progressive dark tint for legibility over the frosted area.
          DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Colors.transparent,
                  Colors.black.withValues(alpha: 0.55),
                ],
                stops: const [0.5, 0.88],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Tappable carousel indicators (the active one is a wider pill).
class _CarouselDots extends StatelessWidget {
  const _CarouselDots({
    required this.count,
    required this.index,
    required this.onTap,
  });

  final int count;
  final int index;
  final ValueChanged<int> onTap;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        for (var i = 0; i < count; i++)
          GestureDetector(
            onTap: () => onTap(i),
            child: Padding(
              padding: EdgeInsets.only(
                right: i == count - 1 ? 0 : 8,
                top: 8,
                bottom: 8,
              ),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 250),
                curve: Curves.easeOut,
                width: i == index ? 22 : 8,
                height: 8,
                decoration: BoxDecoration(
                  color: i == index
                      ? Colors.white
                      : Colors.white.withValues(alpha: 0.4),
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
            ),
          ),
      ],
    );
  }
}
