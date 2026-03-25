import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/settings_provider.dart';
import '../services/user_service.dart';
import 'menu_screen.dart';

// ─── Particle Model ───
class _Particle {
  double x, y, speed, radius, opacity;
  Color color;
  double angle;
  double drift;

  _Particle({
    required this.x,
    required this.y,
    required this.speed,
    required this.radius,
    required this.opacity,
    required this.color,
    required this.angle,
    required this.drift,
  });
}

// ─── Particle Painter ───
class _ParticlePainter extends CustomPainter {
  final List<_Particle> particles;
  final double progress;

  _ParticlePainter({required this.particles, required this.progress});

  @override
  void paint(Canvas canvas, Size size) {
    for (final p in particles) {
      final paint = Paint()
        ..color =
            p.color.withOpacity(p.opacity * (0.3 + 0.7 * sin(progress * pi)))
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, p.radius * 0.8);
      canvas.drawCircle(Offset(p.x, p.y), p.radius, paint);
    }
  }

  @override
  bool shouldRepaint(covariant _ParticlePainter oldDelegate) => true;
}

// ─── Ring Painter ───
class _OrbitRingPainter extends CustomPainter {
  final double rotation;
  final Color color;
  final double dashProgress;

  _OrbitRingPainter({
    required this.rotation,
    required this.color,
    required this.dashProgress,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2;
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0
      ..strokeCap = StrokeCap.round;

    canvas.save();
    canvas.translate(center.dx, center.dy);
    canvas.rotate(rotation);
    canvas.translate(-center.dx, -center.dy);

    const int dashes = 24;
    final double dashAngle = (2 * pi) / dashes;
    const double gapRatio = 0.4;

    for (int i = 0; i < dashes; i++) {
      final startAngle = i * dashAngle;
      final sweepAngle = dashAngle * (1 - gapRatio);
      final opacity = (sin((i / dashes + dashProgress) * 2 * pi) * 0.5 + 0.5);
      paint.color = color.withOpacity(opacity * 0.7);
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        startAngle,
        sweepAngle,
        false,
        paint,
      );
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _OrbitRingPainter oldDelegate) => true;
}

// ─── Orbiting Marbles Painter ───
class _OrbitingMarblesPainter extends CustomPainter {
  final double rotation;
  final List<Color> marbleColors;

  _OrbitingMarblesPainter({
    required this.rotation,
    required this.marbleColors,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2 - 10;

    for (int i = 0; i < marbleColors.length; i++) {
      final angle = rotation + (2 * pi / marbleColors.length) * i;
      final mx = center.dx + radius * cos(angle);
      final my = center.dy + radius * sin(angle);

      // Glow
      final glowPaint = Paint()
        ..color = marbleColors[i].withOpacity(0.4)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8);
      canvas.drawCircle(Offset(mx, my), 8, glowPaint);

      // Marble body
      final marblePaint = Paint()
        ..shader = RadialGradient(
          colors: [
            marbleColors[i].withOpacity(0.9),
            marbleColors[i].withOpacity(0.3),
          ],
        ).createShader(Rect.fromCircle(center: Offset(mx, my), radius: 7));
      canvas.drawCircle(Offset(mx, my), 6, marblePaint);

      // Highlight
      final highlightPaint = Paint()
        ..color = Colors.white.withOpacity(0.7);
      canvas.drawCircle(Offset(mx - 2, my - 2), 1.8, highlightPaint);
    }
  }

  @override
  bool shouldRepaint(covariant _OrbitingMarblesPainter oldDelegate) => true;
}

// ─── Main Splash Screen ───
class SplashScreen extends ConsumerStatefulWidget {
  const SplashScreen({super.key});

  @override
  ConsumerState<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends ConsumerState<SplashScreen>
    with TickerProviderStateMixin {
  late AnimationController _fadeCtrl;
  late AnimationController _pulseCtrl;
  late AnimationController _particleCtrl;
  late AnimationController _ringCtrl;
  late AnimationController _titleSlideCtrl;
  late AnimationController _shimmerCtrl;
  late AnimationController _marbleOrbitCtrl;

  late Animation<double> _logoScale;
  late Animation<double> _titleSlide;
  late Animation<double> _titleOpacity;
  late Animation<double> _subtitleSlide;
  late Animation<double> _subtitleOpacity;
  late Animation<double> _loaderOpacity;

  final List<_Particle> _particles = [];
  final Random _random = Random();
  bool _started = false;

  final List<Color> _marbleColors = [
    const Color(0xFFE53935),
    const Color(0xFF1E88E5),
    const Color(0xFF43A047),
    const Color(0xFFFDD835),
    const Color(0xFFAB47BC),
    const Color(0xFFFF7043),
  ];

  @override
  void initState() {
    super.initState();

    // ── SLOW fade in for logo (1.5s) ──
    _fadeCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    );

    // ── SLOW pulse / breathe (3s cycle) ──
    _pulseCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 3000),
    )..repeat(reverse: true);

    // ── Particles (continuous) ──
    _particleCtrl = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 15),
    )..repeat();

    // ── SLOW ring rotation (12s full rotation) ──
    _ringCtrl = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 12),
    )..repeat();

    // ── SLOW marble orbit (10s full rotation) ──
    _marbleOrbitCtrl = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 10),
    )..repeat();

    // ── SLOW title slide in (2s) ──
    _titleSlideCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000),
    );

    // ── Shimmer (3s cycle for gentle sweep) ──
    _shimmerCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 3000),
    )..repeat();

    // ── Staggered Animations ──

    // Logo: elastic bounce scale in over first 70% of fade duration
    _logoScale = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _fadeCtrl,
        curve: const Interval(0.0, 0.7, curve: Curves.elasticOut),
      ),
    );

    // Title: slide up from 50px, from 0% to 40% of title ctrl
    _titleSlide = Tween<double>(begin: 50.0, end: 0.0).animate(
      CurvedAnimation(
        parent: _titleSlideCtrl,
        curve: const Interval(0.0, 0.4, curve: Curves.easeOutCubic),
      ),
    );

    // Title opacity: fade in from 0% to 35%
    _titleOpacity = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _titleSlideCtrl,
        curve: const Interval(0.0, 0.35, curve: Curves.easeIn),
      ),
    );

    // Subtitle: slide up from 40px, from 25% to 60%
    _subtitleSlide = Tween<double>(begin: 40.0, end: 0.0).animate(
      CurvedAnimation(
        parent: _titleSlideCtrl,
        curve: const Interval(0.25, 0.6, curve: Curves.easeOutCubic),
      ),
    );

    // Subtitle opacity: fade in from 25% to 55%
    _subtitleOpacity = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _titleSlideCtrl,
        curve: const Interval(0.25, 0.55, curve: Curves.easeIn),
      ),
    );

    // Loader opacity: fade in from 55% to 80%
    _loaderOpacity = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _titleSlideCtrl,
        curve: const Interval(0.55, 0.8, curve: Curves.easeIn),
      ),
    );

    // ── Start logo fade FIRST, then after 800ms delay start title ──
    _fadeCtrl.forward();

    Future.delayed(const Duration(milliseconds: 1200), () {
      if (mounted) _titleSlideCtrl.forward();
    });

    _particleCtrl.addListener(_updateParticles);
  }

  void _initParticles(Size size) {
    if (_particles.isNotEmpty) return;
    for (int i = 0; i < 45; i++) {
      _particles.add(_createParticle(size, randomY: true));
    }
  }

  _Particle _createParticle(Size size, {bool randomY = false}) {
    final colors = [
      _marbleColors[_random.nextInt(_marbleColors.length)],
      Colors.white,
      const Color(0xFF80DEEA),
      const Color(0xFFCE93D8),
    ];
    return _Particle(
      x: _random.nextDouble() * size.width,
      y: randomY
          ? _random.nextDouble() * size.height
          : size.height + _random.nextDouble() * 40,
      speed: 0.2 + _random.nextDouble() * 0.8, // slower particles
      radius: 1.0 + _random.nextDouble() * 3.5,
      opacity: 0.1 + _random.nextDouble() * 0.45,
      color: colors[_random.nextInt(colors.length)],
      angle: _random.nextDouble() * 2 * pi,
      drift: (_random.nextDouble() - 0.5) * 0.5, // gentler drift
    );
  }

  void _updateParticles() {
    if (!mounted) return;
    final size = MediaQuery.of(context).size;
    for (int i = 0; i < _particles.length; i++) {
      final p = _particles[i];
      p.y -= p.speed;
      p.x += sin(p.angle) * p.drift;
      p.angle += 0.008; // slower angle change

      if (p.y < -10 || p.x < -10 || p.x > size.width + 10) {
        _particles[i] = _createParticle(size);
      }
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_started) return;
    _started = true;
    WidgetsBinding.instance.addPostFrameCallback((_) => _startFlow());
  }

  Future<void> _startFlow() async {
    precacheImage(const AssetImage('assets/images/logo.png'), context);
    UserService.preWarm();

    // ── Wait 5 seconds so user can enjoy the splash ──
    await Future.delayed(const Duration(milliseconds: 5000));
    if (!mounted) return;

    Navigator.of(context).pushReplacement(
      PageRouteBuilder(
        pageBuilder: (_, __, ___) => const MenuScreen(),
        transitionsBuilder: (_, a, __, child) =>
            FadeTransition(opacity: a, child: child),
        transitionDuration: const Duration(milliseconds: 600),
      ),
    );
  }

  @override
  void dispose() {
    _fadeCtrl.dispose();
    _pulseCtrl.dispose();
    _particleCtrl.dispose();
    _ringCtrl.dispose();
    _titleSlideCtrl.dispose();
    _shimmerCtrl.dispose();
    _marbleOrbitCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final t = ref.watch(boardThemeProvider);
    final size = MediaQuery.of(context).size;

    _initParticles(size);

    // Logo container size scales with screen
    final logoAreaSize = size.width * 0.82;
    final logoImageSize = size.width * 0.55;

    return Scaffold(
      body: Stack(
        fit: StackFit.expand,
        children: [
          // ── Background gradient ──
          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  t.backgroundGradient.colors.first,
                  t.backgroundGradient.colors.first.withOpacity(0.85),
                  t.backgroundGradient.colors.last,
                  t.backgroundGradient.colors.last.withOpacity(0.9),
                ],
                stops: const [0.0, 0.35, 0.65, 1.0],
              ),
            ),
          ),

          // ── Radial glow behind logo ──
          AnimatedBuilder(
            animation: _pulseCtrl,
            builder: (context, child) {
              return Center(
                child: Transform.translate(
                  offset: const Offset(0, -40),
                  child: Container(
                    width: logoAreaSize + 60 + (_pulseCtrl.value * 40),
                    height: logoAreaSize + 60 + (_pulseCtrl.value * 40),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: RadialGradient(
                        colors: [
                          t.accent.withOpacity(0.10 + _pulseCtrl.value * 0.06),
                          t.accent.withOpacity(0.03),
                          Colors.transparent,
                        ],
                        stops: const [0.0, 0.5, 1.0],
                      ),
                    ),
                  ),
                ),
              );
            },
          ),

          // ── Floating particles ──
          AnimatedBuilder(
            animation: _particleCtrl,
            builder: (context, _) {
              return CustomPaint(
                size: size,
                painter: _ParticlePainter(
                  particles: _particles,
                  progress: _particleCtrl.value,
                ),
              );
            },
          ),

          // ── Main content ──
          SafeArea(
            child: Center(
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const SizedBox(height: 20),

                    // ══════════════════════════════════════
                    // ── BIG LOGO with rings + marbles ──
                    // ══════════════════════════════════════
                    AnimatedBuilder(
                      animation: Listenable.merge([
                        _fadeCtrl,
                        _pulseCtrl,
                        _ringCtrl,
                        _marbleOrbitCtrl,
                      ]),
                      builder: (context, child) {
                        return Transform.scale(
                          scale: _logoScale.value,
                          child: SizedBox(
                            width: logoAreaSize,
                            height: logoAreaSize,
                            child: Stack(
                              alignment: Alignment.center,
                              children: [
                                // Outer ring 1
                                Positioned.fill(
                                  child: CustomPaint(
                                    painter: _OrbitRingPainter(
                                      rotation: _ringCtrl.value * 2 * pi,
                                      color: t.accent.withOpacity(0.5),
                                      dashProgress: _ringCtrl.value,
                                    ),
                                  ),
                                ),
                                // Outer ring 2 (counter-rotate)
                                Positioned.fill(
                                  child: Padding(
                                    padding: const EdgeInsets.all(16),
                                    child: CustomPaint(
                                      painter: _OrbitRingPainter(
                                        rotation:
                                            -_ringCtrl.value * 2 * pi * 0.6,
                                        color: t.accent.withOpacity(0.25),
                                        dashProgress: 1 - _ringCtrl.value,
                                      ),
                                    ),
                                  ),
                                ),
                                // Orbiting marbles
                                Positioned.fill(
                                  child: Padding(
                                    padding: const EdgeInsets.all(6),
                                    child: CustomPaint(
                                      painter: _OrbitingMarblesPainter(
                                        rotation:
                                            _marbleOrbitCtrl.value * 2 * pi,
                                        marbleColors: _marbleColors,
                                      ),
                                    ),
                                  ),
                                ),
                                // Glow behind logo image
                                Container(
                                  width: logoImageSize + 30,
                                  height: logoImageSize + 30,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    boxShadow: [
                                      BoxShadow(
                                        color: t.accent.withOpacity(
                                            0.15 + _pulseCtrl.value * 0.12),
                                        blurRadius:
                                            50 + _pulseCtrl.value * 25,
                                        spreadRadius: 8,
                                      ),
                                    ],
                                  ),
                                ),
                                // Logo image with gentle breathing
                                Transform.scale(
                                  scale: 0.96 + (_pulseCtrl.value * 0.04),
                                  child: child,
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                      child: _buildLogo(t, logoImageSize),
                    ),

                    const SizedBox(height: 36),

                    // ══════════════════════════
                    // ── Title with shimmer ──
                    // ══════════════════════════
                    AnimatedBuilder(
                      animation:
                          Listenable.merge([_titleSlideCtrl, _shimmerCtrl]),
                      builder: (context, _) {
                        return Opacity(
                          opacity: _titleOpacity.value,
                          child: Transform.translate(
                            offset: Offset(0, _titleSlide.value),
                            child: ShaderMask(
                              blendMode: BlendMode.srcIn,
                              shaderCallback: (bounds) {
                                return LinearGradient(
                                  colors: [
                                    t.textPrimary,
                                    t.accent,
                                    t.textPrimary,
                                  ],
                                  stops: [
                                    (_shimmerCtrl.value - 0.3).clamp(0.0, 1.0),
                                    _shimmerCtrl.value,
                                    (_shimmerCtrl.value + 0.3).clamp(0.0, 1.0),
                                  ],
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                ).createShader(bounds);
                              },
                              child: Text(
                                'KNOCK THE MARBLE',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  fontSize: 30,
                                  fontWeight: FontWeight.w900,
                                  letterSpacing: 3,
                                  color: t.textPrimary,
                                  shadows: [
                                    Shadow(
                                      color: t.accent.withOpacity(0.5),
                                      blurRadius: 14,
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        );
                      },
                    ),

                    const SizedBox(height: 12),

                    // ══════════════════
                    // ── Subtitle ──
                    // ══════════════════
                    AnimatedBuilder(
                      animation: _titleSlideCtrl,
                      builder: (context, child) {
                        return Opacity(
                          opacity: _subtitleOpacity.value,
                          child: Transform.translate(
                            offset: Offset(0, _subtitleSlide.value),
                            child: child,
                          ),
                        );
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 22, vertical: 8),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(24),
                          border: Border.all(
                            color: t.accent.withOpacity(0.3),
                            width: 1.2,
                          ),
                          gradient: LinearGradient(
                            colors: [
                              t.accent.withOpacity(0.05),
                              t.accent.withOpacity(0.02),
                            ],
                          ),
                        ),
                        child: Text(
                          'STRATEGY BOARD GAME',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 4,
                            color: t.textSecondary,
                          ),
                        ),
                      ),
                    ),

                    const SizedBox(height: 44),

                    // ══════════════════════════════
                    // ── Marble-style loader ──
                    // ══════════════════════════════
                    AnimatedBuilder(
                      animation:
                          Listenable.merge([_titleSlideCtrl, _shimmerCtrl]),
                      builder: (context, _) {
                        return Opacity(
                          opacity: _loaderOpacity.value,
                          child: Column(
                            children: [
                              SizedBox(
                                width: 80,
                                height: 16,
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: List.generate(5, (i) {
                                    final delay = i * 0.18;
                                    final value =
                                        ((_shimmerCtrl.value - delay) % 1.0)
                                            .clamp(0.0, 1.0);
                                    final scale = 0.4 + 0.6 * sin(value * pi);
                                    return Padding(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 3),
                                      child: Transform.scale(
                                        scale: scale,
                                        child: Container(
                                          width: 10,
                                          height: 10,
                                          decoration: BoxDecoration(
                                            shape: BoxShape.circle,
                                            color: _marbleColors[i],
                                            boxShadow: [
                                              BoxShadow(
                                                color: _marbleColors[i]
                                                    .withOpacity(0.6),
                                                blurRadius: 8 * scale,
                                              ),
                                            ],
                                          ),
                                        ),
                                      ),
                                    );
                                  }),
                                ),
                              ),
                              const SizedBox(height: 16),
                              Text(
                                'Loading...',
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w500,
                                  color: t.textSecondary.withOpacity(0.6),
                                  letterSpacing: 3,
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                    ),

                    const SizedBox(height: 20),
                  ],
                ),
              ),
            ),
          ),

          // ── Corner glow: top-left ──
          Positioned(
            top: -50,
            left: -50,
            child: _buildCornerGlow(_marbleColors[0]),
          ),

          // ── Corner glow: bottom-right ──
          Positioned(
            bottom: -60,
            right: -60,
            child: _buildCornerGlow(_marbleColors[1]),
          ),

          // ── Corner glow: top-right ──
          Positioned(
            top: -40,
            right: -40,
            child: _buildCornerGlow(_marbleColors[4], size: 100),
          ),
        ],
      ),
    );
  }

  Widget _buildCornerGlow(Color color, {double size = 140}) {
    return AnimatedBuilder(
      animation: _pulseCtrl,
      builder: (context, _) {
        return Container(
          width: size + _pulseCtrl.value * 20,
          height: size + _pulseCtrl.value * 20,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: RadialGradient(
              colors: [
                color.withOpacity(0.12 + _pulseCtrl.value * 0.05),
                Colors.transparent,
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildLogo(dynamic t, double logoSize) {
    return Container(
      width: logoSize,
      height: logoSize,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(
          color: t.accent.withOpacity(0.35),
          width: 2.5,
        ),
        boxShadow: [
          BoxShadow(
            color: t.accent.withOpacity(0.1),
            blurRadius: 20,
            spreadRadius: 2,
          ),
        ],
      ),
      child: ClipOval(
        child: Image.asset(
          'assets/images/logo.png',
          width: logoSize,
          height: logoSize,
          fit: BoxFit.contain,
          gaplessPlayback: true,
          filterQuality: FilterQuality.medium,
          frameBuilder: (context, child, frame, wasSynchronouslyLoaded) {
            if (wasSynchronouslyLoaded || frame != null) return child;
            return _buildFallbackIcon(t, logoSize);
          },
          errorBuilder: (context, error, stackTrace) =>
              _buildFallbackIcon(t, logoSize),
        ),
      ),
    );
  }

  Widget _buildFallbackIcon(dynamic t, double logoSize) {
    return Container(
      width: logoSize,
      height: logoSize,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: RadialGradient(
          colors: [
            t.accent.withOpacity(0.25),
            t.accent.withOpacity(0.05),
          ],
        ),
      ),
      child: Icon(
        Icons.hexagon_rounded,
        size: logoSize * 0.5,
        color: t.accent.withOpacity(0.85),
      ),
    );
  }
}