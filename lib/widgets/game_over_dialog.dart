import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/player.dart';
import '../models/game_mode.dart';
import '../providers/settings_provider.dart';
import '../providers/game_provider.dart';
import '../providers/user_provider.dart';
import '../providers/room_provider.dart';
import '../services/game_save_service.dart';
import 'avatar_widget.dart';

class GameOverDialog extends ConsumerStatefulWidget {
  final Player winner;
  final VoidCallback onPlayAgain;
  final VoidCallback onMainMenu;
  final bool earnedBonus;

  const GameOverDialog({
    super.key,
    required this.winner,
    required this.onPlayAgain,
    required this.onMainMenu,
    this.earnedBonus = false,
  });

  @override
  ConsumerState<GameOverDialog> createState() => _GameOverDialogState();
}

class _GameOverDialogState extends ConsumerState<GameOverDialog>
    with TickerProviderStateMixin {
  late AnimationController _bgCtrl;
  late AnimationController _trophyCtrl;
  late AnimationController _titleCtrl;
  late AnimationController _cardCtrl;
  late AnimationController _buttonsCtrl;
  late AnimationController _confettiCtrl;
  late AnimationController _glowCtrl;
  late AnimationController _shimmerCtrl;
  late AnimationController _fireworkCtrl;
  late AnimationController _burstCtrl;

  late Animation<double> _bgAnim;
  late Animation<double> _trophyScale;
  late Animation<double> _trophyRotate;
  late Animation<double> _titleSlide;
  late Animation<double> _titleFade;
  late Animation<double> _cardSlide;
  late Animation<double> _cardFade;
  late Animation<double> _btnSlide;
  late Animation<double> _btnFade;
  late Animation<double> _glowAnim;
  late Animation<double> _shimmerAnim;

  final List<_Confetti> _confetti = [];
  final List<_Firework> _fireworks = [];
  final List<_Star> _stars = [];
  final _rng = Random();

  late final GameMode _mode;
  late final _WinnerInfo _info;
  late final AiDifficulty _diff;
  late final int _bScore;
  late final int _wScore;
  bool _alive = true;

  @override
  void initState() {
    super.initState();

    final n = ref.read(gameProvider.notifier);
    final g = ref.read(gameProvider);
    _mode = n.mode;
    _info = _buildWinnerInfo(_mode);
    _diff = n.aiDifficulty;
    _bScore = g.blackScore;
    _wScore = g.whiteScore;

    GameSaveService.deleteSave(_mode);

    _setupAnimations();
    _generateParticles();
    _runSequence();
  }

  void _setupAnimations() {
    _bgCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 600));
    _bgAnim = CurvedAnimation(parent: _bgCtrl, curve: Curves.easeOut);

    _trophyCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 1200));
    _trophyScale = Tween(begin: 0.0, end: 1.0).animate(
        CurvedAnimation(parent: _trophyCtrl, curve: Curves.elasticOut));
    _trophyRotate = Tween(begin: -0.5, end: 0.0).animate(CurvedAnimation(
        parent: _trophyCtrl,
        curve: const Interval(0.0, 0.6, curve: Curves.easeOut)));

    _titleCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 800));
    _titleSlide = Tween(begin: 30.0, end: 0.0).animate(
        CurvedAnimation(parent: _titleCtrl, curve: Curves.easeOutCubic));
    _titleFade = CurvedAnimation(parent: _titleCtrl, curve: Curves.easeOut);

    _cardCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 700));
    _cardSlide = Tween(begin: 40.0, end: 0.0).animate(
        CurvedAnimation(parent: _cardCtrl, curve: Curves.easeOutCubic));
    _cardFade = CurvedAnimation(parent: _cardCtrl, curve: Curves.easeOut);

    _buttonsCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 700));
    _btnSlide = Tween(begin: 50.0, end: 0.0).animate(
        CurvedAnimation(parent: _buttonsCtrl, curve: Curves.easeOutCubic));
    _btnFade = CurvedAnimation(parent: _buttonsCtrl, curve: Curves.easeOut);

    // ═══════════════════════════════════════
    // SLOW: Confetti takes 10 seconds to fall
    // ═══════════════════════════════════════
    _confettiCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 10000));

    _glowCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 2500));
    _glowAnim = Tween(begin: 0.4, end: 1.0).animate(
        CurvedAnimation(parent: _glowCtrl, curve: Curves.easeInOut));

    _shimmerCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 3000));
    _shimmerAnim =
        CurvedAnimation(parent: _shimmerCtrl, curve: Curves.linear);

    // ═══════════════════════════════════════
    // SLOW: Fireworks over 6 seconds
    // ═══════════════════════════════════════
    _fireworkCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 6000));

    _burstCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 2500));
  }
  void _generateParticles() {
    final colors = [
      const Color(0xFFFFD700),
      const Color(0xFFFF6B6B),
      const Color(0xFF4ECDC4),
      const Color(0xFF45B7D1),
      const Color(0xFFFFA07A),
      const Color(0xFF98D8C8),
      const Color(0xFFF7DC6F),
      const Color(0xFFBB8FCE),
      const Color(0xFF85C1E9),
      const Color(0xFFE74C3C),
      const Color(0xFF2ECC71),
      const Color(0xFFE67E22),
    ];

    // ═══════════════════════════════════════
    // CONFETTI: Slower fall, more spread out
    // ═══════════════════════════════════════
    for (int i = 0; i < 100; i++) {
      _confetti.add(_Confetti(
        x: _rng.nextDouble(),
        y: -0.05 - _rng.nextDouble() * 0.3,
        sx: (_rng.nextDouble() - 0.5) * 0.2,   // Less horizontal drift
        sy: 0.08 + _rng.nextDouble() * 0.15,    // Much slower fall
        rot: _rng.nextDouble() * 360,
        rotSpd: (_rng.nextDouble() - 0.5) * 8,  // Slower spin
        size: 4 + _rng.nextDouble() * 10,
        color: colors[_rng.nextInt(colors.length)],
        shape: _rng.nextInt(4),
        delay: _rng.nextDouble() * 0.6,         // More spread in timing
        wobSpd: 1 + _rng.nextDouble() * 2,      // Gentle wobble
        wobAmt: 15 + _rng.nextDouble() * 30,    // Wide wobble
      ));
    }

    // ═══════════════════════════════════════
    // FIREWORKS: Spaced out over time, one by one
    // ═══════════════════════════════════════
    for (int i = 0; i < 8; i++) {
      final sparks = <_Spark>[];
      final c = colors[_rng.nextInt(colors.length)];
      final cnt = 14 + _rng.nextInt(12);
      for (int s = 0; s < cnt; s++) {
        sparks.add(_Spark(
          angle: (s / cnt) * pi * 2 + _rng.nextDouble() * 0.3,
          speed: 0.04 + _rng.nextDouble() * 0.07,
          size: 2 + _rng.nextDouble() * 3.5,
          color:
              Color.lerp(c, Colors.white, _rng.nextDouble() * 0.5)!,
        ));
      }
      _fireworks.add(_Firework(
        x: 0.1 + _rng.nextDouble() * 0.8,
        y: 0.05 + _rng.nextDouble() * 0.35,
        // Each firework has its own time window
        delay: i * 0.12,
        sparks: sparks,
      ));
    }

    for (int i = 0; i < 30; i++) {
      _stars.add(_Star(
        x: _rng.nextDouble(),
        y: _rng.nextDouble(),
        size: 1 + _rng.nextDouble() * 3,
        spd: 1 + _rng.nextDouble() * 3,
        delay: _rng.nextDouble(),
      ));
    }
  }
  Future<void> _runSequence() async {
    if (!_alive) return;
    HapticFeedback.heavyImpact();

    // Step 1: Background
    _bgCtrl.forward();
    await Future.delayed(const Duration(milliseconds: 400));
    if (!_alive) return;

    // Step 2: Trophy bounces in
    _trophyCtrl.forward();
    _burstCtrl.forward();
    HapticFeedback.mediumImpact();
    await Future.delayed(const Duration(milliseconds: 600));
    if (!_alive) return;

    // Step 3: Confetti starts falling slowly
    _confettiCtrl.forward();
    _glowCtrl.repeat(reverse: true);
    _shimmerCtrl.repeat();
    await Future.delayed(const Duration(milliseconds: 400));
    if (!_alive) return;

    // Step 4: Title
    _titleCtrl.forward();
    HapticFeedback.lightImpact();
    await Future.delayed(const Duration(milliseconds: 500));
    if (!_alive) return;

    // Step 5: Fireworks start (they play over 6 seconds)
    _fireworkCtrl.forward();
    HapticFeedback.mediumImpact();
    await Future.delayed(const Duration(milliseconds: 400));
    if (!_alive) return;

    // Step 6: Winner card
    _cardCtrl.forward();
    await Future.delayed(const Duration(milliseconds: 500));
    if (!_alive) return;

    // Step 7: Buttons
    _buttonsCtrl.forward();
    HapticFeedback.lightImpact();

    // ═══════════════════════════════════════
    // Keep fireworks repeating for celebration
    // ═══════════════════════════════════════
    await Future.delayed(const Duration(milliseconds: 5000));
    if (!_alive) return;

    // Restart fireworks for continuous celebration
    _fireworkCtrl.forward(from: 0);

    // Restart confetti too
    await Future.delayed(const Duration(milliseconds: 6000));
    if (!_alive) return;
    _confettiCtrl.forward(from: 0);
    _fireworkCtrl.forward(from: 0);
  }
  @override
  void dispose() {
    _alive = false;
    _bgCtrl.dispose();
    _trophyCtrl.dispose();
    _titleCtrl.dispose();
    _cardCtrl.dispose();
    _buttonsCtrl.dispose();
    _confettiCtrl.dispose();
    _glowCtrl.dispose();
    _shimmerCtrl.dispose();
    _fireworkCtrl.dispose();
    _burstCtrl.dispose();
    super.dispose();
  }

  // Safe clamp helper
  double _op(double v) => v.clamp(0.0, 1.0);

  @override
  Widget build(BuildContext context) {
    final t = ref.watch(boardThemeProvider);
    final screen = MediaQuery.of(context).size;
    final compact = screen.height < 700;

    return AnimatedBuilder(
      animation: Listenable.merge([
        _bgCtrl, _trophyCtrl, _titleCtrl, _cardCtrl,
        _buttonsCtrl, _confettiCtrl, _glowCtrl,
        _shimmerCtrl, _fireworkCtrl, _burstCtrl,
      ]),
      builder: (context, _) {
        return Material(
          color: Colors.transparent,
          type: MaterialType.transparency,
          child: Stack(
            children: [
              // Dark overlay
              Positioned.fill(
                child: GestureDetector(
                  onTap: () {},
                  child: Container(
                    color: Colors.black.withOpacity(
                        _op(_bgAnim.value * 0.88)),
                  ),
                ),
              ),

              // Stars
              if (_info.isMe)
                Positioned.fill(
                  child: IgnorePointer(
                    child: CustomPaint(
                      painter: _StarsPainter(
                        stars: _stars, time: _shimmerAnim.value),
                    ),
                  ),
                ),

              // Fireworks
              if (_info.isMe)
                Positioned.fill(
                  child: IgnorePointer(
                    child: CustomPaint(
                      painter: _FireworksPainter(
                        fireworks: _fireworks,
                        progress: _fireworkCtrl.value),
                    ),
                  ),
                ),

              // Confetti
              Positioned.fill(
                child: IgnorePointer(
                  child: CustomPaint(
                    painter: _ConfettiPainter(
                      particles: _confetti,
                      progress: _confettiCtrl.value),
                  ),
                ),
              ),

              // Content
              Positioned.fill(
                child: SafeArea(
                  child: Center(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 24, vertical: 16),
                      child: _buildContent(t, compact),
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

  Widget _buildContent(dynamic t, bool compact) {
    final isMe = _info.isMe;

    return DefaultTextStyle(
      style: const TextStyle(decoration: TextDecoration.none),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _buildTrophy(t, isMe, compact),
          SizedBox(height: compact ? 14 : 22),
          _buildTitle(t, isMe),
          SizedBox(height: compact ? 14 : 22),
          _buildWinnerCard(t, isMe, compact),
          SizedBox(height: compact ? 18 : 28),
          _buildButtons(t, isMe),
        ],
      ),
    );
  }

  // ══════════════════════════════════════
  // TROPHY
  // ══════════════════════════════════════

  Widget _buildTrophy(dynamic t, bool isMe, bool compact) {
    final sz = compact ? 100.0 : 120.0;
    final outerSz = sz + 40;

    return Transform.scale(
      scale: _trophyScale.value,
      child: Transform.rotate(
        angle: _trophyRotate.value,
        child: SizedBox(
          width: outerSz,
          height: outerSz,
          child: Stack(
            alignment: Alignment.center,
            children: [
              // Glow
              if (isMe)
                Container(
                  width: outerSz,
                  height: outerSz,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: RadialGradient(
                      colors: [
                        const Color(0xFFFFD700)
                            .withOpacity(_op(0.25 * _glowAnim.value)),
                        const Color(0xFFFFD700)
                            .withOpacity(_op(0.08 * _glowAnim.value)),
                        Colors.transparent,
                      ],
                      stops: const [0.0, 0.5, 1.0],
                    ),
                  ),
                ),

              // Burst rays
              if (isMe)
                ...List.generate(8, (i) {
                  final angle = (i / 8) * pi * 2;
                  final bp = _burstCtrl.value;
                  final len = sz * 0.4 *
                      Curves.easeOut
                          .transform((bp - i * 0.05).clamp(0.0, 1.0));
                  final op = bp > 0.7 ? (1.0 - (bp - 0.7) / 0.3) : 1.0;

                  return Positioned(
                    left: outerSz / 2 + cos(angle) * (sz * 0.35) - 1.5,
                    top: outerSz / 2 + sin(angle) * (sz * 0.35) - len / 2,
                    child: Transform.rotate(
                      angle: angle + pi / 2,
                      child: Container(
                        width: 3,
                        height: len,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(2),
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [
                              const Color(0xFFFFD700)
                                  .withOpacity(_op(op * 0.8)),
                              Colors.transparent,
                            ],
                          ),
                        ),
                      ),
                    ),
                  );
                }),

              // Circle
              Container(
                width: sz,
                height: sz,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: isMe
                        ? const [
                            Color(0xFFFFD700),
                            Color(0xFFFFA500),
                            Color(0xFFFF8C00)
                          ]
                        : const [
                            Color(0xFF607D8B),
                            Color(0xFF455A64),
                            Color(0xFF37474F)
                          ],
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: isMe
                          ? const Color(0xFFFFD700).withOpacity(0.5)
                          : Colors.black.withOpacity(0.3),
                      blurRadius: 30,
                      spreadRadius: 5,
                    ),
                  ],
                ),
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    // Shimmer sweep
                    if (isMe)
                      ClipOval(
                        child: ShaderMask(
                          shaderCallback: (bounds) {
                            return LinearGradient(
                              begin: Alignment(
                                  -2 + _shimmerAnim.value * 4, 0),
                              end: Alignment(
                                  -1 + _shimmerAnim.value * 4, 1),
                              colors: [
                                Colors.transparent,
                                Colors.white.withOpacity(0.2),
                                Colors.transparent,
                              ],
                              stops: const [0.0, 0.5, 1.0],
                            ).createShader(bounds);
                          },
                          blendMode: BlendMode.srcATop,
                          child: Container(
                            width: sz,
                            height: sz,
                            color: Colors.white.withOpacity(0.1),
                          ),
                        ),
                      ),
                    Icon(
                      isMe
                          ? Icons.emoji_events_rounded
                          : Icons.sentiment_dissatisfied_rounded,
                      size: sz * 0.5,
                      color: Colors.white,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ══════════════════════════════════════
  // TITLE — minimal text
  // ══════════════════════════════════════

  Widget _buildTitle(dynamic t, bool isMe) {
    return Transform.translate(
      offset: Offset(0, _titleSlide.value),
      child: Opacity(
        opacity: _op(_titleFade.value),
        child: ShaderMask(
          shaderCallback: (bounds) {
            if (!isMe) {
              return const LinearGradient(
                colors: [Colors.white70, Colors.white70],
              ).createShader(bounds);
            }
            return LinearGradient(
              begin: Alignment(-2 + _shimmerAnim.value * 4, 0),
              end: Alignment(-1 + _shimmerAnim.value * 4, 1),
              colors: const [
                Color(0xFFFFD700),
                Color(0xFFFFF8DC),
                Color(0xFFFFD700),
                Color(0xFFFFA500),
                Color(0xFFFFD700),
              ],
              stops: const [0.0, 0.3, 0.5, 0.7, 1.0],
            ).createShader(bounds);
          },
          child: Text(
            isMe ? 'VICTORY!' : 'DEFEAT',
            style: TextStyle(
              fontSize: isMe ? 32 : 28,
              fontWeight: FontWeight.w900,
              letterSpacing: 4,
              color: Colors.white,
              decoration: TextDecoration.none,
              height: 1.1,
            ),
            textAlign: TextAlign.center,
          ),
        ),
      ),
    );
  }

  // ══════════════════════════════════════
  // WINNER CARD — uses theme marble colors
  // ══════════════════════════════════════

  Widget _buildWinnerCard(dynamic t, bool isMe, bool compact) {
    final accent = isMe
        ? const Color(0xFFFFD700)
        : const Color(0xFF607D8B);

    // Use theme marble colors instead of hardcoded
    final marbleColors = widget.winner == Player.black
        ? t.blackMarbleColors as List<Color>
        : t.whiteMarbleColors as List<Color>;

    return Transform.translate(
      offset: Offset(0, _cardSlide.value),
      child: Opacity(
        opacity: _op(_cardFade.value),
        child: Container(
          width: double.infinity,
          constraints: const BoxConstraints(maxWidth: 340),
          padding: EdgeInsets.all(compact ? 16 : 20),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(24),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Colors.white.withOpacity(0.08),
                Colors.white.withOpacity(0.03),
              ],
            ),
            border: Border.all(
              color: accent.withOpacity(0.3), width: 1.5),
            boxShadow: [
              BoxShadow(
                color: accent.withOpacity(0.1),
                blurRadius: 20,
                spreadRadius: 2,
              ),
            ],
          ),
          child: Column(
            children: [
              // Avatar + Name row
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // Avatar with theme marble ring
                  Container(
                    padding: const EdgeInsets.all(3),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: accent.withOpacity(0.6), width: 2.5),
                      boxShadow: [
                        BoxShadow(
                          color: accent.withOpacity(0.2),
                          blurRadius: 10),
                      ],
                    ),
                    child: _info.avatarIndex != null
                        ? AvatarWidget(
                            avatarIndex: _info.avatarIndex!,
                            size: compact ? 48.0 : 56.0,
                          )
                        : Container(
                            width: compact ? 48.0 : 56.0,
                            height: compact ? 48.0 : 56.0,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              // Use theme colors!
                              gradient: RadialGradient(
                                center: const Alignment(-0.3, -0.35),
                                radius: 0.85,
                                colors: marbleColors,
                              ),
                            ),
                            child: Icon(
                              _opponentIcon(),
                              size: compact ? 24 : 28,
                              color: Colors.white.withOpacity(0.8),
                            ),
                          ),
                  ),

                  const SizedBox(width: 14),

                  // Name + crown
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          if (isMe)
                            const Padding(
                              padding: EdgeInsets.only(right: 6),
                              child:
                                  Text('👑', style: TextStyle(fontSize: 18)),
                            ),
                          Text(
                            _info.winnerName,
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: compact ? 18 : 22,
                              fontWeight: FontWeight.w900,
                              decoration: TextDecoration.none,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      // Marble color indicator using theme
                      
                    ],
                  ),
                ],
              ),

              SizedBox(height: compact ? 14 : 18),

              // Score display with theme marble dots
              _buildScoreRow(t, compact),

              // Difficulty badge
              if (_mode == GameMode.vsComputer) ...[
                const SizedBox(height: 10),
                _buildDiffBadge(),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildScoreRow(dynamic t, bool compact) {
    final blackColors = t.blackMarbleColors as List<Color>;
    final whiteColors = t.whiteMarbleColors as List<Color>;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        color: Colors.white.withOpacity(0.05),
        border: Border.all(color: Colors.white.withOpacity(0.08)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Black score
          _scoreItem(
            colors: blackColors,
            score: _bScore,
            isWinner: widget.winner == Player.black,
            compact: compact,
          ),

          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Text(
              ':',
              style: TextStyle(
                fontSize: 32,
                fontWeight: FontWeight.w900,
                color: Colors.white.withOpacity(0.2),
                decoration: TextDecoration.none,
              ),
            ),
          ),

          // White score
          _scoreItem(
            colors: whiteColors,
            score: _wScore,
            isWinner: widget.winner == Player.white,
            compact: compact,
          ),
        ],
      ),
    );
  }

  Widget _scoreItem({
    required List<Color> colors,
    required int score,
    required bool isWinner,
    required bool compact,
  }) {
    return Column(
      children: [
        // Theme marble dot
        Container(
          width: compact ? 28 : 32,
          height: compact ? 28 : 32,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: RadialGradient(
              center: const Alignment(-0.3, -0.35),
              radius: 0.85,
              colors: colors,
            ),
            border: Border.all(
              color: isWinner
                  ? const Color(0xFFFFD700).withOpacity(0.6)
                  : Colors.white.withOpacity(0.1),
              width: isWinner ? 2 : 1,
            ),
            boxShadow: isWinner
                ? [
                    BoxShadow(
                      color: const Color(0xFFFFD700).withOpacity(0.3),
                      blurRadius: 8,
                    )
                  ]
                : null,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          '$score',
          style: TextStyle(
            fontSize: compact ? 28 : 34,
            fontWeight: FontWeight.w900,
            color: isWinner
                ? const Color(0xFFFFD700)
                : Colors.white.withOpacity(0.4),
            decoration: TextDecoration.none,
          ),
        ),
      ],
    );
  }

  Widget _buildDiffBadge() {
    String label;
    IconData icon;
    Color color;
    switch (_diff) {
      case AiDifficulty.easy:
        label = 'Easy';
        icon = Icons.sentiment_satisfied;
        color = Colors.green;
      case AiDifficulty.medium:
        label = 'Medium';
        icon = Icons.psychology;
        color = Colors.orange;
      case AiDifficulty.hard:
        label = 'Hard';
        icon = Icons.local_fire_department;
        color = Colors.red;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        color: color.withOpacity(0.1),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              color: color,
              fontSize: 11,
              fontWeight: FontWeight.w700,
              decoration: TextDecoration.none,
            ),
          ),
        ],
      ),
    );
  }

  // ══════════════════════════════════════
  // BUTTONS
  // ══════════════════════════════════════

  Widget _buildButtons(dynamic t, bool isMe) {
    return Transform.translate(
      offset: Offset(0, _btnSlide.value),
      child: Opacity(
        opacity: _op(_btnFade.value),
        child: Container(
          constraints: const BoxConstraints(maxWidth: 340),
          child: Column(
            children: [
              // Rematch
              SizedBox(
                width: double.infinity,
                child: GestureDetector(
                  onTap: () {
                    HapticFeedback.mediumImpact();
                    widget.onPlayAgain();
                  },
                  child: AnimatedBuilder(
                    animation: _glowAnim,
                    builder: (_, __) => Container(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(18),
                        gradient: LinearGradient(
                          colors: isMe
                              ? const [Color(0xFFFFD700), Color(0xFFFFA500)]
                              : const [Color(0xFF4ECDC4), Color(0xFF45B7D1)],
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: (isMe
                                    ? const Color(0xFFFFD700)
                                    : const Color(0xFF4ECDC4))
                                .withOpacity(
                                    _op(0.2 + _glowAnim.value * 0.15)),
                            blurRadius: 16,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.replay_rounded,
                            color: isMe ? Colors.black87 : Colors.white,
                            size: 22,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            _mode == GameMode.vsComputer
                                ? 'REMATCH'
                                : 'PLAY AGAIN',
                            style: TextStyle(
                              color: isMe ? Colors.black87 : Colors.white,
                              fontSize: 16,
                              fontWeight: FontWeight.w900,
                              letterSpacing: 1,
                              decoration: TextDecoration.none,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 12),

              // Main menu
              SizedBox(
                width: double.infinity,
                child: GestureDetector(
                  onTap: () {
                    HapticFeedback.lightImpact();
                    widget.onMainMenu();
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(18),
                      color: Colors.white.withOpacity(0.06),
                      border:
                          Border.all(color: Colors.white.withOpacity(0.12)),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.home_rounded,
                          color: Colors.white.withOpacity(0.5),
                          size: 20,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'MAIN MENU',
                          style: TextStyle(
                            color: Colors.white.withOpacity(0.5),
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 0.5,
                            decoration: TextDecoration.none,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ══════════════════════════════════════
  // HELPERS
  // ══════════════════════════════════════

  IconData _opponentIcon() {
    switch (_mode) {
      case GameMode.vsComputer:
        return Icons.smart_toy_rounded;
      case GameMode.online:
        return Icons.person_outline_rounded;
      case GameMode.localMultiplayer:
        return Icons.person_rounded;
    }
  }

  _WinnerInfo _buildWinnerInfo(GameMode mode) {
    final user = ref.read(currentUserProvider);

    if (mode == GameMode.vsComputer) {
      final n = ref.read(gameProvider.notifier);
      final iWon = widget.winner == n.myColor;
      if (iWon) {
        return _WinnerInfo(
          name: user?.displayName.isNotEmpty == true
              ? user!.displayName
              : 'You',
          avatar: user?.avatarIndex,
          isMe: true,
        );
      }
      return _WinnerInfo(name: 'Computer', avatar: null, isMe: false);
    }

    if (mode == GameMode.online) {
      final room = ref.read(roomProvider);
      final iWon = widget.winner == room.myColor;
      if (iWon) {
        return _WinnerInfo(
          name: user?.displayName.isNotEmpty == true
              ? user!.displayName
              : 'You',
          avatar: user?.avatarIndex,
          isMe: true,
        );
      }
      String oppName = 'Opponent';
      int? oppAvatar;
      final rd = room.roomData;
      if (rd != null) {
        if (room.isHost) {
          oppName = rd.guestName ?? 'Opponent';
          oppAvatar = rd.guestAvatar;
        } else {
          oppName = rd.hostName;
          oppAvatar = rd.hostAvatar;
        }
      }
      return _WinnerInfo(name: oppName, avatar: oppAvatar, isMe: false);
    }

    if (widget.winner == Player.black) {
      return _WinnerInfo(
        name: user?.displayName.isNotEmpty == true
            ? user!.displayName
            : 'Player 1',
        avatar: user?.avatarIndex,
        isMe: true,
      );
    }
    return _WinnerInfo(name: 'Player 2', avatar: null, isMe: false);
  }
}

// ══════════════════════════════════════════════════════
// DATA CLASSES
// ══════════════════════════════════════════════════════

class _WinnerInfo {
  final String name;
  final int? avatar;
  final bool isMe;
  _WinnerInfo({required this.name, this.avatar, required this.isMe});

  String get winnerName => name;
  int? get avatarIndex => avatar;
}

class _Confetti {
  double x, y;
  final double sx, sy, rot, rotSpd, size, delay, wobSpd, wobAmt;
  final Color color;
  final int shape;
  _Confetti({
    required this.x,
    required this.y,
    required this.sx,
    required this.sy,
    required this.rot,
    required this.rotSpd,
    required this.size,
    required this.color,
    required this.shape,
    required this.delay,
    required this.wobSpd,
    required this.wobAmt,
  });
}

class _Spark {
  final double angle, speed, size;
  final Color color;
  _Spark({
    required this.angle,
    required this.speed,
    required this.size,
    required this.color,
  });
}

class _Firework {
  final double x, y, delay;
  final List<_Spark> sparks;
  _Firework({
    required this.x,
    required this.y,
    required this.delay,
    required this.sparks,
  });
}

class _Star {
  final double x, y, size, spd, delay;
  _Star({
    required this.x,
    required this.y,
    required this.size,
    required this.spd,
    required this.delay,
  });
}

// ══════════════════════════════════════════════════════
// CONFETTI PAINTER
// ══════════════════════════════════════════════════════

class _ConfettiPainter extends CustomPainter {
  final List<_Confetti> particles;
  final double progress;
  _ConfettiPainter({required this.particles, required this.progress});

  @override
  void paint(Canvas canvas, Size size) {
    for (final p in particles) {
      final t =
          ((progress - p.delay) / (1.0 - p.delay)).clamp(0.0, 1.0);
      if (t <= 0) continue;

      final wobble = sin(t * p.wobSpd * pi * 2) * p.wobAmt;
      final cx = p.x * size.width + p.sx * size.width * t + wobble;
      // ═══════════════════════════════════════
      // SLOWER gravity — reduced t*t multiplier
      // ═══════════════════════════════════════
      final cy =
          p.y * size.height + p.sy * size.height * t + t * t * 60;
      final r = (p.rot + p.rotSpd * t * 360) * pi / 180;

      // ═══════════════════════════════════════
      // LONGER visible — fade only in last 10%
      // ═══════════════════════════════════════
      final op = (t < 0.9 ? 1.0 : (1.0 - (t - 0.9) / 0.1))
          .clamp(0.0, 1.0);
      if (op <= 0) continue;

      final paint = Paint()
        ..color = p.color.withOpacity(op)
        ..style = PaintingStyle.fill;

      canvas.save();
      canvas.translate(cx, cy);
      canvas.rotate(r);

      final scaleX =
          cos(t * pi * 2 + p.delay * pi * 2).abs().clamp(0.3, 1.0);

      switch (p.shape) {
        case 0:
          canvas.scale(scaleX, 1.0);
          canvas.drawRect(
              Rect.fromCenter(
                  center: Offset.zero,
                  width: p.size,
                  height: p.size * 0.5),
              paint);
          break;
        case 1:
          canvas.drawCircle(Offset.zero, p.size * 0.35, paint);
          break;
        case 2:
          final path = Path()
            ..moveTo(0, -p.size * 0.4)
            ..lineTo(p.size * 0.25, 0)
            ..lineTo(0, p.size * 0.4)
            ..lineTo(-p.size * 0.25, 0)
            ..close();
          canvas.drawPath(path, paint);
          break;
        case 3:
          canvas.scale(scaleX, 1.0);
          final path = Path();
          for (int i = 0; i < 10; i++) {
            final a = (i * 36 - 90) * pi / 180;
            final rad = i.isEven ? p.size * 0.4 : p.size * 0.2;
            final pt = Offset(cos(a) * rad, sin(a) * rad);
            if (i == 0) {
              path.moveTo(pt.dx, pt.dy);
            } else {
              path.lineTo(pt.dx, pt.dy);
            }
          }
          path.close();
          canvas.drawPath(path, paint);
          break;
      }
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(covariant _ConfettiPainter old) =>
      old.progress != progress;
}
// ══════════════════════════════════════════════════════
// FIREWORKS PAINTER
// ══════════════════════════════════════════════════════

class _FireworksPainter extends CustomPainter {
  final List<_Firework> fireworks;
  final double progress;
  _FireworksPainter({required this.fireworks, required this.progress});

  @override
  void paint(Canvas canvas, Size size) {
    for (final fw in fireworks) {
      // ═══════════════════════════════════════
      // Each firework gets 30% of total time to play
      // With delay spacing, they appear one by one
      // ═══════════════════════════════════════
      final windowSize = 0.3;
      final t = ((progress - fw.delay) / windowSize).clamp(0.0, 1.0);
      if (t <= 0) continue;

      final cx = fw.x * size.width;
      final cy = fw.y * size.height;
      // Slower expansion
      final expand = Curves.easeOutCubic.transform(t);
      // Fade in last 40%
      final op = (t < 0.6 ? 1.0 : (1.0 - (t - 0.6) / 0.4))
          .clamp(0.0, 1.0);

      for (final s in fw.sparks) {
        final dist = s.speed * size.width * expand;
        final sx = cx + cos(s.angle) * dist;
        final sy = cy + sin(s.angle) * dist;

        // Longer trail
        final trailDist = dist * 0.4;
        final tx = cx + cos(s.angle) * (dist - trailDist);
        final ty = cy + sin(s.angle) * (dist - trailDist);

        // Trail line
        canvas.drawLine(
          Offset(tx, ty),
          Offset(sx, sy),
          Paint()
            ..color = s.color.withOpacity((op * 0.5).clamp(0.0, 1.0))
            ..strokeWidth = s.size * 0.6
            ..strokeCap = StrokeCap.round,
        );

        // Spark dot
        final dotSize = s.size * (1 - t * 0.4);
        canvas.drawCircle(
          Offset(sx, sy),
          dotSize,
          Paint()..color = s.color.withOpacity(op),
        );

        // Bright center glow
        canvas.drawCircle(
          Offset(sx, sy),
          dotSize * 0.5,
          Paint()
            ..color = Colors.white.withOpacity((op * 0.7).clamp(0.0, 1.0)),
        );

        // Outer glow
        canvas.drawCircle(
          Offset(sx, sy),
          s.size * 3,
          Paint()
            ..color = s.color.withOpacity((op * 0.15).clamp(0.0, 1.0))
            ..maskFilter =
                const MaskFilter.blur(BlurStyle.normal, 6),
        );
      }
    }
  }

  @override
  bool shouldRepaint(covariant _FireworksPainter old) =>
      old.progress != progress;
}
// ══════════════════════════════════════════════════════
// STARS PAINTER
// ══════════════════════════════════════════════════════

class _StarsPainter extends CustomPainter {
  final List<_Star> stars;
  final double time;
  _StarsPainter({required this.stars, required this.time});

  @override
  void paint(Canvas canvas, Size size) {
    for (final s in stars) {
      final twinkle =
          (sin((time * s.spd + s.delay) * pi * 2) * 0.5 + 0.5)
              .clamp(0.0, 1.0);
      final op = (twinkle * 0.7).clamp(0.0, 1.0);

      canvas.drawCircle(
        Offset(s.x * size.width, s.y * size.height),
        s.size * (0.5 + twinkle * 0.5),
        Paint()
          ..color = Colors.white.withOpacity(op)
          ..maskFilter =
              MaskFilter.blur(BlurStyle.normal, s.size * 0.5),
      );
    }
  }

  @override
  bool shouldRepaint(covariant _StarsPainter old) => old.time != time;
}