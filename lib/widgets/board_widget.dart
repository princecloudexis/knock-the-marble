import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/hex.dart';
import '../models/player.dart';
import '../models/game_mode.dart';
import '../models/game_state.dart';
import '../providers/settings_provider.dart';
import '../providers/game_provider.dart';
import '../theme/board_themes.dart';
import 'marble_widget.dart';

class BoardWidget extends ConsumerStatefulWidget {
  final Map<Hex, Player> board;
  final List<Hex> selection;
  final Set<Hex> hintHexes;
  final Set<Hex> pushTargets;
  final Player currentTurn;
  final ValueChanged<Hex> onHexTap;
  final bool flipBoard;

  const BoardWidget({
    super.key,
    required this.board,
    required this.selection,
    required this.hintHexes,
    required this.pushTargets,
    required this.currentTurn,
    required this.onHexTap,
    this.flipBoard = false,
  });

  @override
  ConsumerState<BoardWidget> createState() => _BoardWidgetState();
}

class _BoardWidgetState extends ConsumerState<BoardWidget>
    with TickerProviderStateMixin {
  // ══════════════════════════════════════
  // DRAG STATE
  // ══════════════════════════════════════
  Offset? _dragStart;
  Hex? _dragHex;
  Offset _dragOffset = Offset.zero;
  bool _isDragging = false;

  // ══════════════════════════════════════
  // LAST MOVE HIGHLIGHT
  // ══════════════════════════════════════
  final Set<Hex> _lastMoveFrom = {};
  final Set<Hex> _lastMoveTo = {};
  Timer? _autoStopTimer;
  bool _highlightsActive = false;

  late AnimationController _lastMoveCtrl;
  late Animation<double> _lastMoveAnim;

  // ══════════════════════════════════════
  // SLIDE ANIMATION
  // ══════════════════════════════════════
  late AnimationController _slideCtrl;
  late Animation<double> _slideAnim;
  MoveAnimationData? _activeSlideData;
  Map<Hex, Offset> _slideOffsets = {};
  bool _isSliding = false;

  MoveAnimationData? _pendingHighlightData;

  // ══════════════════════════════════════
  // ROLL-OFF ANIMATION
  // ══════════════════════════════════════
  late AnimationController _rollOffCtrl;
  late Animation<double> _rollOffAnim;
  List<_RollingMarble> _rollingMarbles = [];

  // ══════════════════════════════════════
  // LAYOUT CACHE
  // ══════════════════════════════════════
  double _baseSize = 0;
  double _cxOff = 0;
  double _cyOff = 0;
  double _totalW = 0;
  double _totalH = 0;
  double _flip = 1.0;
  double _hexRadius = 0;
  Offset _boardCenter = Offset.zero;

  Map<Hex, Player>? _prevBoard;
  int _prevMoveCount = 0;
  int _prevBlackScore = 0;
  int _prevWhiteScore = 0;
  List<Hex> _prevSelection = [];

  @override
  void initState() {
    super.initState();

    _lastMoveCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    );
    _lastMoveAnim = CurvedAnimation(
      parent: _lastMoveCtrl,
      curve: Curves.easeInOut,
    );

    _slideCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 320),
    );
    _slideAnim = CurvedAnimation(
      parent: _slideCtrl,
      curve: Curves.easeOutCubic,
    );

    _rollOffCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    );
    _rollOffAnim = CurvedAnimation(
      parent: _rollOffCtrl,
      curve: Curves.easeIn,
    );

    _prevSelection = List.from(widget.selection);
  }

  @override
  void dispose() {
    _autoStopTimer?.cancel();
    _lastMoveCtrl.dispose();
    _slideCtrl.dispose();
    _rollOffCtrl.dispose();
    super.dispose();
  }

  // ══════════════════════════════════════
  // FULL RESET — clears ALL visual state
  // ══════════════════════════════════════
   void _fullVisualReset() {
    // Clear all highlights
    _lastMoveFrom.clear();
    _lastMoveTo.clear();
    _highlightsActive = false;
    _autoStopTimer?.cancel();
    _lastMoveCtrl.stop();
    _lastMoveCtrl.reset();

    // Clear slide animation
    _isSliding = false;
    _slideOffsets.clear();
    _activeSlideData = null;
    _pendingHighlightData = null;
    if (_slideCtrl.isAnimating) {
      _slideCtrl.stop();
      _slideCtrl.reset();
    }

    // Clear roll-off animation
    _rollingMarbles.clear();
    if (_rollOffCtrl.isAnimating) {
      _rollOffCtrl.stop();
      _rollOffCtrl.reset();
    }

    // Clear drag state
    _dragStart = null;
    _dragHex = null;
    _dragOffset = Offset.zero;
    _isDragging = false;

    // Reset all tracking counters
    _prevMoveCount = 0;
    _prevBlackScore = 0;
    _prevWhiteScore = 0;
    _prevSelection = [];
    _prevBoard = null;
  }

  // ══════════════════════════════════════
  // DETECT GAME RESET
  // ══════════════════════════════════════
  bool _isGameReset() {
    final game = ref.read(gameProvider);

    // Move count went back to 0 from a higher number = restart
    if (game.moveCount == 0 && _prevMoveCount > 0) {
      return true;
    }

    // Both scores reset to 0 when they were previously > 0
    if (game.blackScore == 0 &&
        game.whiteScore == 0 &&
        (_prevBlackScore > 0 || _prevWhiteScore > 0)) {
      return true;
    }

    // No animation data AND moveCount is 0 AND board changed
    // (fresh game started)
    if (game.moveCount == 0 &&
        game.lastMoveAnimation == null &&
        game.selection.isEmpty &&
        game.hintHexes.isEmpty) {
      return true;
    }

    return false;
  }

  // ══════════════════════════════════════
  // DETECT BOARD AND SELECTION CHANGES
  // ══════════════════════════════════════
  @override
  void didUpdateWidget(BoardWidget old) {
    super.didUpdateWidget(old);

    // ═══════════════════════════════════════
    // FIX: Check for game reset FIRST
    // ═══════════════════════════════════════
    if (_isGameReset()) {
      setState(() {
        _fullVisualReset();
        _prevBoard = Map.from(widget.board);
      });
      return; // Don't process as a normal board change
    }

    // Board changed — start animations (normal gameplay only)
    if (old.board != widget.board) {
      final game = ref.read(gameProvider);
      final animData = game.lastMoveAnimation;
      final moveCount = game.moveCount;

      if (animData != null &&
          animData.animations.isNotEmpty &&
          moveCount > _prevMoveCount) {
        _startSlideAnimation(animData);
      } else if (_prevBoard != null) {
        _detectChanges(_prevBoard!, widget.board);
      }

      _prevMoveCount = moveCount;
      _prevBlackScore = game.blackScore;
      _prevWhiteScore = game.whiteScore;
    }

    // Selection changed: clear highlights when player starts selecting
    if (_prevSelection.isEmpty && widget.selection.isNotEmpty) {
      _clearHighlights();
    }

    _prevSelection = List.from(widget.selection);
    _prevBoard = Map.from(widget.board);
  }

  // ══════════════════════════════════════
  // SLIDE ANIMATION
  // ══════════════════════════════════════
  void _startSlideAnimation(MoveAnimationData data) {
    _activeSlideData = data;
    _pendingHighlightData = data;

    final offsets = <Hex, Offset>{};
    for (final anim in data.sliding) {
      final fromPx = _hexToPixel(anim.from);
      final toPx = _hexToPixel(anim.to);
      offsets[anim.to] = fromPx - toPx;
    }

    _slideOffsets = offsets;
    _isSliding = true;

    _slideCtrl.forward(from: 0).then((_) {
      if (!mounted) return;
      setState(() {
        _isSliding = false;
        _slideOffsets.clear();
        _activeSlideData = null;
      });

      // Apply highlights AFTER slide completes
      if (_pendingHighlightData != null) {
        _applyHighlightsFromAnimation(_pendingHighlightData!);
        _pendingHighlightData = null;
      }
    });

    if (data.pushedOff.isNotEmpty) {
      _startRollOff(data);
    }
  }

  // ══════════════════════════════════════
  // APPLY HIGHLIGHTS FROM ANIMATION DATA
  // ══════════════════════════════════════
  void _applyHighlightsFromAnimation(MoveAnimationData data) {
    if (!mounted) return;

    final newFrom = <Hex>{};
    final newTo = <Hex>{};

    for (final a in data.sliding) {
      newFrom.add(a.from);
      newTo.add(a.to);
    }

    if (newTo.isEmpty && newFrom.isEmpty) return;

    setState(() {
      _lastMoveFrom.clear();
      _lastMoveTo.clear();
      _lastMoveFrom.addAll(newFrom);
      _lastMoveTo.addAll(newTo);
      _highlightsActive = true;
    });

    _startLastMoveHighlight();
  }

  // ══════════════════════════════════════
  // ROLL-OFF ANIMATION
  // ══════════════════════════════════════
  void _startRollOff(MoveAnimationData data) {
    final dir = data.direction;
    final dirPxX =
        (math.sqrt(3) * dir.q + math.sqrt(3) / 2 * dir.r) * _flip;
    final dirPxY = (1.5 * dir.r) * _flip;
    final dirLen = math.sqrt(dirPxX * dirPxX + dirPxY * dirPxY);
    final normX = dirPxX / dirLen;
    final normY = dirPxY / dirLen;
    final rollDistance = _baseSize * 12.0;

    _rollingMarbles = data.pushedOff.map((anim) {
      final startPx = _hexToPixel(anim.from);
      return _RollingMarble(
        startPos: startPx,
        dirX: normX,
        dirY: normY,
        rollDistance: rollDistance,
        player: anim.player,
      );
    }).toList();

    Future.delayed(const Duration(milliseconds: 60), () {
      if (!mounted) return;
      _rollOffCtrl.forward(from: 0).then((_) {
        if (mounted) {
          setState(() => _rollingMarbles.clear());
        }
      });
    });
  }

  Offset _hexToPixel(Hex hex) {
    final px = math.sqrt(3) * hex.q + math.sqrt(3) / 2 * hex.r;
    final py = 1.5 * hex.r;
    return Offset(
      _totalW / 2 + (px - _cxOff) * _baseSize * _flip,
      _totalH / 2 + (py - _cyOff) * _baseSize * _flip,
    );
  }

  // ══════════════════════════════════════
  // CHANGE DETECTION (fallback when no animData)
  // ══════════════════════════════════════
  void _detectChanges(Map<Hex, Player> oldB, Map<Hex, Player> newB) {
    final newFrom = <Hex>{};
    final newTo = <Hex>{};

    final all = {...oldB.keys, ...newB.keys};
    for (final hex in all) {
      final o = oldB[hex] ?? Player.none;
      final n = newB[hex] ?? Player.none;
      if (o == n) continue;
      if (o != Player.none && n == Player.none) newFrom.add(hex);
      if (o == Player.none && n != Player.none) newTo.add(hex);
      if (o != Player.none && n != Player.none && o != n) {
        newTo.add(hex);
      }
    }

    if (newTo.isNotEmpty || newFrom.isNotEmpty) {
      setState(() {
        _lastMoveFrom.clear();
        _lastMoveTo.clear();
        _lastMoveFrom.addAll(newFrom);
        _lastMoveTo.addAll(newTo);
        _highlightsActive = true;
      });
      _startLastMoveHighlight();
    }
  }

  // ══════════════════════════════════════
  // HIGHLIGHT TIMER
  // ══════════════════════════════════════
  void _startLastMoveHighlight() {
    _autoStopTimer?.cancel();
    _lastMoveCtrl.repeat(reverse: true);
    _autoStopTimer = Timer(const Duration(seconds: 10), () {
      if (mounted) _clearHighlights();
    });
  }

  void _clearHighlights() {
    if (!_highlightsActive) return;
    setState(() {
      _lastMoveFrom.clear();
      _lastMoveTo.clear();
      _highlightsActive = false;
    });
    _lastMoveCtrl.stop();
    _lastMoveCtrl.reset();
    _autoStopTimer?.cancel();
  }

  // ══════════════════════════════════════
  // BUILD
  // ══════════════════════════════════════
  @override
  Widget build(BuildContext context) {
    final theme = ref.watch(boardThemeProvider);
    final showHints = ref.watch(showHintsProvider);
    final animSpeed = ref.watch(animationSpeedProvider);
    final isAiThinking = ref.watch(isAiThinkingProvider);
    final notifier = ref.read(gameProvider.notifier);
    final mode = notifier.mode;

    return LayoutBuilder(
      builder: (context, constraints) {
        final maxW = constraints.maxWidth;
        final maxH = constraints.maxHeight;

        double minX = double.infinity, maxX = double.negativeInfinity;
        double minY = double.infinity, maxY = double.negativeInfinity;

        for (final hex in widget.board.keys) {
          final px = math.sqrt(3) * hex.q + math.sqrt(3) / 2 * hex.r;
          final py = 1.5 * hex.r;
          if (px < minX) minX = px;
          if (px > maxX) maxX = px;
          if (py < minY) minY = py;
          if (py > maxY) maxY = py;
        }

        final gridW = (maxX - minX) + 2.0;
        final gridH = (maxY - minY) + 2.0;

        final sizeW = maxW / gridW;
        final sizeH = maxH / gridH;
        final baseSize = math.min(sizeW, sizeH);

        const mScale = 1.18;
        final visualSize = baseSize * mScale;
        final totalW = gridW * baseSize;
        final totalH = gridH * baseSize;
        final cxOff = (minX + maxX) / 2.0;
        final cyOff = (minY + maxY) / 2.0;
        final hexRadius = baseSize * 8.0;
        final flip = widget.flipBoard ? -1.0 : 1.0;
        final tapSize = visualSize * 1.1;

        _baseSize = baseSize;
        _cxOff = cxOff;
        _cyOff = cyOff;
        _totalW = totalW;
        _totalH = totalH;
        _flip = flip;
        _hexRadius = hexRadius;
        _boardCenter = Offset(totalW / 2, totalH / 2);

        return Center(
          child: SizedBox(
            width: totalW,
            height: totalH,
            child: CustomPaint(
              painter: _HexBoardPainter(
                centerX: totalW / 2,
                centerY: totalH / 2,
                hexRadius: hexRadius,
                marbleSize: baseSize,
                theme: theme,
                boardHexes: widget.board.keys.toList(),
                centerXOffset: cxOff,
                centerYOffset: cyOff,
                flip: flip,
              ),
              child: AnimatedBuilder(
                animation: Listenable.merge([
                  _lastMoveAnim,
                  _slideAnim,
                  _rollOffAnim,
                ]),
                builder: (context, _) {
                  final slideT = _isSliding ? _slideAnim.value : 1.0;

                  return Stack(
                    clipBehavior: Clip.none,
                    children: [
                      ...widget.board.keys.map((hex) => _buildHexTile(
                            hex: hex,
                            baseSize: baseSize,
                            visualSize: visualSize,
                            tapSize: tapSize,
                            totalW: totalW,
                            totalH: totalH,
                            cxOff: cxOff,
                            cyOff: cyOff,
                            flip: flip,
                            slideT: slideT,
                            theme: theme,
                            showHints: showHints,
                            animSpeed: animSpeed,
                            isAiThinking: isAiThinking,
                            mode: mode,
                          )),
                      ..._buildRollingMarbles(visualSize, theme),
                    ],
                  );
                },
              ),
            ),
          ),
        );
      },
    );
  }

  // ══════════════════════════════════════
  // ROLLING MARBLES
  // ══════════════════════════════════════
  List<Widget> _buildRollingMarbles(double marbleSize, BoardTheme theme) {
    if (_rollingMarbles.isEmpty) return [];

    final t = _rollOffAnim.value;
    final rollT = t * t;
    final rotation = t * math.pi * 4.0;
    final scale = (1.0 - t * 0.6).clamp(0.0, 1.0);
    final opacity = t > 0.7 ? ((1.0 - t) / 0.3).clamp(0.0, 1.0) : 1.0;

    return _rollingMarbles.map((rm) {
      final currentX =
          rm.startPos.dx + rm.dirX * rm.rollDistance * rollT;
      final currentY =
          rm.startPos.dy + rm.dirY * rm.rollDistance * rollT;
      final currentSize = marbleSize * scale;
      final halfSize = currentSize / 2;

      return Positioned(
        left: currentX - halfSize,
        top: currentY - halfSize,
        child: IgnorePointer(
          child: Opacity(
            opacity: opacity,
            child: Transform.rotate(
              angle: rotation,
              child: Transform.scale(
                scale: scale,
                child: SizedBox(
                  width: marbleSize,
                  height: marbleSize,
                  child: MarbleWidget(
                    player: rm.player,
                    size: marbleSize,
                    theme: theme,
                  ),
                ),
              ),
            ),
          ),
        ),
      );
    }).toList();
  }

  // ══════════════════════════════════════
  // HEX TILE
  // ══════════════════════════════════════
  Widget _buildHexTile({
    required Hex hex,
    required double baseSize,
    required double visualSize,
    required double tapSize,
    required double totalW,
    required double totalH,
    required double cxOff,
    required double cyOff,
    required double flip,
    required double slideT,
    required BoardTheme theme,
    required bool showHints,
    required double animSpeed,
    required bool isAiThinking,
    required GameMode mode,
  }) {
    final px = math.sqrt(3) * hex.q + math.sqrt(3) / 2 * hex.r;
    final py = 1.5 * hex.r;

    double centerX = totalW / 2 + (px - cxOff) * baseSize * flip;
    double centerY = totalH / 2 + (py - cyOff) * baseSize * flip;

    double left = centerX - tapSize / 2;
    double top = centerY - tapSize / 2;

    final slideOffset = _slideOffsets[hex];
    if (slideOffset != null && _isSliding) {
      final remaining = 1.0 - slideT;
      left += slideOffset.dx * remaining;
      top += slideOffset.dy * remaining;
    }

    if (_isDragging && _dragHex == hex) {
      left += _dragOffset.dx;
      top += _dragOffset.dy;
    }

    final isHint = showHints && widget.hintHexes.contains(hex);
    final isPush = showHints && widget.pushTargets.contains(hex);
    final isSelected = widget.selection.contains(hex);
    final isMyMarble = widget.board[hex] == widget.currentTurn;
    final isLastTarget = _lastMoveTo.contains(hex);
    final isLastSource = _lastMoveFrom.contains(hex);

    double bounceScale = 1.0;
    if (slideOffset != null && _isSliding && slideT > 0.75) {
      final bt = (slideT - 0.75) / 0.25;
      bounceScale = 1.0 + math.sin(bt * math.pi) * 0.04;
    }

    return Positioned(
      left: left,
      top: top,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () {
          if (!_isDragging) {
            widget.onHexTap(hex);
          }
        },
        onPanStart: (d) {
          if (isMyMarble || isSelected) {
            setState(() {
              _dragStart = d.globalPosition;
              _dragHex = hex;
              _dragOffset = Offset.zero;
              _isDragging = false;
            });
            if (!isSelected && isMyMarble) widget.onHexTap(hex);
          }
        },
        onPanUpdate: (d) {
          if (_dragStart != null && _dragHex != null) {
            final delta = d.globalPosition - _dragStart!;
            if (delta.distance > 10) {
              setState(() {
                _isDragging = true;
                _dragOffset = delta * 0.5;
              });
            }
          }
        },
        onPanEnd: (d) {
          if (_isDragging && _dragHex != null) {
            _handleDragEnd(d, hex, baseSize, flip);
          }
          setState(() {
            _dragStart = null;
            _dragHex = null;
            _dragOffset = Offset.zero;
            _isDragging = false;
          });
        },
        onPanCancel: () {
          setState(() {
            _dragStart = null;
            _dragHex = null;
            _dragOffset = Offset.zero;
            _isDragging = false;
          });
        },
        child: SizedBox(
          width: tapSize,
          height: tapSize,
          child: Center(
            child: Transform.scale(
              scale: bounceScale,
              child: SizedBox(
                width: visualSize,
                height: visualSize,
                child: _buildMarbleContent(
                  hex: hex,
                  marbleSize: visualSize,
                  theme: theme,
                  animSpeed: animSpeed,
                  isSelected: isSelected,
                  isHint: isHint,
                  isPush: isPush,
                  isLastTarget: isLastTarget,
                  isLastSource: isLastSource,
                  mode: mode,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  // ══════════════════════════════════════
  // MARBLE CONTENT WITH LAST-MOVE RINGS
  // ══════════════════════════════════════
  Widget _buildMarbleContent({
    required Hex hex,
    required double marbleSize,
    required BoardTheme theme,
    required double animSpeed,
    required bool isSelected,
    required bool isHint,
    required bool isPush,
    required bool isLastTarget,
    required bool isLastSource,
    required GameMode mode,
  }) {
    // Hide last-move rings when player has selected marbles
    final bool hasSelection = widget.selection.isNotEmpty;
    final bool showTarget = isLastTarget && !hasSelection && _highlightsActive;
    final bool showSource = isLastSource && !hasSelection && _highlightsActive;

    Widget marble = MarbleWidget(
      player: widget.board[hex]!,
      size: marbleSize,
      isSelected: isSelected,
      isHint: isHint,
      isPushTarget: isPush,
      theme: theme,
      animationSpeed: animSpeed,
    );

    // ── RING around marbles that just moved (destination) ──
    if (showTarget && !isSelected && widget.board[hex] != Player.none) {
      final isOnline = mode == GameMode.online;
      final ringColor =
          isOnline ? const Color(0xFF4CAF50) : const Color(0xFF4CAF50);

      marble = Stack(
        alignment: Alignment.center,
        children: [
          AnimatedBuilder(
            animation: _lastMoveAnim,
            builder: (context, _) {
              final v = _lastMoveAnim.value;
              return Container(
                width: marbleSize * 0.95,
                height: marbleSize * 0.95,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: ringColor.withOpacity(0.08 + v * 0.08),
                  border: Border.all(
                    color: ringColor.withOpacity(0.4 + v * 0.35),
                    width: isOnline ? 3.0 : 2.5,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: ringColor.withOpacity(0.1 + v * 0.15),
                      blurRadius: 6,
                      spreadRadius: 1,
                    ),
                  ],
                ),
              );
            },
          ),
          marble,
        ],
      );
    }

    // ── DOT where marbles moved FROM (source) ──
    if (showSource &&
        widget.board[hex] == Player.none &&
        !isSelected &&
        !isHint) {
      final isOnline = mode == GameMode.online;
      final dotColor =
          isOnline ? const Color(0xFF4CAF50) : theme.accent;

      marble = Stack(
        alignment: Alignment.center,
        children: [
          marble,
          AnimatedBuilder(
            animation: _lastMoveAnim,
            builder: (context, _) {
              final v = _lastMoveAnim.value;
              return Container(
                width: marbleSize * 0.25,
                height: marbleSize * 0.25,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: dotColor.withOpacity(0.2 + v * 0.15),
                  border: Border.all(
                    color: dotColor.withOpacity(0.3 + v * 0.2),
                    width: 1.5,
                  ),
                ),
              );
            },
          ),
        ],
      );
    }

    return marble;
  }

  // ══════════════════════════════════════
  // DRAG HANDLING
  // ══════════════════════════════════════
  void _handleDragEnd(
    DragEndDetails details,
    Hex hex,
    double marbleSize,
    double flip,
  ) {
    if (_dragStart == null || _dragHex == null) return;

    final dx = _dragOffset.dx * flip;
    final dy = _dragOffset.dy * flip;
    if (_dragOffset.distance < marbleSize * 0.3) return;

    final angle = math.atan2(dy, dx);
    final dir = _angleToHexDir(angle);

    if (dir != null) {
      ref.read(gameProvider.notifier).handleSwipeMove(_dragHex!, dir);
    }
  }

  Hex? _angleToHexDir(double angle) {
    final dirs = [
      (Hex(1, 0), 0.0),
      (Hex(1, -1), -60.0),
      (Hex(0, -1), -120.0),
      (Hex(-1, 0), 180.0),
      (Hex(-1, 1), 120.0),
      (Hex(0, 1), 60.0),
    ];

    final deg = angle * 180 / math.pi;
    Hex? best;
    double bestDiff = double.infinity;

    for (final (d, a) in dirs) {
      var diff = (deg - a).abs();
      if (diff > 180) diff = 360 - diff;
      if (diff < bestDiff) {
        bestDiff = diff;
        best = d;
      }
    }

    return bestDiff <= 30 ? best : null;
  }
}

// ══════════════════════════════════════════════
// ROLLING MARBLE DATA
// ══════════════════════════════════════════════

class _RollingMarble {
  final Offset startPos;
  final double dirX;
  final double dirY;
  final double rollDistance;
  final Player player;

  _RollingMarble({
    required this.startPos,
    required this.dirX,
    required this.dirY,
    required this.rollDistance,
    required this.player,
  });
}

// ══════════════════════════════════════════════
// HEX BOARD PAINTER
// ══════════════════════════════════════════════

class _HexBoardPainter extends CustomPainter {
  final double centerX;
  final double centerY;
  final double hexRadius;
  final double marbleSize;
  final BoardTheme theme;
  final List<Hex> boardHexes;
  final double centerXOffset;
  final double centerYOffset;
  final double flip;

  _HexBoardPainter({
    required this.centerX,
    required this.centerY,
    required this.hexRadius,
    required this.marbleSize,
    required this.theme,
    required this.boardHexes,
    required this.centerXOffset,
    required this.centerYOffset,
    this.flip = 1.0,
  });

  static const double boardRotationDeg = 30.0;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(centerX, centerY);
    final frameWidth = marbleSize * 0.5;

    canvas.drawPath(
      _hexagonPath(center, hexRadius + frameWidth + 6),
      Paint()
        ..color = Colors.black.withOpacity(0.10)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 16),
    );

    final outerPath = _hexagonPath(center, hexRadius + frameWidth);
    canvas.drawPath(outerPath, Paint()..color = theme.boardRimShadow);

    final bevelRect = Rect.fromCircle(
      center: center,
      radius: hexRadius + frameWidth,
    );
    canvas.drawPath(
      outerPath,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            theme.boardBorderColor,
            Color.lerp(theme.boardBorderColor, Colors.black, 0.3)!,
          ],
        ).createShader(bevelRect),
    );

    canvas.drawPath(
      outerPath,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Colors.white.withOpacity(0.35),
            Colors.transparent,
            Colors.transparent,
            Colors.black.withOpacity(0.15),
          ],
          stops: const [0.0, 0.3, 0.7, 1.0],
        ).createShader(bevelRect)
        ..style = PaintingStyle.stroke
        ..strokeWidth = frameWidth * 0.4,
    );

    canvas.drawPath(
      _hexagonPath(center, hexRadius + 2),
      Paint()
        ..color = Colors.black.withOpacity(0.2)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5,
    );

    final mainPath = _hexagonPath(center, hexRadius);
    final mainRect =
        Rect.fromCircle(center: center, radius: hexRadius);

    canvas.drawPath(
      mainPath,
      Paint()
        ..shader = RadialGradient(
          colors: theme.boardFillColors,
          stops: theme.boardFillStops,
          center: const Alignment(-0.1, -0.15),
          radius: 1.0,
        ).createShader(mainRect),
    );

    canvas.save();
    canvas.clipPath(mainPath);

    final linePaint = Paint()
      ..color = theme.boardTextureColor
          .withOpacity(theme.boardTextureOpacity)
      ..strokeWidth = 1.0
      ..style = PaintingStyle.stroke;

    for (final hex in boardHexes) {
      final px =
          math.sqrt(3) * hex.q + math.sqrt(3) / 2 * hex.r;
      final py = 1.5 * hex.r;
      final x =
          centerX + (px - centerXOffset) * marbleSize * flip;
      final y =
          centerY + (py - centerYOffset) * marbleSize * flip;

      for (final dir in Hex.directions) {
        final neighbor = hex + dir;
        if (boardHexes.contains(neighbor)) {
          final nx = math.sqrt(3) * neighbor.q +
              math.sqrt(3) / 2 * neighbor.r;
          final ny = 1.5 * neighbor.r;
          final nx2 = centerX +
              (nx - centerXOffset) * marbleSize * flip;
          final ny2 = centerY +
              (ny - centerYOffset) * marbleSize * flip;
          canvas.drawLine(Offset(x, y), Offset(nx2, ny2), linePaint);
        }
      }
    }

    canvas.drawPath(
      mainPath,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Colors.white.withOpacity(0.1),
            Colors.transparent,
            Colors.transparent,
            Colors.black.withOpacity(0.1),
          ],
          stops: const [0.0, 0.2, 0.8, 1.0],
        ).createShader(mainRect),
    );

    canvas.restore();

    canvas.drawPath(
      mainPath,
      Paint()
        ..color = theme.boardInnerBorderColor
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5,
    );
  }

  Path _hexagonPath(Offset center, double radius) {
    final path = Path();
    for (int i = 0; i < 6; i++) {
      final angle =
          (60.0 * i - 90.0 + boardRotationDeg) * math.pi / 180.0;
      final x = center.dx + radius * math.cos(angle);
      final y = center.dy + radius * math.sin(angle);
      if (i == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
    }
    path.close();
    return path;
  }

  @override
  bool shouldRepaint(covariant _HexBoardPainter old) {
    return old.theme.type != theme.type ||
        old.centerX != centerX ||
        old.centerY != centerY ||
        old.hexRadius != hexRadius ||
        old.flip != flip;
  }
}