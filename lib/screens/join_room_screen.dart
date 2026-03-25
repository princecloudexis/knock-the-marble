// lib/screens/join_room_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/room_provider.dart';
import '../providers/settings_provider.dart';
import 'game_screen.dart';

class JoinRoomScreen extends ConsumerStatefulWidget {
  const JoinRoomScreen({super.key});

  @override
  ConsumerState<JoinRoomScreen> createState() => _JoinRoomScreenState();
}

class _JoinRoomScreenState extends ConsumerState<JoinRoomScreen> {
  final List<TextEditingController> _controllers =
      List.generate(6, (_) => TextEditingController());
  final List<FocusNode> _focusNodes =
      List.generate(6, (_) => FocusNode());
  bool _isJoining = false;
  String? _errorText;

  @override
  void dispose() {
    for (final c in _controllers) {
      c.dispose();
    }
    for (final f in _focusNodes) {
      f.dispose();
    }
    super.dispose();
  }

  String get _code =>
      _controllers.map((c) => c.text).join().toUpperCase();

  Future<void> _joinRoom() async {
    final code = _code;
    if (code.length < 6) {
      setState(() => _errorText = 'Please enter the full 6-character code');
      return;
    }

    setState(() {
      _isJoining = true;
      _errorText = null;
    });

    final success =
        await ref.read(roomProvider.notifier).joinRoom(code);

    if (!mounted) return;

    if (success) {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => const GameScreen()),
      );
    } else {
      setState(() {
        _isJoining = false;
        _errorText = 'Room not found or already full';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = ref.watch(boardThemeProvider);

    return Scaffold(
      body: Container(
        decoration: BoxDecoration(gradient: t.backgroundGradient),
        child: SafeArea(
          child: Column(
            children: [
              // Top bar
              Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    GestureDetector(
                      onTap: () => Navigator.pop(context),
                      child: Container(
                        width: 36,
                        height: 36,
                        decoration: BoxDecoration(
                          color: t.cardColor.withOpacity(0.5),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: t.surfaceBorder),
                        ),
                        child: Icon(Icons.arrow_back_ios_new,
                            size: 16, color: t.textSecondary),
                      ),
                    ),
                    const SizedBox(width: 14),
                    Text('Join Room',
                        style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.w700,
                          color: t.textPrimary,
                        )),
                  ],
                ),
              ),

              const Spacer(flex: 2),

              // Icon
              Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: t.accent.withOpacity(0.1),
                  border: Border.all(
                      color: t.accent.withOpacity(0.3), width: 2),
                ),
                child: Icon(Icons.login_rounded,
                    size: 36, color: t.accent),
              ),

              const SizedBox(height: 24),

              Text('Enter Room Code',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                    color: t.textPrimary,
                  )),

              const SizedBox(height: 8),
              Text('Ask your friend for the 6-character code',
                  style: TextStyle(
                    fontSize: 13,
                    color: t.textSecondary,
                  )),

              const SizedBox(height: 32),

              // Code input boxes
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 40),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: List.generate(6, (i) {
                    return Container(
                      width: 44,
                      height: 52,
                      margin: EdgeInsets.only(
                        right: i < 5 ? 8 : 0,
                        left: i == 3 ? 8 : 0, // Extra gap in middle
                      ),
                      child: TextField(
                        controller: _controllers[i],
                        focusNode: _focusNodes[i],
                        textAlign: TextAlign.center,
                        maxLength: 1,
                        textCapitalization:
                            TextCapitalization.characters,
                        style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.w900,
                          color: t.textPrimary,
                        ),
                        decoration: InputDecoration(
                          counterText: '',
                          filled: true,
                          fillColor: t.cardColor.withOpacity(0.6),
                          border: OutlineInputBorder(
                            borderRadius:
                                BorderRadius.circular(10),
                            borderSide: BorderSide(
                                color: t.surfaceBorder),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius:
                                BorderRadius.circular(10),
                            borderSide: BorderSide(
                                color: t.surfaceBorder),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius:
                                BorderRadius.circular(10),
                            borderSide: BorderSide(
                                color: t.accent, width: 2),
                          ),
                        ),
                        onChanged: (val) {
                          if (val.isNotEmpty && i < 5) {
                            _focusNodes[i + 1].requestFocus();
                          }
                          if (val.isEmpty && i > 0) {
                            _focusNodes[i - 1].requestFocus();
                          }
                          setState(() => _errorText = null);
                        },
                      ),
                    );
                  }),
                ),
              ),

              if (_errorText != null) ...[
                const SizedBox(height: 16),
                Text(_errorText!,
                    style: TextStyle(
                      color: Colors.red.shade400,
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                    )),
              ],

              const SizedBox(height: 32),

              // Join button
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 60),
                child: SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: ElevatedButton(
                    onPressed: _isJoining ? null : _joinRoom,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: t.accent,
                      foregroundColor: Colors.white,
                      disabledBackgroundColor:
                          t.accent.withOpacity(0.5),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                      elevation: 0,
                    ),
                    child: _isJoining
                        ? const SizedBox(
                            width: 22,
                            height: 22,
                            child: CircularProgressIndicator(
                              color: Colors.white,
                              strokeWidth: 2.5,
                            ),
                          )
                        : const Text('Join Game',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                            )),
                  ),
                ),
              ),

              const Spacer(flex: 3),
            ],
          ),
        ),
      ),
    );
  }
}