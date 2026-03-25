import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/hex.dart';
import '../models/player.dart';
import '../providers/settings_provider.dart';
import '../theme/board_themes.dart';
import 'marble_widget.dart';

// ══════════════════════════════════════════════════════
// STANDALONE TUTORIAL SCREEN
// ══════════════════════════════════════════════════════

class TutorialScreen extends StatelessWidget {
  final bool markAsSeen;

  const TutorialScreen({super.key, this.markAsSeen = false});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: TutorialOverlay(
        markAsSeen: markAsSeen,
        onDismiss: () {
          if (context.mounted) {
            Navigator.of(context).pop();
          }
        },
      ),
    );
  }
}

// ══════════════════════════════════════
// TUTORIAL LESSON DEFINITION
// ══════════════════════════════════════

enum _Phase { instruction, waitingAction, success }

class _Lesson {
  final String title;
  final String instruction;
  final String successText;
  final IconData icon;
  final Map<Hex, Player> board;
  final Set<Hex> highlightHexes;
  final Set<Hex> secondaryHighlights;
  final bool Function(_TutorialState state, Hex tapped) onTap;
  final Player playAs;
  final List<Hex> handTargets;

  const _Lesson({
    required this.title,
    required this.instruction,
    required this.successText,
    required this.icon,
    required this.board,
    required this.highlightHexes,
    this.secondaryHighlights = const {},
    required this.onTap,
    this.playAs = Player.white,
    this.handTargets = const [],
  });
}

class _TutorialState {
  Map<Hex, Player> board;
  List<Hex> selection;
  Set<Hex> hintHexes;
  Set<Hex> pushTargets;
  int tapCount;
  bool actionDone;
  int subStep;

  _TutorialState({
    required this.board,
    this.selection = const [],
    this.hintHexes = const {},
    this.pushTargets = const {},
    this.tapCount = 0,
    this.actionDone = false,
    this.subStep = 0,
  });
}

// ══════════════════════════════════════
// TUTORIAL OVERLAY WIDGET
// ══════════════════════════════════════

class TutorialOverlay extends ConsumerStatefulWidget {
  final VoidCallback onDismiss;
  final bool markAsSeen;

  const TutorialOverlay({
    super.key,
    required this.onDismiss,
    this.markAsSeen = true,
  });

  @override
  ConsumerState<TutorialOverlay> createState() => _TutorialOverlayState();
}

class _TutorialOverlayState extends ConsumerState<TutorialOverlay>
    with TickerProviderStateMixin {
  int _currentLesson = 0;
  _Phase _phase = _Phase.instruction;
  late _TutorialState _tutState;
  late List<_Lesson> _lessons;

  late AnimationController _pulseCtrl;
  late AnimationController _fadeCtrl;
  late AnimationController _successCtrl;
  late AnimationController _instructionCtrl;
  late AnimationController _entryCtrl;
  late AnimationController _bubbleCtrl;
  late AnimationController _handCtrl;

  late Animation<double> _pulseAnim;
  late Animation<double> _fadeAnim;
  late Animation<double> _successAnim;
  late Animation<double> _entryAnim;
  late Animation<double> _bubbleAnim;
  late Animation<double> _handAnim;

  final GlobalKey _boardKey = GlobalKey();
  final GlobalKey _stackKey = GlobalKey();

  double _boardTotalW = 0;
  double _boardTotalH = 0;
  double _boardMarbleSize = 0;
  double _boardCxOff = 0;
  double _boardCyOff = 0;

  @override
  void initState() {
    super.initState();

    _lessons = _buildLessons();
    _tutState = _TutorialState(board: Map.from(_lessons[0].board));

    _pulseCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat(reverse: true);
    _pulseAnim = CurvedAnimation(parent: _pulseCtrl, curve: Curves.easeInOut);

    _fadeCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    )..forward();
    _fadeAnim = CurvedAnimation(parent: _fadeCtrl, curve: Curves.easeOut);

    _successCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    _successAnim = CurvedAnimation(
      parent: _successCtrl,
      curve: Curves.elasticOut,
    );

    _instructionCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    )..forward();

    _entryCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    )..forward();
    _entryAnim = CurvedAnimation(parent: _entryCtrl, curve: Curves.easeOutBack);

    _bubbleCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    )..forward();
    _bubbleAnim = CurvedAnimation(
      parent: _bubbleCtrl,
      curve: Curves.easeOutBack,
    );

    _handCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000),
    )..repeat();
    _handAnim = CurvedAnimation(parent: _handCtrl, curve: Curves.linear);

    Future.delayed(const Duration(milliseconds: 800), () {
      if (mounted) {
        setState(() => _phase = _Phase.waitingAction);
      }
    });
  }

  @override
  void dispose() {
    _pulseCtrl.dispose();
    _fadeCtrl.dispose();
    _successCtrl.dispose();
    _instructionCtrl.dispose();
    _entryCtrl.dispose();
    _bubbleCtrl.dispose();
    _handCtrl.dispose();
    super.dispose();
  }

  // ══════════════════════════════════════
  // BUILD LESSONS — KEEP ALL YOUR EXISTING LESSON CODE
  // ══════════════════════════════════════

  List<_Lesson> _buildLessons() {
    // ── Lesson 1: Select a marble ──
    final board1 = _makeBoard({
      const Hex(0, 2): Player.white,
      const Hex(1, 1): Player.white,
      const Hex(-1, 2): Player.white,
      const Hex(0, -2): Player.black,
      const Hex(1, -2): Player.black,
      const Hex(-1, -1): Player.black,
    });

    // ── Lesson 2: Select a group of 3 ──
    final board2 = _makeBoard({
      const Hex(0, 0): Player.white,
      const Hex(1, -1): Player.white,
      const Hex(-1, 1): Player.white,
      const Hex(0, -3): Player.black,
      const Hex(1, -3): Player.black,
      const Hex(-1, -2): Player.black,
    });

    // ── Lesson 3: Move marbles ──
    final board3 = _makeBoard({
      const Hex(0, 0): Player.white,
      const Hex(1, -1): Player.white,
      const Hex(-1, 1): Player.white,
      const Hex(-2, -1): Player.black,
      const Hex(-3, 0): Player.black,
      const Hex(3, -3): Player.black,
    });

    // ── Lesson 4: Push opponent (2 vs 1) ──
    final board4 = _makeBoard({
      const Hex(-1, 0): Player.white,
      const Hex(0, 0): Player.white,
      const Hex(1, 0): Player.black,
      const Hex(-3, 1): Player.black,
      const Hex(0, -3): Player.black,
      const Hex(-2, -1): Player.white,
    });

    // ── Lesson 5: Push opponent (3 vs 2) ──
    final board5 = _makeBoard({
      const Hex(-2, 0): Player.white,
      const Hex(-1, 0): Player.white,
      const Hex(0, 0): Player.white,
      const Hex(1, 0): Player.black,
      const Hex(2, 0): Player.black,
      const Hex(0, -3): Player.black,
    });

    // ── Lesson 6: Push off the edge ──
    final board6 = _makeBoard({
      const Hex(1, 0): Player.white,
      const Hex(2, 0): Player.white,
      const Hex(3, 0): Player.white,
      const Hex(4, 0): Player.black,
      const Hex(-2, -1): Player.black,
      const Hex(-1, -2): Player.black,
    });

    return [
      _Lesson(
        title: 'Tap Your Marble',
        instruction: 'Tap the glowing marble to select it',
        successText: 'Selected! The golden ring shows it\'s ready.',
        icon: Icons.touch_app_rounded,
        board: board1,
        highlightHexes: {const Hex(0, 2)},
        handTargets: [const Hex(0, 2)],
        onTap: (state, tapped) {
          if (tapped == const Hex(0, 2)) {
            state.selection = [tapped];
            state.actionDone = true;
            return true;
          }
          return false;
        },
      ),
      _Lesson(
        title: 'Select a Group',
        instruction: 'Tap all 3 glowing marbles to form a line',
        successText: 'A group of 3! Groups move together as one.',
        icon: Icons.group_work_rounded,
        board: board2,
        highlightHexes: {const Hex(-1, 1), const Hex(0, 0), const Hex(1, -1)},
        handTargets: [const Hex(-1, 1), const Hex(0, 0), const Hex(1, -1)],
        onTap: (state, tapped) {
          final targets = {const Hex(-1, 1), const Hex(0, 0), const Hex(1, -1)};
          if (targets.contains(tapped)) {
            if (!state.selection.contains(tapped)) {
              final newSel = [...state.selection, tapped];
              if (_isValidLine(newSel)) {
                state.selection = newSel;
                state.tapCount++;
                state.subStep = state.selection.length;
              }
            } else {
              state.selection = state.selection
                  .where((h) => h != tapped)
                  .toList();
              state.subStep = state.selection.length;
            }
            if (state.selection.length >= 3) {
              state.actionDone = true;
              return true;
            }
          }
          return false;
        },
      ),
      _Lesson(
        title: 'Move Your Marbles',
        instruction: 'Select all 3, then tap the green dot to move',
        successText: 'Moved! Your marbles slid into new positions.',
        icon: Icons.open_with_rounded,
        board: board3,
        highlightHexes: {const Hex(-1, 1), const Hex(0, 0), const Hex(1, -1)},
        handTargets: [const Hex(-1, 1), const Hex(0, 0), const Hex(1, -1)],
        onTap: (state, tapped) {
          final targets = {const Hex(-1, 1), const Hex(0, 0), const Hex(1, -1)};

          if (state.subStep == 0) {
            if (targets.contains(tapped) &&
                state.board[tapped] == Player.white) {
              if (!state.selection.contains(tapped)) {
                final newSel = [...state.selection, tapped];
                if (_isValidLine(newSel)) {
                  state.selection = newSel;
                  state.tapCount++;
                }
              } else {
                state.selection = state.selection
                    .where((h) => h != tapped)
                    .toList();
              }

              if (state.selection.length >= 3) {
                state.hintHexes = {
                  const Hex(-2, 2),
                  const Hex(2, -2),
                  const Hex(0, 1),
                  const Hex(-1, 0),
                  const Hex(1, 0),
                  const Hex(0, -1),
                };
                state.hintHexes = state.hintHexes
                    .where(
                      (h) =>
                          state.board.containsKey(h) &&
                          state.board[h] == Player.none,
                    )
                    .toSet();
                state.subStep = 1;
              }
            }
            return false;
          }

          if (state.subStep == 1 && state.hintHexes.contains(tapped)) {
            Hex? moveDir;
            for (final sel in state.selection) {
              final diff = tapped - sel;
              if (Hex.directions.contains(diff)) {
                moveDir = diff;
                break;
              }
            }

            if (moveDir != null) {
              final newBoard = Map<Hex, Player>.from(state.board);
              final sorted = _sortByDir(state.selection, moveDir);

              bool canMove = true;
              for (final h in sorted) {
                final dest = h + moveDir;
                if (!newBoard.containsKey(dest)) {
                  canMove = false;
                  break;
                }
              }

              if (canMove) {
                for (int i = sorted.length - 1; i >= 0; i--) {
                  final from = sorted[i];
                  final to = from + moveDir;
                  newBoard[to] = Player.white;
                  newBoard[from] = Player.none;
                }

                state.board = newBoard;
                state.selection = [];
                state.hintHexes = {};
                state.actionDone = true;
                return true;
              }
            }
          }
          return false;
        },
      ),
      _Lesson(
        title: 'Push with 2',
        instruction: 'Select your 2 marbles, then push the enemy!',
        successText: '2 vs 1 — pushed! Outnumber to push enemies.',
        icon: Icons.arrow_forward_rounded,
        board: board4,
        highlightHexes: {const Hex(-1, 0), const Hex(0, 0)},
        secondaryHighlights: {const Hex(1, 0)},
        handTargets: [const Hex(-1, 0), const Hex(0, 0)],
        onTap: (state, tapped) {
          final whites = {const Hex(-1, 0), const Hex(0, 0)};
          final enemy = const Hex(1, 0);

          if (state.subStep == 0) {
            if (whites.contains(tapped) &&
                state.board[tapped] == Player.white) {
              if (!state.selection.contains(tapped)) {
                final newSel = [...state.selection, tapped];
                if (_isValidLine(newSel)) {
                  state.selection = newSel;
                  state.tapCount++;
                }
              } else {
                state.selection = state.selection
                    .where((h) => h != tapped)
                    .toList();
              }

              if (state.selection.length >= 2) {
                state.pushTargets = {enemy};
                state.subStep = 1;
              }
            }
            return false;
          }

          if (state.subStep == 1 &&
              (tapped == enemy || state.pushTargets.contains(tapped))) {
            final dir = const Hex(1, 0);
            final newBoard = Map<Hex, Player>.from(state.board);

            final enemyDest = enemy + dir;
            if (newBoard.containsKey(enemyDest)) {
              newBoard[enemyDest] = Player.black;
            }

            final sorted = _sortByDir(state.selection, dir);
            for (int i = sorted.length - 1; i >= 0; i--) {
              final from = sorted[i];
              final to = from + dir;
              newBoard[to] = Player.white;
              newBoard[from] = Player.none;
            }

            state.board = newBoard;
            state.selection = [];
            state.hintHexes = {};
            state.pushTargets = {};
            state.actionDone = true;
            return true;
          }
          return false;
        },
      ),
      _Lesson(
        title: 'Push with 3 vs 2',
        instruction: 'Select 3 marbles to push 2 enemies back!',
        successText: '3 vs 2 — pushed! You need more marbles to push.',
        icon: Icons.group_remove_rounded,
        board: board5,
        highlightHexes: {const Hex(-2, 0), const Hex(-1, 0), const Hex(0, 0)},
        secondaryHighlights: {const Hex(1, 0), const Hex(2, 0)},
        handTargets: [const Hex(-2, 0), const Hex(-1, 0), const Hex(0, 0)],
        onTap: (state, tapped) {
          final whites = {const Hex(-2, 0), const Hex(-1, 0), const Hex(0, 0)};
          final enemy1 = const Hex(1, 0);
          final enemy2 = const Hex(2, 0);

          if (state.subStep == 0) {
            if (whites.contains(tapped) &&
                state.board[tapped] == Player.white) {
              if (!state.selection.contains(tapped)) {
                final newSel = [...state.selection, tapped];
                if (_isValidLine(newSel)) {
                  state.selection = newSel;
                  state.tapCount++;
                }
              } else {
                state.selection = state.selection
                    .where((h) => h != tapped)
                    .toList();
              }

              if (state.selection.length >= 3) {
                state.pushTargets = {enemy1, enemy2};
                state.subStep = 1;
              }
            }
            return false;
          }

          if (state.subStep == 1 &&
              (tapped == enemy1 ||
                  tapped == enemy2 ||
                  state.pushTargets.contains(tapped))) {
            final dir = const Hex(1, 0);
            final newBoard = Map<Hex, Player>.from(state.board);

            final enemy2Dest = enemy2 + dir;
            if (newBoard.containsKey(enemy2Dest)) {
              newBoard[enemy2Dest] = Player.black;
            }

            final enemy1Dest = enemy1 + dir;
            if (newBoard.containsKey(enemy1Dest)) {
              newBoard[enemy1Dest] = Player.black;
            }

            final sorted = _sortByDir(state.selection, dir);
            for (int i = sorted.length - 1; i >= 0; i--) {
              final from = sorted[i];
              final to = from + dir;
              newBoard[to] = Player.white;
              newBoard[from] = Player.none;
            }

            state.board = newBoard;
            state.selection = [];
            state.hintHexes = {};
            state.pushTargets = {};
            state.actionDone = true;
            return true;
          }
          return false;
        },
      ),
      _Lesson(
        title: 'Push Off the Edge!',
        instruction: 'Push the enemy marble off the board to score!',
        successText: '🏆 Push 6 off to win! You\'re ready to play!',
        icon: Icons.emoji_events_rounded,
        board: board6,
        highlightHexes: {const Hex(1, 0), const Hex(2, 0), const Hex(3, 0)},
        secondaryHighlights: {const Hex(4, 0)},
        handTargets: [const Hex(1, 0), const Hex(2, 0), const Hex(3, 0)],
        onTap: (state, tapped) {
          final whites = {const Hex(1, 0), const Hex(2, 0), const Hex(3, 0)};
          final enemy = const Hex(4, 0);

          if (state.subStep == 0) {
            if (whites.contains(tapped) &&
                state.board[tapped] == Player.white) {
              if (!state.selection.contains(tapped)) {
                final newSel = [...state.selection, tapped];
                if (_isValidLine(newSel)) {
                  state.selection = newSel;
                  state.tapCount++;
                }
              } else {
                state.selection = state.selection
                    .where((h) => h != tapped)
                    .toList();
              }

              if (state.selection.length >= 3) {
                state.pushTargets = {enemy};
                state.subStep = 1;
              }
            }
            return false;
          }

          if (state.subStep == 1 &&
              (tapped == enemy || state.pushTargets.contains(tapped))) {
            final dir = const Hex(1, 0);
            final newBoard = Map<Hex, Player>.from(state.board);

            newBoard[enemy] = Player.none;

            final sorted = _sortByDir(state.selection, dir);
            for (int i = sorted.length - 1; i >= 0; i--) {
              final from = sorted[i];
              final to = from + dir;
              if (newBoard.containsKey(to)) {
                newBoard[to] = Player.white;
              }
              newBoard[from] = Player.none;
            }

            state.board = newBoard;
            state.selection = [];
            state.hintHexes = {};
            state.pushTargets = {};
            state.actionDone = true;
            return true;
          }
          return false;
        },
      ),
    ];
  }

  bool _isValidLine(List<Hex> hexes) {
    if (hexes.length <= 1) return true;
    if (hexes.length == 2) {
      final diff = hexes[1] - hexes[0];
      return Hex.directions.contains(diff);
    }
    if (hexes.length == 3) {
      final sorted = List<Hex>.from(hexes);
      for (int i = 0; i < sorted.length; i++) {
        for (int j = 0; j < sorted.length; j++) {
          if (i == j) continue;
          final diff = sorted[j] - sorted[i];
          if (!Hex.directions.contains(diff)) continue;
          for (int k = 0; k < sorted.length; k++) {
            if (k == i || k == j) continue;
            final diff2 = sorted[k] - sorted[j];
            if (diff2 == diff) return true;
            final diff3 = sorted[i] - sorted[k];
            if (diff3 == diff) return true;
          }
        }
      }
      return false;
    }
    return false;
  }

  List<Hex> _sortByDir(List<Hex> hexes, Hex dir) {
    final sorted = List<Hex>.from(hexes);
    sorted.sort((a, b) {
      final da = a.q * dir.q + a.r * dir.r;
      final db = b.q * dir.q + b.r * dir.r;
      return da.compareTo(db);
    });
    return sorted;
  }

  Map<Hex, Player> _makeBoard(Map<Hex, Player> placements) {
    final board = <Hex, Player>{};
    for (int q = -4; q <= 4; q++) {
      for (int r = -4; r <= 4; r++) {
        final hex = Hex(q, r);
        if (hex.isOnBoard) {
          board[hex] = placements[hex] ?? Player.none;
        }
      }
    }
    return board;
  }

  // ══════════════════════════════════════
  // ACTIONS
  // ══════════════════════════════════════

  void _onHexTap(Hex hex) {
    if (_phase != _Phase.waitingAction) return;

    final lesson = _lessons[_currentLesson];
    final completed = lesson.onTap(_tutState, hex);

    setState(() {});

    if (completed && _tutState.actionDone) {
      HapticFeedback.mediumImpact();
      _showSuccess();
    } else if (_tutState.selection.isNotEmpty) {
      HapticFeedback.lightImpact();
    }
  }

  void _showSuccess() {
    setState(() => _phase = _Phase.success);
    _successCtrl.forward(from: 0);
    _bubbleCtrl.forward(from: 0);

    final isLast = _currentLesson >= _lessons.length - 1;
    final delay = isLast ? 2500 : 1800;

    Future.delayed(Duration(milliseconds: delay), () {
      if (!mounted) return;
      if (isLast) {
        _finish();
      } else {
        _goToNextLesson();
      }
    });
  }

  void _goToNextLesson() {
    final next = _currentLesson + 1;
    if (next >= _lessons.length) {
      _finish();
      return;
    }

    _fadeCtrl.reverse().then((_) {
      if (!mounted) return;
      setState(() {
        _currentLesson = next;
        _phase = _Phase.instruction;
        _tutState = _TutorialState(board: Map.from(_lessons[next].board));
      });

      _fadeCtrl.forward();
      _instructionCtrl.forward(from: 0);
      _bubbleCtrl.forward(from: 0);
      _handCtrl.forward(from: 0);

      Future.delayed(const Duration(milliseconds: 700), () {
        if (mounted) {
          setState(() => _phase = _Phase.waitingAction);
        }
      });
    });
  }

  void _finish() {
    HapticFeedback.heavyImpact();
    if (widget.markAsSeen) {
      ref.read(settingsProvider.notifier).markTutorialSeen();
    }
    widget.onDismiss();
  }

  void _skip() {
    if (widget.markAsSeen) {
      ref.read(settingsProvider.notifier).markTutorialSeen();
    }
    widget.onDismiss();
  }

  // ══════════════════════════════════════
  // HEX POSITION HELPERS
  // ══════════════════════════════════════

  Offset _hexPositionInBoard(Hex hex) {
    final px = math.sqrt(3) * hex.q + math.sqrt(3) / 2 * hex.r;
    final py = 1.5 * hex.r;
    final x = _boardTotalW / 2 + (px - _boardCxOff) * _boardMarbleSize;
    final y = _boardTotalH / 2 + (py - _boardCyOff) * _boardMarbleSize;
    return Offset(x, y);
  }

  Offset? _boardToStack(Offset boardLocal) {
    final boardBox = _boardKey.currentContext?.findRenderObject() as RenderBox?;
    final stackBox = _stackKey.currentContext?.findRenderObject() as RenderBox?;
    if (boardBox == null || stackBox == null) return null;

    final globalPos = boardBox.localToGlobal(boardLocal);
    return stackBox.globalToLocal(globalPos);
  }

  Hex? _getCurrentHandTarget() {
    final lesson = _lessons[_currentLesson];
    if (_phase != _Phase.waitingAction) return null;
    if (lesson.handTargets.isEmpty) return null;

    if (_tutState.hintHexes.isNotEmpty) {
      return _tutState.hintHexes.first;
    }

    if (_tutState.pushTargets.isNotEmpty) {
      return _tutState.pushTargets.first;
    }

    for (final target in lesson.handTargets) {
      if (!_tutState.selection.contains(target)) {
        return target;
      }
    }

    return null;
  }

  // ══════════════════════════════════════
  // BUILD
  // ══════════════════════════════════════

  @override
  Widget build(BuildContext context) {
    final theme = ref.watch(boardThemeProvider);
    final screen = MediaQuery.of(context).size;
    final compact = screen.height < 700;
    final lesson = _lessons[_currentLesson];
    final isLast = _currentLesson >= _lessons.length - 1;
    final progress = (_currentLesson + 1) / _lessons.length;

    return Material(
      color: Colors.transparent,
      child: AnimatedBuilder(
        animation: _entryAnim,
        builder: (context, child) {
          return Opacity(
            opacity: _entryAnim.value.clamp(0.0, 1.0),
            child: Transform.scale(
              scale: 0.95 + 0.05 * _entryAnim.value,
              child: child,
            ),
          );
        },
        child: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [Color(0xFF0D1117), Color(0xFF161B22), Color(0xFF0D1117)],
            ),
          ),
          child: SafeArea(
            child: Stack(
              key: _stackKey,
              children: [
                Column(
                  children: [
                    _buildTopBar(theme, compact, progress),
                    SizedBox(height: compact ? 4 : 8),
                    _buildInstructionBubble(theme, lesson, compact),
                    SizedBox(height: compact ? 6 : 12),
                    Expanded(
                      child: _buildInteractiveBoard(theme, lesson, compact),
                    ),
                    SizedBox(height: compact ? 4 : 8),
                    _buildBottomInfo(theme, lesson, compact, isLast),
                    SizedBox(height: compact ? 8 : 14),
                  ],
                ),
                if (_phase == _Phase.waitingAction) _buildFingerCursor(),
                if (_phase == _Phase.success)
                  _buildSuccessOverlay(theme, lesson, isLast),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ══════════════════════════════════════
  // ALL REMAINING BUILD METHODS — UNCHANGED
  // Keep your existing implementations of:
  // - _buildFingerCursor()
  // - _buildTopBar()
  // - _buildInstructionBubble()
  // - _getDynamicInstruction()
  // - _buildInteractiveBoard()
  // - _buildPulseRing()
  // - _buildBottomInfo()
  // - _getHelpText()
  // - _buildSuccessOverlay()
  // ══════════════════════════════════════

  Widget _buildFingerCursor() {
    final target = _getCurrentHandTarget();
    if (target == null) return const SizedBox.shrink();

    return AnimatedBuilder(
      animation: Listenable.merge([_handAnim, _pulseAnim]),
      builder: (context, _) {
        final boardLocal = _hexPositionInBoard(target);
        final stackPos = _boardToStack(boardLocal);

        if (stackPos == null) return const SizedBox.shrink();

        final t = _handAnim.value;

        double fingerOffsetY;
        double fingerScale;
        double rippleOpacity = 0.0;
        double rippleSize = 0.0;

        if (t < 0.3) {
          final p = t / 0.3;
          fingerOffsetY = 20.0 - 20.0 * Curves.easeOut.transform(p);
          fingerScale = 1.0;
        } else if (t < 0.5) {
          final p = (t - 0.3) / 0.2;
          fingerOffsetY = 0.0;
          fingerScale = 1.0 - 0.1 * math.sin(p * math.pi);
          rippleOpacity = p * 0.6;
          rippleSize = p * 30;
        } else if (t < 0.7) {
          final p = (t - 0.5) / 0.2;
          fingerOffsetY = 20.0 * Curves.easeIn.transform(p);
          fingerScale = 1.0;
          rippleOpacity = 0.6 * (1.0 - p);
          rippleSize = 30 + p * 20;
        } else {
          fingerOffsetY = 20.0;
          fingerScale = 1.0;
        }

        final fingerX = stackPos.dx + _boardMarbleSize * 0.05;
        final fingerY = stackPos.dy + _boardMarbleSize * 0.25 + fingerOffsetY;

        return Stack(
          children: [
            if (rippleOpacity > 0)
              Positioned(
                left: stackPos.dx - rippleSize / 2,
                top: stackPos.dy - rippleSize / 2,
                child: IgnorePointer(
                  child: Container(
                    width: rippleSize,
                    height: rippleSize,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: Colors.white.withOpacity(rippleOpacity * 0.5),
                        width: 2,
                      ),
                    ),
                  ),
                ),
              ),
            Positioned(
              left: fingerX - 16,
              top: fingerY - 8,
              child: IgnorePointer(
                child: Transform.scale(
                  scale: fingerScale,
                  alignment: Alignment.topCenter,
                  child: Transform.rotate(
                    angle: -0.15,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          decoration: BoxDecoration(
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.5),
                                blurRadius: 8,
                                offset: const Offset(2, 4),
                              ),
                            ],
                          ),
                          child: const Text(
                            '👆',
                            style: TextStyle(fontSize: 28, height: 1),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildTopBar(BoardTheme theme, bool compact, double progress) {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 16, vertical: compact ? 4 : 8),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.06),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.school_rounded,
                      color: Colors.amber.withOpacity(0.8),
                      size: 16,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      '${_currentLesson + 1} / ${_lessons.length}',
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.7),
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
              const Spacer(),
              GestureDetector(
                onTap: _skip,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.06),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: Colors.white.withOpacity(0.08)),
                  ),
                  child: Text(
                    'Skip',
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.4),
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          ClipRRect(
            borderRadius: BorderRadius.circular(3),
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 3,
              backgroundColor: Colors.white.withOpacity(0.06),
              valueColor: AlwaysStoppedAnimation<Color>(
                Color.lerp(Colors.amber, Colors.green, progress)!,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInstructionBubble(
    BoardTheme theme,
    _Lesson lesson,
    bool compact,
  ) {
    return FadeTransition(
      opacity: _fadeAnim,
      child: AnimatedBuilder(
        animation: _bubbleAnim,
        builder: (context, child) {
          return Transform.scale(
            scale: 0.9 + 0.1 * _bubbleAnim.value,
            child: Transform.translate(
              offset: Offset(0, 10 * (1 - _bubbleAnim.value)),
              child: child,
            ),
          );
        },
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Container(
            width: double.infinity,
            padding: EdgeInsets.all(compact ? 14 : 18),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(20),
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Colors.white.withOpacity(0.08),
                  Colors.white.withOpacity(0.04),
                ],
              ),
              border: Border.all(
                color: Colors.amber.withOpacity(0.2),
                width: 1,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.amber.withOpacity(0.05),
                  blurRadius: 20,
                  spreadRadius: 2,
                ),
              ],
            ),
            child: Row(
              children: [
                AnimatedBuilder(
                  animation: _pulseAnim,
                  builder: (context, child) {
                    return Transform.scale(
                      scale: 1.0 + _pulseAnim.value * 0.08,
                      child: child,
                    );
                  },
                  child: Container(
                    width: compact ? 40 : 48,
                    height: compact ? 40 : 48,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: const LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [Color(0xFFFFD700), Color(0xFFF39C12)],
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.amber.withOpacity(0.3),
                          blurRadius: 12,
                        ),
                      ],
                    ),
                    child: Icon(
                      lesson.icon,
                      color: Colors.white,
                      size: compact ? 20 : 24,
                    ),
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        lesson.title,
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: compact ? 16 : 18,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        _phase == _Phase.waitingAction
                            ? _getDynamicInstruction(lesson)
                            : _phase == _Phase.instruction
                            ? 'Get ready...'
                            : lesson.successText,
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.55),
                          fontSize: compact ? 12 : 13,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  String _getDynamicInstruction(_Lesson lesson) {
    switch (_currentLesson) {
      case 2:
        if (_tutState.selection.length >= 3 && _tutState.hintHexes.isNotEmpty) {
          return 'Now tap a green dot to move them!';
        }
        if (_tutState.selection.isNotEmpty) {
          return 'Select ${3 - _tutState.selection.length} more marble${3 - _tutState.selection.length > 1 ? 's' : ''}';
        }
        return lesson.instruction;
      case 3:
        if (_tutState.selection.length >= 2 &&
            _tutState.pushTargets.isNotEmpty) {
          return 'Tap the enemy marble to push it!';
        }
        if (_tutState.selection.isNotEmpty) {
          return 'Select ${2 - _tutState.selection.length} more marble${2 - _tutState.selection.length > 1 ? 's' : ''}';
        }
        return lesson.instruction;
      case 4:
        if (_tutState.selection.length >= 3 &&
            _tutState.pushTargets.isNotEmpty) {
          return 'Tap an enemy marble to push both back!';
        }
        if (_tutState.selection.isNotEmpty) {
          return 'Select ${3 - _tutState.selection.length} more marble${3 - _tutState.selection.length > 1 ? 's' : ''}';
        }
        return lesson.instruction;
      case 5:
        if (_tutState.selection.length >= 3 &&
            _tutState.pushTargets.isNotEmpty) {
          return 'Push the enemy off the board edge!';
        }
        if (_tutState.selection.isNotEmpty) {
          return 'Select ${3 - _tutState.selection.length} more marble${3 - _tutState.selection.length > 1 ? 's' : ''}';
        }
        return lesson.instruction;
      default:
        return lesson.instruction;
    }
  }

  Widget _buildInteractiveBoard(
    BoardTheme theme,
    _Lesson lesson,
    bool compact,
  ) {
    return FadeTransition(
      opacity: _fadeAnim,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final maxW = constraints.maxWidth - 16;
          final maxH = constraints.maxHeight - 8;
          final board = _tutState.board;

          double minX = double.infinity, maxX = double.negativeInfinity;
          double minY = double.infinity, maxY = double.negativeInfinity;

          for (final hex in board.keys) {
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

          // ═══════════════════════════════════════
          // FIX: Scale up marbles like real game
          // ═══════════════════════════════════════
          const mScale = 1.18;
          final visualSize = baseSize * mScale;
          final tapSize = visualSize * 1.3; // Generous tap target

          final totalW = gridW * baseSize;
          final totalH = gridH * baseSize;

          final cxOff = (minX + maxX) / 2.0;
          final cyOff = (minY + maxY) / 2.0;

          final hexRadius = baseSize * 8.0;

          // Cache for finger cursor positioning
          _boardTotalW = totalW;
          _boardTotalH = totalH;
          _boardMarbleSize = baseSize;
          _boardCxOff = cxOff;
          _boardCyOff = cyOff;

          return Center(
            child: SizedBox(
              key: _boardKey,
              width: totalW,
              height: totalH,
              child: CustomPaint(
                painter: _TutBoardPainter(
                  centerX: totalW / 2,
                  centerY: totalH / 2,
                  hexRadius: hexRadius,
                  marbleSize: baseSize,
                  theme: theme,
                  boardHexes: board.keys.toList(),
                  centerXOffset: cxOff,
                  centerYOffset: cyOff,
                ),
                child: AnimatedBuilder(
                  animation: _pulseAnim,
                  builder: (context, _) {
                    return Stack(
                      clipBehavior: Clip.none,
                      children: board.keys.map((hex) {
                        final px =
                            math.sqrt(3) * hex.q + math.sqrt(3) / 2 * hex.r;
                        final py = 1.5 * hex.r;

                        // Center position in pixels
                        final centerX = totalW / 2 + (px - cxOff) * baseSize;
                        final centerY = totalH / 2 + (py - cyOff) * baseSize;

                        // Tap area positioned from center
                        final tapLeft = centerX - tapSize / 2;
                        final tapTop = centerY - tapSize / 2;

                        final isHighlight = lesson.highlightHexes.contains(hex);
                        final isSecondary = lesson.secondaryHighlights.contains(
                          hex,
                        );
                        final isSelected = _tutState.selection.contains(hex);
                        final isHint = _tutState.hintHexes.contains(hex);
                        final isPush = _tutState.pushTargets.contains(hex);
                        final player = board[hex]!;
                        final shouldPulse =
                            _phase == _Phase.waitingAction &&
                            !_tutState.actionDone;

                        return Positioned(
                          left: tapLeft,
                          top: tapTop,
                          child: GestureDetector(
                            // ═══════════════════════════════
                            // FIX: Opaque hit test = no misses
                            // ═══════════════════════════════
                            behavior: HitTestBehavior.opaque,
                            onTap: () => _onHexTap(hex),
                            child: SizedBox(
                              width: tapSize,
                              height: tapSize,
                              child: Center(
                                // ═══════════════════════════
                                // FIX: Visual marble is bigger
                                // ═══════════════════════════
                                child: SizedBox(
                                  width: visualSize,
                                  height: visualSize,
                                  child: Stack(
                                    alignment: Alignment.center,
                                    children: [
                                      // Pulse ring on highlight targets
                                      if (shouldPulse &&
                                          isHighlight &&
                                          !isSelected &&
                                          player != Player.none)
                                        _buildPulseRing(
                                          visualSize,
                                          Colors.amber,
                                        ),

                                      // Secondary highlight (enemies)
                                      if (shouldPulse &&
                                          isSecondary &&
                                          !isSelected &&
                                          player != Player.none)
                                        _buildPulseRing(
                                          visualSize,
                                          Colors.red.withOpacity(0.6),
                                        ),

                                      // Push target pulse
                                      if (isPush && player != Player.none)
                                        _buildPulseRing(
                                          visualSize,
                                          Colors.redAccent,
                                        ),

                                      // The marble itself
                                      MarbleWidget(
                                        player: player,
                                        size: visualSize,
                                        isSelected: isSelected,
                                        isHint: isHint,
                                        isPushTarget: isPush,
                                        theme: theme,
                                        animationSpeed: 1.0,
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ),
                        );
                      }).toList(),
                    );
                  },
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildPulseRing(double size, Color color) {
    return AnimatedBuilder(
      animation: _pulseAnim,
      builder: (context, _) {
        final scale = 0.85 + _pulseAnim.value * 0.25;
        final opacity = 0.3 + _pulseAnim.value * 0.4;
        return Transform.scale(
          scale: scale,
          child: Container(
            width: size * 0.85,
            height: size * 0.85,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: color.withOpacity(opacity), width: 3.0),
              boxShadow: [
                BoxShadow(
                  color: color.withOpacity(opacity * 0.5),
                  blurRadius: 16,
                  spreadRadius: 4,
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildBottomInfo(
    BoardTheme theme,
    _Lesson lesson,
    bool compact,
    bool isLast,
  ) {
    final selCount = _tutState.selection.length;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: FadeTransition(
        opacity: _fadeAnim,
        child: Container(
          width: double.infinity,
          padding: EdgeInsets.symmetric(
            horizontal: 16,
            vertical: compact ? 10 : 14,
          ),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            color: Colors.white.withOpacity(0.04),
            border: Border.all(color: Colors.white.withOpacity(0.06)),
          ),
          child: Row(
            children: [
              if (selCount > 0) ...[
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(10),
                    color: Colors.amber.withOpacity(0.15),
                    border: Border.all(color: Colors.amber.withOpacity(0.3)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.check_circle,
                        color: Colors.amber,
                        size: 14,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        '$selCount selected',
                        style: const TextStyle(
                          color: Colors.amber,
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
              ] else ...[
                Icon(
                  Icons.info_outline_rounded,
                  color: Colors.white.withOpacity(0.3),
                  size: 16,
                ),
                const SizedBox(width: 8),
                Text(
                  _getHelpText(),
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.35),
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
              const Spacer(),
              if (_tutState.hintHexes.isNotEmpty)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(10),
                    color: Colors.green.withOpacity(0.15),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 8,
                        height: 8,
                        decoration: const BoxDecoration(
                          shape: BoxShape.circle,
                          color: Colors.greenAccent,
                        ),
                      ),
                      const SizedBox(width: 4),
                      Text(
                        'Tap green',
                        style: TextStyle(
                          color: Colors.greenAccent.withOpacity(0.8),
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              if (_tutState.pushTargets.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(left: 6),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(10),
                      color: Colors.red.withOpacity(0.15),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.arrow_forward,
                          color: Colors.redAccent,
                          size: 12,
                        ),
                        const SizedBox(width: 3),
                        Text(
                          'Push!',
                          style: TextStyle(
                            color: Colors.redAccent.withOpacity(0.8),
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  String _getHelpText() {
    switch (_currentLesson) {
      case 0:
        return 'Tap the glowing marble';
      case 1:
        return 'Tap all 3 glowing marbles';
      case 2:
        return _tutState.selection.length >= 3
            ? 'Now tap a green dot'
            : 'Select the glowing marbles';
      case 3:
        return _tutState.selection.length >= 2
            ? 'Tap the enemy to push'
            : 'Select your 2 marbles';
      case 4:
        return _tutState.selection.length >= 3
            ? 'Tap enemy to push both'
            : 'Select all 3 marbles';
      case 5:
        return _tutState.selection.length >= 3
            ? 'Push off the edge!'
            : 'Select all 3 marbles';
      default:
        return 'Follow the finger';
    }
  }

  Widget _buildSuccessOverlay(BoardTheme theme, _Lesson lesson, bool isLast) {
    return AnimatedBuilder(
      animation: _successAnim,
      builder: (context, _) {
        final opacity = _successAnim.value.clamp(0.0, 1.0);
        final scale = 0.5 + _successAnim.value * 0.5;

        return Positioned.fill(
          child: Container(
            color: Colors.black.withOpacity(opacity * 0.4),
            child: Center(
              child: Transform.scale(
                scale: scale,
                child: GestureDetector(
                  onTap: isLast ? _finish : null,
                  child: Container(
                    margin: const EdgeInsets.symmetric(horizontal: 40),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 28,
                      vertical: 24,
                    ),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(24),
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: isLast
                            ? [const Color(0xFF1A472A), const Color(0xFF0D2818)]
                            : [
                                const Color(0xFF2D2006),
                                const Color(0xFF1A1304),
                              ],
                      ),
                      border: Border.all(
                        color: isLast
                            ? Colors.green.withOpacity(0.4)
                            : Colors.amber.withOpacity(0.3),
                        width: 1.5,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: (isLast ? Colors.green : Colors.amber)
                              .withOpacity(0.2),
                          blurRadius: 30,
                          spreadRadius: 5,
                        ),
                      ],
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 56,
                          height: 56,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            gradient: LinearGradient(
                              colors: isLast
                                  ? [Colors.green, Colors.green.shade700]
                                  : [Colors.amber, Colors.orange],
                            ),
                          ),
                          child: Icon(
                            isLast
                                ? Icons.emoji_events_rounded
                                : Icons.check_rounded,
                            color: Colors.white,
                            size: 30,
                          ),
                        ),
                        const SizedBox(height: 14),
                        Text(
                          isLast ? 'You\'re Ready!' : 'Nice!',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 22,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          lesson.successText,
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: Colors.white.withOpacity(0.6),
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                            height: 1.4,
                          ),
                        ),
                        if (isLast) ...[
                          const SizedBox(height: 16),
                          GestureDetector(
                            onTap: _finish,
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 28,
                                vertical: 12,
                              ),
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(14),
                                gradient: const LinearGradient(
                                  colors: [
                                    Color(0xFF2ED573),
                                    Color(0xFF05C46B),
                                  ],
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.green.withOpacity(0.3),
                                    blurRadius: 12,
                                    offset: const Offset(0, 4),
                                  ),
                                ],
                              ),
                              child: const Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    'Start Playing',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 15,
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                                  SizedBox(width: 6),
                                  Icon(
                                    Icons.play_arrow_rounded,
                                    color: Colors.white,
                                    size: 20,
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

// ══════════════════════════════════════════════════════
// BOARD PAINTER — UNCHANGED
// ══════════════════════════════════════════════════════

class _TutBoardPainter extends CustomPainter {
  final double centerX, centerY, hexRadius, marbleSize;
  final BoardTheme theme;
  final List<Hex> boardHexes;
  final double centerXOffset, centerYOffset;

  _TutBoardPainter({
    required this.centerX,
    required this.centerY,
    required this.hexRadius,
    required this.marbleSize,
    required this.theme,
    required this.boardHexes,
    required this.centerXOffset,
    required this.centerYOffset,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(centerX, centerY);
    final frameWidth = marbleSize * 0.5;

    canvas.drawPath(
      _hexPath(center, hexRadius + frameWidth + 6),
      Paint()
        ..color = Colors.black.withOpacity(0.15)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 16),
    );

    final outerPath = _hexPath(center, hexRadius + frameWidth);
    final bevelRect = Rect.fromCircle(
      center: center,
      radius: hexRadius + frameWidth,
    );

    canvas.drawPath(outerPath, Paint()..color = theme.boardRimShadow);
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
      _hexPath(center, hexRadius + 2),
      Paint()
        ..color = Colors.black.withOpacity(0.2)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5,
    );

    final mainPath = _hexPath(center, hexRadius);
    final mainRect = Rect.fromCircle(center: center, radius: hexRadius);

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
      ..color = theme.boardTextureColor.withOpacity(theme.boardTextureOpacity)
      ..strokeWidth = 1.0
      ..style = PaintingStyle.stroke;

    for (final hex in boardHexes) {
      final px = math.sqrt(3) * hex.q + math.sqrt(3) / 2 * hex.r;
      final py = 1.5 * hex.r;
      final x = centerX + (px - centerXOffset) * marbleSize;
      final y = centerY + (py - centerYOffset) * marbleSize;

      for (final dir in Hex.directions) {
        final neighbor = hex + dir;
        if (boardHexes.contains(neighbor)) {
          final nx = math.sqrt(3) * neighbor.q + math.sqrt(3) / 2 * neighbor.r;
          final ny = 1.5 * neighbor.r;
          canvas.drawLine(
            Offset(x, y),
            Offset(
              centerX + (nx - centerXOffset) * marbleSize,
              centerY + (ny - centerYOffset) * marbleSize,
            ),
            linePaint,
          );
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

  Path _hexPath(Offset center, double radius) {
    final path = Path();
    for (int i = 0; i < 6; i++) {
      final angle = (60.0 * i - 90.0 + 30.0) * math.pi / 180.0;
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
  bool shouldRepaint(covariant _TutBoardPainter old) {
    return old.theme.type != theme.type;
  }
}
