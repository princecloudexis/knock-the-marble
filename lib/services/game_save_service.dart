import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/hex.dart';
import '../models/player.dart';
import '../models/game_state.dart';
import '../models/game_mode.dart';

class SavedGameData {
  final Map<Hex, Player> board;
  final Player currentTurn;
  final int blackScore;
  final int whiteScore;
  final int moveCount;
  final GameMode mode;
  final AiDifficulty? aiDifficulty;
  final Player? myColor;
  final DateTime savedAt;

  const SavedGameData({
    required this.board,
    required this.currentTurn,
    required this.blackScore,
    required this.whiteScore,
    required this.moveCount,
    required this.mode,
    this.aiDifficulty,
    this.myColor,
    required this.savedAt,
  });

  Map<String, dynamic> toJson() {
    final boardMap = <String, int>{};
    board.forEach((hex, player) {
      boardMap['${hex.q},${hex.r}'] = player.index;
    });

    return {
      'board': boardMap,
      'currentTurn': currentTurn.index,
      'blackScore': blackScore,
      'whiteScore': whiteScore,
      'moveCount': moveCount,
      'mode': mode.index,
      'aiDifficulty': aiDifficulty?.index,
      'myColor': myColor?.index,
      'savedAt': savedAt.millisecondsSinceEpoch,
    };
  }

  factory SavedGameData.fromJson(Map<String, dynamic> json) {
    final boardMap = <Hex, Player>{};
    final rawBoard = Map<String, dynamic>.from(json['board'] ?? {});

    rawBoard.forEach((key, value) {
      final parts = key.split(',');
      if (parts.length == 2) {
        final q = int.tryParse(parts[0]);
        final r = int.tryParse(parts[1]);
        if (q != null && r != null) {
          boardMap[Hex(q, r)] = Player.values[(value as int).clamp(0, 2)];
        }
      }
    });

    return SavedGameData(
      board: boardMap,
      currentTurn: Player.values[(json['currentTurn'] as int? ?? 0).clamp(0, 2)],
      blackScore: json['blackScore'] ?? 0,
      whiteScore: json['whiteScore'] ?? 0,
      moveCount: json['moveCount'] ?? 0,
      mode: GameMode.values[(json['mode'] as int? ?? 0).clamp(0, 2)],
      aiDifficulty: json['aiDifficulty'] != null
          ? AiDifficulty.values[(json['aiDifficulty'] as int).clamp(0, 2)]
          : null,
      myColor: json['myColor'] != null
          ? Player.values[(json['myColor'] as int).clamp(0, 2)]
          : null,
      savedAt: DateTime.fromMillisecondsSinceEpoch(
        json['savedAt'] ?? DateTime.now().millisecondsSinceEpoch,
      ),
    );
  }

  String get difficultyLabel {
    switch (aiDifficulty) {
      case AiDifficulty.easy:
        return 'Easy';
      case AiDifficulty.medium:
        return 'Medium';
      case AiDifficulty.hard:
        return 'Hard';
      default:
        return '';
    }
  }

  String get modeLabel {
    switch (mode) {
      case GameMode.vsComputer:
        return 'vs Computer';
      case GameMode.localMultiplayer:
        return 'Local 1v1';
      case GameMode.online:
        return 'Online';
    }
  }
}

class GameSaveService {
  static const String _vsComputerKey = 'saved_game_vs_computer';
  static const String _localKey = 'saved_game_local';

  static SavedGameData? _vsComputerCache;
  static SavedGameData? _localCache;
  static bool _vsComputerCacheLoaded = false;
  static bool _localCacheLoaded = false;

  /// Get the correct key for a game mode
  static String _keyForMode(GameMode mode) {
    switch (mode) {
      case GameMode.vsComputer:
        return _vsComputerKey;
      case GameMode.localMultiplayer:
        return _localKey;
      case GameMode.online:
        return ''; // Never save online
    }
  }

  /// Check if saved game exists for a specific mode
  static Future<bool> hasSavedGame(GameMode mode) async {
    if (mode == GameMode.online) return false;
    final data = await loadGame(mode);
    return data != null;
  }

  /// Load saved game for a specific mode
  static Future<SavedGameData?> loadGame(GameMode mode) async {
    if (mode == GameMode.online) return null;

    // Check cache first
    if (mode == GameMode.vsComputer && _vsComputerCacheLoaded) {
      return _vsComputerCache;
    }
    if (mode == GameMode.localMultiplayer && _localCacheLoaded) {
      return _localCache;
    }

    try {
      final prefs = await SharedPreferences.getInstance();
      final key = _keyForMode(mode);
      final jsonStr = prefs.getString(key);

      if (jsonStr == null || jsonStr.isEmpty) {
        _setCache(mode, null);
        return null;
      }

      final json = jsonDecode(jsonStr) as Map<String, dynamic>;
      final data = SavedGameData.fromJson(json);

      // Validate board
      if (data.board.length < 50) {
        await deleteSave(mode);
        return null;
      }

      // Check expiry (7 days)
      if (DateTime.now().difference(data.savedAt).inDays > 7) {
        await deleteSave(mode);
        return null;
      }

      // Validate mode matches
      if (data.mode != mode) {
        await deleteSave(mode);
        return null;
      }

      _setCache(mode, data);
      return data;
    } catch (e) {
      _setCache(mode, null);
      return null;
    }
  }

  /// Save game for current mode
  static Future<void> saveGame({
    required GameState gameState,
    required GameMode mode,
    AiDifficulty? aiDifficulty,
    Player? myColor,
  }) async {
    // Never save online or finished or no-move games
    if (mode == GameMode.online) return;
    if (gameState.isGameOver) {
      await deleteSave(mode);
      return;
    }
    if (gameState.moveCount == 0) return;

    try {
      final saveData = SavedGameData(
        board: gameState.board,
        currentTurn: gameState.currentTurn,
        blackScore: gameState.blackScore,
        whiteScore: gameState.whiteScore,
        moveCount: gameState.moveCount,
        mode: mode,
        aiDifficulty: aiDifficulty,
        myColor: myColor,
        savedAt: DateTime.now(),
      );

      final prefs = await SharedPreferences.getInstance();
      final key = _keyForMode(mode);
      await prefs.setString(key, jsonEncode(saveData.toJson()));

      _setCache(mode, saveData);
    } catch (_) {}
  }

  /// Delete saved game for a specific mode
  static Future<void> deleteSave(GameMode mode) async {
    if (mode == GameMode.online) return;

    try {
      final prefs = await SharedPreferences.getInstance();
      final key = _keyForMode(mode);
      await prefs.remove(key);
    } catch (_) {}

    _setCache(mode, null);
  }

  /// Delete ALL saves
  static Future<void> deleteAllSaves() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_vsComputerKey);
      await prefs.remove(_localKey);
    } catch (_) {}

    _vsComputerCache = null;
    _vsComputerCacheLoaded = true;
    _localCache = null;
    _localCacheLoaded = true;
  }

  /// Clear cache (call when entering menu to force fresh reads)
  static void clearCache() {
    _vsComputerCacheLoaded = false;
    _vsComputerCache = null;
    _localCacheLoaded = false;
    _localCache = null;
  }

  static void _setCache(GameMode mode, SavedGameData? data) {
    if (mode == GameMode.vsComputer) {
      _vsComputerCache = data;
      _vsComputerCacheLoaded = true;
    } else if (mode == GameMode.localMultiplayer) {
      _localCache = data;
      _localCacheLoaded = true;
    }
  }
}