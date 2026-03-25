import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/user_provider.dart';
import '../providers/settings_provider.dart';
import '../theme/board_themes.dart';

class NameSetupDialog {
  /// Show the name setup dialog. Returns true if saved, false if cancelled.
  static Future<bool?> show(
    BuildContext context,
    WidgetRef ref, {
    String title = 'Set Your Name',
    String subtitle = 'Choose a name before playing',
    String buttonText = 'Let\'s Play!',
    bool barrierDismissible = false,
  }) {
    final t = ref.read(boardThemeProvider);

    return showDialog<bool>(
      context: context,
      barrierDismissible: barrierDismissible,
      barrierColor: Colors.black.withOpacity(0.7),
      builder: (ctx) => _NameSetupDialogContent(
        t: t,
        title: title,
        subtitle: subtitle,
        buttonText: buttonText,
      ),
    );
  }

  /// Helper to check if user has name, show dialog if not.
  /// Returns true if name exists or was just set.
  static Future<bool> ensureNameSet(
    BuildContext context,
    WidgetRef ref, {
    String? subtitle,
  }) async {
    final user = ref.read(currentUserProvider);
    if (user == null) return false;
    if (user.displayName.trim().isNotEmpty) return true;

    final result = await show(
      context,
      ref,
      subtitle: subtitle ?? 'Choose a name before playing',
    );
    return result == true;
  }
}

class _NameSetupDialogContent extends ConsumerStatefulWidget {
  final BoardTheme t;
  final String title;
  final String subtitle;
  final String buttonText;

  const _NameSetupDialogContent({
    required this.t,
    required this.title,
    required this.subtitle,
    required this.buttonText,
  });

  @override
  ConsumerState<_NameSetupDialogContent> createState() =>
      _NameSetupDialogContentState();
}

class _NameSetupDialogContentState
    extends ConsumerState<_NameSetupDialogContent> {
  late TextEditingController _nameCtrl;
  Timer? _debounce;
  NameValidationState _validationState = NameValidationState.idle;
  bool _isSaving = false;
  String? _errorText;

  @override
  void initState() {
    super.initState();
    _nameCtrl = TextEditingController();

    // Pre-fill if user already has a name (editing scenario)
    final user = ref.read(currentUserProvider);
    if (user != null && user.displayName.isNotEmpty) {
      _nameCtrl.text = user.displayName;
      _validationState = NameValidationState.available;
    }
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _debounce?.cancel();
    super.dispose();
  }

  void _onNameChanged(String value) {
    _debounce?.cancel();

    final trimmed = value.trim();

    if (trimmed.isEmpty) {
      setState(() {
        _validationState = NameValidationState.idle;
        _errorText = null;
      });
      return;
    }

    if (trimmed.length < 3) {
      setState(() {
        _validationState = NameValidationState.tooShort;
        _errorText = 'At least 3 characters required';
      });
      return;
    }

    if (trimmed.length > 16) {
      setState(() {
        _validationState = NameValidationState.tooLong;
        _errorText = 'Maximum 16 characters';
      });
      return;
    }

    final validPattern = RegExp(r'^[a-zA-Z0-9_]+$');
    if (!validPattern.hasMatch(trimmed)) {
      setState(() {
        _validationState = NameValidationState.invalid;
        _errorText = 'Only letters, numbers, and underscore';
      });
      return;
    }

    // Check if same as current name
    final currentUser = ref.read(currentUserProvider);
    if (currentUser != null &&
        trimmed.toLowerCase() == currentUser.displayName.toLowerCase()) {
      setState(() {
        _validationState = NameValidationState.available;
        _errorText = null;
      });
      return;
    }

    setState(() {
      _validationState = NameValidationState.checking;
      _errorText = null;
    });

    // Debounce the server check
    _debounce = Timer(const Duration(milliseconds: 500), () async {
      final result =
          await ref.read(userProvider.notifier).validateName(trimmed);
      if (mounted) {
        setState(() {
          _validationState = result;
          _errorText = _getErrorForState(result);
        });
      }
    });
  }

  String? _getErrorForState(NameValidationState state) {
    switch (state) {
      case NameValidationState.tooShort:
        return 'At least 3 characters required';
      case NameValidationState.tooLong:
        return 'Maximum 16 characters';
      case NameValidationState.taken:
        return 'This name is already taken';
      case NameValidationState.invalid:
        return 'Only letters, numbers, and underscore';
      default:
        return null;
    }
  }

  bool get _canSave {
    if (_isSaving) return false;
    final name = _nameCtrl.text.trim();
    if (name.isEmpty) return false;
    return _validationState == NameValidationState.available;
  }

  Future<void> _handleSave() async {
    if (!_canSave) return;

    final name = _nameCtrl.text.trim();

    setState(() {
      _isSaving = true;
      _errorText = null;
    });

    try {
      final success =
          await ref.read(userProvider.notifier).updateName(name);

      if (!mounted) return;

      if (success) {
        HapticFeedback.mediumImpact();
        Navigator.pop(context, true);
      } else {
        setState(() {
          _isSaving = false;
          _validationState = NameValidationState.taken;
          _errorText = 'Name already taken, try another';
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isSaving = false;
          _errorText = 'Something went wrong, try again';
        });
      }
    }
  }

  Color _getBorderColor() {
    final t = widget.t;
    if (_errorText != null &&
        _validationState != NameValidationState.checking) {
      switch (_validationState) {
        case NameValidationState.taken:
        case NameValidationState.invalid:
          return Colors.red.withOpacity(0.5);
        case NameValidationState.tooShort:
        case NameValidationState.tooLong:
          return Colors.orange.withOpacity(0.5);
        default:
          return t.surfaceBorder.withOpacity(0.5);
      }
    }

    switch (_validationState) {
      case NameValidationState.available:
        return Colors.green.withOpacity(0.5);
      case NameValidationState.checking:
        return t.accent.withOpacity(0.4);
      default:
        return t.surfaceBorder.withOpacity(0.5);
    }
  }

  Widget? _buildSuffixIcon() {
    final t = widget.t;
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

  @override
  Widget build(BuildContext context) {
    final t = widget.t;

    return Dialog(
      backgroundColor: Colors.transparent,
      elevation: 0,
      insetPadding: const EdgeInsets.symmetric(horizontal: 28),
      child: SingleChildScrollView(
        child: Container(
          padding: const EdgeInsets.fromLTRB(24, 28, 24, 22),
          decoration: BoxDecoration(
            color: t.cardColor,
            borderRadius: BorderRadius.circular(28),
            border: Border.all(color: t.surfaceBorder.withOpacity(0.6)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.3),
                blurRadius: 30,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // ── Header Icon ──
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      t.accent.withOpacity(0.2),
                      t.accent.withOpacity(0.05),
                    ],
                  ),
                ),
                child: Icon(
                  Icons.person_rounded,
                  color: t.accent,
                  size: 28,
                ),
              ),
              const SizedBox(height: 16),

              // ── Title ──
              Text(
                widget.title,
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w900,
                  color: t.textPrimary,
                  letterSpacing: -0.3,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                widget.subtitle,
                style: TextStyle(
                  fontSize: 13,
                  color: t.textSecondary.withOpacity(0.7),
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),

              // ── Name Input ──
              Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(16),
                  color: t.surfaceColor.withOpacity(0.5),
                  border: Border.all(
                    color: _getBorderColor(),
                    width: 1.5,
                  ),
                ),
                child: TextField(
                  controller: _nameCtrl,
                  autofocus: true,
                  maxLength: 16,
                  style: TextStyle(
                    color: t.textPrimary,
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                  decoration: InputDecoration(
                    hintText: 'Enter unique name...',
                    hintStyle: TextStyle(
                      color: t.textSecondary.withOpacity(0.4),
                      fontSize: 15,
                    ),
                    counterText: '',
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 14,
                    ),
                    border: InputBorder.none,
                    prefixIcon: Icon(
                      Icons.alternate_email_rounded,
                      color: t.textSecondary.withOpacity(0.4),
                      size: 20,
                    ),
                    suffixIcon: _buildSuffixIcon(),
                  ),
                  inputFormatters: [
                    FilteringTextInputFormatter.allow(
                      RegExp(r'[a-zA-Z0-9_]'),
                    ),
                    LengthLimitingTextInputFormatter(16),
                  ],
                  onChanged: _onNameChanged,
                  onSubmitted: (_) => _handleSave(),
                ),
              ),

              // ── Validation Message ──
              const SizedBox(height: 6),
              SizedBox(
                height: 18,
                child: _buildValidationMessage(),
              ),

              // ── Rules Hint ──
              const SizedBox(height: 6),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: t.surfaceColor.withOpacity(0.3),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Username rules:',
                      style: TextStyle(
                        color: t.textSecondary,
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 4),
                    _ruleRow('3–16 characters', t),
                    _ruleRow('Letters, numbers, underscore only', t),
                    _ruleRow('Must be unique', t),
                  ],
                ),
              ),

              const SizedBox(height: 22),

              // ── Save Button ──
              SizedBox(
                width: double.infinity,
                child: GestureDetector(
                  onTap: _canSave ? _handleSave : null,
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    padding: const EdgeInsets.symmetric(vertical: 15),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(16),
                      gradient: _canSave
                          ? LinearGradient(
                              colors: [t.accent, t.accent.withOpacity(0.8)],
                            )
                          : null,
                      color: _canSave
                          ? null
                          : t.surfaceColor.withOpacity(0.3),
                      border: Border.all(
                        color: _canSave
                            ? t.accent.withOpacity(0.5)
                            : t.surfaceBorder.withOpacity(0.3),
                      ),
                      boxShadow: _canSave
                          ? [
                              BoxShadow(
                                color: t.accent.withOpacity(0.25),
                                blurRadius: 12,
                                offset: const Offset(0, 4),
                              ),
                            ]
                          : [],
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        if (_isSaving) ...[
                          SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white.withOpacity(0.8),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Text(
                            'Saving...',
                            style: TextStyle(
                              color: Colors.white.withOpacity(0.8),
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ] else ...[
                          Icon(
                            Icons.check_rounded,
                            color: _canSave
                                ? Colors.white
                                : t.textSecondary.withOpacity(0.4),
                            size: 20,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            widget.buttonText,
                            style: TextStyle(
                              color: _canSave
                                  ? Colors.white
                                  : t.textSecondary.withOpacity(0.4),
                              fontSize: 16,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 10),

              // ── Cancel ──
              GestureDetector(
                onTap: () => Navigator.pop(context, false),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 6),
                  child: Text(
                    'Cancel',
                    style: TextStyle(
                      color: t.textSecondary.withOpacity(0.5),
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildValidationMessage() {
    final t = widget.t;
    String msg = '';
    Color color = t.textSecondary;
    IconData? icon;

    switch (_validationState) {
      case NameValidationState.available:
        msg = 'Name is available!';
        color = Colors.green;
        icon = Icons.check_circle_rounded;
        break;
      case NameValidationState.taken:
        msg = _errorText ?? 'Name already taken';
        color = Colors.red;
        icon = Icons.cancel_rounded;
        break;
      case NameValidationState.tooShort:
        msg = _errorText ?? 'Too short (min 3)';
        color = Colors.orange;
        icon = Icons.warning_rounded;
        break;
      case NameValidationState.tooLong:
        msg = _errorText ?? 'Too long (max 16)';
        color = Colors.orange;
        icon = Icons.warning_rounded;
        break;
      case NameValidationState.invalid:
        msg = _errorText ?? 'Invalid characters';
        color = Colors.orange;
        icon = Icons.error_rounded;
        break;
      case NameValidationState.checking:
        msg = 'Checking availability...';
        color = t.accent;
        icon = null;
        break;
      case NameValidationState.idle:
        return const SizedBox.shrink();
    }

    return Row(
      children: [
        if (icon != null) ...[
          Icon(icon, size: 13, color: color.withOpacity(0.8)),
          const SizedBox(width: 5),
        ],
        if (_validationState == NameValidationState.checking) ...[
          SizedBox(
            width: 10,
            height: 10,
            child: CircularProgressIndicator(
              strokeWidth: 1.5,
              color: color.withOpacity(0.6),
            ),
          ),
          const SizedBox(width: 5),
        ],
        Expanded(
          child: Text(
            msg,
            style: TextStyle(
              color: color.withOpacity(0.8),
              fontSize: 11,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    );
  }

  Widget _ruleRow(String text, BoardTheme t) {
    return Padding(
      padding: const EdgeInsets.only(top: 2),
      child: Row(
        children: [
          Icon(Icons.circle, size: 3, color: t.textSecondary.withOpacity(0.5)),
          const SizedBox(width: 8),
          Text(
            text,
            style: TextStyle(
              color: t.textSecondary.withOpacity(0.6),
              fontSize: 10,
            ),
          ),
        ],
      ),
    );
  }
}