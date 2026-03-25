import 'dart:async';
import 'package:knock_the_marble/widgets/banner_ad_widget.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/user_profile.dart';
import '../providers/user_provider.dart';
import '../providers/settings_provider.dart';
import '../widgets/avatar_picker.dart';

class ProfileScreen extends ConsumerStatefulWidget {
  final bool isFirstTime;

  const ProfileScreen({super.key, this.isFirstTime = false});

  @override
  ConsumerState<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends ConsumerState<ProfileScreen>
    with SingleTickerProviderStateMixin {
  late TextEditingController _nameCtrl;
  late AnimationController _animCtrl;
  Timer? _debounce;
  NameValidationState _validationState = NameValidationState.idle;
  bool _saving = false;
  bool _initialized = false;

  @override
  void initState() {
    super.initState();
    _nameCtrl = TextEditingController();
    _animCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    )..forward();
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _animCtrl.dispose();
    _debounce?.cancel();
    super.dispose();
  }

  void _initName(UserProfile user) {
    if (!_initialized) {
      _initialized = true;
      if (user.displayName.isNotEmpty) {
        _nameCtrl.text = user.displayName;
        _validationState = NameValidationState.available;
      }
    }
  }

  void _onNameChanged(String value) {
    _debounce?.cancel();

    final trimmed = value.trim();
    if (trimmed.isEmpty) {
      setState(() => _validationState = NameValidationState.idle);
      return;
    }
    if (trimmed.length < 3) {
      setState(() => _validationState = NameValidationState.tooShort);
      return;
    }
    if (trimmed.length > 16) {
      setState(() => _validationState = NameValidationState.tooLong);
      return;
    }

    final valid = RegExp(r'^[a-zA-Z0-9_]+$');
    if (!valid.hasMatch(trimmed)) {
      setState(() => _validationState = NameValidationState.invalid);
      return;
    }

    setState(() => _validationState = NameValidationState.checking);

    _debounce = Timer(const Duration(milliseconds: 500), () async {
      final result = await ref
          .read(userProvider.notifier)
          .validateName(trimmed);
      if (mounted) {
        setState(() => _validationState = result);
      }
    });
  }

  Future<void> _save() async {
    if (_saving) return;
    final name = _nameCtrl.text.trim();

    if (name.isEmpty && !widget.isFirstTime) {
      Navigator.pop(context);
      return;
    }

    if (name.isNotEmpty && _validationState != NameValidationState.available) {
      return;
    }

    setState(() => _saving = true);

    try {
      if (name.isNotEmpty) {
        final success = await ref.read(userProvider.notifier).updateName(name);
        if (!success && mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(const SnackBar(content: Text('Name already taken!')));
          setState(() => _saving = false);
          return;
        }
      }

      if (mounted) {
        HapticFeedback.mediumImpact();
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    }

    if (mounted) setState(() => _saving = false);
  }

  @override
  Widget build(BuildContext context) {
    final t = ref.watch(boardThemeProvider);
    final userAsync = ref.watch(userProvider);

    return Scaffold(
      // ── Banner outside the rebuild tree ──
      bottomNavigationBar: const BannerAdWidget(),
      body: Container(
        decoration: BoxDecoration(gradient: t.backgroundGradient),
        child: SafeArea(
          child: userAsync.when(
            loading: () =>
                Center(child: CircularProgressIndicator(color: t.accent)),
            error: (e, _) => Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'Error loading profile',
                    style: TextStyle(color: t.textPrimary),
                  ),
                  const SizedBox(height: 8),
                  TextButton(
                    onPressed: () =>
                        ref.read(userProvider.notifier).refreshProfile(),
                    child: Text('Retry', style: TextStyle(color: t.accent)),
                  ),
                ],
              ),
            ),
            data: (user) {
              _initName(user);
              return _buildContent(user, t);
            },
          ),
        ),
      ),
    );
  }

  Widget _buildContent(UserProfile user, dynamic t) {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        children: [
          const SizedBox(height: 16),

          // ── Back button (replace existing) ──
          Align(
            alignment: Alignment.centerLeft,
            child: GestureDetector(
              onTap: () => Navigator.pop(context),
              child: Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: t.cardColor.withOpacity(0.5),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: t.surfaceBorder),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.15),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: const Icon(
                  Icons.chevron_left_rounded,
                  size: 22,
                  color: Colors.white70,
                ),
              ),
            ),
          ),
          const SizedBox(height: 20),

          // Title
          FadeTransition(
            opacity: _animCtrl,
            child: Text(
              widget.isFirstTime ? 'CREATE PROFILE' : 'EDIT PROFILE',
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w900,
                letterSpacing: 3,
                color: t.textPrimary,
              ),
            ),
          ),

          const SizedBox(height: 8),

          // User ID badge
          FadeTransition(
            opacity: _animCtrl,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
              decoration: BoxDecoration(
                color: t.cardColor.withOpacity(0.5),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: t.surfaceBorder),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.tag_rounded, size: 14, color: t.accent),
                  const SizedBox(width: 6),
                  Text(
                    user.shortId,
                    style: TextStyle(
                      color: t.accent,
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 1,
                    ),
                  ),
                  const SizedBox(width: 6),
                  GestureDetector(
                    onTap: () {
                      Clipboard.setData(ClipboardData(text: user.shortId));
                      HapticFeedback.lightImpact();
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('ID copied: ${user.shortId}'),
                          duration: const Duration(seconds: 1),
                        ),
                      );
                    },
                    child: Icon(Icons.copy_all_rounded, size: 13, color: t.textSecondary),
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 30),

          // ── AVATAR SECTION ──
          Text(
            'CHOOSE AVATAR',
            style: TextStyle(
              color: t.textSecondary,
              fontSize: 11,
              fontWeight: FontWeight.w700,
              letterSpacing: 1.5,
            ),
          ),
          const SizedBox(height: 14),

          AvatarPicker(
            selectedIndex: user.avatarIndex,
            onSelect: (index) {
              HapticFeedback.selectionClick();
              ref.read(userProvider.notifier).updateAvatar(index);
            },
          ),

          const SizedBox(height: 30),

          // ── NAME SECTION ──
          Text(
            'DISPLAY NAME',
            style: TextStyle(
              color: t.textSecondary,
              fontSize: 11,
              fontWeight: FontWeight.w700,
              letterSpacing: 1.5,
            ),
          ),
          const SizedBox(height: 10),

          Container(
            decoration: BoxDecoration(
              color: t.cardColor.withOpacity(0.6),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: _getBorderColor(t), width: 1.5),
            ),
            child: TextField(
              controller: _nameCtrl,
              onChanged: _onNameChanged,
              maxLength: 16,
              style: TextStyle(
                color: t.textPrimary,
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
              decoration: InputDecoration(
                hintText: 'Enter unique name...',
                hintStyle: TextStyle(color: t.textSecondary.withOpacity(0.4)),
                counterText: '',
                border: InputBorder.none,
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 14,
                ),
                suffixIcon: _validationIcon(t),
              ),
            ),
          ),

          const SizedBox(height: 6),
          _validationMessage(t),

          const SizedBox(height: 8),
          Text(
            '3-16 characters • letters, numbers, underscore',
            style: TextStyle(color: t.textSecondary, fontSize: 10),
          ),

          const SizedBox(height: 36),

          // ── SAVE BUTTON ──
          SizedBox(
            width: double.infinity,
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: _canSave() ? _save : null,
                borderRadius: BorderRadius.circular(16),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 300),
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(16),
                    gradient: _canSave()
                        ? LinearGradient(
                            colors: [t.accent, t.accent.withOpacity(0.8)],
                          )
                        : null,
                    color: _canSave() ? null : t.cardColor.withOpacity(0.3),
                    border: Border.all(
                      color: _canSave()
                          ? t.accent.withOpacity(0.5)
                          : t.surfaceBorder,
                    ),
                  ),
                  child: Center(
                    child: _saving
                        ? SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: t.textPrimary,
                            ),
                          )
                        : Text(
                            widget.isFirstTime ? 'GET STARTED' : 'SAVE',
                            style: TextStyle(
                              color: _canSave()
                                  ? Colors.white
                                  : t.textSecondary,
                              fontSize: 15,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 1.5,
                            ),
                          ),
                  ),
                ),
              ),
            ),
          ),

          const SizedBox(height: 30),
        ],
      ),
    );
  }

  bool _canSave() {
    if (_saving) return false;
    final name = _nameCtrl.text.trim();
    if (name.isEmpty) return true;
    return _validationState == NameValidationState.available;
  }

  Color _getBorderColor(dynamic t) {
    switch (_validationState) {
      case NameValidationState.available:
        return Colors.green.withOpacity(0.5);
      case NameValidationState.taken:
      case NameValidationState.invalid:
        return Colors.red.withOpacity(0.5);
      case NameValidationState.tooShort:
      case NameValidationState.tooLong:
        return Colors.orange.withOpacity(0.5);
      case NameValidationState.checking:
        return t.accent.withOpacity(0.3);
      case NameValidationState.idle:
        return t.surfaceBorder;
    }
  }

 // ── Validation icons method - replace _validationIcon ──
Widget? _validationIcon(dynamic t) {
  switch (_validationState) {
    case NameValidationState.checking:
      return Padding(
        padding: const EdgeInsets.all(14),
        child: SizedBox(
          width: 16,
          height: 16,
          child: CircularProgressIndicator(
            strokeWidth: 2,
            color: t.accent,
          ),
        ),
      );
    case NameValidationState.available:
      return const Padding(
        padding: EdgeInsets.all(14),
        child: Icon(
          Icons.check_circle_rounded,
          color: Colors.green,
          size: 20,
        ),
      );
    case NameValidationState.taken:
      return const Padding(
        padding: EdgeInsets.all(14),
        child: Icon(
          Icons.cancel_rounded,
          color: Colors.red,
          size: 20,
        ),
      );
    case NameValidationState.tooShort:
    case NameValidationState.tooLong:
    case NameValidationState.invalid:
      return const Padding(
        padding: EdgeInsets.all(14),
        child: Icon(
          Icons.error_rounded,
          color: Colors.orange,
          size: 20,
        ),
      );
    case NameValidationState.idle:
      return Padding(
        padding: const EdgeInsets.all(14),
        child: Icon(
          Icons.edit_rounded,
          color: t.textSecondary.withOpacity(0.3),
          size: 18,
        ),
      );
  }
}

  Widget _validationMessage(dynamic t) {
    String msg = '';
    Color color = t.textSecondary;

    switch (_validationState) {
      case NameValidationState.available:
        msg = '✓ Name available!';
        color = Colors.green;
        break;
      case NameValidationState.taken:
        msg = '✗ Name already taken';
        color = Colors.red;
        break;
      case NameValidationState.tooShort:
        msg = 'Too short (min 3 characters)';
        color = Colors.orange;
        break;
      case NameValidationState.tooLong:
        msg = 'Too long (max 16 characters)';
        color = Colors.orange;
        break;
      case NameValidationState.invalid:
        msg = 'Only letters, numbers, underscore allowed';
        color = Colors.orange;
        break;
      case NameValidationState.checking:
        msg = 'Checking availability...';
        break;
      case NameValidationState.idle:
        break;
    }

    return SizedBox(
      height: 16,
      child: Text(msg, style: TextStyle(color: color, fontSize: 11)),
    );
  }
}
