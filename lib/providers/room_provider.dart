import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/player.dart';
import '../services/room_service.dart';
import '../providers/user_provider.dart';
import '../providers/game_provider.dart';
import '../logic/game_logic.dart';

final roomProvider = NotifierProvider<RoomNotifier, RoomState>(
  RoomNotifier.new,
);

class RoomState {
  final String? roomId;
  final RoomData? roomData;
  final Player? myColor;
  final bool isHost;
  final bool isLoading;
  final String? error;
  final bool opponentDisconnected;
  final int disconnectSecondsLeft;
  final String? closedReason;

  const RoomState({
    this.roomId,
    this.roomData,
    this.myColor,
    this.isHost = false,
    this.isLoading = false,
    this.error,
    this.opponentDisconnected = false,
    this.disconnectSecondsLeft = 60,
    this.closedReason,
  });

  bool get inRoom => roomId != null;
  bool get isWaiting => roomData?.status == 'waiting';
  bool get isPlaying => roomData?.status == 'playing';
  bool get isAbandoned => roomData?.status == 'abandoned';
  bool get isFinished => roomData?.status == 'finished';
  bool get isClosed => isAbandoned || isFinished;

  RoomState copyWith({
    String? roomId,
    RoomData? roomData,
    Player? myColor,
    bool? isHost,
    bool? isLoading,
    String? error,
    bool? opponentDisconnected,
    int? disconnectSecondsLeft,
    String? closedReason,
  }) {
    return RoomState(
      roomId: roomId ?? this.roomId,
      roomData: roomData ?? this.roomData,
      myColor: myColor ?? this.myColor,
      isHost: isHost ?? this.isHost,
      isLoading: isLoading ?? this.isLoading,
      error: error,
      opponentDisconnected: opponentDisconnected ?? this.opponentDisconnected,
      disconnectSecondsLeft:
          disconnectSecondsLeft ?? this.disconnectSecondsLeft,
      closedReason: closedReason ?? this.closedReason,
    );
  }
}

class RoomNotifier extends Notifier<RoomState> {
  StreamSubscription<RoomData?>? _roomSub;
  Timer? _heartbeatTimer;
  Timer? _disconnectCountdown;
  Timer? _offlineCheckTimer;
  bool _disposed = false;
  bool _gameStartedForHost = false;
  bool _isLeaving = false;
  String? _myUserId;
  DateTime? _gameStartedAt;
  int _consecutiveOfflineChecks = 0;

  // ── Track last known move count to detect fresh moves ──
  int _lastKnownMoveCount = 0;

  // ── Cooldown: don't re-mark disconnect right after it was cleared ──
  DateTime? _lastDisconnectClearedAt;

  static const int _heartbeatInterval = 8;
  static const int _offlineCheckInterval = 10;
  static const int _consecutiveChecksRequired = 3;
  static const int _graceAfterGameStart = 20;

  // ── How long to wait after disconnect cleared before re-checking ──
  static const int _disconnectClearCooldown = 15;

  @override
  RoomState build() {
    _disposed = false;
    _gameStartedForHost = false;
    _isLeaving = false;
    _myUserId = null;
    _gameStartedAt = null;
    _consecutiveOfflineChecks = 0;
    _lastKnownMoveCount = 0;
    _lastDisconnectClearedAt = null;
    ref.onDispose(() {
      _disposed = true;
      _fullCleanup();
    });
    return const RoomState();
  }

  void _safeUpdate(RoomState newState) {
    if (!_disposed && !_isLeaving) state = newState;
  }

  void _fullCleanup() {
    _roomSub?.cancel();
    _roomSub = null;
    _heartbeatTimer?.cancel();
    _heartbeatTimer = null;
    _disconnectCountdown?.cancel();
    _disconnectCountdown = null;
    _offlineCheckTimer?.cancel();
    _offlineCheckTimer = null;
  }

  void _wireOnlineCallback() {
    ref.read(gameProvider.notifier).onMoveMade = () async {
      await sendMove();
    };
  }

  void _unwireOnlineCallback() {
    try {
      ref.read(gameProvider.notifier).onMoveMade = null;
    } catch (_) {}
  }

  // ══════════════════════════════════════
  // HEARTBEAT - Fixed: more reliable
  // ══════════════════════════════════════

  void _startHeartbeat(String roomId) {
    _heartbeatTimer?.cancel();
    _sendHeartbeat(roomId);
    _heartbeatTimer = Timer.periodic(
      const Duration(seconds: _heartbeatInterval),
      (_) => _sendHeartbeat(roomId),
    );
  }

  void _sendHeartbeat(String roomId) {
    if (_disposed || _myUserId == null || _isLeaving) return;
    RoomService.sendHeartbeat(roomId, _myUserId!);
  }

  void _stopHeartbeat() {
    _heartbeatTimer?.cancel();
    _heartbeatTimer = null;
  }

  // ══════════════════════════════════════
  // OFFLINE CHECK - Fixed: cooldown + move-aware
  // ══════════════════════════════════════

  void _startOfflineCheck() {
    _offlineCheckTimer?.cancel();
    _consecutiveOfflineChecks = 0;

    Future.delayed(Duration(seconds: _graceAfterGameStart), () {
      if (_disposed || _isLeaving) return;
      _offlineCheckTimer = Timer.periodic(
        const Duration(seconds: _offlineCheckInterval),
        (_) => _checkOpponentOnline(),
      );
    });
  }

  void _stopOfflineCheck() {
    _offlineCheckTimer?.cancel();
    _offlineCheckTimer = null;
    _consecutiveOfflineChecks = 0;
  }

  void _checkOpponentOnline() {
    if (_disposed || _isLeaving) return;

    final roomData = state.roomData;
    if (roomData == null || !roomData.isPlaying) return;
    if (_myUserId == null) return;

    // Don't check during grace period after game start
    if (_gameStartedAt != null) {
      final elapsed = DateTime.now().difference(_gameStartedAt!).inSeconds;
      if (elapsed < _graceAfterGameStart) return;
    }

    // FIX: Don't re-check if disconnect was recently cleared (cooldown)
    if (_lastDisconnectClearedAt != null) {
      final sinceClear =
          DateTime.now().difference(_lastDisconnectClearedAt!).inSeconds;
      if (sinceClear < _disconnectClearCooldown) {
        _consecutiveOfflineChecks = 0;
        return;
      }
    }

    final opponentId = _myUserId == roomData.hostId
        ? roomData.guestId
        : roomData.hostId;
    if (opponentId == null) return;

    // FIX: If there's already a disconnect flag, don't add another
    if (roomData.hasDisconnect) {
      _consecutiveOfflineChecks = 0;
      return;
    }

    // FIX: Check if opponent made a recent move (board updated recently)
    if (roomData.lastMoveAt != null) {
      final sinceMoveSeconds =
          DateTime.now().difference(roomData.lastMoveAt!).inSeconds;
      if (sinceMoveSeconds < 30) {
        // Opponent was active recently via moves, reset counter
        _consecutiveOfflineChecks = 0;
        return;
      }
    }

    final isOffline = roomData.isPlayerOffline(opponentId);

    if (isOffline) {
      _consecutiveOfflineChecks++;
      debugPrint(
        '[Room] Opponent offline check: $_consecutiveOfflineChecks/$_consecutiveChecksRequired',
      );
      if (_consecutiveOfflineChecks >= _consecutiveChecksRequired) {
        RoomService.markDisconnected(state.roomId!, opponentId);
        _consecutiveOfflineChecks = 0;
      }
    } else {
      _consecutiveOfflineChecks = 0;
    }
  }

  // ══════════════════════════════════════
  // DISCONNECT COUNTDOWN - Fixed
  // ══════════════════════════════════════

  void _startDisconnectCountdown(int startSeconds) {
    _disconnectCountdown?.cancel();

    final clampedSeconds = startSeconds.clamp(1, 60);

    _safeUpdate(
      state.copyWith(
        opponentDisconnected: true,
        disconnectSecondsLeft: clampedSeconds,
      ),
    );

    _disconnectCountdown = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_disposed || _isLeaving) {
        timer.cancel();
        return;
      }

      // FIX: Re-check if disconnect was cleared in Firestore while counting
      final roomData = state.roomData;
      if (roomData != null && !roomData.hasDisconnect) {
        timer.cancel();
        _stopDisconnectCountdown();
        return;
      }

      final left = state.disconnectSecondsLeft - 1;
      if (left <= 0) {
        timer.cancel();
        _onDisconnectExpired();
      } else {
        _safeUpdate(state.copyWith(disconnectSecondsLeft: left));
      }
    });
  }

  void _stopDisconnectCountdown() {
    _disconnectCountdown?.cancel();
    _disconnectCountdown = null;

    if (state.opponentDisconnected) {
      _lastDisconnectClearedAt = DateTime.now();
      _consecutiveOfflineChecks = 0;

      _safeUpdate(
        state.copyWith(opponentDisconnected: false, disconnectSecondsLeft: 60),
      );

      debugPrint('[Room] Disconnect countdown stopped - opponent reconnected');
    }
  }

  void _onDisconnectExpired() {
    final roomId = state.roomId;
    if (roomId != null && !_isLeaving) {
      RoomService.closeGame(roomId, 'disconnect_timeout');
    }
  }

  // ══════════════════════════════════════
  // HANDLE DISCONNECT STATE - Major Fix
  // ══════════════════════════════════════

  void _handleDisconnectState(RoomData roomData) {
    if (_myUserId == null || _isLeaving) return;

    if (roomData.hasDisconnect) {
      // Case 1: I'm the one marked as disconnected → clear it immediately
      if (roomData.disconnectedBy == _myUserId) {
        debugPrint('[Room] I was marked disconnected - clearing');
        RoomService.clearDisconnect(roomData.roomId, _myUserId!);
        // Also stop any countdown that might be showing
        _stopDisconnectCountdown();
        return;
      }

      // Case 2: Opponent is marked as disconnected
      if (!state.opponentDisconnected) {
        // Start countdown only if not already running
        final secondsLeft = roomData.disconnectSecondsLeft;
        if (secondsLeft > 0) {
          debugPrint(
            '[Room] Opponent disconnected - starting countdown: ${secondsLeft}s',
          );
          _startDisconnectCountdown(secondsLeft);
        } else {
          _onDisconnectExpired();
        }
      }
      // If countdown already running, let it continue (don't restart)
    } else {
      // FIX: No disconnect flag in Firestore → ALWAYS clear local countdown
      if (state.opponentDisconnected) {
        debugPrint('[Room] Disconnect cleared in Firestore - stopping banner');
        _stopDisconnectCountdown();
      }
    }
  }

  void _handleGameClosed(String? reason) {
    if (_isLeaving) return;

    _stopDisconnectCountdown();
    _stopHeartbeat();
    _stopOfflineCheck();
    _roomSub?.cancel();
    _roomSub = null;
    _unwireOnlineCallback();

    String errorMessage;
    switch (reason) {
      case 'disconnect_timeout':
        errorMessage = 'Opponent disconnected — game ended';
        break;
      case 'player_left':
        errorMessage = 'Opponent left the game';
        break;
      case 'host_created_new_room':
      case 'guest_created_new_room':
        errorMessage = 'Room was closed';
        break;
      default:
        errorMessage = 'Game ended';
    }

    _safeUpdate(RoomState(error: errorMessage, closedReason: reason));
  }

  // ══════════════════════════════════════
  // CREATE / JOIN ROOM
  // ══════════════════════════════════════

  Future<String?> createRoom({Player hostColor = Player.black}) async {
    final user = ref.read(currentUserProvider);
    if (user == null) {
      _safeUpdate(state.copyWith(error: 'Profile not loaded'));
      return null;
    }

    _safeUpdate(state.copyWith(isLoading: true, error: null));

    try {
      final initialBoard = GameLogic.initialState().board;
      final roomId = await RoomService.createRoom(
        host: user,
        initialBoard: initialBoard,
        hostColor: hostColor,
      );

      _myUserId = user.userId;
      _gameStartedForHost = false;
      _gameStartedAt = null;
      _isLeaving = false;
      _lastKnownMoveCount = 0;
      _lastDisconnectClearedAt = null;
      _consecutiveOfflineChecks = 0;

      _safeUpdate(
        RoomState(
          roomId: roomId,
          myColor: hostColor,
          isHost: true,
          isLoading: false,
        ),
      );

      _listenToRoom(roomId);
      _startHeartbeat(roomId);

      return roomId;
    } catch (e) {
      _safeUpdate(
        state.copyWith(isLoading: false, error: 'Failed to create room'),
      );
      return null;
    }
  }

  Future<bool> joinRoom(String roomId) async {
    final user = ref.read(currentUserProvider);
    if (user == null) {
      _safeUpdate(state.copyWith(error: 'Profile not loaded'));
      return false;
    }

    _safeUpdate(state.copyWith(isLoading: true, error: null));

    try {
      final code = roomId.trim().toUpperCase();

      final exists = await RoomService.roomExists(code);
      if (!exists) {
        _safeUpdate(state.copyWith(isLoading: false, error: 'Room not found'));
        return false;
      }

      final success = await RoomService.joinRoom(roomId: code, guest: user);
      if (!success) {
        _safeUpdate(
          state.copyWith(
            isLoading: false,
            error: 'Room full or not available',
          ),
        );
        return false;
      }

      _myUserId = user.userId;
      _gameStartedAt = DateTime.now();
      _isLeaving = false;
      _lastKnownMoveCount = 0;
      _lastDisconnectClearedAt = null;
      _consecutiveOfflineChecks = 0;

      final roomStream = RoomService.listenToRoom(code);
      final roomData = await roomStream.first;

      Player myColor;
      if (roomData != null) {
        myColor = roomData.hostColor.opponent;
      } else {
        myColor = Player.white;
      }

      _safeUpdate(
        RoomState(
          roomId: code,
          myColor: myColor,
          isHost: false,
          isLoading: false,
        ),
      );

      _listenToRoom(code);
      _startHeartbeat(code);

      ref.read(gameProvider.notifier).startOnline(myColor);
      _wireOnlineCallback();
      _startOfflineCheck();

      return true;
    } catch (e) {
      _safeUpdate(
        state.copyWith(isLoading: false, error: 'Failed to join room'),
      );
      return false;
    }
  }

  // ══════════════════════════════════════
  // ROOM LISTENER - Fixed: move-aware disconnect clearing
  // ══════════════════════════════════════

  void _listenToRoom(String roomId) {
    _roomSub?.cancel();

    _roomSub = RoomService.listenToRoom(roomId).listen(
      (roomData) {
        if (_disposed || _isLeaving) return;

        if (roomData == null) {
          _handleGameClosed('room_deleted');
          return;
        }

        if (roomData.isClosed) {
          _handleGameClosed(roomData.closedReason);
          return;
        }

        // FIX: Detect if opponent made a new move (most reliable "alive" signal)
        final moveCountChanged = roomData.moveCount > _lastKnownMoveCount;
        if (moveCountChanged) {
          _lastKnownMoveCount = roomData.moveCount;
          // Opponent made a move → they are definitely online
          // Reset consecutive checks so we don't falsely mark them
          _consecutiveOfflineChecks = 0;
        }

        _safeUpdate(state.copyWith(roomData: roomData));

        if (roomData.isPlaying) {
          _handleDisconnectState(roomData);
        }

        if (roomData.isPlaying && state.isHost && !_gameStartedForHost) {
          _gameStartedForHost = true;
          _gameStartedAt = DateTime.now();
          _lastKnownMoveCount = roomData.moveCount;

          ref
              .read(gameProvider.notifier)
              .startOnline(state.myColor ?? Player.black);
          _wireOnlineCallback();
          _startOfflineCheck();
        }

        if (roomData.isPlaying) {
          final game = ref.read(gameProvider);
          if (roomData.moveCount > game.moveCount) {
            ref
                .read(gameProvider.notifier)
                .updateFromOnline(
                  roomData.board,
                  roomData.currentTurn,
                  roomData.blackScore,
                  roomData.whiteScore,
                  roomData.moveCount,
                );
          }
        }
      },
      onError: (e) {
        if (!_disposed && !_isLeaving) {
          _safeUpdate(state.copyWith(error: 'Connection lost'));
        }
      },
    );
  }

  // ══════════════════════════════════════
  // SEND MOVE - Fixed: also clears disconnect
  // ══════════════════════════════════════

  Future<void> sendMove() async {
    final room = state.roomId;
    if (room == null || _disposed || _isLeaving) return;

    try {
      final game = ref.read(gameProvider);

      // FIX: Update board (which already clears disconnect flags in RoomService)
      await RoomService.updateBoard(
        roomId: room,
        board: game.board,
        nextTurn: game.currentTurn,
        blackScore: game.blackScore,
        whiteScore: game.whiteScore,
        moveCount: game.moveCount,
      );

      // FIX: Send an extra heartbeat right after move to ensure lastSeen is fresh
      _sendHeartbeat(room);
    } catch (e) {
      debugPrint('Send move error: $e');
    }
  }

  // ══════════════════════════════════════
  // APP LIFECYCLE - Fixed: less aggressive self-marking
  // ══════════════════════════════════════

  void onAppPaused() {
    if (_disposed || state.roomId == null || _myUserId == null) return;
    if (!state.isPlaying) return;

    _stopHeartbeat();
    // FIX: Removed the aggressive 8-second self-mark.
    // The OPPONENT's offline checker will detect us as offline
    // after consecutive checks fail. This prevents false positives
    // when the app briefly pauses (e.g., notification overlay).
  }

  void onAppResumed() {
    if (_disposed || state.roomId == null || _myUserId == null) return;

    // FIX: Restart heartbeat immediately
    _startHeartbeat(state.roomId!);

    if (state.isPlaying) {
      // FIX: Clear any disconnect flag on ourselves
      RoomService.clearDisconnect(state.roomId!, _myUserId!);

      // FIX: Send immediate heartbeat to update lastSeen
      _sendHeartbeat(state.roomId!);
    }
  }

  // ══════════════════════════════════════
  // LEAVE ROOM
  // ══════════════════════════════════════

  Future<void> leaveRoom() async {
    _isLeaving = true;

    _stopDisconnectCountdown();
    _stopHeartbeat();
    _stopOfflineCheck();
    _roomSub?.cancel();
    _roomSub = null;
    _unwireOnlineCallback();

    final roomId = state.roomId;
    final userId = _myUserId;

    // Reset state immediately so UI doesn't react to further events
    state = const RoomState();

    if (roomId != null && userId != null) {
      try {
        await RoomService.leaveRoom(roomId, userId);
      } catch (_) {}
    }

    _isLeaving = false;
  }

  void clearError() {
    if (!_isLeaving) {
      _safeUpdate(state.copyWith(error: null));
    }
  }
}