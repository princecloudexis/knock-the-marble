import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/player.dart';
import '../models/game_mode.dart';
import '../providers/game_provider.dart';
import '../providers/settings_provider.dart';
import '../providers/user_provider.dart';
import '../providers/room_provider.dart';
import '../theme/board_themes.dart';
import 'avatar_widget.dart';

class PlayerPanel extends ConsumerWidget {
  final Player player;
  final int score;
  final bool isActive;
  final bool isTop;

  const PlayerPanel({
    super.key,
    required this.player,
    required this.score,
    required this.isActive,
    required this.isTop,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = ref.watch(boardThemeProvider);
    final notifier = ref.read(gameProvider.notifier);
    final mode = notifier.mode;
    final isBlack = player == Player.black;
    final screen = MediaQuery.of(context).size;
    final compact = screen.height < 700;

    final bool isAi =
        mode == GameMode.vsComputer && player == notifier.aiColor;
    final gameState = ref.watch(gameProvider);
    final aiThinking = isAi && gameState.isAnimating;

    final bool isMe = _isMyPanel(ref, mode, notifier);
    final playerInfo =
        _getPlayerInfo(ref, mode, isBlack, isAi, notifier, isMe);

    final List<Color> marbleColors =
        isBlack ? t.blackMarbleColors : t.whiteMarbleColors;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 400),
      curve: Curves.easeOutCubic,
      margin: EdgeInsets.symmetric(
        horizontal: compact ? 12 : 16,
        vertical: compact ? 2 : 4,
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: CustomPaint(
          painter: _PanelBackgroundPainter(
            isActive: isActive,
            theme: t,
            isTop: isTop,
          ),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 400),
            padding: EdgeInsets.symmetric(
              horizontal: compact ? 10 : 14,
              vertical: compact ? 8 : 10,
            ),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: isActive
                    ? t.accent.withOpacity(0.5)
                    : t.surfaceBorder.withOpacity(0.3),
                width: isActive ? 1.5 : 0.5,
              ),
            ),
            child: Row(
              children: [
                _buildAvatarSection(
                  t, isBlack, isActive, playerInfo, isAi,
                  aiThinking, marbleColors, compact,
                ),
                SizedBox(width: compact ? 10 : 14),
                Expanded(
                  child: _buildInfoSection(
                    t, playerInfo, isActive, isAi, aiThinking,
                    isMe, mode, compact,
                  ),
                ),
                _buildCapturedMarbles(t, isActive, isBlack, compact),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ══════════════════════════════════════
  // AVATAR SECTION (unchanged)
  // ══════════════════════════════════════

  Widget _buildAvatarSection(
    BoardTheme t,
    bool isBlack,
    bool isActive,
    _PlayerInfo info,
    bool isAi,
    bool aiThinking,
    List<Color> marbleColors,
    bool compact,
  ) {
    final size = compact ? 36.0 : 42.0;

    return Stack(
      clipBehavior: Clip.none,
      children: [
        if (isActive)
          Positioned.fill(
            child: _ActiveGlowRing(color: t.accent, size: size),
          ),
        Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(
              color: isActive
                  ? t.accent.withOpacity(0.8)
                  : t.surfaceBorder.withOpacity(0.4),
              width: isActive ? 2.0 : 1.0,
            ),
            boxShadow: isActive
                ? [
                    BoxShadow(
                      color: t.accent.withOpacity(0.25),
                      blurRadius: 10,
                      spreadRadius: 2,
                    ),
                  ]
                : null,
          ),
          child: ClipOval(
            child: _avatarContent(t, isBlack, isActive, info, isAi, size),
          ),
        ),
        if (aiThinking)
          Positioned.fill(
            child: SizedBox(
              width: size,
              height: size,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: t.accent.withOpacity(0.8),
              ),
            ),
          ),
        if (isActive && !aiThinking)
          Positioned(
            bottom: -2,
            right: -2,
            child: Container(
              width: 12,
              height: 12,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: t.accent,
                border: Border.all(color: t.cardColor, width: 2),
                boxShadow: [
                  BoxShadow(
                    color: t.accent.withOpacity(0.5),
                    blurRadius: 6,
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }

  Widget _avatarContent(
    BoardTheme t,
    bool isBlack,
    bool isActive,
    _PlayerInfo info,
    bool isAi,
    double size,
  ) {
    if (info.avatarIndex != null && !isAi) {
      return AvatarWidget(
        avatarIndex: info.avatarIndex!,
        size: size,
        showBorder: false,
      );
    }

    if (isAi) {
      return Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF64748B), Color(0xFF475569)],
          ),
        ),
        child: Center(
          child: Icon(
            Icons.memory_rounded,
            color: Colors.white.withOpacity(isActive ? 1.0 : 0.6),
            size: size * 0.48,
          ),
        ),
      );
    }

    return Container(
      decoration: BoxDecoration(
        gradient: RadialGradient(
          center: const Alignment(-0.3, -0.35),
          radius: 0.9,
          colors: isBlack ? t.blackMarbleColors : t.whiteMarbleColors,
        ),
      ),
      child: Align(
        alignment: const Alignment(-0.3, -0.3),
        child: Container(
          width: size * 0.25,
          height: size * 0.14,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(50),
            gradient: LinearGradient(colors: [
              (isBlack ? t.blackHighlightColor : t.whiteHighlightColor)
                  .withOpacity(isBlack
                      ? t.blackHighlightOpacity
                      : t.whiteHighlightOpacity),
              Colors.transparent,
            ]),
          ),
        ),
      ),
    );
  }

  // ══════════════════════════════════════
  // INFO SECTION (unchanged)
  // ══════════════════════════════════════

  Widget _buildInfoSection(
    BoardTheme t,
    _PlayerInfo info,
    bool isActive,
    bool isAi,
    bool aiThinking,
    bool isMe,
    GameMode mode,
    bool compact,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          children: [
            Flexible(
              child: Text(
                info.name,
                style: TextStyle(
                  color: isActive
                      ? t.textPrimary
                      : t.textSecondary.withOpacity(0.7),
                  fontSize: compact ? 13 : 14,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.5,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            if (mode != GameMode.localMultiplayer) ...[
              const SizedBox(width: 6),
              _buildRoleChip(t, isMe, isAi),
            ],
          ],
        ),
        const SizedBox(height: 4),
        _buildTurnRow(t, isActive, aiThinking, compact),
      ],
    );
  }

  Widget _buildRoleChip(BoardTheme t, bool isMe, bool isAi) {
    final String label;
    final Color color;
    final IconData? icon;

    if (isAi) {
      label = 'AI';
      color = const Color(0xFF64748B);
      icon = Icons.memory_rounded;
    } else if (isMe) {
      label = 'YOU';
      color = t.accent;
      icon = null;
    } else {
      label = 'OPP';
      color = Colors.orange;
      icon = null;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withOpacity(0.2)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 8, color: color.withOpacity(0.8)),
            const SizedBox(width: 3),
          ],
          Text(
            label,
            style: TextStyle(
              color: color.withOpacity(0.9),
              fontSize: 8,
              fontWeight: FontWeight.w900,
              letterSpacing: 0.5,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTurnRow(
    BoardTheme t,
    bool isActive,
    bool aiThinking,
    bool compact,
  ) {
    if (aiThinking) {
      return _ThinkingDots(color: t.accent);
    }

    if (isActive) {
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _ActivePulseBar(color: t.accent),
          const SizedBox(width: 6),
          Text(
            'YOUR MOVE',
            style: TextStyle(
              color: t.accent,
              fontSize: compact ? 8 : 9,
              fontWeight: FontWeight.w900,
              letterSpacing: 1.5,
            ),
          ),
        ],
      );
    }

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 16,
          height: 2,
          decoration: BoxDecoration(
            color: t.textSecondary.withOpacity(0.15),
            borderRadius: BorderRadius.circular(1),
          ),
        ),
        const SizedBox(width: 6),
        Text(
          'WAITING',
          style: TextStyle(
            color: t.textSecondary.withOpacity(0.35),
            fontSize: compact ? 8 : 9,
            fontWeight: FontWeight.w700,
            letterSpacing: 1.5,
          ),
        ),
      ],
    );
  }

  // ══════════════════════════════════════
  // CAPTURED MARBLES (NEW — replaces score orbs)
  // ══════════════════════════════════════

  Widget _buildCapturedMarbles(
    BoardTheme t,
    bool isActive,
    bool isBlack,
    bool compact,
  ) {
    // This player captures OPPONENT marbles
    final capturedPlayer = isBlack ? Player.white : Player.black;
    final orbSize = compact ? 12.0 : 14.0;
    final spacing = compact ? 2.0 : 3.0;

    return AnimatedOpacity(
      duration: const Duration(milliseconds: 300),
      opacity: isActive ? 1.0 : 0.6,
      child: Container(
        padding: const EdgeInsets.all(6),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          color: isActive
              ? t.accent.withOpacity(0.06)
              : Colors.transparent,
          border: Border.all(
            color: isActive
                ? t.accent.withOpacity(0.15)
                : t.surfaceBorder.withOpacity(0.15),
            width: 0.5,
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              mainAxisSize: MainAxisSize.min,
              children: List.generate(3, (i) {
                return Padding(
                  padding: EdgeInsets.symmetric(horizontal: spacing / 2),
                  child: _CapturedMarble(
                    filled: i < score,
                    size: orbSize,
                    capturedPlayer: capturedPlayer,
                    theme: t,
                    isActive: isActive,
                    index: i,
                    totalScore: score,
                  ),
                );
              }),
            ),
            SizedBox(height: spacing),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: List.generate(3, (i) {
                final idx = i + 3;
                return Padding(
                  padding: EdgeInsets.symmetric(horizontal: spacing / 2),
                  child: _CapturedMarble(
                    filled: idx < score,
                    size: orbSize,
                    capturedPlayer: capturedPlayer,
                    theme: t,
                    isActive: isActive,
                    index: idx,
                    totalScore: score,
                  ),
                );
              }),
            ),
          ],
        ),
      ),
    );
  }

  // ══════════════════════════════════════
  // HELPERS (unchanged)
  // ══════════════════════════════════════

  bool _isMyPanel(WidgetRef ref, GameMode mode, GameNotifier notifier) {
    if (mode == GameMode.vsComputer) return player == notifier.myColor;
    if (mode == GameMode.online) {
      final room = ref.watch(roomProvider);
      return room.myColor != null && player == room.myColor;
    }
    if (mode == GameMode.localMultiplayer) return !isTop;
    return false;
  }

  _PlayerInfo _getPlayerInfo(
    WidgetRef ref,
    GameMode mode,
    bool isBlack,
    bool isAi,
    GameNotifier notifier,
    bool isMe,
  ) {
    if (isAi) {
      return _PlayerInfo(name: 'COMPUTER', avatarIndex: null, userId: null);
    }

    final user = ref.watch(currentUserProvider);

    if (mode == GameMode.online) {
      final room = ref.watch(roomProvider);
      final roomData = room.roomData;
      if (roomData != null) {
        if (isMe) {
          return _PlayerInfo(
            name: user?.displayName.isNotEmpty == true
                ? user!.displayName
                : user?.shortId ?? 'YOU',
            avatarIndex: user?.avatarIndex ?? 0,
            userId: user?.shortId,
          );
        } else {
          final opponentIsHost = !room.isHost;
          return _PlayerInfo(
            name: opponentIsHost
                ? roomData.hostName
                : (roomData.guestName ?? 'Opponent'),
            avatarIndex: opponentIsHost
                ? roomData.hostAvatar
                : roomData.guestAvatar,
            userId: null,
          );
        }
      }
    }

    if (mode == GameMode.vsComputer && isMe) {
      return _PlayerInfo(
        name: user?.displayName.isNotEmpty == true
            ? user!.displayName
            : user?.shortId ?? 'YOU',
        avatarIndex: user?.avatarIndex ?? 0,
        userId: user?.shortId,
      );
    }

    if (mode == GameMode.localMultiplayer) {
      if (isMe) {
        return _PlayerInfo(
          name: user?.displayName.isNotEmpty == true
              ? user!.displayName
              : 'PLAYER 1',
          avatarIndex: user?.avatarIndex ?? 0,
          userId: user?.shortId,
        );
      } else {
        return _PlayerInfo(
          name: 'PLAYER 2',
          avatarIndex: null,
          userId: null,
        );
      }
    }

    return _PlayerInfo(
      name: isBlack ? 'BLACK' : 'WHITE',
      avatarIndex: null,
      userId: null,
    );
  }
}

// ══════════════════════════════════════════════
// CAPTURED MARBLE WIDGET
// ══════════════════════════════════════════════

class _CapturedMarble extends StatefulWidget {
  final bool filled;
  final double size;
  final Player capturedPlayer;
  final BoardTheme theme;
  final bool isActive;
  final int index;
  final int totalScore;

  const _CapturedMarble({
    required this.filled,
    required this.size,
    required this.capturedPlayer,
    required this.theme,
    required this.isActive,
    required this.index,
    required this.totalScore,
  });

  @override
  State<_CapturedMarble> createState() => _CapturedMarbleState();
}

class _CapturedMarbleState extends State<_CapturedMarble>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  bool _wasFilled = false;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );
    _wasFilled = widget.filled;
    if (widget.filled) _ctrl.value = 1.0;
  }

  @override
  void didUpdateWidget(_CapturedMarble old) {
    super.didUpdateWidget(old);
    if (widget.filled && !_wasFilled) {
      // Newly captured — animate in
      _ctrl.forward(from: 0);
    } else if (!widget.filled && _wasFilled) {
      // Undo — animate out
      _ctrl.reverse();
    }
    _wasFilled = widget.filled;
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final t = widget.theme;
    final isBlack = widget.capturedPlayer == Player.black;
    final isLast = widget.filled &&
        widget.index == widget.totalScore - 1 &&
        widget.isActive;

    return AnimatedBuilder(
      animation: _ctrl,
      builder: (context, _) {
        final v = _ctrl.value;

        // Empty slot
        if (v < 0.01) {
          return Container(
            width: widget.size * 0.65,
            height: widget.size * 0.65,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: t.scoreEmpty,
            ),
          );
        }

        // Scale: 0 → overshoot → 1.0
        final scale = _elasticScale(v);
        // Rotation: full spin → 0
        final rotation = (1.0 - v) * math.pi * 1.5;

        return Transform.scale(
          scale: scale,
          child: Transform.rotate(
            angle: rotation,
            child: Container(
              width: widget.size,
              height: widget.size,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                boxShadow: [
                  if (isLast)
                    BoxShadow(
                      color: t.accent.withOpacity(0.4),
                      blurRadius: 6,
                      spreadRadius: 1,
                    ),
                  BoxShadow(
                    color: Colors.black.withOpacity(0.25),
                    blurRadius: 2,
                    offset: const Offset(0.5, 1),
                  ),
                ],
              ),
              child: CustomPaint(
                painter: _MiniMarblePainter(
                  isBlack: isBlack,
                  theme: t,
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  double _elasticScale(double t) {
    if (t < 0.6) {
      return t / 0.6 * 1.15;
    } else if (t < 0.8) {
      return 1.15 - (t - 0.6) / 0.2 * 0.15;
    } else {
      return 1.0 + (1.0 - t) / 0.2 * 0.03;
    }
  }
}

// ══════════════════════════════════════════════
// MINI MARBLE PAINTER
// ══════════════════════════════════════════════

class _MiniMarblePainter extends CustomPainter {
  final bool isBlack;
  final BoardTheme theme;

  _MiniMarblePainter({required this.isBlack, required this.theme});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final r = size.width / 2;
    final rect = Rect.fromCircle(center: center, radius: r);

    final colors = isBlack ? theme.blackMarbleColors : theme.whiteMarbleColors;
    final stops = isBlack ? theme.blackMarbleStops : theme.whiteMarbleStops;

    // Shadow
    canvas.drawCircle(
      Offset(center.dx + 0.3, center.dy + 0.8),
      r * 0.88,
      Paint()
        ..color = Colors.black.withOpacity(0.2)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 1.2),
    );

    // Main body
    canvas.drawCircle(
      center,
      r,
      Paint()
        ..shader = RadialGradient(
          center: const Alignment(-0.3, -0.35),
          radius: 0.9,
          colors: colors,
          stops: stops,
        ).createShader(rect),
    );

    // Highlight
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(center.dx - r * 0.2, center.dy - r * 0.25),
        width: r * 0.45,
        height: r * 0.25,
      ),
      Paint()..color = Colors.white.withOpacity(isBlack ? 0.12 : 0.3),
    );

    // Specular dot
    canvas.drawCircle(
      Offset(center.dx - r * 0.12, center.dy - r * 0.18),
      r * 0.08,
      Paint()..color = Colors.white.withOpacity(isBlack ? 0.25 : 0.5),
    );
  }

  @override
  bool shouldRepaint(covariant _MiniMarblePainter old) =>
      old.isBlack != isBlack || old.theme.type != theme.type;
}

// ══════════════════════════════════════════════
// PANEL BACKGROUND PAINTER (unchanged)
// ══════════════════════════════════════════════

class _PanelBackgroundPainter extends CustomPainter {
  final bool isActive;
  final BoardTheme theme;
  final bool isTop;

  _PanelBackgroundPainter({
    required this.isActive,
    required this.theme,
    required this.isTop,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (size.width <= 0 || size.height <= 0) return;

    final rect = Offset.zero & size;

    final basePaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: isActive
            ? [
                theme.cardColor.withOpacity(0.95),
                Color.lerp(theme.cardColor, theme.accent, 0.08)!
                    .withOpacity(0.9),
              ]
            : [
                theme.cardColor.withOpacity(0.35),
                theme.cardColor.withOpacity(0.25),
              ],
      ).createShader(rect);

    canvas.drawRect(rect, basePaint);

    if (isActive) {
      final linePaint = Paint()
        ..color = theme.accent.withOpacity(0.03)
        ..strokeWidth = 0.5;

      for (double y = 0; y < size.height; y += 3) {
        canvas.drawLine(Offset(0, y), Offset(size.width, y), linePaint);
      }

      final glowY = isTop ? size.height : 0.0;
      canvas.drawRect(
        Rect.fromLTWH(0, glowY - 1, size.width, 2),
        Paint()
          ..shader = LinearGradient(
            colors: [
              Colors.transparent,
              theme.accent.withOpacity(0.4),
              theme.accent.withOpacity(0.6),
              theme.accent.withOpacity(0.4),
              Colors.transparent,
            ],
            stops: const [0.0, 0.2, 0.5, 0.8, 1.0],
          ).createShader(Rect.fromLTWH(0, glowY, size.width, 2)),
      );

      canvas.drawRect(
        Rect.fromLTWH(0, isTop ? size.height - 4 : 0.0, size.width, 6),
        Paint()
          ..color = theme.accent.withOpacity(0.08)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4),
      );
    }
  }

  @override
  bool shouldRepaint(covariant _PanelBackgroundPainter old) {
    return old.isActive != isActive || old.theme.type != theme.type;
  }
}

// ══════════════════════════════════════════════
// ACTIVE GLOW RING (unchanged)
// ══════════════════════════════════════════════

class _ActiveGlowRing extends StatefulWidget {
  final Color color;
  final double size;
  const _ActiveGlowRing({required this.color, required this.size});

  @override
  State<_ActiveGlowRing> createState() => _ActiveGlowRingState();
}

class _ActiveGlowRingState extends State<_ActiveGlowRing>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _ctrl,
      builder: (context, _) {
        double v = _ctrl.value.clamp(0.0, 1.0);
        return Container(
          width: widget.size + 8,
          height: widget.size + 8,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: widget.color.withOpacity((0.15 + v * 0.15).clamp(0.0, 1.0)),
                blurRadius: (10.0 + v * 6.0).clamp(0.0, 50.0),
                spreadRadius: (1.0 + v * 2.0).clamp(0.0, 10.0),
              ),
            ],
          ),
        );
      },
    );
  }
}

// ══════════════════════════════════════════════
// ACTIVE PULSE BAR (unchanged)
// ══════════════════════════════════════════════

class _ActivePulseBar extends StatefulWidget {
  final Color color;
  const _ActivePulseBar({required this.color});

  @override
  State<_ActivePulseBar> createState() => _ActivePulseBarState();
}

class _ActivePulseBarState extends State<_ActivePulseBar>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _ctrl,
      builder: (context, _) {
        final v = _ctrl.value.clamp(0.0, 1.0);
        return Container(
          width: 20.0 + v * 8.0,
          height: 3,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(2),
            gradient: LinearGradient(
              colors: [
                widget.color.withOpacity(0.8),
                widget.color.withOpacity(0.2 + v * 0.3),
              ],
            ),
            boxShadow: [
              BoxShadow(
                color: widget.color.withOpacity(0.3 + v * 0.2),
                blurRadius: 4,
              ),
            ],
          ),
        );
      },
    );
  }
}

// ══════════════════════════════════════════════
// THINKING DOTS (FIXED — only show when AI is thinking)
// ══════════════════════════════════════════════

class _ThinkingDots extends StatefulWidget {
  final Color color;
  const _ThinkingDots({required this.color});

  @override
  State<_ThinkingDots> createState() => _ThinkingDotsState();
}

class _ThinkingDotsState extends State<_ThinkingDots>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(3, (i) {
        return AnimatedBuilder(
          animation: _ctrl,
          builder: (context, _) {
            final v = _ctrl.value.clamp(0.0, 1.0);
            final delay = i * 0.2;
            final t = ((v - delay) % 1.0).clamp(0.0, 1.0);
            final bounce = math.sin(t * math.pi).clamp(0.0, 1.0);

            return Container(
              margin: const EdgeInsets.symmetric(horizontal: 2),
              child: Transform.translate(
                offset: Offset(0, -bounce * 4),
                child: Container(
                  width: 5,
                  height: 5,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: widget.color.withOpacity(
                      (0.4 + bounce * 0.6).clamp(0.0, 1.0),
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: widget.color.withOpacity(
                          (bounce * 0.4).clamp(0.0, 1.0),
                        ),
                        blurRadius: 3,
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      }),
    );
  }
}

// ══════════════════════════════════════════════
// PLAYER INFO MODEL (unchanged)
// ══════════════════════════════════════════════

class _PlayerInfo {
  final String name;
  final int? avatarIndex;
  final String? userId;

  _PlayerInfo({
    required this.name,
    this.avatarIndex,
    this.userId,
  });
}