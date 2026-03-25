import 'package:knock_the_marble/services/room_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:knock_the_marble/widgets/name_setup_dialog.dart';
import 'package:share_plus/share_plus.dart';
import '../models/avatar_data.dart';
import '../models/player.dart';
import '../models/user_profile.dart';
import '../providers/room_provider.dart';
import '../providers/user_provider.dart';
import '../providers/settings_provider.dart';
import '../providers/ad_provider.dart';
import '../theme/board_themes.dart';
import '../widgets/banner_ad_widget.dart';
import 'game_screen.dart';

class RoomScreen extends ConsumerStatefulWidget {
  const RoomScreen({super.key});

  @override
  ConsumerState<RoomScreen> createState() => _RoomScreenState();
}

class _RoomScreenState extends ConsumerState<RoomScreen>
    with SingleTickerProviderStateMixin {
  final _joinCtrl = TextEditingController();
  bool _isJoining = false;

  @override
  void dispose() {
    _joinCtrl.dispose();
    super.dispose();
  }

  void _goToGame() {
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (_) => const GameScreen()),
    );
  }

  // ══════════════════════════════════════
  // HELPERS
  // ══════════════════════════════════════

  String _marbleName(BoardTheme t, Player player) {
    if (player == Player.black) {
      return _inferMarbleColorName(t.blackMarbleColors);
    } else if (player == Player.white) {
      return _inferMarbleColorName(t.whiteMarbleColors);
    }
    return '';
  }

  String _inferMarbleColorName(List<Color> colors) {
    if (colors.isEmpty) return 'Marble';
    final primary = colors.first;
    final r = primary.red, g = primary.green, b = primary.blue;

    if (r > 200 && g > 200 && b > 200) return 'Pearl';
    if (r > 200 && g > 180 && b < 150) return 'Gold';
    if (r > 200 && g < 100 && b < 100) return 'Ruby';
    if (r > 200 && g > 100 && b < 80) return 'Ember';
    if (r > 200 && g < 120 && b > 120) return 'Rose';
    if (r < 100 && g < 100 && b > 150) return 'Sapphire';
    if (r < 80 && g > 120 && b > 150) return 'Teal';
    if (r < 100 && g > 150 && b < 120) return 'Emerald';
    if (r > 100 && g < 80 && b > 150) return 'Amethyst';
    if (r > 150 && g > 150 && b > 200) return 'Crystal';
    if (r > 200 && g > 220 && b > 220) return 'Frost';
    if (r > 180 && g > 200 && b > 230) return 'Ice';
    if (r > 200 && g > 200 && b < 100) return 'Amber';
    if (r < 60 && g > 100 && b > 100) return 'Ocean';

    if (r > g && r > b) return 'Crimson';
    if (g > r && g > b) return 'Jade';
    if (b > r && b > g) return 'Azure';

    return 'Marble';
  }

  String? _getUserName() {
    final user = ref.read(currentUserProvider);
    if (user == null) return null;
    return user.displayName.isNotEmpty ? user.displayName : null;
  }

  // ══════════════════════════════════════
  // NAME CHECK
  // ══════════════════════════════════════

  Future<bool> _ensureUserHasName() async {
  return await NameSetupDialog.ensureNameSet(
    context,
    ref,
    subtitle: 'You need a name to play online',
  );
}

  // ══════════════════════════════════════
  // SHARE ROOM CODE
  // ══════════════════════════════════════

  void _shareRoomCode(String roomCode) {
    Share.share(
      'Join my Abalone game! 🎮\n\n'
      'Room Code: $roomCode\n\n'
      'Open the app → Play Online → Join Room → Enter the code!',
      subject: 'Abalone Game Invite',
    );
  }

  // ══════════════════════════════════════
  // BUILD
  // ══════════════════════════════════════

  @override
  Widget build(BuildContext context) {
    final t = ref.watch(boardThemeProvider);
    final room = ref.watch(roomProvider);
    final user = ref.watch(currentUserProvider);

    ref.listen<RoomState>(roomProvider, (prev, next) {
      if (next.roomData?.status == 'playing' &&
          prev?.roomData?.status != 'playing') {
        _goToGame();
      }
      if (next.error != null && prev?.error == null) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Row(
                children: [
                  const Icon(Icons.error_outline,
                      color: Colors.white, size: 18),
                  const SizedBox(width: 8),
                  Expanded(child: Text(next.error!)),
                ],
              ),
              backgroundColor: Colors.red.withOpacity(0.85),
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              margin: const EdgeInsets.all(16),
              duration: const Duration(seconds: 3),
            ),
          );
          Future.microtask(() {
            ref.read(roomProvider.notifier).clearError();
          });
        }
      }
    });

    return Scaffold(
      body: Container(
        decoration: BoxDecoration(gradient: t.backgroundGradient),
        child: SafeArea(
          child: Column(
            children: [
              _topBar(t),
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: room.inRoom
                      ? _waitingView(room, user, t)
                      : _lobbyView(user, t, room),
                ),
              ),
              const BannerAdWidget(),
            ],
          ),
        ),
      ),
    );
  }

  // ══════════════════════════════════════
  // TOP BAR
  // ══════════════════════════════════════

  Widget _topBar(BoardTheme t) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      child: Row(
        children: [
          GestureDetector(
            onTap: () async {
              await ref.read(roomProvider.notifier).leaveRoom();
              if (mounted) Navigator.pop(context);
            },
            child: Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: t.cardColor.withOpacity(0.5),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: t.surfaceBorder),
              ),
              child: Icon(
                Icons.arrow_back_ios_new,
                size: 16,
                color: t.textSecondary,
              ),
            ),
          ),
          const Spacer(),
          Text(
            'PLAY ONLINE',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w800,
              letterSpacing: 3,
              color: t.textPrimary,
            ),
          ),
          const Spacer(),
          const SizedBox(width: 40),
        ],
      ),
    );
  }

  // ══════════════════════════════════════
  // LOBBY VIEW
  // ══════════════════════════════════════

  Widget _lobbyView(UserProfile? user, BoardTheme t, RoomState room) {
    return Column(
      children: [
        const SizedBox(height: 30),
        if (user != null) _profileCard(user, t),
        const SizedBox(height: 30),

        if (room.error != null) ...[
          _errorBanner(room.error!, t),
          const SizedBox(height: 16),
        ],

        _actionButton(
          icon: Icons.add_circle_outline,
          label: 'CREATE ROOM',
          subtitle: 'Host a game & choose your marble',
          onTap: room.isLoading
              ? null
              : () async {
                  final hasName = await _ensureUserHasName();
                  if (!hasName || !mounted) return;
                  _showHostColorPicker(t);
                },
          t: t,
          isLoading: room.isLoading,
        ),

        const SizedBox(height: 16),

        Row(
          children: [
            Expanded(child: Divider(color: t.surfaceBorder)),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Text(
                'OR',
                style: TextStyle(
                  color: t.textSecondary,
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            Expanded(child: Divider(color: t.surfaceBorder)),
          ],
        ),
        const SizedBox(height: 16),

        Text(
          'JOIN ROOM',
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
            border: Border.all(color: t.surfaceBorder),
          ),
          child: TextField(
            controller: _joinCtrl,
            textCapitalization: TextCapitalization.characters,
            maxLength: 6,
            inputFormatters: [
              FilteringTextInputFormatter.allow(
                  RegExp(r'[a-zA-Z0-9]')),
              UpperCaseTextFormatter(),
            ],
            style: TextStyle(
              color: t.textPrimary,
              fontSize: 20,
              fontWeight: FontWeight.w800,
              letterSpacing: 8,
            ),
            textAlign: TextAlign.center,
            decoration: InputDecoration(
              hintText: '------',
              hintStyle: TextStyle(
                color: t.textSecondary.withOpacity(0.3),
                letterSpacing: 8,
              ),
              counterText: '',
              border: InputBorder.none,
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 16,
              ),
            ),
          ),
        ),

        const SizedBox(height: 12),

        SizedBox(
          width: double.infinity,
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: _isJoining
                  ? null
                  : () async {
                      final code = _joinCtrl.text.trim();
                      if (code.length != 6) {
                        _showValidationError(
                          'Please enter a 6-character room code',
                          t,
                        );
                        return;
                      }
                      final hasName = await _ensureUserHasName();
                      if (!hasName || !mounted) return;

                      setState(() => _isJoining = true);

                      ref
                          .read(adProvider.notifier)
                          .showAdBeforeGame(
                        onDone: () async {
                          if (!mounted) return;
                          final success = await ref
                              .read(roomProvider.notifier)
                              .joinRoom(code);
                          if (mounted) {
                            setState(() => _isJoining = false);
                            if (success) {
                              _joinCtrl.clear();
                              _goToGame();
                            }
                          }
                        },
                      );
                    },
              borderRadius: BorderRadius.circular(14),
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 14),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(14),
                  color: t.accent.withOpacity(0.15),
                  border: Border.all(
                      color: t.accent.withOpacity(0.3)),
                ),
                child: Center(
                  child: _isJoining
                      ? SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: t.accent,
                          ),
                        )
                      : Text(
                          'JOIN',
                          style: TextStyle(
                            color: t.accent,
                            fontSize: 14,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 2,
                          ),
                        ),
                ),
              ),
            ),
          ),
        ),

        const SizedBox(height: 30),
      ],
    );
  }

  void _showValidationError(String message, BoardTheme t) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.warning_amber_rounded,
                color: Colors.white, size: 18),
            const SizedBox(width: 8),
            Text(message),
          ],
        ),
        backgroundColor: Colors.orange.withOpacity(0.85),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        margin: const EdgeInsets.all(16),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  Widget _errorBanner(String error, BoardTheme t) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.red.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.red.withOpacity(0.3)),
      ),
      child: Row(
        children: [
          const Icon(Icons.error_outline, color: Colors.red, size: 18),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              error,
              style:
                  const TextStyle(color: Colors.red, fontSize: 13),
            ),
          ),
          GestureDetector(
            onTap: () =>
                ref.read(roomProvider.notifier).clearError(),
            child: Icon(
              Icons.close,
              size: 16,
              color: Colors.red.withOpacity(0.6),
            ),
          ),
        ],
      ),
    );
  }

  // ══════════════════════════════════════
  // COLOR PICKER — DIALOG STYLE (LIKE MENU)
  // ══════════════════════════════════════

  void _showHostColorPicker(BoardTheme t) {
    final userName = _getUserName() ?? 'You';
    final blackColors = t.blackMarbleColors;
    final whiteColors = t.whiteMarbleColors;
    final blackHlCol = t.blackHighlightColor;
    final blackHlOp = t.blackHighlightOpacity;
    final whiteHlCol = t.whiteHighlightColor;
    final whiteHlOp = t.whiteHighlightOpacity;
    final blackName = _marbleName(t, Player.black);
    final whiteName = _marbleName(t, Player.white);

    showDialog(
      context: context,
      barrierColor: Colors.black.withOpacity(0.6),
      builder: (ctx) => Dialog(
        backgroundColor: Colors.transparent,
        elevation: 0,
        insetPadding: const EdgeInsets.symmetric(horizontal: 28),
        child: SingleChildScrollView(
          child: Container(
            padding: const EdgeInsets.fromLTRB(24, 28, 24, 24),
            decoration: BoxDecoration(
              color: t.cardColor,
              borderRadius: BorderRadius.circular(28),
              border: Border.all(
                  color: t.surfaceBorder.withOpacity(0.6)),
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
                // Header icon
                Container(
                  width: 52,
                  height: 52,
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
                    Icons.language_rounded,
                    color: t.accent,
                    size: 26,
                  ),
                ),
                const SizedBox(height: 16),

                // Title
                Text(
                  'Choose Your Marble',
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w900,
                    color: t.textPrimary,
                    letterSpacing: -0.3,
                  ),
                ),
                const SizedBox(height: 4),

                // Subtitle with username
                RichText(
                  textAlign: TextAlign.center,
                  text: TextSpan(
                    style: TextStyle(
                      fontSize: 13,
                      color: t.textSecondary.withOpacity(0.7),
                    ),
                    children: [
                      TextSpan(
                        text: userName,
                        style: TextStyle(
                          fontWeight: FontWeight.w800,
                          color: t.accent,
                        ),
                      ),
                      const TextSpan(
                          text: ', pick your side for online'),
                    ],
                  ),
                ),
                const SizedBox(height: 28),

                // Marble options
                Row(
                  children: [
                    Expanded(
                      child: _OnlineMarbleOptionCard(
                        t: t,
                        marbleColors: blackColors,
                        highlightColor: blackHlCol,
                        highlightOpacity: blackHlOp,
                        marbleName: blackName,
                        label: 'You go first',
                        player: Player.black,
                        onTap: () async {
                          HapticFeedback.mediumImpact();
                          Navigator.pop(ctx);
                          await ref
                              .read(roomProvider.notifier)
                              .createRoom(hostColor: Player.black);
                        },
                      ),
                    ),
                    const SizedBox(width: 14),

                    // VS badge
                    Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: t.surfaceColor.withOpacity(0.5),
                        border: Border.all(
                            color:
                                t.surfaceBorder.withOpacity(0.4)),
                      ),
                      child: Center(
                        child: Text(
                          'VS',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w900,
                            color:
                                t.textSecondary.withOpacity(0.5),
                            letterSpacing: 0.5,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 14),

                    Expanded(
                      child: _OnlineMarbleOptionCard(
                        t: t,
                        marbleColors: whiteColors,
                        highlightColor: whiteHlCol,
                        highlightOpacity: whiteHlOp,
                        marbleName: whiteName,
                        label: 'Opponent first',
                        player: Player.white,
                        onTap: () async {
                          HapticFeedback.mediumImpact();
                          Navigator.pop(ctx);
                          await ref
                              .read(roomProvider.notifier)
                              .createRoom(hostColor: Player.white);
                        },
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),

                // Cancel
                GestureDetector(
                  onTap: () => Navigator.pop(ctx),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 20, vertical: 10),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(12),
                      color: t.surfaceColor.withOpacity(0.3),
                    ),
                    child: Text(
                      'Cancel',
                      style: TextStyle(
                        color: t.textSecondary.withOpacity(0.6),
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
      ),
    );
  }

  // ══════════════════════════════════════
  // WAITING VIEW
  // ══════════════════════════════════════

  Widget _waitingView(
      RoomState room, UserProfile? user, BoardTheme t) {
    final roomCode = room.roomId ?? '';
    final userName = user?.displayName ?? 'You';

    return Column(
      children: [
        const SizedBox(height: 40),

        // Room Code Card
        Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: t.cardColor.withOpacity(0.8),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
                color: t.accent.withOpacity(0.3), width: 2),
          ),
          child: Column(
            children: [
              Text(
                'ROOM CODE',
                style: TextStyle(
                  color: t.textSecondary,
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 2,
                ),
              ),
              const SizedBox(height: 12),
              GestureDetector(
                onTap: () => _copyRoomCode(roomCode),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      roomCode,
                      style: TextStyle(
                        color: t.accent,
                        fontSize: 36,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 10,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Icon(Icons.copy,
                        color: t.textSecondary, size: 18),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'Share this code with your friend',
                style: TextStyle(
                    color: t.textSecondary, fontSize: 12),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: _roomActionButton(
                      icon: Icons.share_rounded,
                      label: 'Share',
                      onTap: () => _shareRoomCode(roomCode),
                      t: t,
                      isPrimary: true,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),

        const SizedBox(height: 20),

        // Your marble indicator with name & color
        _yourMarbleIndicator(room, t, userName),

        const SizedBox(height: 24),

        SizedBox(
          width: 40,
          height: 40,
          child: CircularProgressIndicator(
            strokeWidth: 3,
            color: t.accent.withOpacity(0.5),
          ),
        ),
        const SizedBox(height: 16),
        Text(
          'Waiting for opponent...',
          style: TextStyle(
            color: t.textPrimary,
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
        ),

        const SizedBox(height: 30),

        if (user != null) _profileCard(user, t),

        if (room.roomData?.guestId != null) ...[
          const SizedBox(height: 14),
          Text(
            'VS',
            style: TextStyle(
              color: t.accent,
              fontSize: 14,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 14),
          _opponentCard(room.roomData!, t),
        ],

        const SizedBox(height: 30),

        SizedBox(
          width: double.infinity,
          child: OutlinedButton.icon(
            onPressed: () async {
              await ref.read(roomProvider.notifier).leaveRoom();
              if (mounted) Navigator.pop(context);
            },
            icon: Icon(
              Icons.close_rounded,
              color: Colors.red.withOpacity(0.7),
              size: 20,
            ),
            label: Text(
              'Cancel & Leave',
              style: TextStyle(
                color: Colors.red.withOpacity(0.7),
                fontWeight: FontWeight.w600,
              ),
            ),
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
              side: BorderSide(
                  color: Colors.red.withOpacity(0.3)),
            ),
          ),
        ),

        const SizedBox(height: 30),
      ],
    );
  }

  // ══════════════════════════════════════
  // HELPER WIDGETS
  // ══════════════════════════════════════

  void _copyRoomCode(String code) {
    Clipboard.setData(ClipboardData(text: code));
    HapticFeedback.mediumImpact();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Row(
          children: [
            Icon(Icons.check_circle, color: Colors.white, size: 18),
            SizedBox(width: 8),
            Text('Room code copied!'),
          ],
        ),
        backgroundColor: Colors.green.withOpacity(0.85),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        margin: const EdgeInsets.all(16),
        duration: const Duration(seconds: 1),
      ),
    );
  }

  Widget _roomActionButton({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
    required BoardTheme t,
    bool isPrimary = false,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            color: isPrimary
                ? t.accent.withOpacity(0.15)
                : t.surfaceColor.withOpacity(0.5),
            border: Border.all(
              color: isPrimary
                  ? t.accent.withOpacity(0.3)
                  : t.surfaceBorder,
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                size: 18,
                color: isPrimary ? t.accent : t.textSecondary,
              ),
              const SizedBox(width: 8),
              Text(
                label,
                style: TextStyle(
                  color:
                      isPrimary ? t.accent : t.textSecondary,
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _yourMarbleIndicator(
      RoomState room, BoardTheme t, String userName) {
    final isBlack = room.myColor == Player.black;
    final List<Color> colors =
        isBlack ? t.blackMarbleColors : t.whiteMarbleColors;
    final colorName =
        _marbleName(t, room.myColor ?? Player.black);
    final goesFirst = isBlack;

    return Container(
      padding: const EdgeInsets.symmetric(
          horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: t.accent.withOpacity(0.1),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: t.accent.withOpacity(0.2)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 28,
            height: 28,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: RadialGradient(
                center: const Alignment(-0.3, -0.35),
                radius: 0.85,
                colors: colors,
              ),
            ),
          ),
          const SizedBox(width: 10),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                '$userName • $colorName',
                style: TextStyle(
                  color: t.accent,
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                ),
              ),
              Text(
                goesFirst
                    ? 'You go first'
                    : 'Opponent goes first',
                style: TextStyle(
                  color: t.accent.withOpacity(0.6),
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _profileCard(UserProfile user, BoardTheme t) {
    final avatar = AvatarData.getAvatar(user.avatarIndex);
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: t.cardColor.withOpacity(0.6),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: t.surfaceBorder),
      ),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(
                colors: avatar.gradientColors,
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
            child: Center(
              child: Text(
                avatar.emoji,
                style: const TextStyle(fontSize: 24),
              ),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  user.displayName.isEmpty
                      ? 'No Name'
                      : user.displayName,
                  style: TextStyle(
                    color: t.textPrimary,
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  user.shortId,
                  style: TextStyle(
                    color: t.textSecondary,
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(
                horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: t.accent.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              'YOU',
              style: TextStyle(
                color: t.accent,
                fontSize: 10,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _opponentCard(RoomData roomData, BoardTheme t) {
    final avatar =
        AvatarData.getAvatar(roomData.guestAvatar ?? 0);
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: t.cardColor.withOpacity(0.6),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: t.surfaceBorder),
      ),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(
                colors: avatar.gradientColors,
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
            child: Center(
              child: Text(
                avatar.emoji,
                style: const TextStyle(fontSize: 24),
              ),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Text(
              roomData.guestName ?? 'Guest',
              style: TextStyle(
                color: t.textPrimary,
                fontSize: 16,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(
                horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.orange.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Text(
              'OPPONENT',
              style: TextStyle(
                color: Colors.orange,
                fontSize: 10,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _actionButton({
    required IconData icon,
    required String label,
    required String subtitle,
    required VoidCallback? onTap,
    required BoardTheme t,
    bool isLoading = false,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(
              vertical: 18, horizontal: 20),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            gradient: LinearGradient(
              colors: [
                t.accent.withOpacity(0.15),
                t.accent.withOpacity(0.05),
              ],
            ),
            border: Border.all(
                color: t.accent.withOpacity(0.3)),
          ),
          child: Row(
            children: [
              isLoading
                  ? SizedBox(
                      width: 24,
                      height: 24,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: t.accent,
                      ),
                    )
                  : Icon(icon, color: t.accent, size: 24),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment:
                      CrossAxisAlignment.start,
                  children: [
                    Text(
                      label,
                      style: TextStyle(
                        color: t.textPrimary,
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: TextStyle(
                        color: t.textSecondary,
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(Icons.chevron_right,
                  color: t.textSecondary, size: 20),
            ],
          ),
        ),
      ),
    );
  }
}

// ══════════════════════════════════════
// ONLINE MARBLE OPTION CARD (LIKE MENU)
// ══════════════════════════════════════

class _OnlineMarbleOptionCard extends StatefulWidget {
  final BoardTheme t;
  final List<Color> marbleColors;
  final Color highlightColor;
  final double highlightOpacity;
  final String marbleName;
  final String label;
  final Player player;
  final VoidCallback onTap;

  const _OnlineMarbleOptionCard({
    required this.t,
    required this.marbleColors,
    required this.highlightColor,
    required this.highlightOpacity,
    required this.marbleName,
    required this.label,
    required this.player,
    required this.onTap,
  });

  @override
  State<_OnlineMarbleOptionCard> createState() =>
      _OnlineMarbleOptionCardState();
}

class _OnlineMarbleOptionCardState
    extends State<_OnlineMarbleOptionCard>
    with SingleTickerProviderStateMixin {
  late AnimationController _hoverCtrl;
  bool _pressed = false;

  @override
  void initState() {
    super.initState();
    _hoverCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 150),
      lowerBound: 0.0,
      upperBound: 1.0,
    );
  }

  @override
  void dispose() {
    _hoverCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final t = widget.t;
    const marbleSize = 50.0;

    return GestureDetector(
      onTap: widget.onTap,
      onTapDown: (_) {
        _hoverCtrl.forward();
        setState(() => _pressed = true);
      },
      onTapUp: (_) {
        _hoverCtrl.reverse();
        setState(() => _pressed = false);
      },
      onTapCancel: () {
        _hoverCtrl.reverse();
        setState(() => _pressed = false);
      },
      child: AnimatedBuilder(
        animation: _hoverCtrl,
        builder: (_, child) {
          final scale = 1.0 - _hoverCtrl.value * 0.04;
          return Transform.scale(
              scale: scale, child: child);
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: const EdgeInsets.symmetric(
              vertical: 16, horizontal: 10),
          decoration: BoxDecoration(
            color: _pressed
                ? t.surfaceColor.withOpacity(0.8)
                : t.surfaceColor.withOpacity(0.4),
            borderRadius: BorderRadius.circular(22),
            border: Border.all(
              color: _pressed
                  ? t.accent.withOpacity(0.5)
                  : t.surfaceBorder.withOpacity(0.5),
              width: _pressed ? 2.0 : 1.5,
            ),
            boxShadow: _pressed
                ? [
                    BoxShadow(
                      color: t.accent.withOpacity(0.15),
                      blurRadius: 16,
                      spreadRadius: 2,
                    ),
                  ]
                : [],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Marble
              Container(
                width: marbleSize,
                height: marbleSize,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    center:
                        const Alignment(-0.3, -0.35),
                    radius: 0.85,
                    colors: widget.marbleColors,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color:
                          Colors.black.withOpacity(0.3),
                      blurRadius: 10,
                      offset: const Offset(2, 4),
                    ),
                    if (_pressed)
                      BoxShadow(
                        color:
                            t.accent.withOpacity(0.2),
                        blurRadius: 12,
                        spreadRadius: 2,
                      ),
                  ],
                ),
                child: Stack(
                  children: [
                    Align(
                      alignment:
                          const Alignment(-0.3, -0.3),
                      child: Container(
                        width: 16,
                        height: 9,
                        decoration: BoxDecoration(
                          borderRadius:
                              BorderRadius.circular(10),
                          gradient: LinearGradient(
                            colors: [
                              widget.highlightColor
                                  .withOpacity(
                                      widget.highlightOpacity *
                                          0.8),
                              Colors.transparent,
                            ],
                          ),
                        ),
                      ),
                    ),
                    Positioned(
                      left: marbleSize * 0.25,
                      top: marbleSize * 0.2,
                      child: Container(
                        width: 5,
                        height: 5,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: Colors.white.withOpacity(
                              widget.highlightOpacity *
                                  0.7),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 10),

              // Marble color name
              Text(
                widget.marbleName,
                style: TextStyle(
                  color: t.textPrimary,
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.3,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 3),

              // Label
              Text(
                widget.label,
                style: TextStyle(
                  color:
                      t.textSecondary.withOpacity(0.6),
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ══════════════════════════════════════
// UPPERCASE TEXT FORMATTER
// ══════════════════════════════════════

class UpperCaseTextFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    return TextEditingValue(
      text: newValue.text.toUpperCase(),
      selection: newValue.selection,
    );
  }
}