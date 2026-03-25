import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../theme/board_themes.dart';

final settingsProvider =
    NotifierProvider<SettingsNotifier, SettingsState>(SettingsNotifier.new);

final boardThemeProvider = Provider<BoardTheme>((ref) {
  final type = ref.watch(settingsProvider.select((s) => s.boardTheme));
  return BoardThemes.fromType(type);
});

// Quick access providers for widgets
final showHintsProvider = Provider<bool>(
  (ref) => ref.watch(settingsProvider.select((s) => s.showMoveHints)),
);

final hapticEnabledProvider = Provider<bool>(
  (ref) => ref.watch(settingsProvider.select((s) => s.hapticEnabled)),
);

final soundEnabledProvider = Provider<bool>(
  (ref) => ref.watch(settingsProvider.select((s) => s.soundEnabled)),
);

final animationSpeedProvider = Provider<double>(
  (ref) => ref.watch(settingsProvider.select((s) => s.animationSpeed)),
);

final hasSeenTutorialProvider = Provider<bool>(
  (ref) => ref.watch(settingsProvider.select((s) => s.hasSeenTutorial)),
);

class SettingsState {
  final bool soundEnabled;
  final bool hapticEnabled;
  final bool showMoveHints;
  final double animationSpeed;
  final BoardThemeType boardTheme;
  final bool hasSeenTutorial;

  const SettingsState({
    this.soundEnabled = true,
    this.hapticEnabled = true,
    this.showMoveHints = true,
    this.animationSpeed = 1.0,
    this.boardTheme = BoardThemeType.woodClassic,
    this.hasSeenTutorial = false,
  });

  /// Get actual duration multiplier (lower speed value = faster)
  double get speedMultiplier => 1.0 / animationSpeed;

  /// Get duration adjusted by animation speed
  Duration adjustDuration(Duration base) {
    return Duration(
      milliseconds: (base.inMilliseconds * speedMultiplier).round(),
    );
  }

  SettingsState copyWith({
    bool? soundEnabled,
    bool? hapticEnabled,
    bool? showMoveHints,
    double? animationSpeed,
    BoardThemeType? boardTheme,
    bool? hasSeenTutorial,
  }) {
    return SettingsState(
      soundEnabled: soundEnabled ?? this.soundEnabled,
      hapticEnabled: hapticEnabled ?? this.hapticEnabled,
      showMoveHints: showMoveHints ?? this.showMoveHints,
      animationSpeed: animationSpeed ?? this.animationSpeed,
      boardTheme: boardTheme ?? this.boardTheme,
      hasSeenTutorial: hasSeenTutorial ?? this.hasSeenTutorial,
    );
  }

  Map<String, dynamic> toMap() => {
        'soundEnabled': soundEnabled,
        'hapticEnabled': hapticEnabled,
        'showMoveHints': showMoveHints,
        'animationSpeed': animationSpeed,
        'boardTheme': boardTheme.index,
        'hasSeenTutorial': hasSeenTutorial,
      };

  factory SettingsState.fromMap(Map<String, dynamic> map) {
    return SettingsState(
      soundEnabled: map['soundEnabled'] ?? true,
      hapticEnabled: map['hapticEnabled'] ?? true,
      showMoveHints: map['showMoveHints'] ?? true,
      animationSpeed: (map['animationSpeed'] ?? 1.0).toDouble(),
      boardTheme: BoardThemeType.values[
          (map['boardTheme'] ?? 0).clamp(0, BoardThemeType.values.length - 1)],
      hasSeenTutorial: map['hasSeenTutorial'] ?? false,
    );
  }
}

class SettingsNotifier extends Notifier<SettingsState> {
  @override
  SettingsState build() {
    _loadFromPrefs();
    return const SettingsState();
  }

  Future<void> _loadFromPrefs() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      state = SettingsState(
        soundEnabled: prefs.getBool('soundEnabled') ?? true,
        hapticEnabled: prefs.getBool('hapticEnabled') ?? true,
        showMoveHints: prefs.getBool('showMoveHints') ?? true,
        animationSpeed: prefs.getDouble('animationSpeed') ?? 1.0,
        boardTheme: BoardThemeType.values[
            (prefs.getInt('boardTheme') ?? 0)
                .clamp(0, BoardThemeType.values.length - 1)],
        hasSeenTutorial: prefs.getBool('hasSeenTutorial') ?? false,
      );
    } catch (_) {}
  }

  Future<void> _save() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('soundEnabled', state.soundEnabled);
      await prefs.setBool('hapticEnabled', state.hapticEnabled);
      await prefs.setBool('showMoveHints', state.showMoveHints);
      await prefs.setDouble('animationSpeed', state.animationSpeed);
      await prefs.setInt('boardTheme', state.boardTheme.index);
      await prefs.setBool('hasSeenTutorial', state.hasSeenTutorial);
    } catch (_) {}
  }

  void toggleSound() {
    state = state.copyWith(soundEnabled: !state.soundEnabled);
    _save();
  }

  void toggleHaptic() {
    state = state.copyWith(hapticEnabled: !state.hapticEnabled);
    _save();
  }

  void toggleHints() {
    state = state.copyWith(showMoveHints: !state.showMoveHints);
    _save();
  }

  void setAnimationSpeed(double speed) {
    state = state.copyWith(animationSpeed: speed);
    _save();
  }

  void setBoardTheme(BoardThemeType theme) {
    state = state.copyWith(boardTheme: theme);
    _save();
  }

  void markTutorialSeen() {
    state = state.copyWith(hasSeenTutorial: true);
    _save();
  }

  void resetTutorial() {
    state = state.copyWith(hasSeenTutorial: false);
    _save();
  }

  void resetDefaults() {
    state = const SettingsState();
    _save();
  }
}