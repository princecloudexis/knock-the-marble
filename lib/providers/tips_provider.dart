import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

final tipsProvider = NotifierProvider<TipsNotifier, TipsState>(
  TipsNotifier.new,
);

final tipsRemainingProvider = Provider<int>(
  (ref) => ref.watch(tipsProvider).remaining,
);

final canUseTipProvider = Provider<bool>(
  (ref) => ref.watch(tipsProvider).remaining > 0,
);

class TipsState {
  final int remaining;
  final int maxPerDay;
  final String lastResetDate;
  final bool isShowingTip;

  const TipsState({
    this.remaining = 5,
    this.maxPerDay = 5,
    this.lastResetDate = '',
    this.isShowingTip = false,
  });

  TipsState copyWith({
    int? remaining,
    int? maxPerDay,
    String? lastResetDate,
    bool? isShowingTip,
  }) {
    return TipsState(
      remaining: remaining ?? this.remaining,
      maxPerDay: maxPerDay ?? this.maxPerDay,
      lastResetDate: lastResetDate ?? this.lastResetDate,
      isShowingTip: isShowingTip ?? this.isShowingTip,
    );
  }
}

class TipsNotifier extends Notifier<TipsState> {
  static const String _prefKeyRemaining = 'tips_remaining';
  static const String _prefKeyLastReset = 'tips_last_reset';
  static const int _dailyLimit = 5;

  @override
  TipsState build() {
    _loadFromPrefs();
    return const TipsState();
  }

  Future<void> _loadFromPrefs() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final today = _todayString();
      final lastReset = prefs.getString(_prefKeyLastReset) ?? '';
      int remaining;

      if (lastReset != today) {
        remaining = _dailyLimit;
        await prefs.setInt(_prefKeyRemaining, _dailyLimit);
        await prefs.setString(_prefKeyLastReset, today);
      } else {
        remaining = prefs.getInt(_prefKeyRemaining) ?? _dailyLimit;
      }

      state = TipsState(
        remaining: remaining,
        maxPerDay: _dailyLimit,
        lastResetDate: today,
      );
    } catch (_) {
      state = const TipsState();
    }
  }

  Future<bool> useTip() async {
    final today = _todayString();
    if (state.lastResetDate != today) {
      await _loadFromPrefs();
    }

    if (state.remaining <= 0) return false;

    final newRemaining = state.remaining - 1;
    state = state.copyWith(remaining: newRemaining, isShowingTip: true);

    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt(_prefKeyRemaining, newRemaining);
    } catch (_) {}

    return true;
  }

  void clearTipDisplay() {
    state = state.copyWith(isShowingTip: false);
  }

  /// Add extra tips (from rewarded ad)
  Future<void> addExtraTips(int count) async {
    final newRemaining = state.remaining + count;
    state = state.copyWith(remaining: newRemaining);

    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt(_prefKeyRemaining, newRemaining);
    } catch (_) {}
  }

  String _todayString() {
    final now = DateTime.now();
    return '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
  }
}