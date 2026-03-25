import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/user_profile.dart';
import '../services/user_service.dart';

final userProvider =
    AsyncNotifierProvider<UserNotifier, UserProfile>(UserNotifier.new);

final currentUserProvider = Provider<UserProfile?>((ref) {
  final asyncValue = ref.watch(userProvider);
  return asyncValue.when(
    data: (profile) => profile,
    loading: () => null,
    error: (_, __) => null,
  );
});

enum NameValidationState {
  idle,
  checking,
  available,
  taken,
  tooShort,
  tooLong,
  invalid,
}

class UserNotifier extends AsyncNotifier<UserProfile> {
  @override
  Future<UserProfile> build() async {
    // This is now fast because UserService uses cache
    return await UserService.initializeUser();
  }

  UserProfile? get _current {
    return state.when(
      data: (profile) => profile,
      loading: () => null,
      error: (_, __) => null,
    );
  }

  Future<bool> updateName(String name) async {
    final current = _current;
    if (current == null) return false;

    final trimmed = name.trim();
    if (trimmed.length < 3 || trimmed.length > 16) return false;

    final validPattern = RegExp(r'^[a-zA-Z0-9_]+$');
    if (!validPattern.hasMatch(trimmed)) return false;

    final available = await UserService.isNameAvailable(trimmed, current.userId);
    if (!available) return false;

    final updated = current.copyWith(displayName: trimmed);
    await UserService.saveProfile(updated);
    state = AsyncData(updated);
    return true;
  }

  Future<void> updateAvatar(int index) async {
    final current = _current;
    if (current == null) return;

    final updated = current.copyWith(avatarIndex: index);
    await UserService.saveProfile(updated);
    state = AsyncData(updated);
  }

  Future<NameValidationState> validateName(String name) async {
    final current = _current;
    if (current == null) return NameValidationState.invalid;

    final trimmed = name.trim();
    if (trimmed.isEmpty) return NameValidationState.idle;
    if (trimmed.length < 3) return NameValidationState.tooShort;
    if (trimmed.length > 16) return NameValidationState.tooLong;

    final validPattern = RegExp(r'^[a-zA-Z0-9_]+$');
    if (!validPattern.hasMatch(trimmed)) return NameValidationState.invalid;

    final available = await UserService.isNameAvailable(trimmed, current.userId);
    return available
        ? NameValidationState.available
        : NameValidationState.taken;
  }

  Future<void> refreshProfile() async {
    UserService.clearCache();
    state = const AsyncLoading();
    state = AsyncData(await UserService.initializeUser());
  }
}