import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/ad_service.dart';

final adProvider = NotifierProvider<AdNotifier, AdState>(AdNotifier.new);

class AdState {
  final bool initialized;
  final bool isAdFree;
  final bool earnedGameOverReward;

  const AdState({
    this.initialized = false,
    this.isAdFree = false,
    this.earnedGameOverReward = false,
  });

  AdState copyWith({
    bool? initialized,
    bool? isAdFree,
    bool? earnedGameOverReward,
  }) {
    return AdState(
      initialized: initialized ?? this.initialized,
      isAdFree: isAdFree ?? this.isAdFree,
      earnedGameOverReward: earnedGameOverReward ?? this.earnedGameOverReward,
    );
  }
}

class AdNotifier extends Notifier<AdState> {
  @override
  AdState build() {
    return AdState(initialized: AdService.isInitialized);
  }

  void showAdBeforeGame({required VoidCallback onDone}) {
    if (state.isAdFree || !AdService.isInitialized) {
      onDone();
      return;
    }
    AdService.showInterstitial(onDone: onDone);
  }

  /// Shows rewarded interstitial at game over.
  /// This is the "game-playing" video ad that shows automatically.
  /// If user watches fully, they earn a reward.
  /// Falls back to regular interstitial if not loaded.
  void showGameOverAd({
    required VoidCallback onDone,
    VoidCallback? onReward,
  }) {
    if (state.isAdFree || !AdService.isInitialized) {
      onDone();
      return;
    }

    // Reset reward state
    state = state.copyWith(earnedGameOverReward: false);

    AdService.showRewardedInterstitial(
      onDone: onDone,
      onReward: () {
        state = state.copyWith(earnedGameOverReward: true);
        onReward?.call();
      },
    );
  }

  Future<bool> showRewardedAd({
    required VoidCallback onReward,
    VoidCallback? onDone,
  }) async {
    if (!AdService.isInitialized || !AdService.isRewardedLoaded) {
      AdService.loadRewarded();
      onDone?.call();
      return false;
    }
    return await AdService.showRewarded(onReward: onReward, onDone: onDone);
  }

  bool get isRewardedReady => AdService.isRewardedLoaded;

  void setAdFree(bool value) {
    state = state.copyWith(isAdFree: value);
  }

  void resetGameOverReward() {
    state = state.copyWith(earnedGameOverReward: false);
  }
}